package hapcli

import std.fs.{File, exists}

public class HapToolchainDoctorOptions {
    public var project: String = "."
    public var target: String = "linux-amd64"
    public var prefer: String = "auto"

    public init() {}
}

public class HapEnvPrintOptions {
    public var subject: String = "runtime,stdx"
    public var shell: String = "zsh"
    public var installRoot: String = ""
    public var target: String = "linux-amd64"

    public init() {}
}

public class HapEnvApplyOptions {
    public var subject: String = "runtime,stdx"
    public var shell: String = "zsh"
    public var installRoot: String = ""
    public var target: String = "linux-amd64"
    public var rcPath: String = ""
    public var receiptPath: String = ""
    public var reviewToken: String = ""

    public init() {}
}

public func resolveToolchainDoctorOptions(commandLine: Array<String>, start: Int64): HapToolchainDoctorOptions {
    let options = HapToolchainDoctorOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--project" && i + 1 < commandLine.size) {
            options.project = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--project=")) {
            options.project = substringFrom(current, 10)
            i += 1
            continue
        }
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
        if (current == "--prefer" && i + 1 < commandLine.size) {
            options.prefer = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--prefer=")) {
            options.prefer = substringFrom(current, 9)
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func resolveEnvPrintOptions(commandLine: Array<String>, start: Int64): HapEnvPrintOptions {
    let options = HapEnvPrintOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--subject" && i + 1 < commandLine.size) {
            options.subject = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--subject=")) {
            options.subject = substringFrom(current, 10)
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
        i += 1
    }
    options
}

