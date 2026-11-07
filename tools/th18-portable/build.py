#!/usr/bin/env python3
"""Build the frozen, offline TH18 AI bundle from verified local inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import zipfile
import zlib


HERE = Path(__file__).resolve().parent
VC_DLLS = {
    "concrt140.dll", "msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll",
    "msvcp140_atomic_wait.dll", "msvcp140_codecvt_ids.dll", "vcamp140.dll",
    "vccorlib140.dll", "vcomp140.dll", "vcruntime140.dll", "vcruntime140_threads.dll",
}
THCRAP_DLLS = {"thcrap_loader.exe", "thcrap.dll", "jansson.dll", "win32_utf8.dll", "zlib-ng.dll"}
# Windows 10/11 components, including the UCRT API sets. DXCore needs modern Windows 10.
SYSTEM_DLLS = {
    "advapi32.dll", "bcrypt.dll", "comdlg32.dll", "d3d11.dll", "d3dcompiler_47.dll", "dbghelp.dll", "dxcore.dll",
    "dsound.dll", "dxgi.dll", "gdi32.dll", "imm32.dll", "kernel32.dll", "msvcrt.dll", "ntdll.dll",
    "ole32.dll", "oleaut32.dll", "psapi.dll", "rpcrt4.dll", "setupapi.dll",
    "shell32.dll", "shlwapi.dll", "user32.dll", "version.dll", "wininet.dll", "winmm.dll",
}
INSTRUCTIONS = """TH18 AI 启动包

1. 将整个 TH18-AI 文件夹解压到可写的短路径，例如 D:\\TH18-AI。
2. 双击 TH18-AI.exe，首次选择自己已有的 TH18 v1.00a 原版游戏程序（通常是 th18.exe）。
3. 进入游戏后按 F10 切换模式。以后直接双击 TH18-AI.exe 即可。

默认是 MANUAL（手动），F10 依次切换 MANUAL / AUTO / BYPASS。
AUTO 自由躲弹，按住鼠标左键可引导；BYPASS 使用现有跟点控制。
方向键或 Shift 手动输入优先。C、D、X 始终由玩家手动操作；自动炸弹安全网关闭。
遇到矩形弹等当前未支持的形状时暂时交回手动，最终处理方案待确认。
AI 接管时生成的游戏录像不能保证正确回放，请不要依赖录像复现 AI 操作。

请使用 Windows 10 22H2 或 Windows 11。包内包含 AI、模型、加载器和所需的
非系统运行库，不需要安装 Python、开发工具或系统运行库，也不需要管理员权限或联网。
游戏文件须自行准备。本包只支持清单中精确匹配的 v1.00a 原版程序。
本次仅完成主机构建和静态检查，尚未做 Windows 双击、游戏注入或 AI 效果实机验收。

请完整解压，不要在 ZIP 内直接运行；文件夹须允许当前用户写入。
中文和空格路径可用，但过深的中文目录可能超过现有适配器的 256 UTF-8 字节限制；
遇到路径提示，请移到磁盘根目录附近。游戏目录也应使用较短路径。
需要重新选择游戏时，删除本文件夹内 game-path.txt，或将 th18.exe 拖到 TH18-AI.exe 上。
启动器会在本包内保存 game-path.txt 和 thcrap/config/ai.js。
不会覆盖游戏程序或素材；现有 AI 插件会在游戏目录写入或追加 stg-ai.log。
启动错误可查看 thcrap/logs/thcrap_log.txt，并保留游戏目录的 stg-ai.log 反馈问题。

