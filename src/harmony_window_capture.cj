package hapcli

import std.collection.ArrayList
import std.convert.*
import std.fs.{Directory, File, exists}
import std.process.executeWithOutput
import std.time.*

public class HapPrntOptions {
    public var project: String = "."
    public var device: String = "auto"
    public var config: String = ""
    public var hdcPath: String = ""
    public var bundle: String = ""
    public var ability: String = ""
    public var module: String = ""
    public var layoutType: String = "Phone"
    public var ratio: String = ""
    public var width: Int64 = -1
    public var height: Int64 = -1
    public var left: Int64 = 100
    public var top: Int64 = 100
    public var waitMilliseconds: Int64 = 1500
    public var timeoutSeconds: Int64 = 15
    public var outputDir: String = ""
    public var cropper: String = "auto"
    public var plan: Bool = false
    public var parseError: String = ""

    public init() {}
}

public class HapPrntLayout {
    public var ok: Bool = false
    public var status: String = "invalid-layout"
    public var message: String = ""
    public var family: String = ""
    public var variant: String = ""
    public var width: Int64 = 0
    public var height: Int64 = 0
    public var left: Int64 = 0
    public var top: Int64 = 0

    public init() {}
}

public class HapPrntWindowRect {
    public var ok: Bool = false
    public var windowName: String = ""
    public var displayId: Int64 = -1
    public var pid: String = ""
    public var windowId: Int64 = -1
    public var left: Int64 = 0
    public var top: Int64 = 0
    public var width: Int64 = 0
    public var height: Int64 = 0

    public init() {}
}

class HapPrntReceipt {
    var ok: Bool = false
    var status: String = "not-started"
    var message: String = ""
    var project: String = ""
    var device: String = ""
    var bundle: String = ""
    var ability: String = ""
    var module: String = ""
    var requestedLayoutType: String = ""
    var layoutFamily: String = ""
    var layoutVariant: String = ""
    var requestedLeft: Int64 = 0
    var requestedTop: Int64 = 0
    var requestedWidth: Int64 = 0
    var requestedHeight: Int64 = 0
    var windowName: String = ""
    var pid: String = ""
    var windowId: Int64 = -1
    var displayId: Int64 = -1
    var actualLeft: Int64 = 0
    var actualTop: Int64 = 0
    var actualWidth: Int64 = 0
    var actualHeight: Int64 = 0
    var actualMatchesRequested: Bool = false
    var cropper: String = ""
    var displayPath: String = ""
    var screenshotPath: String = ""
    var screenshotSha256: String = ""
    var receiptPath: String = ""
    var executionActionTaken: Bool = false
    var deviceMutationActionTaken: Bool = false
    var wmsVerified: Bool = false
    var displayCaptureTaken: Bool = false
    var cropActionTaken: Bool = false
    var remoteCleanupAttempted: Bool = false
    var remoteCleanupSucceeded: Bool = false
    var remoteCapturePath: String = ""
    let commands: ArrayList<String> = ArrayList<String>()

    init() {}
}

