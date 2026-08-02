# Contributing to HapCLI

Thank you for helping improve HapCLI. The project accepts focused fixes,
platform adapters, diagnostics, documentation, tests, and portability work.

## Before You Start

- Search existing issues before opening a new one.
- Keep one pull request focused on one problem.
- Do not include credentials, real device identifiers, UDIDs, LAN endpoints,
  local absolute paths, receipts, device memory, or proprietary project data.
- Do not add arbitrary shell-command execution to reviewed surfaces. New
  execution must use fixed argv, explicit inputs, bounded failure handling, and
  testable result truth.
- Do not strengthen platform claims beyond the proof included in the change.

## Build and Test

HapCLI currently targets Cangjie 1.1.x. On macOS, set `SDKROOT` explicitly:

```bash
export SDKROOT="$(xcrun --show-sdk-path)"
cjpm build
cjpm test --skip-build --timeout-each=30s --no-progress --no-color
sh -n release/hapup.sh
sh tests/hapup-security.sh
sh tests/public-surface.sh
```

Linux contributors can omit `SDKROOT`. Platform-specific changes should include
the strongest reproducible proof available and clearly name any device,
signing, SDK, or host prerequisite that was not verified.

## Pull Requests

Describe:

- the user-visible problem
- the exact behavior changed
- validation commands and results
- files or external state that may be modified
- known limits and unverified platforms

Changes intentionally submitted to this repository are licensed under Apache
License 2.0 unless explicitly stated otherwise.

## Public Language

`README.md`, `README.zh-CN.md`, and `README.ru.md` must keep the same technical
claims even when wording is localized naturally. Update all three when a change
affects quick start, platform status, safety boundaries, or public positioning.