依赖来源和哈希见 provenance.json，逐文件校验见 SHA256SUMS，许可见 licenses/。
适配器源码、审阅和已知限制见 source/。本包禁用 thcrap 在线更新。
"""


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def put(root, name, data):
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def extract_cab(source, destination, pattern):
    destination.mkdir(parents=True, exist_ok=True)
    subprocess.run(["cabextract", "-q", "-F", pattern, "-d", str(destination), str(source)], check=True)


def pe_imports(path):
    """Read ordinary and delay import names; reject any non-x86 PE input."""
    data = path.read_bytes()
    pe = struct.unpack_from("<I", data, 0x3c)[0]
    if data[:2] != b"MZ" or data[pe:pe + 4] != b"PE\0\0":
        raise ValueError(f"Not PE: {path}")
    machine, sections = struct.unpack_from("<HH", data, pe + 4)
    size = struct.unpack_from("<H", data, pe + 20)[0]
    optional = pe + 24
    if machine != 0x14c or struct.unpack_from("<H", data, optional)[0] != 0x10b:
        raise ValueError(f"Not x86 PE32: {path}")
    image_base = struct.unpack_from("<I", data, optional + 28)[0]
    table = optional + size

    def offset(rva):
        for i in range(sections):
            virtual_size, virtual, raw_size, raw = struct.unpack_from("<IIII", data, table + i * 40 + 8)
            if virtual <= rva < virtual + max(virtual_size, raw_size):
                return raw + rva - virtual
        raise ValueError(f"Unmapped RVA {rva:x}: {path}")

    imports = set()
    for directory, stride, name_index in ((1, 20, 3), (13, 32, 1)):
        rva, length = struct.unpack_from("<II", data, optional + 96 + directory * 8)
        if not rva or not length:
            continue
        start = offset(rva)
        for entry in range(start, start + length, stride):
            fields = struct.unpack_from("<" + "I" * (stride // 4), data, entry)
            if not any(fields):
                break
            name_rva = fields[name_index]
            if directory == 13 and not fields[0] & 1:
                name_rva -= image_base
            at = offset(name_rva)
            imports.add(data[at:data.index(b"\0", at)].decode("ascii").lower())
    return sorted(imports)


def verify_closure(root):
    binaries = sorted(p for p in root.rglob("*") if p.suffix.lower() in {".dll", ".exe"})
    bundled = {p.name.lower() for p in binaries}
    closure = {}
    for binary in binaries:
        imports = pe_imports(binary)
        missing = [name for name in imports if name not in bundled and name not in SYSTEM_DLLS
                   and not name.startswith(("api-ms-win-", "ext-ms-win-"))]
        if missing:
            raise ValueError(f"Unresolved imports in {binary.name}: {missing}")
        closure[binary.relative_to(root).as_posix()] = imports
    return closure


def build(args):
    lock_bytes = (HERE / "dependencies.json").read_bytes()
    lock = json.loads(lock_bytes)
    # Verify every official archive and license before extracting or using any of them.
    for name, record in lock["inputs"].items():
        if sha((args.cache / name).read_bytes()) != record["sha256"]:
            raise ValueError(f"Input SHA256 mismatch: {name}")
    adapter_bytes = args.adapter.read_bytes()
    if sha(adapter_bytes) != lock["adapter"]["sha256"]:
        raise ValueError("Adapter ZIP SHA256 mismatch")
    launcher_bytes = args.launcher.read_bytes()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="th18-portable-") as temporary:
        work = Path(temporary)
        root = work / "TH18-AI"
        root.mkdir()
        put(root, "TH18-AI.exe", launcher_bytes)
        with zipfile.ZipFile(args.cache / "thcrap-2026-09-04.zip") as vendor:
            for name in sorted(THCRAP_DLLS):
                put(root, f"thcrap/bin/{name}", vendor.read(f"bin/{name}"))
        with zipfile.ZipFile(args.adapter) as adapter:
            put(root, "model/b-request-light-shift-k8-best.onnx",
                adapter.read("game_files/b-request-light-shift-k8-best.onnx"))
            for name in ("onnxruntime.dll", "onnxruntime_providers_shared.dll"):
                put(root, f"runtime/{name}", adapter.read(f"game_files/{name}"))
            put(root, "thcrap/bin/stg_ai.dll", adapter.read("thcrap/bin/stg_ai.dll"))
            for name in ("patch.js", "th18.v1.00a.js"):
                put(root, f"thcrap/patches/stg-ai-th18/{name}",
                    adapter.read(f"thcrap/patches/stg-ai-th18/{name}"))
            for name in adapter.namelist():
                if not name.endswith("/") and name.startswith(("source/", "licenses/")):
                    if ".." in Path(name).parts:
                        raise ValueError(f"Unsafe adapter path: {name}")
                    put(root, name, adapter.read(name))
            for name in ("BUILD-SOURCES.json", "INDEPENDENT-REVIEW.md", "VALIDATION.md", "README.txt"):
                put(root, f"source/adapter/{name}", adapter.read(name))
        extract_cab(args.cache / "vc_redist.x86.exe", work / "vc", "a2")
        extract_cab(work / "vc/a2", work / "vc-core", "*.dll_x86")
        vc_files = {p.name.removesuffix("_x86"): p for p in (work / "vc-core").iterdir()}
        if set(vc_files) != VC_DLLS:
            raise ValueError(f"Unexpected VC minimum DLL set: {sorted(vc_files)}")
        for name, path in vc_files.items():
            put(root, f"runtime/{name}", path.read_bytes())
        for cab, name in (("Jun2010_d3dx9_43_x86.cab", "d3dx9_43.dll"),
                          ("APR2007_xinput_x86.cab", "xinput1_3.dll")):
            extract_cab(args.cache / "directx_Jun2010_redist.exe", work / "dx-cabs", cab)
            extract_cab(work / "dx-cabs" / cab, work / "dx", name)
            put(root, f"runtime/{name}", (work / "dx" / name).read_bytes())
        for name in lock["inputs"]:
            if not name.endswith((".zip", ".exe")):
                put(root, f"licenses/{name}", (args.cache / name).read_bytes())
        patch = root / "thcrap/patches/stg-ai-th18"
        original = json.loads((patch / "patch.js").read_bytes())
        if original.get("update") is not False or original.get("dependencies"):
            raise ValueError("AI patch must disable updates and have no dependencies")
        dump(patch / "versions.js", {"hashes": {lock["target"]["sha256"]:
             [lock["target"]["game"], lock["target"]["build"], "original", 932]}})
        dump(patch / "th18.js", {"game": "th18", "title": "Touhou 18"})
        dump(patch / "files.js", {p.name: zlib.crc32(p.read_bytes()) for p in sorted(patch.iterdir())
                                  if p.name != "files.js"})
        dump(root / "thcrap/config/games.js", {})
        dump(root / "thcrap/bin/update.json", [])
        (root / "thcrap/logs").mkdir()
        put(root, "使用说明.txt", INSTRUCTIONS.encode("utf-8-sig"))
        for name in ("launcher.c", "Makefile", "build.py", "dependencies.json"):
            put(root, f"source/{name}", (HERE / name).read_bytes())
        put(root, "source/README.md", (HERE / "README.md").read_bytes())
        closure = verify_closure(root)
        expected_binaries = THCRAP_DLLS | VC_DLLS | {
            "TH18-AI.exe", "stg_ai.dll", "onnxruntime.dll", "onnxruntime_providers_shared.dll",
            "d3dx9_43.dll", "xinput1_3.dll",
        }
        if {Path(name).name for name in closure} != expected_binaries or len(closure) != len(expected_binaries):
            raise ValueError("Unexpected executable/DLL in bundle")
        dump(root / "provenance.json", {
            "format": 1, "target": lock["target"], "dependencies": lock,
            "dependency_lock_sha256": sha(lock_bytes),
            "launcher_sha256": sha(launcher_bytes),
            "binaries_sha256": {name: sha((root / name).read_bytes()) for name in closure},
            "x86_imports": closure,
            "verification": "x86 PE32 ordinary/delay import closure against bundled DLLs and Windows system DLLs/API sets; no Windows execution",
            "checksum_scope": "SHA256SUMS covers every other regular bundle file; ZIP sidecar covers the entire archive",
        })
        files = sorted(p for p in root.rglob("*") if p.is_file())
        put(root, "SHA256SUMS", "".join(f"{sha(p.read_bytes())}  {p.relative_to(root).as_posix()}\n"
                                      for p in files).encode("utf-8"))
        files.append(root / "SHA256SUMS")
        expected = {"TH18-AI/" + p.relative_to(root).as_posix(): p.read_bytes() for p in files}
        # Fixed ZIP timestamps and sorted names make identical inputs reproducible.
        with zipfile.ZipFile(args.output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for name, data in sorted(expected.items()):
                entry = zipfile.ZipInfo(name, (2026, 10, 22, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.external_attr = 0o100644 << 16
                archive.writestr(entry, data)
            entry = zipfile.ZipInfo("TH18-AI/thcrap/logs/", (2026, 10, 22, 0, 0, 0))
            entry.external_attr = (0o40755 << 16) | 0x10
            archive.writestr(entry, b"")
        with zipfile.ZipFile(args.output) as archive:
            if archive.testzip() is not None:
                raise ValueError("ZIP CRC verification failed")
            if set(archive.namelist()) != set(expected) | {"TH18-AI/thcrap/logs/"}:
                raise ValueError("ZIP file list mismatch")
            for name, data in expected.items():
                if archive.read(name) != data:
                    raise ValueError(f"ZIP content mismatch: {name}")
    digest = sha(args.output.read_bytes())
    args.output.with_suffix(args.output.suffix + ".sha256").write_text(
        f"{digest}  {args.output.name}\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output), "bytes": args.output.stat().st_size,
                      "sha256": digest, "files": len(files), "x86_binaries": len(closure),
                      "verified": "pinned inputs, PE import closure, ZIP CRC and every file byte"}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", required=True, type=Path)
    parser.add_argument("--adapter", required=True, type=Path)
    parser.add_argument("--launcher", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    build(parser.parse_args())
