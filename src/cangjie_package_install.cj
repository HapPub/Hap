package hapcli

import std.collection.ArrayList
import std.convert.*
import std.env.getVariable
import std.fs.{Directory, File, exists}

public class HapCangjiePackageInstallOptions {
    public var requestedSpec: String = ""
    public var requestedPackage: String = ""
    public var resolvedPackage: String = ""
    public var requestedVersion: String = "latest"
    public var resolvedVersion: String = ""
    public var assetVersion: String = ""
    public var releaseChannel: String = ""
    public var target: String = ""
    public var platform: String = ""
    public var requestedRegion: String = "auto"
    public var selectedRegion: String = "global"
    public var regionSelectionSource: String = "default-global"
    public var installRoot: String = ""
    public var receipt: String = ""
    public var networkMode: String = "no-proxy"
    public var timeoutSeconds: Int64 = 900
    public var retryCount: Int64 = 2
    public var plan: Bool = false
    public var valid: Bool = false
    public var errorCode: String = ""
    public var errorMessage: String = ""

    public init() {}
}

public class HapCangjiePackageInstallAsset {
    public var valid: Bool = false
    public var packageName: String = ""
    public var name: String = ""
    public var version: String = ""
    public var url: String = ""
    public var mirrorUrl: String = ""
    public var sourceUrl: String = ""
    public var sha256: String = ""
    public var checksumAuthority: String = ""

    public init() {}
}

public class HapCangjiePackageInstallResult {
    public var ok: Bool = false
    public var status: String = "not-started"
    public var cacheHit: Bool = false
    public var downloadActionTaken: Bool = false
    public var installActionTaken: Bool = false
    public var checksumVerified: Bool = false
    public var archivePath: String = ""
    public var finalRoot: String = ""
    public var envsetupPath: String = ""
    public var activationHint: String = ""
    public var diagnostic: String = ""

    public init() {}
}

public func resolveCangjiePackageInstallOptions(commandLine: Array<String>, start: Int64): HapCangjiePackageInstallOptions {
    let options = HapCangjiePackageInstallOptions()
    if (start >= commandLine.size) {
        return rejectCangjiePackageOptions(options, "missing-package-spec", "usage: hap install <cangjie|cangjie-sdk|cangjie-stdx>[@version] [--target <target>] [--install-root <path>] [--plan]")
    }
    options.requestedSpec = trimAsciiText(commandLine[start])
    parseCangjiePackageSpec(options)
    var i = start + 1
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--target" && i + 1 < commandLine.size) {
            options.target = canonicalTargetName(commandLine[i + 1])
            i += 2
            continue
        }
        if (startsWithText(current, "--target=")) {
            options.target = canonicalTargetName(substringFrom(current, 9))
            i += 1
            continue
        }
        if (current == "--install-root" && i + 1 < commandLine.size) {
            options.installRoot = trimTrailingSlash(commandLine[i + 1])
            i += 2
            continue
        }
        if (startsWithText(current, "--install-root=")) {
            options.installRoot = trimTrailingSlash(substringFrom(current, 15))
            i += 1
            continue
        }
        if (current == "--receipt" && i + 1 < commandLine.size) {
            options.receipt = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--receipt=")) {
            options.receipt = substringFrom(current, 10)
            i += 1
            continue
        }
        if (current == "--region" && i + 1 < commandLine.size) {
            options.requestedRegion = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--region=")) {
            options.requestedRegion = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--timeout-seconds" && i + 1 < commandLine.size) {
            options.timeoutSeconds = parsePositiveCangjieInstallInt(commandLine[i + 1], options.timeoutSeconds)
            i += 2
            continue
        }
        if (startsWithText(current, "--timeout-seconds=")) {
            options.timeoutSeconds = parsePositiveCangjieInstallInt(substringFrom(current, 18), options.timeoutSeconds)
            i += 1
            continue
        }
        if (current == "--retry" && i + 1 < commandLine.size) {
            options.retryCount = parseNonNegativeCangjieInstallInt(commandLine[i + 1], options.retryCount)
            i += 2
            continue
        }
        if (startsWithText(current, "--retry=")) {
            options.retryCount = parseNonNegativeCangjieInstallInt(substringFrom(current, 8), options.retryCount)
            i += 1
            continue
        }
        if (current == "--proxy") {
            options.networkMode = "inherit-proxy"
            i += 1
            continue
        }
        if (current == "--no-proxy") {
            options.networkMode = "no-proxy"
            i += 1
            continue
        }
        if (current == "--plan") {
            options.plan = true
            i += 1
            continue
        }
        return rejectCangjiePackageOptions(options, "unknown-install-option", "unknown Cangjie package install option: " + current)
    }
    if (!options.valid) {
        return options
    }
    if (options.target.size == 0) {
        options.target = detectNativeCangjieInstallTarget()
    }
    options.platform = cangjieDownloadPlatformForTarget(options.target)
    if (!isNativeCangjieInstallTarget(options.target) || options.platform.size == 0) {
        return rejectCangjiePackageOptions(options, "unsupported-install-target", "supported targets: macos-arm64, macos-amd64, linux-arm64, linux-amd64, windows-amd64")
    }
    let route = resolveCangjieSourceRoute(options.requestedRegion, options.requestedRegion != "auto", "", "")
    if (!route.valid) {
        return rejectCangjiePackageOptions(options, "invalid-install-region", "supported regions: auto, global, zh-cn")
    }
    options.selectedRegion = route.selectedRegion
    options.regionSelectionSource = route.selectionSource
    if (options.installRoot.size == 0) {
        options.installRoot = defaultCangjiePackageInstallRoot()
    }
    if (options.installRoot.size == 0) {
        return rejectCangjiePackageOptions(options, "install-root-unavailable", "HOME is unavailable; pass --install-root explicitly")
    }
    if (!cangjiePackageInstallRootIsPrivate(options.installRoot)) {
        return rejectCangjiePackageOptions(options, "install-root-not-private", "install root must stay under HOME/.hap or an OS temporary directory")
    }
    if (options.receipt.size == 0) {
        options.receipt = options.installRoot + "/receipts/" + options.resolvedPackage + "-" + options.assetVersion + "-" + options.target + ".json"
    } else if (!cangjiePackageReceiptIsPrivate(options.installRoot, options.receipt)) {
        return rejectCangjiePackageOptions(options, "receipt-outside-install-root", "receipt must stay inside the selected private install root")
    }
    options
}

