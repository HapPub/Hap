package hapcli

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.process.executeWithOutput

class HapReviewedCommand {
    var label: String = ""
    var program: String = ""
    var args: ArrayList<String> = ArrayList<String>()
    var timeoutSeconds: Int64 = 0
    var expectedTarget: String = ""
    var networkMode: String = "no-proxy"

    init(label: String, program: String) {
        this.label = label
        this.program = program
    }
}

class HapReviewedCommandResult {
    var label: String = ""
    var program: String = ""
    var args: ArrayList<String> = ArrayList<String>()
    var rawExitCode: Int64 = -1
    var exitCode: Int64 = -1
    var semanticStatus: String = "not-run"
    var stdoutLog: String = ""
    var stderrLog: String = ""
    var stdoutBytes: Int64 = 0
    var stderrBytes: Int64 = 0
    var networkMode: String = "no-proxy"
    var timeoutSeconds: Int64 = 0
    var timeoutEnforced: Bool = false

    init(command: HapReviewedCommand) {
        this.label = command.label
        this.program = command.program
        this.args = command.args
        this.networkMode = command.networkMode
        this.timeoutSeconds = command.timeoutSeconds
        this.timeoutEnforced = command.timeoutSeconds > 0 && exists("/bin/sh")
    }
}

class HapAutoWirelessMemoryResult {
    var attempted: Bool = false
    var memoryWritten: Bool = false
    var status: String = "not-attempted"
    var target: String = ""
    var ip: String = ""
    var port: String = "5555"
    var memoryPath: String = ""
    var memoryPathSource: String = ""

    init() {}
}

public func runHarmonyReviewedExecution(options: HapProjectActionOptions): String {
    renderHarmonyReviewedExecutionJson(options, true)
}

public func runHarmonyLocalDevAutoExecution(options: HapProjectActionOptions): String {
    renderHarmonyReviewedExecutionJson(prepareHarmonyLocalDevAutoOptions(options), true)
}

public func renderHarmonyLocalDevProgressText(): String {
    ".... preparing Hap dev\n" +
    ".... checking HarmonyOS device\n" +
    ".... building application\n" +
    ".... installing and launching\n" +
    ".... verifying process"
}

public func renderHarmonyLocalDevSpinnerFrame(tick: Int64, done: Bool, ok: Bool): String {
    renderHarmonyLocalDevSpinnerFrameForStage(tick, done, ok, "preparing Hap dev")
}

public func renderHarmonyLocalDevSpinnerFrameForStage(tick: Int64, done: Bool, ok: Bool, stageLabel: String): String {
    let green = "\u{001B}[0;32m"
    let cyan = "\u{001B}[0;36m"
    let red = "\u{001B}[0;31m"
    let dim = "\u{001B}[2m"
    let reset = "\u{001B}[0m"
    let color = if (done && !ok) { red } else { green }
    let mark = if (done) {
        if (ok) { "✓" } else { "✕" }
    } else {
        harmonyLocalDevSpinnerChar(tick)
    }
    let fill = if (done) { Int64(20) } else { harmonyLocalDevStageFill(stageLabel, tick) }
    let empty = 20 - fill
    let label = if (done) {
        if (ok) { "Hap dev completed" } else { "Hap dev failed" }
    } else {
        harmonyLocalDevSpinnerMessage(stageLabel)
    }
    "\r" + color + mark + reset + " " + cyan + harmonyLocalDevProgressBar(fill, empty, tick, done) + reset + " " + label + dim + "  " + percentText(fill, 20) + reset + "     "
}

func harmonyLocalDevSpinnerChar(tick: Int64): String {
    let index = tick % 10
    if (index == 0) { return "⠋" }
    if (index == 1) { return "⠙" }
    if (index == 2) { return "⠹" }
    if (index == 3) { return "⠸" }
    if (index == 4) { return "⠼" }
    if (index == 5) { return "⠴" }
    if (index == 6) { return "⠦" }
    if (index == 7) { return "⠧" }
    if (index == 8) { return "⠇" }
    "⠏"
}

func harmonyLocalDevSpinnerMessage(stageLabel: String): String {
    let label = trimAsciiText(stageLabel)
    if (label.size > 0) {
        return label
    }
    "preparing Hap dev"
}

func harmonyLocalDevStageFill(stageLabel: String, tick: Int64): Int64 {
    let label = trimAsciiText(stageLabel)
    // Percentages represent observed command stages, not elapsed-time guesses.
    if (tick < 0) {
        return 1
    }
    if (containsText(label, "preparing")) {
        return 1
    }
    if (containsText(label, "reconnecting")) {
        return 2
    }
    if (containsText(label, "checking") || containsText(label, "selecting")) {
        return 4
    }
    if (containsText(label, "building")) {
        return 7
    }
    if (containsText(label, "installing")) {
        return 14
    }
    if (containsText(label, "launching")) {
        return 16
    }
    if (containsText(label, "verifying")) {
        return 18
    }
    if (containsText(label, "refreshing")) {
        return 19
    }
    1
}

func harmonyLocalDevProgressBar(fill: Int64, empty: Int64, tick: Int64, done: Bool): String {
    let out = StringBuilder()
    out.append("[")
    let total = fill + empty
    for (i in 0..total) {
        if (done || i < fill - 1) {
            out.append("⣿")
        } else if (i == fill - 1) {
            out.append(harmonyLocalDevProgressPulseChar(tick))
        } else {
            out.append(" ")
        }
    }
    out.append("]")
    out.toString()
}

func harmonyLocalDevProgressPulseChar(tick: Int64): String {
    let index = tick % 8
    if (index == 0) { return "⠁" }
    if (index == 1) { return "⠃" }
    if (index == 2) { return "⠇" }
    if (index == 3) { return "⠏" }
    if (index == 4) { return "⠟" }
    if (index == 5) { return "⠿" }
    if (index == 6) { return "⡿" }
    "⣿"
}

func percentText(value: Int64, total: Int64): String {
    ((value * 100) / total).toString() + "%"
}

public func renderHarmonyExecutionHumanSummary(json: String): String {
    let ok = containsJsonTrue(json, "ok")
    let status = extractFlatJsonString(json, "status")
    let diagnosis = extractFlatJsonString(json, "diagnosis")
    let failed = extractFlatJsonString(json, "failedCommandLabel")
    let logDir = extractFlatJsonString(json, "logDir")
    let receiptPath = extractFlatJsonString(json, "receiptPath")
    let autoWirelessStatus = extractFlatJsonString(json, "autoWirelessMemoryStatus")
    let autoWirelessIp = extractFlatJsonString(json, "autoWirelessIp")
    let out = StringBuilder()
    if (ok) {
        out.append("Hap dev succeeded\n")
    } else {
        out.append("Hap dev failed\n")
    }
    if (status.size > 0) {
        out.append("Status: " + status + "\n")
    }
    if (failed.size > 0) {
        out.append("Failed step: " + failed + "\n")
    }
    if (diagnosis.size > 0) {
        out.append("Diagnosis: " + diagnosis + "\n")
    }
    if (ok && autoWirelessStatus.size > 0 && autoWirelessStatus != "not-attempted") {
        let suffix = if (autoWirelessIp.size > 0) { " " + autoWirelessIp } else { "" }
        out.append("Wireless memory: " + autoWirelessStatus + suffix + "\n")
    }
    if (!ok && logDir.size > 0) {
        out.append("Logs: " + logDir + "\n")
    }
    if (receiptPath.size > 0) {
        out.append("Receipt: " + receiptPath + "\n")
    }
    if (!ok) {
        let next = firstFlatJsonArrayString(json, "nextManualCommands")
        if (next.size > 0) {
            out.append("Try: " + next + "\n")
        }
        let excerpt = harmonyFailureLogExcerpt(failed, logDir)
        if (excerpt.size > 0) {
            out.append(excerpt + "\n")
        }
    }
    out.append("Use -v or --verbose for the full execution JSON; add --write-receipt for one-shot agent/CI receipt.")
    out.toString()
}

func harmonyFailureLogExcerpt(label: String, logDir: String): String {
    if (label.size == 0 || logDir.size == 0) {
        return ""
    }
    let base = trimTrailingSlash(logDir) + "/" + label
    let stderrPath = base + ".stderr.log"
    if (exists(stderrPath)) {
        let excerpt = compactLogExcerpt(String.fromUtf8(File.readFrom(stderrPath)), 6, 900)
        if (excerpt.size > 0) {
            return "Log excerpt (stderr):\n" + excerpt
        }
    }
    let stdoutPath = base + ".stdout.log"
    if (exists(stdoutPath)) {
        let excerpt = compactLogExcerpt(String.fromUtf8(File.readFrom(stdoutPath)), 6, 900)
        if (excerpt.size > 0) {
            return "Log excerpt (stdout):\n" + excerpt
        }
    }
    ""
}

