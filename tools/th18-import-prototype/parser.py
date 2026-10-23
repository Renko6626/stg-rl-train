"""Strict, stdlib-only reader for unmapped ``thecl -r -x -d18`` output.

This reads raw operands, not thecl's reconstructed expressions. Labels point to
instruction indexes; anim/ecli dependency lists are validated but not returned.
Use thecl's additional ``-j`` flag and decode UTF-8: decoding its escaped CP932
bytes directly can corrupt strings containing a CP932 trail byte of 0x5c.
Binary attachment is optional, but required for stack consumption metadata.
"""

from dataclasses import dataclass
import json
import re
import struct
from typing import Any


@dataclass
class Param:
    kind: str
    value: Any
    ref: bool = False
    cast: str | None = None  # Target type of thecl's _ff/_SS/_fS/_Sf prefix.


@dataclass
class Instruction:
    op: int
    args: list[Param]
    time: int
    rank: int
    line: int
    address: int | None
    offset: int | None
    stack_pop: int | None = None  # Number of entries, not bytes.


@dataclass
class Sub:
    name: str
    instructions: list[Instruction]
    labels: dict[str, int]


class ParseError(ValueError):
    def __init__(self, line: int, message: str):
        self.line = line
        super().__init__(f"line {line}: {message}")


_TOKEN = re.compile(
    r'(?P<space>\s+)|(?P<comment>//[^\n]*|/\*[\s\S]*?\*/)'
    r'|(?P<string>"(?:[^"\\\n]|\\[^\n])*")'
    r'|(?P<number>[+-]?(?:0[xX][0-9a-fA-F]+|(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?[fF]?))'
    r'|(?P<name>[A-Za-z_][A-Za-z_0-9]*)|(?P<rank>![*\-ENHLXO67]+)'
    r'|(?P<symbol>[{}()\[\],;:])'
)
_ADDRESS = re.compile(r'/\*\s*([0-9a-fA-F]+)\s*\(\+\s*([0-9a-fA-F]+)\)\s*\*/')


def _tokens(text: str) -> list[tuple[str, str, int]]:
    result = []
    pos, line = 0, 1
    while pos < len(text):
        match = _TOKEN.match(text, pos)
        if match is None:
            raise ParseError(line, f"unknown syntax {text[pos:pos + 32]!r}")
        kind, value = match.lastgroup, match.group()
        if kind == 'comment' and _ADDRESS.fullmatch(value):
            result.append(('address', value, line))
        elif kind not in ('space', 'comment'):
            result.append((kind, value, line))
        line += value.count('\n')
        pos = match.end()
    result.append(('eof', '', line))
    return result


