# HapCLI Command Reference

Run `hap help` for the exact command list supported by the current binary. This
document groups the stable command families; subcommand options remain defined
by the executable.

| Family | Purpose |
| --- | --- |
| `project detect` | Detect generic Cangjie/cjpm, Cangjie-native HarmonyOS package, hvigor HarmonyOS, iOS, and KMP project shapes. |
| `device`, `device set` | List relevant devices and manage local aliases/defaults. |
| `build`, `test`, `dev`, `push` | Plan or execute fixed project adapters. |
| `prnt` | Start a HarmonyOS app at a requested size, bind its PID to WMS, capture the display, and crop the actual window rectangle. |
| `inspect-cjpm`, `plan-switch`, `apply-switch` | Inspect and review CJPM dependency profile changes. |
| `record cangjie.stdx` | Store a reusable stdx target profile from a known-good project. |
| `doctorfix cangjie.stdx` | Plan or apply a backed-up stdx target repair. |
| `doctor stdx`, `doctor runtime` | Diagnose local runtime and stdx path evidence. |
| `bundle` | Diagnose central dependency topology before fixed `cjpm bundle`. |
| `cjpm graph ...` | Discover manifests, diagnose dependency graphs, normalize reviewed copies, and emit CI preflight text. |
| `ci ...` | Diagnose workflows and generate reviewed bootstrap, bridge, executor, and hosted-proof artifacts. |
| `toolchain providers`, `toolchain doctor` | Inspect compatible provider families without switching SDK versions. |
| `get cangjie --version <version>` | Install SDK + matching stdx and activate a verified native toolchain; `--plan` previews, `--no-activate` installs only. |
| `get cangjie-stdx`, `get cangjie-sdk` | Emit reviewed acquisition/install plans. |
| `fetch reviewed-recipe` | Write a checksum-gated fetch/deploy recipe without executing it inside HapCLI. |
| `install cangjie|cangjie-sdk|cangjie-stdx[@version]` | Install checksum-gated official SDK/stdx packages into Hap private storage; `--plan` is read-only. |
| `install doctor|replace-plan|restore-plan|receipt-readback` | Review replacement/restore inputs and read Hapup receipts. |
| `dictionary refresh` | Refresh a local dictionary cache from an explicit source. |
| `release manifest` | Emit current preview release metadata without publishing assets. |

See [installation](INSTALLATION.md) for `hapup install` and complete toolchain setup.

## Cangjie Download Routes

For stable/LTS package installation:

```bash
hap install cangjie@latest --target macos-arm64 --region auto
hap install cangjie-stdx@1.1.3 --target macos-arm64 --region zh-cn
hap install cangjie@nightly --target macos-arm64 --route auto
hap install cangjie@1.3.0-alpha.20260828010050 --target macos-arm64 --route mirror
hap install cangjie-sdk@1.1.3 --target macos-arm64 --route auto
hap install cangjie-sdk@1.1.3 --target macos-arm64 --route mirror
hap install cangjie-sdk@1.1.3 --target linux-amd64 --plan
```

In the lower-level `hap install` command, `cangjie` resolves to `cangjie-sdk`. Omitted/latest/lts is pinned to `1.0.5`
LTS; `1.1.3` is an exact STS request. `nightly` dynamically resolves the newest
validated prerelease, and an exact bounded nightly tag remains reproducible.
SDK and stdx use separate assets and
completion markers. The default root is `~/.hap/toolchains`. An explicit root
must remain under `HOME/.hap` or an OS temporary directory,
and a custom receipt must remain inside that root. `global` tries the HapPub
byte-preserving mirror before the official source; `zh-cn` prepends only
the built-in allowlisted accelerator URLs, then tries the direct mirror and
official source. Every candidate must match the same pinned SHA-256.

The exact terminal command `hap install cangjie` opens a three-stage keyboard
TUI: LTS/STS/current-nightly version, observed route latency/selection, and final private-install
confirmation. Its probes use fixed HTTPS HEAD requests with bounded connect and
total timeouts. `Automatic` picks the lowest observed latency among successful
reviewed routes. Choosing a named route forces exactly that URL, even if its
probe was unreachable; the subsequent bounded download remains the real
availability check. Cancelling after probes records that network observation
while keeping archive download, extraction, and system/project/rc mutations
false.

`--route auto` provides the same bounded fastest-success selection for a
non-interactive install. `--route mirror|ghfast|ghproxy|official` forces one
exact route and disables fallback. `--route` and `--region` are mutually
exclusive. `--plan` never probes. Latency values and acceleration never become
checksum authority.

Dynamic discovery first accepts the schema-gated supplementary dictionary at
`https://cli.hap.pub/manifests/cangjie-install-v1.json`, then falls back to the
live HapPub mirror release index. A successful HTTP response with the wrong
schema, including the website HTML fallback, is rejected. The exact selected
release `manifest.v1.json` must then provide the target asset and SHA-256 before
any route probe or archive download. `--plan` performs none of these requests.

`hap get cangjie-sdk` and `hap get cangjie-stdx` resolve a transport and emit a
non-executing plan. Region precedence is:

```text
--region > HAP_REGION > downloadRegion in Hap TOML > locale/timezone > global
```

- `global`: GitHub `HapPub/CangjieSDK-Mirror` first, GitCode original second.
- `zh-cn`: GitCode original first, GitHub mirror second.
- `auto`: continue through the precedence list.
- `--provider-url`: use only that custom provider; no regional fallback.

The built-in routes refer to the mirror `manifest.v1.json` for SHA-256 evidence.
The plan does not fetch the manifest, download an archive, install a runtime, or
claim that a mirrored target has passed a Hap build.

