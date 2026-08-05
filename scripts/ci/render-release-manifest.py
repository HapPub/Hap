#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

from runtime_portability import (
    VERIFIED_STATUS,
    load_runtime_portability_receipt,
    sha256,
)


TARGETS = {
    "darwin-arm64": ("darwin", "arm64"),
    "linux-amd64": ("linux", "amd64"),
    "linux-arm64": ("linux", "arm64"),
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dist", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--notes-output", type=Path, required=True)
    args = parser.parse_args()

    if args.tag != f"v{args.version}":
        raise SystemExit("tag and version do not match")

    base_url = f"https://github.com/{args.repository}/releases/download/{args.tag}"
    assets = []

    hapup = args.dist / "hapup.sh"
    source = args.dist / f"hap-{args.version}-source.tar.gz"
    for path in (hapup, source):
        if not path.is_file():
            raise SystemExit(f"required release asset is missing: {path.name}")

    assets.append({
        "id": "hapup-sh",
        "kind": "bootstrap-shell",
        "target": "portable-posix-shell",
        "name": hapup.name,
        "url": f"{base_url}/{hapup.name}",
        "sha256": sha256(hapup),
        "downloadable": True,
        "executable": True,
    })

    binary_rows = []
    for target, (os_name, arch) in TARGETS.items():
        path = args.dist / f"hap-{args.version}-{target}.tar.gz"
        if not path.is_file():
            raise SystemExit(f"required release target is missing: {target}")
        receipt_path, receipt = load_runtime_portability_receipt(
            args.dist, args.version, target, path
        )
        checksum = sha256(path)
        assets.append({
            "id": f"hap-{target}",
            "kind": "flagship-binary",
            "target": target,
            "os": os_name,
            "arch": arch,
            "name": path.name,
            "url": f"{base_url}/{path.name}",
            "sha256": checksum,
            "downloadable": True,
            "executable": True,
            "status": VERIFIED_STATUS,
            "runtimePortabilityReceipt": {
                "name": receipt_path.name,
                "url": f"{base_url}/{receipt_path.name}",
                "sha256": sha256(receipt_path),
                "status": receipt["status"],
            },
        })
        binary_rows.append((target, path.name, checksum))

    assets.append({
        "id": "hap-source",
        "kind": "source-archive",
        "target": "portable-source",
        "name": source.name,
        "url": f"{base_url}/{source.name}",
        "sha256": sha256(source),
        "downloadable": True,
        "executable": False,
    })

    manifest = {
        "schema": "happub-release-manifest-v0",
        "ok": True,
        "channel": "stable",
        "version": args.version,
        "status": "released-from-verified-assets",
        "repository": args.repository,
        "tag": args.tag,
        "manifestUrl": f"{base_url}/manifest.v0.json",
        "downloadableAssetCount": len(assets),
        "downloadableAssets": assets,
        "plannedAssets": [],
        "manifestInstallStatus": "available",
        "manifestInstallCommand": (
            "sh hapup.sh install-from-manifest --manifest ./manifest.v0.json "
            "--target auto --install-dir \"$HOME/.local/bin\" --review-token reviewed"
        ),
        "sourceBuildSupported": True,
        "runtimePortabilityPolicy": "native archives must pass hap version with an empty inherited environment and no Cangjie SDK paths",
        "checksumPolicy": "all downloadable assets are SHA-256 recorded after successful build and SDK-independent runtime smoke verification",
        "nonPromises": [
            "release binaries cover only the targets present in downloadableAssets",
            "SDK-independent version smoke does not verify every Hap command or external toolchain",
            "release binaries do not bundle project-specific HarmonyOS, Apple, Android, Gradle, or DevEco toolchains",
            "Windows and macOS Intel binaries are not claimed by this release",
        ],
    }
    args.output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    lines = [
        f"# HapCLI {args.version}",
        "",
        "This release is assembled from tag-matched source and verified native builds.",
        "Every binary asset passed `hap version` from its extracted archive with an empty inherited SDK environment before publication.",
        "",
        "| Target | Asset | SHA-256 |",
        "| --- | --- | --- |",
    ]
    lines.extend(f"| `{target}` | `{name}` | `{checksum}` |" for target, name, checksum in binary_rows)
    lines.extend([
        "",
        "The source archive is always available as the portable fallback. See the README for the checksum-first Hapup flow.",
        "",
    ])
    args.notes_output.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
