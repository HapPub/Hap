# HapCLI Downstream Adoption Policy

HapCLI adoption is intentionally staged. A downstream project with a green CI
chain should not replace that chain by default.

This policy defines the minimum ladder for using HapCLI in another project.

## Adoption Levels

| Level | Name | Allowed action | Required approver | Required receipts |
| --- | --- | --- | --- | --- |
| L0 | Read-only diagnosis | Run `hap ci action-doctor`, `hap install doctor`, `hap cjpm pipeline plan`, or graph doctors without writing workflow files. | Project maintainer or CI owner awareness. | Command JSON/log retained in CI or review notes. |
| L1 | Non-mutating preflight | Add a disposable or optional CI job that runs HapCLI diagnosis/bridge recipes without changing the existing green build path. | Project maintainer review. | Preflight log plus project bridge receipt when a bridge script is run. |
| L2 | Reviewed bootstrap/executor proof | Use reviewed `hapup` bootstrap, executor recipe, and project bridge scripts in a proof job or disposable branch. | Project maintainer and release/CI owner review. | Bootstrap log, executor receipt, project bridge receipt, and uploaded artifact bundle. |
| L3 | Optional workflow insertion | Insert HapCLI preflight into the normal workflow as a non-blocking or bounded blocking check. | Downstream owner approval. | PR review, rollback plan, receipts from at least one successful hosted run. |
| L4 | Release-gated replacement | Replace part of the existing green dependency/toolchain setup with a HapCLI-managed reviewed chain. | Downstream owner plus release owner approval. | Repeated hosted receipts, rollback proof, release gate approval, and documented stop-loss. |

## Stop-Loss Rules

- If a current hosted workflow is green, start at L0 or L1.
- If HapCLI output conflicts with a known-green workflow, keep the green workflow as canonical until a maintainer accepts the HapCLI evidence.
- If bootstrap, executor, or bridge receipts are missing, do not claim adoption.
- If a generated script mutates files outside the declared project or install root, stop and discard the run.
- If a hosted run fails for environment limits, keep the receipt as blocker evidence instead of rewriting history as success.

## Rollback Rules

- L0 has no rollback because it is read-only.
- L1 rollback is removing the optional preflight job or proof branch.
- L2 rollback is deleting the proof job, generated scripts, and temporary install/cache roots.
- L3 rollback must be one PR revert or workflow-file restore.
- L4 rollback must restore the last green dependency/toolchain path and keep the failed receipts for audit.

## Receipt Requirements

Minimum hosted adoption bundle:

- bootstrap log or bootstrap receipt proving how `hap` became available
- executor receipt when `hap ci executor-recipe` is used
- project bridge receipt when `hap ci project-bridge-recipe` is used
- cache or fetch receipt when dictionary/runtime/stdx refresh is involved
- workflow diff or proof-branch ref for any workflow insertion

## Non-Promises

- This policy does not certify a downstream release.
- This policy does not replace a downstream maintainer's approval.
- This policy does not make HapCLI an official package manager.
- This policy does not require projects with green CI to adopt HapCLI.
