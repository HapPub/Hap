# Stdx And Runtime Execution Boundary

HapCLI is package-management-adjacent glue, not a hidden package manager.

## Roles

- `hap`: inspect, plan, diagnose, emit reviewed recipes and receipts, and run
  the explicit checksum-gated `install cangjie|cangjie-sdk|cangjie-stdx`
  package surface inside Hap private storage.
- `hapup`: bootstrap or install reviewed assets after checksum and review gates.
- hosted CI / sandbox shell: execute reviewed scripts and upload receipts after workflow review.
- `cjpm`: remains the build tool; HapCLI does not replace it.

## Rules

- `hap fetch reviewed-recipe` emits reviewed bash text only.
- Passing `--execute` or `--run` to `hap fetch reviewed-recipe` is rejected with `direct-execute-not-supported`.
- `hap install cangjie*` is a separate explicit package transaction. It accepts
  only supported package/version/target inputs, requires SHA-256 authority,
  uses a Hap-private or OS-temporary install root, and writes structured action
  truth. `--plan` performs no catalog lookup, download, extraction, or write.
- Fetch/deploy receipts must record source URL, target, version, checksum status, install root, and mutation truth.
- `cjpm.toml` mutation is separate from stdx/runtime fetch/deploy.
- Global SDK paths are not mutated by default.

## Non-Promises

- no SDK version manager
- no official package-manager status
- no silent online lookup
- no install through `get`, `doctor`, or `fetch reviewed-recipe`; package bytes
  are installed only through an explicit `hap install cangjie*` request
- no release certification from a fetch/deploy receipt alone

## Complete user installation

Starting with 0.2.0, an explicit `hap get cangjie --version <version>` request
installs both SDK and stdx, verifies a native compile/run, and changes the user's
managed shell selection. This higher-level command owns activation; the separate
`get cangjie-sdk/stdx` planners and lower-level package installs retain their
existing behavior. `--plan` takes no network or filesystem action and
`--no-activate` leaves shell defaults unchanged. See [installation](INSTALLATION.md).
