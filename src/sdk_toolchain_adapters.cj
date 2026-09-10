package hapcli

import std.collection.ArrayList
import std.fs.{File, exists, rename, removeIfExists}
import std.process.executeWithOutput

// Native tar/unzip retain executable permissions. Reject archive path escapes,
// special files and zip symlinks before extraction; tar keeps its default
// protection against writing through symlinks (never pass -P or --absolute-names).
func sdkExtractArchive(archive: String, destination: String): Unit {
    if (archive.endsWith(".zip")) {
        let listing = sdkCommand("unzip", ["-Z", "-l", archive])
        for (line in listing.split("\n")) {
            if (startsWithText(line, "l") || startsWithText(line, "b") || startsWithText(line, "c") || startsWithText(line, "p") || startsWithText(line, "s")) {
                throw Exception("zip links and special files are not accepted")
            }
        }
    } else {
        validateSdkTarLinks(archive)
    }
    let result = extractCangjieBootstrapArchive(archive, destination)
    if (result.exitCode != 0) { throw Exception("archive extraction failed: " + result.stderr) }
}

func sdkJdkHome(root: String): String {
    let javac = sdkFindOne(root, "javac")
    let home = parentPath(parentPath(javac))
    if (!exists(home + "/bin/java") || !exists(home + "/release")) { throw Exception("archive does not contain a complete JDK") }
    home
}

func sdkNativeHome(root: String): String {
    let manifests = sdkFind(root, "oh-uni-package.json")
    for (manifest in manifests) {
        let home = parentPath(manifest)
        if (home.endsWith("/native") && exists(home + "/llvm/bin/clang") && exists(home + "/build/cmake/ohos.toolchain.cmake") && exists(home + "/sysroot")) { return home }
    }
    throw Exception("SDK has no native component with clang, sysroot and CMake toolchain")
}

func prepareSdkToolchain(o: HapSdkGetOptions, root: String): Unit {
    if (o.subject == "jdk") { return }
    if (o.subject == "android") { prepareAndroidSdk(o, root); return }
    if (o.subject == "ohos") {
        let archives = sdkFind(root, "*.zip")
        var count: Int64 = 0
        for (archive in archives) {
            let parts = archive.split("/")
            let name = parts[parts.size - 1]
            let hostMatches = if (startsWithText(o.target, "macos-")) { containsText(name, "darwin") } else { containsText(name, "linux") }
            if (hostMatches && (o.profile == "full" || startsWithText(name, "native-") || startsWithText(name, "toolchains-"))) {
                sdkExtractArchive(archive, root + "/components/current")
                count += 1
            }
        }
        if (count == 0) { throw Exception("OpenHarmony archive has no components for the selected native host") }
        let native = sdkNativeHome(root)
        let metadata = String.fromUtf8(File.readFrom(native + "/oh-uni-package.json"))
        let api = jsonStringValueForKey(metadata, "apiVersion")
        if (!allAsciiDigits(api)) { throw Exception("OpenHarmony component lacks a numeric API version") }
        rename(root + "/components/current", to: root + "/components/" + api)
        for (archive in archives) { removeIfExists(archive) }
        return
    }
    // Command Line Tools contains the SDK and a private Node/JDK. Discover the
    // delivered layout instead of borrowing executables from a system DevEco.
    sdkFindOne(root, "ohpm")
    sdkFindOne(root, "hvigorw")
    sdkNativeHome(root)
}

func sdkAndroidJava(o: HapSdkGetOptions): String {
    if (o.javaHome.size > 0) {
        if (!exists(o.javaHome + "/bin/java")) { throw Exception("--java-home lacks bin/java") }
        return o.javaHome
    }
    // Provision Java privately without changing the user's active JAVA_HOME.
    let output = runSdkToolchainGet(["hap", "get", "jdk", "--provider", "semeru", "--version", "21", "--install-root", o.root, "--no-activate"])
    if (cangjieToolchainGetExitCode(output) != 0) { throw Exception("Android JDK provisioning failed: " + output) }
    return sdkJdkHome(jsonStringValueForKey(output, "finalRoot") + "/payload")
}

