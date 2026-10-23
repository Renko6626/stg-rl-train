#!/usr/bin/env python3
"""Throwaway TH18 raw-instruction -> existing stg-core image experiment.

One subroutine, one difficulty, no calls/async. Source stack slots are lowered to
target locals; control flow stays jumps. No source interpreter runs per frame.
Only integer script times are supported. --demo opts into listed gameplay
approximations; without it unsupported gameplay is rejected, never dropped.
"""
from __future__ import annotations

import argparse
from collections import deque
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import subprocess

from parser import Instruction, Param, Sub, parse

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
ENGINE = REPO.parent / 'stg-engine'
THECL = REPO.parent / 'renkolab/local/vendor/thtk/build/thecl/thecl'
WORK = REPO / 'transcribe/work/th18-prototype'


class Unsupported(ValueError):
    pass


def constants(path: Path, prefix: str) -> dict[str, int]:
    """Read the existing engine's public numeric ABI; do not duplicate its table."""
    return {name: int(value, 0) for name, value in re.findall(
        rf'pub const ({prefix}\w+): \w+ = (0x[0-9a-fA-F]+|\d+);', path.read_text())}


OPS = constants(ENGINE / 'crates/stg-core/src/ecl/ops.rs', 'OP_')
SYS = constants(ENGINE / 'crates/stg-core/src/ecl/syscall.rs', 'SYS_')
XF = constants(ENGINE / 'crates/stg-core/src/xform.rs', 'OP_')
TAU = round(struct.unpack('<f', struct.pack('<f', math.tau))[0] * 65536)


def fx(value: float) -> int:
    value = struct.unpack('<f', struct.pack('<f', value))[0]
    result = round(value * 65536)
    if not -(1 << 31) <= result < (1 << 31):
        raise Unsupported(f'float {value} is outside Q16.16')
    return result


