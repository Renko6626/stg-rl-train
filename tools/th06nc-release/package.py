#!/usr/bin/env python3
"""Package an existing TH06NC build, with one model and no development files."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dll", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--license", type=Path, required=True)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    templates = Path(__file__).resolve().parent
    manifest = json.loads(args.manifest.read_text())
    files = {
        "VCRUNTIME140_1.dll": args.dll.read_bytes(),
        "onnxruntime.dll": args.runtime.read_bytes(),
        "model.onnx": args.model.read_bytes(),
        "onnxruntime-LICENSE.txt": args.license.read_bytes(),
    }
    for name in ("README.txt", "th06nc_autoplay.ini"):
        value = (templates / name).read_text(encoding="utf-8")
        files[name] = value.replace("\n", "\r\n").encode("utf-8-sig")
    if sha(files["model.onnx"]) != manifest["sha256"]["onnx"]:
        raise ValueError("Model SHA256 differs from manifest")
    if manifest["graph_version"] != 7:
        raise ValueError("This release requires graph7")
    for name in ("VCRUNTIME140_1.dll", "onnxruntime.dll"):
        data = files[name]
        pe = struct.unpack_from("<I", data, 0x3C)[0]
        if data[:2] != b"MZ" or data[pe:pe + 4] != b"PE\0\0" or struct.unpack_from("<H", data, pe + 4)[0] != 0x8664:
            raise ValueError(f"{name} is not Windows x64 PE")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    # Refuse to overwrite an earlier release accidentally.
    with zipfile.ZipFile(args.output, "x", zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, (2026, 10, 28, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data, compresslevel=9)
    with zipfile.ZipFile(args.output) as archive:
        if archive.testzip() is not None or set(archive.namelist()) != set(files):
            raise ValueError("Archive verification failed")
        for name, data in files.items():
            if archive.read(name) != data:
                raise ValueError(f"Archive bytes differ: {name}")
    digest = sha(args.output.read_bytes())
    args.output.with_suffix(".zip.sha256").write_text(f"{digest}  {args.output.name}\n")
    report = {
        "zip": args.output.name,
        "bytes": args.output.stat().st_size,
        "sha256": digest,
        "files": {name: {"bytes": len(data), "sha256": sha(data)} for name, data in sorted(files.items())},
        "inputs": {name: str(getattr(args, name).resolve()) for name in ("dll", "runtime", "license", "model", "manifest")},
        "model_manifest": manifest,
        "windows_gameplay_verified": False,
    }
    args.output.with_suffix(".release.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({key: report[key] for key in ("zip", "bytes", "sha256")}, ensure_ascii=False))
    print(f"Verified {len(files)} files, CRC and SHA256; development report saved beside ZIP")


if __name__ == "__main__":
    main()
