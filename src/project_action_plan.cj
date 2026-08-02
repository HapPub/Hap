package hapcli

import std.collection.ArrayList
import std.env.{getStdIn, getVariable}
import std.fs.{File, exists}

public class HapProjectActionOptions {
    public var action: String = "build"
    public var project: String = "."
    public var platform: String = "auto"
    public var target: String = "auto"
    public var outputDir: String = ""
    public var device: String = "auto"
    public var artifact: String = ""
    public var useOld: Bool = false
    public var iosScheme: String = ""
    public var iosConfiguration: String = ""
    public var iosDevelopmentTeam: String = ""
    public var iosDerivedDataPath: String = ""
    public var config: String = ""
    public var verbose: Bool = false
    public var networkMode: String = "no-proxy"
    public var lint: Bool = false
    public var listen: Bool = false
    public var allowWireless: Bool = false
    public var wirelessReceipt: String = ""
    public var deviceMemory: String = ""
    public var plan: Bool = false
    public var executeReviewed: Bool = false
    public var localDevAuto: Bool = false
    public var reviewToken: String = ""
    public var receipt: String = ""
    public var receiptRequested: Bool = false
    public var logDir: String = ""
    public var interactive: Bool = false
    public let toolchainAnswers: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func resolveProjectActionOptions(action: String, commandLine: Array<String>, startIndex: Int64): HapProjectActionOptions {
    let options = HapProjectActionOptions()
    options.action = action
    var i = startIndex
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
        if (current == "--platform" && i + 1 < commandLine.size) {
            options.platform = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--platform=")) {
            options.platform = substringFrom(current, 11)
            i += 1
            continue
        }
        if (current == "--target" && i + 1 < commandLine.size) {
            options.target = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--target=")) {
            options.target = substringFrom(current, 9)
            i += 1
            continue
        }
        if ((current == "--output" || current == "--output-dir") && i + 1 < commandLine.size) {
            options.outputDir = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--output=")) {
            options.outputDir = substringFrom(current, 9)
            i += 1
            continue
        }
        if (startsWithText(current, "--output-dir=")) {
            options.outputDir = substringFrom(current, 13)
            i += 1
            continue
        }
        if (current == "--device" && i + 1 < commandLine.size) {
            options.device = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--device=")) {
            options.device = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--artifact" && i + 1 < commandLine.size) {
            options.artifact = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--artifact=")) {
            options.artifact = substringFrom(current, 11)
            i += 1
            continue
        }
        if (current == "--useOld" || current == "--use-old") {
            options.useOld = true
            i += 1
            continue
        }
        if (current == "--scheme" && i + 1 < commandLine.size) {
            options.iosScheme = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--scheme=")) {
            options.iosScheme = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--configuration" && i + 1 < commandLine.size) {
            options.iosConfiguration = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--configuration=")) {
            options.iosConfiguration = substringFrom(current, 16)
            i += 1
            continue
        }
        if (current == "--development-team" && i + 1 < commandLine.size) {
            options.iosDevelopmentTeam = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--development-team=")) {
            options.iosDevelopmentTeam = substringFrom(current, 19)
            i += 1
            continue
        }
        if (current == "--derived-data-path" && i + 1 < commandLine.size) {
            options.iosDerivedDataPath = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--derived-data-path=")) {
            options.iosDerivedDataPath = substringFrom(current, 20)
            i += 1
            continue
        }
        if (current == "--config" && i + 1 < commandLine.size) {
            options.config = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--config=")) {
            options.config = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--verbose" || current == "-v") {
            options.verbose = true
            i += 1
            continue
        }
        if (current == "--proxy") {
            options.networkMode = "proxy"
            i += 1
            continue
        }
        if (current == "--no-proxy") {
            options.networkMode = "no-proxy"
            i += 1
            continue
        }
        if (current == "--lint") {
            options.lint = true
            i += 1
            continue
        }
        if (current == "--listen") {
            options.listen = true
            i += 1
            continue
        }
        if (current == "--allow-wireless") {
            options.allowWireless = true
            i += 1
            continue
        }
        if ((current == "--wireless-receipt" || current == "--device-receipt") && i + 1 < commandLine.size) {
            options.wirelessReceipt = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--wireless-receipt=")) {
            options.wirelessReceipt = substringFrom(current, 19)
            i += 1
            continue
        }
        if (startsWithText(current, "--device-receipt=")) {
            options.wirelessReceipt = substringFrom(current, 17)
            i += 1
            continue
        }
        if ((current == "--device-memory" || current == "--device-memory-path") && i + 1 < commandLine.size) {
            options.deviceMemory = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--device-memory=")) {
            options.deviceMemory = substringFrom(current, 16)
            i += 1
            continue
        }
        if (startsWithText(current, "--device-memory-path=")) {
            options.deviceMemory = substringFrom(current, 21)
            i += 1
            continue
        }
        if (current == "--plan") {
            options.plan = true
            i += 1
            continue
        }
        if (current == "--execute-reviewed") {
            options.executeReviewed = true
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
        if (current == "--receipt" && i + 1 < commandLine.size) {
            options.receipt = commandLine[i + 1]
            options.receiptRequested = true
            i += 2
            continue
        }
        if (startsWithText(current, "--receipt=")) {
            options.receipt = substringFrom(current, 10)
            options.receiptRequested = true
            i += 1
            continue
        }
        if (current == "--write-receipt" || current == "--with-receipt") {
            options.receiptRequested = true
            i += 1
            continue
        }
        if (current == "--log-dir" && i + 1 < commandLine.size) {
            options.logDir = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--log-dir=")) {
            options.logDir = substringFrom(current, 10)
            i += 1
            continue
        }
        if (current == "--interactive") {
            options.interactive = true
            i += 1
            continue
        }
        if (current == "--toolchain-answer" && i + 1 < commandLine.size) {
            options.toolchainAnswers.add(commandLine[i + 1])
            i += 2
            continue
        }
        if (startsWithText(current, "--toolchain-answer=")) {
            options.toolchainAnswers.add(substringFrom(current, 19))
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func prepareHarmonyLocalDevAutoOptions(options: HapProjectActionOptions): HapProjectActionOptions {
    options.localDevAuto = true
    if (options.receipt.size == 0 && options.receiptRequested) {
        options.receipt = trimTrailingSlash(options.project) + "/.hapData/receipts/harmony-dev-latest.receipt.json"
    }
    if (options.logDir.size == 0) {
        options.logDir = trimTrailingSlash(options.project) + "/.hapData/logs/harmony-dev"
    }
    options
}

public func shouldUseProjectActionPlan(commandLine: Array<String>, startIndex: Int64): Bool {
    var i = startIndex
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--plan" || current == "--platform" || startsWithText(current, "--platform=")) {
            return true
        }
        if (current == "--execute-reviewed") {
            return true
        }
        i += 1
    }
    false
}

public func shouldUseAutoProjectActionForBuild(commandLine: Array<String>, startIndex: Int64): Bool {
    if (shouldUseProjectActionPlan(commandLine, startIndex)) {
        return true
    }
    let options = resolveProjectActionOptions("build", commandLine, startIndex)
    let candidates = detectProjectCandidates(options.project)
    let selected = selectProjectDetection(candidates, options.platform)
    let selection = resolveProjectSelectionInfo(candidates, options.platform, selected)
    if (selection.status != "selected") {
        return true
    }
    selected.projectKind != "cangjie"
}

public func renderProjectActionPlanJson(options: HapProjectActionOptions): String {
    let candidates = detectProjectCandidates(options.project)
    let selected = selectProjectDetection(candidates, options.platform)
    let selection = resolveProjectSelectionInfo(candidates, options.platform, selected)
    let wirelessTrust = inspectHarmonyWirelessReceipt(options.wirelessReceipt)
    let wirelessGateTrust = resolveHarmonyWirelessGateTrust(options, wirelessTrust)
    let harmonyConfig = resolveHarmonyAdapterConfig(options)
    let interactiveRepair = applyInteractiveToolchainAnswers(selected.projectKind, options.action, options, harmonyConfig)
    let directWirelessTarget = selected.projectKind == "harmonyos" && actionNeedsDevice(options.action) && containsText(harmonyConfig.selectedDeviceTarget, ":")
    let wirelessReconnectAllowed = directWirelessTarget || (options.allowWireless && wirelessGateTrust.trusted && selected.projectKind == "harmonyos" && actionNeedsDevice(options.action))
    let toolchainStatus = projectToolchainStatusWithInteractive(selected.projectKind, options.action, options.project, options.target, harmonyConfig, interactiveRepair)
    let selectionOk = selection.status == "selected"
    let ok = selectionOk && selected.projectKind != "unknown" && supportsProjectAction(selected.projectKind, options.action) && (!options.allowWireless || wirelessGateTrust.trusted)
    let commands = if (selectionOk) { projectActionCommands(selected.projectKind, options.action, options, wirelessGateTrust, harmonyConfig) } else { ArrayList<String>() }
    let renderedDeviceTool = if (selected.projectKind == "kotlin-multiplatform" && isKmpDesktopTarget(options.target)) { "gradle" } else { selected.deviceTool }
    let status = if (!selectionOk) {
        selection.status
    } else if (!supportsProjectAction(selected.projectKind, options.action)) {
        "action-not-supported-for-adapter"
    } else if (options.allowWireless && !wirelessGateTrust.trusted && options.wirelessReceipt.size == 0 && options.deviceMemory.size == 0) {
        "wireless-receipt-required"
    } else if (options.allowWireless && !wirelessGateTrust.trusted) {
        wirelessGateTrust.status
    } else {
        "adapter-plan-ready"
    }

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-project-action-plan-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"plan-only\",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"action\": \"" + escapeJson(options.action) + "\",\n")
    out.append("  \"project\": \"" + escapeJson(options.project) + "\",\n")
    out.append("  \"requestedPlatform\": \"" + escapeJson(options.platform) + "\",\n")
    out.append("  \"target\": \"" + escapeJson(options.target) + "\",\n")
    out.append("  \"normalizedPlatform\": \"" + escapeJson(normalizeProjectPlatform(options.platform)) + "\",\n")
    out.append("  \"selectionStatus\": \"" + escapeJson(selection.status) + "\",\n")
    out.append("  \"ambiguousProject\": " + boolJson(selection.ambiguous) + ",\n")
    out.append("  \"needsPlatform\": " + boolJson(selection.needsPlatform) + ",\n")
    out.append("  \"availablePlatforms\": ")
    appendProjectJsonStringArray(out, selection.availablePlatforms)
    out.append(",\n")
    out.append("  \"projectKind\": \"" + escapeJson(selected.projectKind) + "\",\n")
    out.append("  \"buildSystem\": \"" + escapeJson(selected.buildSystem) + "\",\n")
    out.append("  \"deviceTool\": \"" + escapeJson(renderedDeviceTool) + "\",\n")
    out.append("  \"confidence\": \"" + escapeJson(selected.confidence) + "\",\n")
    out.append("  \"outputDir\": \"" + escapeJson(options.outputDir) + "\",\n")
    out.append("  \"device\": \"" + escapeJson(options.device) + "\",\n")
    out.append("  \"artifact\": \"" + escapeJson(options.artifact) + "\",\n")
    out.append("  \"config\": \"" + escapeJson(options.config) + "\",\n")
    out.append("  \"harmonyConfigPath\": \"" + escapeJson(harmonyConfig.configPath) + "\",\n")
    out.append("  \"harmonyConfigSource\": \"" + escapeJson(harmonyConfig.pathSource) + "\",\n")
    out.append("  \"toolchainStatus\": \"" + escapeJson(toolchainStatus) + "\",\n")
    out.append("  \"interactiveToolchainRequested\": " + boolJson(options.interactive || options.toolchainAnswers.size > 0) + ",\n")
    out.append("  \"interactiveRepairStatus\": \"" + escapeJson(interactiveRepair.status) + "\",\n")
    out.append("  \"verbose\": " + boolJson(options.verbose) + ",\n")
    out.append("  \"networkMode\": \"" + escapeJson(normalizeHapNetworkMode(options.networkMode)) + "\",\n")
    out.append("  \"proxyEnvironmentInherited\": " + boolJson(normalizeHapNetworkMode(options.networkMode) == "proxy") + ",\n")
    out.append("  \"proxyEnvironmentCleared\": " + boolJson(normalizeHapNetworkMode(options.networkMode) == "no-proxy") + ",\n")
    out.append("  \"lintRequested\": " + boolJson(options.lint) + ",\n")
    out.append("  \"listenRequested\": " + boolJson(options.listen) + ",\n")
    out.append("  \"executeReviewedRequested\": " + boolJson(options.executeReviewed) + ",\n")
    out.append("  \"localDevAutoRequested\": " + boolJson(options.localDevAuto) + ",\n")
    out.append("  \"reviewTokenPresent\": " + boolJson(options.reviewToken.size > 0) + ",\n")
    out.append("  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n")
    out.append("  \"logDir\": \"" + escapeJson(options.logDir) + "\",\n")
    out.append("  \"allowWirelessRequested\": " + boolJson(options.allowWireless) + ",\n")
    out.append("  \"wirelessReceipt\": \"" + escapeJson(options.wirelessReceipt) + "\",\n")
    out.append("  \"wirelessReceiptStatus\": \"" + escapeJson(wirelessTrust.status) + "\",\n")
    out.append("  \"wirelessReceiptTrusted\": " + boolJson(wirelessTrust.trusted) + ",\n")
    out.append("  \"deviceMemory\": \"" + escapeJson(options.deviceMemory) + "\",\n")
    out.append("  \"deviceMemoryPath\": \"" + escapeJson(wirelessGateTrust.deviceMemoryPath) + "\",\n")
    out.append("  \"deviceMemoryStatus\": \"" + escapeJson(wirelessGateTrust.deviceMemoryStatus) + "\",\n")
    out.append("  \"deviceMemoryTrusted\": " + boolJson(wirelessGateTrust.deviceMemoryTrusted) + ",\n")
    out.append("  \"wirelessTrustSource\": \"" + escapeJson(wirelessGateTrust.source) + "\",\n")
    out.append("  \"trustedWirelessTarget\": \"" + escapeJson(wirelessGateTrust.target) + "\",\n")
    out.append("  \"trustedWirelessIp\": \"" + escapeJson(wirelessGateTrust.ip) + "\",\n")
    out.append("  \"trustedWirelessPort\": \"" + escapeJson(wirelessGateTrust.port) + "\",\n")
    out.append("  \"executionActionTaken\": false,\n")
    out.append("  \"mutationActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"workflowMutationActionTaken\": false,\n")
    out.append("  \"wirelessReconnectAllowed\": " + boolJson(wirelessReconnectAllowed) + ",\n")
    out.append("  \"usbFirstRequired\": " + boolJson(selected.projectKind == "harmonyos" && actionNeedsDevice(options.action) && harmonyConfig.selectedDeviceTarget.size == 0 && !wirelessReconnectAllowed) + ",\n")
    out.append("  \"trustedDeviceMemoryRequired\": " + boolJson(selected.projectKind == "harmonyos" && options.allowWireless) + ",\n")
    out.append("  \"signals\": ")
    appendProjectJsonStringArray(out, selected.signals)
    out.append(",\n")
    out.append("  \"toolchainQuestions\": ")
    appendProjectJsonStringArray(out, projectToolchainQuestions(selected.projectKind, options.action, options.project, options.target, harmonyConfig))
    out.append(",\n")
    out.append("  \"toolchainValidationCommands\": ")
    appendProjectJsonStringArray(out, projectToolchainValidationCommands(selected.projectKind, options.action, options.project, options.target, harmonyConfig))
    out.append(",\n")
    out.append("  \"interactiveToolchainAnswers\": ")
    appendProjectJsonStringArray(out, interactiveRepair.answers)
    out.append(",\n")
    out.append("  \"interactiveConfigSuggestions\": ")
    appendProjectJsonStringArray(out, interactiveRepair.configSuggestions)
    out.append(",\n")
    out.append("  \"interactiveEnvSuggestions\": ")
    appendProjectJsonStringArray(out, interactiveRepair.envSuggestions)
    out.append(",\n")
    out.append("  \"fixedCommandTemplates\": ")
    appendProjectJsonStringArray(out, commands)
    out.append(",\n")
    out.append("  \"receiptPlan\": {\n")
    out.append("    \"wouldWriteReceipt\": true,\n")
    out.append("    \"receiptSchema\": \"happub-hapcli-project-action-receipt-v0\",\n")
    out.append("    \"requiredFields\": [\"schema\", \"ok\", \"action\", \"projectKind\", \"fixedCommandTemplates\", \"exitCode\", \"artifactCandidates\", \"changedPaths\"]\n")
    out.append("  },\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"promote one adapter to fixed execution only after plan receipts are accepted\",\n")
    out.append("    \"run KMP iOS source-build execution only on a macOS host with one ready device and valid Xcode signing assets\",\n")
    out.append("    \"generate hap harmony wireless-recipe for reviewed USB-first tconn proof before any wireless reconnect\",\n")
    out.append("    \"keep HarmonyOS wireless reconnect behind prior USB proof and allow-wireless\",\n")
    out.append("    \"keep dependency update and self-upgrade outside build/test plans\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"this plan does not execute hvigor, xcodebuild, gradle, cjpm, hdc, simctl, or devicectl\",\n")
    out.append("    \"this plan does not prove that an Apple account, signing identity, provisioning profile, or iOS device is currently usable\",\n")
    out.append("    \"this plan does not install, launch, listen, reconnect devices, update dependencies, or mutate workflow files\",\n")
    out.append("    \"command templates are fixed adapter candidates, not arbitrary shell input\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func supportsProjectAction(projectKind: String, action: String): Bool {
    if (action == "build" || action == "test") {
        return projectKind == "harmonyos" || projectKind == "ios" || projectKind == "kotlin-multiplatform" || projectKind == "cangjie"
    }
    if (action == "dev") {
        return projectKind == "harmonyos" || projectKind == "kotlin-multiplatform"
    }
    action == "push" && projectKind == "harmonyos"
}

func actionNeedsDevice(action: String): Bool {
    action == "dev" || action == "push"
}

class HapHarmonyWirelessGateTrust {
    var trusted: Bool = false
    var source: String = "none"
    var status: String = "trusted-wireless-proof-required"
    var target: String = ""
    var ip: String = ""
    var port: String = ""
    var wirelessReceiptStatus: String = "missing-receipt"
    var deviceMemoryPath: String = ""
    var deviceMemoryStatus: String = "memory-not-found"
    var deviceMemoryTrusted: Bool = false

    init() {}
}

class HapToolchainInteractiveRepair {
    var status: String = "not-requested"
    let answers: ArrayList<String> = ArrayList<String>()
    let configSuggestions: ArrayList<String> = ArrayList<String>()
    let envSuggestions: ArrayList<String> = ArrayList<String>()

    init() {}
}

func resolveHarmonyWirelessGateTrust(options: HapProjectActionOptions, wirelessTrust: HapHarmonyWirelessReceiptTrust): HapHarmonyWirelessGateTrust {
    let gate = HapHarmonyWirelessGateTrust()
    gate.wirelessReceiptStatus = wirelessTrust.status
    let memoryOptions = HapHarmonyDeviceMemoryOptions()
    memoryOptions.project = options.project
    memoryOptions.memory = options.deviceMemory
    let memoryTrust = inspectHarmonyDeviceMemory(memoryOptions)
    gate.deviceMemoryPath = memoryTrust.memoryPath
    gate.deviceMemoryStatus = memoryTrust.status
    gate.deviceMemoryTrusted = memoryTrust.trusted
    if (wirelessTrust.trusted) {
        gate.trusted = true
        gate.source = "wireless-receipt"
        gate.status = wirelessTrust.status
        gate.target = wirelessTrust.target
        gate.ip = wirelessTrust.ip
        gate.port = wirelessTrust.port
        return gate
    }
    if (memoryTrust.trusted) {
        gate.trusted = true
        gate.source = "device-memory"
        gate.status = memoryTrust.status
        gate.target = memoryTrust.target
        gate.ip = memoryTrust.ip
        gate.port = memoryTrust.port
        return gate
    }
    gate.source = if (options.deviceMemory.size > 0) { "device-memory" } else if (options.wirelessReceipt.size > 0) { "wireless-receipt" } else { "none" }
    gate.status = if (options.deviceMemory.size > 0) { memoryTrust.status } else if (options.wirelessReceipt.size > 0) { wirelessTrust.status } else { "trusted-wireless-proof-required" }
    gate
}

func applyInteractiveToolchainAnswers(projectKind: String, action: String, options: HapProjectActionOptions, config: HapHarmonyAdapterConfig): HapToolchainInteractiveRepair {
    let repair = HapToolchainInteractiveRepair()
    if (!options.interactive && options.toolchainAnswers.size == 0) {
        return repair
    }
    repair.status = "not-needed"
    if (projectKind == "harmonyos") {
        var needed: Int64 = 0
        var valid: Int64 = 0
        if ((action == "build" || action == "test" || action == "dev") && !isProgramResolvable(config.hvigorwPath)) {
            needed += 1
            let answer = resolveToolchainAnswerOrPrompt(options, "hvigorw", "请输入可执行 hvigorw 路径，或直接回车跳过：")
            if (recordToolchainAnswer(repair, "hvigorw", answer, "hvigorwPath", "HAP_HARMONY_HVIGORW", "harmonyos")) {
                config.hvigorwPath = answer
                valid += 1
            }
        }
        if ((action == "dev" || action == "push") && !isProgramResolvable(config.hdcPath)) {
            needed += 1
            let answer = resolveToolchainAnswerOrPrompt(options, "hdc", "请输入可执行 hdc 路径，或直接回车跳过：")
            if (recordToolchainAnswer(repair, "hdc", answer, "hdcPath", "HAP_HARMONY_HDC", "harmonyos")) {
                config.hdcPath = answer
                valid += 1
            }
        }
        if (needed == 0 && options.toolchainAnswers.size > 0) {
            let hvigorwAnswer = findToolchainAnswer(options, "hvigorw")
            if (hvigorwAnswer.size > 0) {
                needed += 1
                if (recordToolchainAnswer(repair, "hvigorw", hvigorwAnswer, "hvigorwPath", "HAP_HARMONY_HVIGORW", "harmonyos")) {
                    config.hvigorwPath = hvigorwAnswer
                    valid += 1
                }
            }
            let hdcAnswer = findToolchainAnswer(options, "hdc")
            if (hdcAnswer.size > 0) {
                needed += 1
                if (recordToolchainAnswer(repair, "hdc", hdcAnswer, "hdcPath", "HAP_HARMONY_HDC", "harmonyos")) {
                    config.hdcPath = hdcAnswer
                    valid += 1
                }
            }
        }
        repair.status = interactiveRepairStatus(needed, valid)
        return repair
    }
    if (projectKind == "cangjie") {
        var needed: Int64 = 0
        var valid: Int64 = 0
        if (!isProgramResolvable("cjpm")) {
            needed += 1
            let answer = resolveToolchainAnswerOrPrompt(options, "cjpm", "请输入可执行 cjpm 路径，或直接回车跳过：")
            if (recordToolchainAnswer(repair, "cjpm", answer, "PATH", "PATH", "cangjie")) {
                valid += 1
            }
        }
        if (!isProgramResolvable("cjc")) {
            needed += 1
            let answer = resolveToolchainAnswerOrPrompt(options, "cjc", "请输入可执行 cjc 路径，或直接回车跳过：")
            if (recordToolchainAnswer(repair, "cjc", answer, "PATH", "PATH", "cangjie")) {
                valid += 1
            }
        }
        if (needed == 0 && options.toolchainAnswers.size > 0) {
            let cjpmAnswer = findToolchainAnswer(options, "cjpm")
            if (cjpmAnswer.size > 0) {
                needed += 1
                if (recordToolchainAnswer(repair, "cjpm", cjpmAnswer, "PATH", "PATH", "cangjie")) {
                    valid += 1
                }
            }
            let cjcAnswer = findToolchainAnswer(options, "cjc")
            if (cjcAnswer.size > 0) {
                needed += 1
                if (recordToolchainAnswer(repair, "cjc", cjcAnswer, "PATH", "PATH", "cangjie")) {
                    valid += 1
                }
            }
        }
        repair.status = interactiveRepairStatus(needed, valid)
        return repair
    }
    repair.status = "unsupported-project-kind"
    repair
}

func interactiveRepairStatus(needed: Int64, valid: Int64): String {
    if (needed == 0) {
        return "not-needed"
    }
    if (valid == needed) {
        return "valid-answers-accepted"
    }
    if (valid > 0) {
        return "partial-valid-answers"
    }
    "missing-or-invalid-answers"
}

func resolveToolchainAnswerOrPrompt(options: HapProjectActionOptions, key: String, prompt: String): String {
    let fromArgs = findToolchainAnswer(options, key)
    if (fromArgs.size > 0) {
        return fromArgs
    }
    if (options.interactive) {
        println(prompt)
        match (getStdIn().readln()) {
            case Some(value) => return trimAsciiText(value)
            case None => return ""
        }
    }
    ""
}

func findToolchainAnswer(options: HapProjectActionOptions, key: String): String {
    for (item in options.toolchainAnswers) {
        let eq = indexOfText(item, "=")
        if (eq <= 0) {
            continue
        }
        let answerKey = normalizeToolchainAnswerKey(substringTo(item, eq))
        if (answerKey == normalizeToolchainAnswerKey(key)) {
            return trimAsciiText(substringFrom(item, eq + 1))
        }
    }
    ""
}

func normalizeToolchainAnswerKey(key: String): String {
    let trimmed = trimAsciiText(key)
    match (trimmed) {
        case "hvigorwPath" => "hvigorw"
        case "HAP_HARMONY_HVIGORW" => "hvigorw"
        case "hdcPath" => "hdc"
        case "HAP_HARMONY_HDC" => "hdc"
        case _ => trimmed
    }
}

func recordToolchainAnswer(
    repair: HapToolchainInteractiveRepair,
    key: String,
    answer: String,
    configKey: String,
    envKey: String,
    family: String
): Bool {
    if (answer.size == 0) {
        repair.answers.add(key + "=<empty> valid=false reason=empty-answer")
        return false
    }
    let valid = isProgramResolvable(answer)
    let validationCommand = answer + " --version"
    repair.answers.add(key + "=" + answer + " valid=" + boolJson(valid) + " family=" + family + " validation=\"" + validationCommand + "\"")
    if (valid) {
        if (family == "harmonyos") {
            repair.configSuggestions.add("happub.toml: " + configKey + " = \"" + answer + "\"")
            repair.envSuggestions.add("export " + envKey + "=\"" + answer + "\"")
        } else if (family == "cangjie") {
            repair.envSuggestions.add("export PATH=\"" + parentPath(answer) + ":$PATH\"")
        }
    }
    valid
}

func projectToolchainStatusWithInteractive(projectKind: String, action: String, project: String, target: String, config: HapHarmonyAdapterConfig, repair: HapToolchainInteractiveRepair): String {
    let status = projectToolchainStatus(projectKind, action, project, target, config)
    if (status == "toolchain-ready") {
        return status
    }
    if (repair.status == "valid-answers-accepted" && projectKind == "cangjie") {
        return "toolchain-answer-valid-path-update-required"
    }
    status
}

func projectActionCommands(
    projectKind: String,
    action: String,
    options: HapProjectActionOptions,
    wirelessTrust: HapHarmonyWirelessGateTrust,
    config: HapHarmonyAdapterConfig
): ArrayList<String> {
    let commands = ArrayList<String>()
    if (projectKind == "harmonyos") {
        if (action == "build") {
            commands.add(config.hvigorwPath + " assembleApp --mode project -p product=" + config.product + " -p buildMode=" + config.buildMode)
            commands.add(config.nodePath + " " + config.hvigorwJsPath + " --mode module -p module=" + config.module + " -p product=" + config.product + " -p buildMode=" + config.buildMode + " assembleHap")
        } else if (action == "test") {
            commands.add(config.hvigorwPath + " test")
            if (options.lint) {
                commands.add(config.hvigorwPath + " lint")
            }
        } else if (action == "dev") {
            let directWirelessTarget = containsText(config.selectedDeviceTarget, ":")
            if (directWirelessTarget) {
                commands.add(config.hdcPath + " tconn " + config.selectedDeviceTarget)
            }
            commands.add(config.hdcPath + " list targets")
            if (!directWirelessTarget && options.allowWireless && wirelessTrust.trusted) {
                commands.add(config.hdcPath + " tconn " + wirelessTrust.ip + ":" + wirelessTrust.port)
            }
            commands.add(config.hvigorwPath + " assembleApp --mode project -p product=" + config.product + " -p buildMode=" + config.buildMode)
            commands.add(hdcPlanCommand(config, "install -r " + config.artifactPath))
            commands.add(hdcPlanCommand(config, "shell aa start -b " + config.bundle + " -a " + config.ability))
            if (options.listen) {
                commands.add(hdcPlanCommand(config, "hilog"))
            }
        } else if (action == "push") {
            let directWirelessTarget = containsText(config.selectedDeviceTarget, ":")
            if (directWirelessTarget) {
                commands.add(config.hdcPath + " tconn " + config.selectedDeviceTarget)
            }
            commands.add(config.hdcPath + " list targets")
            if (!directWirelessTarget && options.allowWireless && wirelessTrust.trusted) {
                commands.add(config.hdcPath + " tconn " + wirelessTrust.ip + ":" + wirelessTrust.port)
            }
            if (options.artifact.size > 0) {
                commands.add(hdcPlanCommand(config, "install -r " + options.artifact))
            } else {
                commands.add(hdcPlanCommand(config, "install -r " + config.artifactPath))
            }
        }
    } else if (projectKind == "ios") {
        if (action == "build") {
            commands.add("xcodebuild build -scheme <scheme> -destination <destination>")
        } else {
            commands.add("xcodebuild test -scheme <scheme> -destination <destination>")
        }
    } else if (projectKind == "kotlin-multiplatform") {
        appendKmpEnvironmentTemplates(commands, options.target)
        if (action == "build") {
            commands.add(kmpGradleBuildCommand(options.project))
        } else {
            if (action == "dev") {
                if (isKmpDesktopTarget(options.target)) {
                    commands.add(kmpDesktopRunCommand(options.project))
                } else if (options.useOld || options.artifact.size > 0) {
                    commands.add("xcrun devicectl device info details --device <core-device-id>")
                    commands.add("xcrun devicectl device install app --device <core-device-id> " + if (options.artifact.size > 0) { options.artifact } else { "iosApp/build/Build/Products/Debug-iphoneos/<AppName>.app" })
                    commands.add("xcrun devicectl device process launch --device <core-device-id> <bundle-id>")
                } else {
                    commands.add(kmpGradleBuildCommand(options.project))
                    commands.add("xcodebuild -showdestinations -project iosApp/iosApp.xcodeproj -scheme " + inferKmpIosScheme(options.project))
                    commands.add("xcrun devicectl device info details --device <core-device-id>")
                    commands.add("sleep 15 # retry once if CoreDevice reports Device is busy or destination timeout")
                    commands.add("cd iosApp && JAVA_HOME=<jdk17-home> KONAN_DATA_DIR=$HOME/.gradle/.konan KOTLIN_DAEMON_DATA_DIR=/tmp/kotlin-daemon-$USER xcodebuild -project iosApp.xcodeproj -scheme " + inferKmpIosScheme(options.project) + " -sdk iphoneos -configuration Debug -destination \"id=<xcode-device-udid>\" -derivedDataPath /private/tmp/hap-kmp-ios-<project> -allowProvisioningUpdates -allowProvisioningDeviceRegistration CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES build")
                    commands.add("xcrun devicectl device install app --device <core-device-id> /private/tmp/hap-kmp-ios-<project>/Build/Products/Debug-iphoneos/<AppName>.app")
                    commands.add("xcrun devicectl device process launch --device <core-device-id> <bundle-id>")
                }
            } else {
                commands.add("./gradlew test --no-daemon -Dkotlin.compiler.execution.strategy=in-process")
                if (options.lint) {
                    commands.add("./gradlew lint --no-daemon -Dkotlin.compiler.execution.strategy=in-process")
                }
            }
        }
    } else if (projectKind == "cangjie") {
        if (action == "build") {
            commands.add("cjpm build")
        } else {
            commands.add("cjpm test")
        }
    }
    commands
}

func hdcPlanCommand(config: HapHarmonyAdapterConfig, suffix: String): String {
    if (config.selectedDeviceTarget.size > 0) {
        return config.hdcPath + " -t " + config.selectedDeviceTarget + " " + suffix
    }
    config.hdcPath + " " + suffix
}

func projectToolchainStatus(projectKind: String, action: String, project: String, target: String, config: HapHarmonyAdapterConfig): String {
    if (projectKind == "harmonyos") {
        if ((action == "build" || action == "test" || action == "dev") && !isProgramResolvable(config.hvigorwPath)) {
            return "missing-harmony-hvigorw"
        }
        if ((action == "dev" || action == "push") && !isProgramResolvable(config.hdcPath)) {
            return "missing-harmony-hdc"
        }
        return "toolchain-ready"
    }
    if (projectKind == "cangjie") {
        if (!isProgramResolvable("cjpm")) {
            return "missing-cangjie-cjpm"
        }
        if (!isProgramResolvable("cjc")) {
            return "missing-cangjie-cjc"
        }
        return "toolchain-ready"
    }
    if (projectKind == "kotlin-multiplatform") {
        if (!hasKmpGradleRunner(project)) {
            return "missing-kmp-gradle-runner"
        }
        if (action == "dev" && !isKmpDesktopTarget(target) && !isProgramResolvable("xcodebuild")) {
            return "missing-ios-xcodebuild"
        }
        if (action == "dev" && !isKmpDesktopTarget(target) && !isProgramResolvable("xcrun")) {
            return "missing-ios-xcrun-devicectl"
        }
        return "toolchain-ready"
    }
    "toolchain-ready"
}

func projectToolchainQuestions(projectKind: String, action: String, project: String, target: String, config: HapHarmonyAdapterConfig): ArrayList<String> {
    let questions = ArrayList<String>()
    if (projectKind == "harmonyos") {
        if ((action == "build" || action == "test" || action == "dev") && !isProgramResolvable(config.hvigorwPath)) {
            questions.add("请提供可执行 hvigorw 路径；可写入 happub.toml 的 hvigorwPath，或设置 HAP_HARMONY_HVIGORW。")
        }
        if ((action == "dev" || action == "push") && !isProgramResolvable(config.hdcPath)) {
            questions.add("请提供可执行 hdc 路径；可写入 happub.toml 的 hdcPath，或设置 HAP_HARMONY_HDC。")
        }
    } else if (projectKind == "cangjie") {
        if (!isProgramResolvable("cjpm")) {
            questions.add("请提供 cjpm 所在路径并放入 PATH；HapCLI 当前按固定 cjpm build/test 调用，不接收任意 shell。")
        }
        if (!isProgramResolvable("cjc")) {
            questions.add("请提供 cjc 所在路径并放入 PATH；用于确认仓颉 SDK 可用。")
        }
    } else if (projectKind == "kotlin-multiplatform") {
        if (!hasKmpGradleRunner(project)) {
            questions.add("请在 KMP 项目根提供 gradlew，或确保 gradle 在 PATH 中；HapCLI 计划使用固定 Gradle task，不接收任意 shell。")
        }
        if (isKmpDesktopTarget(target)) {
            questions.add("KMP Desktop 构建建议使用 JDK17；HapCLI 将运行固定 Compose Desktop Gradle task。")
        } else {
            questions.add("KMP+iOS 构建建议设置 JAVA_HOME=JDK17、KOTLIN_DAEMON_DATA_DIR=/tmp/kotlin-daemon-$USER、KONAN_DATA_DIR=$HOME/.gradle/.konan。")
        }
        if (action == "dev" && !isKmpDesktopTarget(target)) {
            questions.add("iOS 真机部署需要先用 xcodebuild -showdestinations 获取 ECID，并用 xcrun devicectl list devices 获取 CoreDevice id；两者不能混用。")
            questions.add("如果 xcodebuild 报 Device is busy 或 destination timeout，先用 xcrun devicectl device info details --device <core-device-id> 确认设备就绪，等待 10-15 秒后重试。")
        }
    } else if (projectKind == "unknown") {
        questions.add("请在支持的项目根目录运行，或使用 --project 指向 HarmonyOS/Cangjie/iOS/KMP 项目。")
    }
    questions
}

func projectToolchainValidationCommands(projectKind: String, action: String, project: String, target: String, config: HapHarmonyAdapterConfig): ArrayList<String> {
    let commands = ArrayList<String>()
    if (projectKind == "harmonyos") {
        if (action == "build" || action == "test" || action == "dev") {
            commands.add(config.hvigorwPath + " --version")
        }
        if (action == "dev" || action == "push") {
            commands.add(config.hdcPath + " list targets")
        }
        commands.add("hap project detect --project " + configShellPathHint("<project>") + " --platform harmonyos")
    } else if (projectKind == "cangjie") {
        commands.add("cjpm --version")
        commands.add("cjc --version")
        commands.add("hap project detect --project " + configShellPathHint("<project>") + " --platform cangjie")
    } else if (projectKind == "kotlin-multiplatform") {
        commands.add("./gradlew --version")
        commands.add("java -version")
        if (action == "dev" && !isKmpDesktopTarget(target)) {
            commands.add("xcodebuild -version")
            commands.add("xcrun devicectl list devices")
            commands.add("xcrun devicectl device info details --device <core-device-id>")
            commands.add("xcodebuild -showdestinations -project iosApp/iosApp.xcodeproj -scheme " + inferKmpIosScheme(project))
        }
        commands.add("hap project detect --project " + configShellPathHint("<project>") + " --platform kmp")
    }
    commands
}

func appendKmpEnvironmentTemplates(commands: ArrayList<String>, target: String): Unit {
    commands.add("export JAVA_HOME=<jdk17-home>")
    if (isKmpDesktopTarget(target)) {
        return
    }
    commands.add("export KOTLIN_DAEMON_DATA_DIR=/tmp/kotlin-daemon-$USER")
    commands.add("mkdir -p \"$KOTLIN_DAEMON_DATA_DIR\"")
    commands.add("export KONAN_DATA_DIR=$HOME/.gradle/.konan")
}

func kmpGradleBuildCommand(project: String): String {
    if (isKmpComposeAppProject(project)) {
        return "./gradlew :composeApp:compileKotlinJvm :composeApp:compileKotlinIosArm64 :composeApp:linkDebugFrameworkIosArm64 --no-daemon -Dkotlin.compiler.execution.strategy=in-process"
    }
    "./gradlew build --no-daemon -Dkotlin.compiler.execution.strategy=in-process"
}

func kmpDesktopRunCommand(project: String): String {
    if (isKmpComposeAppProject(project)) {
        return "./gradlew :composeApp:run --no-daemon -Dkotlin.compiler.execution.strategy=in-process"
    }
    "./gradlew run --no-daemon -Dkotlin.compiler.execution.strategy=in-process"
}

public func isKmpDesktopTarget(target: String): Bool {
    let value = trimAsciiText(target)
    value == "desktop" || value == "macos" || value == "darwin" || value == "current-os"
}

public func isKmpIosTarget(target: String): Bool {
    let value = trimAsciiText(target)
    value == "ios" || value == "ipados" || value == "iphoneos"
}

func isKmpComposeAppProject(project: String): Bool {
    exists(joinProjectPath(project, "composeApp/build.gradle.kts")) || exists(joinProjectPath(project, "composeApp/src/commonMain"))
}

func inferKmpIosScheme(project: String): String {
    if (exists(joinProjectPath(project, "iosApp/iosApp.xcodeproj/project.pbxproj"))) {
        return "iosApp"
    }
    "<scheme>"
}

func hasKmpGradleRunner(project: String): Bool {
    exists(joinProjectPath(project, "gradlew")) || isProgramResolvable("gradle")
}

func configShellPathHint(value: String): String {
    value
}

func isProgramResolvable(program: String): Bool {
    if (program.size == 0) {
        return false
    }
    if (containsText(program, "/")) {
        return exists(program)
    }
    match (getVariable("PATH")) {
        case Some(pathText) =>
            for (dir in pathText.split(":")) {
                if (dir.size > 0 && exists(trimTrailingSlash(dir) + "/" + program)) {
                    return true
                }
            }
        case None => ()
    }
    false
}

class HapHarmonyAdapterConfig {
    var configPath: String = ""
    var pathSource: String = "fallback-template"
    var hvigorwPath: String = "hvigorw"
    var hdcPath: String = "hdc"
    var nodePath: String = "node"
    var hvigorwJsPath: String = "hvigorw.js"
    var product: String = "default"
    var buildMode: String = "debug"
    var module: String = "Product"
    var artifactPath: String = "$" + "{PROJECT}/Product/build/default/outputs/default/Product-default-signed.hap"
    var bundle: String = "<bundle>"
    var ability: String = "<ability>"
    var deviceProbeOrder: String = "recent-success,ip-history,usb-history,full-scan"
    var deviceProbeMaxHistory: String = "8"
    var deviceProbeFullScan: String = "true"
    var deviceProbeTimeoutSeconds: String = "3"
    var hdcRestartOnTconnTimeout: String = "true"
    var hdcRestartTimeoutSeconds: String = "5"
    var hdcReconnectRetryCount: String = "1"
    var defaultDevice: String = "auto"
    var selectedDeviceAlias: String = ""
    var selectedDeviceTarget: String = ""
    var deviceSelectionStatus: String = "auto"

    init() {}
}

func resolveHarmonyAdapterConfig(options: HapProjectActionOptions): HapHarmonyAdapterConfig {
    let config = HapHarmonyAdapterConfig()
    config.artifactPath = trimTrailingSlash(options.project) + "/Product/build/default/outputs/default/Product-default-signed.hap"
    let configPath = findHarmonyConfigPath(options)
    config.configPath = configPath
    var configText = ""
    if (configPath.size > 0 && exists(configPath)) {
        configText = String.fromUtf8(File.readFrom(configPath))
        config.pathSource = if (options.config.size > 0) { "explicit-config" } else { "config-file" }
        applyHarmonyTomlString(config, configText)
    } else {
        config.pathSource = "env-or-template"
    }
    applyHarmonyEnv(config)
    applyHarmonyDeviceSelection(options, config, configText)
    applyHarmonyProjectInference(options, config)
    if (options.artifact.size > 0) {
        config.artifactPath = options.artifact
    }
    config
}

func findHarmonyConfigPath(options: HapProjectActionOptions): String {
    if (options.config.size > 0) {
        return options.config
    }
    match (getVariable("HOME")) {
        case Some(home) =>
            if (home.size > 0) {
                let homeConfig = trimTrailingSlash(home) + "/.hap/config.toml"
                if (exists(homeConfig)) {
                    return homeConfig
                }
            }
        case None => ()
    }
    let projectConfig = trimTrailingSlash(options.project) + "/.hapData/config.toml"
    if (exists(projectConfig)) {
        return projectConfig
    }
    let happubConfig = trimTrailingSlash(options.project) + "/happub.toml"
    if (exists(happubConfig)) {
        return happubConfig
    }
    ""
}

func applyHarmonyTomlString(config: HapHarmonyAdapterConfig, text: String): Unit {
    config.hvigorwPath = tomlStringOrDefault(text, "hvigorwPath", config.hvigorwPath)
    config.hdcPath = tomlStringOrDefault(text, "hdcPath", config.hdcPath)
    config.nodePath = tomlStringOrDefault(text, "nodePath", config.nodePath)
    config.hvigorwJsPath = tomlStringOrDefault(text, "hvigorwJsPath", config.hvigorwJsPath)
    config.product = tomlStringOrDefault(text, "product", config.product)
    config.buildMode = tomlStringOrDefault(text, "buildMode", config.buildMode)
    config.module = tomlStringOrDefault(text, "module", config.module)
    config.artifactPath = tomlStringOrDefault(text, "artifactPath", config.artifactPath)
    config.bundle = tomlStringOrDefault(text, "bundle", config.bundle)
    config.ability = tomlStringOrDefault(text, "ability", config.ability)
    config.deviceProbeOrder = tomlScalarOrDefault(text, "deviceProbeOrder", config.deviceProbeOrder)
    config.deviceProbeMaxHistory = tomlScalarOrDefault(text, "deviceProbeMaxHistory", config.deviceProbeMaxHistory)
    config.deviceProbeFullScan = tomlScalarOrDefault(text, "deviceProbeFullScan", config.deviceProbeFullScan)
    config.deviceProbeTimeoutSeconds = tomlScalarOrDefault(text, "deviceProbeTimeoutSeconds", config.deviceProbeTimeoutSeconds)
    config.hdcRestartOnTconnTimeout = tomlScalarOrDefault(text, "hdcRestartOnTconnTimeout", config.hdcRestartOnTconnTimeout)
    config.hdcRestartTimeoutSeconds = tomlScalarOrDefault(text, "hdcRestartTimeoutSeconds", config.hdcRestartTimeoutSeconds)
    config.hdcReconnectRetryCount = tomlScalarOrDefault(text, "hdcReconnectRetryCount", config.hdcReconnectRetryCount)
    config.defaultDevice = tomlStringOrDefault(text, "defaultDevice", config.defaultDevice)
}

func applyHarmonyDeviceSelection(options: HapProjectActionOptions, config: HapHarmonyAdapterConfig, text: String): Unit {
    var requested = if (options.device != "auto" && options.device.size > 0) { options.device } else { config.defaultDevice }
    if (requested.size == 0 || requested == "auto") {
        let universalDefault = resolveHapDefaultDeviceAlias(options.project, "harmonyos")
        if (universalDefault.size > 0) {
            requested = universalDefault
        }
    }
    if (requested.size == 0 || requested == "auto") {
        config.deviceSelectionStatus = "auto"
        return
    }
    config.selectedDeviceAlias = requested
    let universalTarget = resolveHapDeviceAlias(options.project, requested, "harmonyos")
    if (universalTarget != requested) {
        config.selectedDeviceTarget = universalTarget
        config.deviceSelectionStatus = "universal-alias-resolved"
        return
    }
    let aliasTarget = tomlSectionStringOrDefault(text, "harmony.deviceAliases", requested, "")
    if (aliasTarget.size > 0) {
        config.selectedDeviceTarget = aliasTarget
        config.deviceSelectionStatus = "alias-resolved"
        return
    }
    config.selectedDeviceTarget = requested
    config.deviceSelectionStatus = "direct-target"
}

func tomlSectionStringOrDefault(text: String, section: String, key: String, fallback: String): String {
    let sectionHeader = "[" + section + "]"
    var inSection = false
    for (line in text.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (startsWithText(trimmed, "[")) {
            inSection = trimmed == sectionHeader
            continue
        }
        if (inSection && startsWithText(trimmed, key + " = \"")) {
            let prefix = key + " = \""
            let rest = substringFrom(trimmed, Int64(prefix.size))
            let end = indexOfText(rest, "\"")
            if (end >= 0) {
                return substringTo(rest, end)
            }
        }
    }
    fallback
}

func applyHarmonyEnv(config: HapHarmonyAdapterConfig): Unit {
    config.hvigorwPath = envOrDefault("HAP_HARMONY_HVIGORW", config.hvigorwPath)
    config.hdcPath = envOrDefault("HAP_HARMONY_HDC", config.hdcPath)
    config.nodePath = envOrDefault("HAP_HARMONY_NODE", config.nodePath)
    config.hvigorwJsPath = envOrDefault("HAP_HARMONY_HVIGORW_JS", config.hvigorwJsPath)
    config.product = envOrDefault("HAP_HARMONY_PRODUCT", config.product)
    config.buildMode = envOrDefault("HAP_HARMONY_BUILD_MODE", config.buildMode)
    config.module = envOrDefault("HAP_HARMONY_MODULE", config.module)
    config.artifactPath = envOrDefault("HAP_HARMONY_ARTIFACT", config.artifactPath)
    config.bundle = envOrDefault("HAP_HARMONY_BUNDLE", config.bundle)
    config.ability = envOrDefault("HAP_HARMONY_ABILITY", config.ability)
    config.deviceProbeOrder = envOrDefault("HAP_HARMONY_DEVICE_PROBE_ORDER", config.deviceProbeOrder)
    config.deviceProbeMaxHistory = envOrDefault("HAP_HARMONY_DEVICE_PROBE_MAX_HISTORY", config.deviceProbeMaxHistory)
    config.deviceProbeFullScan = envOrDefault("HAP_HARMONY_DEVICE_PROBE_FULL_SCAN", config.deviceProbeFullScan)
    config.deviceProbeTimeoutSeconds = envOrDefault("HAP_HARMONY_DEVICE_PROBE_TIMEOUT_SECONDS", config.deviceProbeTimeoutSeconds)
    config.hdcRestartOnTconnTimeout = envOrDefault("HAP_HARMONY_HDC_RESTART_ON_TCONN_TIMEOUT", config.hdcRestartOnTconnTimeout)
    config.hdcRestartTimeoutSeconds = envOrDefault("HAP_HARMONY_HDC_RESTART_TIMEOUT_SECONDS", config.hdcRestartTimeoutSeconds)
    config.hdcReconnectRetryCount = envOrDefault("HAP_HARMONY_HDC_RECONNECT_RETRY_COUNT", config.hdcReconnectRetryCount)
}

func applyHarmonyProjectInference(options: HapProjectActionOptions, config: HapHarmonyAdapterConfig): Unit {
    var inferred = false
    let executionMode = options.localDevAuto || options.executeReviewed
    if (executionMode && config.hvigorwPath == "hvigorw") {
        let macHvigorw = "/Applications/DevTools/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw"
        if (exists(macHvigorw)) {
            config.hvigorwPath = macHvigorw
            inferred = true
        }
    }
    if (executionMode && config.hvigorwJsPath == "hvigorw.js") {
        let macHvigorwJs = "/Applications/DevTools/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js"
        if (exists(macHvigorwJs)) {
            config.hvigorwJsPath = macHvigorwJs
            inferred = true
        }
    }

    let project = trimTrailingSlash(options.project)
    if (config.bundle == "<bundle>" || config.bundle.size == 0) {
        let bundle = inferHarmonyBundle(project)
        if (bundle.size > 0) {
            config.bundle = bundle
            inferred = true
        }
    }
    if (config.ability == "<ability>" || config.ability.size == 0) {
        let ability = inferHarmonyAbility(project, config.module)
        if (ability.size > 0) {
            config.ability = ability
            inferred = true
        }
    }
    if (inferred) {
        if (config.pathSource == "env-or-template") {
            config.pathSource = "project-inference"
        } else {
            config.pathSource = config.pathSource + "+project-inference"
        }
    }
}

func inferHarmonyBundle(project: String): String {
    let appConfig = trimTrailingSlash(project) + "/AppScope/app.json5"
    if (!exists(appConfig)) {
        return ""
    }
    let text = String.fromUtf8(File.readFrom(appConfig))
    extractFlatJsonString(text, "bundleName")
}

func inferHarmonyAbility(project: String, module: String): String {
    let candidates = ArrayList<String>()
    if (module.size > 0) {
        candidates.add(trimTrailingSlash(project) + "/" + module + "/src/main/module.json5")
    }
    candidates.add(trimTrailingSlash(project) + "/Product/src/main/module.json5")
    candidates.add(trimTrailingSlash(project) + "/product/src/main/module.json5")
    candidates.add(trimTrailingSlash(project) + "/entry/src/main/module.json5")
    for (candidate in candidates) {
        if (exists(candidate)) {
            let text = String.fromUtf8(File.readFrom(candidate))
            let mainElement = extractFlatJsonString(text, "mainElement")
            if (mainElement.size > 0) {
                return mainElement
            }
            let ability = inferFirstHarmonyAbilityName(text)
            if (ability.size > 0) {
                return ability
            }
        }
    }
    ""
}

func inferFirstHarmonyAbilityName(text: String): String {
    let abilityList = indexOfText(text, "\"abilities\"")
    if (abilityList < 0) {
        return ""
    }
    let rest = substringFrom(text, abilityList)
    extractFlatJsonString(rest, "name")
}

func envOrDefault(name: String, fallback: String): String {
    match (getVariable(name)) {
        case Some(value) =>
            if (value.size > 0) {
                return value
            }
        case None => ()
    }
    fallback
}

func tomlStringOrDefault(text: String, key: String, fallback: String): String {
    let lines = text.split("\n")
    for (line in lines) {
        let trimmed = trimAsciiText(line)
        if (startsWithText(trimmed, key + " = \"")) {
            let prefix = key + " = \""
            let rest = substringFrom(trimmed, Int64(prefix.size))
            let end = indexOfText(rest, "\"")
            if (end >= 0) {
                return substringTo(rest, end)
            }
        }
    }
    fallback
}

func tomlScalarOrDefault(text: String, key: String, fallback: String): String {
    let lines = text.split("\n")
    for (line in lines) {
        let trimmed = trimAsciiText(line)
        let prefix = key + " = "
        if (startsWithText(trimmed, prefix)) {
            let raw = trimAsciiText(substringFrom(trimmed, Int64(prefix.size)))
            if (startsWithText(raw, "\"")) {
                let rest = substringFrom(raw, 1)
                let end = indexOfText(rest, "\"")
                if (end >= 0) {
                    return substringTo(rest, end)
                }
            }
            if (raw.size > 0) {
                return firstTomlScalarToken(raw)
            }
        }
    }
    fallback
}

func firstTomlScalarToken(text: String): String {
    let runes = text.toRuneArray()
    var out = ""
    for (r in runes) {
        if (r == r' ' || r == r'\t' || r == r'#' || r == r'\r' || r == r'\n') {
            return out
        }
        out += r.toString()
    }
    out
}
