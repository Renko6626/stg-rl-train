#!/usr/bin/env python3
"""Build TH18 graph7 / 2048 bullet inputs with diagnostic logging retained."""
import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import zipfile
import zlib

from build import verify_closure

BASE_SHA256 = "b63926db46c4cd1e09794de36e26c3fde1b2505276e795bf10c480ec81e5222e"
PREFIX = "TH18-AI/"
SOURCES = (
    "mods/_shared/stg-ai/native/plugin.c",
    "mods/_shared/stg-ai/README.md",
    "mods/th06nc/autoplay/native/policy_model.c",
    "mods/th06nc/autoplay/native/policy_model.h",
    "mods/th06nc/autoplay/native/policy.c",
    "mods/th06nc/autoplay/native/tests/test_policy_model.c",
    "mods/th06nc/autoplay/native/tests/test_policy.c",
    "mods/th16.v1.00a/autoplay/README.md",
    "mods/th18.v1.00a/autoplay/README.md",
    "mods/th18.v1.00a/autoplay/native/th18_extract.h",
    "mods/th18.v1.00a/autoplay/native/th18_extract.c",
    "mods/th18.v1.00a/autoplay/native/tests/test_extract.c",
    "mods/th18.v1.00a/autoplay/PROBE.md",
    "mods/th18.v1.00a/autoplay/TARGET.md",
    "mods/th18.v1.00a/autoplay/FIELD-NOTES.md",
    "mods/th18.v1.00a/autoplay/AUDIT.md",
)
PROTOCOL_SOURCES = (
    "c/world.h", "c/sa_model.h", "c/sa_model.c", "c/sa_onnx.h", "c/sa_onnx.c",
    "c/sa_motor.h", "c/sa_motor.c",
)
MODEL_PATH = "model/b-request-light-shift-k8-best.onnx"
CHECKPOINT_SHA256 = "8b3824871e18ca4a5fd052e758ef13833a0303d856513ebe58e6d604f0a19c88"
GUIDE = """TH18 AI 2048弹输入修正版 r5（保留诊断探针）

游戏快照与模型原始输入容量均为2048；适配层直接填表，不做额外排序。
只保留图内TopK：64颗逐弹编码，其余有效圆弹进入粗密度图。
保留直线／无限激光状态映射修复与冻结到期首帧保留。
AUTO 自由躲弹；BYPASS 横向跟随敌人，优先 Boss，没有 Boss 时跟随普通敌人。
同类目标按原有遍历顺序选择；没有可碰撞敌人时返回底部中央。
BYPASS 纵向站位仍为384，弹幕压力大时临时自由躲弹；按住鼠标左键仍优先引导。
包含此前的子弹链表入口修复，并保留日志。本版仍待 Windows 实机确认。
完整解压后双击 TH18-AI.exe，选择自己的原版游戏，进入关卡按 F10 切到 AUTO。
先松开方向键、Shift 和鼠标左键观察约 10 秒，再按住鼠标左键引导约 10 秒。
退出游戏后，将以下文件提供给开发者：
1. 游戏 th18.exe 旁的 stg-ai.log（主要诊断记录，搜索 [probe]）。
2. 本包 thcrap/logs/thcrap_log.txt（加载器记录）。

探针每秒最多输出一组详细记录。同一checkpoint权重重导出为图版本7，未重新训练。
包内仍使用旧模型文件名以兼容启动器，实际输入为2048行，以graph=7和manifest为准。
半径口径和手动接管规则沿用原版。
有激光时重点看 world 的 l 和 inputs masks_b/e/l 的第三项是否非零。
raw_laser.state 是原生状态，world/model 状态已转换为共享预警／有效状态。
日志区分原生链表、world 快照、实际模型输入，以及本帧未执行推理的情况。
默认仍为手动；自动炸弹关闭，C/D/X 保留手动。特殊形状仍按原暂定门交回手动。
本机只验证构建和日志逻辑，实际问题须依据 Windows 试玩记录判断。
详细字段见 source/mods/th18.v1.00a/autoplay/PROBE.md。
"""


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def build(args):
    raw = args.base.read_bytes()
    if sha(raw) != BASE_SHA256:
        raise ValueError("Probe requires the pinned r2 portable ZIP")
    with zipfile.ZipFile(args.base) as archive:
        if archive.testzip() is not None:
            raise ValueError("Base ZIP CRC failed")
        files = {name[len(PREFIX):]: archive.read(name) for name in archive.namelist()
                 if name.startswith(PREFIX) and not name.endswith("/")}
    files.pop("SHA256SUMS")
    files["thcrap/bin/stg_ai.dll"] = args.dll.read_bytes()
    model = args.model.read_bytes()
    manifest = json.loads(args.manifest.read_bytes())
    expected_inputs = [
        {"name": "bullets", "dtype": "float32", "shape": [2048, 5]},
        {"name": "bullets_mask", "dtype": "bool", "shape": [2048]},
    ]
    if (manifest.get("graph_version") != 7 or manifest.get("inputs", [])[:2] != expected_inputs
            or manifest.get("sha256", {}).get("onnx") != sha(model)
            or manifest.get("sha256", {}).get("checkpoint") != CHECKPOINT_SHA256):
        raise ValueError("Requires graph7 / 2048 model from the pinned B/Shift checkpoint")
    files[MODEL_PATH] = model
    manifest["onnx"] = Path(MODEL_PATH).name
    files[MODEL_PATH.removesuffix(".onnx") + ".manifest.json"] = encoded(manifest)
    for name in SOURCES:
        files["source/" + name] = (args.source / name).read_bytes()
    for name in PROTOCOL_SOURCES:
        files["source/stg-agent-proto/" + name] = (args.protocol_source / name).read_bytes()
    files["source/stgtrain/export_onnx.py"] = args.export_source.read_bytes()
    files["source/build_probe.py"] = Path(__file__).read_bytes()
    patch_root = "thcrap/patches/stg-ai-th18/"
    patch = json.loads(files[patch_root + "th18.v1.00a.js"])
    patch["breakpoints"]["stg_ai_tick"]["probe"] = 1
    files[patch_root + "th18.v1.00a.js"] = encoded(patch)
    metadata = {name[len(patch_root):]: zlib.crc32(data) for name, data in files.items()
                if name.startswith(patch_root) and name != patch_root + "files.js"}
    files[patch_root + "files.js"] = encoded(metadata)
    for name in ("th18.v1.00a.js", "files.js"):
        files["source/mods/th18.v1.00a/autoplay/patch/" + name] = files[patch_root + name]
    files["诊断说明.txt"] = GUIDE.encode("utf-8-sig")
    files["使用说明.txt"] = GUIDE.encode("utf-8-sig") + b"\r\n" + files["使用说明.txt"].removeprefix(b"\xef\xbb\xbf")
    with tempfile.TemporaryDirectory(prefix="th18-probe-check-") as temporary:
        root = Path(temporary)
        for name, data in files.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        closure = verify_closure(root)
    provenance = json.loads(files["provenance.json"])
    provenance["diagnostic"] = {
        "enabled": True, "interval_ms": 1000, "base_zip_sha256": BASE_SHA256,
        "purpose": "2048 raw bullet rows without adapter sorting; laser normalization and thaw-ready coverage retained",
        "variant": "capacity2048-graph7-r5",
        "sources_sha256": {name: sha(files["source/" + name]) for name in SOURCES},
    }
    provenance["model"] = {
        "path": MODEL_PATH, "sha256": sha(model), "graph_version": 7,
        "bullet_rows": 2048, "checkpoint_sha256": CHECKPOINT_SHA256,
        "source_manifest": args.manifest.name,
    }
    provenance["protocol_sources_sha256"] = {
        name: sha(files["source/stg-agent-proto/" + name]) for name in PROTOCOL_SOURCES
    }
    provenance["export_source_sha256"] = sha(files["source/stgtrain/export_onnx.py"])
    provenance["binaries_sha256"] = {name: sha(files[name]) for name in closure}
    provenance["x86_imports"] = closure
    files["provenance.json"] = encoded(provenance)
    files["SHA256SUMS"] = "".join(f"{sha(data)}  {name}\n" for name, data in sorted(files.items())).encode("utf-8")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(files.items()):
            entry = zipfile.ZipInfo(PREFIX + name, (2026, 10, 22, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, data)
        directory = zipfile.ZipInfo(PREFIX + "thcrap/logs/", (2026, 10, 22, 0, 0, 0))
        directory.external_attr = (0o40755 << 16) | 0x10
        archive.writestr(directory, b"")
    with zipfile.ZipFile(args.output) as archive:
        if archive.testzip() is not None:
            raise ValueError("Probe ZIP CRC failed")
        for name, data in files.items():
            if archive.read(PREFIX + name) != data:
                raise ValueError(f"Probe ZIP content mismatch: {name}")
    digest = sha(args.output.read_bytes())
    args.output.with_suffix(args.output.suffix + ".sha256").write_text(
        f"{digest}  {args.output.name}\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output), "bytes": args.output.stat().st_size,
                      "sha256": digest, "files": len(files), "x86_binaries": len(closure)}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, type=Path)
    parser.add_argument("--dll", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--protocol-source", required=True, type=Path)
    parser.add_argument("--export-source", required=True, type=Path)
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    build(parser.parse_args())
