#!/usr/bin/env python3
import argparse
import json
import re
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
    parser.add_argument("--sdk-version", choices=("1.0.5", "1.1.3"))
    parser.add_argument("--source-revision")
    args = parser.parse_args()

    permitted_tags = {f"v{args.version}"}
    if args.sdk_version:
        permitted_tags.add(f"v{args.version}-cangjie-{args.sdk_version}")
        if not re.fullmatch(r"[0-9a-f]{40}", args.source_revision or ""):
            raise SystemExit("toolchain release requires an exact source revision")
    if args.tag not in permitted_tags:
        raise SystemExit("tag, version and build toolchain do not match")

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
    targets = dict(TARGETS)
    if args.sdk_version:
        targets["windows-amd64"] = ("windows", "amd64")
    for target, (os_name, arch) in targets.items():
        extension = "zip" if target.startswith("windows-") else "tar.gz"
        path = args.dist / f"hap-{args.version}-{target}.{extension}"
        if not path.is_file():
            raise SystemExit(f"required release target is missing: {target}")
        receipt_path, receipt = load_runtime_portability_receipt(
            args.dist, args.version, target, path
        )
        checksum = sha256(path)
        if args.sdk_version:
            resolution_path = args.dist / f"hap-{args.version}-{target}.cangjie-sdk-resolution.json"
            resolution = json.loads(resolution_path.read_text(encoding="utf-8"))
            platform = {"linux-amd64": "linux-x64", "linux-arm64": "linux-aarch64",
                        "darwin-arm64": "mac-aarch64", "windows-amd64": "windows-x64"}[target]
            if (resolution.get("sdkTag") != args.sdk_version or
                    resolution.get("sdkPlatform") != platform or
                    resolution.get("status") != "verified-and-installed" or
                    not re.fullmatch(r"[0-9a-f]{64}", resolution.get("sdkSha256", ""))):
                raise SystemExit(f"build SDK provenance mismatch for {target}")
            # Publish provenance, not runner-local installation paths.
            resolution = {key: resolution[key] for key in (
                "schema", "status", "sdkTag", "sdkPlatform", "sdkName", "sdkUrl",
                "sdkSha256", "checksumAuthority")}
            resolution_path.write_text(json.dumps(resolution, indent=2) + "\n", encoding="utf-8")
            assets.append({
                "id": f"sdk-provenance-{target}", "kind": "build-toolchain-receipt",
                "target": target, "name": resolution_path.name,
                "url": f"{base_url}/{resolution_path.name}", "sha256": sha256(resolution_path),
                "downloadable": True, "executable": False,
            })
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
            "macOS Intel and Windows ARM64 host SDKs are not published for these stable toolchains"
            if args.sdk_version else "Windows and macOS Intel binaries are not claimed by this release",
        ],
    }
    if args.sdk_version:
        manifest["buildToolchain"] = {"language": "Cangjie", "version": args.sdk_version}
        manifest["sourceRevision"] = args.source_revision
    args.output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    lines = [
        f"# HapCLI {args.version}" + (f" — Cangjie {args.sdk_version}" if args.sdk_version else ""),
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
    if args.sdk_version:
        lines.extend([
            f"Built with Cangjie **{args.sdk_version}** from `{args.source_revision}`.",
            "The toolchain qualifier identifies the compiler used to build HapCLI; it does not select the SDK installed by `hap get`.",
            "",
            "## Updates / 更新内容",
            "- Fix Windows package-transaction temporary paths, checksum execution and standard SDK-layout lookup.",
            "- Fix macOS Intel testing for unavailable stable SDK pairs and retain failure diagnostics.",
            "- Provide complete Cangjie installation, IBM Semeru JDK and Android/OpenHarmony/HarmonyOS SDK installers.",
            "- Synchronize three-language READMEs and source-version checks.",
            "- 修复 Windows 构建测试的路径与校验工具问题，分别提供仓颉 1.0.5 / 1.1.3 构建版本。",
            "",
            "## Validation and limits / 验证与限制",
            "All four native targets must build, pass the full test suite and run the extracted binary with no inherited SDK environment before publication.",
            "SDK installation is native macOS/Linux only; Windows SDK installers remain plan-only. Android and current macOS HarmonyOS live upstream installation acceptance remains incomplete.",
            "四个平台均须通过原生构建、完整测试与解包后版本验证。发行可用不代表所有工具链安装、应用签名或设备流程均已验收。",
        ])
    args.notes_output.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