public func resolveHapPrntOptions(commandLine: Array<String>, startIndex: Int64): HapPrntOptions {
    let options = HapPrntOptions()
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
        if (current == "--hdc" && i + 1 < commandLine.size) {
            options.hdcPath = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--hdc=")) {
            options.hdcPath = substringFrom(current, 6)
            i += 1
            continue
        }
        if (current == "--bundle" && i + 1 < commandLine.size) {
            options.bundle = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--bundle=")) {
            options.bundle = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--ability" && i + 1 < commandLine.size) {
            options.ability = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--ability=")) {
            options.ability = substringFrom(current, 10)
            i += 1
            continue
        }
        if (current == "--module" && i + 1 < commandLine.size) {
            options.module = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--module=")) {
            options.module = substringFrom(current, 9)
            i += 1
            continue
        }
        if ((current == "--layoutType" || current == "--layout-type") && i + 1 < commandLine.size) {
            options.layoutType = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--layoutType=")) {
            options.layoutType = substringFrom(current, 13)
            i += 1
            continue
        }
        if (startsWithText(current, "--layout-type=")) {
            options.layoutType = substringFrom(current, 14)
            i += 1
            continue
        }
        if (current == "--ratio" && i + 1 < commandLine.size) {
            options.ratio = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--ratio=")) {
            options.ratio = substringFrom(current, 8)
            i += 1
            continue
        }
        if (current == "--width" && i + 1 < commandLine.size) {
            options.width = parseHapPrntInteger(commandLine[i + 1], -1)
            i += 2
            continue
        }
        if (startsWithText(current, "--width=")) {
            options.width = parseHapPrntInteger(substringFrom(current, 8), -1)
            i += 1
            continue
        }
        if (current == "--height" && i + 1 < commandLine.size) {
            options.height = parseHapPrntInteger(commandLine[i + 1], -1)
            i += 2
            continue
        }
        if (startsWithText(current, "--height=")) {
            options.height = parseHapPrntInteger(substringFrom(current, 9), -1)
            i += 1
            continue
        }
        if (current == "--left" && i + 1 < commandLine.size) {
            options.left = parseHapPrntInteger(commandLine[i + 1], -1)
            i += 2
            continue
        }
        if (startsWithText(current, "--left=")) {
            options.left = parseHapPrntInteger(substringFrom(current, 7), -1)
            i += 1
            continue
        }
        if (current == "--top" && i + 1 < commandLine.size) {
            options.top = parseHapPrntInteger(commandLine[i + 1], -1)
            i += 2
            continue
        }
        if (startsWithText(current, "--top=")) {
            options.top = parseHapPrntInteger(substringFrom(current, 6), -1)
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
        if (current == "--cropper" && i + 1 < commandLine.size) {
            options.cropper = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--cropper=")) {
            options.cropper = substringFrom(current, 10)
            i += 1
            continue
        }
        if (current == "--wait-ms" && i + 1 < commandLine.size) {
            options.waitMilliseconds = parseHapPrntInteger(commandLine[i + 1], -1)
            i += 2
            continue
        }
        if (startsWithText(current, "--wait-ms=")) {
            options.waitMilliseconds = parseHapPrntInteger(substringFrom(current, 10), -1)
            i += 1
            continue
        }
        if (current == "--timeout-seconds" && i + 1 < commandLine.size) {
            options.timeoutSeconds = parseHapPrntInteger(commandLine[i + 1], -1)
            i += 2
            continue
        }
        if (startsWithText(current, "--timeout-seconds=")) {
            options.timeoutSeconds = parseHapPrntInteger(substringFrom(current, 18), -1)
            i += 1
            continue
        }
        if (current == "--plan") {
            options.plan = true
            i += 1
            continue
        }
        options.parseError = "unknown or incomplete prnt option: " + current
        return options
    }
    options
}

public func resolveHapPrntLayout(options: HapPrntOptions): HapPrntLayout {
    let layout = HapPrntLayout()
    layout.left = options.left
    layout.top = options.top
    if (options.parseError.size > 0) {
        layout.message = options.parseError
        return layout
    }
    if (options.left < 0 || options.top < 0) {
        layout.message = "--left and --top must be non-negative integers"
        return layout
    }
    if (options.waitMilliseconds < 0 || options.timeoutSeconds < 1) {
        layout.message = "--wait-ms must be non-negative and --timeout-seconds must be positive"
        return layout
    }
    if (options.cropper != "auto" && options.cropper != "sips" && options.cropper != "magick") {
        layout.message = "--cropper must be auto, sips, or magick"
        return layout
    }

    var family = options.layoutType
    var variant = options.ratio
    let inlineParts = options.layoutType.split("/")
    if (inlineParts.size > 2) {
        layout.message = "--layoutType accepts Family or Family/Variant"
        return layout
    }
    if (inlineParts.size == 2) {
        family = inlineParts[0]
        if (variant.size == 0) {
            variant = inlineParts[1]
        }
    }
    if (family == "phone") { family = "Phone" }
    if (family == "tablet") { family = "Tablet" }
    if (family == "fold" || family == "Fold") {
        family = "Tablet"
        if (variant.size > 0 && !startsWithText(variant, "Fold")) {
            variant = "Fold" + variant
        }
    }
    if (family == "pc") { family = "PC" }
    if (family == "2in1") {
        family = "PC"
        if (variant.size == 0) { variant = "2in1" }
    }
    if (family != "Phone" && family != "Tablet" && family != "PC") {
        layout.message = "unsupported --layoutType family: " + family
        return layout
    }
    if (variant.size == 0) {
        variant = if (family == "Phone") { "16:9" } else if (family == "Tablet") { "3:2" } else { "2in1" }
    }
    if (family == "Tablet") {
        if (variant == "4:3") { variant = "Fold4:3" }
        if (variant == "√2:1" || variant == "sqrt2:1") { variant = "Fold√2:1" }
        if (variant == "Foldsqrt2:1") { variant = "Fold√2:1" }
        if (variant == "1.15:1") { variant = "Fold1.15:1" }
    }

    var presetWidth: Int64 = 0
    var presetHeight: Int64 = 0
    if (family == "Phone" && variant == "16:9") {
        presetWidth = 516
        presetHeight = 918
    } else if (family == "Phone" && variant == "18:9") {
        presetWidth = 516
        presetHeight = 1032
    } else if (family == "Phone" && variant == "21:9") {
        presetWidth = 516
        presetHeight = 1204
    } else if (family == "Tablet" && variant == "Fold4:3") {
        presetWidth = 1200
        presetHeight = 900
    } else if (family == "Tablet" && variant == "Fold√2:1") {
        presetWidth = 1273
        presetHeight = 900
    } else if (family == "Tablet" && variant == "Fold1.15:1") {
        presetWidth = 1035
        presetHeight = 900
    } else if (family == "Tablet" && variant == "16:9") {
        presetWidth = 1600
        presetHeight = 900
    } else if (family == "Tablet" && variant == "3:2") {
        presetWidth = 1350
        presetHeight = 900
    } else if (family == "Tablet" && variant == "7:5") {
        presetWidth = 1260
        presetHeight = 900
    } else if (family == "PC" && variant == "2in1") {
        presetWidth = 1440
        presetHeight = 900
    } else if (family != "PC" || variant != "trible") {
        layout.message = "unsupported layout variant " + family + "/" + variant
        return layout
    }

    let explicitWidth = options.width > 0
    let explicitHeight = options.height > 0
    if (explicitWidth != explicitHeight) {
        layout.message = "--width and --height must be supplied together"
        return layout
    }
    if (family == "PC" && variant == "trible" && !explicitWidth) {
        layout.message = "PC/trible requires explicit --width and --height because the name does not define one canonical ratio"
        return layout
    }
    layout.family = family
    layout.variant = variant
    layout.width = if (explicitWidth) { options.width } else { presetWidth }
    layout.height = if (explicitHeight) { options.height } else { presetHeight }
    layout.ok = layout.width > 0 && layout.height > 0
    layout.status = if (layout.ok) { "layout-ready" } else { "invalid-layout" }
    layout.message = if (layout.ok) { "window geometry resolved" } else { "window geometry must be positive" }
    layout
}

