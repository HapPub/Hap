# Installing HapCLI and Cangjie

`hapup install` and complete `hap get cangjie` installation require version
**0.2.0 or newer**. The SDK/JDK commands require HapCLI **0.3.0 or newer**.
Check `hap version` before using them. A source checkout or local build does not
publish a GitHub release; `hapup install` selects only a release that actually exists there.

## Install HapCLI itself

With a verified Hapup 0.2.0 or newer downloaded from a published release:

```sh
sh hapup.sh install
# Subsequent updates:
hapup install
hap version
```

Use `hapup install --version VERSION` to select an exact **published** version.
Replace `VERSION` with a release tag's version; this does not install a source branch.
If the available release predates the feature you need, build from source below.

An omitted action also installs. The installer detects the host, resolves the
latest release once and pins its tag, verifies the manifest's SHA-256 and the
selected archive's SHA-256, then installs `hap` and `hapup` into `~/.local/bin`.
It keeps a replacement receipt and uses the existing binary backup/restore
mechanism. It adds an idempotent PATH line to `.profile`, `.bashrc`, and `.zshrc`,
also updating an existing Bash login profile and preserving original files as `.hap-backup`. Use `--no-path` to skip those hooks.
The current shell cannot inherit changes from a child process: use the printed
PATH command immediately, or open a new terminal. Only targets with a published
binary can be installed. Checksums establish consistency with the HTTPS release;
they are not an independent signature of the publisher.

`--target` and `--install-dir` select a different published target or user
location. Advanced `install-from-manifest` and `install-flagship` commands remain
available, with their explicit checksum and review-token contracts.

