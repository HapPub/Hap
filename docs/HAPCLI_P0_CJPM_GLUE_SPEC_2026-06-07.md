# HapCLI P0 Cjpm Glue Spec

> Historical design seed. The capability goals remain useful, but command names
> below are mapped to the current `0.1.0` CLI instead of preserving obsolete
> sketches. Use [`COMMAND_REFERENCE.md`](COMMAND_REFERENCE.md) or `hap help` as
> the executable truth.

## Purpose

`HapCLI P0` exists to solve one concrete pain:

`Cangjie/Harmony projects can pass locally but fail in CI/CD or cloud handoff because dependency, stdx, runtime, and mirror truth differ across devices.`

The first anchor case is a Cangjie GitHub CI/CD failure class where local dependency shape and cloud dependency shape diverge.

## P0 Capability Set

### 1. Dependency Profile Inspect

Current command:

```sh
hap inspect-cjpm ./cjpm.toml
```

Expected output:

- current `cjpm.toml` dependency shape
- local `path` dependencies
- remote `git / branch / tag` dependencies
- mixed profile warnings
- inferred profile:
  - `local-dev`
  - `review`
  - `cloud`
  - `release`

### 2. Local / Remote Dependency Switcher

Current commands:

```sh
hap plan-switch ./cjpm.toml ./profiles.toml cloud
hap apply-switch ./cjpm.toml ./profiles.toml cloud \
  --output ./cjpm.cloud.toml \
  --receipt ./.hapData/receipts/switch-cloud.json \
  --review-token reviewed
```

Rules:

- `local-dev` may use local `path` dependencies
- `cloud / review / release` should use remote `git / branch / tag`
- mixed profile requires explicit exception
- every mutation writes a backup and restore receipt

### 3. stdx Doctor And Temporary Repair

Current commands:

```sh
hap doctor stdx --project . --target aarch64-apple-darwin
hap record cangjie.stdx --project . --target aarch64-apple-darwin
hap doctorfix cangjie.stdx --project . --target aarch64-apple-darwin --plan
hap doctorfix cangjie.stdx --project . --target aarch64-apple-darwin --write
```

Rules:

- inspect current stdx/runtime paths
- if a temporary `cjpm.toml` edit is needed for a real build, write:
  - original file backup
  - patched file
  - restore receipt
- restore original file after build unless user explicitly keeps the patch

### 4. Runtime / Extended Runtime Doctor

Current commands:

```sh
hap doctor runtime --project . --target aarch64-apple-darwin
hap get cangjie-sdk --target=ohos-arm64 --version=<version> \
  --provider-url=<reviewed-url> --install-root=<path> --sha256=<sha256>
```

P0 scope:

- detect missing Cangjie runtime
- detect missing stdx runtime path
- provide copyable install guidance
- avoid pretending all platforms are supported before proof

### 5. Region-Aware Source Mirror

Current direction:

```sh
hap dictionary refresh --cache=./.hapData/dictionary.json --source=<reviewed-source>
```

Source-profile switching remains explicit through `plan-switch` and
`apply-switch`; automatic region selection is not a current public claim.

Example:

```toml
# global
WebRuntime = { git = "https://github.com/example/web-runtime.git" }

# cn
WebRuntime = { git = "https://gitcode.com/example/web-runtime-cangjie.git" }
```

Rules:

- use a local dictionary first
- optionally fetch a public dictionary later from GitHub Pages / EdgeOne style endpoints
- network dictionary must be cacheable and overrideable

### 6. Network Dictionary

P0 local-first:

- local dictionary file
- exact source profile id
- checksum or version marker

Later:

- public dictionary endpoint
- cache TTL
- signed or checksum-pinned dictionary

## Safety Contract

Every file mutation must produce:

- original path
- backup path
- mutation reason
- profile before
- profile after
- changed keys
- restore command
- receipt path

No silent mutation.
No irreversible rewrite.
No public claim without proof.

## First Fixture

Use a synthetic local/cloud drift fixture:

- one `cjpm.toml` with local `path` dependency
- one cloud/review profile with remote dependency
- one stdx path drift case
- one restore test

Success:

- inspect detects local-only dependency truth
- switch creates cloud/review-safe dependency shape
- stdx doctor reports actionable state
- restore returns file to original content
- receipt records what happened

## P0 Non-Goals

- no package registry
- no package publish
- no hosted service
- no talent platform
- no full runtime manager
- no `cjvs` implementation in the first proof unless explicitly promoted
- no CI/CD integration beyond making the config shape pushable
