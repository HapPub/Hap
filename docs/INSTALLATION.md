# Installing HapCLI and Cangjie

These user-facing commands require HapCLI / Hapup 0.2.0. Check `hap version`
before using them. A source checkout or local build does not publish a GitHub
release; `hapup install` selects only a release that actually exists there.

## Install HapCLI itself

With the new bootstrap companion downloaded from a verified release:

```sh
sh hapup.sh install
# After the first install:
hapup install --version 0.2.0
```

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
