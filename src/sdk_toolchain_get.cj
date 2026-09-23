package hapcli

import std.collection.ArrayList
import std.env.getStdErr
import std.fs.{File, exists, rename, removeIfExists, canonicalize}
import std.process.executeWithOutput

public class HapSdkGetOptions {
    public var subject: String = ""
    public var provider: String = ""
    public var version: String = ""
    public var target: String = ""
    public var root: String = ""
    public var archive: String = ""
    public var url: String = ""
    public var sha256: String = ""
    public var profile: String = "full"
    public var observedVersion: String = ""
    public var apiVersion: String = ""
    public var javaHome: String = ""
    public var buildTools: String = "36.0.0"
    public var ndk: String = ""
    public var cmake: String = ""
    public var plan: Bool = false
    public var activate: Bool = true
    public var acceptLicenses: Bool = false
    public init() {}
}

public class HapSdkAsset {
    public var version: String = ""
    public var url: String = ""
    public var sha256: String = ""
    public var authority: String = ""
    public init() {}
}

public func sdkGetToken(value: String): Bool {
    if (value.size == 0 || value.size > 128 || value == "." || containsText(value, "..")) { return false }
    for (ch in value.toArray()) {
        if (!((ch >= 48 && ch <= 57) || (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122) || ch == 45 || ch == 46 || ch == 95 || ch == 43)) { return false }
    }
    true
}

func resolveSdkGetOptions(args: Array<String>): HapSdkGetOptions {
    let o = HapSdkGetOptions()
    o.subject = if (args[2] == "semeru") { "jdk" } else if (args[2] == "openharmony") { "ohos" } else { args[2] }
    o.target = detectNativeCangjieInstallTarget()
    o.root = cangjiePackageEnvironmentPath("HOME") + "/.hap/toolchains"
    o.version = if (o.subject == "jdk") { "21" } else if (o.subject == "android") { "36" } else if (o.subject == "ohos") { "6.0" } else { "5.1.0.840" }
    o.provider = if (o.subject == "jdk") { "semeru" } else { "official" }
    let seen = ArrayList<String>()
    var i: Int64 = 3
    while (i < args.size) {
        let pieces = args[i].split("=")
        let key = pieces[0]
        if (seen.contains(key)) { throw Exception("duplicate option: " + key) }
        seen.add(key)
        if (key == "--plan" || key == "--no-activate" || key == "--accept-licenses") {
            if (pieces.size != 1) { throw Exception("flag takes no value: " + key) }
            if (key == "--plan") { o.plan = true }
            if (key == "--no-activate") { o.activate = false }
            if (key == "--accept-licenses") { o.acceptLicenses = true }
        } else {
            var value = ""
            if (pieces.size > 1) { value = substringFrom(args[i], key.size + 1) }
            else {
                i += 1
                if (i >= args.size) { throw Exception("missing value: " + key) }
                value = args[i]
            }
            if (value.size == 0 || startsWithText(value, "--")) { throw Exception("empty value: " + key) }
            match (key) {
                case "--version" => o.version = value
                case "--provider" => o.provider = value
                case "--target" => o.target = if (value == "auto") { detectNativeCangjieInstallTarget() } else { canonicalTargetName(value) }
                case "--install-root" => o.root = trimTrailingSlash(value)
                case "--archive" => o.archive = value
                case "--url" => o.url = value
                case "--sha256" => o.sha256 = value
                case "--profile" => o.profile = value
                case "--java-home" => o.javaHome = value
                case "--build-tools" => o.buildTools = value
                case "--ndk" => o.ndk = value
                case "--cmake" => o.cmake = value
                case _ => throw Exception("unknown option: " + key)
            }
        }
        i += 1
    }
    for (v in [o.version, o.provider, o.target, o.buildTools]) { if (!sdkGetToken(v)) { throw Exception("invalid version/provider/target token") } }
    for (v in [o.ndk, o.cmake]) { if (v.size > 0 && !sdkGetToken(v)) { throw Exception("invalid NDK/CMake version") } }
    if (o.subject == "jdk" && o.provider != "semeru") { throw Exception("supported JDK provider: semeru (IBM Open Edition / OpenJ9)") }
    if (o.subject != "jdk" && o.provider != "official") { throw Exception("SDK provider must be official") }
    if (o.profile != "full" && !(o.subject == "ohos" && o.profile == "native") && !(o.subject == "android" && o.profile == "tools")) { throw Exception("profile must be full, ohos native, or android tools") }
    if (o.subject != "android" && (o.ndk.size > 0 || o.cmake.size > 0 || o.javaHome.size > 0 || seen.contains("--build-tools"))) { throw Exception("Java/build-tools/NDK/CMake options are Android-only") }
    if (o.subject == "android" && !allAsciiDigits(o.version)) { throw Exception("Android --version is a numeric API level, e.g. 36") }
    if (o.url.size > 0 && o.archive.size > 0) { throw Exception("choose --url or --archive") }
    if (o.url.size > 0 && !startsWithText(o.url, "https://")) { throw Exception("--url requires HTTPS") }
    if ((o.url.size > 0 || o.archive.size > 0) && !isLowerHexSha256(o.sha256)) { throw Exception("an explicit archive or URL requires --sha256") }
    if (o.sha256.size > 0 && o.url.size == 0 && o.archive.size == 0) { throw Exception("--sha256 requires --archive or --url") }
    if (!cangjiePackageInstallRootIsPrivate(o.root) || containsText(o.root, "\n") || containsText(o.root, "\r")) { throw Exception("install root must be a private HOME/.hap or temporary path") }
    return o
}

