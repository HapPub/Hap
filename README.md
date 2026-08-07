<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-HapCLI-c96b2c?style=for-the-badge&labelColor=1f2430" alt="Cangjie HapCLI" />
  <img src="https://img.shields.io/badge/version-0.1.0-3182ce?style=for-the-badge&labelColor=1f2430" alt="Version 0.1.0" />
  <img src="https://img.shields.io/badge/mode-local--first-2f855a?style=for-the-badge&labelColor=1f2430" alt="Local first" />
  <img src="https://img.shields.io/badge/focus-toolchain%20glue-805ad5?style=for-the-badge&labelColor=1f2430" alt="Toolchain glue" />
  <img src="https://img.shields.io/badge/license-Apache--2.0-d69e2e?style=for-the-badge&labelColor=1f2430" alt="Apache License 2.0" />
</p>
<div align="center">
<span style="font-weight:300;font-size:38px">HapCLI</span><br/>
<span style="font-weight:100;font-size:24px">Local-first toolchain compatibility and repair</span>
<p align="center">
  <strong>Inspect first, plan the repair, execute fixed adapters, keep the receipt.</strong><br/>
  <sub>Cangjie · cjpm · stdx · HarmonyOS · Kotlin Multiplatform · CI</sub>
</p>
</div>

**English** | [简体中文](README.zh-CN.md) | [Русский](README.ru.md)

## What is HapCLI

HapCLI is an open-source command-line compatibility layer for projects whose
toolchain configuration changes between a developer machine, CI, a cloud host,
or a connected device. It currently focuses on Cangjie/cjpm, HarmonyOS
application development, and Kotlin Multiplatform workflows.

HapCLI does not replace `cjpm`, Gradle, Xcode, DevEco Studio, `hdc`, or a package
manager. It detects project and environment facts, produces reviewable plans,
executes a bounded set of fixed tool adapters, and records structured results.

## Quick Start

Verified release binaries are available for Linux AMD64, Linux ARM64, and
macOS ARM64. Download Hapup and the generated manifest, verify both files, then
install the binary selected for the current host:

```bash
VERSION=0.1.0
BASE="https://github.com/HapPub/Hap/releases/download/v$VERSION"
WORK="$(mktemp -d)"
cd "$WORK"
curl -fsSLO "$BASE/hapup.sh" -O "$BASE/hapup.sh.sha256"
curl -fsSLO "$BASE/manifest.v0.json" -O "$BASE/manifest.v0.json.sha256"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c hapup.sh.sha256
  sha256sum -c manifest.v0.json.sha256
else
  shasum -a 256 -c hapup.sh.sha256
  shasum -a 256 -c manifest.v0.json.sha256
fi
sh ./hapup.sh install-from-manifest \
  --manifest ./manifest.v0.json \
  --install-dir "$HOME/.local/bin" \
  --review-token reviewed
"$HOME/.local/bin/hap" version
```

The source archive remains the portable fallback. Building from source requires
the Cangjie SDK and `cjpm` 1.1.x. On macOS, expose the active SDK first:

```bash
export SDKROOT="$(xcrun --show-sdk-path)"
```

Build and install a user-local command:

```bash
cjpm build
mkdir -p "$HOME/.local/bin"
cp ./target/release/bin/main "$HOME/.local/bin/hap"
chmod +x "$HOME/.local/bin/hap"
hap version
```

Run the first read-only checks inside a project:

```bash
hap project detect --project .
hap toolchain providers
hap help
```

The checked-in [`release/manifest.v0.json`](release/manifest.v0.json) records the
source preview. Every GitHub Release carries a generated manifest built only
from native jobs that completed build, test, checksum, and `hap version` gates.

## Core Capabilities

- Detect Cangjie/cjpm, HarmonyOS, iOS, and Compose Multiplatform project shapes.
- Inspect `cjpm.toml` dependency profiles and diagnose local `path` versus
  remote `git` drift.
- Record a known-good stdx target profile and plan or apply a backed-up repair
  in another project.
- Run fixed `cjpm build` and `cjpm bundle` actions with bounded environment
  diagnosis, one reviewed repair attempt, and central-repository dependency
  ordering guidance.
- Build, install, launch, and verify HarmonyOS applications through fixed
  `hvigor` and `hdc` commands.