func compactLogExcerpt(text: String, maxLines: Int64, maxChars: Int64): String {
    let out = StringBuilder()
    let lines = splitAsciiLines(text)
    var usedLines: Int64 = 0
    var usedChars: Int64 = 0
    for (line in lines) {
        var trimmed = trimAsciiText(line)
        if (!looksLikePriorityDiagnosticLogLine(trimmed)) {
            continue
        }
        let errorIndex = indexOfText(trimmed, "Error:")
        if (errorIndex >= 0) {
            trimmed = substringFrom(trimmed, errorIndex)
        }
        if (usedLines >= maxLines || usedChars >= maxChars) {
            break
        }
        var clipped = trimmed
        let remaining = maxChars - usedChars
        if (remaining <= 0) {
            break
        }
        if (Int64(clipped.size) > remaining) {
            clipped = substringTo(clipped, remaining)
        }
        if (usedLines > 0) {
            out.append("\n")
        }
        out.append(clipped)
        usedLines += 1
        usedChars += Int64(clipped.size)
    }
    if (usedLines > 0) {
        return out.toString()
    }
    for (line in lines) {
        var trimmed = trimAsciiText(line)
        if (trimmed.size == 0) {
            continue
        }
        let errorIndex = indexOfText(trimmed, "Error:")
        if (errorIndex >= 0) {
            trimmed = substringFrom(trimmed, errorIndex)
        } else if (Int64(trimmed.size) > 240 && !looksLikeDiagnosticLogLine(trimmed)) {
            continue
        }
        if (usedLines >= maxLines || usedChars >= maxChars) {
            break
        }
        var clipped = trimmed
        let remaining = maxChars - usedChars
        if (remaining <= 0) {
            break
        }
        if (Int64(clipped.size) > remaining) {
            clipped = substringTo(clipped, remaining)
        }
        if (usedLines > 0) {
            out.append("\n")
        }
        out.append(clipped)
        usedLines += 1
        usedChars += Int64(clipped.size)
    }
    out.toString()
}

func looksLikeDiagnosticLogLine(text: String): Bool {
    containsText(text, "Error:") ||
        containsText(text, "FAILED") ||
        containsText(text, "Failed") ||
        containsText(text, "failed") ||
        containsText(text, "Delete ") ||
        containsText(text, "delete ") ||
        containsText(text, ".lock") ||
        containsText(text, "Node.js")
}

func looksLikePriorityDiagnosticLogLine(text: String): Bool {
    startsWithText(text, "Error:") ||
        startsWithText(text, "Node.js") ||
        startsWithText(text, "The registration information") ||
        startsWithText(text, "Delete ") ||
        startsWithText(text, "delete ")
}

public func projectActionExecutionExitCodeFromJson(json: String): Int64 {
    if (containsJsonTrue(json, "ok")) {
        return 0
    }
    if (extractFlatJsonString(json, "status") == "reviewed-execution-failed") {
        return 1
    }
    if (containsJsonFalse(json, "executionActionTaken")) {
        return 2
    }
    1
}

public func renderHarmonyReviewedExecutionJson(options: HapProjectActionOptions, canExecute: Bool): String {
    let candidates = detectProjectCandidates(options.project)
    let selected = selectProjectDetection(candidates, options.platform)
    let selection = resolveProjectSelectionInfo(candidates, options.platform, selected)
    let wirelessTrust = inspectHarmonyWirelessReceipt(options.wirelessReceipt)
    let wirelessGateTrust = resolveHarmonyWirelessGateTrust(options, wirelessTrust)
    let config = resolveHarmonyAdapterConfig(options)
    let interactiveRepair = applyInteractiveToolchainAnswers(selected.projectKind, options.action, options, config)
    let commands = harmonyReviewedCommands(options, config, wirelessGateTrust)
    for (command in commands) {
        command.networkMode = normalizeHapNetworkMode(options.networkMode)
    }
    let receiptPath = options.receipt
    let logDir = resolveHarmonyReviewedLogDir(options)
    let preflightStatus = harmonyReviewedPreflightStatus(options, selection.status, selected.projectKind, config, wirelessGateTrust, canExecute)
    let preflightOk = preflightStatus == "reviewed-execution-ready"
    var executed = false
    var finalExit: Int64 = -1
    let results = ArrayList<HapReviewedCommandResult>()
    let autoWirelessMemory = HapAutoWirelessMemoryResult()

    if (preflightOk) {
        if (!exists(logDir)) {
            Directory.create(logDir, recursive: true)
        }
        if (receiptPath.size > 0) {
            let receiptDir = parentPath(receiptPath)
            if (receiptDir.size > 0 && !exists(receiptDir)) {
                Directory.create(receiptDir, recursive: true)
            }
        }
        for (command in commands) {
            if (shouldSkipReviewedCommandBeforeExecution(options, command, results)) {
                continue
            }
            if (shouldStopBeforeDeploymentBecauseDeviceProbeFailed(options, command, results)) {
                results.add(harmonyInternalFailedCommandResult("harmony-device-probe-not-satisfied", "device-probe-not-satisfied"))
                finalExit = 1
                break
            }
            let result = executeHarmonyReviewedCommand(command, options.project, logDir)
            results.add(result)
            executed = true
            let effectiveResult = executeHdcTconnTimeoutRecovery(options, config, command, result, results, logDir)
            finalExit = effectiveResult.exitCode
            if (effectiveResult.exitCode != 0 && !shouldContinueAfterReviewedCommandFailure(options, effectiveResult)) {
                break
            }
        }
    }

    let ok = preflightOk && executed && finalExit == 0
    if (ok) {
        attemptHarmonyAutoWirelessMemory(options, config, wirelessGateTrust, results, logDir, receiptPath, autoWirelessMemory)
    }
    let status = if (!preflightOk) {
        preflightStatus
    } else if (ok) {
        "reviewed-execution-succeeded"
    } else {
        "reviewed-execution-failed"
    }
    let receiptWritten = preflightOk && receiptPath.size > 0
    let receiptBody = renderHarmonyReviewedReceiptBody(options, selected.projectKind, config, interactiveRepair, wirelessTrust, wirelessGateTrust, autoWirelessMemory, results, receiptPath, logDir, ok, status, executed, finalExit, receiptWritten)
    if (receiptWritten) {
        File.writeTo(receiptPath, receiptBody.toArray())
    }
    receiptBody
}

func harmonyReviewedPreflightStatus(
    options: HapProjectActionOptions,
    selectionStatus: String,
    projectKind: String,
    config: HapHarmonyAdapterConfig,
    wirelessTrust: HapHarmonyWirelessGateTrust,
    canExecute: Bool
): String {
    if (!canExecute) {
        return "execution-disabled"
    }
    if (!options.executeReviewed && !options.localDevAuto) {
        return "execute-reviewed-required"
    }
    if (!options.localDevAuto && options.reviewToken.size == 0) {
        return "missing-review-token"
    }
    if (!options.localDevAuto && options.receipt.size == 0) {
        return "missing-receipt"
    }
    if (selectionStatus != "selected") {
        return selectionStatus
    }
    if (projectKind != "harmonyos") {
        return "harmonyos-project-required"
    }
    if (!supportsProjectAction(projectKind, options.action)) {
        return "action-not-supported-for-adapter"
    }
    if (options.allowWireless && !actionNeedsDevice(options.action)) {
        return "wireless-action-requires-dev-or-push"
    }
    if (options.allowWireless && !wirelessTrust.trusted) {
        return wirelessTrust.status
    }
    if (options.action == "dev" && (config.bundle == "<bundle>" || config.bundle.size == 0 || config.ability == "<ability>" || config.ability.size == 0)) {
        return "missing-harmony-launch-config"
    }
    let toolchainStatus = projectToolchainStatus(projectKind, options.action, options.project, options.target, config)
    if (toolchainStatus != "toolchain-ready") {
        return toolchainStatus
    }
    "reviewed-execution-ready"
}