func prepareAndroidSdk(o: HapSdkGetOptions, root: String): Unit {
    let manager = sdkFindOne(root, "sdkmanager")
    let tools = parentPath(parentPath(manager))
    let sdk = root + "/sdk"
    ensureCangjieToolchainDirectory(sdk + "/cmdline-tools")
    rename(tools, to: sdk + "/cmdline-tools/latest")
    o.javaHome = sdkAndroidJava(o)
    File.writeTo(root + "/java-home.txt", (o.javaHome + "\n").toArray())
    let installedManager = sdk + "/cmdline-tools/latest/bin/sdkmanager"
    let javaEnv = "JAVA_HOME=" + o.javaHome
    sdkCommand("env", [javaEnv, installedManager, "--sdk_root=" + sdk, "--version"])
    if (o.profile == "tools") { return }
    // The user explicitly selected --accept-licenses. The vendor manager records
    // acceptance; HapCLI never fabricates license hashes or accepted receipts.
    sdkCommand("sh", ["-c", "yes | \"$@\"", "hap-sdk-licenses", "env", javaEnv, installedManager, "--sdk_root=" + sdk, "--licenses"])
    let packages = ArrayList<String>()
    packages.add(javaEnv); packages.add(installedManager); packages.add("--sdk_root=" + sdk)
    packages.add("platform-tools"); packages.add("platforms;android-" + o.version); packages.add("build-tools;" + o.buildTools)
    if (o.ndk.size > 0) { packages.add("ndk;" + o.ndk) }
    if (o.cmake.size > 0) { packages.add("cmake;" + o.cmake) }
    sdkCommand("env", packages.toArray())
}

func sdkVerifyJdk(o: HapSdkGetOptions, root: String): Unit {
    let home = sdkJdkHome(root)
    let metadata = String.fromUtf8(File.readFrom(home + "/release"))
    if (!containsText(metadata, "IBM") && !containsText(metadata, "Semeru")) { throw Exception("JDK archive does not identify IBM Semeru") }
    for (line in metadata.split("\n")) {
        if (startsWithText(line, "JAVA_VERSION=")) { o.observedVersion = trimAsciiText(substringFrom(line, 13)).replace("\"", "") }
    }
    var requested = o.version
    if (startsWithText(requested, "jdk-")) { requested = substringFrom(requested, 4) }
    let major = requested.split(".")[0].split("+")[0]
    if (!startsWithText(o.observedVersion, major + ".") && o.observedVersion != major) { throw Exception("installed JDK major does not match requested version") }
    sdkCommand(home + "/bin/java", ["-version"])
    let smoke = root + "/.hap-java-smoke"
    ensureCangjieToolchainDirectory(smoke)
    File.writeTo(smoke + "/HapSdkSmoke.java", "public class HapSdkSmoke { public static void main(String[] args) { System.out.print(\"hap-sdk-ok\"); } }".toArray())
    sdkCommand(home + "/bin/javac", ["-d", smoke, smoke + "/HapSdkSmoke.java"])
    if (trimAsciiText(sdkCommand(home + "/bin/java", ["-cp", smoke, "HapSdkSmoke"])) != "hap-sdk-ok") { throw Exception("JDK compile/run smoke failed") }
    removeIfExists(smoke, recursive: true)
}

