#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path


TARGETS = {
    "linux-amd64": ("linux", "amd64", ".tar.gz"),
    "linux-arm64": ("linux", "arm64", ".tar.gz"),
    "darwin-arm64": ("macos", "arm64", ".tar.gz"),
    "darwin-amd64": ("macos", "amd64", ".tar.gz"),
    "windows-amd64": ("windows", "amd64", ".zip"),
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
    parser.add_argument("--sdk-manifest", type=Path, required=True)
    parser.add_argument("--hap-version", required=True)
    parser.add_argument("--release-tag", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--notes-output", type=Path, required=True)
    args = parser.parse_args()

    sdk = json.loads(args.sdk_manifest.read_text(encoding="utf-8"))
    sdk_tag = sdk.get("upstream", {}).get("tag", "")
    if sdk.get("schema") != "happub-cangjie-sdk-mirror-manifest-v1" or not sdk_tag:
        raise SystemExit("invalid Cangjie SDK mirror manifest")
    if args.release_tag != f"nightly-{sdk_tag}":
        raise SystemExit("nightly release tag does not match SDK tag")

    base_url = f"https://github.com/{args.repository}/releases/download/{args.release_tag}"
    assets = []
    target_status = []
    for target, (os_name, arch, extension) in TARGETS.items():
        name = f"hap-{args.hap_version}-{target}{extension}"
        path = args.dist / name
        if path.is_file():
            assets.append({
                "kind": "flagship-binary",
                "target": target,
                "os": os_name,
                "arch": arch,
                "name": name,
                "url": f"{base_url}/{name}",
                "sha256": sha256(path),
                "status": "built-and-smoke-verified",
            })
            status = "built-and-smoke-verified"
        else:
            status = "runner-build-not-produced"
        target_status.append({"target": target, "status": status})

    source = args.dist / f"hap-{args.hap_version}-source.tar.gz"
    if not source.is_file():
        raise SystemExit("nightly source archive is missing")
    assets.append({
        "kind": "source-archive",
        "target": "portable-source",
        "name": source.name,
        "url": f"{base_url}/{source.name}",
        "sha256": sha256(source),
        "status": "packaged-from-workflow-commit",
    })
    target_status.extend([
        {"target": "ohos-arm64", "status": "sdk-mirrored-only"},
        {"target": "windows-arm64", "status": "unsupported-upstream-host-sdk"},
        {"target": "windows-x86", "status": "unsupported-upstream-host-sdk"},
    ])

    manifest = {
        "schema": "happub-hap-nightly-manifest-v1",
        "ok": True,
        "channel": "nightly",
        "prerelease": True,
        "hapVersion": args.hap_version,
        "releaseTag": args.release_tag,
        "cangjieSdk": {
            "tag": sdk_tag,
            "manifestUrl": sdk.get("mirror", {}).get("manifestUrl", ""),
            "checksumAuthority": sdk.get("checksumPolicy", {}).get("authority", ""),
        },
        "assets": assets,
        "targetStatus": target_status,
        "nonPromises": [
            "nightly artifacts do not change stable v0.1.0 release claims",
            "sdk-mirrored-only is not a Hap runtime verification result",
            "a missing experimental artifact is not reported as supported",
        ],
    }
    args.output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    built = [row for row in target_status if row["status"] == "built-and-smoke-verified"]
    lines = [
        f"# HapCLI nightly with Cangjie {sdk_tag}",
        "",
        "Nightly artifacts are built on GitHub-hosted native runners from a checksum-verified SDK mirror manifest.",
        "They are prerelease evidence and do not widen the stable release promise.",
        "",
        "| Target | Status |",
        "| --- | --- |",
    ]
    lines.extend(f"| `{row['target']}` | `{row['status']}` |" for row in target_status)
    lines.extend(["", f"Built target count: {len(built)}", ""])
    args.notes_output.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