func harmonyReviewedCommands(
    options: HapProjectActionOptions,
    config: HapHarmonyAdapterConfig,
    wirelessTrust: HapHarmonyWirelessGateTrust
): ArrayList<HapReviewedCommand> {
    let commands = ArrayList<HapReviewedCommand>()
    if (options.action == "build") {
        commands.add(hvigorAssembleCommand(config))
    } else if (options.action == "test") {
        commands.add(simpleCommand("harmony-test", config.hvigorwPath, ["test"]))
        if (options.lint) {
            commands.add(simpleCommand("harmony-lint", config.hvigorwPath, ["lint"]))
        }
    } else if (options.action == "dev") {
        if (options.localDevAuto) {
            appendLocalDevAutoDeviceProbeCommands(commands, options, config)
        } else {
            if (shouldAttemptTrustedWirelessReconnect(options, wirelessTrust)) {
                commands.add(simpleCommandWithTimeout("hdc-trusted-wireless-reconnect", config.hdcPath, ["tconn", wirelessTrust.ip + ":" + wirelessTrust.port], harmonyConfigInt(config.deviceProbeTimeoutSeconds, 3)))
            }
            commands.add(simpleCommandWithTimeout("hdc-list-targets", config.hdcPath, ["list", "targets"], harmonyConfigInt(config.deviceProbeTimeoutSeconds, 3)))
        }
        commands.add(hvigorAssembleCommand(config))
        commands.add(simpleCommand("hdc-install", config.hdcPath, hdcSelectedArgs(config, ["install", "-r", config.artifactPath])))
        commands.add(simpleCommand("hdc-launch", config.hdcPath, hdcSelectedArgs(config, ["shell", "aa", "start", "-b", config.bundle, "-a", config.ability])))
        commands.add(simpleCommand("hdc-verify-pidof", config.hdcPath, hdcSelectedArgs(config, ["shell", "pidof", config.bundle])))
        if (options.listen) {
            commands.add(simpleCommand("hdc-listen", config.hdcPath, hdcSelectedArgs(config, ["hilog"])))
        }
    } else if (options.action == "push") {
        if (shouldAttemptTrustedWirelessReconnect(options, wirelessTrust)) {
            commands.add(simpleCommandWithTimeout("hdc-trusted-wireless-reconnect", config.hdcPath, ["tconn", wirelessTrust.ip + ":" + wirelessTrust.port], harmonyConfigInt(config.deviceProbeTimeoutSeconds, 3)))
        }
        commands.add(simpleCommandWithTimeout("hdc-list-targets", config.hdcPath, ["list", "targets"], harmonyConfigInt(config.deviceProbeTimeoutSeconds, 3)))
        let artifact = if (options.artifact.size > 0) { options.artifact } else { config.artifactPath }
        commands.add(simpleCommand("hdc-install", config.hdcPath, hdcSelectedArgs(config, ["install", "-r", artifact])))
    }
    commands
}

func appendLocalDevAutoDeviceProbeCommands(commands: ArrayList<HapReviewedCommand>, options: HapProjectActionOptions, config: HapHarmonyAdapterConfig): Unit {
    if (config.selectedDeviceTarget.size > 0) {
        if (containsText(config.selectedDeviceTarget, ":")) {
            commands.add(simpleCommandWithTimeout("hdc-trusted-wireless-reconnect", config.hdcPath, ["tconn", config.selectedDeviceTarget], harmonyConfigInt(config.deviceProbeTimeoutSeconds, 3)))
        }
        let selectedList = simpleCommandWithTimeout("hdc-list-targets", config.hdcPath, ["list", "targets"], harmonyConfigInt(config.deviceProbeTimeoutSeconds, 3))
        selectedList.expectedTarget = config.selectedDeviceTarget
        commands.add(selectedList)
        return
    }
    let memoryOptions = HapHarmonyDeviceMemoryOptions()
    memoryOptions.project = options.project
    memoryOptions.memory = options.deviceMemory
    let endpoints = trustedHarmonyDeviceMemoryEndpoints(memoryOptions)
    let order = normalizedHarmonyDeviceProbeOrder(config.deviceProbeOrder)
    let attemptedWirelessKeys = ArrayList<String>()
    var addedWireless: Int64 = 0
    var addedHdcScan = false
    for (probe in order) {
        if (probe == "recent-success") {
            addedWireless = appendLocalDevAutoWirelessEndpointCommands(commands, config, endpoints, 0, 1, addedWireless, attemptedWirelessKeys)
        } else if (probe == "ip-history") {
            let startIndex = if (addedWireless > 0) { Int64(1) } else { Int64(0) }
            addedWireless = appendLocalDevAutoWirelessEndpointCommands(commands, config, endpoints, startIndex, harmonyConfigInt(config.deviceProbeMaxHistory, 8), addedWireless, attemptedWirelessKeys)
        } else if ((probe == "usb-history" || probe == "hdc-scan" || probe == "full-scan") && !addedHdcScan && harmonyConfigBool(config.deviceProbeFullScan, true)) {
            commands.add(simpleCommandWithTimeout("hdc-list-targets", config.hdcPath, ["list", "targets"], harmonyConfigInt(config.deviceProbeTimeoutSeconds, 3)))
            addedHdcScan = true
        }
    }
}

func hdcSelectedArgs(config: HapHarmonyAdapterConfig, args: Array<String>): Array<String> {
    if (config.selectedDeviceTarget.size == 0) {
        return args
    }
    let out = ArrayList<String>()
    out.add("-t")
    out.add(config.selectedDeviceTarget)
    for (arg in args) {
        out.add(arg)
    }
    out.toArray()
}

func appendLocalDevAutoWirelessEndpointCommands(
    commands: ArrayList<HapReviewedCommand>,
    config: HapHarmonyAdapterConfig,
    endpoints: ArrayList<HapHarmonyWirelessEndpointMemory>,
    startIndex: Int64,
    maxHistory: Int64,
    alreadyAdded: Int64,
    attemptedWirelessKeys: ArrayList<String>
): Int64 {
    var i: Int64 = 0
    var added = alreadyAdded
    let maxCount = harmonyConfigInt(config.deviceProbeMaxHistory, 8)
    while (i < endpoints.size && added < maxCount) {
        let endpoint = endpoints[i]
        if (i >= startIndex && i < startIndex + maxHistory) {
            let key = harmonyWirelessEndpointAttemptKey(endpoint)
            if (!harmonyStringListContains(attemptedWirelessKeys, key)) {
                attemptedWirelessKeys.add(key)
                let label = if (added == 0) { "hdc-trusted-wireless-reconnect" } else { "hdc-trusted-wireless-reconnect-" + (added + 1).toString() }
                commands.add(simpleCommandWithTimeout(label, config.hdcPath, ["tconn", endpoint.ip + ":" + endpoint.port], harmonyConfigInt(config.deviceProbeTimeoutSeconds, 3)))
                added += 1
            }
        }
        i += 1
    }
    added
}

func harmonyWirelessEndpointAttemptKey(endpoint: HapHarmonyWirelessEndpointMemory): String {
    if (endpoint.target.size > 0) {
        return "target:" + endpoint.target
    }
    "endpoint:" + endpoint.ip + ":" + endpoint.port
}

func harmonyStringListContains(items: ArrayList<String>, value: String): Bool {
    for (item in items) {
        if (item == value) {
            return true
        }
    }
    false
}

func normalizedHarmonyDeviceProbeOrder(value: String): ArrayList<String> {
    let out = ArrayList<String>()
    for (raw in value.split(",")) {
        let token = trimAsciiText(raw)
        if (token == "recent-success" || token == "ip-history" || token == "usb-history" || token == "hdc-scan" || token == "full-scan") {
            out.add(token)
        }
    }
    if (out.size == 0) {
        out.add("recent-success")
        out.add("ip-history")
        out.add("usb-history")
        out.add("full-scan")
    }
    out
}

func shouldAttemptTrustedWirelessReconnect(options: HapProjectActionOptions, wirelessTrust: HapHarmonyWirelessGateTrust): Bool {
    actionNeedsDevice(options.action) && wirelessTrust.trusted && (options.allowWireless || options.localDevAuto)
}

func shouldContinueAfterReviewedCommandFailure(options: HapProjectActionOptions, result: HapReviewedCommandResult): Bool {
    options.localDevAuto && options.action == "dev" && isHarmonyDeviceProbeCommand(result.label)
}

func shouldSkipReviewedCommandBeforeExecution(options: HapProjectActionOptions, command: HapReviewedCommand, results: ArrayList<HapReviewedCommandResult>): Bool {
    if (!options.localDevAuto || options.action != "dev") {
        return false
    }
    if (isHarmonyDeviceProbeCommand(command.label) && reviewedDeviceProbeSatisfied(results)) {
        return true
    }
    false
}