func parseCangjiePackageSpec(options: HapCangjiePackageInstallOptions): Unit {
    let parts = options.requestedSpec.split("@")
    if (parts.size > 2 || parts.size == 0) {
        rejectCangjiePackageOptions(options, "invalid-package-spec", "package spec must contain at most one @version suffix")
        return
    }
    options.requestedPackage = trimAsciiText(parts[0])
    if (options.requestedPackage != "cangjie" && options.requestedPackage != "cangjie-sdk" && options.requestedPackage != "cangjie-stdx") {
        rejectCangjiePackageOptions(options, "unknown-cangjie-package", "supported packages: cangjie, cangjie-sdk, cangjie-stdx")
        return
    }
    options.resolvedPackage = if (options.requestedPackage == "cangjie") { "cangjie-sdk" } else { options.requestedPackage }
    if (parts.size == 2) {
        options.requestedVersion = trimAsciiText(parts[1])
        if (options.requestedVersion.size == 0) {
            rejectCangjiePackageOptions(options, "invalid-package-spec", "version suffix after @ must not be empty")
            return
        }
    }
    let requested = options.requestedVersion
    if (requested == "latest" || requested == "lts") {
        options.resolvedVersion = "1.0.5"
        options.releaseChannel = "LTS"
    } else if (requested == "1.0.5" || (options.resolvedPackage == "cangjie-stdx" && requested == "1.0.5.1")) {
        options.resolvedVersion = "1.0.5"
        options.releaseChannel = "LTS"
    } else if (requested == "1.1.3" || (options.resolvedPackage == "cangjie-stdx" && requested == "1.1.3.1")) {
        options.resolvedVersion = "1.1.3"
        options.releaseChannel = "STS"
    } else {
        rejectCangjiePackageOptions(options, "unsupported-cangjie-version", "supported release lines: latest/lts (1.0.5 LTS), 1.0.5, 1.1.3 STS")
        return
    }
    options.assetVersion = if (options.resolvedPackage == "cangjie-stdx") { options.resolvedVersion + ".1" } else { options.resolvedVersion }
    options.valid = true
}

func rejectCangjiePackageOptions(options: HapCangjiePackageInstallOptions, code: String, message: String): HapCangjiePackageInstallOptions {
    options.valid = false
    options.errorCode = code
    options.errorMessage = message
    options
}

