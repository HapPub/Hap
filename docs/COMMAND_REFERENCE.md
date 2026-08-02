# HapCLI Command Reference

Run `hap help` for the exact command list supported by the current binary. This
document groups the stable command families; subcommand options remain defined
by the executable.

| Family | Purpose |
| --- | --- |
| `project detect` | Detect Cangjie/cjpm, HarmonyOS, iOS, and KMP project shapes. |
| `device`, `device set` | List relevant devices and manage local aliases/defaults. |
| `build`, `test`, `dev`, `push` | Plan or execute fixed project adapters. |
| `inspect-cjpm`, `plan-switch`, `apply-switch` | Inspect and review CJPM dependency profile changes. |
| `record cangjie.stdx` | Store a reusable stdx target profile from a known-good project. |
| `doctorfix cangjie.stdx` | Plan or apply a backed-up stdx target repair. |
| `doctor stdx`, `doctor runtime` | Diagnose local runtime and stdx path evidence. |
| `bundle` | Diagnose central dependency topology before fixed `cjpm bundle`. |
| `cjpm graph ...` | Discover manifests, diagnose dependency graphs, normalize reviewed copies, and emit CI preflight text. |
| `ci ...` | Diagnose workflows and generate reviewed bootstrap, bridge, executor, and hosted-proof artifacts. |
| `toolchain providers`, `toolchain doctor` | Inspect compatible provider families without switching SDK versions. |
| `get cangjie-stdx`, `get cangjie-sdk` | Emit reviewed acquisition/install plans. |
| `fetch reviewed-recipe` | Write a checksum-gated fetch/deploy recipe without executing it inside HapCLI. |
| `install ...` | Review replacement/restore inputs and read Hapup receipts. |
| `dictionary refresh` | Refresh a local dictionary cache from an explicit source. |
| `release manifest` | Emit current preview release metadata without publishing assets. |

## Output Modes

- Default output is concise and intended for interactive use.
- `-v` or `--verbose` exposes structured execution detail and original tool
  output where supported.
- `--write-receipt` enables the default receipt for supported actions.
- `--receipt <path>` selects an explicit receipt path.
- `--plan` keeps supported adapters read-only.
- `--proxy` explicitly inherits shell proxy variables; `--no-proxy` is the
  default for child tools.

## Review Gates

Commands that write reviewed files or run sensitive fixed adapters may require
`--review-token` and an explicit receipt path. A review token confirms that a
human or controlling process approved the exact inputs. It is not an identity
or authorization system and is never intended to be stored in receipts.
