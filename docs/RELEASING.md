# Releasing HapCLI

HapCLI releases are built from version-matched tags. Two toolchain-qualified
releases use the same HapCLI source version and different pinned compilers:

- `v0.3.0-cangjie-1.0.5`: built with Cangjie 1.0.5 LTS.
- `v0.3.0-cangjie-1.1.3`: built with Cangjie 1.1.3 STS.

Each requires native Linux AMD64, Linux ARM64, macOS ARM64 and Windows AMD64
builds, the full test suite, and an extracted-archive `hap version` check with
no inherited SDK environment. Windows failures block publication. Stable 1.0.5
and 1.1.3 do not provide macOS Intel host SDKs; the separate nightly matrix tests
that host with a matching nightly SDK.

SDK archives are resolved from the exact mirror manifest and checked against its
SHA-256. The release manifest records the compiler version, source revision and
per-platform SDK provenance. A missing archive, mismatched SDK receipt or failed
runtime check prevents publication. Published assets are never silently overwritten.

Older toolchains may require runtime libraries. macOS archives carry required
vendor libraries in content-addressed `bin/.hap-runtime` directories, with a
relative loader path; Windows ZIPs carry SDK runtime DLLs beside `hap.exe`.
The vendor license travels with those files. Keep the complete `bin` directory
when manually moving an installation. Hapup preserves macOS runtime bundles
alongside the binary, including prior bundles needed by `hap.prev`.

## Release Procedure

1. Update the version in `cjpm.toml`, `src/hapcli.cj`, `release/hapup.sh`,
   `release/manifest.v0.json` and `src/release_manifest.cj` in the same pull request.
   Refresh the Hapup SHA-256 in both preview manifests after changing its version.
   Synchronize all three README source badges and current-version installation
   examples; keep minimum supported versions and historical release examples
   distinct from the current source version.
2. Run the public, installer-security, and release-workflow tests.
3. Merge the reviewed commit to `main`.
4. Create and push `v<version>-cangjie-1.0.5` and `v<version>-cangjie-1.1.3`
   at the exact verified commit. A plain `v<version>` remains an STS build.
5. Confirm that all native jobs pass and that the GitHub release contains
   `manifest.v0.json`, `SHA256SUMS`, Hapup, source, and all four native archives.
6. Download one release archive through its manifest and rerun `hap version` on
   the target host with an empty inherited environment. Preserve the matching
   `*.runtime-portability.json` receipt before announcing broad availability.

The generated release manifest is built from files downloaded from successful
workflow jobs. It never turns a planned target into a downloadable asset.

## Selecting a toolchain-qualified release

Once the release is published, use a verified bootstrap companion:

```sh
hapup install --version 0.3.0-cangjie-1.1.3
# Or select the LTS compiler build:
hapup install --version 0.3.0-cangjie-1.0.5
```

Both binaries report `hap version` as `0.3.0`; the release tag and manifest identify
the build compiler. This does not change what `hap get cangjie --version ...`
installs. STS is the default latest release; the LTS build is an explicit choice.
Windows users extract the matching ZIP and retain `hap.exe` and its adjacent DLLs;
the POSIX Hapup companion is not a native PowerShell installer.

A branch push to the dedicated release-fix branch or a manual workflow run checks
both compilers without publishing. Only tag runs enter the publication job.

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
