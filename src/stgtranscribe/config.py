"""路径与配置：transcribe/th06/config.toml，关键路径可被环境变量覆盖。"""
from __future__ import annotations

import os
import tomllib
from functools import lru_cache
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TRANSCRIBE_DIR = REPO_ROOT / "transcribe"
TH06_DIR = TRANSCRIBE_DIR / "th06"
WORK_DIR = TRANSCRIBE_DIR / "work"
CONTRACTS_DIR = TRANSCRIBE_DIR / "contracts"
CARDS_DIR = REPO_ROOT / "cards"


@lru_cache(maxsize=1)
def th06_config() -> dict:
    return tomllib.loads((TH06_DIR / "config.toml").read_text(encoding="utf-8"))


def _path(env: str, key: str) -> Path:
    v = os.environ.get(env)
    return Path(v) if v else Path(th06_config()["paths"][key])


def decoded_dir() -> Path:
    """renkolab 的 th06nc 解码目录（含 ecl/ 与 text/）。"""
    return _path("STG_TH06_SRC", "decoded_dir")


def ecl_files() -> list[Path]:
    """7 个关卡 ECL 文本，按关卡号排序；目录缺失时返回空表（CI 上没有 ZUN 数据）。"""
    d = decoded_dir() / "ecl"
    if not d.is_dir():
        return []
    return sorted(d.glob("ecldata*.ecl.txt"))


def stage_file(stage: int) -> Path:
    return decoded_dir() / "ecl" / f"ecldata{stage}.ecl.txt"


def engine_dir() -> Path:
    """stg-engine 仓（worker 读文档、调 release harness）。"""
    return _path("STG_ENGINE_DIR", "engine_dir")


def harness_bin() -> Path:
    return engine_dir() / "target" / "release" / "stg-harness"


def decomp_dir() -> Path:
    """th06-decomp（CC0）源码目录，审核与对照表引用行号用。"""
    return _path("STG_TH06_DECOMP", "decomp_dir")
