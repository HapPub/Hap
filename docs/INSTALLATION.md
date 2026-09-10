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
The old `hap get cangjie-sdk` and `hap get cangjie-stdx` commands remain planners;
`hap install cangjie*` remains the component-level installation interface.

For IBM Semeru JDK, Android SDK/NDK, OpenHarmony SDK and HarmonyOS Command Line Tools, see [SDK and JDK installation](SDK_TOOLCHAINS.md). These `hap get` commands execute installation and support a read-only `--plan`.
