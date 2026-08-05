#!/usr/bin/env python3
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
from urllib.parse import quote


REQUIRED_BUILD_INPUTS = {
    "linux-amd64": ("native", "cangjie-sdk-linux-x64-{tag}.tar.gz"),
    "linux-arm64": ("native", "cangjie-sdk-linux-aarch64-{tag}.tar.gz"),
    "darwin-arm64": ("native", "cangjie-sdk-mac-aarch64-{tag}.tar.gz"),
    "darwin-amd64": ("native", "cangjie-sdk-mac-x64-{tag}.tar.gz"),
    "windows-amd64": ("native", "cangjie-sdk-windows-x64-{tag}.zip"),
    "ohos-arm64": ("cross", "cangjie-sdk-linux-x64-ohos-{tag}.tar.gz"),
    "ohos-amd64": ("cross", "cangjie-sdk-linux-x64-ohos-{tag}.tar.gz"),
}

UPSTREAM_GAP_CANDIDATES = {
    "windows-arm64": [
        "cangjie-sdk-windows-arm64-{tag}.zip",
        "cangjie-sdk-windows-arm64-{tag}.exe",
    ],
    "windows-x86": [
        "cangjie-sdk-windows-x86-{tag}.zip",
        "cangjie-sdk-windows-x86-{tag}.exe",
    ],
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def valid_digest(value: str) -> bool:
    return len(value) == 64 and all(character in "0123456789abcdef" for character in value)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("schema") != "happub-cangjie-sdk-mirror-manifest-v1":
        raise SystemExit("unsupported Cangjie SDK mirror manifest schema")
    if not manifest.get("ok") or manifest.get("status") != "mirrored-verbatim":
        raise SystemExit("Cangjie SDK mirror manifest is not complete")
    if manifest.get("checksumPolicy", {}).get("authority") != "mirror-computed-sha256":
        raise SystemExit("unsupported Cangjie SDK checksum authority")

    tag = manifest.get("upstream", {}).get("tag", "")
    if not tag or tag != manifest.get("mirror", {}).get("tag"):
        raise SystemExit("Cangjie SDK mirror tag mismatch")
    assets = manifest.get("assets", [])
    if manifest.get("assetCount") != len(assets) or not assets:
        raise SystemExit("Cangjie SDK mirror asset count mismatch")

    names = set()
    inventory = []
    for asset in assets:
        name = asset.get("name", "")
        digest = asset.get("sha256", "")
        if not name or name != Path(name).name or name in names:
            raise SystemExit(f"invalid or duplicate mirror asset name: {name}")
        if not valid_digest(digest):
            raise SystemExit(f"invalid mirror asset SHA-256: {name}")
        expected_url = (
            "https://github.com/HapPub/CangjieSDK-Mirror/releases/download/"
            f"{quote(tag, safe='')}/{quote(name, safe='')}"
        )
        if asset.get("mirrorUrl") != expected_url:
            raise SystemExit(f"unexpected mirror URL: {name}")
        names.add(name)
        inventory.append({
            "name": name,
            "classification": asset.get("classification", "unknown"),
            "size": asset.get("size", 0),
            "sha256": digest,
            "mirrorUrl": expected_url,
            "status": "mirrored-and-checksum-resolved",
        })

    build_inputs = []
    for target, (mode, pattern) in REQUIRED_BUILD_INPUTS.items():
        name = pattern.format(tag=tag)
        if name not in names:
            raise SystemExit(f"required {mode} build input is missing: {name}")
        build_inputs.append({
            "target": target,
            "mode": mode,
            "assetName": name,
            "status": "sdk-mirrored-and-resolved",
        })

    gaps = []
    for target, patterns in UPSTREAM_GAP_CANDIDATES.items():
        candidates = [pattern.format(tag=tag) for pattern in patterns]
        matched = [name for name in candidates if name in names]
        if matched:
            status = "upstream-sdk-present-unwired"
        else:
            status = "unsupported-upstream-host-sdk"
        gaps.append({
            "target": target,
            "candidateAssetNames": candidates,
            "matchedAssetNames": matched,
            "status": status,
        })

    counts = Counter(item["classification"] for item in inventory)
    output = {
        "schema": "happub-cangjie-sdk-coverage-v1",
        "ok": True,
        "status": "complete-mirror-inventory-verified",
        "sdkTag": tag,
        "sourceManifest": {
            "url": manifest.get("mirror", {}).get("manifestUrl", ""),
            "sha256": sha256(args.manifest),
            "checksumAuthority": "mirror-computed-sha256",
        },
        "assetCount": len(inventory),
        "coveredAssetCount": len(inventory),
        "classificationCounts": dict(sorted(counts.items())),
        "buildInputs": build_inputs,
        "upstreamTargetGaps": gaps,
        "assets": inventory,
        "nonPromises": [
            "inventory coverage does not claim every mirrored SDK can build HapCLI",
            "cross-build input availability does not prove target-runtime execution",
            "an absent upstream host SDK is not replaced by an incompatible architecture",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
