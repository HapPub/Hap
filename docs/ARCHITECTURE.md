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

### Fixed execution adapters

Execution-capable commands construct fixed argv for known tools such as `cjpm`,
`hvigorw`, `hdc`, Gradle, `xcodebuild`, and `xcrun devicectl`. They do not accept
arbitrary shell command text. Semantic output checks are applied when a tool can
return exit code `0` while reporting failure in its output.

### Local private state

Configuration, stdx records, device aliases, receipts, logs, and trusted device
memory prefer `~/.hap`, then project `.hapData`, then a supported-project
fallback file. Public repositories should ignore these files and must not commit
real device or environment evidence.

### Bootstrap and release

`release/hapup.sh` verifies reviewed assets, installs or restores the flagship
binary, and can deploy a reviewed HarmonyOS Cangjie SDK archive. It remains a
bootstrap companion rather than a second implementation of HapCLI product
logic. `release/manifest.v0.json` is the release-channel truth and is mirrored
to the static Hap.Pub site before publication.

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
replacement, SDK version manager, workflow mutator, or substitute for platform
signing and device authorization.
