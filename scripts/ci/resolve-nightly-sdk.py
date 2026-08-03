#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from urllib.parse import quote


PLATFORMS = {
    "linux-x64": ".tar.gz",
    "linux-aarch64": ".tar.gz",
    "mac-aarch64": ".tar.gz",
    "mac-x64": ".tar.gz",
    "windows-x64": ".zip",
}


def fail(message: str) -> None:
    raise SystemExit(message)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--platform", choices=sorted(PLATFORMS), required=True)
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

    extension = PLATFORMS[args.platform]
    expected_name = f"cangjie-sdk-{args.platform}-{tag}{extension}"
    matches = [
        asset
        for asset in assets
        if asset.get("classification") == "sdk" and asset.get("name") == expected_name
    ]
    if len(matches) != 1:
        fail(f"expected exactly one native host SDK asset: {expected_name}")
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
        "sdkPlatform": args.platform,
        "sdkName": expected_name,
        "sdkUrl": expected_url,
        "sdkSha256": digest,
        "checksumAuthority": "mirror-computed-sha256",
        "status": "selected-from-complete-mirror-manifest",
        "nonPromises": [
            "SDK selection does not prove the Hap build succeeds on this runner",
            "cross SDK assets are not selected as native host SDKs",
        ],
    }
    print(json.dumps(output, indent=2))
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as destination:
            destination.write(f"sdk_tag={tag}\n")
            destination.write(f"sdk_platform={args.platform}\n")
            destination.write(f"sdk_name={expected_name}\n")
            destination.write(f"sdk_url={expected_url}\n")
            destination.write(f"sdk_sha256={digest}\n")


if __name__ == "__main__":
    main()
