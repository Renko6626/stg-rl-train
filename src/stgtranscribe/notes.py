"""worker 的「疑似普遍问题」便笺。

转写 / 审核 worker 撞上**可能影响其它单元**的问题时（对照表写错、引擎缺机制、契约没讲清），
写一条便笺到 `notes.md`，由主会话分诊：值得就改对照表 / 契约 / 记 follow-ups，不值得就标记掉。

没有这条通道时，这类问题只能等事后抽检才浮上来——1–3 关那批的
「§4.3 停火守卫写反」「TH06 640 弹池」「出生特效降速」都是撞了一次却影响全池的例子。

格式（Markdown，一条一个二级标题）：

    ## 一句话标题
    影响面：只此单元 | 疑似同关 | 疑似全池
    证据：文件:行 / 命令 + 实测输出
    建议：改对照表 §X / 改契约 / 引擎侧 / 只是提醒
"""
from __future__ import annotations

import re
from pathlib import Path

SCOPES = ("疑似全池", "疑似同关", "只此单元")
TRIAGED = "notes-triaged.txt"


def _parse(text: str) -> list[dict]:
    out: list[dict] = []
    for block in re.split(r"^##\s+", text, flags=re.M)[1:]:
        lines = block.splitlines()
        title = lines[0].strip()
        body = "\n".join(lines[1:]).strip()
        scope = next((s for s in SCOPES if re.search(rf"影响面[：:]\s*{s}", body)), "未标注")
        if title:
            out.append({"title": title, "scope": scope, "body": body})
    return out


def collect(work_dir: Path) -> list[dict]:
    """扫 `units/<id>/out/notes.md`（转写）与 `review/<id>/notes.md`（审核）。"""
    work_dir = Path(work_dir)
    found: list[dict] = []
    for kind, pattern in (("transcribe", "units/*/out/notes.md"), ("review", "review/*/notes.md")):
        for p in sorted(work_dir.glob(pattern)):
            uid = p.parent.parent.name if kind == "transcribe" else p.parent.name
            for n in _parse(p.read_text(encoding="utf-8")):
                found.append({"id": uid, "kind": kind, "path": str(p), **n})
    return found


def key(note: dict) -> str:
    return f"{note['id']}\t{note['kind']}\t{note['title']}"


def _triaged_path(work_dir: Path) -> Path:
    return Path(work_dir) / TRIAGED


def new_only(all_notes: list[dict], work_dir: Path) -> list[dict]:
    p = _triaged_path(work_dir)
    done = set(p.read_text(encoding="utf-8").splitlines()) if p.exists() else set()
    return [n for n in all_notes if key(n) not in done]


def mark_triaged(notes_: list[dict], work_dir: Path) -> None:
    p = _triaged_path(work_dir)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as f:
        for n in notes_:
            f.write(key(n) + "\n")


def render(notes_: list[dict]) -> str:
    order = {s: i for i, s in enumerate(SCOPES)}
    lines: list[str] = []
    for scope in sorted({n["scope"] for n in notes_}, key=lambda s: order.get(s, 99)):
        group = [n for n in notes_ if n["scope"] == scope]
        lines.append(f"── {scope}（{len(group)} 条）" + "─" * 40)
        for n in group:
            lines.append(f"  [{n['kind']}] {n['id']}：{n['title']}")
            for ln in n["body"].splitlines():
                if ln.strip() and not ln.startswith("影响面"):
                    lines.append(f"      {ln.strip()}")
    return "\n".join(lines)