public func resolveCangjiePackageInstallAsset(options: HapCangjiePackageInstallOptions): HapCangjiePackageInstallAsset {
    if (!options.valid) {
        return HapCangjiePackageInstallAsset()
    }
    if (options.resolvedPackage == "cangjie-sdk") {
        return resolveOfficialCangjieSdkInstallAsset(options.assetVersion, options.platform)
    }
    resolveOfficialCangjieStdxInstallAsset(options.assetVersion, options.platform)
}

public func resolveOfficialCangjieSdkInstallAsset(version: String, platform: String): HapCangjiePackageInstallAsset {
    let asset = HapCangjiePackageInstallAsset()
    asset.packageName = "cangjie-sdk"
    asset.version = version
    asset.checksumAuthority = "cangjie-lang-official-sha256"
    if (version == "1.0.5" && platform == "mac-aarch64") {
        setOfficialCangjieSdkAsset(asset, "cangjie-sdk-mac-aarch64-1.0.5.tar.gz", "698acea5bd66ae22b62330ae", "e07d22584237f065b30a771b7110a87a8931334c40be3a148090944ae916ed1f")
    } else if (version == "1.0.5" && platform == "linux-x64") {
        setOfficialCangjieSdkAsset(asset, "cangjie-sdk-linux-x64-1.0.5.tar.gz", "698acf46bd66ae22b62330b0", "bacad84df8e0281c5395bab4c40e481e3ea6cc712eed5c953903b0d561a14562")
    } else if (version == "1.0.5" && platform == "linux-aarch64") {
        setOfficialCangjieSdkAsset(asset, "cangjie-sdk-linux-aarch64-1.0.5.tar.gz", "698acfa3bd66ae22b62330b1", "c0dc48b8851fd87853308bf0ef5cce7040f8681ae8a53005d5dac81657745a35")
    } else if (version == "1.0.5" && platform == "windows-x64") {
        setOfficialCangjieSdkAsset(asset, "cangjie-sdk-windows-x64-1.0.5.zip", "698acebfbd66ae22b62330af", "08c6c1dd0de73396f63ac85085d635e79ce84fef98d330cb00869b4fc8f1cb2e")
    } else if (version == "1.1.3" && platform == "mac-aarch64") {
        setOfficialCangjieSdkAsset(asset, "cangjie-sdk-mac-aarch64-1.1.3.tar.gz", "6a19312721f5a8178d6fd225", "7eff8d3b9119535cf3d05cb81526c5df391137dce908d744449f4edb99da3199")
    } else if (version == "1.1.3" && platform == "linux-x64") {
        setOfficialCangjieSdkAsset(asset, "cangjie-sdk-linux-x64-1.1.3.tar.gz", "6a19349d21f5a8178d6fd22b", "2b68905afc466e665ae181595c63f96c18d75fd2c1fb6c6f0cb64e179c28d61a")
    } else if (version == "1.1.3" && platform == "linux-aarch64") {
        setOfficialCangjieSdkAsset(asset, "cangjie-sdk-linux-aarch64-1.1.3.tar.gz", "6a19350321f5a8178d6fd22c", "0b0ce42ce2492f654b00029687229188c82751418cb34df7990efd43eaf9c41f")
    } else if (version == "1.1.3" && platform == "windows-x64") {
        setOfficialCangjieSdkAsset(asset, "cangjie-sdk-windows-x64-1.1.3.zip", "6a192b2521f5a8178d6fd222", "8bb65499c1b30271eaca422568bc9537677bd25debd8f5208e780a22c917da72")
    }
    asset
}

func setOfficialCangjieSdkAsset(asset: HapCangjiePackageInstallAsset, name: String, objectKey: String, sha256: String): Unit {
    asset.valid = true
    asset.name = name
    asset.mirrorUrl = "https://github.com/HapPub/CangjieSDK-Mirror/releases/download/" + asset.version + "/" + name
    asset.sourceUrl = "https://cangjie-lang.cn/v1/files/auth/downLoad?nsId=142267&fileName=" + name + "&objectKey=" + objectKey
    asset.url = asset.mirrorUrl
    asset.sha256 = sha256
}

