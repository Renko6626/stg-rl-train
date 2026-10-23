#!/usr/bin/env python3
"""Emit reviewable target ECL from the deliberately limited TH18 prototype.

Source control flow uses the existing target language, not a bytecode payload.
Only closed, straight-line branch/loop regions are recovered; others retain goto.
"""
from __future__ import annotations

import argparse
from decimal import Decimal
import hashlib
from pathlib import Path
import subprocess

from compile import Compiler, TAU, THECL, WORK, Unsupported, decode, fx
from parser import Param, Sub


def fixed(raw: int) -> str:
    """Spell a Q16.16 word within the lexer's decimal precision limit.

    Ten decimal places are much finer than half a Q16 unit, so target
    round-half-even reconstructs the same word, without i64 decimal overflow.
    """
    if raw == -(1 << 31):
        return '(-32767fx - 1fx)'
    return f'{Decimal(raw) / Decimal(65536):.10f}fx'


def integer(value: int) -> str:
    # The lexer reads unary minus separately, so positive 2147483648 is illegal.
    return '(-2147483647 - 1)' if value == -(1 << 31) else str(value)


def trunc_div(a: int, b: int) -> int:
    return (abs(a) // abs(b)) * (-1 if (a < 0) != (b < 0) else 1)


class SourceEmitter:
    def __init__(self, sub: Sub, rank: int, demo: bool, structured: bool):
        if rank not in range(4):
            raise Unsupported('rank must be 0..3')
        self.analysis = Compiler(sub, rank, demo)
        # Reuse the existing support checks and approximation inventory. Its
        # transient image is NEVER serialized or executed by the source path.
        self.analysis.build()
        self.sub, self.rank, self.structured = sub, rank, structured
        self.ins = sub.instructions
        self.stacks, self.active = self.analysis.stacks, self.analysis.active
        self.types = dict(self.analysis.types)
        for n, i in enumerate(self.ins):
            if n not in self.stacks or not self.active[n]:
                continue
            for p in i.args:
                if p.ref and p.kind in ('int', 'float') and p.value >= 0:
                    slot = self.analysis.local(p)
                    prior = self.types.setdefault(slot, p.kind)
                    if prior != p.kind:
                        raise Unsupported('source local bit reinterpretation is not supported')
        self.edges = {n: sub.labels[i.args[0].value] for n, i in enumerate(self.ins)
                      if n in self.stacks and self.active[n] and i.op in (12, 13, 14)}
        self.targets = set(self.edges.values())
        self.stack_vars: set[tuple[int, str]] = set()
        for n, stack in self.stacks.items():
            self.stack_vars.update(enumerate(stack))
            if n < len(self.ins) and self.active[n] and self.ins[n].op in (42, 44, 78):
                self.stack_vars.add((len(stack), 'float' if self.ins[n].op == 44 else 'int'))
        self.lines: list[str] = []
        self.indent = 1
        self.n = 0
        self.xforms: dict[str, str] = {}
        self.notes = sorted(self.analysis.notes)

    def put(self, text: str):
        self.lines.append('    ' * self.indent + text)

    @staticmethod
    def stackvar(index: int, kind: str) -> str:
        return f'stack_{index}_{"fx" if kind == "float" else "int"}'

    def sv(self, index: int) -> str:
        return self.stackvar(index, self.stacks[self.n][index])

    def param(self, p: Param) -> str:
        if p.cast:
            raise Unsupported('call argument casts are not supported')
        if not p.ref:
            return fixed(fx(p.value)) if p.kind == 'float' else integer(p.value)
        if p.value >= 0:
            return f'local_{self.analysis.local(p)}'
        if -100 <= p.value <= -1:
            index = len(self.stacks[self.n]) + int(p.value)
            value = self.sv(index)
            kind = self.stacks[self.n][index]
            return value if kind == p.kind else f'({value} as {"fx" if p.kind == "float" else "int"})'
        if p.value == -9998 and p.kind == 'float':
            self.put(f'random_raw = rand({TAU});')
            # int as fx scales numerically; split first so the fractional bits
            # survive and the intermediate never overflows.
            return ('((random_raw / 65536) as fx)'
                    ' + ((((random_raw % 65536) / 256) as fx) / 256)'
                    ' + (((random_raw % 256) as fx) / 65536)')
        raise Unsupported(f'unsupported special variable {p.value}')

    def raw_bits(self, value: str):
        """Convert an fx value to its signed raw word using legal numeric casts.

        Work in two base-256 fractional digits: fx*65536 would wrap before
        the cast. Each digit is exact, including negative fractions.
        """
        self.put(f'raw_fraction = {value};')
        self.put('raw_bits = (raw_fraction as int) * 65536;')
        self.put('raw_fraction = (raw_fraction - ((raw_fraction as int) as fx)) * 256;')
        self.put('raw_bits = raw_bits + (raw_fraction as int) * 256;')
        self.put('raw_fraction = (raw_fraction - ((raw_fraction as int) as fx)) * 256;')
        self.put('raw_bits = raw_bits + (raw_fraction as int);')

    def watch(self, slot: int):
        if self.types.get(slot) == 'float':
            self.raw_bits(f'local_{slot}')
            value = 'raw_bits'
        else:
            value = f'local_{slot}'
        self.put(f'set_global({64 + slot}, {value});')

    def angle(self, p: Param, dest: str):
        value = self.param(p)
        self.raw_bits(f'({value}) / {fixed(TAU)}')
        self.put(f'{dest} = raw_bits as angle;')

    def begin_instruction(self, n: int, label: bool = False):
        self.n = n
        i = self.ins[n]
        if label and n in self.targets:
            self.put(f'source_{n}:')
        addr = '?' if i.address is None else f'0x{i.address:x}'
        offset = '?' if i.offset is None else f'0x{i.offset:x}'
        self.put(f'// sourceoffset={offset} file={addr} line={i.line} ins_{i.op} time={i.time} rank=0x{i.rank:02x}')
        self.put(f'due = {i.time} - ($frame - clock_base);')
        self.put('if due > 0 { wait(due); }')

    def reset_clock(self):
        self.put(f'clock_base = $frame - ({self.param(self.ins[self.n].args[1])});')

    def condition(self, n: int) -> str:
        stack = self.stacks[n]
        value = self.stackvar(len(stack) - 1, stack[-1])
        if stack[-1] == 'float':
            value = f'({value} as int)'
        return f'{value} {"==" if self.ins[n].op == 13 else "!="} 0'

    def instruction(self, n: int, label: bool = False):
        if n not in self.stacks:
            return
        self.begin_instruction(n, label)
        if not self.active[n]:
            self.put('// Rank-masked instruction: time gate above still applies.')
            return
        i = self.ins[n]
        op, a = i.op, i.args
        depth = len(self.stacks[n])
        if op in (0, 40):
            return
        if op in (1, 10):
            self.put('set_global(19, 1);')
            self.put('return;')
        elif op in (12, 13, 14):
            if op != 12:
                self.put(f'if {self.condition(n)} {{')
                self.indent += 1
            self.reset_clock()
            self.put(f'goto source_{self.edges[n]};')
            if op != 12:
                self.indent -= 1
                self.put('}')
        elif op == 23:
            self.put(f'clock_base = clock_base + ({self.param(a[0])});')
        elif op in (42, 44):
            self.put(f'{self.stackvar(depth, "float" if op == 44 else "int")} = {self.param(a[0])};')
        elif op in (43, 45):
            slot = self.analysis.local(a[0])
            self.put(f'local_{slot} = {self.sv(depth - 1)};')
            self.watch(slot)
        elif 50 <= op <= 70:
            symbol = {50:'+',51:'+',52:'-',53:'-',54:'*',55:'*',56:'/',57:'/',58:'%',
                      59:'==',60:'==',61:'!=',62:'!=',63:'<',64:'<',65:'<=',66:'<=',
                      67:'>',68:'>',69:'>=',70:'>='}[op]
            kind = 'int' if op >= 59 else self.stacks[n][-1]
            dest = self.stackvar(depth - 2, kind)
            self.stack_vars.add((depth - 2, kind))
            self.put(f'{dest} = {self.sv(depth - 2)} {symbol} {self.sv(depth - 1)};')
        elif op in (71, 72, 83, 84):
            value = self.sv(depth - 1)
            if op in (71, 72):
                kind = 'int'
                expr = f'{value} == {"0fx" if op == 72 else "0"}'
            else:
                kind = self.stacks[n][-1]
                expr = f'-{value}'
            self.stack_vars.add((depth - 1, kind))
            self.put(f'{self.stackvar(depth - 1, kind)} = {expr};')
        elif op == 78:
            slot = self.analysis.local(a[0])
            self.put(f'{self.stackvar(depth, "int")} = local_{slot};')
            self.put(f'local_{slot} = local_{slot} - 1;')
            self.watch(slot)
        elif op in (535, 536):
            slot = self.analysis.local(a[0])
            self.put(f'local_{slot} = {self.param(a[1 + self.rank])};')
            self.watch(slot)
        else:
            self.gameplay(i)

    def gameplay(self, i):
        a, op = i.args, i.op
        sid = self.analysis.literal(a[0])
        if op == 600:
            self.put(f'sh_reset({sid});')
            self.put(f'sh_offset_abs({sid}, 0fx, 100fx);')
        elif op == 602:
            self.put(f'sh_sprite({sid}, 0, 0); // Demo appearance, not native geometry.')
        elif op == 607:
            self.put(f'sh_ring({sid}, 1);')
            self.put(f'sh_aim({sid}, {int(a[1].value == 2)});')
        elif op == 606:
            self.put(f'sh_count({sid}, {self.param(a[1])}, {self.param(a[2])});')
        elif op == 605:
            self.put(f'sh_speed({sid}, {self.param(a[1])}, 0fx);')
        elif op == 604:
            self.angle(a[1], 'angle_zero')
            self.angle(a[2], 'angle_step')
            self.put(f'sh_angle({sid}, angle_zero, angle_step);')
        elif op == 627:
            self.put(f'sh_dist({sid}, {self.param(a[1])});')
        elif op == 611:
            if a[2].value == 2:
                self.put('// DEMO: native EX2 birth state omitted; curve starts immediately.')
                return
            if any(p.ref or p.cast or p.kind != 'float' for p in a[5:7]):
                raise Unsupported('dynamic EX8 values cannot be expressed by target xformdef')
            acc, rad = fx(a[5].value), fx(a[6].value)
            bam = trunc_div(rad * 65536, TAU)
            name = f'SOURCE_EX8_{self.n}'
            angle = f'{bam}bam' if abs(bam) <= 65535 else f'({integer(bam)} as angle)'
            self.xforms[name] = (f'xformdef {name} {{\n    set_accel({fixed(acc)});\n'
                                f'    @{a[3].value} set_ang_vel({angle});\n    stop_fx();\n}}')
            self.put(f'sh_xform({sid}, {name});')
        elif op == 601:
            self.put(f'sh_fire({sid});')
            self.put('set_global(17, global(17) + 1);')
        else:
            raise Unsupported(f'opcode {op} has no source lowering')

    def plain(self, start: int, end: int, allowed: set[int] | None = None) -> bool:
        return not any(start <= n < end and n not in (allowed or set()) for n in self.edges)

    def closed(self, start: int, end: int) -> bool:
        """Only the first instruction may be entered from outside the region."""
        return not any(not start <= n < end and start < t < end for n, t in self.edges.items())

    def linear(self, start: int, end: int):
        for n in range(start, end):
            self.instruction(n)

    def count_bound(self, slot: int, preheader: int) -> int | None:
        # A linear prefix proves the initial bound, not a guessed runtime value.
        if not self.plain(0, preheader):
            return None
        bound = None
        for n in range(preheader):
            i = self.ins[n]
            if not self.active[n] or i.op not in (43, 45, 78, 535, 536):
                continue
            if self.analysis.local(i.args[0]) != slot:
                continue
            bound = None
            if i.op == 535:
                p = i.args[1 + self.rank]
                if not p.ref and p.kind == 'int':
                    bound = p.value
            elif i.op == 43 and n and self.ins[n - 1].op == 42 and self.active[n - 1]:
                p = self.ins[n - 1].args[0]
                if not p.ref and p.kind == 'int' and not self.ins[n - 1].stack_pop:
                    bound = p.value
        return bound if bound is not None and 0 <= bound < 2147483647 else None

    def recover_for(self, n: int) -> int | None:
        if self.ins[n].op != 12 or n not in self.edges:
            return None
        check = self.edges[n]
        end = check + 2
        if (check <= n + 1 or end > len(self.ins) or self.ins[check].op != 78
                or self.ins[check + 1].op != 14 or self.edges.get(check + 1) != n + 1
                or self.ins[check].stack_pop != 0 or any(t <= n for t in self.edges.values())
                or not self.active[check] or not self.closed(n, end)
                or not self.plain(n + 1, check)):
            return None
        slot = self.analysis.local(self.ins[check].args[0])
        bound = self.count_bound(slot, n)
        if bound is None:
            return None
        for k in range(n + 1, check):
            i = self.ins[k]
            if (self.active[k] and i.op in (43, 45, 78, 535, 536)
                    and self.analysis.local(i.args[0]) == slot):
                return None
        self.put('// Recovered for: literal nonnegative countdown, no body counter writes or interior entries.')
        self.begin_instruction(n, True)
        self.reset_clock()
        self.put(f'for iteration_{n} in 0..{bound} {{')
        self.indent += 1
        self.instruction(check)
        self.begin_instruction(check + 1)
        self.reset_clock()
        self.linear(n + 1, check)
        self.indent -= 1
        self.put('}')
        self.put('// Final failed check still decrements the source counter to -1.')
        self.instruction(check)
        self.begin_instruction(check + 1)
        return end

    def recover_while(self, start: int) -> int | None:
        # head: straight condition; conditional exit; straight body; goto head.
        for branch in range(start, len(self.ins)):
            if branch not in self.edges:
                continue
            end = self.edges[branch]
            tail = end - 1
            if (self.ins[branch].op not in (13, 14) or tail <= branch
                    or end > len(self.ins) or self.edges.get(tail) != start
                    or self.ins[tail].op != 12 or not self.closed(start, end)
                    or not self.plain(start, end, {branch, tail})):
                return None
            self.put('// Recovered while: straight condition/body, one back edge, no interior entries.')
            if start in self.targets:
                self.put(f'source_{start}:')
            self.linear(start, branch)
            self.begin_instruction(branch)
            self.put(f'while !({self.condition(branch)}) {{')
            self.indent += 1
            self.linear(branch + 1, tail)
            self.begin_instruction(tail)
            self.reset_clock()
            self.linear(start, branch)
            self.begin_instruction(branch)
            self.indent -= 1
            self.put('}')
            self.n = branch
            self.reset_clock()
            return end
        return None

    def recover_if(self, n: int) -> int | None:
        if self.ins[n].op not in (13, 14) or n not in self.edges:
            return None
        target = self.edges[n]
        if target <= n + 1:
            return None
        tail = target - 1
        end = self.edges.get(tail, target)
        has_else = (tail in self.edges and self.ins[tail].op == 12 and end > target)
        if not has_else:
            end = target
        if (not self.closed(n, end) or not self.plain(n + 1, end, {tail} if has_else else set())):
            return None
        self.put('// Recovered if: forward branch with closed straight arms.')
        self.begin_instruction(n, True)
        self.put(f'if !({self.condition(n)}) {{')
        self.indent += 1
        self.linear(n + 1, tail if has_else else target)
        if has_else:
            self.begin_instruction(tail)
            self.reset_clock()
        self.indent -= 1
        self.put('} else {')
        self.indent += 1
        self.n = n
        self.reset_clock()
        if has_else:
            self.linear(target, end)
        self.indent -= 1
        self.put('}')
        return end

    def build(self) -> str:
        n = 0
        while n < len(self.ins):
            end = None
            if self.structured and n in self.stacks:
                end = self.recover_for(n) or self.recover_while(n) or self.recover_if(n)
            if end is None:
                self.instruction(n, True)
                n += 1
            else:
                n = end
        if len(self.ins) in self.targets:
            self.put(f'source_{len(self.ins)}:')
        self.put('return;')
        prefix = [f'// TH18 sub {self.sub.name}; rank={self.rank}; prototype only.',
                  '// Float locals/stacks are Q16.16; int locals/stacks remain signed i32.',
                  '// clock = $frame - clock_base; gates precede rank filtering; source wait changes base only.',
                  '// Globals: 16=entry frame, 17=volleys, 19=explicit end, 64+slot=raw source local.',
                  '// Structure recovery is conservative; unrecognized CFG retains same-sub label/goto.',
                  '// Calls, async, clock freezing and variable clock rates are not imported.']
        prefix.extend('// APPROXIMATION: ' + note for note in self.notes)
        prefix.extend(self.xforms.values())
        prefix.append('sub main() {')
        for slot in range(self.analysis.nlocals):
            kind = 'fx' if self.types.get(slot) == 'float' else 'int'
            prefix.append(f'    var local_{slot}: {kind} = 0{"fx" if kind == "fx" else ""}; // source byte offset {4 * slot}')
        for depth, kind in sorted(self.stack_vars):
            ty = 'fx' if kind == 'float' else 'int'
            prefix.append(f'    var {self.stackvar(depth, kind)}: {ty} = 0{"fx" if ty == "fx" else ""};')
        prefix.extend(['    var clock_base: int = $frame;', '    var due: int = 0;',
                       '    var random_raw: int = 0;', '    var raw_bits: int = 0;',
                       '    var raw_fraction: fx = 0fx;', '    var angle_zero: angle = 0bam;',
                       '    var angle_step: angle = 0bam;', '    set_global(16, clock_base);'])
        return '\n'.join(prefix + self.lines + ['}', ''])


def emit_source(sub: Sub, rank: int, demo: bool = False, structured: bool = True) -> str:
    """Return target source; strict mode rejects known numerical/gameplay gaps."""
    return SourceEmitter(sub, rank, demo, structured).build()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('input', type=Path)
    p.add_argument('--sub', required=True)
    p.add_argument('--rank', type=int, choices=range(4), default=1)
    p.add_argument('--demo', action='store_true')
    p.add_argument('--no-structured', action='store_true')
    p.add_argument('--thecl', type=Path, default=THECL)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    if not args.output.resolve().is_relative_to(WORK.resolve()):
        p.error(f'write derived source only beneath gitignored {WORK}')
    try:
        subs, binary = decode(args.input, args.thecl)
        if args.sub not in subs:
            raise Unsupported(f'no sub named {args.sub}')
        source = emit_source(subs[args.sub], args.rank, args.demo, not args.no_structured)
        source = f'// Source SHA256: {hashlib.sha256(binary).hexdigest()}\n' + source
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(source)
    except (Unsupported, ValueError, subprocess.CalledProcessError) as exc:
        p.exit(2, f'UNSUPPORTED: {exc}\n')
    print(f'{args.sub} rank {args.rank}: wrote {args.output}')


if __name__ == '__main__':
    main()
