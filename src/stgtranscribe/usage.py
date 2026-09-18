"""dsh worker 的用量账：从 `~/.dsh/sessions` 的会话记录复原步数、上下文增长与计费估算。

dsh **不记录官方 token 用量**，这里按内容估：token ≈ CJK 字符数 + 其余字符数 / 4。

计费的大头是**输入**：每个 step 是一次 API 调用，输入 = 到那一步为止的全部内容，
所以 `billed_in ≈ Σ_k ctx_k`，随步数二次增长（步数翻倍 ≈ 账单四倍）。
`out` 是输出侧（正文 + 推理 + 工具参数），其中 `reasoning` 单列——`reasoningEffort` 调低先省这一块。

只用于横向比较与找浪费点，不等于账单。
"""
from __future__ import annotations

import collections
import json
import subprocess
from pathlib import Path

PHASES = ("split", "transcribe", "review")


def est_tokens(s: str) -> int:
    """CJK 一字一 token，其余按 4 字符 1 token。"""
    if not s:
        return 0
    cjk = sum(1 for ch in s if "　" <= ch <= "鿿" or "＀" <= ch <= "￯")
    return cjk + (len(s) - cjk) // 4


def sessions_root() -> Path:
    return Path.home() / ".dsh" / "sessions"


def latest_session(cwd: str | Path) -> Path | None:
    """dsh 把会话按 cwd 路径（斜杠换成 `-`）分目录；同一 cwd 可能跑过多次，取最新的一次。"""
    key = "--" + str(cwd).strip("/").replace("/", "-") + "--"
    d = sessions_root() / key
    if not d.is_dir():
        return None
    files = sorted(d.glob("session-*/session.v3.jsonl.zstd"), key=lambda p: p.stat().st_mtime)
    return files[-1] if files else None


def _rows(path: Path):
    out = subprocess.run(["zstd", "-dc", str(path)], capture_output=True, text=True).stdout
    for line in out.splitlines():
        if line.strip():
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                pass


def _text(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for x in content:
            if not isinstance(x, dict):
                continue
            v = x.get("text")
            if isinstance(v, str):
                parts.append(v)
            elif isinstance(x.get("content"), (str, list)):
                parts.append(_text(x["content"]))
        return "\n".join(parts)
    return ""


def session_stats(path: Path) -> dict:
    """一次 worker 会话的账：步数、计费输入估算、末尾上下文、输出与其中的推理、工具调用次数。"""
    ctx = 0
    billed = out = reasoning = steps = 0
    tools: collections.Counter[str] = collections.Counter()
    for d in _rows(Path(path)):
        kind, data = d.get("type"), d.get("data", {})
        if kind == "agent/inbox/spliced":
            for m in data.get("inserted", []):
                ctx += est_tokens(_text(m.get("content")))
        elif kind == "assistant/message":
            steps += 1
            billed += ctx                      # 这一步的输入 = 之前累计的全部内容
            n = 0
            for part in data.get("message", {}).get("content", []):
                if not isinstance(part, dict):
                    continue
                t = part.get("type")
                if t == "reasoning":
                    k = est_tokens(part.get("text", ""))
                    reasoning += k
                    n += k
                elif t == "text":
                    n += est_tokens(part.get("text", ""))
                elif t == "tool-call":
                    n += est_tokens(str(part.get("arguments", "")))
            out += n
            ctx += n
        elif kind == "tool/call":
            tools[data.get("name") or "?"] += 1
        elif kind == "tool/result":
            ctx += est_tokens(_text(data.get("message", {}).get("content")))
    return {"steps": steps, "billed_in": billed, "ctx_end": ctx, "out": out,
            "reasoning": reasoning, "tool_calls": dict(tools)}


def stats_for_cwd(cwd: str | Path) -> dict | None:
    p = latest_session(cwd)
    return session_stats(p) if p else None


def summarize(rows: list[dict]) -> dict[str, dict]:
    """按 `kind` 汇总，外加「合计」。rows = state.jsonl 里带 usage 的记录。"""
    agg: dict[str, dict] = {}
    for r in rows + [{**r, "kind": "合计"} for r in rows]:
        a = agg.setdefault(r.get("kind", "?"), {"n": 0, "steps": 0, "billed_in": 0, "out": 0,
                                                "reasoning": 0, "ctx_end": 0})
        a["n"] += 1
        for k in ("steps", "billed_in", "out", "reasoning", "ctx_end"):
            a[k] += int(r.get(k, 0))
    for a in agg.values():
        a["reasoning_frac"] = a["reasoning"] / a["out"] if a["out"] else 0.0
        a["ctx_end_avg"] = a["ctx_end"] / a["n"] if a["n"] else 0
        a["steps_avg"] = a["steps"] / a["n"] if a["n"] else 0
    return agg


def render(agg: dict[str, dict]) -> str:
    head = f"{'阶段':10}{'会话':>5}{'步数':>7}{'均步':>7}{'计费输入':>12}{'输出':>10}{'推理占比':>9}{'末上下文均值':>13}"
    lines = [head]
    for k in list(PHASES) + ["合计"]:
        if k not in agg:
            continue
        a = agg[k]
        lines.append(f"{k:10}{a['n']:5}{a['steps']:7}{a['steps_avg']:7.1f}{a['billed_in'] / 1e6:11.2f}M"
                     f"{a['out'] / 1e6:9.2f}M{a['reasoning_frac'] * 100:8.0f}%{a['ctx_end_avg'] / 1000:12.0f}k")
    return "\n".join(lines)
