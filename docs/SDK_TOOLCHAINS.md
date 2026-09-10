# SDK and JDK installation

`hap get` downloads an archive, checks SHA-256, installs components, runs native
verification, writes a receipt, and selects an environment. These commands execute
installation; `--plan` performs no network requests or filesystem writes.

```sh
hap get jdk --provider semeru --version 17
hap get semeru --version 21
hap get android --version 36 --accept-licenses
hap get android --version 36 --ndk 26.3.11579264 --cmake 3.22.1 --accept-licenses
hap get ohos --version 6.0 --profile native
hap get ohos --version 6.0
```

The default destination is `~/.hap/toolchains`. Add `--no-activate` to install
without changing shell startup files. Otherwise, new sh/bash/zsh sessions load
`~/.hap/env.sh`; the receipt gives the command to update the current shell.
Existing startup files are backed up once, including symlinked dotfiles. JDK,
Android, OpenHarmony, HarmonyOS and Cangjie selections coexist in separate blocks
inside one atomically published environment file.

## Providers and availability

| Subject | What is installed | Catalog and execution boundary |
| --- | --- | --- |
| `jdk`, alias `semeru` | IBM Semeru Open Edition JDK (OpenJ9), JAVA_HOME, javac/java | GitHub `ibmruntimes/semeru{11,17,21,25}-binaries`; a major selects its latest stable release, an exact `jdk-*` tag pins that release. Requires an actual matching JDK archive. |
| `android` | Command-line tools, private Semeru 21 when no Java path is supplied, platform-tools, platform API, build-tools; optional NDK and CMake | Google command-line tools build 15859902 and published SHA-256 values. macOS Intel/ARM and Linux x64. `--version` means Android API level; build-tools defaults to 36.0.0. |
| `ohos`, alias `openharmony` | OpenHarmony public SDK; `native` profile installs native + toolchains, `full` expands host components | Pinned OpenHarmony 6.0 public SDK 6.0.0.47 / API 20. macOS Intel/ARM and Linux x64. The official archive's component metadata labels its release type Beta1; this is not a claim that all public SDKs are the latest stable release. |
| `harmonyos` | Huawei Command Line Tools with its bundled SDK, Node, JDK, ohpm, hvigorw and hdc | Public Huawei mirror currently pins Linux x64 CLT 5.1.0.840. Other versions/hosts require a downloaded official archive or explicit HTTPS URL plus SHA-256. The current Huawei download center can require sign-in. |

Installation and activation currently execute on a **native macOS or Linux
host**. Windows and foreign-host targets are plan-only. A successful plan is not
an availability or installation claim. Missing upstream assets fail explicitly;
HapCLI does not substitute another architecture. No Python, pip or npm dependency
is added to the installer: it uses the native HapCLI binary and the host's curl,
tar, unzip, find, shell and SHA-256 utility.

## Android

```sh
hap get android --version 35 --build-tools 35.0.0 --accept-licenses
hap get android --version 36 --java-home /path/to/jdk --accept-licenses
hap get android --version 36 --profile tools --accept-licenses
```

Read the [Google SDK terms](https://developer.android.com/studio/terms) before
passing `--accept-licenses`. This explicit flag authorizes the vendor manager's
license-acceptance flow. HapCLI never writes invented license hashes. The tools
profile installs only the command-line tools and Java prerequisite; it does not
claim to install Android platforms, NDK or build-tools.

The adapter uses the `sdkmanager` shipped in the verified command-line tools
archive, which remains listed on the [official download page](https://developer.android.com/studio#command-line-tools-only).
The newer [Android CLI](https://developer.android.com/tools/agents/android-cli)
is a separate distribution and is not installed by this version.

`ANDROID_HOME` and `ANDROID_SDK_ROOT` point at the installed SDK. The managed
`sdkmanager` and `avdmanager` launchers select the installation's Java without
overwriting the globally selected JDK. `HAP_ANDROID_JAVA_HOME` records that Java;
use it explicitly for a project when appropriate:

```sh
JAVA_HOME="$HAP_ANDROID_JAVA_HOME" ./gradlew assembleDebug
```

Choose a JDK compatible with the project's Gradle/AGP versions. Semeru's presence
and Java smoke success do not certify every Gradle or Android plugin combination.
HapCLI does not edit project Gradle files, `local.properties`, signing settings,
or system package-manager dependencies. `--ndk` also exports `ANDROID_NDK_HOME`.

## OpenHarmony and HarmonyOS

These are separate SDK selections. OpenHarmony sets `OHOS_SDK_HOME` / `OHOS_BASE_SDK_HOME` (containing
the API directory) and `OHOS_SDK_NATIVE`. HarmonyOS sets `DEVECO_SDK_HOME`,
`HARMONYOS_SDK_HOME`, `HAP_HARMONYOS_NATIVE`, and `HAP_HARMONYOS_JAVA_HOME`.
Its managed ohpm/hvigorw launchers bind the bundled Node and Java. This avoids
silently turning the public OpenHarmony SDK into a HarmonyOS system/full SDK.

The archive adapter handles OpenHarmony's outer tarball and inner component
zips. It reads the native package metadata to choose the API directory. For an
SDK outside the built-in catalog or a signed-in Huawei download:

```sh
hap get harmonyos --version 6.0.2.650 \
  --archive /path/to/official-commandline-tools.zip \
  --sha256 ACTUAL_VENDOR_SHA256 --accept-licenses

hap get ohos --version RELEASE \
  --url https://official.example/sdk.tar.gz --sha256 ACTUAL_VENDOR_SHA256
```

Replace the illustrative path, URL, version and checksum with the actual package.
An explicit URL/archive is user-selected input; its receipt records
`checksumAuthority=explicit-user-sha256`, not vendor authentication. It is still
verified, extracted, installed and tested by HapCLI. Restricted downloads,
accounts and licenses are not bypassed.

Official sources: [OpenHarmony 6.0 release notes](https://github.com/openharmony/docs/blob/master/zh-cn/release-notes/OpenHarmony-v6.0-release.md),
[OpenHarmony public archives](https://repo.huaweicloud.com/openharmony/os/6.0-Release/),
[Huawei public CLT mirror](https://repo.huaweicloud.com/openharmony/ohpm/5.1.0/),
[Huawei download center](https://developer.huawei.com/consumer/cn/download/), and
[IBM Semeru downloads](https://developer.ibm.com/languages/java/semeru-runtimes/downloads/).

## Verification and recovery

Receipts record requested/resolved and observed versions, API, source URL,
checksum authority, SHA-256, final root, cache use, native verification, activation,
and an activation command. Inspect the top-level `ok`. On a cache replay, the
receipt's checksum binding and native tools are checked again; the whole extracted
tree is not re-hashed, so `checksumVerified=false` does not mean a fresh archive
was verified on that replay.

Java is compiled and run. Android checks the manager, requested files, adb and
aapt2, plus requested native tools. OHOS/HarmonyOS compile a C source into an
AArch64 OHOS object using the SDK sysroot; this proves cross compilation, not
execution on a device. HarmonyOS also runs the bundled Node, ohpm and hvigorw.
Application builds, signing, deployment and cross-host certification remain
separate acceptance work.

Failed downloads, checksums, extraction or verification leave the active selection
unchanged. Per-subject locks prevent overlapping installs; a global activation
lock protects the combined environment. Failed staging created by the current
run is removed. An interrupted staging directory or unknown partial destination
is preserved for inspection and reported, not silently deleted. Move it aside
before retrying once no installer is running. Existing system SDKs are untouched.
