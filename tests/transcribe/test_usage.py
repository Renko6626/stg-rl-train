"""dsh 会话用量统计：步数 / 上下文增长 / 计费输入估算 / 输出与推理占比。"""
import json
import subprocess

import pytest

from stgtranscribe import usage


def _write_session(dirpath, rows):
    p = dirpath / "session.v3.jsonl.zstd"
    raw = "\n".join(json.dumps(r, ensure_ascii=False) for r in rows).encode()
    subprocess.run(["zstd", "-q", "-o", str(p)], input=raw, check=True)
    return p


def test_estimate_tokens_counts_cjk_by_char():
    assert usage.est_tokens("") == 0
    assert usage.est_tokens("弹幕") == 2
    assert usage.est_tokens("abcdefgh") == 2
    assert usage.est_tokens("弹" + "a" * 8) == 3


def test_session_stats_context_growth_and_reasoning(tmp_path):
    def msg(reason, text, args=None):
        c = [{"type": "reasoning", "text": reason}, {"type": "text", "text": text}]
        if args:
            c.append({"type": "tool-call", "id": "c1", "name": "read", "arguments": args})
        return {"type": "assistant/message", "data": {"message": {"role": "assistant", "content": c}}}

    rows = [
        {"type": "session", "version": 3, "cwd": "/x"},
        {"type": "agent/inbox/spliced", "data": {"inserted": [{"content": [{"type": "text", "text": "a" * 400}]}]}},
        msg("r" * 40, "t" * 40, '{"file_path": "/f"}'),
        {"type": "tool/call", "data": {"callId": "c1", "name": "read", "arguments": '{"file_path": "/f"}'}},
        {"type": "tool/result", "data": {"message": {"source": {"kind": "tool", "callId": "c1"},
                                                     "content": [{"type": "text", "text": "o" * 800}]}}},
        msg("r" * 80, "t" * 80),
    ]
    s = usage.session_stats(_write_session(tmp_path, rows))
    assert s["steps"] == 2
    # 第 1 步输入 = 100（brief）；第 1 步输出 = 推理 10 + 正文 10 + 工具参数 4 = 24；第 2 步输入 = 100 + 24 + 工具结果 200
    assert s["billed_in"] == 100 + (100 + 24 + 200)
    assert s["ctx_end"] == 100 + 24 + 200 + 40   # 第 2 步输出 = 推理 20 + 正文 20
    assert s["out"] == 24 + 40 and s["reasoning"] == 10 + 20
    assert s["tool_calls"] == {"read": 1}


def test_latest_session_for_cwd(tmp_path, monkeypatch):
    root = tmp_path / "sessions"
    d1 = root / "--x-y-units-th06_s1_w01--" / "session-old"
    d2 = root / "--x-y-units-th06_s1_w01--" / "session-new"
    for d in (d1, d2):
        d.mkdir(parents=True)
        _write_session(d, [{"type": "session", "version": 3, "cwd": "/x/y/units/th06_s1_w01"}])
    import os
    os.utime(d1 / "session.v3.jsonl.zstd", (10**9, 10**9))   # 把旧的那个时间戳调早
    monkeypatch.setattr(usage, "sessions_root", lambda: root)
    assert usage.latest_session("/x/y/units/th06_s1_w01") == d2 / "session.v3.jsonl.zstd"
    assert usage.latest_session("/nope") is None


def test_summarize_rows():
    rows = [{"kind": "transcribe", "steps": 10, "billed_in": 1_000_000, "out": 9000, "reasoning": 8000, "ctx_end": 50_000},
            {"kind": "transcribe", "steps": 20, "billed_in": 3_000_000, "out": 21000, "reasoning": 18000, "ctx_end": 90_000},
            {"kind": "review", "steps": 5, "billed_in": 500_000, "out": 5000, "reasoning": 4500, "ctx_end": 40_000}]
    t = usage.summarize(rows)
    assert t["transcribe"]["n"] == 2 and t["transcribe"]["steps"] == 30
    assert t["transcribe"]["billed_in"] == 4_000_000 and t["transcribe"]["reasoning_frac"] == pytest.approx(26 / 30)
    assert t["合计"]["billed_in"] == 4_500_000 and t["合计"]["n"] == 3


def test_builtins_cheatsheet_is_signatures_only(tmp_path):
    from stgtranscribe import extract

    src = tmp_path / "7-reference.md"
    src.write_text("# 标题\n\n段落说明很长很长。\n\n"
                   "- `fire(shape: int) -> int` — 发一颗弹;细节一大堆一大堆一大堆\n"
                   "- `wait(n: int)` — 等 n 帧\n"
                   "- 不是签名的条目\n", encoding="utf-8")
    out = extract.builtins_cheatsheet(src)
    assert "`fire(shape: int) -> int` — 发一颗弹" in out and "细节一大堆" not in out
    assert "`wait(n: int)` — 等 n 帧" in out
    assert "不是签名的条目" not in out and "段落说明" not in out