public func resolveOfficialCangjieStdxInstallAsset(version: String, platform: String): HapCangjiePackageInstallAsset {
    let asset = HapCangjiePackageInstallAsset()
    asset.packageName = "cangjie-stdx"
    asset.version = version
    asset.checksumAuthority = "hapcli-pinned-official-release-download-sha256"
    if (version == "1.0.5.1" && platform == "mac-aarch64") {
        setOfficialCangjieStdxAsset(asset, platform, "202b91110996c60de35f2dc07c278bc19a08df2029dc3376710c9f3e84121e7b")
    } else if (version == "1.0.5.1" && platform == "linux-aarch64") {
        setOfficialCangjieStdxAsset(asset, platform, "1ca6147479edfad4d330377842d1147ac03605a7738d45146a36c43068ce9582")
    } else if (version == "1.0.5.1" && platform == "linux-x64") {
        setOfficialCangjieStdxAsset(asset, platform, "6e301e63ae9ab74ca17d360400eaa0c525b9f48e5d08077f05ce4f704be7c277")
    } else if (version == "1.0.5.1" && platform == "windows-x64") {
        setOfficialCangjieStdxAsset(asset, platform, "8cd08133c4f1152acdcff00c923d9abe8184f081d6b92e924d2285f7e27f7162")
    } else if (version == "1.1.3.1" && platform == "mac-aarch64") {
        setOfficialCangjieStdxAsset(asset, platform, "97b21c94907eade61c031567694da9e9f41121824ea9f5276f0f3975b3cb55ef")
    } else if (version == "1.1.3.1" && platform == "mac-x64") {
        setOfficialCangjieStdxAsset(asset, platform, "d7b41d81dcf9cfd25b9f6ea3c9e18382bac481dd35c0da3f49440057c6741493")
    } else if (version == "1.1.3.1" && platform == "linux-aarch64") {
        setOfficialCangjieStdxAsset(asset, platform, "d7fc207848db79f7b6be298c7e040a2bdf9e6b94cfa410bab5d43b406bcc0a6a")
    } else if (version == "1.1.3.1" && platform == "linux-x64") {
        setOfficialCangjieStdxAsset(asset, platform, "41653244d6e4706359b906b1e1092db601d6fd8b07d72f03a0a2bfa33886a26f")
    } else if (version == "1.1.3.1" && platform == "windows-x64") {
        setOfficialCangjieStdxAsset(asset, platform, "32710143e48e955bf13c2af8d02bf02dd57e5b7972a130e63b6710aea424100c")
    }
    asset
}

func setOfficialCangjieStdxAsset(asset: HapCangjiePackageInstallAsset, platform: String, sha256: String): Unit {
    asset.valid = true
    asset.name = "cangjie-stdx-" + platform + "-" + asset.version + ".zip"
    asset.mirrorUrl = "https://github.com/HapPub/CangjieSDK-Mirror/releases/download/v" + asset.version + "/" + asset.name
    asset.sourceUrl = "https://gitcode.com/Cangjie/cangjie_stdx/releases/download/v" + asset.version + "/" + asset.name
    asset.url = asset.mirrorUrl
    asset.sha256 = sha256
}

public func renderCangjiePackageInstallPlanJson(options: HapCangjiePackageInstallOptions): String {
    if (!options.valid) {
        return renderInspectCjpmErrorJson(options.errorCode, options.errorMessage)
    }
    let asset = resolveCangjiePackageInstallAsset(options)
    if (!asset.valid) {
        return renderCangjiePackageInstallJson(options, asset, unsupportedCangjiePackageInstallResult(options))
    }
    let result = HapCangjiePackageInstallResult()
    result.ok = true
    result.status = "planned"
    result.finalRoot = cangjiePackageFinalRoot(options)
    result.archivePath = cangjiePackageArchivePath(options, asset)
    result.activationHint = cangjiePackageActivationHint(options, result.finalRoot, "")
    renderCangjiePackageInstallJson(options, asset, result)
}