func sdkCommand(program: String, args: Array<String>): String {
    let (code, out, err) = executeWithOutput(program, args)
    if (code != 0) {
        let detail = String.fromUtf8(err) + String.fromUtf8(out)
        throw Exception(program + " exited " + code.toString() + ": " + if (detail.size > 3000) { substringRange(detail, 0, 3000) } else { detail })
    }
    String.fromUtf8(out)
}

func sdkCatalog(url: String): String {
    let result = fetchCangjieCatalogText(url, "proxy", 30)
    if (result.exitCode != 0) { throw Exception("catalog fetch failed: " + url + ": " + result.stderr) }
    result.stdout
}

func sdkFind(root: String, name: String): ArrayList<String> {
    let result = ArrayList<String>()
    let output = sdkCommand("find", [root, "-maxdepth", "12", "-type", "f", "-name", name, "-print"])
    for (line in output.split("\n")) { if (line.size > 0 && !startsWithText(line, root + "/hap-bin/")) { result.add(line) } }
    result
}

func sdkFindOne(root: String, name: String): String {
    let paths = sdkFind(root, name)
    if (paths.size != 1) { throw Exception("expected one " + name + " inside " + root + "; found " + paths.size.toString()) }
    paths[0]
}

// Resolve the nearest existing ancestor before making directories. /tmp aliases are
// canonicalized, but a private-looking path pointing into a system SDK is rejected.
func sdkValidatePrivateRoot(root: String): Unit {
    var ancestor = root
    while (!exists(ancestor)) {
        let parent = parentPath(ancestor)
        if (parent == ancestor || parent.size == 0) { throw Exception("cannot resolve install root") }
        ancestor = parent
    }
    let real = canonicalize(ancestor).toString().replace("\\", "/") + substringFrom(root, ancestor.size)
    let home = cangjiePackageEnvironmentPath("HOME")
    if (home.size > 0 && exists(home)) {
        let base = canonicalize(home).toString().replace("\\", "/") + "/.hap"
        if (real == base || startsWithText(real, base + "/")) { return }
    }
    for (temp in ["/private/tmp", "/tmp", cangjiePackageEnvironmentPath("TMPDIR"), cangjiePackageEnvironmentPath("TEMP"), cangjiePackageEnvironmentPath("TMP")]) {
        if (temp.size > 0 && exists(temp)) {
            let base = trimTrailingSlash(canonicalize(temp).toString().replace("\\", "/"))
            if (real == base || startsWithText(real, base + "/")) { return }
        }
    }
    throw Exception("install root resolves outside private storage")
}

