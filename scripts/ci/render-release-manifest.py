#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path


TARGETS = {
    "darwin-arm64": ("darwin", "arm64"),
    "linux-amd64": ("linux", "amd64"),
    "linux-arm64": ("linux", "arm64"),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


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
        "checksumPolicy": "all downloadable assets are SHA-256 recorded after successful build and smoke verification",
        "nonPromises": [
            "release binaries cover only the targets present in downloadableAssets",
            "release binaries do not bundle project-specific HarmonyOS, Apple, Android, Gradle, or DevEco toolchains",
            "Windows and macOS Intel binaries are not claimed by this release",
        ],
    }
    args.output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    lines = [
        f"# HapCLI {args.version}",
        "",
        "This release is assembled from tag-matched source and verified native builds.",
        "Every binary asset passed `hap version` before publication.",
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
