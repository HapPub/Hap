#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
from typing import Any


SCHEMA = "happub-hap-native-runtime-portability-receipt-v1"
VERIFIED_STATUS = "sdk-independent-runtime-smoke-verified"
REQUIRED_CLEARED = {
    "CANGJIE_HOME",
    "CANGJIE_STDX_PATH",
    "CJC_HOME",
    "CJPM_HOME",
    "LD_LIBRARY_PATH",
    "DYLD_LIBRARY_PATH",
    "LIBRARY_PATH",
    "SDKROOT",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def receipt_name(version: str, target: str) -> str:
    return f"hap-{version}-{target}.runtime-portability.json"


def load_runtime_portability_receipt(
    dist: Path,
    version: str,
    target: str,
    archive: Path,
) -> tuple[Path, dict[str, Any]]:
    path = dist / receipt_name(version, target)
    if not path.is_file():
        raise SystemExit(
            f"SDK-independent runtime portability receipt is missing: {path.name}"
        )
    try:
        receipt = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"invalid runtime portability receipt {path.name}: {error}")

    expected_binary = "hap.exe" if target == "windows-amd64" else "hap"
    checks = (
        (receipt.get("schema") == SCHEMA, "schema"),
        (receipt.get("ok") is True, "ok"),
        (receipt.get("status") == VERIFIED_STATUS, "status"),
        (receipt.get("target") == target, "target"),
        (receipt.get("version") == version, "version"),
        (receipt.get("inheritedSdkEnvironment") is False, "SDK environment"),
        (
            receipt.get("environmentMode")
            == "empty-inherited-environment-with-minimal-os-baseline",
            "environment mode",
        ),
        (receipt.get("archive", {}).get("name") == archive.name, "archive name"),
        (
            receipt.get("archive", {}).get("sha256") == sha256(archive),
            "archive checksum",
        ),
        (receipt.get("binary", {}).get("name") == expected_binary, "binary name"),
        (
            len(receipt.get("binary", {}).get("sha256", "")) == 64,
            "binary checksum",
        ),
        (receipt.get("smoke", {}).get("command") == "hap version", "command"),
        (
            receipt.get("smoke", {}).get("expectedVersion") == version,
            "expected version",
        ),
        (
            receipt.get("smoke", {}).get("actualVersion") == version,
            "actual version",
        ),
        (receipt.get("smoke", {}).get("exitCode") == 0, "exit code"),
    )
    failed = [label for accepted, label in checks if not accepted]

    cleared = set(receipt.get("clearedEnvironmentVariables", []))
    allowed = set(receipt.get("allowedEnvironmentVariables", []))
    if not REQUIRED_CLEARED.issubset(cleared):
        failed.append("cleared environment set")
    if cleared.intersection(allowed):
        failed.append("allowed environment overlaps cleared SDK variables")
    if failed:
        raise SystemExit(
            f"runtime portability receipt {path.name} failed: {', '.join(failed)}"
        )
    return path, receipt