public func runCangjiePackageInstall(options: HapCangjiePackageInstallOptions): String {
    if (!options.valid) {
        return renderInspectCjpmErrorJson(options.errorCode, options.errorMessage)
    }
    let asset = resolveCangjiePackageInstallAsset(options)
    if (!asset.valid) {
        return renderCangjiePackageInstallJson(options, asset, unsupportedCangjiePackageInstallResult(options))
    }
    let result = installResolvedCangjiePackage(options, asset)
    let json = renderCangjiePackageInstallJson(options, asset, result)
    if (result.ok) {
        try {
            let receiptRoot = parentPath(options.receipt)
            if (receiptRoot.size > 0 && !exists(receiptRoot)) {
                Directory.create(receiptRoot, recursive: true)
            }
            File.writeTo(options.receipt, json.toArray())
        } catch (error: Exception) {
            result.ok = false
            result.status = "receipt-write-failed"
            result.diagnostic = error.message
            return renderCangjiePackageInstallJson(options, asset, result)
        }
    }
    json
}

public func installResolvedCangjiePackage(options: HapCangjiePackageInstallOptions, asset: HapCangjiePackageInstallAsset): HapCangjiePackageInstallResult {
    let result = HapCangjiePackageInstallResult()
    result.finalRoot = cangjiePackageFinalRoot(options)
    result.archivePath = cangjiePackageArchivePath(options, asset)
    let marker = result.finalRoot + "/.hap-complete"
    if (bootstrapCompletionMarkerMatches(marker, asset.version, asset.sha256)) {
        if (options.resolvedPackage == "cangjie-sdk") {
            result.envsetupPath = findBootstrapEnvsetup(result.finalRoot)
            if (result.envsetupPath.size == 0) {
                result.status = "cached-sdk-envsetup-not-found"
                return result
            }
        } else if (!exists(result.finalRoot + "/" + cangjiePlatformNameForTarget(options.target))) {
            result.status = "cached-stdx-platform-not-found"
            return result
        }
        result.ok = true
        result.cacheHit = true
        result.status = "verified-marker-cache-hit"
        result.activationHint = cangjiePackageActivationHint(options, result.finalRoot, result.envsetupPath)
        return result
    }
    try {
        let downloadRoot = parentPath(result.archivePath)
        if (!exists(downloadRoot)) {
            Directory.create(downloadRoot, recursive: true)
        }
        if (!exists(result.finalRoot)) {
            Directory.create(result.finalRoot, recursive: true)
        }
    } catch (error: Exception) {
        result.status = "install-root-create-failed"
        result.diagnostic = error.message
        return result
    }
    if (!verifyCangjieBootstrapSha256(result.archivePath, asset.sha256)) {
        let candidates = cangjiePackageTransferCandidates(options.selectedRegion, asset.mirrorUrl, asset.sourceUrl)
        let download = downloadCangjieBootstrapFile(candidates, result.archivePath, options.timeoutSeconds, options.retryCount, options.networkMode)
        if (!download.ran || download.exitCode != 0) {
            result.status = "download-failed"
            result.diagnostic = download.stderr
            return result
        }
        result.downloadActionTaken = true
    }
    if (!verifyCangjieBootstrapSha256(result.archivePath, asset.sha256)) {
        result.status = "checksum-rejected"
        return result
    }
    result.checksumVerified = true
    let extract = extractCangjieBootstrapArchive(result.archivePath, result.finalRoot)
    if (!extract.ran || extract.exitCode != 0) {
        result.status = "extract-failed"
        result.diagnostic = extract.stderr
        return result
    }
    result.installActionTaken = true
    if (options.resolvedPackage == "cangjie-sdk") {
        result.envsetupPath = findBootstrapEnvsetup(result.finalRoot)
        if (result.envsetupPath.size == 0) {
            result.status = "sdk-envsetup-not-found"
            return result
        }
    } else if (!exists(result.finalRoot + "/" + cangjiePlatformNameForTarget(options.target))) {
        result.status = "stdx-platform-not-found"
        return result
    }
    writeBootstrapCompletionMarker(marker, asset.version, asset.sha256)
    result.ok = true
    result.status = "verified-and-installed"
    result.activationHint = cangjiePackageActivationHint(options, result.finalRoot, result.envsetupPath)
    result
}

func unsupportedCangjiePackageInstallResult(options: HapCangjiePackageInstallOptions): HapCangjiePackageInstallResult {
    let result = HapCangjiePackageInstallResult()
    result.status = "official-asset-not-available"
    result.finalRoot = cangjiePackageFinalRoot(options)
    result.diagnostic = "the selected official release does not publish this package/platform pair"
    result
}