func shouldStopBeforeDeploymentBecauseDeviceProbeFailed(options: HapProjectActionOptions, command: HapReviewedCommand, results: ArrayList<HapReviewedCommandResult>): Bool {
    options.localDevAuto && options.action == "dev" && isHarmonyDeploymentCommand(command.label) && !reviewedDeviceProbeSatisfied(results)
}

func isHarmonyDeploymentCommand(label: String): Bool {
    label == "harmony-assemble-app" ||
        label == "hdc-install" ||
        label == "hdc-launch" ||
        label == "hdc-verify-pidof" ||
        label == "hdc-listen"
}

func reviewedDeviceProbeSatisfied(results: ArrayList<HapReviewedCommandResult>): Bool {
    reviewedSuccessfulResultsContainTrustedWirelessReconnect(results) || reviewedSuccessfulResultsContainLabel(results, "hdc-list-targets")
}

func reviewedDeviceProbeTimeoutEnforced(results: ArrayList<HapReviewedCommandResult>): Bool {
    var sawProbe = false
    for (result in results) {
        if (!isHarmonyDeviceProbeCommand(result.label)) {
            continue
        }
        sawProbe = true
        if (!result.timeoutEnforced) {
            return false
        }
    }
    sawProbe
}

func isHarmonyDeviceProbeCommand(label: String): Bool {
    isTrustedWirelessReconnectLabel(label) || label == "hdc-list-targets"
}

func harmonyInternalFailedCommandResult(label: String, semanticStatus: String): HapReviewedCommandResult {
    let result = HapReviewedCommandResult(HapReviewedCommand(label, "hap-internal"))
    result.rawExitCode = 1
    result.exitCode = 1
    result.semanticStatus = semanticStatus
    result
}

func isTrustedWirelessReconnectLabel(label: String): Bool {
    label == "hdc-trusted-wireless-reconnect" || startsWithText(label, "hdc-trusted-wireless-reconnect-")
}

func executeHdcTconnTimeoutRecovery(
    options: HapProjectActionOptions,
    config: HapHarmonyAdapterConfig,
    command: HapReviewedCommand,
    original: HapReviewedCommandResult,
    results: ArrayList<HapReviewedCommandResult>,
    logDir: String
): HapReviewedCommandResult {
    if (!options.localDevAuto || original.rawExitCode != 124 || !harmonyConfigBool(config.hdcRestartOnTconnTimeout, true) || !isHdcTconnCommand(command)) {
        return original
    }
    let restart = simpleCommandWithTimeout(
        "hdc-server-restart-after-tconn-timeout",
        config.hdcPath,
        ["kill", "-r"],
        harmonyConfigInt(config.hdcRestartTimeoutSeconds, 5)
    )
    restart.networkMode = command.networkMode
    results.add(executeHarmonyReviewedCommand(restart, options.project, logDir))
    var effective = original
    let retryCount = boundedHarmonyReconnectRetryCount(config.hdcReconnectRetryCount)
    var i: Int64 = 0
    while (i < retryCount) {
        let retry = simpleCommandWithTimeout(
            command.label + "-retry-" + (i + 1).toString(),
            command.program,
            command.args.toArray(),
            command.timeoutSeconds
        )
        retry.expectedTarget = command.expectedTarget
        retry.networkMode = command.networkMode
        effective = executeHarmonyReviewedCommand(retry, options.project, logDir)
        results.add(effective)
        if (effective.exitCode == 0) {
            break
        }
        i += 1
    }
    effective
}

func isHdcTconnCommand(command: HapReviewedCommand): Bool {
    command.args.size > 0 && command.args[0] == "tconn"
}

func boundedHarmonyReconnectRetryCount(value: String): Int64 {
    let parsed = harmonyConfigInt(value, 1)
    if (parsed < 0) { Int64(0) } else if (parsed > 3) { Int64(3) } else { parsed }
}

func hvigorAssembleCommand(config: HapHarmonyAdapterConfig): HapReviewedCommand {
    simpleCommand("harmony-assemble-app", config.hvigorwPath, ["assembleApp", "--mode", "project", "-p", "product=" + config.product, "-p", "buildMode=" + config.buildMode])
}

func simpleCommand(label: String, program: String, args: Array<String>): HapReviewedCommand {
    let command = HapReviewedCommand(label, program)
    for (arg in args) {
        command.args.add(arg)
    }
    command
}

func simpleCommandWithTimeout(label: String, program: String, args: Array<String>, timeoutSeconds: Int64): HapReviewedCommand {
    let command = simpleCommand(label, program, args)
    command.timeoutSeconds = timeoutSeconds
    command
}

func executeHarmonyReviewedCommand(command: HapReviewedCommand, project: String, logDir: String): HapReviewedCommandResult {
    let result = HapReviewedCommandResult(command)
    let workingDir = if (project.size > 0) { trimTrailingSlash(project) } else { "." }
    File.writeTo(harmonyCurrentStepPath(logDir), harmonyCommandHumanLabel(command.label).toArray())
    let (exitCode, stdoutBytes, stderrBytes) = executeHarmonyCommandWithTimeout(command, workingDir)
    let stdoutText = String.fromUtf8(stdoutBytes)
    let stderrText = String.fromUtf8(stderrBytes)
    result.rawExitCode = exitCode
    result.semanticStatus = harmonyCommandSemanticStatus(command, exitCode, stdoutText, stderrText)
    result.exitCode = if (result.semanticStatus == "ok") { 0 } else { 1 }
    result.stdoutBytes = Int64(stdoutBytes.size)
    result.stderrBytes = Int64(stderrBytes.size)
    result.stdoutLog = trimTrailingSlash(logDir) + "/" + command.label + ".stdout.log"
    result.stderrLog = trimTrailingSlash(logDir) + "/" + command.label + ".stderr.log"
    File.writeTo(result.stdoutLog, stdoutBytes)
    File.writeTo(result.stderrLog, stderrBytes)
    File.writeTo(harmonyLastStepPath(logDir), harmonyCommandHumanLabel(command.label).toArray())
    result
}

func executeHarmonyCommandWithTimeout(command: HapReviewedCommand, workingDir: String): (Int64, Array<Byte>, Array<Byte>) {
    let networkCommand = resolveHapNetworkCommand(command.networkMode, command.program, command.args.toArray())
    if (command.timeoutSeconds <= 0 || !exists("/bin/sh")) {
        return executeWithOutput(networkCommand.program, networkCommand.args.toArray(), workingDirectory: Path(workingDir))
    }
    let script = "timeout=\"$1\"; shift\n" +
        "cmd=\"$1\"; shift\n" +
        "\"$cmd\" \"$@\" &\n" +
        "pid=$!\n" +
        "elapsed=0\n" +
        "while kill -0 \"$pid\" 2>/dev/null; do\n" +
        "  if [ \"$elapsed\" -ge \"$timeout\" ]; then\n" +
        "    kill \"$pid\" 2>/dev/null\n" +
        "    sleep 1\n" +
        "    kill -9 \"$pid\" 2>/dev/null\n" +
        "    wait \"$pid\" 2>/dev/null\n" +
        "    echo \"hap command timeout after $timeout seconds\" >&2\n" +
        "    exit 124\n" +
        "  fi\n" +
        "  sleep 1\n" +
        "  elapsed=$((elapsed + 1))\n" +
        "done\n" +
        "wait \"$pid\"\n" +
        "exit \"$?\""
    let args = ArrayList<String>()
    args.add("-c")
    args.add(script)
    args.add("hapcli-timeout")
    args.add(command.timeoutSeconds.toString())
    args.add(networkCommand.program)
    for (arg in networkCommand.args) {
        args.add(arg)
    }
    executeWithOutput("/bin/sh", args.toArray(), workingDirectory: Path(workingDir))
}

public func harmonyCurrentStepPath(logDir: String): String {
    trimTrailingSlash(logDir) + "/.hap-current-step"
}

func harmonyLastStepPath(logDir: String): String {
    trimTrailingSlash(logDir) + "/.hap-last-step"
}

