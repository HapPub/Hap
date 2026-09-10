package hapcli

import std.collection.ArrayList
import std.env.getStdErr
import std.fs.{Directory, File, exists, rename, removeIfExists}
import std.process.executeWithOutput

public class HapCangjieToolchainGetOptions {
    public var sdk: HapCangjiePackageInstallOptions = HapCangjiePackageInstallOptions()
    public var stdx: HapCangjiePackageInstallOptions = HapCangjiePackageInstallOptions()
    public var activate: Bool = true
    public var receipt: String = ""
    public var error: String = ""
    public init() {}
}

public func resolveCangjieToolchainGetOptions(args: Array<String>): HapCangjieToolchainGetOptions {
    let result = HapCangjieToolchainGetOptions()
    let forwarded = ArrayList<String>()
    var version = "latest"
    var versionSeen = false
    var i: Int64 = 3
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--no-activate") {
            result.activate = false
        } else if (arg == "--version" || startsWithText(arg, "--version=")) {
            if (versionSeen) { result.error = "--version must be specified once"; return result }
            versionSeen = true
            if (arg == "--version") {
                i += 1
                if (i >= args.size) { result.error = "missing --version value"; return result }
                version = args[i]
            } else { version = substringFrom(arg, 10) }
        } else if (arg == "--receipt" || startsWithText(arg, "--receipt=")) {
            if (arg == "--receipt") {
                i += 1
                if (i >= args.size) { result.error = "missing --receipt value"; return result }
                result.receipt = args[i]
            } else { result.receipt = substringFrom(arg, 10) }
        } else { forwarded.add(arg) }
        i += 1
    }
    let sdkArgs = ArrayList<String>()
    let stdxArgs = ArrayList<String>()
    sdkArgs.add("cangjie-sdk@" + version)
    stdxArgs.add("cangjie-stdx@" + version)
    for (arg in forwarded) { sdkArgs.add(arg); stdxArgs.add(arg) }
    result.sdk = resolveCangjiePackageInstallOptions(sdkArgs.toArray(), 0)
    result.stdx = resolveCangjiePackageInstallOptions(stdxArgs.toArray(), 0)
    if (!result.sdk.valid) { result.error = result.sdk.errorMessage }
    else if (!result.stdx.valid) { result.error = result.stdx.errorMessage }
    else if (result.receipt.size > 0 && !cangjiePackageReceiptIsPrivate(result.sdk.installRoot, result.receipt)) {
        result.error = "receipt must stay inside the selected private install root"
    }
    if (result.receipt.size == 0) { result.receipt = result.sdk.installRoot + "/receipts/cangjie-toolchain.json" }
    result
}