public func runSdkToolchainGet(args: Array<String>): String {
    var lock = ""
    var stage = ""
    var locked = false
    var ownsStage = false
    try {
        let o = resolveSdkGetOptions(args)
        if (o.plan) {
            return "{\"schema\":\"happub-sdk-get-v1\",\"ok\":true,\"status\":\"planned\",\"catalogActionTaken\":false,\"installed\":false,\"activated\":false,\"subject\":\"" + o.subject + "\",\"provider\":\"" + o.provider + "\",\"requestedVersion\":\"" + o.version + "\",\"target\":\"" + o.target + "\",\"profile\":\"" + o.profile + "\",\"licenseAcceptanceRequired\":" + boolJson(o.subject == "android" || o.subject == "harmonyos") + ",\"detail\":\"Resolution, asset availability and native validation are pending execution. No network or writes.\"}"
        }
        if (o.target != detectNativeCangjieInstallTarget() || startsWithText(o.target, "windows-")) { throw Exception("SDK execution currently requires native macOS/Linux; foreign targets are plan-only") }
        if ((o.subject == "android" || o.subject == "harmonyos") && !o.acceptLicenses) { throw Exception("license-acceptance-required: read https://developer.android.com/studio/terms or the selected Huawei package license; rerun with --accept-licenses after accepting applicable vendor terms") }
        sdkValidatePrivateRoot(o.root)
        getStdErr().writeln("[1/4] Resolving " + o.subject + " " + o.version + " for " + o.target + "...")
        let asset = resolveSdkToolchainAsset(o)
        if (!isLowerHexSha256(asset.sha256) || !sdkGetToken(asset.version)) { throw Exception("catalog returned invalid version or SHA-256") }
        ensureCangjieToolchainDirectory(o.root)
        lock = o.root + "/." + o.subject + "-install-lock"
        sdkCommand("mkdir", [lock])
        locked = true
        writeHapInstallLockOwner(lock, o.subject + "-install")
        var javaKey = ""
        if (o.subject == "android" && o.javaHome.size > 0) {
            File.writeTo(lock + "/java-home.txt", o.javaHome.toArray())
            javaKey = "-java-" + substringRange(hapPrntFileSha256(lock + "/java-home.txt"), 0, 12)
        }
        let key = o.subject + "/" + asset.version + "/" + o.target + "/" + o.profile + "-" + substringRange(asset.sha256, 0, 12) + if (o.subject == "android") { "-" + o.buildTools + "-" + o.ndk + "-" + o.cmake + javaKey } else { "" }
        let finalRoot = o.root + "/" + key
        sdkValidatePrivateRoot(finalRoot)
        let receipt = finalRoot + "/.hap-receipt.json"
        stage = finalRoot + ".staging"
        let cacheHit = exists(receipt)
        if (exists(finalRoot) && !cacheHit) { throw Exception("incomplete install exists; inspect or move it before retrying: " + finalRoot) }
        if (!cacheHit) {
            if (exists(stage)) { throw Exception("interrupted staging directory exists; inspect or move it before retrying: " + stage) }
            ensureCangjieToolchainDirectory(stage)
            ownsStage = true
            let ext = if ((if (o.archive.size > 0) { o.archive } else { asset.url }).endsWith(".zip")) { ".zip" } else { ".tar.gz" }
            let archive = stage + "/download" + ext
            getStdErr().writeln("[2/4] Downloading and checking SHA-256...")
            if (o.archive.size > 0) { sdkCommand("cp", [o.archive, archive]) }
            else {
                sdkCommand("curl", hapHttpsDownloadArgs(asset.url, archive, 1800, 2))
            }
            if (!verifyCangjieBootstrapSha256(archive, asset.sha256)) { throw Exception("archive SHA-256 mismatch") }
            getStdErr().writeln("[3/4] Extracting and installing components...")
            sdkExtractArchive(archive, stage + "/payload")
            removeIfExists(archive)
            prepareSdkToolchain(o, stage + "/payload")
            verifySdkToolchain(o, stage + "/payload")
            ensureCangjieToolchainDirectory(parentPath(finalRoot))
            rename(stage, to: finalRoot)
            stage = ""
            verifySdkToolchain(o, finalRoot + "/payload")
        } else {
            let prior = String.fromUtf8(File.readFrom(receipt))
            if (jsonStringValueForKey(prior, "sha256") != asset.sha256) { throw Exception("cached receipt checksum does not match resolved asset") }
            verifySdkToolchain(o, finalRoot + "/payload")
        }
        getStdErr().writeln("[4/4] Verifying native tools and selecting environment...")
        writeSdkToolchainLaunchers(o, finalRoot + "/payload")
        let environment = sdkToolchainEnvironment(o, finalRoot + "/payload")
        File.writeTo(finalRoot + "/env.sh", environment.toArray())
        // Publish install evidence before activation, so a startup-file error remains
        // retryable and never masquerades as an unrecognized partial installation.
        let installed = renderSdkGetReceipt(o, asset, finalRoot, receipt, cacheHit, false)
        File.writeTo(receipt, installed.toArray())
        if (o.activate) { activateHapToolchainEnvironment(o.subject, environment, cangjiePackageEnvironmentPath("HOME")) }
        let output = renderSdkGetReceipt(o, asset, finalRoot, receipt, cacheHit, o.activate)
        File.writeTo(receipt + ".new", output.toArray())
        rename(receipt + ".new", to: receipt, overwrite: true)
        return output
    } catch (error: Exception) {
        return renderInspectCjpmErrorJson("sdk-toolchain-install-failed", error.message)
    } finally {
        if (stage.size > 0 && ownsStage && exists(stage)) { removeIfExists(stage, recursive: true) }
        if (locked) { removeIfExists(lock, recursive: true) }
    }
}