public func parseHapPrntWmsWindow(text: String, pid: String): HapPrntWindowRect {
    let missing = HapPrntWindowRect()
    if (!hapPrntDigitsOnly(pid)) {
        return missing
    }
    var focusId: Int64 = -1
    for (line in splitAsciiLines(text)) {
        let trimmed = trimAsciiText(line)
        if (startsWithText(trimmed, "Focus window:")) {
            focusId = parseHapPrntInteger(trimAsciiText(substringFrom(trimmed, Int64("Focus window:".size))), -1)
        }
    }
    var fallback = HapPrntWindowRect()
    for (line in splitAsciiLines(text)) {
        let words = hapPrntAsciiWords(line)
        if (words.size < 13 || words[2] != pid) {
            continue
        }
        let displayId = parseHapPrntInteger(words[1], -1)
        let windowId = parseHapPrntInteger(words[3], -1)
        let left = parseHapPrntInteger(words[9], -1)
        let top = parseHapPrntInteger(words[10], -1)
        let width = parseHapPrntInteger(words[11], -1)
        let height = parseHapPrntInteger(words[12], -1)
        if (displayId < 0 || windowId < 0 || left < 0 || top < 0 || width < 1 || height < 1) {
            continue
        }
        let candidate = HapPrntWindowRect()
        candidate.ok = true
        candidate.windowName = words[0]
        candidate.displayId = displayId
        candidate.pid = pid
        candidate.windowId = windowId
        candidate.left = left
        candidate.top = top
        candidate.width = width
        candidate.height = height
        if (windowId == focusId) {
            return candidate
        }
        if (!fallback.ok) {
            fallback = candidate
        }
    }
    fallback
}

func parseHapPrntWmsWindowForPids(text: String, pids: ArrayList<String>): HapPrntWindowRect {
    let focusId = hapPrntWmsFocusId(text)
    var fallback = HapPrntWindowRect()
    for (pid in pids) {
        let candidate = parseHapPrntWmsWindow(text, pid)
        if (!candidate.ok) {
            continue
        }
        if (candidate.windowId == focusId) {
            return candidate
        }
        if (!fallback.ok) {
            fallback = candidate
        }
    }
    fallback
}

func hapPrntWmsFocusId(text: String): Int64 {
    for (line in splitAsciiLines(text)) {
        let trimmed = trimAsciiText(line)
        if (startsWithText(trimmed, "Focus window:")) {
            return parseHapPrntInteger(trimAsciiText(substringFrom(trimmed, Int64("Focus window:".size))), -1)
        }
    }
    -1
}

