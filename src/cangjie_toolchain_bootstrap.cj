package hapcli

import std.collection.ArrayList
import std.convert.*
import std.env.getVariable
import std.fs.{Directory, File, Path, exists}
import std.process.executeWithOutput
import std.time.*

public class HapCangjieBootstrapAsset {
    public var valid: Bool = false
    public var name: String = ""
    public var classification: String = ""
    public var sha256: String = ""
    public var mirrorUrl: String = ""
    public var sourceUrl: String = ""

    public init() {}
}

public class HapCangjieBootstrapResult {
    public var attempted: Bool = false
    public var ok: Bool = false
    public var status: String = "not-attempted"
    public var selectedRegion: String = ""
    public var regionSelectionSource: String = ""
    public var version: String = ""
    public var hostPlatform: String = ""
    public var sdkPlatform: String = ""
    public var stdxPlatform: String = ""
    public var cacheRoot: String = ""
    public var cacheRootSource: String = ""
    public var manifestPath: String = ""
    public var manifestUrl: String = ""
    public var sdkAsset: HapCangjieBootstrapAsset = HapCangjieBootstrapAsset()
    public var stdxAsset: HapCangjieBootstrapAsset = HapCangjieBootstrapAsset()
    public var sdkInstallRoot: String = ""
    public var stdxInstallRoot: String = ""
    public var envsetupPath: String = ""
    public var downloadSource: String = ""
    public var downloadActionTaken: Bool = false
    public var checksumVerified: Bool = false
    public var installActionTaken: Bool = false
    public var cacheHit: Bool = false
    public var diagnostic: String = ""

    public init() {}
}

public func defaultCangjieDownloadAccelerators(): Array<String> {
    ["https://ghfast.top/", "https://ghproxy.link/"]
}

public func rewriteGithubDownloadUrl(accelerator: String, originalUrl: String): String {
    let normalized = trimTrailingSlash(trimAsciiText(accelerator))
    if (!startsWithText(originalUrl, "https://github.com/")) {
        return ""
    }
    if (normalized != "https://ghfast.top" && normalized != "https://ghproxy.link") {
        return ""
    }
    normalized + "/" + originalUrl
}

public func cangjieBootstrapTransferCandidates(
    selectedRegion: String,
    mirrorUrl: String,
    sourceUrl: String,
    acceleration: String,
    accelerators: Array<String>
): ArrayList<String> {
    let candidates = ArrayList<String>()
    if (selectedRegion == "zh-cn") {
        addUniqueBootstrapText(candidates, sourceUrl)
        addUniqueBootstrapText(candidates, mirrorUrl)
    } else {
        addUniqueBootstrapText(candidates, mirrorUrl)
    }
    if (acceleration != "off") {
        for (accelerator in accelerators) {
            addUniqueBootstrapText(candidates, rewriteGithubDownloadUrl(accelerator, mirrorUrl))
        }
    }
    if (selectedRegion != "zh-cn") {
        addUniqueBootstrapText(candidates, sourceUrl)
    }
    candidates
}

public func resolveCangjieBootstrapSdkPlatform(osName: String, archName: String, target: String): String {
    let os = trimAsciiText(osName)
    let arch = trimAsciiText(archName)
    let canonical = canonicalTargetName(target)
    let ohos = canonical == "ohos-arm64" || canonical == "ohos-amd64"
    if (os == "Darwin" && (arch == "arm64" || arch == "aarch64")) {
        return "mac-aarch64"
    }
    if (os == "Darwin" && arch == "x86_64") {
        return "mac-x64"
    }
    if (os == "Linux" && arch == "x86_64") {
        return if (ohos) { "linux-x64-ohos" } else { "linux-x64" }
    }
    if (os == "Linux" && (arch == "aarch64" || arch == "arm64")) {
        return "linux-aarch64"
    }
    if ((startsWithText(os, "MINGW") || startsWithText(os, "MSYS") || startsWithText(os, "CYGWIN") || os == "Windows") &&
        (arch == "x86_64" || arch == "AMD64")) {
        return if (ohos) { "windows-x64-ohos" } else { "windows-x64" }
    }
    ""
}

