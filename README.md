<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-HapCLI-c96b2c?style=for-the-badge&labelColor=1f2430" alt="Cangjie HapCLI" />
  <img src="https://img.shields.io/badge/source-0.3.0-3182ce?style=for-the-badge&labelColor=1f2430" alt="Source 0.3.0" />
  <img src="https://img.shields.io/badge/mode-local--first-2f855a?style=for-the-badge&labelColor=1f2430" alt="Local first" />
  <img src="https://img.shields.io/badge/focus-toolchain%20glue-805ad5?style=for-the-badge&labelColor=1f2430" alt="Toolchain glue" />
  <img src="https://img.shields.io/badge/license-Apache--2.0-d69e2e?style=for-the-badge&labelColor=1f2430" alt="Apache License 2.0" />
</p>
<div align="center">
<span style="font-weight:300;font-size:38px">HapCLI</span><br/>
<span style="font-weight:100;font-size:24px">Local-first toolchain compatibility and repair</span>
<p align="center">
  <strong>Inspect first, plan the repair, execute fixed adapters, keep the receipt.</strong><br/>
  <sub>Cangjie · Semeru JDK · Android SDK · OpenHarmony · HarmonyOS · KMP</sub>
</p>
</div>

**English** | [简体中文](README.zh-CN.md) | [Русский](README.ru.md)

## What is HapCLI

HapCLI is an open-source command-line compatibility layer for projects whose
toolchain configuration changes between a developer machine, CI, a cloud host,
or a connected device. It installs Cangjie and SDK/JDK toolchains and supports
Cangjie/cjpm, HarmonyOS application development, and Kotlin Multiplatform workflows.

HapCLI does not replace `cjpm`, Gradle, Xcode, DevEco Studio, `hdc`, or a package
manager. It detects project and environment facts, produces reviewable plans,
executes a bounded set of fixed tool adapters, and records structured results.

See the [capability matrix](docs/CAPABILITIES.md) for implementation status, verified hosts and known limitations. Host-tool commands require Python 3.11+; SSH pairing also requires OpenSSH and OpenSSL.

## Quick Start

