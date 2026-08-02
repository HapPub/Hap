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
   the target host before announcing broad availability.

The generated release manifest is built from files downloaded from successful
workflow jobs. It never turns a planned target into a downloadable asset.