public func harmonyCommandHumanLabel(label: String): String {
    if (isTrustedWirelessReconnectLabel(label)) {
        return "reconnecting cached HarmonyOS device"
    }
    if (label == "hdc-server-restart-after-tconn-timeout") {
        return "restarting stalled HDC server"
    }
    if (label == "hdc-list-targets") {
        return "checking HarmonyOS device"
    }
    if (label == "harmony-assemble-app") {
        return "building HarmonyOS application"
    }
    if (label == "hdc-install") {
        return "installing HarmonyOS app"
    }
    if (label == "hdc-launch") {
        return "launching HarmonyOS app"
    }
    if (label == "hdc-verify-pidof") {
        return "verifying HarmonyOS process"
    }
    if (startsWithText(label, "hdc-auto-wireless-")) {
        return "refreshing wireless device memory"
    }
    label
}

func harmonyCommandSemanticStatus(command: HapReviewedCommand, rawExitCode: Int64, stdoutText: String, stderrText: String): String {
    if (rawExitCode != 0) {
        return "raw-exit-nonzero"
    }
    let combined = stdoutText + "\n" + stderrText
    let commandFailure = hdcCommandOutputFailureStatus(command, combined)
    if (commandFailure.size > 0) {
        return commandFailure
    }
    if (hdcOutputLooksFailed(combined)) {
        return "hdc-output-failure"
    }
    if (command.label == "hdc-list-targets") {
        if (!hdcListTargetsHasTarget(stdoutText)) {
            return "hdc-no-targets"
        }
        if (command.expectedTarget.size > 0 && !hdcListTargetsHasExpectedTarget(stdoutText, command.expectedTarget)) {
            return "hdc-selected-target-not-found"
        }
    }
    if (command.label == "hdc-verify-pidof" && !pidofOutputHasPid(stdoutText)) {
        return "pidof-missing-numeric-pid"
    }
    "ok"
}

func hdcCommandOutputFailureStatus(command: HapReviewedCommand, text: String): String {
    if (command.label == "hdc-install") {
        if (containsText(text, "device is unauthorized") ||
            containsText(text, "UDID of your device is configured in the signing profile") ||
            containsText(text, "code:9568423")) {
            return "hdc-install-device-unauthorized"
        }
        if (containsText(text, "failed to install bundle") ||
            containsText(text, "Failed to install the HAP") ||
            containsText(text, "msg:error")) {
            return "hdc-install-failed"
        }
    }
    if (command.label == "hdc-launch" &&
        (containsText(text, "failed to start ability") ||
        containsText(text, "The specified ability does not exist") ||
        containsText(text, "Error Code:"))) {
        return "hdc-launch-failed"
    }
    ""
}

func harmonyConfigBool(value: String, fallback: Bool): Bool {
    let normalized = trimAsciiText(value)
    if (normalized == "true" || normalized == "1" || normalized == "yes" || normalized == "on") {
        return true
    }
    if (normalized == "false" || normalized == "0" || normalized == "no" || normalized == "off") {
        return false
    }
    fallback
}

func harmonyConfigInt(value: String, fallback: Int64): Int64 {
    let trimmed = trimAsciiText(value)
    let runes = trimmed.toRuneArray()
    if (runes.size == 0) {
        return fallback
    }
    var out: Int64 = 0
    for (r in runes) {
        if (r < r'0' || r > r'9') {
            return fallback
        }
        out = out * 10 + digitRuneValue(r)
    }
    if (out < 1) {
        return fallback
    }
    out
}

func digitRuneValue(r: Rune): Int64 {
    if (r == r'0') { return 0 }
    if (r == r'1') { return 1 }
    if (r == r'2') { return 2 }
    if (r == r'3') { return 3 }
    if (r == r'4') { return 4 }
    if (r == r'5') { return 5 }
    if (r == r'6') { return 6 }
    if (r == r'7') { return 7 }
    if (r == r'8') { return 8 }
    9
}

func hdcOutputLooksFailed(text: String): Bool {
    containsText(text, "[Fail]") ||
        containsText(text, "[FAILED]") ||
        containsText(text, "need connect-key") ||
        containsText(text, "Need connect-key") ||
        containsText(text, "No such device") ||
        containsText(text, "no such device") ||
        containsText(text, "device not found") ||
        containsText(text, "Device not found") ||
        containsText(text, "not found device") ||
        containsText(text, "No devices") ||
        containsText(text, "no devices") ||
        containsText(text, "failed to connect") ||
        containsText(text, "Failed to connect")
}

func hdcListTargetsHasTarget(stdoutText: String): Bool {
    let lines = splitAsciiLines(stdoutText)
    for (line in lines) {
        let trimmed = trimAsciiText(line)
        if (trimmed.size == 0) {
            continue
        }
        if (containsText(trimmed, "List of devices") || containsText(trimmed, "list of devices") || containsText(trimmed, "attached")) {
            continue
        }
        if (containsText(trimmed, "[Empty]") || containsText(trimmed, "empty") || containsText(trimmed, "Empty")) {
            continue
        }
        return true
    }
    false
}

func hdcListTargetsHasExpectedTarget(stdoutText: String, expectedTarget: String): Bool {
    for (line in splitAsciiLines(stdoutText)) {
        if (trimAsciiText(line) == expectedTarget) {
            return true
        }
    }
    false
}

func pidofOutputHasPid(stdoutText: String): Bool {
    let trimmed = trimAsciiText(stdoutText)
    if (trimmed.size == 0) {
        return false
    }
    let runes = trimmed.toRuneArray()
    var sawDigit = false
    for (r in runes) {
        if (r >= r'0' && r <= r'9') {
            sawDigit = true
            continue
        }
        if (r == r' ' || r == r'\t' || r == r'\n' || r == r'\r') {
            continue
        }
        return false
    }
    sawDigit
}

func splitAsciiLines(text: String): ArrayList<String> {
    let lines = ArrayList<String>()
    let runes = text.toRuneArray()
    var current = ""
    for (r in runes) {
        if (r == r'\n') {
            lines.add(current)
            current = ""
        } else if (r != r'\r') {
            current += r.toString()
        }
    }
    lines.add(current)
    lines
}

func attemptHarmonyAutoWirelessMemory(
    options: HapProjectActionOptions,
    config: HapHarmonyAdapterConfig,
    wirelessTrust: HapHarmonyWirelessGateTrust,
    results: ArrayList<HapReviewedCommandResult>,
    logDir: String,
    receiptPath: String,
    autoResult: HapAutoWirelessMemoryResult
): Unit {
    if (!options.localDevAuto || options.action != "dev") {
        autoResult.status = "not-local-dev-auto"
        return
    }
    let trustedReconnect = firstSuccessfulTrustedWirelessReconnectResult(results)
    if (wirelessTrust.trusted && trustedReconnect.label.size > 0) {
        autoResult.status = "already-using-trusted-wireless-memory"
        autoResult.target = wirelessTrust.target
        let endpoint = endpointFromTrustedWirelessReconnectResult(trustedReconnect)
        autoResult.ip = endpoint.ip
        autoResult.port = endpoint.port
        autoResult.memoryPath = wirelessTrust.deviceMemoryPath
        return
    }
    let target = firstUsbTargetFromReviewedResults(results)
    if (target.size == 0) {
        autoResult.status = "usb-target-not-detected"
        return
    }
    autoResult.attempted = true
    autoResult.target = target
    let timeoutSeconds = harmonyConfigInt(config.deviceProbeTimeoutSeconds, 3)
    let ifconfigCommand = simpleCommandWithTimeout("hdc-auto-wireless-read-ifconfig", config.hdcPath, ["-t", target, "shell", "ifconfig", "wlan0"], timeoutSeconds)
    ifconfigCommand.networkMode = normalizeHapNetworkMode(options.networkMode)
    let ifconfigResult = executeHarmonyReviewedCommand(ifconfigCommand, options.project, logDir)
    results.add(ifconfigResult)
    var ip = reviewedResultFirstIpv4(ifconfigResult)
    if (ip.size == 0) {
        let ipAddrCommand = simpleCommandWithTimeout("hdc-auto-wireless-read-ip-addr", config.hdcPath, ["-t", target, "shell", "ip", "addr", "show", "wlan0"], timeoutSeconds)
        ipAddrCommand.networkMode = normalizeHapNetworkMode(options.networkMode)
        let ipAddrResult = executeHarmonyReviewedCommand(ipAddrCommand, options.project, logDir)
        results.add(ipAddrResult)
        ip = reviewedResultFirstIpv4(ipAddrResult)
    }
    if (ip.size == 0) {
        autoResult.status = "wireless-ip-not-detected"
        return
    }
    autoResult.ip = ip
    let port = "5555"
    autoResult.port = port
    let tmodeCommand = simpleCommandWithTimeout("hdc-auto-wireless-tmode-port", config.hdcPath, ["-t", target, "tmode", "port", port], timeoutSeconds)
    tmodeCommand.networkMode = normalizeHapNetworkMode(options.networkMode)
    let tmodeResult = executeHarmonyReviewedCommand(tmodeCommand, options.project, logDir)
    results.add(tmodeResult)
    if (tmodeResult.exitCode != 0) {
        autoResult.status = "tmode-port-failed"
        return
    }
    let tconnCommand = simpleCommandWithTimeout("hdc-auto-wireless-tconn", config.hdcPath, ["tconn", ip + ":" + port], timeoutSeconds)
    tconnCommand.networkMode = normalizeHapNetworkMode(options.networkMode)
    let tconnResult = executeHarmonyReviewedCommand(tconnCommand, options.project, logDir)
    results.add(tconnResult)
    let effectiveTconnResult = executeHdcTconnTimeoutRecovery(options, config, tconnCommand, tconnResult, results, logDir)
    if (effectiveTconnResult.exitCode != 0) {
        autoResult.status = "tconn-failed"
        return
    }
    let memoryOptions = HapHarmonyDeviceMemoryOptions()
    memoryOptions.project = options.project
    memoryOptions.memory = options.deviceMemory
    memoryOptions.receipt = receiptPath
    memoryOptions.target = target
    memoryOptions.ip = ip
    memoryOptions.port = port
    memoryOptions.timestamp = "local-dev-auto-usb-proof"
    let writeResult = writeHarmonyDeviceMemory(memoryOptions, options.project, target, ip, port, "dev")
    autoResult.memoryWritten = writeResult.written
    autoResult.memoryPath = writeResult.path
    autoResult.memoryPathSource = writeResult.pathSource
    autoResult.status = if (writeResult.written) { "trusted-device-memory-auto-cached" } else { writeResult.status }
}