func renderSdkGetReceipt(o: HapSdkGetOptions, a: HapSdkAsset, root: String, receipt: String, cache: Bool, activated: Bool): String {
    "{\"schema\":\"happub-sdk-get-v1\",\"ok\":true,\"status\":\"installed\",\"subject\":\"" + o.subject + "\",\"provider\":\"" + o.provider + "\",\"requestedVersion\":\"" + o.version + "\",\"resolvedVersion\":\"" + a.version + "\",\"observedVersion\":\"" + escapeJson(o.observedVersion) + "\",\"javaHome\":\"" + escapeJson(o.javaHome) + "\",\"apiVersion\":\"" + escapeJson(o.apiVersion) + "\",\"target\":\"" + o.target + "\",\"profile\":\"" + o.profile + "\",\"sha256\":\"" + a.sha256 + "\",\"checksumAuthority\":\"" + escapeJson(a.authority) + "\",\"sourceUrl\":\"" + escapeJson(a.url) + "\",\"checksumVerified\":" + boolJson(!cache) + ",\"cacheHit\":" + boolJson(cache) + ",\"verificationLevel\":\"native-probe\",\"nativeToolsVerified\":true,\"installed\":true,\"activated\":" + boolJson(activated) + ",\"finalRoot\":\"" + escapeJson(root) + "\",\"receipt\":\"" + escapeJson(receipt) + "\",\"activationHint\":\"" + escapeJson(". " + shellQuote(if (activated) { cangjiePackageEnvironmentPath("HOME") + "/.hap/env.sh" } else { root + "/env.sh" })) + "\"}"
}