public func renderCangjiePackageInstallJson(options: HapCangjiePackageInstallOptions, asset: HapCangjiePackageInstallAsset, result: HapCangjiePackageInstallResult): String {
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cangjie-package-install-v1\",\n")
    out.append("  \"ok\": " + boolJson(result.ok) + ",\n")
    out.append("  \"status\": \"" + escapeJson(result.status) + "\",\n")
    out.append("  \"plan\": " + boolJson(options.plan) + ",\n")
    out.append("  \"requestedSpec\": \"" + escapeJson(options.requestedSpec) + "\",\n")
    out.append("  \"requestedPackage\": \"" + escapeJson(options.requestedPackage) + "\",\n")
    out.append("  \"resolvedPackage\": \"" + escapeJson(options.resolvedPackage) + "\",\n")
    out.append("  \"requestedVersion\": \"" + escapeJson(options.requestedVersion) + "\",\n")
    out.append("  \"resolvedVersion\": \"" + escapeJson(options.resolvedVersion) + "\",\n")
    out.append("  \"assetVersion\": \"" + escapeJson(options.assetVersion) + "\",\n")
    out.append("  \"releaseChannel\": \"" + escapeJson(options.releaseChannel) + "\",\n")
    out.append("  \"latestPolicy\": \"latest-is-pinned-lts\",\n")
    out.append("  \"target\": \"" + escapeJson(options.target) + "\",\n")
    out.append("  \"platform\": \"" + escapeJson(options.platform) + "\",\n")
    out.append("  \"requestedRegion\": \"" + escapeJson(options.requestedRegion) + "\",\n")
    out.append("  \"selectedRegion\": \"" + escapeJson(options.selectedRegion) + "\",\n")
    out.append("  \"regionSelectionSource\": \"" + escapeJson(options.regionSelectionSource) + "\",\n")
    out.append("  \"catalogUrl\": \"https://cli.hap.pub/manifests/cangjie-install-v1.json\",\n")
    out.append("  \"asset\": \"" + escapeJson(asset.name) + "\",\n")
    out.append("  \"assetUrl\": \"" + escapeJson(asset.url) + "\",\n")
    out.append("  \"mirrorUrl\": \"" + escapeJson(asset.mirrorUrl) + "\",\n")
    out.append("  \"sourceUrl\": \"" + escapeJson(asset.sourceUrl) + "\",\n")
    out.append("  \"sha256\": \"" + escapeJson(asset.sha256) + "\",\n")
    out.append("  \"checksumAuthority\": \"" + escapeJson(asset.checksumAuthority) + "\",\n")
    out.append("  \"installRoot\": \"" + escapeJson(options.installRoot) + "\",\n")
    out.append("  \"archivePath\": \"" + escapeJson(result.archivePath) + "\",\n")
    out.append("  \"finalRoot\": \"" + escapeJson(result.finalRoot) + "\",\n")
    out.append("  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n")
    out.append("  \"networkMode\": \"" + escapeJson(options.networkMode) + "\",\n")
    out.append("  \"cacheHit\": " + boolJson(result.cacheHit) + ",\n")
    out.append("  \"downloadActionTaken\": " + boolJson(result.downloadActionTaken) + ",\n")
    out.append("  \"checksumVerified\": " + boolJson(result.checksumVerified) + ",\n")
    out.append("  \"installActionTaken\": " + boolJson(result.installActionTaken) + ",\n")
    out.append("  \"systemMutation\": false,\n")
    out.append("  \"projectMutation\": false,\n")
    out.append("  \"rcMutation\": false,\n")
    out.append("  \"envsetupPath\": \"" + escapeJson(result.envsetupPath) + "\",\n")
    out.append("  \"activationHint\": \"" + escapeJson(result.activationHint) + "\",\n")
    out.append("  \"diagnostic\": \"" + escapeJson(result.diagnostic) + "\"\n")
    out.append("}")
    out.toString()
}

public func cangjiePackageInstallExitCode(json: String): Int64 {
    if (containsText(json, "\"ok\": true")) {
        return 0
    }
    if (containsText(json, "happub-hapcli-error-v0")) { 2 } else { 1 }
}

func cangjiePackageFinalRoot(options: HapCangjiePackageInstallOptions): String {
    options.installRoot + "/cangjie/" + options.resolvedPackage + "/" + options.assetVersion + "/" + options.target
}

func cangjiePackageArchivePath(options: HapCangjiePackageInstallOptions, asset: HapCangjiePackageInstallAsset): String {
    options.installRoot + "/downloads/" + asset.name
}

