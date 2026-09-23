# Installer engines and LAN SSH

These commands require **Python 3.11+** on PATH. The reviewed helpers are embedded
in Hap; Python runs in isolated mode and does not load modules from your project.
SSH pairing additionally needs OpenSSH with `ssh-keygen -Y` support and OpenSSL
with `req -addext` support. `hap ssh doctor` reports dependencies; it does not
prove server readiness or a successful connection. No component is downloaded
silently to satisfy these prerequisites.

## Private installer engines

```sh
hap installer inspect --engine nsis
hap installer inspect --engine nsis --bundle /trusted/canghui-package
hap get nsis --version 3.12 --archive /trusted/engine.tar.gz --sha256 <sha256>
hap get nsis --version 3.12 --url https://publisher.example/engine.tar.gz --sha256 <sha256>
hap get nsis --version 3.12 --archive /trusted/engine.tar.gz --sha256 <sha256> --offline
hap get nsis --version 3.12 --sha256 <sha256> --offline
hap get wix --version 6.0.2 --archive /trusted/wix-pack.zip --sha256 <sha256> --plan
```

Use a dedicated `--install-root` to override `~/.hap/engines`. An existing POSIX
root must be owned by the current user with mode 0700. Windows roots receive a
private ACL. `--plan` performs no network or storage mutation. This first version
accepts an explicitly selected, prepared engine pack; it has **no automatic
upstream NSIS/WiX catalog**. Plain upstream archives must be prepared to the pack
contract before use. License review belongs to whoever selects/distributes the
pack; a user-supplied SHA-256 binds bytes, not publisher identity.

`inspect` without `--bundle` only discovers an unmanaged executable path and
does not execute it. Selecting a trusted bundle checks the complete inventory
before invoking its fixed version command. No global PATH or tool is changed.
Installation verifies the archive, rejects links, reparse points, path escapes,
case collisions and special files, and enforces 10000 entries/1 GiB limits. It
stages privately, checks the native compiler, then publishes atomically. Cached
installs are fully re-hashed. Offline mode imports a local archive on first use or reuses a verified cache; it never downloads from a URL. A failed invocation preserves existing installs.

NSIS uses `chui.installer-engine.v1`: `version`, `host` and `files` (every relative
regular-file path except `engine.json`, mapped to lowercase SHA-256). Host names
include `darwin-arm64`, `linux-x86_64` and `win32-x86_64`. The root contains
`makensis`/`makensis.exe`, `COPYING`, `Stubs`, `Include`, `Contrib` and `Plugins`.
New packs should identify `engine=canghui-package` and `backend=NSIS`. The native
version command receives private `NSISDIR` and disables global NSIS config.
The receipt's `bundleRoot` can be passed to CUIC's `--engine-bundle`.

WiX uses the separate `happub.wix-engine.v1` inventory with root `wix.exe`, all its
runtime files, and license notices. Native WiX execution requires Windows plus
its required .NET runtime. Managing a pack does not prove MSI building or Windows
installation. NSIS Honor-profile support is not certified by Hap.

## Prepare SSH

```sh
hap get ssh --plan
hap get ssh
# On an elevated Windows terminal, explicitly select a Private LAN interface:
hap get ssh --server --listen 192.168.1.20 --port 22 --plan
hap get ssh --server --listen 192.168.1.20 --port 22 --no-autostart
hap ssh doctor
```

Bare `get ssh` only prepares a client. macOS/Linux reuse the native client;
server setup remains with the platform's service manager. Windows uses the
Microsoft-supported optional component. Without elevation it reports
`needs-elevation`; Hap does not invoke UAC or bypass it. Fresh server setup binds
the selected address, allows the Private interface's local subnet, disables
password login/forwarding and tests configuration before starting. Keys and
login authorization persist; `--no-autostart` changes boot behavior only.

A healthy running server is reused without configuration changes. A stopped,
broken, occupied or inconsistent installation requires an explicit maintenance
window; this version **does not automatically replace or repair an existing
server**, install a Win32-OpenSSH alternative package, or change its port.
New-install failure removes only the new component/rules and preserves newly
generated server data in a protected failure directory. Existing configuration
and keys are never overwritten by this path.

## Pair and connect

On the host, as the account that will receive shell access:

```sh
hap ssh --pair --listen 192.168.1.20 --ttl 5m
```