- Remember reviewed HarmonyOS device aliases and recent USB-proven wireless
  endpoints without scanning the local network.
- Run Compose Multiplatform desktop applications and build/install/launch iOS
  applications when the host already has valid Apple signing assets.
- Diagnose GitHub Actions, generate reviewed CI recipes, and keep workflow
  mutation outside the CLI.
- Keep normal output concise; use `-v` or `--verbose` for structured execution
  details and `--write-receipt` for an explicit agent/CI handoff.

## Common Workflows

### Cangjie and stdx

```bash
hap inspect-cjpm ./cjpm.toml
hap record cangjie.stdx --project . --target x86_64-unknown-linux-gnu
hap doctorfix cangjie.stdx --project . --target x86_64-unknown-linux-gnu --plan
hap build --project . --target x86_64-unknown-linux-gnu
hap bundle --project . --skip-lint
hap get cangjie-sdk --target linux-amd64 --version <nightly-tag> --region auto --install-root "$HOME/.hap/runtimes"
hap get cangjie-stdx --target linux-amd64 --version <nightly-tag> --region auto --install-root "$HOME/.hap/stdx"
```

The two `get` commands emit plans; they do not download or install from this
surface. `global` routes to the byte-preserving
[CangjieSDK-Mirror](https://github.com/HapPub/CangjieSDK-Mirror) first, while
`zh-cn` routes to the original GitCode release first. Both built-in routes use
the mirror's `manifest.v1.json` as their SHA-256 authority. An explicit
`--provider-url` stays custom and has no silent fallback.

For reviewed GitHub Actions and other hosted runners, the repository provides
a real mirror-to-environment bridge:

```bash
bash scripts/ci/bootstrap-cangjie-from-mirror.sh \
  https://github.com/HapPub/CangjieSDK-Mirror/releases/download/<nightly-tag>/manifest.v1.json \
  linux-x64 "$RUNNER_TEMP/cangjie" "$RUNNER_TEMP/cangjie-env.sh" \
  "$RUNNER_TEMP/cangjie-sdk-resolution.json"
source "$RUNNER_TEMP/cangjie-env.sh"
```

The bridge resolves one exact SDK and mirror SHA-256, performs the verified
runner installation, and writes both a sourceable environment file and a JSON
receipt. It does not mutate shell rc files or the parent process environment.
See [Full Cangjie Artifact Action](docs/CANGJIE_FULL_ARTIFACT_ACTION.md) for the
Linux, macOS, Windows, and OHOS cross-build matrix.

### HarmonyOS application development

```bash
hap project detect --project .
hap device --project .
hap dev --project .
hap dev --project . --device demo-phone
hap dev --project . --device 192.0.2.40:5555 -v
```

`hap dev` auto-selects the workflow when exactly one supported project type is
present. Use `--platform` only for mixed or ambiguous directories.

### Kotlin Multiplatform

```bash
hap dev --project . --target desktop
hap dev --project . --target ios
hap dev --project . --target ios --useOld --artifact ./iosApp/build/Debug-iphoneos/DemoApp.app
```

### CI and dependency graphs

```bash
hap ci action-doctor --workflow .github/workflows/build.yml --project . --target linux-amd64
hap cjpm graph doctor --manifest ./cjpm.toml
hap cjpm graph ci-workflow-export --manifest ./cjpm.toml --workflow-output /tmp/hap-preflight.yml --review-token reviewed
```

## Platform Status

| Surface | Status | Honest boundary |
| --- | --- | --- |
| Cangjie/cjpm on macOS arm64 | Source, tests, and tag release lane verified | Current Cangjie 1.1.3 static runtime objects require macOS 13.3 even when the linker target is lower. |
| Cangjie/cjpm on Linux AMD64/ARM64 | Tag release lanes available | Each release is published only after the native runner builds, tests, and smoke-checks its binary. |
| Windows AMD64 and macOS Intel | Nightly native lanes verified | Stable `v0.1.0` remains unchanged; nightly binaries require build, test, package, and `hap version` gates on matching hosted runners. |
| OHOS ARM64/AMD64 | Nightly cross-build and link verification available | The artifacts are not runtime-smoked on an OHOS device and require a compatible target Cangjie runtime. |
| Windows ARM64/x86 | Upstream gap recorded | The mirrored Cangjie release has no matching native host SDK, so HapCLI does not relabel another architecture as support. |
| HarmonyOS applications | Real build/install/launch workflow available | Requires a working DevEco toolchain, authorized device, and valid signing profile. |
| KMP desktop on macOS | Real Gradle build/run verified | Other desktop hosts require separate field verification. |
| KMP iOS/iPadOS | Build/install/launch implementation available | Apple account, certificate, profile, development team, paired device, and CoreDevice readiness remain host prerequisites. |
| Android device listing | Read-only ADB discovery available | APK build/install orchestration is not implemented. |

The separate nightly workflow builds Linux AMD64/ARM64, macOS ARM64/Intel, and
Windows AMD64 on matching GitHub-hosted runners. It also cross-builds and
link-verifies OHOS ARM64/AMD64 with a Linux-to-OHOS Cangjie SDK and a
checksum-verified OpenHarmony sysroot. Native artifacts use
`sdk-independent-runtime-smoke-verified` after the extracted binary passes
`hap version` with an empty inherited SDK environment; cross artifacts use
`cross-built-link-verified`. Each nightly publishes machine-readable runtime
portability receipts plus a receipt covering every mirrored SDK, stdx,
frontend, documentation, and source asset, including explicit evidence for the
unavailable Windows ARM64/x86 host SDKs.

## Configuration and Safety

HapCLI reads private configuration in this order:

1. `~/.hap/config.toml`
2. project `./.hapData/config.toml`
3. project `./happub.toml`, only after a supported project is detected

The Cangjie download route uses `--region`, then `HAP_REGION`, then the
`downloadRegion` TOML key, then locale/timezone signals, and finally `global`.
Supported values are `auto`, `global`, and `zh-cn`:

```toml
downloadRegion = "auto"
```

Device aliases use the same local-first fallback model. Public examples use
synthetic identifiers; do not commit real serial numbers, UDIDs, LAN endpoints,
tokens, receipts, or device-memory files.

Child tool processes default to `no-proxy`. Pass `--proxy` only when the child
should inherit the current shell proxy variables. Review tokens are human
confirmation presence gates, not authentication credentials. HapCLI does not
accept arbitrary shell commands on reviewed execution surfaces.

## Development

```bash
export SDKROOT="$(xcrun --show-sdk-path)"  # macOS only
cjpm build
cjpm test --timeout-each=30s --no-progress --no-color
sh -n release/hapup.sh
sh tests/hapup-security.sh
sh tests/public-surface.sh
sh tests/release-workflow.sh
sh tests/nightly-workflow.sh
```

The GitHub public-surface workflow validates documentation, release metadata,
shell syntax, checksums, and installer security fixtures. A `v*` tag matching
the package version downloads checksum-pinned official Cangjie SDKs and
publishes only binaries that pass native build, tests, and version smoke.

## Documentation

- [Command reference](docs/COMMAND_REFERENCE.md)
- [Architecture](docs/ARCHITECTURE.md)
- [stdx self-learning and doctorfix](docs/STDX_SELF_LEARNING_AND_DOCTORFIX.md)
- [stdx/runtime execution boundary](docs/STDX_RUNTIME_EXECUTION_BOUNDARY.md)
- [Downstream adoption policy](docs/DOWNSTREAM_ADOPTION_POLICY.md)
- [Release process](docs/RELEASING.md)
- [Shell and flagship boundary](docs/SHELL_AND_FLAGSHIP_BOUNDARY_2026-06-07.md)

## Project Boundary

HapCLI is not an official Cangjie or HarmonyOS tool, a package-manager
replacement, a package registry, an SDK version manager, a silent manifest
rewriter, or a guarantee that third-party mirrors and device toolchains are
available.

The full CLI and source code are open under Apache License 2.0. Commercial
support may cover integration, migration, training, deployment assistance, and
service-level commitments; it does not unlock a hidden proprietary edition of
the CLI.

## Contributing and Security

See [CONTRIBUTING.md](CONTRIBUTING.md) before sending a change. Report security
issues through the private process in [SECURITY.md](SECURITY.md), not a public
issue.

## License

HapCLI is released under the [Apache License 2.0](LICENSE). See [NOTICE](NOTICE)
for project attribution.