public func resolveLatestCangjieMirrorTag(releasesJson: String): String {
    var cursor: Int64 = 0
    while (cursor < releasesJson.toRuneArray().size) {
        let tagIndex = indexOfTextFrom(releasesJson, "\"tag_name\"", cursor)
        if (tagIndex < 0) {
            return ""
        }
        let nextTag = indexOfTextFrom(releasesJson, "\"tag_name\"", tagIndex + 1)
        let draftIndex = indexOfTextFrom(releasesJson, "\"draft\"", tagIndex)
        if (draftIndex >= 0 && (nextTag < 0 || draftIndex < nextTag)) {
            let draftValue = jsonBoolValueAfter(releasesJson, draftIndex)
            if (draftValue == "false") {
                return jsonStringValueAfter(releasesJson, tagIndex)
            }
        }
        cursor = tagIndex + 1
    }
    ""
}

public func validateCangjieMirrorManifest(manifest: String, requestedTag: String): Bool {
    if (!containsText(manifest, "\"schema\": \"happub-cangjie-sdk-mirror-manifest-v1\"") ||
        !containsText(manifest, "\"ok\": true") ||
        !containsText(manifest, "\"status\": \"mirrored-verbatim\"") ||
        !containsText(manifest, "\"authority\": \"mirror-computed-sha256\"")) {
        return false
    }
    let upstream = jsonNamedObject(manifest, "upstream")
    let mirror = jsonNamedObject(manifest, "mirror")
    if (upstream.size == 0 || mirror.size == 0) {
        return false
    }
    let upstreamTag = jsonStringValueForKey(upstream, "tag")
    let mirrorTag = jsonStringValueForKey(mirror, "tag")
    upstreamTag.size > 0 && upstreamTag == mirrorTag && upstreamTag == requestedTag
}

public func resolveCangjieManifestAsset(manifest: String, exactName: String, expectedClassification: String): HapCangjieBootstrapAsset {
    let asset = HapCangjieBootstrapAsset()
    let object = jsonObjectContainingExactString(manifest, "name", exactName)
    if (object.size == 0) {
        return asset
    }
    asset.name = jsonStringValueForKey(object, "name")
    asset.classification = jsonStringValueForKey(object, "classification")
    asset.sha256 = jsonStringValueForKey(object, "sha256")
    asset.mirrorUrl = jsonStringValueForKey(object, "mirrorUrl")
    asset.sourceUrl = jsonStringValueForKey(object, "sourceUrl")
    asset.valid = asset.name == exactName && asset.classification == expectedClassification &&
        isLowerHexSha256(asset.sha256) && startsWithText(asset.mirrorUrl, "https://github.com/HapPub/CangjieSDK-Mirror/releases/download/") &&
        startsWithText(asset.sourceUrl, "https://gitcode.com/Cangjie/nightly_build/releases/download/")
    asset
}

public func resolveCangjieManifestAssetByPrefix(manifest: String, prefix: String, expectedClassification: String): HapCangjieBootstrapAsset {
    let empty = HapCangjieBootstrapAsset()
    var cursor: Int64 = 0
    var selectedAsset = HapCangjieBootstrapAsset()
    var count: Int64 = 0
    while (cursor < manifest.toRuneArray().size) {
        let nameIndex = indexOfTextFrom(manifest, "\"name\"", cursor)
        if (nameIndex < 0) {
            break
        }
        let value = jsonStringValueAfter(manifest, nameIndex)
        if (startsWithText(value, prefix)) {
            let candidate = resolveCangjieManifestAsset(manifest, value, expectedClassification)
            if (candidate.valid) {
                selectedAsset = candidate
                count += 1
            }
        }
        cursor = nameIndex + 1
    }
    if (count == 1) { selectedAsset } else { empty }
}