class Compiler:
    def __init__(self, sub: Sub, rank: int, demo: bool = False):
        self.sub, self.rank, self.demo = sub, rank, demo
        self.code: list[int] = []
        self.fixups: list[tuple[int, int]] = []
        self.starts: dict[int, int] = {}
        self.source_map: list[dict] = []
        self.notes: set[str] = set()
        self.active = [bool(i.rank & (1 << rank)) for i in sub.instructions]
        floating_ops = {24,44,45,51,53,55,57,60,62,64,66,68,70,72,84,536}
        if any(active and (i.op in floating_ops or any(p.kind == 'float' for p in i.args))
               for i, active in zip(sub.instructions, self.active)):
            if not demo:
                raise Unsupported('source floats require --demo: Q16.16 quantization may change arithmetic, comparisons and float-to-int branch decisions')
            self.notes.add('Source f32 is lowered to Q16.16: arithmetic, comparisons and float-to-int branch decisions may differ near numeric thresholds, not just trajectories.')
        sizes = [self.literal(i.args[0]) for i in sub.instructions if i.op == 40]
        if any(n < 0 or n % 4 for n in sizes):
            raise Unsupported('unaligned/negative source local allocation')
        self.nlocals = max(sizes, default=0) // 4
        if self.nlocals > 24:
            raise Unsupported('prototype supports at most 24 source local words')
        self.types: dict[int, str] = {}
        for i, active in zip(sub.instructions, self.active):
            if active and i.op in (43, 45, 78, 535, 536):
                slot = self.local(i.args[0])
                ty = 'float' if i.op in (45, 536) else 'int'
                if slot in self.types and self.types[slot] != ty:
                    raise Unsupported('mixed typed local writes need a richer lowering')
                self.types[slot] = ty
        self.stacks = self.analyze_stack()
        self.stack_base = self.nlocals
        depth = max((len(s) for s in self.stacks.values()), default=0)
        self.clock_base = self.stack_base + depth
        self.temp = self.clock_base + 1
        self.xbase = self.temp + 1
        if self.xbase + 9 > 64:
            raise Unsupported('prototype local storage exceeds target VM capacity')
        self.current: Instruction | None = None
        self.stack: tuple[str, ...] = ()
        self.xform_shooter: int | None = None

    @staticmethod
    def literal(p: Param) -> int:
        if p.ref or p.kind != 'int' or p.cast:
            raise Unsupported('expected an integer literal')
        return p.value

    def local(self, p: Param) -> int:
        if not p.ref or p.value < 0 or int(p.value) != p.value or int(p.value) % 4:
            raise Unsupported('expected aligned source local reference')
        slot = int(p.value) // 4
        if slot >= self.nlocals:
            raise Unsupported(f'local byte offset {p.value} exceeds allocation')
        return slot

    def successors(self, n: int) -> list[int]:
        i = self.sub.instructions[n]
        if not self.active[n]:
            return [n + 1]
        if i.op in (1, 10):
            return []
        if i.op in (12, 13, 14):
            try:
                target = self.sub.labels[i.args[0].value]
            except KeyError as exc:
                raise Unsupported(f'unknown jump label {i.args[0].value}') from exc
            return [target] if i.op == 12 else [target, n + 1]
        return [n + 1]

    def analyze_stack(self) -> dict[int, tuple[str, ...]]:
        states = {0: ()}
        todo = deque([0])
        binary = {50:'int', 51:'float', 52:'int', 53:'float', 54:'int',
                  55:'float', 56:'int', 57:'float', 58:'int'}
        while todo:
            n = todo.popleft()
            if n == len(self.sub.instructions):
                continue
            i = self.sub.instructions[n]
            stack = list(states[n])
            def pop(kind=None):
                if not stack:
                    raise Unsupported(f'line {i.line}: source stack underflow')
                got = stack.pop()
                if kind and got != kind:
                    raise Unsupported(f'line {i.line}: mixed typed stack arithmetic')
            if self.active[n]:
                if i.stack_pop is None:
                    raise Unsupported('binary header attachment required for stack consumption')
                if i.op in (42, 44, 78):
                    stack.append('float' if i.op == 44 else 'int')
                elif i.op in (43, 45):
                    pop('float' if i.op == 45 else 'int')
                elif i.op in (13, 14):
                    pop()  # TH18 truncates floating conditions to int.
                elif i.op in binary:
                    pop(binary[i.op]); pop(binary[i.op]); stack.append(binary[i.op])
                elif 59 <= i.op <= 70:
                    kind = 'float' if i.op % 2 == 0 else 'int'
                    pop(kind); pop(kind); stack.append('int')
                elif i.op in (71, 72, 83, 84):
                    kind = 'float' if i.op in (72, 84) else 'int'
                    pop(kind); stack.append('int' if i.op in (71, 72) else kind)
                for _ in range(i.stack_pop):
                    pop()
            result = tuple(stack)
            for target in self.successors(n):
                if target in states and states[target] != result:
                    raise Unsupported(f'line {i.line}: incompatible stack shapes at merge')
                if target not in states:
                    states[target] = result
                    todo.append(target)
        return states

    def emit(self, name: str, *args: int) -> int:
        at = len(self.code)
        self.code.extend([OPS['OP_' + name], *(v & 0xffffffff for v in args)])
        return at

    def push(self, value: int):
        if not -(1 << 31) <= value < (1 << 31):
            raise Unsupported(f'int literal outside i32: {value}')
        self.emit('PUSHI', value)

    def sys(self, name: str):
        self.emit('SYS', SYS['SYS_' + name])

    def global_from_top(self, slot: int):
        self.emit('POPL', self.temp)
        self.push(slot); self.emit('PUSHL', self.temp); self.sys('SET_VAR')

    def watch(self, slot: int):
        self.push(64 + slot); self.emit('PUSHL', slot); self.sys('SET_VAR')

    def convert(self, source: str, target: str):
        if source != target:
            self.push(65536)
            self.emit('MUL' if target == 'float' else 'DIV')

    def param(self, p: Param):
        if p.cast:
            raise Unsupported('call argument casts are parsed but not lowered yet')
        if p.kind not in ('int', 'float'):
            raise Unsupported(f'unsupported value kind {p.kind}')
        if not p.ref:
            self.push(fx(p.value) if p.kind == 'float' else p.value)
        elif p.value >= 0:
            slot = self.local(p)
            source_type = self.types.get(slot)
            if source_type and source_type != p.kind:
                raise Unsupported('source local bit reinterpretation is not supported')
            self.emit('PUSHL', slot)
        elif -100 <= p.value <= -1 and int(p.value) == p.value:
            index = len(self.stack) + int(p.value)
            if index < 0:
                raise Unsupported('stack reference outside current stack')
            self.emit('PUSHL', self.stack_base + index)
            self.convert(self.stack[index], p.kind)
        elif p.value == -9998 and p.kind == 'float' and self.demo:
            self.notes.add('Native RANDRAD replaced by target PCG32 uniform [0,2pi); seeds are not native-equivalent.')
            self.push(TAU); self.sys('RAND_RANGE')
        else:
            raise Unsupported(f'unsupported special variable {p.value}')

    def angle(self, p: Param):
        if p.kind != 'float':
            raise Unsupported('angle must be a source float in radians')
        self.param(p); self.push(TAU); self.emit('DIVF')

    def time_gate(self, t: int):
        # Source clock = global_frame - base. Gate BEFORE rank filtering, as in ZUN.
        self.push(t); self.sys('FRAME'); self.emit('PUSHL', self.clock_base)
        self.emit('SUB'); self.emit('SUB'); self.emit('POPL', self.temp)
        self.emit('PUSHL', self.temp); self.push(0); self.emit('GT')
        done = self.emit('JZ', 0)
        self.emit('PUSHL', self.temp); self.emit('WAIT')
        self.code[done + 1] = len(self.code)

    def jump(self, n: int, i: Instruction):
        skip = None
        if i.op != 12:
            self.emit('PUSHL', self.stack_base + len(self.stack) - 1)
            self.convert(self.stack[-1], 'int')
            if i.op == 13:
                self.push(0); self.emit('EQ')
            skip = self.emit('JZ', 0)
        self.sys('FRAME'); self.param(i.args[1]); self.emit('SUB')
        self.emit('POPL', self.clock_base)
        at = self.emit('JMP', 0)
        self.fixups.append((at + 1, self.sub.labels[i.args[0].value]))
        if skip is not None:
            self.code[skip + 1] = len(self.code)

    def gameplay(self, i: Instruction):
        if not self.demo:
            raise Unsupported('gameplay import is experimental; use --demo to accept the explicit approximations')
        a, op = i.args, i.op
        sid = self.literal(a[0])
        if not 0 <= sid < 4:
            raise Unsupported('prototype requires literal shooter ID 0..3')
        self.notes.add('Standalone fixed emitter at (0,100); parent movement/async lifecycle is not imported.')
        if op == 600:
            self.push(sid); self.sys('SH_RESET')
            self.push(sid); self.push(0); self.push(100 * 65536); self.sys('SH_OFFSET_ABS')
        elif op == 602:
            self.notes.add('Native sprite/radius replaced by target appearance 0; native collision geometry is not reproduced.')
            self.push(sid); self.push(0); self.sys('SH_SPRITE')
        elif op == 607:
            mode = self.literal(a[1])
            if mode not in (2, 3):
                raise Unsupported('only single-layer aimed/un-aimed ring modes 2/3 supported')
            self.push(sid); self.push(1); self.sys('SH_RING')
            self.push(sid); self.push(int(mode == 2)); self.sys('SH_AIM')
        elif op == 606:
            if self.literal(a[2]) != 1:
                raise Unsupported('multi-layer speed interpolation not implemented')
            for p in a:
                self.param(p)
            self.sys('SH_COUNT')
        elif op == 605:
            self.push(sid); self.param(a[1]); self.push(0); self.sys('SH_SPEED')
        elif op == 604:
            self.push(sid); self.angle(a[1]); self.angle(a[2]); self.sys('SH_ANGLE')
        elif op == 627:
            self.push(sid); self.param(a[1]); self.sys('SH_DIST')
        elif op == 611:
            channel, typ = self.literal(a[1]), self.literal(a[2])
            if channel != 0:
                raise Unsupported('parallel EX channels not supported')
            if typ == 2 and self.literal(a[3]) == 1:
                self.notes.add('EX2 spawn state OMITTED: no initial -4*v offset, half-speed animation interval or delayed collision. Curve starts immediately; not faithful training data.')
                return
            if typ != 8 or self.xform_shooter is not None:
                raise Unsupported('only one EX8 setup in a sub is supported')
            self.xform_shooter = sid
            duration = self.literal(a[3])
            if not 1 <= duration <= 65535:
                raise Unsupported('EX8 duration outside supported range')
            # Three runtime-staged xform slots: acceleration, timed angular speed, stop.
            for k, (name, wait, value) in enumerate([
                ('SET_ACCEL', 0, a[5]), ('SET_ANG_VEL', duration, a[6]), ('STOP_FX', 0, None)
            ]):
                slot = self.xbase + 3*k
                self.push((wait << 16) | (XF['OP_' + name] << 8)); self.emit('POPL', slot)
                if value is None:
                    self.push(0)
                elif name == 'SET_ANG_VEL':
                    self.angle(value)
                else:
                    self.param(value)
                self.emit('POPL', slot + 1)
                self.push(0); self.emit('POPL', slot + 2)
            self.push(sid); self.push(self.xbase); self.push(3); self.sys('SH_XFORM')
            self.notes.add('EX8 uses target Q16.16/BAM integration for the specified duration; native float trajectories differ.')
        elif op == 601:
            self.push(sid); self.sys('SH_FIRE')
            self.push(17); self.push(17); self.sys('GET_VAR'); self.push(1); self.emit('ADD'); self.sys('SET_VAR')
        else:
            raise Unsupported(f'unsupported gameplay opcode {op}')

    def instruction(self, n: int, i: Instruction):
        op, a = i.op, i.args
        depth = len(self.stack)
        top = self.stack_base + depth - 1
        if op in (0, 40):
            return
        if op in (1, 10):
            self.push(19); self.push(1); self.sys('SET_VAR'); self.emit('END')
        elif op in (12, 13, 14):
            self.jump(n, i)
        elif op == 23:
            self.emit('PUSHL', self.clock_base); self.param(a[0]); self.emit('ADD')
            self.emit('POPL', self.clock_base)
        elif op in (42, 44):
            self.param(a[0]); self.emit('POPL', top + 1)
        elif op in (43, 45):
            slot = self.local(a[0])
            self.emit('PUSHL', top); self.emit('POPL', slot); self.watch(slot)
        elif 50 <= op <= 70:
            opname = {50:'ADD',51:'ADD',52:'SUB',53:'SUB',54:'MUL',55:'MULF',
                      56:'DIV',57:'DIVF',58:'MOD',59:'EQ',60:'EQ',61:'NE',62:'NE',
                      63:'LT',64:'LT',65:'LE',66:'LE',67:'GT',68:'GT',69:'GE',70:'GE'}[op]
            self.emit('PUSHL', top - 1); self.emit('PUSHL', top); self.emit(opname)
            self.emit('POPL', top - 1)
        elif op in (71, 72, 83, 84):
            self.emit('PUSHL', top)
            if op in (71, 72):
                self.push(0); self.emit('EQ')
            else:
                self.emit('NEG')
            self.emit('POPL', top)
        elif op == 78:
            slot = self.local(a[0])
            self.emit('PUSHL', slot); self.emit('DUP'); self.emit('POPL', top + 1)
            self.push(1); self.emit('SUB'); self.emit('POPL', slot); self.watch(slot)
        elif op in (535, 536):
            slot = self.local(a[0]); self.param(a[1 + self.rank])
            self.emit('POPL', slot); self.watch(slot)
        elif op in (600, 601, 602, 604, 605, 606, 607, 611, 627):
            self.gameplay(i)
        else:
            raise Unsupported(f'opcode {op} has no prototype lowering')

    def build(self) -> dict:
        self.sys('FRAME'); self.emit('POPL', self.clock_base)
        self.push(16); self.emit('PUSHL', self.clock_base); self.sys('SET_VAR')
        for n, i in enumerate(self.sub.instructions):
            self.starts[n] = len(self.code)
            if n not in self.stacks:
                continue
            self.current, self.stack = i, self.stacks[n]
            if not 0 <= i.time <= 32767:
                raise Unsupported(f'line {i.line}: time outside prototype range')
            self.time_gate(i.time)
            if self.active[n]:
                try:
                    self.instruction(n, i)
                except Unsupported as exc:
                    raise Unsupported(f'{self.sub.name}:{i.line} ins_{i.op}: {exc}') from exc
            self.source_map.append({'line':i.line, 'file_offset':i.address, 'op':i.op,
                                    'time':i.time, 'rank':i.rank, 'stack_in':list(self.stack),
                                    'target_word':self.starts[n], 'target_end':len(self.code)})
        self.starts[len(self.sub.instructions)] = len(self.code)
        self.emit('END')
        for word, target in self.fixups:
            self.code[word] = self.starts[target]
        version = constants(ENGINE / 'crates/stg-core/src/lib.rs', 'ENGINE_')['ENGINE_VER']
        return {'code':self.code, 'subs':[{'entry':0,'kind':'root','params':[]}],
                'entries':[], 'root':0, 'engine_ver':version,
                'watch_globals':[16,17,19,*range(64,64+self.nlocals)],
                'source_sub':self.sub.name, 'rank':self.rank, 'source_map':self.source_map,
                'approximations':sorted(self.notes), 'prototype_only':True}


