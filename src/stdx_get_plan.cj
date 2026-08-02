package hapcli

public class HapCangjieStdxGetOptions {
    public var target: String = "linux-amd64"
    public var version: String = ""
    public var providerUrl: String = ""
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
    let downloadName = stdxDownloadFilename(platform, options.version)
    let downloadUrl = buildProviderDownloadUrl(options.providerUrl, downloadName)
    let hasChecksum = options.sha256.size > 0
    let requiredOk = platform.size > 0 && options.version.size > 0 && options.providerUrl.size > 0 && options.installRoot.size > 0
    let verificationOk = hasChecksum || options.allowUnverified
    let ok = requiredOk && verificationOk && !options.executeRequested
    let status = resolveGetPlanStatus(requiredOk, verificationOk, options.executeRequested)

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cangjie-stdx-get-plan-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"plan-only\",\n")
    out.append("  \"subject\": \"cangjie-stdx\",\n")
    out.append("  \"target\": \"" + escapeJson(options.target) + "\",\n")
    out.append("  \"downloadPlatform\": \"" + escapeJson(platform) + "\",\n")
    out.append("  \"version\": \"" + escapeJson(options.version) + "\",\n")
    out.append("  \"providerUrl\": \"" + escapeJson(options.providerUrl) + "\",\n")
    out.append("  \"downloadFilename\": \"" + escapeJson(downloadName) + "\",\n")
    out.append("  \"downloadUrl\": \"" + escapeJson(downloadUrl) + "\",\n")
    out.append("  \"installRoot\": \"" + escapeJson(options.installRoot) + "\",\n")
    out.append("  \"expectedInstallPathHint\": \"" + escapeJson(pathHint) + "\",\n")
    out.append("  \"sha256\": \"" + escapeJson(options.sha256) + "\",\n")
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
    out.append("    \"unverified plan is not release-safe without human approval\"\n")
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
    "cangjie-stdx-" + platform + "-" + version + ".zip"
}

func buildProviderDownloadUrl(providerUrl: String, filename: String): String {
    if (providerUrl.size == 0 || filename.size == 0) {
        return ""
    }
    trimTrailingSlash(providerUrl) + "/" + filename
}

func resolveGetPlanStatus(requiredOk: Bool, verificationOk: Bool, executeRequested: Bool): String {
    if (executeRequested) {
        return "execute-not-supported-in-flagship-plan"
    }
    if (!requiredOk) {
        return "missing-required-field"
    }
    if (!verificationOk) {
        return "missing-checksum-or-unverified-approval"
    }
    "ready-for-human-review"
}