The temporary pairing port defaults to 49222 (`--pair-port` changes it). The
selected LAN interface must permit that port; Hap does not automatically add a
pairing firewall rule. Use a trusted out-of-band channel to share the complete
long code. It binds the endpoint, a fresh TLS certificate and a 256-bit one-use
secret. It contains no password/private key. It expires in 30–600 seconds. Host
confirmation displays the requesting key fingerprint and account before adding
it. The host can explicitly preauthorize one enrollment with `--preauthorize`.
Root/Windows administrative enrollment additionally requires
`--allow-privileged`; Windows's shared administrators key file grants
administrative shell access, not isolation to one administrator identity.

On the client:

```sh
hap ssh conn <long-code> --save win-lab
hap ssh conn --code-stdin --save win-lab
hap ssh conn win-lab
hap ssh peers
```

`--code-stdin` keeps the secret out of shell history and process arguments. When
using non-terminal output or `--json`, host code output requires `--show-code`;
that output is sensitive. Ordinary peer receipts never store codes or secrets.
`--no-connect` enrolls without opening a shell. No-argument `hap ssh` offers a
small terminal menu; non-terminal callers must select an operation.

TLS validates the certificate carried by the code and its IP name, with an
additional exact certificate pin. An OpenSSH signature over a fresh, bound
challenge proves possession of the client's new private key. Private keys stay
on the client; each peer has a separate persistent key/known_hosts record under
`~/.hap/ssh`. Connections use strict host-key checking, isolated SSH options,
and no forwarding. The installed authorized-key entry also disables agent,
TCP and X11 forwarding. Shell access is **not a debugging sandbox**.

On the host, revoke an enrollment:

```sh
hap ssh revoke <peer-id>
```

This removes that exact public key from server authorization. Code expiry does
not revoke existing enrollment. Existing sessions are not killed. The result
reports key removal; a separate new-connection test must verify rejection.
`hap ssh forget <alias>` only removes a local alias and does not revoke access.
IP changes require renewed host identity verification; no network scan or
automatic re-trust occurs.

## Evidence and remaining platform work

The current local acceptance covers macOS ARM64 NSIS compilation consumed by
CUIC and isolated macOS loopback TLS enrollment, OpenSSH login, reconnect,
byte-exact transfer and new-login rejection after revocation. It does not prove
Windows EXE/MSI installation or Mac-to-Windows pairing. Windows service setup
requires native validation. The Windows desktop helper below still requires native acceptance; SSH login
alone does not prove that a GUI is visible. Inspect `installReady`, `pairReady`,
`sshAuthenticated` and `guiSessionVerified` separately.

### Windows desktop acceptance helper

`tools/windows/desktop-session.ps1` supplies an explicit desktop launch/log/stop
helper for native acceptance. It requires exactly one Explorer desktop for the
current account, creates a separate private task directory and limited
interactive scheduled task, and tracks the launched PID plus start time before
stopping it. It collects no passwords and changes no autologon setting.

```powershell
.\desktop-session.ps1 -Action launch -TaskId smoke-01 -Executable C:\test\Demo.exe -TimeoutSeconds 120
.\desktop-session.ps1 -Action status -TaskId smoke-01
.\desktop-session.ps1 -Action stop -TaskId smoke-01
# After terminal status and reviewing the task's receipt/logs:
Unregister-ScheduledTask -TaskPath '\Hap\' -TaskName 'HapDesktop-smoke-01' -Confirm:$false
```

Use a different ID, workspace and app port for each concurrent task. A successful
launch only records scheduling/process evidence; a person or a desktop test must
confirm visibility, input and exit before `guiSessionVerified` can be asserted.
The helper currently awaits real Windows desktop acceptance. It does not promise
that two tasks can control one application window independently.

## Path, failure and receipt behavior

Managed SSH paths support spaces, Unicode, quotes and percent characters where
allowed by the host filesystem. Both identity and known-hosts paths use quoted
OpenSSH configuration values. Strict host verification remains enabled.

A completed SSH command with exit 1–254 still proves authentication; the receipt
records its `sessionExitCode` separately and the CLI exits nonzero. Exit 255 or a
signal leaves authentication unknown (`null`), because the session may have
failed before or after authentication. Enrollment alone never proves login.

Host subprocess failures expose an allowlisted status, exit code, retryability
and next action; arbitrary child stderr and command arguments are not echoed.
Installer receipts expose `verificationLevel`, `declaredTargets` and
`verifiedTargets`; a version smoke does not verify a target compiler stub.

Lock `owner.json` records the process and creation time. Check that process has
stopped before removing an interrupted lock. Private-root checks still reject
user links/reparse points; macOS's fixed `/tmp` and `/var` aliases are normalized.
