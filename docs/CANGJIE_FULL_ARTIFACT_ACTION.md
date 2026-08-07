# Full Cangjie Artifact Action

Use the mirror manifest as the only SDK asset index. Do not reconstruct SDK
URLs or checksums from a tag string in workflow YAML.

## Bootstrap

The repository provides one reviewed bridge:

```bash
bash scripts/ci/bootstrap-cangjie-from-mirror.sh \
  "$RUNNER_TEMP/sdk-manifest/manifest.v1.json" \
  linux-x64 \
  "$RUNNER_TEMP/cangjie-sdk" \
  "$RUNNER_TEMP/cangjie-env.sh" \
  "$RUNNER_TEMP/cangjie-sdk-resolution.json"
source "$RUNNER_TEMP/cangjie-env.sh"
```

The bridge downloads a remote manifest only over HTTPS, validates the complete
mirror schema through resolve-nightly-sdk.py, selects one exact asset and
mirror-computed SHA-256, invokes install-cangjie-sdk.sh, and writes a
machine-readable resolution receipt. It does not mutate the runner's parent
environment; the workflow must source the generated environment file.

## Native Matrix

Use these runner and resolver pairs:

| Runner | Resolver platform | Artifact target |
| --- | --- | --- |
| ubuntu-24.04 | linux-x64 | linux-amd64 |
| ubuntu-24.04-arm | linux-aarch64 | linux-arm64 |
| macos-14 | mac-aarch64 | darwin-arm64 |
| macos-15-intel | mac-x64 | darwin-amd64 |
| windows-2025 | windows-x64 | windows-amd64 |

Each matrix job should run bootstrap, source the environment file, then run
the project's fixed build/test/package command and upload only its own
artifact directory.

## OHOS Cross Lane

On ubuntu-24.04 use resolver platform linux-x64-ohos, install the mirrored
Linux-to-OHOS SDK with the same bridge, install the reviewed OpenHarmony native
sysroot, then run the fixed OHOS ARM64 and AMD64 cross-build commands. Keep the
receipt status cross-built-link-verified unless a real target runtime smoke
has been performed.

## Acceptance

Every job must retain and upload:

- exact SDK tag, asset name, mirror URL and SHA-256 in its resolution receipt;
- build, test and package exit codes;
- artifact SHA-256 and target metadata;
- explicit non-promises for cross builds and unsupported upstream host SDKs.

Do not claim Windows ARM64/x86 native SDK support when the upstream mirror
manifest has no matching host SDK asset. Do not install SDKs into system
directories or append to shell rc files from the workflow.