func cangjiePackageActivationHint(options: HapCangjiePackageInstallOptions, finalRoot: String, envsetup: String): String {
    if (options.resolvedPackage == "cangjie-sdk") {
        if (envsetup.size > 0) { "source '" + envsetup + "'" } else { "source '<finalRoot>/cangjie/envsetup.sh'" }
    } else {
        "export CANGJIE_STDX_PATH='" + finalRoot + "'"
    }
}

public func cangjiePackageTransferCandidates(selectedRegion: String, mirrorUrl: String, sourceUrl: String): ArrayList<String> {
    let candidates = ArrayList<String>()
    if (selectedRegion == "zh-cn") {
        for (accelerator in defaultCangjieDownloadAccelerators()) {
            addUniqueBootstrapText(candidates, rewriteGithubDownloadUrl(accelerator, mirrorUrl))
        }
    }
    addUniqueBootstrapText(candidates, mirrorUrl)
    addUniqueBootstrapText(candidates, sourceUrl)
    candidates
}

func defaultCangjiePackageInstallRoot(): String {
    match (getVariable("HOME")) {
        case Some(home) => if (home.size > 0 && home != "/dev/null") { trimTrailingSlash(home) + "/.hap/toolchains" } else { "" }
        case None => ""
    }
}

func cangjiePackageInstallRootIsPrivate(path: String): Bool {
    let normalized = trimTrailingSlash(path.replace("\\", "/"))
    if (normalized.size == 0 || containsText(normalized, "/../") || normalized.endsWith("/..")) {
        return false
    }
    if (normalized == "/tmp" || startsWithText(normalized, "/tmp/") || normalized == "/private/tmp" || startsWithText(normalized, "/private/tmp/")) {
        return true
    }
    let tempRoots = [cangjiePackageEnvironmentPath("TMPDIR"), cangjiePackageEnvironmentPath("TEMP"), cangjiePackageEnvironmentPath("TMP")]
    for (root in tempRoots) {
        if (root.size > 0 && (normalized == root || startsWithText(normalized, root + "/"))) {
            return true
        }
    }
    let home = cangjiePackageEnvironmentPath("HOME")
    home.size > 0 && (normalized == home + "/.hap" || startsWithText(normalized, home + "/.hap/"))
}

func cangjiePackageReceiptIsPrivate(installRoot: String, receipt: String): Bool {
    let root = trimTrailingSlash(installRoot.replace("\\", "/"))
    let normalized = receipt.replace("\\", "/")
    root.size > 0 && !containsText(normalized, "/../") && !normalized.endsWith("/..") && startsWithText(normalized, root + "/")
}

func cangjiePackageEnvironmentPath(name: String): String {
    match (getVariable(name)) {
        case Some(value) => trimTrailingSlash(value.replace("\\", "/"))
        case None => ""
    }
}

func detectNativeCangjieInstallTarget(): String {
    let host = detectCangjieBootstrapHost()
    if (host[0] == "Darwin" && (host[1] == "arm64" || host[1] == "aarch64")) { "macos-arm64" }
    else if (host[0] == "Darwin" && host[1] == "x86_64") { "macos-amd64" }
    else if (host[0] == "Linux" && (host[1] == "arm64" || host[1] == "aarch64")) { "linux-arm64" }
    else if (host[0] == "Linux" && host[1] == "x86_64") { "linux-amd64" }
    else if ((startsWithText(host[0], "MINGW") || startsWithText(host[0], "MSYS") || startsWithText(host[0], "CYGWIN") || host[0] == "Windows") && (host[1] == "x86_64" || host[1] == "AMD64")) { "windows-amd64" }
    else { "" }
}

func isNativeCangjieInstallTarget(target: String): Bool {
    target == "macos-arm64" || target == "macos-amd64" || target == "linux-arm64" || target == "linux-amd64" || target == "windows-amd64"
}

func parsePositiveCangjieInstallInt(value: String, fallback: Int64): Int64 {
    try {
        let parsed = Int64.parse(value)
        if (parsed > 0) { parsed } else { fallback }
    } catch (_: Exception) {
        fallback
    }
}

func parseNonNegativeCangjieInstallInt(value: String, fallback: Int64): Int64 {
    try {
        let parsed = Int64.parse(value)
        if (parsed >= 0) { parsed } else { fallback }
    } catch (_: Exception) {
        fallback
    }
}
