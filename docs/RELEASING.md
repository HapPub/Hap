# Releasing HapCLI

HapCLI releases are created only from a version-matched Git tag. The release
workflow downloads the official Cangjie 1.1.3 SDK for each native host, verifies
its pinned SHA-256, builds and tests HapCLI, runs `hap version`, and packages only
the binaries that passed those gates.

The required first-release targets are:

- `linux-amd64` on `ubuntu-24.04`
- `linux-arm64` on `ubuntu-24.04-arm`
- `darwin-arm64` on `macos-14`

Windows and macOS Intel are not claimed. The source archive is always emitted as
the portable fallback.

## Release Procedure

1. Update the version in `cjpm.toml` and `src/hapcli.cj` in the same pull request.
2. Run the public, installer-security, and release-workflow tests.
3. Merge the reviewed commit to `main`.
4. Create and push `v<version>` at that exact commit.
5. Confirm that all native jobs pass and that the GitHub release contains
   `manifest.v0.json`, `SHA256SUMS`, Hapup, source, and all three native archives.
6. Download one release archive through its manifest and rerun `hap version` on
   the target host with an empty inherited environment. Preserve the matching
   `*.runtime-portability.json` receipt before announcing broad availability.

The generated release manifest is built from files downloaded from successful
workflow jobs. It never turns a planned target into a downloadable asset.

## Nightly Platform Evidence

The nightly workflow follows the newest complete `CangjieSDK-Mirror` manifest
unless an exact SDK tag is supplied manually. It verifies every mirrored asset
name, URL, and SHA-256 and publishes `cangjie-sdk-coverage.v1.json` with one
entry for every SDK, stdx, frontend, documentation, checksum, and source asset.
Nightly release tags bind both the exact SDK tag and the first 12 characters of
the full Hap source revision; artifacts from a newer Hap commit never overwrite
a release that still points at older source.

Native nightly jobs cover Linux AMD64/ARM64, macOS ARM64/Intel, and Windows
AMD64. Their archives are published only after build, test, package, and exact
`hap version` gates under `env -i`. Cangjie/stdx homes, compiler/linker library
paths, `SDKROOT`, DevEco and OHOS SDK variables are absent; only a minimal OS
baseline is retained. Accepted targets report
`sdk-independent-runtime-smoke-verified` and publish a receipt bound to the
archive and binary SHA-256 values.

The OHOS job uses the mirrored Linux-to-OHOS Cangjie SDK plus a checksum-verified
OpenHarmony 6.1 native sysroot. It emits ARM64 and AMD64 archives only after ELF
architecture and archive checks, with status `cross-built-link-verified`. These
archives are not presented as target-runtime smoke proof. Windows ARM64 and x86
remain explicit upstream gaps until a matching Cangjie host SDK is present in
the mirrored release.
