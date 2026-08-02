# Stdx And Runtime Execution Boundary

HapCLI is package-management-adjacent glue, not a hidden package manager.

## Roles

- `hap`: inspect, plan, diagnose, emit reviewed recipes, emit receipts, and reject direct stdx/runtime execution requests.
- `hapup`: bootstrap or install reviewed assets after checksum and review gates.
- hosted CI / sandbox shell: execute reviewed scripts and upload receipts after workflow review.
- `cjpm`: remains the build tool; HapCLI does not replace it.

## Rules

- `hap fetch reviewed-recipe` emits reviewed bash text only.
- Passing `--execute` or `--run` to `hap fetch reviewed-recipe` is rejected with `direct-execute-not-supported`.
- Fetch/deploy receipts must record source URL, target, version, checksum status, install root, and mutation truth.
- `cjpm.toml` mutation is separate from stdx/runtime fetch/deploy.
- Global SDK paths are not mutated by default.

## Non-Promises

- no SDK version manager
- no official package-manager status
- no silent online lookup
- no hidden runtime/stdx install inside flagship `hap`
- no release certification from a fetch/deploy receipt alone