This README describes **source version 0.3.0**. Downloadable versions and host
assets are listed on [GitHub Releases](https://github.com/HapPub/Hap/releases).
A source version badge does not mean that a matching binary has been published.

With Hapup 0.2.0 or newer, install the latest published HapCLI release:

```bash
hapup install
hap version
```

Hapup source now supports [adaptive download routes](docs/INSTALLATION.md#download-routes): automatic throughput probing, Mainland accelerators, low-speed fallback, and `--region global|zh-cn` / `--route` overrides. Use the updated script; older release assets are unchanged.

For a first installation, see [installing HapCLI](docs/INSTALLATION.md).
If the published binary predates the commands below,
[build this checkout](docs/INSTALLATION.md#build-from-source).
Complete Cangjie installation requires HapCLI 0.2.0 or newer; SDK/JDK installation
requires **0.3.0 or newer**.

The build compiler can be selected independently: see [Cangjie 1.0.5 / 1.1.3 releases](docs/RELEASING.md#selecting-a-toolchain-qualified-release). Keep bundled runtime files when extracting a release manually.

### Install a toolchain

```bash
hap get cangjie --version sts
# Exact version: hap get cangjie --version 1.1.3
hap get jdk --provider semeru --version 17
hap get android --version 36 --accept-licenses
hap get ohos --version 6.0 --profile native
```

Cangjie `sts` installs SDK **1.1.3** and matching stdx **1.1.3.1**, including their
separate release tags. Each installer downloads and verifies its packages,
checks the installed tools, and activates a private environment after verification.
New terminals load it automatically; use the returned `activationHint` in the
current terminal. `--plan` makes no network requests or writes;
`--no-activate` installs without changing the active selection.

The SDK/JDK commands execute on **native macOS/Linux**; Windows and foreign
hosts are plan-only. Catalog coverage differs by provider. For example,
HarmonyOS's built-in catalog currently covers **Linux x64**:

```bash
hap get harmonyos --version 5.1.0.840 --accept-licenses
```

Other HarmonyOS hosts/releases require an official archive or HTTPS URL plus
SHA-256. Read the vendor terms before using `--accept-licenses`.
See [SDK/JDK installation](docs/SDK_TOOLCHAINS.md) for Android NDK/CMake,
provider coverage, private Java launchers and environment coexistence.

### Inspect a project

```bash
hap project detect --project .
hap toolchain providers
hap help
```

## Core Capabilities

- Detect generic Cangjie/cjpm, Cangjie-native HarmonyOS package workspaces,
  hvigor HarmonyOS, iOS, and Compose Multiplatform project shapes.
- Inspect Cangjie-native HarmonyOS `[app]` / `[workspace]` manifests and expose
  their HAP/HSP/HAR module graph before any package provider is selected.
- Inspect `cjpm.toml` dependency profiles and diagnose local `path` versus
  remote `git` drift.
- Record a known-good stdx target profile and plan or apply a backed-up repair
  in another project.
- Run fixed `cjpm build` and `cjpm bundle` actions with bounded environment
  diagnosis, one reviewed repair attempt, and central-repository dependency
  ordering guidance.
- Install a complete Cangjie SDK/stdx pair with `hap get cangjie`, including
  compile/run verification and backed-up shell activation. Component-level
  `hap install cangjie*` keeps its install-only contract without shell changes.
- Install Semeru JDK, Android SDK with optional NDK/CMake, OpenHarmony SDK and
  HarmonyOS Command Line Tools with checksums, native-tool checks and independent
  managed environments. Availability depends on the provider and host.
- Build, install, launch, and verify HarmonyOS applications through fixed
  `hvigor` and `hdc` commands.
- Start a debug-signed HarmonyOS window at a named Phone/Tablet/Fold/PC layout,
  verify its actual PID-bound WMS rectangle, and crop a structured screenshot
  receipt from the full display.
- Remember reviewed HarmonyOS device aliases and recent USB-proven wireless
  endpoints without scanning the local network.
- Run Compose Multiplatform desktop applications and build/install/launch iOS
  applications when the host already has valid Apple signing assets.
- Diagnose GitHub Actions, generate reviewed CI recipes, and keep workflow
  mutation outside the CLI.
- Keep normal output concise; use `-v` or `--verbose` for structured execution
  details and `--write-receipt` for an explicit automation/CI handoff.

## Common Workflows

### Cangjie and stdx

```bash
hap inspect-cjpm ./cjpm.toml
hap record cangjie.stdx --project . --target x86_64-unknown-linux-gnu
hap doctorfix cangjie.stdx --project . --target x86_64-unknown-linux-gnu --plan
hap build --project . --target x86_64-unknown-linux-gnu
hap bundle --project . --skip-lint
hap install cangjie@latest --target macos-arm64 --region auto
hap install cangjie-sdk@1.1.3 --target linux-amd64 --region global
hap install cangjie-stdx@1.1.3 --target macos-arm64 --region zh-cn
hap install cangjie@nightly --target macos-arm64 --route auto
hap install cangjie@latest --target macos-arm64 --plan
hap get cangjie-sdk --target linux-amd64 --version <nightly-tag> --region auto --install-root "$HOME/.hap/runtimes"
hap get cangjie-stdx --target linux-amd64 --version <nightly-tag> --region auto --install-root "$HOME/.hap/stdx"
```

In the component-level `hap install` interface, `cangjie` is an alias for
`cangjie-sdk`; `cangjie-stdx` remains a separate
package. An omitted version, `@latest`, or `@lts` resolves to the pinned latest
LTS (`1.0.5`); `@1.1.3` remains the exact STS line. `@nightly` dynamically
resolves the newest validated prerelease, while an exact bounded nightly tag
such as `@1.3.0-alpha.20260828010050` remains reproducible. Installs default to
`~/.hap/toolchains`; explicit roots are restricted to `HOME/.hap` or an OS
temporary directory. `--plan` performs no download or filesystem write.

Run the exact command `hap install cangjie` in a terminal to open the
interactive installer. It lets you choose LTS, STS, or the currently resolved
nightly, measures the current
HTTPS latency of the reviewed mirror, Mainland accelerators, and official
source, then offers automatic-fastest or one forced route before final
confirmation. A failed probe is displayed as unreachable, not as a fabricated
latency. Scripts, redirected input, explicit package versions, and `--plan`
remain non-interactive. Scripts and CI can use
`--route auto|mirror|ghfast|ghproxy|official`; an exact forced route never
silently falls back. Probe timing is transport evidence only and never replaces
the pinned SHA-256 authority.

The two older `get` commands remain plan-only acquisition surfaces. Real
nightly installs are now available through `install`, and `--plan` deliberately
reports pending dynamic resolution without contacting the network. HapCLI treats
`https://cli.hap.pub/manifests/cangjie-install-v1.json` as a schema-gated
supplementary dictionary, then falls back to the live HapPub mirror index when
the dictionary is absent, stale, or is a website fallback rather than JSON.
The selected release's exact `manifest.v1.json` remains the asset and SHA-256
authority. For stable/LTS installs, `global` routes to the byte-preserving
[CangjieSDK-Mirror](https://github.com/HapPub/CangjieSDK-Mirror) first, while
`zh-cn` prepends allowlisted acceleration prefixes to the same mirror, then
falls back to the direct mirror and official source. Accelerators never become
checksum authorities.

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
hap prnt --project . --device demo-pc --layoutType Phone --ratio 18:9 --plan
hap prnt --project . --device demo-pc --layoutType Tablet/Fold4:3
```

Pure Cangjie HarmonyOS workspaces are reported as `cangjie-harmonyos`, distinct
from hvigor projects and ordinary Cangjie packages:

```bash
hap project detect --project ./native-harmony-app
hap build --project ./native-harmony-app --platform cangjie-harmonyos --plan
```

The detector reads the root `[app]` and `[workspace]` tables plus member
`[hap]`, `[hsp]`, and `[har]` tables. Packaging is deliberately fail-closed:
the build plan returns `package-provider-required` until a separately reviewed,
fixed-argv provider with structured receipts is available. HapCLI does not
silently adopt an external packager, generate HAP bytes, sign, install, or
launch from this plan-only surface.

`hap dev` auto-selects the workflow when exactly one supported project type is
present. Use `--platform` only for mixed or ambiguous directories.

`hap prnt` resolves and requests the window size before it queries WMS and
captures the display. Phone supports `16:9`, `18:9`, and `21:9`; Tablet/Fold
supports `Fold4:3`, `Fold√2:1`, `Fold1.15:1`, `16:9`, `3:2`, and `7:5`; PC
supports `2in1`. The literal `trible` profile is accepted only with explicit
`--width` and `--height`, so HapCLI does not invent a ratio. See the
[command reference](docs/COMMAND_REFERENCE.md#harmonyos-window-capture) for
platform and screenshot-ownership limits.

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
| SDK/JDK installation | Native macOS/Linux execution; Windows/foreign hosts plan-only | Provider availability below is separate from HapCLI binary availability. |
| IBM Semeru JDK | GitHub Release installation; macOS ARM64 Java compile/run verified | Requires a matching Open Edition JDK asset; not universal Gradle compatibility. |
| Android SDK/NDK/CMake | macOS Intel/ARM and Linux x64 catalog; controlled integration verified | Real upstream download acceptance remains incomplete; vendor terms and compatible Java are required. |
| OpenHarmony SDK | 6.0 catalog for macOS Intel/ARM and Linux x64; macOS ARM64 native/full verified | SDK 6.0.0.47 / API 20; target-object compilation does not prove device execution. |
| HarmonyOS Command Line Tools | Built-in Linux x64 5.1.0.840 catalog; official archive/URL override | Current macOS live-package acceptance remains incomplete; other hosts/releases require official assets and SHA-256. |
| Cangjie/cjpm on macOS arm64 | Source, tests, and tag release lane verified | Current Cangjie 1.1.3 static runtime objects require macOS 13.3 even when the linker target is lower. |
| Cangjie/cjpm on Linux AMD64/ARM64 | Tag release lanes available | Each release is published only after the native runner builds, tests, and smoke-checks its binary. |
| Windows AMD64 | Included in both toolchain-qualified release builds | Requires native tests and extracted ZIP smoke; SDK installation remains plan-only. |
| macOS Intel | Nightly native build lane | No native SDK in the stable 1.0.5/1.1.3 catalog; matching nightly SDK required. |
| OHOS ARM64/AMD64 | Nightly cross-build and link verification available | The artifacts are not runtime-smoked on an OHOS device and require a compatible target Cangjie runtime. |
| Windows ARM64/x86 | Upstream gap recorded | The mirrored Cangjie release has no matching native host SDK, so HapCLI does not relabel another architecture as support. |
| HarmonyOS applications | Real build/install/launch workflow available | Requires a working DevEco toolchain, authorized device, and valid signing profile. |
| Cangjie-native HarmonyOS packages | Detection, HAP/HSP/HAR module graph, and provider plan available | Package generation remains fail-closed until a reviewed fixed provider is integrated. |
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

For Cangjie projects, `hap build --target ohos` enables a flagship-only
toolchain bootstrap by default. If `cjpm` or the selected target stdx is not
available, Hap resolves one exact SDK/stdx pair from the mirror manifest,
checks downloaded archives against its SHA-256 values, installs them under a
private cache, and exposes them only to the fixed build child process:

```toml
toolchainAutoBootstrap = true
cangjieSdkVersion = "auto"
toolchainCacheRoot = "/absolute/path/to/hap-toolchains"
toolchainBootstrapTimeoutSeconds = 900
toolchainDownloadRetryCount = 2
downloadAcceleration = "auto"
downloadAccelerators = ["https://ghfast.top/", "https://ghproxy.link/"]
```

Use `--no-toolchain-bootstrap` to disable it. SDK/stdx bootstrap does not
install or prove the OpenHarmony native sysroot, signing assets, runtime, or
device acceptance.

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

- [HapCLI and Cangjie installation](docs/INSTALLATION.md)
- [SDK and JDK installation](docs/SDK_TOOLCHAINS.md)
- [Command reference](docs/COMMAND_REFERENCE.md)
- [Architecture](docs/ARCHITECTURE.md)
- [stdx self-learning and doctorfix](docs/STDX_SELF_LEARNING_AND_DOCTORFIX.md)
- [stdx/runtime execution boundary](docs/STDX_RUNTIME_EXECUTION_BOUNDARY.md)
- [Downstream adoption policy](docs/DOWNSTREAM_ADOPTION_POLICY.md)
- [Release process](docs/RELEASING.md)
- [Shell and flagship boundary](docs/SHELL_AND_FLAGSHIP_BOUNDARY_2026-06-07.md)

## Project Boundary

HapCLI is not an official Cangjie or HarmonyOS tool, a package-manager
replacement, a package registry, a universal SDK manager, a silent manifest
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

## Installer engines and LAN SSH

`hap get nsis|wix` installs an explicitly selected, checksum-pinned engine pack into private storage. `hap get ssh` prepares the client; explicit Windows server setup uses a selected Private LAN interface. `hap ssh --pair` and `hap ssh conn` enroll independent keys over certificate-bound TLS and pin the SSH host key. Python 3.11+, OpenSSH and OpenSSL prerequisites, examples, revocation and current platform limits are documented in [Host tools](docs/HOST_TOOLS.md).