public func cangjieBootstrapSdkFilename(platform: String, version: String): String {
    if (platform.size == 0 || version.size == 0) {
        return ""
    }
    let extension = if (startsWithText(platform, "windows-")) { ".zip" } else { ".tar.gz" }
    "cangjie-sdk-" + platform + "-" + version + extension
}

public func cangjieBootstrapStdxPrefix(target: String, version: String): String {
    let platform = cangjieDownloadPlatformForTarget(target)
    if (platform.size == 0 || version.size == 0) {
        return ""
    }
    "cangjie-stdx-" + platform + "-" + version
}

func prepareCangjieToolchainBootstrap(options: HapBuildOptions, config: HapBuildConfig): HapCangjieBootstrapResult {
    let result = HapCangjieBootstrapResult()
    result.attempted = true
    let route = resolveCangjieSourceRoute(
        config.downloadRegion,
        config.downloadRegionExplicit,
        if (config.exists) { config.path } else { "" },
        ""
    )
    result.selectedRegion = route.selectedRegion
    result.regionSelectionSource = route.selectionSource
    if (!route.valid) {
        result.status = "invalid-source-route"
        return result
    }
    if (!isProgramResolvable("curl")) {
        result.status = "missing-bootstrap-downloader-curl"
        return result
    }
    let host = detectCangjieBootstrapHost()
    result.hostPlatform = host[0]
    result.sdkPlatform = resolveCangjieBootstrapSdkPlatform(host[0], host[1], options.target)
    result.stdxPlatform = cangjieDownloadPlatformForTarget(options.target)
    if (result.sdkPlatform.size == 0 || result.stdxPlatform.size == 0) {
        result.status = "unsupported-host-target-bootstrap-pair"
        return result
    }
    let cache = selectCangjieBootstrapCacheRoot(options.project, config.toolchainCacheRoot)
    result.cacheRoot = cache[0]
    result.cacheRootSource = cache[1]
    if (result.cacheRoot.size == 0) {
        result.status = "no-writable-toolchain-cache"
        return result
    }
    let accelerators = if (config.downloadAccelerators.size > 0) {
        config.downloadAccelerators.toArray()
    } else {
        defaultCangjieDownloadAccelerators()
    }
    var version = config.cangjieSdkVersion
    if (version.size == 0 || version == "auto") {
        let releasesPath = result.cacheRoot + "/mirror-releases.json"
        let releasesCandidates = cangjieBootstrapTransferCandidates(
            route.selectedRegion,
            "https://api.github.com/repos/HapPub/CangjieSDK-Mirror/releases?per_page=20",
            "",
            config.downloadAcceleration,
            accelerators
        )
        let releasesDownload = downloadCangjieBootstrapFile(releasesCandidates, releasesPath, config.toolchainBootstrapTimeoutSeconds, config.toolchainDownloadRetryCount, options.networkMode)
        if (!releasesDownload.ran || releasesDownload.exitCode != 0 || !exists(releasesPath)) {
            result.status = "mirror-release-resolution-failed"
            result.diagnostic = releasesDownload.stderr
            return result
        }
        version = resolveLatestCangjieMirrorTag(String.fromUtf8(File.readFrom(releasesPath)))
        if (version.size == 0) {
            result.status = "mirror-release-tag-not-found"
            return result
        }
    }
    result.version = version
    let versionRoot = result.cacheRoot + "/cangjie/" + version
    let downloadsRoot = versionRoot + "/downloads"
    result.sdkInstallRoot = versionRoot + "/sdk-" + result.sdkPlatform
    result.stdxInstallRoot = versionRoot + "/stdx-" + result.stdxPlatform
    result.manifestPath = versionRoot + "/manifest.v1.json"
    result.manifestUrl = cangjieSourceManifestUrl(route, version)
    try {
        if (!exists(downloadsRoot)) {
            Directory.create(downloadsRoot, recursive: true)
        }
    } catch (error: Exception) {
        result.status = "toolchain-cache-create-failed"
        result.diagnostic = error.message
        return result
    }
    var manifest = if (exists(result.manifestPath)) { String.fromUtf8(File.readFrom(result.manifestPath)) } else { "" }
    if (!validateCangjieMirrorManifest(manifest, version)) {
        let manifestCandidates = cangjieBootstrapTransferCandidates(
            route.selectedRegion,
            result.manifestUrl,
            "",
            config.downloadAcceleration,
            accelerators
        )
        let manifestDownload = downloadCangjieBootstrapFile(manifestCandidates, result.manifestPath, config.toolchainBootstrapTimeoutSeconds, config.toolchainDownloadRetryCount, options.networkMode)
        if (!manifestDownload.ran || manifestDownload.exitCode != 0 || !exists(result.manifestPath)) {
            result.status = "mirror-manifest-download-failed"
            result.diagnostic = manifestDownload.stderr
            return result
        }
        manifest = String.fromUtf8(File.readFrom(result.manifestPath))
    }
    if (!validateCangjieMirrorManifest(manifest, version)) {
        result.status = "mirror-manifest-validation-failed"
        return result
    }
    result.sdkAsset = resolveCangjieManifestAsset(manifest, cangjieBootstrapSdkFilename(result.sdkPlatform, version), "sdk")
    result.stdxAsset = resolveCangjieManifestAssetByPrefix(manifest, cangjieBootstrapStdxPrefix(options.target, version), "stdx")
    if (!result.sdkAsset.valid) {
        result.status = "mirror-sdk-asset-not-found"
        return result
    }
    if (!result.stdxAsset.valid) {
        result.status = "mirror-stdx-asset-not-found"
        return result
    }
    result.envsetupPath = findBootstrapEnvsetup(result.sdkInstallRoot)
    let sdkComplete = bootstrapCompletionMarkerMatches(result.sdkInstallRoot + "/.hap-complete", version, result.sdkAsset.sha256)
    let stdxComplete = bootstrapCompletionMarkerMatches(result.stdxInstallRoot + "/.hap-complete", version, result.stdxAsset.sha256)
    if (result.envsetupPath.size > 0 && sdkComplete && stdxComplete) {
        result.ok = true
        result.cacheHit = true
        result.checksumVerified = false
        result.status = "manifest-bound-toolchain-cache-hit"
        result.diagnostic = "cache hit accepted by manifest-bound envsetup and .hap-complete markers; installed files were not rehashed"
        return result
    }
    let sdkArchive = downloadsRoot + "/" + result.sdkAsset.name
    let stdxArchive = downloadsRoot + "/" + result.stdxAsset.name
    let sdkCandidates = cangjieBootstrapTransferCandidates(route.selectedRegion, result.sdkAsset.mirrorUrl, result.sdkAsset.sourceUrl, config.downloadAcceleration, accelerators)
    let sdkDownload = downloadCangjieBootstrapFile(sdkCandidates, sdkArchive, config.toolchainBootstrapTimeoutSeconds, config.toolchainDownloadRetryCount, options.networkMode)
    if (!sdkDownload.ran || sdkDownload.exitCode != 0) {
        result.status = "sdk-download-failed"
        result.diagnostic = sdkDownload.stderr
        return result
    }
    result.downloadActionTaken = true
    result.downloadSource = trimAsciiText(sdkDownload.stdout)
    if (!verifyCangjieBootstrapSha256(sdkArchive, result.sdkAsset.sha256)) {
        result.status = "sdk-checksum-rejected"
        return result
    }
    let stdxCandidates = cangjieBootstrapTransferCandidates(route.selectedRegion, result.stdxAsset.mirrorUrl, result.stdxAsset.sourceUrl, config.downloadAcceleration, accelerators)
    let stdxDownload = downloadCangjieBootstrapFile(stdxCandidates, stdxArchive, config.toolchainBootstrapTimeoutSeconds, config.toolchainDownloadRetryCount, options.networkMode)
    if (!stdxDownload.ran || stdxDownload.exitCode != 0) {
        result.status = "stdx-download-failed"
        result.diagnostic = stdxDownload.stderr
        return result
    }
    if (!verifyCangjieBootstrapSha256(stdxArchive, result.stdxAsset.sha256)) {
        result.status = "stdx-checksum-rejected"
        return result
    }
    result.checksumVerified = true
    let sdkExtract = extractCangjieBootstrapArchive(sdkArchive, result.sdkInstallRoot)
    if (!sdkExtract.ran || sdkExtract.exitCode != 0) {
        result.status = "sdk-extract-failed"
        result.diagnostic = sdkExtract.stderr
        return result
    }
    let stdxExtract = extractCangjieBootstrapArchive(stdxArchive, result.stdxInstallRoot)
    if (!stdxExtract.ran || stdxExtract.exitCode != 0) {
        result.status = "stdx-extract-failed"
        result.diagnostic = stdxExtract.stderr
        return result
    }
    result.installActionTaken = true
    result.envsetupPath = findBootstrapEnvsetup(result.sdkInstallRoot)
    if (result.envsetupPath.size == 0) {
        result.status = "sdk-envsetup-not-found"
        return result
    }
    writeBootstrapCompletionMarker(result.sdkInstallRoot + "/.hap-complete", version, result.sdkAsset.sha256)
    writeBootstrapCompletionMarker(result.stdxInstallRoot + "/.hap-complete", version, result.stdxAsset.sha256)
    result.ok = true
    result.status = "verified-and-installed"
    result
}

