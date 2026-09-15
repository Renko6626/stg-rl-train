"""对照表的两道闸门（spec §6）：覆盖率（需本地原文）+ 片段编译（CI 必跑）。"""
import re

import pytest
import stg_rl

from stgtranscribe import config
from stgtranscribe.mapping import DISPOSITIONS, load_index, sections
from stgtranscribe.thecl import parse_file

MAPPING = config.TH06_DIR / "mapping.md"
EXAMPLES = config.TH06_DIR / "examples"


def ecl_fences(text: str) -> list[str]:
    return re.findall(r"^```ecl\n(.*?)^```", text, flags=re.S | re.M)


def test_index_is_well_formed():
    idx = load_index(MAPPING.read_text(encoding="utf-8"))
    assert len(idx) >= 120
    heads = sections(MAPPING.read_text(encoding="utf-8"))
    for name, (disp, sec) in idx.items():
        assert disp in DISPOSITIONS, name
        assert sec in heads, f"{name} 指向不存在的节 {sec}"


def test_every_ecl_fence_compiles():
    fences = ecl_fences(MAPPING.read_text(encoding="utf-8"))
    assert len(fences) >= 8, "围栏扫描是否失效？"
    for n, src in enumerate(fences):
        try:
            stg_rl.compile_sources([("mapping.ecl", src)])
        except stg_rl.CompileError as e:
            pytest.fail(f"mapping.md 第 {n} 个 ecl 围栏编译失败:\n{e}\n---\n{src}")


def test_examples_compile():
    dirs = sorted(p for p in EXAMPLES.iterdir() if p.is_dir()) if EXAMPLES.is_dir() else []
    for d in dirs:
        stg_rl.compile_dir(d)


@pytest.mark.skipif(not config.ecl_files(), reason="本地没有 th06nc 解码原文")
def test_every_used_instruction_has_an_entry():
    idx = load_index(MAPPING.read_text(encoding="utf-8"))
    used = set()
    for f in config.ecl_files():
        e = parse_file(f)
        for b in [*e.subs.values(), *e.timelines.values()]:
            used.update(i.name for i in b.instrs)
    missing = sorted(used - set(idx))
    assert not missing, f"mapping.md 索引缺条目: {missing}"