public func renderHapPrntPlanJson(options: HapPrntOptions): String {
    let layout = resolveHapPrntLayout(options)
    let config = resolveHapPrntConfig(options)
    let receipt = baseHapPrntReceipt(options, layout, config)
    if (!layout.ok) {
        receipt.status = "invalid-layout"
        receipt.message = layout.message
        return renderHapPrntReceiptJson(receipt)
    }
    let contractError = hapPrntContractError(config)
    if (contractError.size > 0) {
        receipt.status = "invalid-capture-contract"
        receipt.message = contractError
        return renderHapPrntReceiptJson(receipt)
    }
    appendHapPrntPlanCommands(receipt.commands, config, layout, receipt)
    receipt.ok = true
    receipt.status = "plan-ready"
    receipt.message = "window-first capture plan ready; no command executed"
    renderHapPrntReceiptJson(receipt)
}

public func runHapPrnt(options: HapPrntOptions): String {
    let layout = resolveHapPrntLayout(options)
    let config = resolveHapPrntConfig(options)
    let receipt = baseHapPrntReceipt(options, layout, config)
    if (!layout.ok) {
        receipt.status = "invalid-layout"
        receipt.message = layout.message
        return renderHapPrntReceiptJson(receipt)
    }
    let contractError = hapPrntContractError(config)
    if (contractError.size > 0) {
        receipt.status = "invalid-capture-contract"
        receipt.message = contractError
        return renderHapPrntReceiptJson(receipt)
    }
    if (!isProgramResolvable(config.hdcPath)) {
        receipt.status = "hdc-unavailable"
        receipt.message = "configured hdc executable is unavailable: " + config.hdcPath
        return renderHapPrntReceiptJson(receipt)
    }
    let cropperProgram = resolveHapPrntCropper(options.cropper)
    if (cropperProgram.size == 0) {
        receipt.status = "cropper-unavailable"
        receipt.message = "window-only capture requires /usr/bin/sips or ImageMagick magick"
        return renderHapPrntReceiptJson(receipt)
    }
    receipt.cropper = if (containsText(cropperProgram, "sips")) { "sips" } else { "magick" }
    if (receipt.receiptPath.size == 0) {
        receipt.status = "output-dir-unresolved"
        receipt.message = "capture output directory could not be resolved"
        return renderHapPrntReceiptJson(receipt)
    }
    let outputDir = parentPathText(receipt.receiptPath)
    if (!exists(outputDir)) {
        Directory.create(outputDir, recursive: true)
    }

    receipt.commands.add("hdc-list-targets")
    receipt.executionActionTaken = true
    let (listCode, listOut, listErr) = executeHapDeviceCommandWithTimeout(config.hdcPath, ["list", "targets"], options.timeoutSeconds)
    let listText = String.fromUtf8(listOut) + "\n" + String.fromUtf8(listErr)
    var selectedDeviceReady = listCode == 0 && hdcListTargetsHasExpectedTarget(String.fromUtf8(listOut), config.selectedDeviceTarget)
    if (!selectedDeviceReady && containsText(config.selectedDeviceTarget, ":")) {
        receipt.commands.add("hdc-connect-explicit-target")
        let (connectCode, _, _) = executeHapDeviceCommandWithTimeout(
            config.hdcPath,
            ["tconn", config.selectedDeviceTarget],
            options.timeoutSeconds
        )
        if (connectCode == 0) {
            receipt.commands.add("hdc-list-targets-after-connect")
            let (retryListCode, retryListOut, _) = executeHapDeviceCommandWithTimeout(
                config.hdcPath,
                ["list", "targets"],
                options.timeoutSeconds
            )
            selectedDeviceReady = retryListCode == 0 && hdcListTargetsHasExpectedTarget(String.fromUtf8(retryListOut), config.selectedDeviceTarget)
        }
    }
    if (!selectedDeviceReady) {
        receipt.status = "selected-device-not-ready"
        receipt.message = "selected HDC target was not present in `hdc list targets`: " + config.selectedDeviceTarget + hapPrntCommandDetail(listText)
        return finalizeHapPrntReceipt(receipt, config, options)
    }

    receipt.commands.add("hdc-aa-start-window")
    receipt.deviceMutationActionTaken = true
    let launchArgs = hdcSelectedArgs(config, hapPrntLaunchArgs(config, layout))
    let (launchCode, launchOut, launchErr) = executeHapDeviceCommandWithTimeout(config.hdcPath, launchArgs, options.timeoutSeconds)
    let launchText = String.fromUtf8(launchOut) + "\n" + String.fromUtf8(launchErr)
    if (launchCode != 0 || hdcOutputLooksFailed(launchText)) {
        receipt.status = "window-launch-failed"
        receipt.message = "aa start did not accept the requested window geometry" + hapPrntCommandDetail(launchText)
        return finalizeHapPrntReceipt(receipt, config, options)
    }

    if (options.waitMilliseconds > 0) {
        sleep(Duration.millisecond * options.waitMilliseconds)
    }
    receipt.commands.add("hdc-pidof-bundle")
    let (pidCode, pidOut, pidErr) = executeHapDeviceCommandWithTimeout(
        config.hdcPath,
        hdcSelectedArgs(config, ["shell", "pidof", config.bundle]),
        options.timeoutSeconds
    )
    let pids = hapPrntPidList(String.fromUtf8(pidOut))
    if (pidCode != 0 || pids.size == 0) {
        receipt.status = "bundle-pid-unverified"
        receipt.message = "pidof did not bind the running process to bundle " + config.bundle + hapPrntCommandDetail(String.fromUtf8(pidErr))
        return finalizeHapPrntReceipt(receipt, config, options)
    }
    receipt.pid = pids[0]

    receipt.commands.add("hdc-wms-window-query")
    let (wmsCode, wmsOut, wmsErr) = executeHapDeviceCommandWithTimeout(
        config.hdcPath,
        hdcSelectedArgs(config, ["shell", "hidumper", "-s", "WindowManagerService", "-a", "-a"]),
        options.timeoutSeconds
    )
    if (wmsCode != 0) {
        receipt.status = "wms-query-failed"
        receipt.message = "WindowManagerService query failed" + hapPrntCommandDetail(String.fromUtf8(wmsErr))
        return finalizeHapPrntReceipt(receipt, config, options)
    }
    let wmsText = String.fromUtf8(wmsOut)
    let window = parseHapPrntWmsWindowForPids(wmsText, pids)
    if (!window.ok) {
        receipt.status = "wms-window-unverified"
        receipt.message = "WMS did not expose a positive rectangle for any PID returned by bundle " + config.bundle
        return finalizeHapPrntReceipt(receipt, config, options)
    }
    applyHapPrntActualWindow(receipt, window)
    receipt.wmsVerified = true
    receipt.remoteCapturePath = "/data/local/tmp/hapcli-prnt-" + window.pid + ".jpeg"

    receipt.commands.add("hdc-snapshot-display")
    let (snapshotCode, snapshotOut, snapshotErr) = executeHapDeviceCommandWithTimeout(
        config.hdcPath,
        hdcSelectedArgs(config, ["shell", "snapshot_display", "-i", window.displayId.toString(), "-f", receipt.remoteCapturePath]),
        options.timeoutSeconds
    )
    let snapshotText = String.fromUtf8(snapshotOut) + "\n" + String.fromUtf8(snapshotErr)
    if (snapshotCode != 0 || hdcOutputLooksFailed(snapshotText)) {
        receipt.status = "display-capture-failed"
        receipt.message = "snapshot_display failed for display " + window.displayId.toString() + hapPrntCommandDetail(snapshotText)
        return finalizeHapPrntReceipt(receipt, config, options)
    }
    receipt.displayCaptureTaken = true

    receipt.commands.add("hdc-receive-display")
    let (recvCode, _, recvErr) = executeHapDeviceCommandWithTimeout(
        config.hdcPath,
        hdcSelectedArgs(config, ["file", "recv", receipt.remoteCapturePath, receipt.displayPath]),
        options.timeoutSeconds
    )
    if (recvCode != 0 || !exists(receipt.displayPath)) {
        receipt.status = "display-receive-failed"
        receipt.message = "captured display could not be received locally" + hapPrntCommandDetail(String.fromUtf8(recvErr))
        return finalizeHapPrntReceipt(receipt, config, options)
    }

    receipt.commands.add("crop-wms-window")
    let cropArgs = hapPrntCropArgs(receipt.cropper, receipt.displayPath, receipt.screenshotPath, window)
    let (cropCode, _, cropErr) = executeWithOutput(cropperProgram, cropArgs)
    receipt.cropActionTaken = true
    if (cropCode != 0 || !exists(receipt.screenshotPath)) {
        receipt.status = "window-crop-failed"
        receipt.message = "fixed " + receipt.cropper + " crop failed" + hapPrntCommandDetail(String.fromUtf8(cropErr))
        return finalizeHapPrntReceipt(receipt, config, options)
    }
    receipt.screenshotSha256 = hapPrntFileSha256(receipt.screenshotPath)
    receipt.ok = true
    receipt.status = "window-capture-complete"
    receipt.message = "window was requested first, then verified by PID/WMS before display capture and crop"
    finalizeHapPrntReceipt(receipt, config, options)
}