func downloadCangjieBootstrapFile(
    candidates: ArrayList<String>,
    outputPath: String,
    timeoutSeconds: Int64,
    retryCount: Int64,
    networkMode: String
): HapBuildCommandResult {
    var last = HapBuildCommandResult()
    for (candidate in candidates) {
        if (candidate.size == 0) {
            continue
        }
        if (startsWithText(candidate, "file://")) {
            let source = substringFrom(candidate, 7)
            try {
                File.writeTo(outputPath, File.readFrom(source))
                return HapBuildCommandResult(0, candidate, "")
            } catch (error: Exception) {
                last = HapBuildCommandResult(1, "", error.message)
                continue
            }
        }
        if (!startsWithText(candidate, "https://")) {
            last = HapBuildCommandResult(2, "", "refusing non-HTTPS bootstrap candidate")
            continue
        }
        let args = [
            "--proto", "=https", "--tlsv1.2", "--location", "--fail", "--show-error", "--silent",
            "--connect-timeout", timeoutSeconds.toString(), "--max-time", timeoutSeconds.toString(),
            "--retry", retryCount.toString(), "--retry-delay", "2", "--output", outputPath, candidate
        ]
        let command = resolveHapNetworkCommand(networkMode, "curl", args)
        let (code, stdoutBytes, stderrBytes) = executeWithOutput(command.program, command.args.toArray())
        last = HapBuildCommandResult(code, if (code == 0) { candidate } else { String.fromUtf8(stdoutBytes) }, String.fromUtf8(stderrBytes))
        if (code == 0 && exists(outputPath)) {
            return last
        }
    }
    last
}

