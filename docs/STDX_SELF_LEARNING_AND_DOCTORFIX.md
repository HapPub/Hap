# Stdx Self-Learning And Doctorfix

HapCLI treats stdx self-healing as a subject-based record and repair loop:

```bash
hap record --target x86_64-unknown-linux-gnu cangjie.stdx --project . --name linux-static --from-build-success
hap doctorfix --target x86_64-unknown-linux-gnu cangjie.stdx --project . --plan
hap doctorfix --target x86_64-unknown-linux-gnu cangjie.stdx --project . --write
hap build --project . --target x86_64-unknown-linux-gnu
```

The command shape is intentionally generic. `cangjie.stdx` is the subject, so future ecosystems can use the same `record` and `doctorfix` family without inventing a new top-level command for every toolchain.

## Config Path Order

When `--config <path>` is not provided, HapCLI tries config locations in this order:

1. `~/.hap/config.toml`
2. `./.hapData/config.toml`
3. `./happub.toml`, only after the current directory is recognized as a supported Cangjie `cjpm` project

`record` writes to the first usable path. If a preferred location cannot be created or written, it falls back to the next candidate instead of silently failing the whole learning loop.

`doctorfix` reads the first existing candidate. This lets a project-local fallback remain usable on sandboxed hosts where `~/.hap` is unavailable.

## Record

`hap record cangjie.stdx` reads the selected project's `cjpm.toml`, finds the requested target block and `bin-dependencies.path-option`, and appends a reusable profile:

```toml
[[records]]
subject = "cangjie.stdx"
name = "linux-static"
target = "linux-amd64"
sourceTarget = "x86_64-unknown-linux-gnu"
source = "recorded-from-build-success"
sourceManifest = "./cjpm.toml"
compileOption = "-Woff unused -ldl"
linkOption = ""
pathOption = ["${CANGJIE_STDX_PATH}/linux_x86_64_llvm/static/stdx"]
```

`--from-build-success` is a confidence marker supplied by the caller. HapCLI records it, but does not certify the build unless a separate build receipt exists.

## Doctorfix

`hap doctorfix cangjie.stdx --plan` reports the intended repair without mutating `cjpm.toml`.

`hap doctorfix cangjie.stdx --write` rewrites the detected target block from the recorded profile, writes `cjpm.toml.hap-backup`, and writes a receipt under:

```text
./.hapData/receipts/doctorfix-cangjie-stdx.json
```

This is a reviewed manifest repair, not a package-manager action. It does not download stdx, run `cjpm build`, mutate shell rc files, or claim hosted CI adoption.

## Build Wrapper

`hap build` is the narrow execution layer on top of the record/doctorfix loop. It runs fixed `cjpm build` in the selected project and emits a structured receipt at:

```text
./.hapData/receipts/build-cangjie-stdx.json
```

When the first build fails, HapCLI checks the selected config:

```toml
[hap]
alwaysFix = true
verbose = false
```

If `alwaysFix=true` and a matching `cangjie.stdx` record exists, HapCLI applies one `doctorfix --write`, keeps `cjpm.toml.hap-backup`, and retries `cjpm build` once. If `alwaysFix=false`, if no matching record exists, or if the retry still fails, the receipt reports that state without pretending the build succeeded.

`--verbose` or `verbose=true` includes captured stdout/stderr from the underlying `cjpm` calls in the receipt. Without verbose mode, the receipt keeps byte counts and exit codes but does not embed the full tool output.

The wrapper still does not accept arbitrary shell commands, download stdx/runtime assets, mutate workflow files, or certify release readiness.

## Current Boundary

Implemented now:

- subject-based `record cangjie.stdx`
- subject-based `doctorfix cangjie.stdx --plan|--write`
- fixed `hap build` wrapper over `cjpm build`
- `alwaysFix=true` one-shot doctorfix retry loop
- config fallback from home private path to project-local paths
- Linux, OHOS, macOS, and Windows target alias normalization
- backup and receipt on `--write`

Not implemented yet:

- confidence scoring beyond explicit recorded source markers
- automatic stdx download during doctorfix

The next safe layer is confidence and scoring: learn from repeated known-good build receipts, keep author/version/time metadata for reusable records, and only then decide whether a profile should be promoted beyond local config.