def decode(path: Path, thecl: Path = THECL) -> tuple[dict[str, Sub], bytes]:
    binary = path.read_bytes()
    proc = subprocess.run([str(thecl), '-r', '-x', '-j', '-d', '18', str(path)],
                          check=True, capture_output=True)
    if proc.stderr:
        raise Unsupported(f'thecl diagnostics: {proc.stderr.decode(errors="replace")}')
    return parse(proc.stdout.decode('utf-8'), binary), binary


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('input', type=Path)
    p.add_argument('--sub', required=True)
    p.add_argument('--rank', type=int, choices=range(4), default=1)
    p.add_argument('--frames', type=int, default=160)
    p.add_argument('--seed', type=int, default=1)
    p.add_argument('--demo', action='store_true')
    p.add_argument('--thecl', type=Path, default=THECL)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    if not args.output.resolve().is_relative_to(WORK.resolve()):
        p.error(f'write derived images only beneath gitignored {WORK}')
    try:
        subs, binary = decode(args.input, args.thecl)
        if args.sub not in subs:
            raise Unsupported(f'no sub named {args.sub}')
        image = Compiler(subs[args.sub], args.rank, args.demo).build()
        image.update(frames=args.frames, seed=args.seed,
                     source_sha256=hashlib.sha256(binary).hexdigest())
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(image, indent=2) + '\n')
    except (Unsupported, ValueError, subprocess.CalledProcessError) as exc:
        p.exit(2, f'UNSUPPORTED: {exc}\n')
    print(json.dumps({'sub':args.sub,'words':len(image['code']),
                      'approximations':image['approximations']}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