func verifyCangjieBootstrapSha256(path: String, expected: String): Bool {
    if (!isLowerHexSha256(expected) || !exists(path)) {
        return false
    }
    var result = HapBuildCommandResult()
    if (isProgramResolvable("shasum")) {
        let (code, out, err) = executeWithOutput("shasum", ["-a", "256", path])
        result = HapBuildCommandResult(code, String.fromUtf8(out), String.fromUtf8(err))
    } else if (isProgramResolvable("sha256sum")) {
        let (code, out, err) = executeWithOutput("sha256sum", [path])
        result = HapBuildCommandResult(code, String.fromUtf8(out), String.fromUtf8(err))
    } else {
        return false
    }
    result.exitCode == 0 && firstBootstrapAsciiToken(result.stdout) == expected
}

func bootstrapCompletionMarkerMatches(path: String, version: String, sha256: String): Bool {
    if (!exists(path) || version.size == 0 || !isLowerHexSha256(sha256)) {
        return false
    }
    let expected = version + "\n" + sha256 + "\n"
    String.fromUtf8(File.readFrom(path)) == expected
}

func writeBootstrapCompletionMarker(path: String, version: String, sha256: String): Unit {
    File.writeTo(path, (version + "\n" + sha256 + "\n").toArray())
}

func extractCangjieBootstrapArchive(archive: String, destination: String): HapBuildCommandResult {
    try {
        if (!exists(destination)) {
            Directory.create(destination, recursive: true)
        }
    } catch (error: Exception) {
        return HapBuildCommandResult(1, "", error.message)
    }
    if (archive.endsWith(".zip")) {
        if (!isProgramResolvable("unzip")) {
            return HapBuildCommandResult(127, "", "missing required command: unzip")
        }
        let (listCode, listOut, listErr) = executeWithOutput("unzip", ["-Z1", archive])
        if (listCode != 0 || bootstrapArchiveListUnsafe(String.fromUtf8(listOut))) {
            return HapBuildCommandResult(1, String.fromUtf8(listOut), if (listCode != 0) { String.fromUtf8(listErr) } else { "unsafe archive member" })
        }
        let (code, out, err) = executeWithOutput("unzip", ["-q", "-o", archive, "-d", destination])
        return HapBuildCommandResult(code, String.fromUtf8(out), String.fromUtf8(err))
    }
    if (!isProgramResolvable("tar")) {
        return HapBuildCommandResult(127, "", "missing required command: tar")
    }
    let (listCode, listOut, listErr) = executeWithOutput("tar", ["-tzf", archive])
    if (listCode != 0 || bootstrapArchiveListUnsafe(String.fromUtf8(listOut))) {
        return HapBuildCommandResult(1, String.fromUtf8(listOut), if (listCode != 0) { String.fromUtf8(listErr) } else { "unsafe archive member" })
    }
    let (code, out, err) = executeWithOutput("tar", ["-xzf", archive, "-C", destination])
    HapBuildCommandResult(code, String.fromUtf8(out), String.fromUtf8(err))
}