func firstUsbTargetFromReviewedResults(results: ArrayList<HapReviewedCommandResult>): String {
    let text = reviewedStdoutTextForLabel(results, "hdc-list-targets")
    let lines = splitAsciiLines(text)
    for (line in lines) {
        let trimmed = trimAsciiText(line)
        if (trimmed.size == 0) {
            continue
        }
        if (containsText(trimmed, "List of devices") || containsText(trimmed, "list of devices") || containsText(trimmed, "attached")) {
            continue
        }
        if (containsText(trimmed, "[Empty]") || containsText(trimmed, "empty") || containsText(trimmed, "Empty")) {
            continue
        }
        if (containsText(trimmed, ":") && containsText(trimmed, ".")) {
            return ""
        }
        return firstAsciiToken(trimmed)
    }
    ""
}

func reviewedStdoutTextForLabel(results: ArrayList<HapReviewedCommandResult>, label: String): String {
    for (result in results) {
        if (result.label == label && result.stdoutLog.size > 0 && exists(result.stdoutLog)) {
            return String.fromUtf8(File.readFrom(result.stdoutLog))
        }
    }
    ""
}

func reviewedResultFirstIpv4(result: HapReviewedCommandResult): String {
    if (result.stdoutLog.size == 0 || !exists(result.stdoutLog)) {
        return ""
    }
    extractFirstIpv4(String.fromUtf8(File.readFrom(result.stdoutLog)))
}

func firstAsciiToken(text: String): String {
    let runes = text.toRuneArray()
    var token = ""
    for (r in runes) {
        if (r == r' ' || r == r'\t' || r == r'\n' || r == r'\r') {
            return token
        }
        token += r.toString()
    }
    token
}

func extractFirstIpv4(text: String): String {
    let runes = text.toRuneArray()
    var current = ""
    for (r in runes) {
        if ((r >= r'0' && r <= r'9') || r == r'.') {
            current += r.toString()
        } else {
            if (looksLikeIpv4(current)) {
                return current
            }
            current = ""
        }
    }
    if (looksLikeIpv4(current)) {
        return current
    }
    ""
}

func looksLikeIpv4(text: String): Bool {
    let trimmed = trimAsciiText(text)
    if (trimmed.size < 7) {
        return false
    }
    let runes = trimmed.toRuneArray()
    var dots: Int64 = 0
    var segmentDigits: Int64 = 0
    for (r in runes) {
        if (r >= r'0' && r <= r'9') {
            segmentDigits += 1
            if (segmentDigits > 3) {
                return false
            }
        } else if (r == r'.') {
            if (segmentDigits == 0) {
                return false
            }
            dots += 1
            segmentDigits = 0
        } else {
            return false
        }
    }
    dots == 3 && segmentDigits > 0
}

func resolveHarmonyReviewedLogDir(options: HapProjectActionOptions): String {
    if (options.logDir.size > 0) {
        return trimTrailingSlash(options.logDir)
    }
    if (options.receipt.size > 0) {
        let receiptDir = parentPath(options.receipt)
        if (receiptDir.size > 0) {
            return receiptDir + "/logs"
        }
    }
    trimTrailingSlash(options.project) + "/.hapData/logs/harmony-reviewed"
}

