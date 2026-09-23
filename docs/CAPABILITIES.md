# Capability matrix

This matrix describes the `feat/audit-remediation` source branch (2026-09-23),
based on revision `98d305c`. A supported command,
a successful build, a real installation and a device acceptance test are different
results. Check the [release assets](https://github.com/HapPub/Hap/releases) for the
version and host you intend to install.

**Implemented** means the execution path exists. **Verified** names the observed
test scope. **Plan only** means no corresponding installation or execution is
performed. Unlisted host combinations are not verified by this matrix.

## Installation and toolchains

| Capability / entry | Implementation | Verification and limits |
| --- | --- | --- |
| `hapup install` | Installs the published CLI and companion, checks hashes, backs up PATH hooks | Real macOS installations and hosted installation checks; POSIX shell required |
| Hapup adaptive downloads | Automatic route probes, slow-transfer fallback and forced routes | 18 routing regressions and real downloads; not geographic coverage certification; older release scripts are unchanged |
| `hap get cangjie --version sts` | Installs matching SDK + stdx and verifies before activation | Real macOS compile/run; automatic activation requires native macOS/Linux; foreign targets require `--no-activate` and suitable host tools |
| `hap install cangjie*` | Component installation; LTS, STS and dynamic nightly resolution | Does not activate the shell; `cangjie` means SDK only here; cache checks completion markers, not every extracted file |
| `hap get cangjie-sdk`, `hap get cangjie-stdx` | Legacy plan / recipe entrypoints | These commands do not directly install the components |
| `hap get jdk --provider semeru` | Resolves and installs IBM Semeru releases | Native macOS/Linux adapter; real macOS package proof; other host coverage depends on available assets |
| `hap get android` | Installs command-line tools, platforms and optional NDK/CMake | Native macOS/Linux adapter and fixture integration tests; real upstream end-to-end acceptance remains incomplete |
| `hap get ohos` | Installs OpenHarmony SDK native/toolchains or full profile | Real macOS package/native-object proof; does not prove application signing or device execution |
| `hap get harmonyos` | Installs CLT and manages its SDK/Node/JDK environment | Built-in catalog is Linux x64 5.1.0.840; other versions need an official archive/URL and SHA-256; real current-macOS package acceptance is incomplete |
| SDK/JDK on Windows | Plans exist | SDK/JDK execution is rejected by the current adapter; a Windows CLI build does not change this |
| `hap installer inspect` | Discovers unmanaged NSIS/WiX; verifies explicitly selected bundles | Unmanaged discovery does not execute the detected compiler |
| `hap get nsis` | Installs an explicitly supplied, pinned engine pack into private storage | Real macOS ARM64 NSIS 3.12 pack → consumer → install/portable EXE compilation; Windows EXE execution is not verified |
| `hap get wix` | Separate verified-pack installation contract | Native execution requires Windows; real MSI compilation/installation is not verified |

Engine packs require an explicit archive or HTTPS URL plus SHA-256; automatic
upstream engine discovery is not implemented. Their complete inventory is checked
on every cache reuse. Ordinary NSIS hosting does not establish Honor support.
See [SDK/JDK installation](SDK_TOOLCHAINS.md), [host tools](HOST_TOOLS.md) and
[installation](INSTALLATION.md).

## Projects and devices

| Capability / entry | Implementation | Verification and limits |
| --- | --- | --- |
| `project detect`, CJPM inspection / graph diagnosis | Reads project and dependency structure | Cangjie, native Cangjie HarmonyOS, hvigor HarmonyOS, iOS and KMP remain distinct |
| `record`, `doctorfix`, `build`, `bundle` | stdx profiles, fixed CJPM execution and bounded repair retry | Native regression and historical macOS project proof; target SDK/sysroot availability still matters |
| Native Cangjie HAP/HSP/HAR packaging | Workspace/module inspection and provider plan | `package-provider-required`; no built-in package executor, signing or deployment |
| HarmonyOS `dev` | Fixed hvigor/HDC build, install and launch adapters | Historical real-device proof; every new build still needs valid signing and device authorization |
| `device` aliases and wireless memory | Explicit selection and recorded device identity | No LAN scan; a saved endpoint does not prove current connectivity |
| HarmonyOS `prnt` | Requests geometry, binds PID/WMS rectangle, captures and crops | Real macOS-hosted capture/crop proof; ImageMagick required on macOS; occlusion and visual acceptance are separate |
| KMP desktop / iOS | Fixed Gradle and Apple tooling adapters | Historical desktop and signed-artifact/device proof; source signing and multi-device acceptance remain environment-dependent |
| `update`, `upgrade` | Dependency, toolchain and CLI upgrade plans | No automatic update or dependency mutation |
| HDC host distribution | Uses an externally installed HDC | No built-in six-host HDC download/install catalog |
| CI diagnosis and recipes | Diagnoses and generates reviewable scripts | CLI does not directly mutate workflows |

## SSH and desktop sessions

| Capability / entry | macOS / Linux | Windows |
| --- | --- | --- |
| `hap get ssh` client | Reuses a healthy installed client | System client reuse verified in hosted CI; optional-component install path exists |
| `hap get ssh --server` | Requires native service-manager setup outside this adapter | Fresh system-component setup and healthy-service reuse implemented; clean-machine installation/rollback acceptance incomplete |
| `hap ssh --pair` / `conn` | Real TLS enrollment on macOS/Linux; real SSH session, reconnect, transfer and revoke rejection on isolated macOS loopback | Code exists; two-host Windows pairing/authentication not yet verified |
| `peers`, `revoke`, `forget` | Host key removal tested; `forget` only removes a local alias | ACL adapter implemented; real target acceptance incomplete |
| `ssh doctor` | Dependency/version diagnostics | Dependency/version and service diagnostics; does not prove login |
| Desktop task helper | Not implemented for these hosts | Scheduled-task helper and syntax check; visible GUI, input and cleanup acceptance incomplete |
| Broken-service replacement / temporary pairing firewall management | Not implemented | Not implemented; requires an explicit maintenance workflow |

Host-tool commands require **Python 3.11+**. Pairing also requires **OpenSSH and
OpenSSL**. Keys remain authorized until revoked; code expiry does not revoke
existing keys or terminate sessions. Use `--code-stdin` to avoid shell-history
exposure. SSH key and known-hosts paths are quoted for OpenSSH, including spaces, Unicode
and percent tokens; real macOS loopback sessions cover these paths. Windows domain-style and non-ASCII account names are
not accepted by the current username validator.

## Verification boundaries

- The host-tools workflow builds/tests on Windows x64, Linux x64 and macOS ARM64.
  All native jobs now run command contracts and isolated installer/TLS enrollment
  tests, with Windows coverage pending the updated workflow result. Real SSH
  sessions remain macOS-only; interactive desktop acceptance remains separate.
- The Cangjie suite has 233 passing cases on macOS after the test-file split. The separate host-tool
  suite has 28 public-command checks on macOS/Linux. These are different suites.
- Successful compilation is not proof of host installation, target execution,
  signing, interactive desktop visibility or user acceptance.
- Legacy JSON handlers now map top-level `ok=false` to a nonzero exit code;
  nested component success cannot override the command result. Reports without
  an `ok` field retain their previous exit behavior.
- Cangjie component installation uses a per-package lock and staging directory.
  A complete archive is verified before publication; incomplete existing installs
  and interrupted stages are preserved for inspection instead of overwritten.
- Receipts distinguish `marker`, `archive`, `native-probe` and `inventory`
  verification. Engine target declarations do not imply compiled target proof.
- Private roots reject user symlink/reparse ancestors. The fixed macOS `/tmp`
  and `/var` system aliases are normalized before these checks.

## Source map

| Area | Owning source |
| --- | --- |
| Command routing | [cli_runtime.cj](https://github.com/HapPub/Hap/blob/feat/audit-remediation/src/cli_runtime.cj) |
| Cangjie components and activation | [cangjie_package_install.cj](https://github.com/HapPub/Hap/blob/feat/audit-remediation/src/cangjie_package_install.cj), [cangjie_toolchain_get.cj](https://github.com/HapPub/Hap/blob/feat/audit-remediation/src/cangjie_toolchain_get.cj) |
| SDK/JDK providers | [sdk_toolchain_get.cj](https://github.com/HapPub/Hap/blob/feat/audit-remediation/src/sdk_toolchain_get.cj), [sdk_toolchain_catalog.cj](https://github.com/HapPub/Hap/blob/feat/audit-remediation/src/sdk_toolchain_catalog.cj) |
| Installer / SSH bridge | [host_tools.cj](https://github.com/HapPub/Hap/blob/feat/audit-remediation/src/host_tools.cj), [reviewable helpers](https://github.com/HapPub/Hap/blob/feat/audit-remediation/tools/host) |
| Windows desktop helper | [desktop-session.ps1](https://github.com/HapPub/Hap/blob/feat/audit-remediation/tools/windows/desktop-session.ps1) |
| Host acceptance | [host-tools.yml](https://github.com/HapPub/Hap/blob/feat/audit-remediation/.github/workflows/host-tools.yml), [ssh-session.py](https://github.com/HapPub/Hap/blob/feat/audit-remediation/tests/ssh-session.py) |