func bootstrapArchiveListUnsafe(listing: String): Bool {
    for (line in listing.split("\n")) {
        let path = trimAsciiText(line)
        if (path.size == 0) {
            continue
        }
        if (startsWithText(path, "/") || startsWithText(path, "\\") || containsText(path, "../") || containsText(path, "..\\")) {
            return true
        }
    }
    false
}

func findBootstrapEnvsetup(root: String): String {
    if (root.size == 0 || !exists(root) || !isProgramResolvable("find")) {
        return ""
    }
    let (code, stdoutBytes, _) = executeWithOutput("find", [root, "-maxdepth", "7", "-type", "f", "-name", "envsetup.sh", "-print"])
    if (code != 0) {
        return ""
    }
    for (line in String.fromUtf8(stdoutBytes).split("\n")) {
        let path = trimAsciiText(line)
        if (path.size > 0 && exists(path)) {
            return path
        }
    }
    ""
}

func detectCangjieBootstrapHost(): Array<String> {
    let (osCode, osOut, _) = executeWithOutput("uname", ["-s"])
    let (archCode, archOut, _) = executeWithOutput("uname", ["-m"])
    if (osCode != 0 || archCode != 0) {
        return ["", ""]
    }
    [trimAsciiText(String.fromUtf8(osOut)), trimAsciiText(String.fromUtf8(archOut))]
}

func selectCangjieBootstrapCacheRoot(project: String, configured: String): Array<String> {
    let candidates = ArrayList<String>()
    let sources = ArrayList<String>()
    if (configured.size > 0) {
        candidates.add(trimTrailingSlash(configured))
        sources.add("configured")
    }
    match (getVariable("HOME")) {
        case Some(home) =>
            if (home.size > 0) {
                candidates.add(trimTrailingSlash(home) + "/.hap/toolchains")
                sources.add("home-private")
            }
        case None => ()
    }
    candidates.add(trimTrailingSlash(project) + "/.hapData/toolchains")
    sources.add("project-hapData-fallback")
    var i: Int64 = 0
    while (i < candidates.size) {
        try {
            if (!exists(candidates[i])) {
                Directory.create(candidates[i], recursive: true)
            }
            let marker = candidates[i] + "/.hap-write-access"
            File.writeTo(marker, (DateTime.nowUTC().toString() + "\n").toArray())
            return [candidates[i], sources[i]]
        } catch (_: Exception) {
            ()
        }
        i += 1
    }
    ["", ""]
}