public func hapPrntExitCode(output: String): Int64 {
    if (containsText(output, "\"ok\": true")) {
        return 0
    }
    if (containsText(output, "\"executionActionTaken\": true")) {
        return 1
    }
    2
}

func resolveHapPrntConfig(options: HapPrntOptions): HapHarmonyAdapterConfig {
    let action = HapProjectActionOptions()
    action.action = "prnt"
    action.project = options.project
    action.device = options.device
    action.config = options.config
    action.localDevAuto = true
    let config = resolveHarmonyAdapterConfig(action)
    if (options.hdcPath.size > 0) { config.hdcPath = options.hdcPath }
    if (options.bundle.size > 0) { config.bundle = options.bundle }
    if (options.ability.size > 0) { config.ability = options.ability }
    if (options.module.size > 0) { config.module = options.module }
    config
}

func hapPrntContractError(config: HapHarmonyAdapterConfig): String {
    if (config.selectedDeviceTarget.size == 0 || config.selectedDeviceTarget == "auto") {
        return "prnt requires --device <target-or-alias> or a configured HarmonyOS default"
    }
    if (config.bundle.size == 0 || config.bundle == "<bundle>") {
        return "prnt requires an inferred/configured --bundle"
    }
    if (config.ability.size == 0 || config.ability == "<ability>") {
        return "prnt requires an inferred/configured --ability"
    }
    if (config.module.size == 0) {
        return "prnt requires an inferred/configured --module"
    }
    ""
}

