package hapcli

import std.fs.{File, exists}

public class HapHarmonyWirelessReceiptTrust {
    public var receiptPath: String = ""
    public var trusted: Bool = false
    public var status: String = "missing-receipt"
    public var target: String = ""
    public var ip: String = ""
    public var port: String = ""
    public var stage: String = ""
    public var message: String = ""

    public init() {}
}

public class HapHarmonyWirelessReadbackOptions {
    public var receipt: String = ""

    public init() {}
}

public func resolveHarmonyWirelessReadbackOptions(commandLine: Array<String>, startIndex: Int64): HapHarmonyWirelessReadbackOptions {
    let options = HapHarmonyWirelessReadbackOptions()
    var i = startIndex
    while (i < commandLine.size) {
        let current = commandLine[i]
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
        i += 1
    }
    options
}

public func inspectHarmonyWirelessReceipt(receiptPath: String): HapHarmonyWirelessReceiptTrust {
    let trust = HapHarmonyWirelessReceiptTrust()
    trust.receiptPath = receiptPath
    if (receiptPath.size == 0) {
        trust.status = "missing-receipt"
        trust.message = "provide --wireless-receipt or --receipt"
        return trust
    }
    if (!exists(receiptPath)) {
        trust.status = "receipt-not-found"
        trust.message = "receipt file does not exist"
        return trust
    }

    let text = String.fromUtf8(File.readFrom(receiptPath))
    trust.target = extractFlatJsonString(text, "target")
    trust.ip = extractFlatJsonString(text, "ip")
    trust.port = extractFlatJsonString(text, "port")
    trust.stage = extractFlatJsonString(text, "stage")

    let schemaOk = containsText(text, "\"schema\":\"happub-hapcli-harmony-wireless-receipt-v0\"") ||
        containsText(text, "\"schema\": \"happub-hapcli-harmony-wireless-receipt-v0\"")
    let okTrue = containsText(text, "\"ok\":true") || containsText(text, "\"ok\": true")
    let usbFirstProof = containsText(text, "\"usbFirstProof\":true") || containsText(text, "\"usbFirstProof\": true")
    let wirelessAction = containsText(text, "\"wirelessReconnectActionTaken\":true") ||
        containsText(text, "\"wirelessReconnectActionTaken\": true")
    let completeStage = trust.stage == "complete"
    let endpointOk = trust.ip.size > 0 && trust.port.size > 0

    trust.trusted = schemaOk && okTrue && usbFirstProof && wirelessAction && completeStage && endpointOk
    trust.status = if (trust.trusted) {
        "trusted-wireless-receipt"
    } else if (!schemaOk) {
        "invalid-schema"
    } else if (!okTrue) {
        "receipt-not-ok"
    } else if (!usbFirstProof) {
        "missing-usb-first-proof"
    } else if (!wirelessAction) {
        "missing-wireless-action-proof"
    } else if (!completeStage) {
        "receipt-not-complete"
    } else {
        "missing-endpoint"
    }
    trust.message = if (trust.trusted) {
        "receipt is eligible for plan-only wireless reconnect templates"
    } else {
        "receipt is not eligible for wireless reconnect planning"
    }
    trust
}

public func renderHarmonyWirelessReadbackJson(options: HapHarmonyWirelessReadbackOptions): String {
    let trust = inspectHarmonyWirelessReceipt(options.receipt)
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-harmony-wireless-readback-v0\",\n")
    out.append("  \"ok\": " + boolJson(trust.trusted) + ",\n")
    out.append("  \"mode\": \"read-only-receipt-readback\",\n")
    out.append("  \"status\": \"" + escapeJson(trust.status) + "\",\n")
    out.append("  \"receipt\": \"" + escapeJson(trust.receiptPath) + "\",\n")
    out.append("  \"trusted\": " + boolJson(trust.trusted) + ",\n")
    out.append("  \"target\": \"" + escapeJson(trust.target) + "\",\n")
    out.append("  \"ip\": \"" + escapeJson(trust.ip) + "\",\n")
    out.append("  \"port\": \"" + escapeJson(trust.port) + "\",\n")
    out.append("  \"stage\": \"" + escapeJson(trust.stage) + "\",\n")
    out.append("  \"wirelessReconnectAllowedForPlan\": " + boolJson(trust.trusted) + ",\n")
    out.append("  \"deviceActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"message\": \"" + escapeJson(trust.message) + "\",\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"readback does not execute hdc\",\n")
    out.append("    \"readback does not prove the device is currently online\",\n")
    out.append("    \"readback only allows plan-only wireless reconnect templates unless a future reviewed executor is added\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func extractFlatJsonString(text: String, key: String): String {
    let spaced = "\"" + key + "\": \""
    let compact = "\"" + key + "\":\""
    let spacedColon = "\"" + key + "\" : \""
    let compactValue = "\"" + key + "\" :\""
    var idx = indexOfText(text, spaced)
    var offset = Int64(spaced.size)
    if (idx < 0) {
        idx = indexOfText(text, compact)
        offset = Int64(compact.size)
    }
    if (idx < 0) {
        idx = indexOfText(text, spacedColon)
        offset = Int64(spacedColon.size)
    }
    if (idx < 0) {
        idx = indexOfText(text, compactValue)
        offset = Int64(compactValue.size)
    }
    if (idx < 0) {
        return ""
    }
    let rest = substringFrom(text, idx + offset)
    let end = indexOfText(rest, "\"")
    if (end < 0) {
        return ""
    }
    substringTo(rest, end)
}
