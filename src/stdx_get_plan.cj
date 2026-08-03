package hapcli

public class HapCangjieStdxGetOptions {
    public var target: String = "linux-amd64"
    public var version: String = ""
    public var providerUrl: String = ""
    public var region: String = "auto"
    public var regionExplicit: Bool = false
    public var configPath: String = ""
    public var installRoot: String = ""
    public var sha256: String = ""
    public var allowUnverified: Bool = false
    public var executeRequested: Bool = false

    public init() {}
}

public func resolveCangjieStdxGetOptions(commandLine: Array<String>, start: Int64): HapCangjieStdxGetOptions {
    let options = HapCangjieStdxGetOptions()
    var i = start
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
        if (current == "--version" && i + 1 < commandLine.size) {
            options.version = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--version=")) {
            options.version = substringFrom(current, 10)
            i += 1
            continue
        }
        if (current == "--provider-url" && i + 1 < commandLine.size) {
            options.providerUrl = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--provider-url=")) {
            options.providerUrl = substringFrom(current, 15)
            i += 1
            continue
        }
        if (current == "--region" && i + 1 < commandLine.size) {
            options.region = commandLine[i + 1]
            options.regionExplicit = true
            i += 2
            continue
        }
        if (startsWithText(current, "--region=")) {
            options.region = substringFrom(current, 9)
            options.regionExplicit = true
            i += 1
            continue
        }
        if (current == "--config" && i + 1 < commandLine.size) {
            options.configPath = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--config=")) {
            options.configPath = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--install-root" && i + 1 < commandLine.size) {
            options.installRoot = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--install-root=")) {
            options.installRoot = substringFrom(current, 15)
            i += 1
            continue
        }
        if (current == "--sha256" && i + 1 < commandLine.size) {
            options.sha256 = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--sha256=")) {
            options.sha256 = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--allow-unverified") {
            options.allowUnverified = true
            i += 1
            continue
        }
        if (current == "--execute") {
            options.executeRequested = true
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func renderCangjieStdxGetPlanJson(options: HapCangjieStdxGetOptions): String {
    let platform = stdxDownloadPlatform(options.target)
    let pathHint = stdxInstallPathHint(options.target)
    let route = resolveCangjieSourceRoute(options.region, options.regionExplicit, options.configPath, options.providerUrl)
    let primaryProviderUrl = cangjieSourceProviderUrl(route, options.version, true)
    let fallbackProviderUrl = cangjieSourceProviderUrl(route, options.version, false)
    let manifestUrl = cangjieSourceManifestUrl(route, options.version)
    let downloadName = stdxDownloadFilename(platform, options.version)
    let downloadUrl = buildProviderDownloadUrl(primaryProviderUrl, downloadName)
    let fallbackDownloadUrl = buildProviderDownloadUrl(fallbackProviderUrl, downloadName)
    let hasChecksum = options.sha256.size > 0
    let requiredOk = route.valid && platform.size > 0 && options.version.size > 0 && primaryProviderUrl.size > 0 && options.installRoot.size > 0
    let verificationOk = hasChecksum || manifestUrl.size > 0 || options.allowUnverified
    let ok = requiredOk && verificationOk && !options.executeRequested
    let status = resolveGetPlanStatus(route.valid, requiredOk, verificationOk, options.executeRequested, manifestUrl.size > 0 && !hasChecksum)

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cangjie-stdx-get-plan-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"plan-only\",\n")
    out.append("  \"subject\": \"cangjie-stdx\",\n")
    out.append("  \"target\": \"" + escapeJson(options.target) + "\",\n")
    out.append("  \"downloadPlatform\": \"" + escapeJson(platform) + "\",\n")
    out.append("  \"version\": \"" + escapeJson(options.version) + "\",\n")
    out.append("  \"requestedRegion\": \"" + escapeJson(route.requestedRegion) + "\",\n")
    out.append("  \"selectedRegion\": \"" + escapeJson(route.selectedRegion) + "\",\n")
    out.append("  \"regionSelectionSource\": \"" + escapeJson(route.selectionSource) + "\",\n")
    out.append("  \"sourceRouteStatus\": \"" + escapeJson(route.status) + "\",\n")
    out.append("  \"sourceConfigPath\": \"" + escapeJson(route.configPath) + "\",\n")
    out.append("  \"primaryProvider\": \"" + escapeJson(route.primaryProvider) + "\",\n")
    out.append("  \"fallbackProvider\": \"" + escapeJson(route.fallbackProvider) + "\",\n")
    out.append("  \"providerUrl\": \"" + escapeJson(primaryProviderUrl) + "\",\n")
    out.append("  \"fallbackProviderUrl\": \"" + escapeJson(fallbackProviderUrl) + "\",\n")
    out.append("  \"manifestUrl\": \"" + escapeJson(manifestUrl) + "\",\n")
    out.append("  \"downloadFilename\": \"" + escapeJson(downloadName) + "\",\n")
    out.append("  \"downloadUrl\": \"" + escapeJson(downloadUrl) + "\",\n")
    out.append("  \"fallbackDownloadUrl\": \"" + escapeJson(fallbackDownloadUrl) + "\",\n")
    out.append("  \"installRoot\": \"" + escapeJson(options.installRoot) + "\",\n")
    out.append("  \"expectedInstallPathHint\": \"" + escapeJson(pathHint) + "\",\n")
    out.append("  \"sha256\": \"" + escapeJson(options.sha256) + "\",\n")
    out.append("  \"checksumAuthority\": \"" + escapeJson(cangjieGetChecksumAuthority(hasChecksum, manifestUrl, options.allowUnverified)) + "\",\n")
    out.append("  \"manifestChecksumRequiredBeforeDownload\": " + boolJson(!hasChecksum && manifestUrl.size > 0) + ",\n")
    out.append("  \"allowUnverified\": " + boolJson(options.allowUnverified) + ",\n")
    out.append("  \"executeRequested\": " + boolJson(options.executeRequested) + ",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"downloadAllowed\": false,\n")
    out.append("  \"installAllowed\": false,\n")
    out.append("  \"shellBoundary\": \"shell-may-download-and-deploy-runtime-only; stdx acquisition contract is owned by flagship HapCLI\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-stdx-get-plan\",\n")
    out.append("    \"attach-checksum\",\n")
    out.append("    \"delegate-runtime-download-to-shell\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"plan does not download stdx\",\n")
    out.append("    \"plan does not install stdx\",\n")
    out.append("    \"plan does not mutate cjpm.toml\",\n")
    out.append("    \"HapCLI does not depend on stdx for this contract\",\n")
    out.append("    \"regional route resolution does not perform a network request\",\n")
    out.append("    \"mirrored stdx presence does not prove a project builds on that target\",\n")
    out.append("    \"unverified custom-provider plan is not release-safe without human approval\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func stdxDownloadPlatform(target: String): String {
    cangjieDownloadPlatformForTarget(target)
}

func stdxInstallPathHint(target: String): String {
    stdxPathHintForTarget(target)
}

func stdxDownloadFilename(platform: String, version: String): String {
    if (platform.size == 0 || version.size == 0) {
        return ""
    }
    let assetVersion = if (containsText(version, "-alpha.") && !version.endsWith(".1")) { version + ".1" } else { version }
    "cangjie-stdx-" + platform + "-" + assetVersion + ".zip"
}

func buildProviderDownloadUrl(providerUrl: String, filename: String): String {
    if (providerUrl.size == 0 || filename.size == 0) {
        return ""
    }
    trimTrailingSlash(providerUrl) + "/" + filename
}

func resolveGetPlanStatus(routeOk: Bool, requiredOk: Bool, verificationOk: Bool, executeRequested: Bool, manifestRequired: Bool): String {
    if (!routeOk) {
        return "invalid-source-route"
    }
    if (executeRequested) {
        return "execute-not-supported-in-flagship-plan"
    }
    if (!requiredOk) {
        return "missing-required-field"
    }
    if (!verificationOk) {
        return "missing-checksum-or-unverified-approval"
    }
    if (manifestRequired) {
        return "ready-for-manifest-checksum-resolution"
    }
    "ready-for-human-review"
}

func cangjieGetChecksumAuthority(hasChecksum: Bool, manifestUrl: String, allowUnverified: Bool): String {
    if (hasChecksum) {
        return "cli-provided-sha256"
    }
    if (manifestUrl.size > 0) {
        return "happub-mirror-manifest-v1"
    }
    if (allowUnverified) {
        return "human-unverified-exception"
    }
    "none"
}