func renderHarmonyReviewedReceiptBody(
    options: HapProjectActionOptions,
    projectKind: String,
    config: HapHarmonyAdapterConfig,
    interactiveRepair: HapToolchainInteractiveRepair,
    receiptTrust: HapHarmonyWirelessReceiptTrust,
    wirelessTrust: HapHarmonyWirelessGateTrust,
    autoWirelessMemory: HapAutoWirelessMemoryResult,
    results: ArrayList<HapReviewedCommandResult>,
    receiptPath: String,
    logDir: String,
    ok: Bool,
    status: String,
    executed: Bool,
    finalExit: Int64,
    receiptWritten: Bool
): String {
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-harmony-reviewed-execution-receipt-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"reviewed-fixed-harmonyos-adapter-execution\",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"action\": \"" + escapeJson(options.action) + "\",\n")
    out.append("  \"project\": \"" + escapeJson(options.project) + "\",\n")
    out.append("  \"projectKind\": \"" + escapeJson(projectKind) + "\",\n")
    out.append("  \"requestedPlatform\": \"" + escapeJson(options.platform) + "\",\n")
    out.append("  \"config\": \"" + escapeJson(options.config) + "\",\n")
    out.append("  \"harmonyConfigPath\": \"" + escapeJson(config.configPath) + "\",\n")
    out.append("  \"harmonyConfigSource\": \"" + escapeJson(config.pathSource) + "\",\n")
    out.append("  \"deviceProbeOrder\": \"" + escapeJson(config.deviceProbeOrder) + "\",\n")
    out.append("  \"deviceProbeMaxHistory\": \"" + escapeJson(config.deviceProbeMaxHistory) + "\",\n")
    out.append("  \"deviceProbeFullScan\": \"" + escapeJson(config.deviceProbeFullScan) + "\",\n")
    out.append("  \"deviceProbeTimeoutSeconds\": \"" + escapeJson(config.deviceProbeTimeoutSeconds) + "\",\n")
    out.append("  \"networkMode\": \"" + escapeJson(normalizeHapNetworkMode(options.networkMode)) + "\",\n")
    out.append("  \"proxyEnvironmentInherited\": " + boolJson(normalizeHapNetworkMode(options.networkMode) == "proxy") + ",\n")
    out.append("  \"proxyEnvironmentCleared\": " + boolJson(normalizeHapNetworkMode(options.networkMode) == "no-proxy") + ",\n")
    out.append("  \"hdcRestartOnTconnTimeout\": \"" + escapeJson(config.hdcRestartOnTconnTimeout) + "\",\n")
    out.append("  \"hdcRestartTimeoutSeconds\": \"" + escapeJson(config.hdcRestartTimeoutSeconds) + "\",\n")
    out.append("  \"hdcReconnectRetryCount\": \"" + escapeJson(config.hdcReconnectRetryCount) + "\",\n")
    out.append("  \"selectedDeviceAlias\": \"" + escapeJson(config.selectedDeviceAlias) + "\",\n")
    out.append("  \"selectedDeviceTarget\": \"" + escapeJson(config.selectedDeviceTarget) + "\",\n")
    out.append("  \"deviceSelectionStatus\": \"" + escapeJson(config.deviceSelectionStatus) + "\",\n")
    out.append("  \"deviceProbeTimeoutEnforced\": " + boolJson(reviewedDeviceProbeTimeoutEnforced(results)) + ",\n")
    out.append("  \"deviceProbeSatisfied\": " + boolJson(reviewedDeviceProbeSatisfied(results)) + ",\n")
    out.append("  \"toolchainStatus\": \"" + escapeJson(projectToolchainStatus(projectKind, options.action, options.project, options.target, config)) + "\",\n")
    out.append("  \"interactiveToolchainRequested\": " + boolJson(options.interactive || options.toolchainAnswers.size > 0) + ",\n")
    out.append("  \"interactiveRepairStatus\": \"" + escapeJson(interactiveRepair.status) + "\",\n")
    out.append("  \"executionGate\": \"" + escapeJson(harmonyExecutionGate(options)) + "\",\n")
    out.append("  \"localDevAutoRequested\": " + boolJson(options.localDevAuto) + ",\n")
    out.append("  \"reviewTokenPresent\": " + boolJson(options.reviewToken.size > 0) + ",\n")
    out.append("  \"receiptPath\": \"" + escapeJson(receiptPath) + "\",\n")
    out.append("  \"logDir\": \"" + escapeJson(logDir) + "\",\n")
    out.append("  \"executionActionTaken\": " + boolJson(executed) + ",\n")
    out.append("  \"deviceActionTaken\": " + boolJson(reviewedSuccessfulResultsContainAnyLabel(results, ["hdc-install", "hdc-launch", "hdc-verify-pidof"])) + ",\n")
    out.append("  \"networkActionTaken\": " + boolJson(reviewedSuccessfulResultsContainTrustedWirelessReconnect(results) || reviewedSuccessfulResultsContainLabel(results, "hdc-auto-wireless-tconn")) + ",\n")
    out.append("  \"selfCheckActionTaken\": " + boolJson(reviewedSuccessfulResultsContainLabel(results, "hdc-verify-pidof")) + ",\n")
    out.append("  \"failedCommandLabel\": \"" + escapeJson(firstFailedReviewedCommandLabel(results, options)) + "\",\n")
    out.append("  \"diagnosis\": \"" + escapeJson(harmonyExecutionDiagnosis(status, results, options, config)) + "\",\n")
    out.append("  \"workflowMutationActionTaken\": false,\n")
    out.append("  \"memoryMutationActionTaken\": " + boolJson(autoWirelessMemory.memoryWritten) + ",\n")
    out.append("  \"autoWirelessMemoryAttempted\": " + boolJson(autoWirelessMemory.attempted) + ",\n")
    out.append("  \"autoWirelessMemoryWritten\": " + boolJson(autoWirelessMemory.memoryWritten) + ",\n")
    out.append("  \"autoWirelessMemoryStatus\": \"" + escapeJson(autoWirelessMemory.status) + "\",\n")
    out.append("  \"autoWirelessMemoryPath\": \"" + escapeJson(autoWirelessMemory.memoryPath) + "\",\n")
    out.append("  \"autoWirelessMemoryPathSource\": \"" + escapeJson(autoWirelessMemory.memoryPathSource) + "\",\n")
    out.append("  \"autoWirelessTarget\": \"" + escapeJson(autoWirelessMemory.target) + "\",\n")
    out.append("  \"autoWirelessIp\": \"" + escapeJson(autoWirelessMemory.ip) + "\",\n")
    out.append("  \"autoWirelessPort\": \"" + escapeJson(autoWirelessMemory.port) + "\",\n")
    out.append("  \"finalExitCode\": " + finalExit.toString() + ",\n")
    out.append("  \"wirelessReceipt\": \"" + escapeJson(options.wirelessReceipt) + "\",\n")
    out.append("  \"wirelessReceiptStatus\": \"" + escapeJson(receiptTrust.status) + "\",\n")
    out.append("  \"deviceMemory\": \"" + escapeJson(options.deviceMemory) + "\",\n")
    out.append("  \"deviceMemoryPath\": \"" + escapeJson(wirelessTrust.deviceMemoryPath) + "\",\n")
    out.append("  \"deviceMemoryStatus\": \"" + escapeJson(wirelessTrust.deviceMemoryStatus) + "\",\n")
    out.append("  \"deviceMemoryTrusted\": " + boolJson(wirelessTrust.deviceMemoryTrusted) + ",\n")
    out.append("  \"wirelessTrustSource\": \"" + escapeJson(wirelessTrust.source) + "\",\n")
    out.append("  \"trustedWirelessTarget\": \"" + escapeJson(wirelessTrust.target) + "\",\n")
    out.append("  \"trustedWirelessIp\": \"" + escapeJson(wirelessTrust.ip) + "\",\n")
    out.append("  \"trustedWirelessPort\": \"" + escapeJson(wirelessTrust.port) + "\",\n")
    out.append("  \"artifactCandidates\": ")
    appendReviewedJsonStringArray(out, harmonyReviewedArtifactCandidates(options, config))
    out.append(",\n")
    out.append("  \"toolchainQuestions\": ")
    appendReviewedJsonStringArray(out, projectToolchainQuestions(projectKind, options.action, options.project, options.target, config))
    out.append(",\n")
    out.append("  \"toolchainValidationCommands\": ")
    appendReviewedJsonStringArray(out, projectToolchainValidationCommands(projectKind, options.action, options.project, options.target, config))
    out.append(",\n")
    out.append("  \"interactiveToolchainAnswers\": ")
    appendReviewedJsonStringArray(out, interactiveRepair.answers)
    out.append(",\n")
    out.append("  \"interactiveConfigSuggestions\": ")
    appendReviewedJsonStringArray(out, interactiveRepair.configSuggestions)
    out.append(",\n")
    out.append("  \"interactiveEnvSuggestions\": ")
    appendReviewedJsonStringArray(out, interactiveRepair.envSuggestions)
    out.append(",\n")
    out.append("  \"changedPaths\": ")
    appendReviewedJsonStringArray(out, harmonyReviewedChangedPaths(receiptPath, logDir, options, autoWirelessMemory, results, executed, receiptWritten))
    out.append(",\n")
    out.append("  \"commands\": ")
    appendReviewedCommandResults(out, results)
    out.append(",\n")
    out.append("  \"nextManualCommands\": ")
    appendReviewedJsonStringArray(out, harmonyManualFallbackCommands(options, config))
    out.append(",\n")
    out.append("  \"nextAllowed\": [\"inspect receipt and logs\", \"reuse cached trusted device memory for the next local hap dev\", \"refresh USB debug authorization if auto wireless memory cannot be written\"],\n")
    out.append("  \"nonPromises\": [\"does not accept arbitrary shell commands\", \"does not scan the local network\", \"does not mutate workflow files\", \"does not certify release readiness\"]\n")
    out.append("}")
    out.toString()
}

func harmonyExecutionGate(options: HapProjectActionOptions): String {
    if (options.localDevAuto) {
        return "local-dev-auto"
    }
    if (options.executeReviewed) {
        return "explicit-reviewed"
    }
    "plan-or-disabled"
}

func firstFailedReviewedCommandLabel(results: ArrayList<HapReviewedCommandResult>, options: HapProjectActionOptions): String {
    for (result in results) {
        if (result.exitCode != 0 && !isOptionalReviewedCommandFailure(options, result.label)) {
            return result.label
        }
    }
    ""
}

func isOptionalReviewedCommandFailure(options: HapProjectActionOptions, label: String): Bool {
    startsWithText(label, "hdc-auto-wireless-") ||
        (options.localDevAuto && options.action == "dev" && isTrustedWirelessReconnectLabel(label))
}