func baseHapPrntReceipt(options: HapPrntOptions, layout: HapPrntLayout, config: HapHarmonyAdapterConfig): HapPrntReceipt {
    let receipt = HapPrntReceipt()
    receipt.project = options.project
    receipt.device = config.selectedDeviceTarget
    receipt.bundle = config.bundle
    receipt.ability = config.ability
    receipt.module = config.module
    receipt.requestedLayoutType = options.layoutType
    receipt.layoutFamily = layout.family
    receipt.layoutVariant = layout.variant
    receipt.requestedLeft = layout.left
    receipt.requestedTop = layout.top
    receipt.requestedWidth = layout.width
    receipt.requestedHeight = layout.height
    receipt.cropper = options.cropper
    let outputDir = if (options.outputDir.size > 0) {
        trimTrailingSlash(options.outputDir)
    } else {
        trimTrailingSlash(options.project) + "/.hapData/prnt"
    }
    receipt.displayPath = outputDir + "/display.jpeg"
    receipt.screenshotPath = outputDir + "/window.png"
    receipt.receiptPath = outputDir + "/receipt.json"
    receipt
}

func appendHapPrntPlanCommands(
    commands: ArrayList<String>,
    config: HapHarmonyAdapterConfig,
    layout: HapPrntLayout,
    receipt: HapPrntReceipt
): Unit {
    commands.add(hapPrntCommandText(config.hdcPath, ["list", "targets"]))
    if (containsText(config.selectedDeviceTarget, ":")) {
        commands.add(hapPrntCommandText(config.hdcPath, ["tconn", config.selectedDeviceTarget]) + "  # only if the explicit target is absent")
    }
    commands.add(hapPrntCommandText(config.hdcPath, hdcSelectedArgs(config, hapPrntLaunchArgs(config, layout))))
    commands.add("wait " + "<window-settle>")
    commands.add(hapPrntCommandText(config.hdcPath, hdcSelectedArgs(config, ["shell", "pidof", config.bundle])))
    commands.add(hapPrntCommandText(config.hdcPath, hdcSelectedArgs(config, ["shell", "hidumper", "-s", "WindowManagerService", "-a", "-a"])))
    commands.add(hapPrntCommandText(config.hdcPath, hdcSelectedArgs(config, ["shell", "snapshot_display", "-i", "<wms-display-id>", "-f", "/data/local/tmp/hapcli-prnt-<pid>.jpeg"])))
    commands.add(hapPrntCommandText(config.hdcPath, hdcSelectedArgs(config, ["file", "recv", "/data/local/tmp/hapcli-prnt-<pid>.jpeg", receipt.displayPath])))
    commands.add("crop <wms-x> <wms-y> <wms-width> <wms-height> " + receipt.displayPath + " -> " + receipt.screenshotPath)
}

func hapPrntLaunchArgs(config: HapHarmonyAdapterConfig, layout: HapPrntLayout): Array<String> {
    [
        "shell", "aa", "start",
        "-a", config.ability,
        "-b", config.bundle,
        "-m", config.module,
        "--wl", layout.left.toString(),
        "--wt", layout.top.toString(),
        "--ww", layout.width.toString(),
        "--wh", layout.height.toString()
    ]
}

func resolveHapPrntCropper(requested: String): String {
    if (requested == "sips") {
        return if (exists("/usr/bin/sips")) { "/usr/bin/sips" } else if (isProgramResolvable("sips")) { "sips" } else { "" }
    }
    if (requested == "magick") {
        return if (isProgramResolvable("magick")) { "magick" } else { "" }
    }
    if (exists("/usr/bin/sips")) {
        return "/usr/bin/sips"
    }
    if (isProgramResolvable("magick")) {
        return "magick"
    }
    ""
}