## Cangjie Build Bootstrap

`hap build --project . --target <target>` is the executing flagship surface.
It enables automatic Cangjie SDK/stdx bootstrap by default when `cjpm` is
missing or the first fixed build reports a target-toolchain failure. The
bootstrap uses only the built-in mirror contract, installs into Hap private
cache, injects environment into the build child only, and performs at most one
classified build retry.

```text
--toolchain-bootstrap | --no-toolchain-bootstrap
--sdk-version <tag>
--region auto|global|zh-cn
--download-acceleration auto|off
--toolchain-cache-root <path>
--accelerator <allowlisted-url>   # repeatable
```

Config keys additionally expose `toolchainBootstrapTimeoutSeconds`,
`toolchainDownloadRetryCount`, and `downloadAccelerators`. Public accelerators
are transport candidates only; manifest SHA-256 remains the authority. A cache
hit requires version-and-checksum-bound completion markers but does not re-hash
all extracted files on every build. OpenHarmony native sysroot, signing,
runtime, and device proof remain separate prerequisites.

## Cangjie-Native HarmonyOS Package Workspaces

`hap project detect` recognizes a pure Cangjie HarmonyOS workspace when its
root `cjpm.toml` contains `[app]`, `[workspace]`, and
`runtime-OS = "HarmonyOS"`. It reads `build-members` (or `members` as a
fallback), rejects member paths that could escape the project root, and reports
member `[hap]`, `[hsp]`, and `[har]` tables as a module graph.

```bash
hap project detect --project . --platform cangjie-harmonyos
hap build --project . --platform cangjie-harmonyos --plan
```

The build plan names three fixed provider stages: `inspect`, `cjpm build`, and
`package`. It returns `ok=false`, `status=package-provider-required`, and
`executionAvailable=false`; the provider commands are templates, not executed
argv. `--execute-reviewed` also fails closed for this adapter. Package byte
generation, signing, HDC installation, launch, and external provider adoption
require separate implementation and acceptance.

## HarmonyOS Window Capture

`hap prnt` is an execution-evidence helper for responsive layouts. It always
handles the window before the screenshot:

```text
validate explicit device and layout
-> force-stop the configured bundle unless --keep-running is set
-> aa start with --wl/--wt/--ww/--wh
-> pidof the configured bundle
-> query WindowManagerService
-> snapshot the WMS display
-> receive the full display
-> crop the PID-bound WMS rectangle
-> write receipt.json
```

Examples:

```bash
hap prnt --project . --device my-pc \
  --layoutType Phone --ratio 18:9 --plan

hap prnt --project . --device 192.0.2.40:5555 \
  --layoutType Tablet --ratio Fold4:3 \
  --left 100 --top 100 --output-dir ./.hapData/prnt/tablet-fold

hap prnt --project . --device my-pc \
  --layoutType PC --ratio trible \
  --width 2400 --height 900
```

`--layoutType Family/Variant` is accepted as a shorthand, for example
`Phone/21:9`, `Tablet/Fold√2:1`, or `PC/2in1`.

| Family | Variants | Default requested pixels |
| --- | --- | --- |
| Phone | `16:9`, `18:9`, `21:9` | `516x918`, `516x1032`, `516x1204` |
| Tablet/Fold | `Fold4:3`, `Fold√2:1`, `Fold1.15:1` | `1200x900`, `1273x900`, `1035x900` |
| Tablet | `16:9`, `3:2`, `7:5` | `1600x900`, `1350x900`, `1260x900` |
| PC | `2in1` | `1440x900` |
| PC | `trible` | No guessed ratio; requires `--width` and `--height`. |

Supplying both `--width` and `--height` overrides a preset's default pixels.
The receipt keeps both the requested rectangle and the actual WMS rectangle;
the actual rectangle is always used for cropping. `--cropper auto` selects the
fixed ImageMagick `magick` adapter. Current macOS `sips` is rejected before any
device action because its CLI ignores the requested crop offset and can emit a
centered image that contradicts the WMS receipt. Arbitrary crop commands are
not accepted.

By default, `prnt` force-stops the configured bundle before `aa start`; a cold
ability launch is required for the requested geometry to take effect reliably.
Use `--keep-running` (alias `--no-force-stop`) only for a second capture after
automation has navigated the already-sized application to a specific UI state.
The receipt exposes `appRestartRequested` and `appForceStopTaken`.

The `aa` window arguments are platform-constrained: they require a 2in1 device
in developer mode and a debug-signed application. The external screenshot is a
crop of a full-display capture, so another window can still occlude the target.
The result is execution evidence, not visual acceptance or release approval.

`prnt` executes each fixed HDC argv in the foreground. This avoids an observed
HDC server failure when the client is backgrounded by a shell timeout wrapper.
For this lane, `--timeout-seconds` remains visible in the receipt as the
requested bound, while `hdcTimeoutEnforced=false` states that HapCLI does not
apply an outer process timeout. HDC transport behavior remains the stopline;
other HapCLI device/build executors keep their existing timeout policies.

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

`get jdk|semeru|android|ohos|openharmony|harmonyos` performs native SDK installation, verification and optional activation. See [SDK and JDK commands](SDK_TOOLCHAINS.md) for exact options and upstream availability. `--plan` performs no network or writes; Windows/foreign targets are plan-only.

## Installer and SSH host commands

See [Host tools](HOST_TOOLS.md) for `hap get nsis|wix`, `hap installer inspect`, `hap get ssh`, and `hap ssh --pair|conn|peers|revoke|forget|doctor`, including prerequisites and execution limits.