public func runCangjieToolchainGet(args: Array<String>): String {
    let options = resolveCangjieToolchainGetOptions(args)
    if (options.error.size > 0) { return renderInspectCjpmErrorJson("invalid-toolchain-get", options.error) }
    let sdk = options.sdk
    let stdx = options.stdx
    if (sdk.plan) {
        let sdkPlan = renderCangjiePackageInstallPlanJson(sdk)
        let stdxPlan = renderCangjiePackageInstallPlanJson(stdx)
        let available = cangjiePackageInstallExitCode(sdkPlan) == 0 && cangjiePackageInstallExitCode(stdxPlan) == 0
        return renderCangjieToolchainGetJson(options, if (available) { "planned" } else { "incomplete-toolchain-release" }, available, sdkPlan, stdxPlan, "", false)
    }
    if (options.activate && (sdk.target != detectNativeCangjieInstallTarget() || sdk.target == "windows-amd64")) {
        return renderInspectCjpmErrorJson("unsupported-activation-target", "automatic activation requires a native macOS/Linux target; use --no-activate to download another target")
    }
    getStdErr().writeln("Resolving Cangjie SDK + stdx for " + sdk.target + "...")
    if (sdk.dynamicRequested) {
        let release = if (sdk.resolvedVersion.size == 0) {
            discoverLatestCangjieNightly("cangjie-sdk", sdk.platform, sdk.networkMode)
        } else { resolveExactCangjieNightly(sdk.resolvedVersion, "cangjie-sdk", sdk.platform, sdk.networkMode) }
        if (!release.valid) { return renderInspectCjpmErrorJson("nightly-catalog-resolution-failed", release.diagnostic) }
        bindCangjieNightlyRelease(sdk, release)
        bindCangjieNightlyRelease(stdx, release)
    }
    // Resolve both assets before starting either transfer, including the same nightly manifest.
    if (!resolveCangjiePackageInstallAsset(sdk).valid || !resolveCangjiePackageInstallAsset(stdx).valid) {
        return renderInspectCjpmErrorJson("incomplete-toolchain-release", "this release does not publish both SDK and stdx for the selected target")
    }
    var sdkJson = "null"
    var stdxJson = "null"
    let lock = sdk.installRoot + "/.toolchain-get-lock"
    var locked = false
    var activated = false
    try {
        ensureCangjieToolchainDirectory(sdk.installRoot)
        let (code, _, _) = executeWithOutput("mkdir", [lock])
        if (code != 0) { return renderInspectCjpmErrorJson("toolchain-install-busy", "another installation owns " + lock + "; if interrupted, remove this directory after checking no installer is running") }
        locked = true
        getStdErr().writeln("[1/3] Installing SDK " + sdk.resolvedVersion + " (download, SHA-256, extraction or verified cache)...")
        sdkJson = runCangjiePackageInstall(sdk)
        if (cangjiePackageInstallExitCode(sdkJson) != 0) {
            return renderCangjieToolchainGetJson(options, "sdk-install-failed", false, sdkJson, stdxJson, "", false)
        }
        getStdErr().writeln("[2/3] Installing stdx " + stdx.assetVersion + "...")
        stdxJson = runCangjiePackageInstall(stdx)
        if (cangjiePackageInstallExitCode(stdxJson) != 0) {
            return renderCangjieToolchainGetJson(options, "stdx-install-failed", false, sdkJson, stdxJson, "", false)
        }
        let sdkHome = parentPath(findBootstrapEnvsetup(cangjiePackageFinalRoot(sdk)))
        let envDir = sdk.installRoot + "/environments/" + sdk.resolvedVersion + "/" + sdk.target
        ensureCangjieToolchainDirectory(envDir)
        let envFile = envDir + "/env.sh"
        let environment = renderCangjieToolchainEnvironment(sdkHome, cangjiePackageFinalRoot(stdx), sdk.target)
        File.writeTo(envFile + ".new", environment.toArray())
        if (options.activate) {
            getStdErr().writeln("[3/3] Verifying compiler, package manager, and compile/run before activation...")
            let smokeRoot = lock + "/smoke"
            ensureCangjieToolchainDirectory(smokeRoot)
            File.writeTo(smokeRoot + "/hello.cj", "main(): Int64 { println(\"HapCLI toolchain ready\"); 0 }\n".toArray())
            let smokeScript = ". \"$1\" && \"$CANGJIE_HOME/bin/cjc\" --version && \"$CANGJIE_HOME/tools/bin/cjpm\" --version && test -d \"$CANGJIE_STDX_PATH_STATIC/stdx\" && test -d \"$CANGJIE_STDX_PATH_DYNAMIC/stdx\" && \"$CANGJIE_HOME/bin/cjc\" \"$2/hello.cj\" -o \"$2/hello\" && \"$2/hello\""
            let (smoke, _, error) = executeWithOutput("sh", ["-c", smokeScript, "hap-toolchain-smoke", envFile + ".new", smokeRoot])
            if (smoke != 0) {
                return renderCangjieToolchainGetJson(options, "toolchain-smoke-failed", false, sdkJson, stdxJson, String.fromUtf8(error), false)
            }
        }
        rename(envFile + ".new", to: envFile, overwrite: true)
        // Verify the receipt destination is writable before changing shell defaults.
        ensureCangjieToolchainDirectory(parentPath(options.receipt))
        File.writeTo(options.receipt + ".new", "".toArray())
        if (options.activate) {
            activateCangjieToolchainEnvironment(environment, cangjiePackageEnvironmentPath("HOME"))
            activated = true
        }
        let output = renderCangjieToolchainGetJson(options, if (options.activate) { "installed-and-activated" } else { "installed" }, true, sdkJson, stdxJson, envFile, options.activate)
        ensureCangjieToolchainDirectory(parentPath(options.receipt))
        File.writeTo(options.receipt + ".new", output.toArray())
        rename(options.receipt + ".new", to: options.receipt, overwrite: true)
        output
    } catch (error: Exception) {
        renderCangjieToolchainGetJson(options, "toolchain-finalization-failed", false, sdkJson, stdxJson, error.message, activated)
    } finally {
        if (locked) { removeIfExists(lock, recursive: true) }
    }
}