For the two compiler builds, see [toolchain-qualified releases](RELEASING.md#selecting-a-toolchain-qualified-release).
A release may carry runtime libraries required by its build compiler. Hapup copies
the content-addressed macOS runtime directory before validating the new binary and
retains prior directories for backup/restore. If installing an archive manually,
keep its entire `bin` directory; copying only `hap` or `hap.exe` may lose required
libraries. Windows ZIP installation is manual; the POSIX bootstrap is not a
PowerShell installer.

## Download routes

Updated Hapup source supports automatic international/Mainland download routing:

```sh
hapup install                         # auto-detect actual route performance
hapup install --region zh-cn          # include Mainland accelerators
hapup install --region global         # direct international route only
hapup install --route ghfast          # force one archive route; no route fallback
hapup install --route ghproxy
hapup install --route direct
```

`--region auto` is the default. For checksum-pinned public HapPub release assets,
Hapup compares direct GitHub, `ghfast.top`, and `ghproxy.link` concurrently. Archive
probes sample at most 64 KiB per route within four seconds and prefer measured
throughput; small metadata uses response time. Unsupported probes remain download
fallbacks. During transfer, a route below 16 KiB/s for 15 seconds is abandoned.
Network failures or incorrect bytes try the next eligible route. A forced route
fails without silently switching. Probe results are temporary network observations.

`HAPUP_REGION` and `HAPUP_ROUTE` provide defaults, including advanced installation
commands; command-line flags override them. Invalid values and conflicting global/
accelerator settings fail before network activity. HTTPS downloads require curl.
Existing proxy environment variables are respected; local curl configuration files
are not loaded. No proxy or shell configuration is changed by route selection.

Release discovery and checksum sidecars remain on the publisher's HTTPS origin.
Only assets with a known SHA-256 use accelerators; arbitrary hosts and URLs with
query strings or fragments remain direct. If GitHub metadata is unreachable,
choose an exact `--version` to skip discovery; trusted checksum retrieval is still
required. The installer reports attempts and records the final archive region,
route and attempt count in `hap-install-receipt.json`. All routes failing preserves
the installed binary. This change does not rewrite older published Hapup files;
use the updated script to obtain this behavior.

## First installation of a compiler build

For HapCLI 0.3.0 built with Cangjie 1.1.3, download and verify its bootstrap,
then let it install the exact release. Use `1.0.5` in the tag for the LTS build.
Run this after the chosen tag appears in GitHub Releases:

```sh
TAG=v0.3.0-cangjie-1.1.3
BASE="https://github.com/HapPub/Hap/releases/download/$TAG"
WORK="$(mktemp -d)"
curl -fsSL "$BASE/hapup.sh" -o "$WORK/hapup.sh"
curl -fsSL "$BASE/hapup.sh.sha256" -o "$WORK/hapup.sh.sha256"
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$WORK" && sha256sum -c hapup.sh.sha256)
else
  (cd "$WORK" && shasum -a 256 -c hapup.sh.sha256)
fi
sh "$WORK/hapup.sh" install --version "$TAG"
```

On Windows, download `hap-0.3.0-windows-amd64.zip` and its SHA-256 sidecar
from the selected release. Compare `Get-FileHash -Algorithm SHA256` with the
sidecar, extract the ZIP, then run `bin\hap.exe version`. Keep its adjacent DLLs.

## First installation from an older release

The following compatibility example selects the published **v0.1.0** assets.
It installs that older binary, which does **not** provide the newer one-command
or SDK/JDK interfaces. Check [GitHub Releases](https://github.com/HapPub/Hap/releases)
for available versions and matching host assets. A checked-in preview manifest
is not a published binary inventory.

```bash
VERSION=0.1.0
BASE="https://github.com/HapPub/Hap/releases/download/v$VERSION"
WORK="$(mktemp -d)"
cd "$WORK"
curl -fsSLO "$BASE/hapup.sh" -O "$BASE/hapup.sh.sha256"
curl -fsSLO "$BASE/manifest.v0.json" -O "$BASE/manifest.v0.json.sha256"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c hapup.sh.sha256
  sha256sum -c manifest.v0.json.sha256
else
  shasum -a 256 -c hapup.sh.sha256
  shasum -a 256 -c manifest.v0.json.sha256
fi
sh ./hapup.sh install-from-manifest \
  --manifest ./manifest.v0.json \
  --install-dir "$HOME/.local/bin" \
  --review-token reviewed
"$HOME/.local/bin/hap" version
```

## Build from source

Use this route when the published binary does not yet include the commands in
this checkout. Cangjie SDK and `cjpm` 1.1.x must already be available. On macOS,
first expose the Apple SDK with `export SDKROOT="$(xcrun --show-sdk-path)"`.
From the source checkout:

```sh
cjpm build
mkdir -p "$HOME/.local/bin"
cp ./target/release/bin/main "$HOME/.local/bin/hap"
cp ./release/hapup.sh "$HOME/.local/bin/hapup"
chmod +x "$HOME/.local/bin/hap" "$HOME/.local/bin/hapup"
export PATH="$HOME/.local/bin:$PATH"
hap version
hapup version
```

Both entrypoints should report this checkout's version, **0.3.0**. These commands
make them available in the current shell; add the same PATH entry to your shell
startup file if it is not already present. Running this source-built `hapup install`
still selects a published release; it does not publish or preserve an unreleased
source build. Native binaries require a compatible host and runtime.

## Install and activate a complete Cangjie toolchain

```sh
hap get cangjie --version sts
hap get cangjie --version 1.1.3
```

Both select SDK **1.1.3** and stdx **1.1.3.1** automatically, including their
different mirror tags. `latest` / `lts` remains pinned to **1.0.5 LTS**;
`nightly` resolves a complete SDK/stdx pair from one validated manifest. There
is no interactive review-token step for this explicit installation command.

HapCLI detects the host and installs verified component archives in
`~/.hap/toolchains`. Before switching defaults it runs the installed `cjc` and
`cjpm`, compiles a small program and executes it. The generated environment sets
`CANGJIE_HOME`, `PATH`, runtime library paths, and all three
`CANGJIE_STDX_PATH`, `CANGJIE_STDX_PATH_STATIC`, and
`CANGJIE_STDX_PATH_DYNAMIC` variables from actual installed paths. It does not
source a vendor script that might alter SDK files as a side effect.

The selected environment is published atomically as `~/.hap/env.sh`. Shell
hooks load that selection in new sh/bash/zsh sessions; original startup files
are backed up once as `.hap-backup`. Existing dotfile symlinks are preserved. Existing project manifests and system SDKs
are untouched. To activate in the current terminal:

```sh
. "$HOME/.hap/env.sh"
cjc --version
cjpm --version
```

The command emits structured JSON including `ok`, `status`, `sdk`, `stdx`,
`activated`, `activationHint`, and `receipt`. Failure exits nonzero even if one
component succeeded. The top-level `activated` field owns shell-selection truth;
component receipts describe component extraction only.

## Preview, installation only, and recovery

```sh
hap get cangjie --version sts --plan
hap get cangjie --version sts --no-activate
hap get cangjie --version sts --route auto
```

- `--plan` performs no downloads, probes, or writes. Nightly resolution remains
  pending until execution; a known incomplete stable pair fails the plan.
- `--no-activate` installs both components and writes a version-specific
  `environments/<version>/<target>/env.sh` under the install root. It does not
  change startup files, run a foreign binary, or change the default selection.
- `--route`, `--region`, `--proxy`, timeouts and retry options use the existing
  package download contracts. Do not combine `--route` with `--region`.
- A failed download, checksum, second component, or smoke leaves the previous
  selection intact. Re-run the same command to reuse completed components and
  validated downloads. A marker cache hit is not a new download or a rehash of
  the extracted tree.
- A per-root lock prevents simultaneous toolchain installers. After an abrupt
  termination, check that no installer remains before removing the lock path
  printed by `toolchain-install-busy` and retrying.
- Automatic activation currently supports native macOS and Linux. Windows and
  foreign targets use `--no-activate`; an unpublished SDK/stdx pair fails before
  component downloads. Fish and PowerShell startup files are not configured.
- System build tools remain prerequisites. If the smoke reports missing `ar`,
  a linker, C headers, or an Apple SDK, install the host build dependencies and
  re-run; HapCLI does not silently invoke a system package manager.

Projects that hardcode the old `linux_x86_64_llvm` stdx layout still need their
project configuration corrected. The installer supplies the actual `cjnative`
paths; it does not disguise a compiler ABI or rewrite a project's requirements.
Ordinary `hap get cangjie-sdk` and `hap get cangjie-stdx` requests install one
component without activation, using the same transaction as `hap install cangjie*`.
Use `--plan` for a read-only preview. `--legacy-plan` and explicit older recipe
options preserve the previous acquisition planner with a migration hint.

For IBM Semeru JDK, Android SDK/NDK, OpenHarmony SDK and HarmonyOS Command Line Tools, see [SDK and JDK installation](SDK_TOOLCHAINS.md). These `hap get` commands execute installation and support a read-only `--plan`.