func verifySdkToolchain(o: HapSdkGetOptions, root: String): Unit {
    if (o.subject == "jdk") { sdkVerifyJdk(o, root); return }
    if (o.subject == "android") {
        o.apiVersion = o.version
        o.observedVersion = o.buildTools
        o.javaHome = trimAsciiText(String.fromUtf8(File.readFrom(root + "/java-home.txt")))
        let sdk = root + "/sdk"
        sdkCommand("env", ["JAVA_HOME=" + o.javaHome, sdk + "/cmdline-tools/latest/bin/sdkmanager", "--sdk_root=" + sdk, "--version"])
        if (o.profile == "tools") { return }
        for (path in ["platforms/android-" + o.version + "/android.jar", "build-tools/" + o.buildTools + "/aapt2", "platform-tools/adb"]) {
            if (!exists(sdk + "/" + path)) { throw Exception("Android package missing after install: " + path) }
        }
        sdkCommand(sdk + "/platform-tools/adb", ["version"])
        sdkCommand(sdk + "/build-tools/" + o.buildTools + "/aapt2", ["version"])
        if (o.ndk.size > 0) {
            if (!exists(sdk + "/ndk/" + o.ndk + "/build/cmake/android.toolchain.cmake")) { throw Exception("NDK toolchain missing") }
            let clang = sdkFindOne(sdk + "/ndk/" + o.ndk, "clang")
            sdkCommand(clang, ["--version"])
        }
        if (o.cmake.size > 0) { sdkCommand(sdk + "/cmake/" + o.cmake + "/bin/cmake", ["--version"]) }
        return
    }
    let native = sdkNativeHome(root)
    let metadata = String.fromUtf8(File.readFrom(native + "/oh-uni-package.json"))
    o.apiVersion = jsonStringValueForKey(metadata, "apiVersion")
    o.observedVersion = jsonStringValueForKey(metadata, "version")
    if (!allAsciiDigits(o.apiVersion) || !sdkGetToken(o.observedVersion)) { throw Exception("invalid native SDK version metadata") }
    if (o.subject == "ohos" && o.version == "6.0" && (o.apiVersion != "20" || o.observedVersion != "6.0.0.47")) { throw Exception("OpenHarmony 6.0 archive does not contain SDK 6.0.0.47 / API 20") }
    sdkCommand(native + "/llvm/bin/clang", ["--version"])
    let smoke = root + "/.hap-native-smoke"
    ensureCangjieToolchainDirectory(smoke)
    File.writeTo(smoke + "/hello.c", "#include <stdio.h>\nint main(void) { puts(\"hap-sdk-ok\"); return 0; }\n".toArray())
    sdkCommand(native + "/llvm/bin/clang", ["--target=aarch64-linux-ohos", "--sysroot=" + native + "/sysroot", "-c", smoke + "/hello.c", "-o", smoke + "/hello.o"])
    if (!exists(smoke + "/hello.o")) { throw Exception("OHOS native compile produced no object") }
    removeIfExists(smoke, recursive: true)
    sdkCommand(sdkFindOne(root, "hdc"), ["-v"])
    if (o.subject == "ohos" && o.profile == "full") {
        for (component in ["ets", "js", "toolchains"]) {
            if (!exists(parentPath(native) + "/" + component + "/oh-uni-package.json")) { throw Exception("full OpenHarmony SDK missing component: " + component) }
        }
    }
    if (o.subject == "harmonyos") {
        let node = sdkFindOne(root, "node")
        let ohpm = sdkFindOne(root, "ohpm")
        let hvigor = sdkFindOne(root, "hvigorw")
        let path = "PATH=" + parentPath(node) + ":" + cangjiePackageEnvironmentPath("PATH")
        let java = "JAVA_HOME=" + sdkJdkHome(root)
        sdkCommand(node, ["--version"])
        sdkCommand("env", [path, java, ohpm, "--version"])
        sdkCommand("env", [path, java, hvigor, "--version"])
    }
}

func sdkEnvironmentPath(paths: Array<String>): String {
    let out = StringBuilder()
    var i = paths.size - 1
    while (i >= 0) {
        let path = shellQuote(paths[i])
        out.append("case \":$PATH:\" in *:" + path + ":*) ;; *) export PATH=" + path + ":\"$PATH\" ;; esac\n")
        i -= 1
    }
    out.toString()
}

func sdkWriteLauncher(path: String, environment: String, program: String): Unit {
    File.writeTo(path, ("#!/bin/sh\n" + environment + "exec " + shellQuote(program) + " \"$@\"\n").toArray())
    sdkCommand("chmod", ["755", path])
}

func writeSdkToolchainLaunchers(o: HapSdkGetOptions, root: String): Unit {
    if (o.subject != "android" && o.subject != "harmonyos") { return }
    ensureCangjieToolchainDirectory(root + "/hap-bin")
    if (o.subject == "android") {
        for (name in ["sdkmanager", "avdmanager"]) {
            let program = root + "/sdk/cmdline-tools/latest/bin/" + name
            if (exists(program)) { sdkWriteLauncher(root + "/hap-bin/" + name, "export JAVA_HOME=" + shellQuote(o.javaHome) + "\n", program) }
        }
    } else {
        let node = sdkFindOne(root, "node")
        let environment = "export JAVA_HOME=" + shellQuote(sdkJdkHome(root)) + "\nexport NODE_HOME=" + shellQuote(parentPath(parentPath(node))) + "\n" + sdkEnvironmentPath([parentPath(node)])
        for (name in ["ohpm", "hvigorw"]) { sdkWriteLauncher(root + "/hap-bin/" + name, environment, sdkFindOne(root, name)) }
    }
}

