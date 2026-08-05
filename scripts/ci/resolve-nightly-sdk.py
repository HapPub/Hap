#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from urllib.parse import quote


SDK_PROFILES = {
    "linux-x64": ("cangjie-sdk-linux-x64-{tag}.tar.gz", "sdk"),
    "linux-aarch64": ("cangjie-sdk-linux-aarch64-{tag}.tar.gz", "sdk"),
    "linux-x64-android": ("cangjie-sdk-linux-x64-android-{tag}.tar.gz", "sdk"),
    "linux-x64-ohos": ("cangjie-sdk-linux-x64-ohos-{tag}.tar.gz", "sdk"),
    "mac-aarch64": ("cangjie-sdk-mac-aarch64-{tag}.tar.gz", "sdk"),
    "mac-aarch64-android": ("cangjie-sdk-mac-aarch64-android-{tag}.tar.gz", "sdk"),
    "mac-aarch64-ios": ("cangjie-sdk-mac-aarch64-ios-{tag}.tar.gz", "sdk"),
    "mac-aarch64-ohos": ("cangjie-sdk-mac-aarch64-ohos-{tag}.tar.gz", "sdk"),
    "mac-x64": ("cangjie-sdk-mac-x64-{tag}.tar.gz", "sdk"),
    "ohos-aarch64": ("cangjie-sdk-ohos-aarch64-{tag}.tar.gz", "sdk"),
    "windows-x64": ("cangjie-sdk-windows-x64-{tag}.zip", "sdk"),
    "windows-x64-android": ("cangjie-sdk-windows-x64-android-{tag}.zip", "sdk"),
    "windows-x64-ohos": ("cangjie-sdk-windows-x64-ohos-{tag}.zip", "sdk"),
    "windows-x64-ohos-arm32": ("cangjie-sdk-windows-x64-ohos-arm32-{tag}.zip", "sdk"),
}


def fail(message: str) -> None:
    raise SystemExit(message)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    selector = parser.add_mutually_exclusive_group(required=True)
    selector.add_argument("--platform", choices=sorted(SDK_PROFILES))
    selector.add_argument("--asset-name")
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("schema") != "happub-cangjie-sdk-mirror-manifest-v1":
        fail("unsupported Cangjie SDK mirror manifest schema")
    if not manifest.get("ok") or manifest.get("status") != "mirrored-verbatim":
        fail("Cangjie SDK mirror manifest is not complete")
    checksum_policy = manifest.get("checksumPolicy", {})
    if checksum_policy.get("authority") != "mirror-computed-sha256":
        fail("Cangjie SDK mirror manifest has an unsupported checksum authority")

    upstream = manifest.get("upstream", {})
    mirror = manifest.get("mirror", {})
    tag = upstream.get("tag", "")
    if not tag or tag != mirror.get("tag"):
        fail("Cangjie SDK mirror tag mismatch")
    assets = manifest.get("assets", [])
    if manifest.get("assetCount") != len(assets):
        fail("Cangjie SDK mirror asset count mismatch")

    expected_classification = None
    if args.platform:
        pattern, expected_classification = SDK_PROFILES[args.platform]
        expected_name = pattern.format(tag=tag)
    else:
        expected_name = args.asset_name
        if not expected_name or expected_name != Path(expected_name).name:
            fail("asset name must be one plain release filename")
    matches = [
        asset
        for asset in assets
        if asset.get("name") == expected_name
        and (expected_classification is None or asset.get("classification") == expected_classification)
    ]
    if len(matches) != 1:
        fail(f"expected exactly one mirrored asset: {expected_name}")
    asset = matches[0]
    digest = asset.get("sha256", "")
    if len(digest) != 64 or any(character not in "0123456789abcdef" for character in digest):
        fail(f"invalid SHA-256 for {expected_name}")
    expected_url = (
        "https://github.com/HapPub/CangjieSDK-Mirror/releases/download/"
        f"{quote(tag, safe='')}/{quote(expected_name, safe='')}"
    )
    if asset.get("mirrorUrl") != expected_url:
        fail(f"unexpected mirror URL for {expected_name}")

    output = {
        "schema": "happub-hap-nightly-sdk-selection-v1",
        "ok": True,
        "sdkTag": tag,
        "sdkPlatform": args.platform or "exact-asset",
        "sdkName": expected_name,
        "classification": asset.get("classification", ""),
        "sdkUrl": expected_url,
        "sdkSha256": digest,
        "checksumAuthority": "mirror-computed-sha256",
        "status": "selected-from-complete-mirror-manifest",
        "nonPromises": [
            "asset selection does not prove the Hap build succeeds on this runner",
            "cross SDK selection does not prove target-runtime execution",
        ],
    }
    print(json.dumps(output, indent=2))
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as destination:
            destination.write(f"sdk_tag={tag}\n")
            destination.write(f"sdk_platform={args.platform or 'exact-asset'}\n")
            destination.write(f"sdk_name={expected_name}\n")
            destination.write(f"sdk_url={expected_url}\n")
            destination.write(f"sdk_sha256={digest}\n")


if __name__ == "__main__":
    main()
