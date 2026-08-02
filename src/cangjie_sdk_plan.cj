package hapcli

public class HapCangjieSdkGetOptions {
    public var target: String = "ohos-arm64"
    public var version: String = ""
    public var providerUrl: String = ""
    public var installRoot: String = ""
    public var sha256: String = ""
    public var allowUnverified: Bool = false
    public var executeRequested: Bool = false

    public init() {}
}

public func resolveCangjieSdkGetOptions(commandLine: Array<String>, start: Int64): HapCangjieSdkGetOptions {
    let options = HapCangjieSdkGetOptions()
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

public func renderCangjieSdkGetPlanJson(options: HapCangjieSdkGetOptions): String {
    let target = canonicalTargetName(options.target)
    let platform = cangjieDownloadPlatformForTarget(target)
    let downloadName = cangjieSdkDownloadFilename(platform, options.version)
    let downloadUrl = buildProviderDownloadUrl(options.providerUrl, downloadName)
    let sdkRootHint = cangjieSdkRootHint(options.installRoot, platform, options.version)
    let envSetupHint = sdkRootHint + "/cangjie/envsetup.sh"
    let hasChecksum = options.sha256.size > 0
    let targetOk = target == "ohos-arm64" || target == "ohos-amd64"
    let requiredOk = targetOk && platform.size > 0 && options.version.size > 0 && options.providerUrl.size > 0 && options.installRoot.size > 0
    let verificationOk = hasChecksum || options.allowUnverified
    let ok = requiredOk && verificationOk && !options.executeRequested
    let status = resolveCangjieSdkGetPlanStatus(targetOk, requiredOk, verificationOk, options.executeRequested)

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cangjie-sdk-get-plan-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"plan-only\",\n")
    out.append("  \"subject\": \"cangjie-sdk\",\n")
    out.append("  \"target\": \"" + escapeJson(target) + "\",\n")
    out.append("  \"downloadPlatform\": \"" + escapeJson(platform) + "\",\n")
    out.append("  \"version\": \"" + escapeJson(options.version) + "\",\n")
    out.append("  \"providerUrl\": \"" + escapeJson(options.providerUrl) + "\",\n")
    out.append("  \"downloadFilename\": \"" + escapeJson(downloadName) + "\",\n")
    out.append("  \"downloadUrl\": \"" + escapeJson(downloadUrl) + "\",\n")
    out.append("  \"installRoot\": \"" + escapeJson(options.installRoot) + "\",\n")
    out.append("  \"sdkRootHint\": \"" + escapeJson(sdkRootHint) + "\",\n")
    out.append("  \"envSetupHint\": \"" + escapeJson(envSetupHint) + "\",\n")
    out.append("  \"sha256\": \"" + escapeJson(options.sha256) + "\",\n")
    out.append("  \"allowUnverified\": " + boolJson(options.allowUnverified) + ",\n")
    out.append("  \"executeRequested\": " + boolJson(options.executeRequested) + ",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"downloadAllowed\": false,\n")
    out.append("  \"installAllowed\": false,\n")
    out.append("  \"shellBoundary\": \"hapup-may-install-reviewed-cangjie-sdk-archive-and-run-ohos-repair-steps\",\n")
    out.append("  \"harmonyOsRepairSteps\": [\n")
    out.append("    \"extract-sdk-archive-under-reviewed-install-root\",\n")
    out.append("    \"repair-envsetup-shebang-from-bash-to-sh-if-needed\",\n")
    out.append("    \"restore-executable-bits-for-tools-bin-and-compiler-bin\",\n")
    out.append("    \"self-sign-shared-objects-when-binary-sign-tool-is-available\",\n")
    out.append("    \"materialize-ld-lld-from-lld-when-ld-lld-is-a-symlink\",\n")
    out.append("    \"print-source-envsetup-snippet-without-mutating-rc-by-default\"\n")
    out.append("  ],\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-cangjie-sdk-get-plan\",\n")
    out.append("    \"attach-checksum-or-allow-unverified-for-local-alpha-sdk\",\n")
    out.append("    \"run-hapup-install-cangjie-sdk-after-review\",\n")
    out.append("    \"run-hap-env-print-or-reviewed-env-apply-after-install\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"plan does not download the SDK\",\n")
    out.append("    \"plan does not install the SDK\",\n")
    out.append("    \"plan does not mutate zshrc, bashrc, or project manifests\",\n")
    out.append("    \"shared object signing depends on a working binary-sign-tool on HarmonyOS\",\n")
    out.append("    \"unverified nightly SDK plans are not release-safe without human approval\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func cangjieSdkDownloadFilename(platform: String, version: String): String {
    if (platform.size == 0 || version.size == 0) {
        return ""
    }
    "cangjie-sdk-" + platform + "-" + version + ".tar.gz"
}

func cangjieSdkRootHint(installRoot: String, platform: String, version: String): String {
    if (installRoot.size == 0 || platform.size == 0 || version.size == 0) {
        return ""
    }
    trimTrailingSlash(installRoot) + "/cangjie-sdk-" + platform + "-" + version
}

func resolveCangjieSdkGetPlanStatus(targetOk: Bool, requiredOk: Bool, verificationOk: Bool, executeRequested: Bool): String {
    if (!targetOk) {
        return "unsupported-sdk-target"
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
    "ready-for-hapup-review"
}