public func renderCangjieToolchainEnvironment(sdkHome: String, stdxHome: String, target: String): String {
    let platform = cangjiePlatformNameForTarget(target)
    let out = StringBuilder()
    out.append("# Managed by hap get cangjie. Source this file from sh, bash, or zsh.\n")
    out.append("export CANGJIE_HOME=" + shellQuote(sdkHome) + "\n")
    out.append("export CANGJIE_STDX_PATH=" + shellQuote(stdxHome) + "\n")
    out.append("export CANGJIE_STDX_PATH_STATIC=" + shellQuote(stdxHome + "/" + platform + "/static") + "\n")
    out.append("export CANGJIE_STDX_PATH_DYNAMIC=" + shellQuote(stdxHome + "/" + platform + "/dynamic") + "\n")
    out.append("case \"$PATH\" in \"$CANGJIE_HOME/bin:$CANGJIE_HOME/tools/bin:\"*) ;; *) export PATH=\"$CANGJIE_HOME/bin:$CANGJIE_HOME/tools/bin:$HOME/.cjpm/bin:$PATH\" ;; esac\n")
    let libraryVar = if (startsWithText(target, "macos-")) { "DYLD_LIBRARY_PATH" } else { "LD_LIBRARY_PATH" }
    out.append("export " + libraryVar + "=" + shellQuote(sdkHome + "/runtime/lib/" + platform + ":" + sdkHome + "/tools/lib:" + stdxHome + "/" + platform + "/dynamic") + ":\"\${" + libraryVar + ":-}\"\n")
    if (startsWithText(target, "macos-")) {
        out.append("if [ -z \"\${SDKROOT:-}\" ] && command -v xcrun >/dev/null 2>&1; then SDKROOT=$(xcrun --sdk macosx --show-sdk-path) && export SDKROOT; fi\n")
    }
    out.toString()
}

// Stage every write and preserve original startup files before publishing the selection.
// The hook points to one atomically replaced file, so component failure cannot switch defaults.
public func activateCangjieToolchainEnvironment(environment: String, home: String): Unit {
    activateHapToolchainEnvironment("cangjie", environment, home)
}

