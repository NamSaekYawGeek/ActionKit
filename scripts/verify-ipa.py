#!/usr/bin/env python3
"""Validate a real Xcode-built, unsigned device IPA without altering it."""

import json
import plistlib
import struct
import sys
from pathlib import PurePosixPath
from zipfile import BadZipFile, ZipFile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(path):
    with ZipFile(path) as archive:
        names = archive.namelist()
        base = "Payload/ActionKit.app/"
        require(names and all(name.startswith("Payload/") for name in names),
                "IPA 根目录只能包含 Payload。")
        require(not any(".." in PurePosixPath(name).parts for name in names),
                "IPA 含有无效路径。")
        require(not any(part.endswith(".appex") for name in names
                        for part in PurePosixPath(name).parts),
                "第一版不允许包含额外的 appex。")
        require(not any("_CodeSignature" in PurePosixPath(name).parts or
                        name.endswith("embedded.mobileprovision") for name in names),
                "产物中存在签名或描述文件，不是要求的未签名 IPA。")

        info = plistlib.loads(archive.read(base + "Info.plist"))
        require(info.get("CFBundlePackageType") == "APPL", "不是应用包。")
        require(info.get("MinimumOSVersion") == "18.0", "最低系统版本必须为 iOS 18.0。")
        require(info.get("DTPlatformName") == "iphoneos", "必须使用 iphoneos SDK。")
        executable = info.get("CFBundleExecutable")
        require(executable == "ActionKit", "缺少正确的应用可执行文件。")
        binary = archive.read(base + executable)
        require(len(binary) > 32, "应用可执行文件为空或损坏。")
        magic, cpu = struct.unpack_from("<II", binary)
        require(magic == 0xFEEDFACF and cpu == 0x0100000C,
                "可执行文件必须为 arm64 Mach-O 真机二进制。")

        metadata = [name for name in names if name.startswith(base + "Metadata.appintents/")
                    and not name.endswith("/") and archive.getinfo(name).file_size > 0]
        require(metadata, "未保留非空 Metadata.appintents；快捷指令可能无法发现操作。")
        require(any(PurePosixPath(name).name == "actionsdata" for name in metadata),
                "缺少 App Intents actionsdata 编译元数据。")
        print(json.dumps({
            "ipa": str(path),
            "bundleIdentifier": info.get("CFBundleIdentifier"),
            "minimumOSVersion": info["MinimumOSVersion"],
            "architecture": "arm64",
            "unsigned": True,
            "appIntentsMetadata": metadata,
        }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("用法：python3 scripts/verify-ipa.py dist/ActionKit.ipa")
    try:
        verify(sys.argv[1])
    except (OSError, ValueError, KeyError, BadZipFile, struct.error) as error:
        raise SystemExit(f"IPA 验证失败：{error}") from error