class _Reader:
    def __init__(self, text: str):
        self.tokens = _tokens(text)
        self.index = 0

    @property
    def token(self) -> tuple[str, str, int]:
        return self.tokens[self.index]

    def take(self) -> tuple[str, str, int]:
        token = self.token
        self.index += 1
        return token

    def expect(self, value: str) -> None:
        if self.token[1] != value:
            raise ParseError(self.token[2], f"expected {value!r}, got {self.token[1]!r}")
        self.take()

    def name(self) -> str:
        if self.token[0] != 'name':
            raise ParseError(self.token[2], "expected identifier")
        return self.take()[1]

    def param(self) -> Param:
        kind, value, line = self.take()
        if kind == 'name' and value in ('_ff', '_SS', '_fS', '_Sf'):
            param = self.param()
            source = 'float' if value[2] == 'f' else 'int'
            if param.kind != source or param.cast is not None:
                raise ParseError(line, f"operand does not match {value}")
            param.cast = 'float' if value[1] == 'f' else 'int'
            return param
        if value in ('(', '['):
            param = self.param()
            self.expect(')' if value == '(' else ']')
            if value == '[':
                if param.kind not in ('int', 'float') or param.ref or param.cast:
                    raise ParseError(line, "reference must contain a numeric operand")
                param.ref = True
            return param
        if kind == 'number':
            if re.fullmatch(r'[+-]?(?:0[xX][0-9a-fA-F]+|\d+)', value):
                base = 16 if 'x' in value.lower() else 10
                return Param('int', int(value, base))
            return Param('float', float(value.rstrip('fF')))
        if kind == 'string':
            try:
                return Param('string', json.loads(value))
            except ValueError as exc:
                raise ParseError(line, f"invalid string escape: {exc}") from exc
        if kind == 'name':
            return Param('label', value)
        raise ParseError(line, f"expected raw operand, got {value!r}")

    def sub(self) -> Sub:
        name = self.name()
        self.expect('(')
        self.expect(')')
        self.expect('{')
        sub = Sub(name, [], {})
        time, rank = 0, 0xff
        while self.token[1] != '}':
            kind, value, line = self.token
            if kind == 'eof':
                raise ParseError(line, f"unclosed sub {name}")
            if kind == 'rank':
                self.take()
                flags = value[1:]
                if flags == '*':
                    rank = 0xff
                elif flags == '-':
                    rank = 0xc0
                else:
                    if '*' in flags or '-' in flags or len(set(flags)) != len(flags):
                        raise ParseError(line, f"invalid TH18 rank {value}")
                    rank = 0xc0
                    for flag in flags:
                        if flag in '67':
                            rank &= ~(1 << int(flag))
                        else:
                            rank |= 1 << 'ENHLXO'.index(flag)
                continue
            if kind == 'number':
                self.take()
                if not re.fullmatch(r'[+-]?\d+', value):
                    raise ParseError(line, "time must be an integer")
                self.expect(':')
                time = ((time + int(value)) if value.startswith('+') else int(value)) & 0xffffffff
                continue
            address = offset = None
            if kind == 'address':
                self.take()
                match = _ADDRESS.fullmatch(value)
                address, offset = (int(part, 16) for part in match.groups())
                kind, value, line = self.token
            if kind != 'name':
                raise ParseError(line, f"expected instruction or label, got {value!r}")
            self.take()
            if self.token[1] == ':' and address is None:
                self.take()
                if value in sub.labels:
                    raise ParseError(line, f"duplicate label {value}")
                sub.labels[value] = len(sub.instructions)
                continue
            if not re.fullmatch(r'ins_\d+', value):
                raise ParseError(line, f"expected raw ins_N instruction, got {value!r}")
            self.expect('(')
            args = []
            if self.token[1] != ')':
                args.append(self.param())
                while self.token[1] == ',':
                    self.take()
                    args.append(self.param())
            self.expect(')')
            self.expect(';')
            sub.instructions.append(Instruction(int(value[4:]), args, time, rank, line, address, offset))
        self.expect('}')
        for instruction in sub.instructions:
            for param in instruction.args:
                if param.kind == 'label' and param.value not in sub.labels:
                    raise ParseError(instruction.line, f"undefined label {param.value}")
        return sub


def parse(text: str, binary: bytes | None = None) -> dict[str, Sub]:
    """Parse raw text; optionally attach stack-pop counts from its ECL binary."""
    reader = _Reader(text)
    subs = {}
    while reader.token[0] != 'eof':
        _, value, line = reader.token
        if value in ('anim', 'ecli'):
            reader.take()
            reader.expect('{')
            while reader.token[1] != '}':
                if reader.token[0] != 'string':
                    raise ParseError(reader.token[2], "expected dependency filename string")
                reader.param()
                reader.expect(';')
            reader.expect('}')
        elif value == 'void':
            reader.take()
            sub = reader.sub()
            if sub.name in subs:
                raise ParseError(line, f"duplicate sub {sub.name}")
            subs[sub.name] = sub
        else:
            raise ParseError(line, f"expected sub or dependency list, got {value!r}")
    if binary is not None:
        attach_binary(subs, binary)
    return subs


def attach_binary(subs: dict[str, Sub], binary: bytes) -> None:
    """Check instruction headers and attach TH18 stack-pop entry counts."""
    for sub in subs.values():
        for instruction in sub.instructions:
            address = instruction.address
            if address is None or address < 0 or address + 16 > len(binary):
                raise ParseError(instruction.line, "missing or out-of-range binary address")
            time, op, size, mask, rank, argc, pop_bytes = struct.unpack_from('<IHHHBBI', binary, address)
            # TH18 0x48d232 loads the low BYTE at +0xc, not the whole word.
            pop_bytes &= 0xff
            if (op, time, rank, argc) != (instruction.op, instruction.time, instruction.rank, len(instruction.args)):
                raise ParseError(instruction.line, "raw text and binary instruction header differ")
            if size < 16 or address + size > len(binary):
                raise ParseError(instruction.line, "invalid binary instruction size")
            if pop_bytes % 8:
                raise ParseError(instruction.line, "binary stack-pop byte count is not divisible by 8")
            instruction.stack_pop = pop_bytes // 8