func hapPrntCropArgs(cropper: String, input: String, output: String, window: HapPrntWindowRect): Array<String> {
    if (cropper == "sips") {
        return [
            "-c", window.height.toString(), window.width.toString(),
            "--cropOffset", window.top.toString(), window.left.toString(),
            input, "--out", output
        ]
    }
    [
        input,
        "-crop", window.width.toString() + "x" + window.height.toString() + "+" + window.left.toString() + "+" + window.top.toString(),
        "+repage",
        output
    ]
}

func applyHapPrntActualWindow(receipt: HapPrntReceipt, window: HapPrntWindowRect): Unit {
    receipt.windowName = window.windowName
    receipt.pid = window.pid
    receipt.windowId = window.windowId
    receipt.displayId = window.displayId
    receipt.actualLeft = window.left
    receipt.actualTop = window.top
    receipt.actualWidth = window.width
    receipt.actualHeight = window.height
    receipt.actualMatchesRequested =
        receipt.requestedLeft == window.left &&
        receipt.requestedTop == window.top &&
        receipt.requestedWidth == window.width &&
        receipt.requestedHeight == window.height
}

func finalizeHapPrntReceipt(receipt: HapPrntReceipt, config: HapHarmonyAdapterConfig, options: HapPrntOptions): String {
    if (receipt.remoteCapturePath.size > 0) {
        receipt.commands.add("hdc-remove-owned-remote-capture")
        receipt.remoteCleanupAttempted = true
        let (cleanupCode, _, _) = executeHapDeviceCommandWithTimeout(
            config.hdcPath,
            hdcSelectedArgs(config, ["shell", "rm", "-f", receipt.remoteCapturePath]),
            options.timeoutSeconds
        )
        receipt.remoteCleanupSucceeded = cleanupCode == 0
    }
    let json = renderHapPrntReceiptJson(receipt)
    let receiptDir = parentPathText(receipt.receiptPath)
    if (receiptDir.size > 0 && exists(receiptDir)) {
        File.writeTo(receipt.receiptPath, json.toArray())
    }
    json
}

func renderHapPrntReceiptJson(receipt: HapPrntReceipt): String {
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-prnt-receipt-v0\",\n")
    out.append("  \"ok\": " + boolJson(receipt.ok) + ",\n")
    out.append("  \"status\": \"" + escapeJson(receipt.status) + "\",\n")
    out.append("  \"message\": \"" + escapeJson(receipt.message) + "\",\n")
    out.append("  \"project\": \"" + escapeJson(receipt.project) + "\",\n")
    out.append("  \"device\": \"" + escapeJson(receipt.device) + "\",\n")
    out.append("  \"bundle\": \"" + escapeJson(receipt.bundle) + "\",\n")
    out.append("  \"ability\": \"" + escapeJson(receipt.ability) + "\",\n")
    out.append("  \"module\": \"" + escapeJson(receipt.module) + "\",\n")
    out.append("  \"requestedLayoutType\": \"" + escapeJson(receipt.requestedLayoutType) + "\",\n")
    out.append("  \"layoutFamily\": \"" + escapeJson(receipt.layoutFamily) + "\",\n")
    out.append("  \"layoutVariant\": \"" + escapeJson(receipt.layoutVariant) + "\",\n")
    out.append("  \"requestedRect\": {\"left\": " + receipt.requestedLeft.toString() + ", \"top\": " + receipt.requestedTop.toString() + ", \"width\": " + receipt.requestedWidth.toString() + ", \"height\": " + receipt.requestedHeight.toString() + "},\n")
    out.append("  \"actualWindow\": {\"name\": \"" + escapeJson(receipt.windowName) + "\", \"pid\": \"" + escapeJson(receipt.pid) + "\", \"windowId\": " + receipt.windowId.toString() + ", \"displayId\": " + receipt.displayId.toString() + ", \"left\": " + receipt.actualLeft.toString() + ", \"top\": " + receipt.actualTop.toString() + ", \"width\": " + receipt.actualWidth.toString() + ", \"height\": " + receipt.actualHeight.toString() + "},\n")
    out.append("  \"actualMatchesRequested\": " + boolJson(receipt.actualMatchesRequested) + ",\n")
    out.append("  \"cropper\": \"" + escapeJson(receipt.cropper) + "\",\n")
    out.append("  \"displayPath\": \"" + escapeJson(receipt.displayPath) + "\",\n")
    out.append("  \"screenshotPath\": \"" + escapeJson(receipt.screenshotPath) + "\",\n")
    out.append("  \"screenshotSha256\": \"" + escapeJson(receipt.screenshotSha256) + "\",\n")
    out.append("  \"receiptPath\": \"" + escapeJson(receipt.receiptPath) + "\",\n")
    out.append("  \"screenshotScope\": \"wms-rect-crop-of-display\",\n")
    out.append("  \"windowOwnership\": \"" + if (receipt.wmsVerified) { "bundle-pid-wms-bound" } else { "unverified" } + "\",\n")
    out.append("  \"installedArtifactIdentityVerified\": false,\n")
    out.append("  \"visualAcceptance\": false,\n")
    out.append("  \"ownerAcceptance\": false,\n")
    out.append("  \"executionActionTaken\": " + boolJson(receipt.executionActionTaken) + ",\n")
    out.append("  \"deviceMutationActionTaken\": " + boolJson(receipt.deviceMutationActionTaken) + ",\n")
    out.append("  \"wmsVerified\": " + boolJson(receipt.wmsVerified) + ",\n")
    out.append("  \"displayCaptureTaken\": " + boolJson(receipt.displayCaptureTaken) + ",\n")
    out.append("  \"cropActionTaken\": " + boolJson(receipt.cropActionTaken) + ",\n")
    out.append("  \"remoteCleanupAttempted\": " + boolJson(receipt.remoteCleanupAttempted) + ",\n")
    out.append("  \"remoteCleanupSucceeded\": " + boolJson(receipt.remoteCleanupSucceeded) + ",\n")
    out.append("  \"commands\": ")
    appendHapPrntJsonStringArray(out, receipt.commands)
    out.append(",\n")
    out.append("  \"nonClaims\": [\n")
    out.append("    \"aa window parameters require a 2in1 developer-mode device and a debug-signed app\",\n")
    out.append("    \"external display capture can contain windows that occlude the target rectangle\",\n")
    out.append("    \"a cropped screenshot is execution evidence, not visual acceptance or release approval\",\n")
    out.append("    \"requested geometry is not substituted for the actual WMS rectangle\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func appendHapPrntJsonStringArray(out: StringBuilder, values: ArrayList<String>): Unit {
    out.append("[")
    var i: Int64 = 0
    while (i < values.size) {
        out.append("\"" + escapeJson(values[i]) + "\"")
        if (i + 1 < values.size) { out.append(", ") }
        i += 1
    }
    out.append("]")
}

