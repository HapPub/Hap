# HapCLI Architecture

HapCLI is one Cangjie executable with a local-first state model and a thin POSIX
bootstrap companion. The implementation is intentionally conservative about
execution: analysis and planning are broad, while mutation and external tool
execution are limited to named adapters.

## Main Layers

### CLI routing

`src/cli_runtime.cj` parses the public command surface and delegates to focused
project, toolchain, device, CI, graph, install, and release modules. `hap help`
is the executable command reference.

### Inspection and planning

Project detection, CJPM profile parsing, dependency-graph diagnosis, stdx
profiles, toolchain providers, CI workflow diagnosis, and release metadata are
read-only by default. Their output is structured so humans and automation can
review the same facts.

The Cangjie-native HarmonyOS inspector is a separate detection lane. It reads
the root app/workspace contract and bounded member manifests, then projects an
HAP/HSP/HAR module graph. Generic Cangjie and hvigor HarmonyOS remain separate
project kinds. The corresponding package-provider surface is contract-first and
plan-only: until a reviewed fixed provider exists, plans report
`package-provider-required` and cannot route into the hvigor/HDC executor.

### Fixed execution adapters

Execution-capable commands construct fixed argv for known tools such as `cjpm`,
`hvigorw`, `hdc`, Gradle, `xcodebuild`, and `xcrun devicectl`. They do not accept
arbitrary shell command text. Semantic output checks are applied when a tool can
return exit code `0` while reporting failure in its output.

The HarmonyOS `prnt` adapter is a strict sequence rather than a generic screen
tool: it requests geometry through `aa start`, resolves the bundle PID, binds
that PID to the WindowManagerService table, captures the resulting display, and
crops only the actual WMS rectangle with a fixed ImageMagick adapter. The
macOS `sips` CLI is intentionally rejected because its ignored offset can make
pixels disagree with the WMS receipt. Requested and actual geometry remain
separate receipt fields.

### Toolchain installation and activation

`hap get cangjie` composes SDK and matching stdx installation, verifies native
compilation/execution and activates a managed shell environment. The lower-level
`hap install cangjie*` interface remains component-only and does not change shell
selection. The older `get cangjie-sdk/stdx` commands remain planners.

`src/sdk_toolchain_get.cj` coordinates Semeru, Android, OpenHarmony and HarmonyOS
installation; `sdk_toolchain_catalog.cj` resolves supported vendor assets, and
`sdk_toolchain_adapters.cj` handles extraction, native checks and launchers.
Provider-specific selections coexist in atomic `~/.hap/env.sh` blocks. Downloads,
checksums and tool verification must pass before activation; failure preserves
the previous selection. `--plan` makes no network requests or writes.
See [SDK/JDK installation](SDK_TOOLCHAINS.md) for host and catalog limits.

### Local private state

Configuration, stdx records, device aliases, receipts, logs, and trusted device
memory prefer `~/.hap`, then project `.hapData`, then a supported-project
fallback file. Public repositories should ignore these files and must not commit
real device or environment evidence.

### Bootstrap and release

`release/hapup.sh` resolves a published release, verifies manifest and asset
checksums, and installs `hap` plus its bootstrap companion with backed-up PATH
hooks. Explicit asset/manifest install and restore interfaces remain available.
It also retains the low-level HarmonyOS Cangjie SDK archive adapter.
`release/manifest.v0.json` records the source preview; it does not prove that
matching binaries or a live-site update have been published. Each GitHub Release
carries a generated manifest containing only assets from successful native jobs.

## Execution Flow

```text
request
  -> project/environment inspection
  -> plan and safety diagnosis
  -> explicit fixed adapter selection
  -> bounded execution
  -> semantic result validation
  -> concise result or structured receipt
```

## Non-Goals

HapCLI is not a general shell runner, package registry, package-manager
replacement, universal SDK manager, workflow mutator, or substitute for platform
signing and device authorization.
