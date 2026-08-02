package hapcli

public class HapRuntimeHandoffOptions {
    public var target: String = "linux-amd64"
    public var version: String = ""
    public var providerUrl: String = ""
    public var installRoot: String = ""
    public var sha256: String = ""
    public var allowUnverified: Bool = false
    public var shell: String = "HapShell"
    public var executeRequested: Bool = false

    public init() {}
}

public func resolveRuntimeHandoffOptions(commandLine: Array<String>, start: Int64): HapRuntimeHandoffOptions {
    let options = HapRuntimeHandoffOptions()
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
        if (current == "--shell" && i + 1 < commandLine.size) {
            options.shell = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--shell=")) {
            options.shell = substringFrom(current, 8)
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

public func renderRuntimeHandoffJson(options: HapRuntimeHandoffOptions): String {
    let platform = runtimeDownloadPlatform(options.target)
    let runtimeName = runtimeDownloadFilename(platform, options.version)
    let runtimeUrl = buildProviderDownloadUrl(options.providerUrl, runtimeName)
    let hasChecksum = options.sha256.size > 0
    let requiredOk = platform.size > 0 && options.version.size > 0 && options.providerUrl.size > 0 && options.installRoot.size > 0
    let verificationOk = hasChecksum || options.allowUnverified
    let ok = requiredOk && verificationOk && !options.executeRequested
    let status = resolveRuntimeHandoffStatus(requiredOk, verificationOk, options.executeRequested)

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-runtime-handoff-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"handoff-only\",\n")
    out.append("  \"subject\": \"cangjie-runtime\",\n")
    out.append("  \"handoffTo\": \"" + escapeJson(options.shell) + "\",\n")
    out.append("  \"target\": \"" + escapeJson(options.target) + "\",\n")
    out.append("  \"downloadPlatform\": \"" + escapeJson(platform) + "\",\n")
    out.append("  \"version\": \"" + escapeJson(options.version) + "\",\n")
    out.append("  \"providerUrl\": \"" + escapeJson(options.providerUrl) + "\",\n")
    out.append("  \"downloadFilename\": \"" + escapeJson(runtimeName) + "\",\n")
    out.append("  \"downloadUrl\": \"" + escapeJson(runtimeUrl) + "\",\n")
    out.append("  \"installRoot\": \"" + escapeJson(options.installRoot) + "\",\n")
    out.append("  \"sha256\": \"" + escapeJson(options.sha256) + "\",\n")
    out.append("  \"allowUnverified\": " + boolJson(options.allowUnverified) + ",\n")
    out.append("  \"executeRequested\": " + boolJson(options.executeRequested) + ",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"executeAllowed\": false,\n")
    out.append("  \"downloadAllowedByFlagship\": false,\n")
    out.append("  \"deployAllowedByFlagship\": false,\n")
    out.append("  \"shellBoundary\": \"shell-may-download-and-deploy-runtime-only-after-reviewed-handoff\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-runtime-handoff\",\n")
    out.append("    \"attach-checksum\",\n")
    out.append("    \"execute-with-shell-after-review\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"flagship does not download runtime\",\n")
    out.append("    \"flagship does not deploy runtime\",\n")
    out.append("    \"handoff does not mutate cjpm.toml\",\n")
    out.append("    \"shell execution still requires explicit reviewed acceptance\",\n")
    out.append("    \"unverified runtime handoff is not release-safe\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func runtimeDownloadPlatform(target: String): String {
    cangjieDownloadPlatformForTarget(target)
}

func runtimeDownloadFilename(platform: String, version: String): String {
    if (platform.size == 0 || version.size == 0) {
        return ""
    }
    "cangjie-runtime-" + platform + "-" + version + ".tar.gz"
}

func resolveRuntimeHandoffStatus(requiredOk: Bool, verificationOk: Bool, executeRequested: Bool): String {
    if (executeRequested) {
        return "execute-not-supported-in-flagship-handoff"
    }
    if (!requiredOk) {
        return "missing-required-field"
    }
    if (!verificationOk) {
        return "missing-checksum-or-unverified-approval"
    }
    "ready-for-shell-review"
}
