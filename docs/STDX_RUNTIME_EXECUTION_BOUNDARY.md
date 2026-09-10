# Stdx And Runtime Execution Boundary

HapCLI is package-management-adjacent glue, not a hidden package manager.

## Roles

- `hap`: inspect, plan, diagnose and emit recipes/receipts; install components
  through `install cangjie|cangjie-sdk|cangjie-stdx`, or complete toolchains through
  `get cangjie` and the SDK/JDK installers, with checksum and verification gates.
- `hapup`: install published HapCLI releases with checksum verification and PATH
  setup; retain explicit low-level asset/manifest and restore interfaces.
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
- System SDK files and project requirements remain unchanged. Explicit complete
  toolchain installation may update the managed user shell selection after checks;
  component-only installation does not change that selection.

## Non-Promises

- no universal SDK manager or official package-manager status
- no network lookup or mutation in `--plan`
- no installation through the older `get cangjie-sdk/stdx` planners, `doctor`, or
  `fetch reviewed-recipe`; an explicit `hap install cangjie*` request installs
  components, while `hap get cangjie` and the SDK/JDK commands install and may activate
  complete toolchains
- no release certification from a fetch/deploy receipt alone

## Complete user installation

Starting with 0.2.0, an explicit `hap get cangjie --version <version>` request
installs both SDK and stdx, verifies a native compile/run, and changes the user's
managed shell selection. This higher-level command owns activation; the separate
`get cangjie-sdk/stdx` planners and lower-level package installs retain their
existing behavior. `--plan` takes no network or filesystem action and
`--no-activate` leaves shell defaults unchanged. See [installation](INSTALLATION.md).

Starting with 0.3.0, `hap get jdk|semeru|android|ohos|openharmony|harmonyos` adds
provider-specific SDK/JDK installation with independent environment selections.
These commands execute only on native macOS/Linux; Windows/foreign targets are
plan-only. See [SDK/JDK installation](SDK_TOOLCHAINS.md) for availability and checks.