func jsonNamedObject(text: String, key: String): String {
    let keyIndex = indexOfText(text, "\"" + key + "\"")
    if (keyIndex < 0) {
        return ""
    }
    jsonObjectFrom(text, keyIndex)
}

func jsonObjectContainingExactString(text: String, key: String, value: String): String {
    let needle = "\"" + key + "\": \"" + value + "\""
    let index = indexOfText(text, needle)
    if (index < 0 || indexOfTextFrom(text, needle, index + 1) >= 0) {
        return ""
    }
    jsonObjectAround(text, index)
}

func jsonObjectFrom(text: String, start: Int64): String {
    let open = indexOfTextFrom(text, "{", start)
    if (open < 0) {
        return ""
    }
    jsonObjectAtOpen(text, open)
}

func jsonObjectAround(text: String, index: Int64): String {
    let runes = text.toRuneArray()
    var open = index
    while (open >= 0 && runes[open] != r'{') {
        open -= 1
    }
    if (open < 0) {
        return ""
    }
    jsonObjectAtOpen(text, open)
}

func jsonObjectAtOpen(text: String, open: Int64): String {
    let runes = text.toRuneArray()
    var depth: Int64 = 0
    var i = open
    var quoted = false
    var escaped = false
    while (i < runes.size) {
        let rune = runes[i]
        if (quoted) {
            if (escaped) {
                escaped = false
            } else if (rune == r'\\') {
                escaped = true
            } else if (rune == r'"') {
                quoted = false
            }
        } else if (rune == r'"') {
            quoted = true
        } else if (rune == r'{') {
            depth += 1
        } else if (rune == r'}') {
            depth -= 1
            if (depth == 0) {
                return substringRange(text, open, i + 1)
            }
        }
        i += 1
    }
    ""
}

func jsonStringValueForKey(text: String, key: String): String {
    let index = indexOfText(text, "\"" + key + "\"")
    if (index < 0) { "" } else { jsonStringValueAfter(text, index) }
}

func jsonStringValueAfter(text: String, keyIndex: Int64): String {
    let colon = indexOfTextFrom(text, ":", keyIndex)
    if (colon < 0) {
        return ""
    }
    let open = indexOfTextFrom(text, "\"", colon + 1)
    if (open < 0) {
        return ""
    }
    let runes = text.toRuneArray()
    var i = open + 1
    var value = ""
    var escaped = false
    while (i < runes.size) {
        let rune = runes[i]
        if (escaped) {
            value += rune.toString()
            escaped = false
        } else if (rune == r'\\') {
            escaped = true
        } else if (rune == r'"') {
            return value
        } else {
            value += rune.toString()
        }
        i += 1
    }
    ""
}

func jsonBoolValueAfter(text: String, keyIndex: Int64): String {
    let colon = indexOfTextFrom(text, ":", keyIndex)
    if (colon < 0) {
        return ""
    }
    let tail = trimAsciiText(substringFrom(text, colon + 1))
    if (startsWithText(tail, "true")) { "true" } else if (startsWithText(tail, "false")) { "false" } else { "" }
}

func indexOfTextFrom(text: String, needle: String, start: Int64): Int64 {
    if (start < 0 || start >= text.toRuneArray().size) {
        return -1
    }
    let relative = indexOfText(substringFrom(text, start), needle)
    if (relative < 0) { -1 } else { start + relative }
}

func isLowerHexSha256(value: String): Bool {
    if (value.toRuneArray().size != 64) {
        return false
    }
    for (rune in value.toRuneArray()) {
        if (!((rune >= r'0' && rune <= r'9') || (rune >= r'a' && rune <= r'f'))) {
            return false
        }
    }
    true
}