func sdkToolchainEnvironment(o: HapSdkGetOptions, root: String): String {
    if (o.subject == "jdk") {
        let home = sdkJdkHome(root)
        return "export JAVA_HOME=" + shellQuote(home) + "\n" + sdkEnvironmentPath([home + "/bin"])
    }
    if (o.subject == "android") {
        let sdk = root + "/sdk"
        var environment = "export ANDROID_HOME=" + shellQuote(sdk) + "\nexport ANDROID_SDK_ROOT=\"$ANDROID_HOME\"\nexport HAP_ANDROID_JAVA_HOME=" + shellQuote(o.javaHome) + "\n" + sdkEnvironmentPath([root + "/hap-bin", sdk + "/cmdline-tools/latest/bin", sdk + "/platform-tools"])
        if (o.ndk.size > 0) { environment += "export ANDROID_NDK_HOME=" + shellQuote(sdk + "/ndk/" + o.ndk) + "\n" }
        return environment
    }
    let native = sdkNativeHome(root)
    if (o.subject == "ohos") {
        return "export OHOS_SDK_HOME=" + shellQuote(parentPath(parentPath(native))) + "\nexport OHOS_BASE_SDK_HOME=\"$OHOS_SDK_HOME\"\nexport OHOS_SDK_NATIVE=" + shellQuote(native) + "\n" + sdkEnvironmentPath([native + "/llvm/bin", parentPath(native) + "/toolchains"])
    }
    let node = sdkFindOne(root, "node")
    let hdc = sdkFindOne(root, "hdc")
    let base = parentPath(parentPath(native))
    let sdk = if (base.endsWith("/default")) { parentPath(base) } else { base }
    return "export HARMONYOS_SDK_HOME=" + shellQuote(sdk) + "\nexport DEVECO_SDK_HOME=" + shellQuote(sdk) + "\nexport HAP_HARMONYOS_JAVA_HOME=" + shellQuote(sdkJdkHome(root)) + "\nexport HAP_HARMONYOS_NATIVE=" + shellQuote(native) + "\n" + sdkEnvironmentPath([root + "/hap-bin", parentPath(node), parentPath(hdc)])
}

// Expand links against the complete archive graph before extraction. Lexical
// '..' checks alone miss a/../../x when a itself is a symbolic link.
func resolveSdkArchivePath(path: String, names: ArrayList<String>, targets: ArrayList<String>, depth: Int64): String {
    if (depth > 40 || startsWithText(path, "/") || containsText(path, "\\") || containsText(path, ":")) { throw Exception("unsafe or cyclic archive link") }
    let parts = path.split("/")
    let stack = ArrayList<String>()
    for (i in 0..parts.size) {
        let part = parts[i]
        if (part == "" || part == ".") { continue }
        if (part == "..") {
            if (stack.size == 0) { throw Exception("archive link escapes installation root") }
            stack.remove(at: stack.size - 1)
            continue
        }
        stack.add(part)
        var current = ""
        for (piece in stack) { current += if (current.size == 0) { piece } else { "/" + piece } }
        for (n in 0..names.size) {
            if (current == names[n]) {
                var expanded = targets[n]
                for (j in (i + 1)..parts.size) { expanded += "/" + parts[j] }
                return resolveSdkArchivePath(expanded, names, targets, depth + 1)
            }
        }
    }
    var result = ""
    for (piece in stack) { result += if (result.size == 0) { piece } else { "/" + piece } }
    return result
}

func validateSdkTarLinks(archive: String): Unit {
    let members = sdkCommand("tar", ["-tzf", archive])
    if (bootstrapArchiveListUnsafe(members)) { throw Exception("unsafe tar member path") }
    for (member in members.split("\n")) {
        if (containsText(member, " ") || containsText(member, "\t") || containsText(member, "\r")) { throw Exception("ambiguous whitespace in SDK tar member name") }
    }
    let names = ArrayList<String>()
    let targets = ArrayList<String>()
    let empty = ArrayList<String>()
    let listing = sdkCommand("tar", ["-tvzf", archive])
    for (line in listing.split("\n")) {
        if (line.size == 0) { continue }
        if (startsWithText(line, "-") || startsWithText(line, "d")) { continue }
        if (!startsWithText(line, "l") && !startsWithText(line, "h")) { throw Exception("tar special files are not accepted") }
        let symbolic = startsWithText(line, "l")
        let separator = if (symbolic) { " -> " } else { " link to " }
        let at = indexOfText(line, separator)
        if (at < 0) { throw Exception("cannot interpret archive link metadata") }
        let fields = trimAsciiText(substringRange(line, 0, at)).split(" ")
        let member = fields[fields.size - 1]
        let target = substringFrom(line, at + separator.size)
        if (target.size == 0 || startsWithText(target, "/") || containsText(target, " ")) { throw Exception("unsafe archive link target") }
        let name = resolveSdkArchivePath(member, empty, empty, 0)
        if (names.contains(name)) { throw Exception("duplicate archive link name") }
        names.add(name)
        targets.add(if (symbolic && containsText(name, "/")) { parentPath(name) + "/" + target } else { target })
    }
    for (target in targets) { resolveSdkArchivePath(target, names, targets, 0) }
    for (member in members.split("\n")) {
        if (member.size > 0) { resolveSdkArchivePath(member, names, targets, 0) }
    }
}