public func activateHapToolchainEnvironment(subject: String, environment: String, home: String): Unit {
    if (home.size == 0) { throw Exception("HOME is required for shell activation") }
    let activationRoot = home + "/.hap"
    ensureCangjieToolchainDirectory(activationRoot)
    let envFile = activationRoot + "/env.sh"
    let hook = "\n# HapCLI Cangjie toolchain\n[ ! -f " + shellQuote(envFile) + " ] || . " + shellQuote(envFile) + "\n"
    let paths = ArrayList<String>()
    let originals = ArrayList<String>()
    let present = ArrayList<Bool>()
    let activationLock = activationRoot + "/.activation-lock"
    let (lockCode, _, _) = executeWithOutput("mkdir", [activationLock])
    if (lockCode != 0) { throw Exception("another activation owns " + activationLock) }
    try {
        let names = ArrayList<String>()
        for (name in [".profile", ".bashrc", ".zshrc"]) { names.add(name) }
        if (exists(home + "/.bash_profile")) { names.add(".bash_profile") }
        else if (exists(home + "/.bash_login")) { names.add(".bash_login") }
        for (name in names) {
            let path = home + "/" + name
            let old = if (exists(path)) { String.fromUtf8(File.readFrom(path)) } else { "" }
            if (containsText(old, hook)) { continue }
            paths.add(path)
            originals.add(old)
            present.add(exists(path))
            if (exists(path) && !exists(path + ".hap-backup")) { File.writeTo(path + ".hap-backup", old.toArray()) }
            File.writeTo(path + ".hap-new", (old + hook).toArray())
        }
        let oldEnvironment = if (exists(envFile)) { String.fromUtf8(File.readFrom(envFile)) } else { "" }
        File.writeTo(envFile + ".new", mergeHapToolchainEnvironment(oldEnvironment, subject, environment).toArray())
        for (path in paths) {
            // Preserve dotfile symlinks and permissions; staged content is ready before any write.
            File.writeTo(path, File.readFrom(path + ".hap-new"))
            removeIfExists(path + ".hap-new")
        }
        rename(envFile + ".new", to: envFile, overwrite: true)
    } catch (error: Exception) {
        for (i in 0..paths.size) {
            if (present[i]) { File.writeTo(paths[i], originals[i].toArray()) }
            else { removeIfExists(paths[i]) }
            removeIfExists(paths[i] + ".hap-new")
        }
        throw error
    } finally {
        removeIfExists(activationLock, recursive: true)
    }
}

func renderCangjieToolchainGetJson(options: HapCangjieToolchainGetOptions, status: String, ok: Bool, sdk: String, stdx: String, detail: String, activated: Bool): String {
    "{\n  \"schema\": \"happub-hapcli-cangjie-toolchain-get-v1\",\n  \"ok\": " + boolJson(ok) +
    ",\n  \"status\": \"" + escapeJson(status) + "\",\n  \"plan\": " + boolJson(options.sdk.plan) +
    ",\n  \"activationRequested\": " + boolJson(options.activate) + ",\n  \"activated\": " + boolJson(activated) +
    ",\n  \"activationHint\": \"" + escapeJson(if (activated) { ". " + shellQuote(cangjiePackageEnvironmentPath("HOME") + "/.hap/env.sh") } else { "" }) +
    "\",\n  \"detail\": \"" + escapeJson(detail) + "\",\n  \"receipt\": \"" + escapeJson(options.receipt) +
    "\",\n  \"sdk\": " + sdk + ",\n  \"stdx\": " + stdx + "\n}\n"
}

public func cangjieToolchainGetExitCode(output: String): Int64 {
    let key = indexOfText(output, "\"ok\"")
    if (key >= 0 && jsonBoolValueAfter(output, key) == "true") { 0 } else { 1 }
}

func ensureCangjieToolchainDirectory(path: String): Unit {
    if (!exists(path)) { Directory.create(path, recursive: true) }
}

// Keep provider selections in a single atomic file. Preserve legacy Cangjie content
// and replace only the selected provider block; no referenced mutable profile files.
public func mergeHapToolchainEnvironment(previous: String, subject: String, environment: String): String {
    let begin = "# hap:begin:" + subject + "\n"
    let end = "# hap:end:" + subject + "\n"
    let block = begin + environment + "\n" + end
    let start = indexOfText(previous, begin)
    if (start >= 0) {
        let stop = indexOfTextFrom(previous, end, start + begin.size)
        if (stop < 0) { throw Exception("malformed managed environment block") }
        return substringRange(previous, 0, start) + block + substringFrom(previous, stop + end.size)
    }
    if (subject == "cangjie" && !containsText(previous, "# hap:begin:")) { return block }
    return previous + if (previous.size == 0 || previous.endsWith("\n")) { "" } else { "\n" } + block
}
