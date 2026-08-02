# HapCLI Cjpm Profile Fixture

## Purpose

This fixture represents a synthetic Cangjie project that works on a local machine but can drift in CI, review, or cloud handoff because dependency and runtime truth are different.

It is synthetic.
It must not contain private paths, credentials, provider details, or real internal repository locations.

## Files

- `cjpm.local.toml`: local-dev starting point with relative `path` dependencies.
- `profiles.toml`: HapCLI profile mapping for local-dev, cloud, review, release, and region mirrors.
- `expected/inspect.json`: expected read-only profile inspection result.
- `expected/switch-cloud.toml`: expected cloud profile output after switching.
- `expected/restore.toml`: expected original content after restore.

## Fixture Story

The local developer version uses relative path dependencies:

- `WebRuntime = { path = "../deps/web-runtime" }`
- `CryptoContract = { path = "../deps/crypto-contract" }`

The cloud/review version should use remote Git dependencies with explicit branch or tag truth.

The fixture also carries a synthetic stdx/runtime expectation so stdx doctor can later report actionable diagnostics without pretending to install or repair anything.

## Acceptance

- no absolute private path
- no token or credential
- valid enough TOML shape for a fixture parser
- local dependency truth and cloud dependency truth are both visible
- restore expectation matches the local starting point

## Next

read-only inspection should implement read-only inspection against `cjpm.local.toml`.
