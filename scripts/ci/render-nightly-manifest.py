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
    "linux-amd64": ("linux", "amd64", ".tar.gz", "native"),
    "linux-arm64": ("linux", "arm64", ".tar.gz", "native"),
    "darwin-arm64": ("macos", "arm64", ".tar.gz", "native"),
    "darwin-amd64": ("macos", "amd64", ".tar.gz", "native"),
    "windows-amd64": ("windows", "amd64", ".zip", "native"),
    "ohos-arm64": ("ohos", "arm64", ".tar.gz", "cross"),
    "ohos-amd64": ("ohos", "amd64", ".tar.gz", "cross"),
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dist", type=Path, required=True)
    parser.add_argument("--sdk-manifest", type=Path, required=True)
    parser.add_argument("--sdk-coverage", type=Path, required=True)
    parser.add_argument("--hap-version", required=True)
    parser.add_argument("--release-tag", required=True)
    parser.add_argument("--source-revision", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--notes-output", type=Path, required=True)
    args = parser.parse_args()

    sdk = json.loads(args.sdk_manifest.read_text(encoding="utf-8"))
    sdk_tag = sdk.get("upstream", {}).get("tag", "")
    if sdk.get("schema") != "happub-cangjie-sdk-mirror-manifest-v1" or not sdk_tag:
        raise SystemExit("invalid Cangjie SDK mirror manifest")
    if len(args.source_revision) != 40 or any(
        character not in "0123456789abcdef" for character in args.source_revision
    ):
        raise SystemExit("nightly source revision must be one full lowercase Git SHA")
    expected_release_tag = f"nightly-{sdk_tag}-hap-{args.source_revision[:12]}"
    if args.release_tag != expected_release_tag:
        raise SystemExit("nightly release tag does not match SDK tag and Hap revision")
    coverage = json.loads(args.sdk_coverage.read_text(encoding="utf-8"))
    if (
        coverage.get("schema") != "happub-cangjie-sdk-coverage-v1"
        or not coverage.get("ok")
        or coverage.get("status") != "complete-mirror-inventory-verified"
        or coverage.get("sdkTag") != sdk_tag
        or coverage.get("assetCount") != sdk.get("assetCount")
        or coverage.get("coveredAssetCount") != sdk.get("assetCount")
        or coverage.get("sourceManifest", {}).get("sha256") != sha256(args.sdk_manifest)
    ):
        raise SystemExit("invalid or incomplete Cangjie SDK coverage receipt")

    base_url = f"https://github.com/{args.repository}/releases/download/{args.release_tag}"
    assets = []
    target_status = []
    for target, (os_name, arch, extension, mode) in TARGETS.items():
        name = f"hap-{args.hap_version}-{target}{extension}"
        path = args.dist / name
        if path.is_file():
            portability = None
            if mode == "native":
                receipt_path, portability = load_runtime_portability_receipt(
                    args.dist, args.hap_version, target, path
                )
                status = VERIFIED_STATUS
            else:
                receipt_path = None
                status = "cross-built-link-verified"
            asset = {
                "kind": "flagship-binary",
                "target": target,
                "os": os_name,
                "arch": arch,
                "buildMode": mode,
                "name": name,
                "url": f"{base_url}/{name}",
                "sha256": sha256(path),
                "status": status,
            }
            if receipt_path is not None and portability is not None:
                asset["runtimePortabilityReceipt"] = {
                    "name": receipt_path.name,
                    "url": f"{base_url}/{receipt_path.name}",
                    "sha256": sha256(receipt_path),
                    "status": portability["status"],
                }
                assets.append({
                    "kind": "native-runtime-portability-receipt",
                    "target": target,
                    "name": receipt_path.name,
                    "url": f"{base_url}/{receipt_path.name}",
                    "sha256": sha256(receipt_path),
                    "status": portability["status"],
                })
            assets.append(asset)
        else:
            status = (
                "runner-build-not-produced"
                if mode == "native"
                else "cross-build-not-produced"
            )
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
    coverage_name = args.sdk_coverage.name
    assets.append({
        "kind": "sdk-coverage-receipt",
        "target": "cangjie-sdk-inventory",
        "name": coverage_name,
        "url": f"{base_url}/{coverage_name}",
        "sha256": sha256(args.sdk_coverage),
        "status": "complete-mirror-inventory-verified",
    })
    gaps = coverage.get("upstreamTargetGaps", [])
    gap_targets = {item.get("target") for item in gaps}
    if gap_targets != {"windows-arm64", "windows-x86"}:
        raise SystemExit("SDK coverage receipt has an unexpected target-gap set")
    for gap in gaps:
        target_status.append({
            "target": gap["target"],
            "status": gap["status"],
            "candidateAssetNames": gap.get("candidateAssetNames", []),
            "matchedAssetNames": gap.get("matchedAssetNames", []),
        })

    manifest = {
        "schema": "happub-hap-nightly-manifest-v1",
        "ok": True,
        "channel": "nightly",
        "prerelease": True,
        "hapVersion": args.hap_version,
        "sourceRevision": args.source_revision,
        "releaseTag": args.release_tag,
        "cangjieSdk": {
            "tag": sdk_tag,
            "manifestUrl": sdk.get("mirror", {}).get("manifestUrl", ""),
            "checksumAuthority": sdk.get("checksumPolicy", {}).get("authority", ""),
            "assetCount": sdk.get("assetCount"),
            "coveredAssetCount": coverage.get("coveredAssetCount"),
            "coverageReceiptUrl": f"{base_url}/{coverage_name}",
        },
        "assets": assets,
        "targetStatus": target_status,
        "nonPromises": [
            "nightly artifacts do not change stable v0.1.0 release claims",
            "SDK-independent version smoke does not verify every Hap command or external toolchain",
            "cross-built-link-verified is not a target-runtime smoke result",
            "a missing experimental artifact is not reported as supported",
            "Windows ARM64 and x86 remain unsupported while the upstream release has no matching host SDK",
        ],
    }
    args.output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    native_built = [row for row in target_status if row["status"] == VERIFIED_STATUS]
    cross_built = [row for row in target_status if row["status"] == "cross-built-link-verified"]
    lines = [
        f"# HapCLI nightly with Cangjie {sdk_tag}",
        "",
        "Nightly artifacts are built on GitHub-hosted runners from checksum-verified Cangjie and OpenHarmony SDK inputs.",
        "They are prerelease evidence and do not widen the stable release promise.",
        "",
        "| Target | Status |",
        "| --- | --- |",
    ]
    lines.extend(f"| `{row['target']}` | `{row['status']}` |" for row in target_status)
    lines.extend([
        "",
        f"Native SDK-independent runtime smoke count: {len(native_built)}",
        f"Cross-build and link verification count: {len(cross_built)}",
        f"Mirrored SDK asset coverage: {coverage.get('coveredAssetCount')}/{coverage.get('assetCount')}",
        "",
    ])
    args.notes_output.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