func hapPrntAsciiWords(text: String): ArrayList<String> {
    let out = ArrayList<String>()
    var current = ""
    for (r in text.toRuneArray()) {
        if (r == r' ' || r == r'\t' || r == r'\r' || r == r'\n' || r == r'[' || r == r']') {
            if (current.size > 0) {
                out.add(current)
                current = ""
            }
        } else {
            current += r.toString()
        }
    }
    if (current.size > 0) { out.add(current) }
    out
}

func hapPrntPidList(text: String): ArrayList<String> {
    let out = ArrayList<String>()
    for (word in hapPrntAsciiWords(text)) {
        if (!hapPrntDigitsOnly(word)) {
            continue
        }
        var duplicate = false
        for (current in out) {
            if (current == word) {
                duplicate = true
            }
        }
        if (!duplicate) {
            out.add(word)
        }
    }
    out
}

func hapPrntDigitsOnly(text: String): Bool {
    let runes = trimAsciiText(text).toRuneArray()
    if (runes.size == 0) { return false }
    for (r in runes) {
        if (r < r'0' || r > r'9') { return false }
    }
    true
}

func parseHapPrntInteger(text: String, fallback: Int64): Int64 {
    try {
        Int64.parse(trimAsciiText(text))
    } catch (_: Exception) {
        fallback
    }
}

func hapPrntCommandText(program: String, args: Array<String>): String {
    var out = program
    for (arg in args) {
        out += " " + arg
    }
    out
}

func hapPrntCommandDetail(text: String): String {
    let trimmed = trimAsciiText(text).replace("\n", " | ")
    if (trimmed.size == 0) { "" } else { ": " + trimmed }
}

func hapPrntFileSha256(path: String): String {
    if (!exists(path)) { return "" }
    if (isProgramResolvable("shasum")) {
        let (code, out, _) = executeWithOutput("shasum", ["-a", "256", path])
        if (code == 0) { return firstHapPrntPidOrToken(String.fromUtf8(out)) }
    }
    if (isProgramResolvable("sha256sum")) {
        let (code, out, _) = executeWithOutput("sha256sum", [path])
        if (code == 0) { return firstHapPrntPidOrToken(String.fromUtf8(out)) }
    }
    ""
}

func firstHapPrntPidOrToken(text: String): String {
    let words = hapPrntAsciiWords(text)
    if (words.size > 0) { words[0] } else { "" }
}