func harmonyExecutionDiagnosis(status: String, results: ArrayList<HapReviewedCommandResult>, options: HapProjectActionOptions, config: HapHarmonyAdapterConfig): String {
    if (status == "reviewed-execution-succeeded") {
        return "fixed HarmonyOS dev chain completed"
    }
    let failed = firstFailedReviewedCommandLabel(results, options)
    let failedSemanticStatus = reviewedCommandSemanticStatus(results, failed)
    if (failed.size > 0) {
        if (failed == "hdc-list-targets") {
            if (config.selectedDeviceTarget.size > 0) {
                return "selected HarmonyOS device is not connected: " + config.selectedDeviceTarget
            }
            return "no HarmonyOS device target is connected; connect USB/debug authorization or provide trusted wireless device memory before rerunning hap dev"
        }
        if (failed == "harmony-device-probe-not-satisfied") {
            return "HarmonyOS device probe did not find a usable target; build/install/launch were skipped"
        }
        if (isTrustedWirelessReconnectLabel(failed)) {
            return "trusted wireless reconnect failed; refresh USB-first wireless proof before rerunning hap dev"
        }
        if (failedSemanticStatus == "hdc-install-device-unauthorized") {
            return "the HAP signing profile does not authorize selected device " + config.selectedDeviceTarget + "; refresh the HarmonyOS signing profile/device UDID, rebuild, then rerun hap dev"
        }
        if (failedSemanticStatus == "hdc-install-failed") {
            return "HDC rejected the HAP install on selected device " + config.selectedDeviceTarget + "; inspect the install log before launch"
        }
        if (failedSemanticStatus == "hdc-launch-failed") {
            return "HDC could not launch the configured HarmonyOS bundle/ability; verify installation, bundle, and ability names"
        }
        if (failed == "hdc-verify-pidof") {
            return "HarmonyOS launch self-check failed because pidof did not return a numeric PID"
        }
        return "fixed HarmonyOS dev chain failed at " + failed + "; inspect stdoutLog and stderrLog for that command"
    }
    if (status == "missing-harmony-launch-config") {
        return "set HarmonyOS bundle and ability in happub.toml or Hap config before running hap dev"
    }
    if (status == "harmonyos-project-required") {
        return "hap dev local auto currently supports HarmonyOS projects only; use --plan for read-only diagnosis"
    }
    if (status == "ambiguous-project-platform") {
        return "multiple project types were detected; rerun with --platform harmonyos|cangjie|ios|kmp"
    }
    if (status == "project-not-detected" || status == "requested-platform-not-detected") {
        return "run from a supported project root or pass --project and, if needed, --platform"
    }
    if (startsWithText(status, "missing-harmony-")) {
        return "set the missing HarmonyOS tool path in happub.toml or HAP_HARMONY_* and rerun the validation command"
    }
    if (startsWithText(status, "missing-cangjie-")) {
        return "put the missing Cangjie tool in PATH and rerun cjpm --version / cjc --version"
    }
    status
}

func reviewedCommandSemanticStatus(results: ArrayList<HapReviewedCommandResult>, label: String): String {
    for (result in results) {
        if (result.label == label) {
            return result.semanticStatus
        }
    }
    ""
}

func harmonyManualFallbackCommands(options: HapProjectActionOptions, config: HapHarmonyAdapterConfig): ArrayList<String> {
    let commands = ArrayList<String>()
    if (options.action == "dev") {
        commands.add(config.hdcPath + " list targets")
        commands.add(config.hvigorwPath + " assembleApp --mode project -p product=" + config.product + " -p buildMode=" + config.buildMode)
        commands.add(hdcPlanCommand(config, "install -r " + config.artifactPath))
        commands.add(hdcPlanCommand(config, "shell aa start -b " + config.bundle + " -a " + config.ability))
        commands.add(hdcPlanCommand(config, "shell pidof " + config.bundle))
    }
    commands
}

func harmonyReviewedArtifactCandidates(options: HapProjectActionOptions, config: HapHarmonyAdapterConfig): ArrayList<String> {
    let items = ArrayList<String>()
    if (options.artifact.size > 0) {
        items.add(options.artifact)
    }
    if (options.action == "build" || options.action == "dev" || options.action == "push") {
        items.add(config.artifactPath)
    }
    items
}

func harmonyReviewedChangedPaths(receiptPath: String, logDir: String, options: HapProjectActionOptions, autoWirelessMemory: HapAutoWirelessMemoryResult, results: ArrayList<HapReviewedCommandResult>, executed: Bool, receiptWritten: Bool): ArrayList<String> {
    let items = ArrayList<String>()
    if (receiptWritten && receiptPath.size > 0) {
        items.add(receiptPath)
    }
    if (executed && logDir.size > 0) {
        items.add(logDir)
    }
    if ((options.action == "build" || options.action == "dev") && reviewedResultsContainLabel(results, "harmony-assemble-app")) {
        items.add(trimTrailingSlash(options.project) + "/Product/build")
    }
    if (autoWirelessMemory.memoryWritten && autoWirelessMemory.memoryPath.size > 0) {
        items.add(autoWirelessMemory.memoryPath)
    }
    items
}

func reviewedResultsContainLabel(results: ArrayList<HapReviewedCommandResult>, label: String): Bool {
    for (result in results) {
        if (result.label == label) {
            return true
        }
    }
    false
}

func reviewedSuccessfulResultsContainLabel(results: ArrayList<HapReviewedCommandResult>, label: String): Bool {
    for (result in results) {
        if (result.label == label && result.exitCode == 0) {
            return true
        }
    }
    false
}

func reviewedSuccessfulResultsContainTrustedWirelessReconnect(results: ArrayList<HapReviewedCommandResult>): Bool {
    firstSuccessfulTrustedWirelessReconnectResult(results).label.size > 0
}

func firstSuccessfulTrustedWirelessReconnectResult(results: ArrayList<HapReviewedCommandResult>): HapReviewedCommandResult {
    for (result in results) {
        if (isTrustedWirelessReconnectLabel(result.label) && result.exitCode == 0) {
            return result
        }
    }
    HapReviewedCommandResult(HapReviewedCommand("", ""))
}

func endpointFromTrustedWirelessReconnectResult(result: HapReviewedCommandResult): HapHarmonyWirelessEndpointMemory {
    let endpoint = HapHarmonyWirelessEndpointMemory()
    if (result.args.size > 1) {
        let value = result.args[1]
        let idx = indexOfText(value, ":")
        if (idx >= 0) {
            endpoint.ip = substringTo(value, idx)
            endpoint.port = substringFrom(value, idx + 1)
        } else {
            endpoint.ip = value
        }
    }
    endpoint
}

func reviewedSuccessfulResultsContainAnyLabel(results: ArrayList<HapReviewedCommandResult>, labels: Array<String>): Bool {
    for (label in labels) {
        if (reviewedSuccessfulResultsContainLabel(results, label)) {
            return true
        }
    }
    false
}

func appendReviewedCommandResults(out: StringBuilder, results: ArrayList<HapReviewedCommandResult>): Unit {
    out.append("[")
    var i: Int64 = 0
    while (i < results.size) {
        let result = results[i]
        if (i > 0) {
            out.append(", ")
        }
        out.append("{\"label\":\"" + escapeJson(result.label) + "\",")
        out.append("\"program\":\"" + escapeJson(result.program) + "\",")
        out.append("\"networkMode\":\"" + escapeJson(result.networkMode) + "\",")
        out.append("\"timeoutSeconds\":" + result.timeoutSeconds.toString() + ",")
        out.append("\"timeoutEnforced\":" + boolJson(result.timeoutEnforced) + ",")
        out.append("\"args\":")
        appendReviewedJsonStringArray(out, result.args)
        out.append(",\"rawExitCode\":" + result.rawExitCode.toString() + ",")
        out.append("\"exitCode\":" + result.exitCode.toString() + ",")
        out.append("\"semanticStatus\":\"" + escapeJson(result.semanticStatus) + "\",")
        out.append("\"stdoutLog\":\"" + escapeJson(result.stdoutLog) + "\",")
        out.append("\"stderrLog\":\"" + escapeJson(result.stderrLog) + "\",")
        out.append("\"stdoutBytes\":" + result.stdoutBytes.toString() + ",")
        out.append("\"stderrBytes\":" + result.stderrBytes.toString() + "}")
        i += 1
    }
    out.append("]")
}

func appendReviewedJsonStringArray(out: StringBuilder, items: ArrayList<String>): Unit {
    out.append("[")
    var i: Int64 = 0
    while (i < items.size) {
        if (i > 0) {
            out.append(", ")
        }
        out.append("\"" + escapeJson(items[i]) + "\"")
        i += 1
    }
    out.append("]")
}

func firstFlatJsonArrayString(text: String, key: String): String {
    let spaced = "\"" + key + "\": ["
    let compact = "\"" + key + "\":["
    var idx = indexOfText(text, spaced)
    var offset = Int64(spaced.size)
    if (idx < 0) {
        idx = indexOfText(text, compact)
        offset = Int64(compact.size)
    }
    if (idx < 0) {
        return ""
    }
    let rest = substringFrom(text, idx + offset)
    let firstQuote = indexOfText(rest, "\"")
    if (firstQuote < 0) {
        return ""
    }
    let valueStart = firstQuote + 1
    let valueRest = substringFrom(rest, valueStart)
    let end = indexOfText(valueRest, "\"")
    if (end < 0) {
        return ""
    }
    substringTo(valueRest, end)
}