public func resolveEnvApplyOptions(commandLine: Array<String>, start: Int64): HapEnvApplyOptions {
    let options = HapEnvApplyOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--subject" && i + 1 < commandLine.size) {
            options.subject = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--subject=")) {
            options.subject = substringFrom(current, 10)
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
        if (current == "--rc" && i + 1 < commandLine.size) {
            options.rcPath = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--rc=")) {
            options.rcPath = substringFrom(current, 5)
            i += 1
            continue
        }
        if (current == "--receipt" && i + 1 < commandLine.size) {
            options.receiptPath = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--receipt=")) {
            options.receiptPath = substringFrom(current, 10)
            i += 1
            continue
        }
        if (current == "--review-token" && i + 1 < commandLine.size) {
            options.reviewToken = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--review-token=")) {
            options.reviewToken = substringFrom(current, 15)
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func renderToolchainProvidersJson(): String {
    "{\n" +
    "  \"schema\": \"happub-hapcli-toolchain-providers-v0\",\n" +
    "  \"ok\": true,\n" +
    "  \"mode\": \"read-only-provider-matrix\",\n" +
    "  \"providerCount\": 6,\n" +
    "  \"providers\": [\n" +
    renderProvider(
        "cjv",
        "sdk-version-manager",
        "external",
        "SDK install/switch/component/envsetup",
        "read-if-present",
        "read-if-present",
        "external-manual",
        "external-manual",
        "external-component-or-manual",
        "external-component-or-manual",
        "external-envsetup",
        "preinstall-or-cache-only",
        "prefer when the user already owns cjv as the SDK lifecycle layer"
    ) + ",\n" +
    renderProvider(
        "cjvs",
        "sdk-version-manager",
        "external",
        "nearby Cangjie SDK/version surface",
        "read-if-present",
        "read-if-present",
        "external-manual",
        "external-manual",
        "external-or-manual",
        "external-or-manual",
        "external-env-hints",
        "preinstall-or-cache-only",
        "prefer when a project already standardizes on cjvs"
    ) + ",\n" +
    renderProvider(
        "official-script",
        "official-asset-script",
        "external",
        "official SDK/runtime/stdx scripts or release assets",
        "reviewed-recipe",
        "release-asset-review",
        "reviewed-external-script",
        "no-sdk-switch",
        "reviewed-official-asset",
        "reviewed-official-asset",
        "script-docs-or-hap-env",
        "good-with-checksum-and-receipt",
        "prefer when official asset truth is known and checksummed"
    ) + ",\n" +
    renderProvider(
        "hap-recipe",
        "reviewed-recipe",
        "hap",
        "receipt-backed runtime/stdx fetch/deploy script",
        "reviewed-recipe",
        "dictionary-or-fixture-backed",
        "reviewed-script-only",
        "no-sdk-switch",
        "reviewed-fetch-recipe",
        "reviewed-fetch-recipe",
        "hap-env-print-or-reviewed-apply",
        "best-for-ci-cloud-bridge",
        "prefer for CI/cloud repair when Hap should not own SDK versions"
    ) + ",\n" +
    renderProvider(
        "harmonyos-pc-sdk",
        "reviewed-ohos-sdk-repair",
        "hap",
        "HarmonyOS PC local Cangjie SDK archive install with chmod/sign/ld.lld repair",
        "reviewed-recipe",
        "local-archive-or-nightly-asset-plan",
        "hapup-install-cangjie-sdk-after-review",
        "no-sdk-switch",
        "sdk-carried-or-follow-up-stdx-profile",
        "sdk-carried-runtime",
        "envsetup-snippet-or-reviewed-hap-env",
        "best-for-harmonyos-pc-bootstrap",
        "prefer when installing cangjie-sdk-ohos-aarch64 on HarmonyOS PC from a reviewed SDK archive"
    ) + ",\n" +
    renderProvider(
        "local-sdk",
        "local-evidence",
        "user",
        "existing CANGJIE_HOME/CJ_HOME/cjc-nearby local SDK",
        "read-only-doctor",
        "env-or-cjc-nearby",
        "none",
        "none",
        "read-local-evidence",
        "read-local-evidence",
        "print-only",
        "host-specific-not-portable",
        "prefer only for same-host diagnosis, not hosted CI truth"
    ) + "\n" +
    "  ],\n" +
    "  \"precedenceRules\": [\n" +
    "    \"hap-recipe is the default CI/cloud repair lane when no external version manager is explicitly preferred\",\n" +
    "    \"cjv and cjvs stay external SDK lifecycle lanes; HapCLI may recommend them but must not run them\",\n" +
    "    \"official-script can feed a reviewed Hap recipe when release asset and checksum truth are available\",\n" +
    "    \"harmonyos-pc-sdk is the reviewed local SDK archive install lane for HarmonyOS PC and remains checksum/unverified-review gated\",\n" +
    "    \"local-sdk evidence is valid for same-host diagnosis but should not be promoted as portable CI truth\"\n" +
    "  ],\n" +
    "  \"conflictRules\": [\n" +
    "    \"do not combine Hap env apply with cjv or cjvs env mutation in the same unchecked step\",\n" +
    "    \"do not treat a local SDK path as proof that hosted runners have the same runtime or stdx layout\",\n" +
    "    \"do not let reviewed fetch recipes overwrite an SDK manager controlled install root unless a human reviewed that root\",\n" +
    "    \"provider lookup never installs, executes, switches, downloads, or mutates shell rc files\"\n" +
    "  ],\n" +
    "  \"matrixBackedBy\": \"static-fixture-contract-v0\",\n" +
    "  \"nextAllowed\": [\n" +
    "    \"run-toolchain-doctor\",\n" +
    "    \"print-env-snippet\",\n" +
    "    \"generate-reviewed-fetch-recipe-if-provider-gap-remains\"\n" +
    "  ],\n" +
    "  \"nonPromises\": [\n" +
    "    \"providers does not execute provider commands\",\n" +
    "    \"providers does not install SDKs, stdx, runtime, cjv, or cjvs\",\n" +
    "    \"providers does not mutate shell rc files\",\n" +
    "    \"HapCLI is not a full SDK version manager\"\n" +
    "  ]\n" +
    "}"
}

func renderProvider(
    id: String,
    kind: String,
    owner: String,
    role: String,
    action: String,
    detect: String,
    install: String,
    switchSdk: String,
    stdxFetch: String,
    runtimeFetch: String,
    envExport: String,
    ciSuitability: String,
    recommendationRule: String
): String {
    "    {\"id\":\"" + escapeJson(id) +
    "\",\"kind\":\"" + escapeJson(kind) +
    "\",\"owner\":\"" + escapeJson(owner) +
    "\",\"role\":\"" + escapeJson(role) +
    "\",\"preferredAction\":\"" + escapeJson(action) +
    "\",\"capabilities\":{\"detect\":\"" + escapeJson(detect) +
    "\",\"install\":\"" + escapeJson(install) +
    "\",\"switch\":\"" + escapeJson(switchSdk) +
    "\",\"stdxFetch\":\"" + escapeJson(stdxFetch) +
    "\",\"runtimeFetch\":\"" + escapeJson(runtimeFetch) +
    "\",\"envExport\":\"" + escapeJson(envExport) +
    "\",\"ciSuitability\":\"" + escapeJson(ciSuitability) +
    "\"},\"recommendationRule\":\"" + escapeJson(recommendationRule) +
    "\",\"providerCommandExecution\":false,\"installActionTaken\":false,\"versionManagementActionTaken\":false,\"rcMutationActionTaken\":false}"
}

public func renderToolchainDoctorJson(options: HapToolchainDoctorOptions): String {
    let prefer = normalizeProviderPreference(options.prefer)
    let target = canonicalTargetName(options.target)
    let platform = cangjiePlatformNameForTarget(target)
    let ok = prefer.size > 0 && platform.size > 0
    let status = if (platform.size == 0) {
        "unsupported-target"
    } else if (prefer.size == 0) {
        "unsupported-provider-preference"
    } else {
        "provider-plan-ready"
    }
    let recommended = recommendedProviderForPreference(prefer)

    "{\n" +
    "  \"schema\": \"happub-hapcli-toolchain-doctor-v0\",\n" +
    "  \"ok\": " + boolJson(ok) + ",\n" +
    "  \"mode\": \"read-only-toolchain-provider-diagnosis\",\n" +
    "  \"project\": \"" + escapeJson(options.project) + "\",\n" +
    "  \"target\": \"" + escapeJson(target) + "\",\n" +
    "  \"platform\": \"" + escapeJson(platform) + "\",\n" +
    "  \"prefer\": \"" + escapeJson(options.prefer) + "\",\n" +
    "  \"normalizedPreference\": \"" + escapeJson(prefer) + "\",\n" +
    "  \"status\": \"" + escapeJson(status) + "\",\n" +
    "  \"recommendedProvider\": \"" + escapeJson(recommended) + "\",\n" +
    "  \"decision\": \"" + escapeJson(providerDecisionText(recommended)) + "\",\n" +
    "  \"recommendedLane\": " + renderDoctorLane(recommended, true) + ",\n" +
    "  \"nonRecommendedLanes\": [\n" +
    renderNonRecommendedLanes(recommended) + "\n" +
    "  ],\n" +
    "  \"precedenceRule\": \"" + escapeJson(providerPrecedenceRule(recommended)) + "\",\n" +
    "  \"providerCommandExecution\": false,\n" +
    "  \"installActionTaken\": false,\n" +
    "  \"versionManagementActionTaken\": false,\n" +
    "  \"rcMutationActionTaken\": false,\n" +
    "  \"nextAllowed\": [\n" +
    "    \"print-env-snippet\",\n" +
    "    \"run-stdx-runtime-doctor\",\n" +
    "    \"generate-reviewed-fetch-recipe\",\n" +
    "    \"use-cjv-or-cjvs-manually-if-selected\"\n" +
    "  ],\n" +
    "  \"nonPromises\": [\n" +
    "    \"toolchain doctor does not run cjv or cjvs\",\n" +
    "    \"toolchain doctor does not install or switch SDKs\",\n" +
    "    \"toolchain doctor does not mutate shell profiles\",\n" +
    "    \"provider recommendation is not compatibility certification\"\n" +
    "  ]\n" +
    "}"
}

func renderDoctorLane(provider: String, selected: Bool): String {
    "    {\"id\":\"" + escapeJson(provider) +
    "\",\"selected\": " + boolJson(selected) +
    ",\"reason\":\"" + escapeJson(providerDecisionText(provider)) +
    "\",\"notSelectedReason\":\"" + escapeJson(nonSelectedProviderReason(provider)) +
    "\",\"executionBoundary\":\"read-only-no-provider-exec\"}"
}

func renderNonRecommendedLanes(recommended: String): String {
    var out = ""
    out = appendNonRecommendedLane(out, recommended, "cjv")
    out = appendNonRecommendedLane(out, recommended, "cjvs")
    out = appendNonRecommendedLane(out, recommended, "official-script")
    out = appendNonRecommendedLane(out, recommended, "hap-recipe")
    out = appendNonRecommendedLane(out, recommended, "harmonyos-pc-sdk")
    out = appendNonRecommendedLane(out, recommended, "local-sdk")
    out
}

func appendNonRecommendedLane(out: String, recommended: String, provider: String): String {
    if (provider == recommended) {
        return out
    }
    if (out.size > 0) {
        return out + ",\n" + renderDoctorLane(provider, false)
    }
    renderDoctorLane(provider, false)
}

func normalizeProviderPreference(prefer: String): String {
    match (prefer) {
        case "auto" => "auto"
        case "cjv" => "cjv"
        case "cjvs" => "cjvs"
        case "official-script" => "official-script"
        case "hap-recipe" => "hap-recipe"
        case "harmonyos-pc-sdk" => "harmonyos-pc-sdk"
        case "local" => "local-sdk"
        case "local-sdk" => "local-sdk"
        case _ => ""
    }
}

func recommendedProviderForPreference(prefer: String): String {
    match (prefer) {
        case "auto" => "hap-recipe"
        case "cjv" => "cjv"
        case "cjvs" => "cjvs"
        case "official-script" => "official-script"
        case "hap-recipe" => "hap-recipe"
        case "harmonyos-pc-sdk" => "harmonyos-pc-sdk"
        case "local-sdk" => "local-sdk"
        case _ => ""
    }
}

func providerDecisionText(provider: String): String {
    match (provider) {
        case "cjv" => "use cjv as SDK/component manager when it is already installed; HapCLI remains project/CI/receipt layer"
        case "cjvs" => "use cjvs as external SDK/version surface when it is already installed; HapCLI remains project/CI/receipt layer"
        case "official-script" => "generate reviewed recipe from official assets instead of owning SDK version lifecycle"
        case "hap-recipe" => "use HapCLI reviewed recipe for CI/cloud/runtime/stdx repair without becoming SDK manager"
        case "harmonyos-pc-sdk" => "use hapup reviewed install for HarmonyOS PC SDK archives, including chmod/sign/ld.lld repair"
        case "local-sdk" => "read local SDK evidence and print env hints without taking ownership"
        case _ => "unsupported provider preference"
    }
}

func providerPrecedenceRule(provider: String): String {
    match (provider) {
        case "cjv" => "external version manager wins SDK lifecycle; HapCLI stays in receipt/project bridge lane"
        case "cjvs" => "external version manager wins SDK lifecycle; HapCLI stays in receipt/project bridge lane"
        case "official-script" => "official asset truth feeds a reviewed recipe after checksum and human review"
        case "hap-recipe" => "Hap reviewed recipe wins CI/cloud repair when no SDK manager preference is declared"
        case "harmonyos-pc-sdk" => "HarmonyOS PC SDK archives must pass reviewed local install with receipt before env promotion"
        case "local-sdk" => "local evidence wins only for same-host diagnosis and must not be exported as hosted CI proof"
        case _ => "unsupported provider preference"
    }
}

func nonSelectedProviderReason(provider: String): String {
    match (provider) {
        case "cjv" => "not selected unless the host already standardizes on cjv"
        case "cjvs" => "not selected unless the host already standardizes on cjvs"
        case "official-script" => "not selected unless official asset and checksum truth are the current review source"
        case "hap-recipe" => "not selected only when an explicit external provider preference overrides the default"
        case "harmonyos-pc-sdk" => "not selected unless the host is bootstrapping a HarmonyOS PC Cangjie SDK archive"
        case "local-sdk" => "not selected for portable CI because local SDK evidence is host-specific"
        case _ => "unsupported provider lane"
    }
}

public func renderEnvPrintJson(options: HapEnvPrintOptions): String {
    let target = canonicalTargetName(options.target)
    let platform = cangjiePlatformNameForTarget(target)
    let shell = normalizeShell(options.shell)
    let ok = options.installRoot.size > 0 && platform.size > 0 && shell.size > 0
    let runtimePath = options.installRoot + "/runtime/" + platform
    let stdxDynamic = options.installRoot + "/stdx/" + platform + "/dynamic"
    let stdxStatic = options.installRoot + "/stdx/" + platform + "/static"
    let snippet = renderShellSnippet(shell, runtimePath, stdxDynamic, stdxStatic)

    "{\n" +
    "  \"schema\": \"happub-hapcli-env-print-v0\",\n" +
    "  \"ok\": " + boolJson(ok) + ",\n" +
    "  \"mode\": \"print-only-shell-env-snippet\",\n" +
    "  \"subject\": \"" + escapeJson(options.subject) + "\",\n" +
    "  \"shell\": \"" + escapeJson(shell) + "\",\n" +
    "  \"target\": \"" + escapeJson(target) + "\",\n" +
    "  \"platform\": \"" + escapeJson(platform) + "\",\n" +
    "  \"installRoot\": \"" + escapeJson(options.installRoot) + "\",\n" +
    "  \"runtimePath\": \"" + escapeJson(runtimePath) + "\",\n" +
    "  \"stdxDynamicPath\": \"" + escapeJson(stdxDynamic) + "\",\n" +
    "  \"stdxStaticPath\": \"" + escapeJson(stdxStatic) + "\",\n" +
    "  \"snippet\": \"" + escapeJson(snippet) + "\",\n" +
    "  \"mutationActionTaken\": false,\n" +
    "  \"rcMutationActionTaken\": false,\n" +
    "  \"nextAllowed\": [\n" +
    "    \"copy-snippet-after-review\",\n" +
    "    \"generate-reviewed-env-apply-plan\",\n" +
    "    \"rerun-toolchain-doctor\"\n" +
    "  ],\n" +
    "  \"nonPromises\": [\n" +
    "    \"env print does not install runtime or stdx\",\n" +
    "    \"env print does not write zshrc, bashrc, fish config, or powershell profile\",\n" +
    "    \"env print does not verify that hinted paths exist\",\n" +
    "    \"persistent rc apply is future review-token work\"\n" +
    "  ]\n" +
    "}"
}

public func runEnvApply(commandLine: Array<String>, start: Int64): String {
    let options = resolveEnvApplyOptions(commandLine, start)
    renderEnvApplyJson(options, true)
}

public func renderEnvApplyJson(options: HapEnvApplyOptions, canWrite: Bool): String {
    let target = canonicalTargetName(options.target)
    let platform = cangjiePlatformNameForTarget(target)
    let shell = normalizeShell(options.shell)
    let requiredOk = options.installRoot.size > 0 && options.rcPath.size > 0 && options.receiptPath.size > 0 && platform.size > 0 && shell.size > 0
    let reviewOk = options.reviewToken.size > 0
    let status = if (!requiredOk) {
        "missing-required-field"
    } else if (!reviewOk) {
        "missing-review-token-for-env-apply"
    } else {
        "reviewed-rc-patch-written"
    }
    let backupPath = options.rcPath + ".hap-backup"
    let runtimePath = options.installRoot + "/runtime/" + platform
    let stdxDynamic = options.installRoot + "/stdx/" + platform + "/dynamic"
    let stdxStatic = options.installRoot + "/stdx/" + platform + "/static"
    let snippet = renderShellSnippet(shell, runtimePath, stdxDynamic, stdxStatic)
    var rcWritten = false
    var backupWritten = false
    var receiptWritten = false
    var beforeText = ""

    if (requiredOk && reviewOk && canWrite) {
        if (exists(options.rcPath)) {
            beforeText = String.fromUtf8(File.readFrom(options.rcPath))
        }
        File.writeTo(backupPath, beforeText.toArray())
        backupWritten = true
        let patchedText = appendHapEnvBlock(beforeText, snippet)
        File.writeTo(options.rcPath, patchedText.toArray())
        rcWritten = true
        File.writeTo(options.receiptPath, renderEnvApplyReceipt(options, target, platform, shell, backupPath, rcWritten, backupWritten).toArray())
        receiptWritten = true
    }

    "{\n" +
    "  \"schema\": \"happub-hapcli-env-apply-v0\",\n" +
    "  \"ok\": " + boolJson(rcWritten && receiptWritten) + ",\n" +
    "  \"mode\": \"reviewed-shell-rc-patch\",\n" +
    "  \"status\": \"" + escapeJson(status) + "\",\n" +
    "  \"subject\": \"" + escapeJson(options.subject) + "\",\n" +
    "  \"shell\": \"" + escapeJson(shell) + "\",\n" +
    "  \"target\": \"" + escapeJson(target) + "\",\n" +
    "  \"platform\": \"" + escapeJson(platform) + "\",\n" +
    "  \"installRoot\": \"" + escapeJson(options.installRoot) + "\",\n" +
    "  \"rcPath\": \"" + escapeJson(options.rcPath) + "\",\n" +
    "  \"backupPath\": \"" + escapeJson(backupPath) + "\",\n" +
    "  \"receiptPath\": \"" + escapeJson(options.receiptPath) + "\",\n" +
    "  \"backupWritten\": " + boolJson(backupWritten) + ",\n" +
    "  \"rcMutationActionTaken\": " + boolJson(rcWritten) + ",\n" +
    "  \"receiptWritten\": " + boolJson(receiptWritten) + ",\n" +
    "  \"nextAllowed\": [\n" +
    "    \"source-rc-after-human-review\",\n" +
    "    \"restore-from-backup-if-needed\",\n" +
    "    \"rerun-env-print\"\n" +
    "  ],\n" +
    "  \"nonPromises\": [\n" +
    "    \"env apply does not install runtime or stdx\",\n" +
    "    \"env apply only mutates the exact rc path provided by the caller\",\n" +
    "    \"env apply does not verify that hinted paths exist\",\n" +
    "    \"backup is file-backed but not a system restore point\"\n" +
    "  ]\n" +
    "}"
}

func appendHapEnvBlock(beforeText: String, snippet: String): String {
    let prefix = if (beforeText.size > 0 && !beforeText.endsWith("\n")) {
        beforeText + "\n"
    } else {
        beforeText
    }
    prefix + "# >>> HapCLI env start\n" + snippet + "\n# <<< HapCLI env end\n"
}

func renderEnvApplyReceipt(options: HapEnvApplyOptions, target: String, platform: String, shell: String, backupPath: String, rcWritten: Bool, backupWritten: Bool): String {
    "{\n" +
    "  \"schema\": \"happub-hapcli-env-apply-receipt-v0\",\n" +
    "  \"ok\": true,\n" +
    "  \"subject\": \"" + escapeJson(options.subject) + "\",\n" +
    "  \"shell\": \"" + escapeJson(shell) + "\",\n" +
    "  \"target\": \"" + escapeJson(target) + "\",\n" +
    "  \"platform\": \"" + escapeJson(platform) + "\",\n" +
    "  \"installRoot\": \"" + escapeJson(options.installRoot) + "\",\n" +
    "  \"rcPath\": \"" + escapeJson(options.rcPath) + "\",\n" +
    "  \"backupPath\": \"" + escapeJson(backupPath) + "\",\n" +
    "  \"backupWritten\": " + boolJson(backupWritten) + ",\n" +
    "  \"rcMutationActionTaken\": " + boolJson(rcWritten) + ",\n" +
    "  \"canonMutation\": false,\n" +
    "  \"restoreHint\": \"copy backupPath back to rcPath after review if rollback is needed\"\n" +
    "}\n"
}

func normalizeShell(shell: String): String {
    match (shell) {
        case "zsh" => "zsh"
        case "bash" => "bash"
        case "fish" => "fish"
        case "powershell" => "powershell"
        case "pwsh" => "powershell"
        case "cmd" => "cmd"
        case _ => ""
    }
}

func renderShellSnippet(shell: String, runtimePath: String, stdxDynamic: String, stdxStatic: String): String {
    match (shell) {
        case "zsh" => "export LD_LIBRARY_PATH=\"" + runtimePath + "/lib:$LD_LIBRARY_PATH\"\nexport CANGJIE_STDX_PATH_DYNAMIC=\"" + stdxDynamic + "\"\nexport CANGJIE_STDX_PATH_STATIC=\"" + stdxStatic + "\""
        case "bash" => "export LD_LIBRARY_PATH=\"" + runtimePath + "/lib:$LD_LIBRARY_PATH\"\nexport CANGJIE_STDX_PATH_DYNAMIC=\"" + stdxDynamic + "\"\nexport CANGJIE_STDX_PATH_STATIC=\"" + stdxStatic + "\""
        case "fish" => "set -gx LD_LIBRARY_PATH \"" + runtimePath + "/lib\" $LD_LIBRARY_PATH\nset -gx CANGJIE_STDX_PATH_DYNAMIC \"" + stdxDynamic + "\"\nset -gx CANGJIE_STDX_PATH_STATIC \"" + stdxStatic + "\""
        case "powershell" => "$env:LD_LIBRARY_PATH=\"" + runtimePath + "/lib\"\n$env:CANGJIE_STDX_PATH_DYNAMIC=\"" + stdxDynamic + "\"\n$env:CANGJIE_STDX_PATH_STATIC=\"" + stdxStatic + "\""
        case "cmd" => "set LD_LIBRARY_PATH=" + runtimePath + "\\lib\nset CANGJIE_STDX_PATH_DYNAMIC=" + stdxDynamic + "\nset CANGJIE_STDX_PATH_STATIC=" + stdxStatic
        case _ => ""
    }
}