func firstBootstrapAsciiToken(text: String): String {
    let trimmed = trimAsciiText(text)
    for (part in trimmed.split(" ")) {
        if (part.size > 0) {
            return trimAsciiText(part)
        }
    }
    ""
}

func addUniqueBootstrapText(items: ArrayList<String>, value: String): Unit {
    let normalized = trimAsciiText(value)
    if (normalized.size == 0) {
        return
    }
    for (item in items) {
        if (item == normalized) {
            return
        }
    }
    items.add(normalized)
}

func applyCangjieBootstrapResult(options: HapBuildOptions, result: HapCangjieBootstrapResult): Unit {
    options.toolchainBootstrapAttempted = result.attempted
    options.toolchainBootstrapOk = result.ok
    options.toolchainBootstrapStatus = result.status
    options.toolchainBootstrapVersion = result.version
    options.toolchainBootstrapSdkPlatform = result.sdkPlatform
    options.toolchainBootstrapStdxPlatform = result.stdxPlatform
    options.toolchainBootstrapCacheRoot = result.cacheRoot
    options.toolchainBootstrapCacheRootSource = result.cacheRootSource
    options.toolchainBootstrapManifestPath = result.manifestPath
    options.toolchainBootstrapManifestUrl = result.manifestUrl
    options.toolchainBootstrapSdkAsset = result.sdkAsset.name
    options.toolchainBootstrapSdkSha256 = result.sdkAsset.sha256
    options.toolchainBootstrapStdxAsset = result.stdxAsset.name
    options.toolchainBootstrapStdxSha256 = result.stdxAsset.sha256
    options.toolchainBootstrapSdkInstallRoot = result.sdkInstallRoot
    options.toolchainBootstrapStdxInstallRoot = result.stdxInstallRoot
    options.toolchainBootstrapEnvsetupPath = result.envsetupPath
    options.toolchainBootstrapDownloadSource = result.downloadSource
    options.toolchainBootstrapDownloadActionTaken = result.downloadActionTaken
    options.toolchainBootstrapChecksumVerified = result.checksumVerified
    options.toolchainBootstrapInstallActionTaken = result.installActionTaken
    options.toolchainBootstrapCacheHit = result.cacheHit
    options.toolchainBootstrapDiagnostic = result.diagnostic
}

func cjpmFailureLooksLikeMissingTargetToolchain(result: HapBuildCommandResult): Bool {
    let text = result.stdout + "\n" + result.stderr
    containsText(text, "target is not supported") ||
        containsText(text, "unsupported target") ||
        containsText(text, "CANGJIE_STDX_PATH") ||
        containsText(text, "stdx") ||
        containsText(text, "cannot find target") ||
        containsText(text, "missing required command: cjpm")
}

func readHapBootstrapTomlInt(text: String, key: String, fallback: Int64): Int64 {
    for (line in text.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (startsWithText(trimmed, key + " ") || startsWithText(trimmed, key + "=")) {
            let equal = indexOfText(trimmed, "=")
            if (equal >= 0) {
                let raw = trimAsciiText(substringFrom(trimmed, equal + 1))
                try {
                    let value = Int64.parse(raw)
                    return if (value >= 0) { value } else { fallback }
                } catch (_: Exception) {
                    return fallback
                }
            }
        }
    }
    fallback
}

func readHapBootstrapStringArray(text: String, key: String): ArrayList<String> {
    let values = ArrayList<String>()
    let keyIndex = indexOfText(text, key)
    if (keyIndex < 0) {
        return values
    }
    let open = indexOfTextFrom(text, "[", keyIndex)
    let close = if (open >= 0) { indexOfTextFrom(text, "]", open + 1) } else { -1 }
    if (open < 0 || close < 0) {
        return values
    }
    for (value in extractQuotedValues(substringRange(text, open, close + 1))) {
        values.add(value)
    }
    values
}
