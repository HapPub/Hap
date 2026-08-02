package hapcli

import std.collection.ArrayList
import std.convert.*
import std.env.getVariable
import std.fs.{Directory, File, exists}
import std.time.{DateTime, DateTimeFormat}

public class HapHarmonyDeviceMemoryOptions {
    public var action: String = "readback"
    public var project: String = "."
    public var receipt: String = ""
    public var memory: String = ""
    public var reviewToken: String = ""
    public var target: String = ""
    public var ip: String = ""
    public var port: String = ""
    public var staleAfterSeconds: String = "86400"
    public var timestamp: String = "manual-review-time-not-supplied"

    public init() {}
}

public class HapHarmonyDeviceMemoryWriteResult {
    public var path: String = ""
    public var pathSource: String = ""
    public var written: Bool = false
    public var status: String = "not-attempted"

    public init() {}
}

public class HapHarmonyDeviceMemoryTrust {
    public var memoryPath: String = ""
    public var pathSource: String = ""
    public var trusted: Bool = false
    public var status: String = "memory-not-found"
    public var target: String = ""
    public var ip: String = ""
    public var port: String = ""
    public var project: String = ""
    public var projectFingerprint: String = ""
    public var proofReceiptPath: String = ""
    public var promotedAt: String = ""
    public var promotedAtEpochSeconds: String = ""
    public var staleAfterSeconds: String = ""
    public var staleStatus: String = "stale-not-evaluated"

    public init() {}
}

public class HapHarmonyWirelessEndpointMemory {
    public var target: String = ""
    public var ip: String = ""
    public var port: String = ""
    public var project: String = ""
    public var projectFingerprint: String = ""
    public var proofReceiptPath: String = ""
    public var proofAction: String = ""
    public var promotedAt: String = ""
    public var promotedAtEpochSeconds: String = ""
    public var staleAfterSeconds: String = ""

    public init() {}
}

public func resolveHarmonyDeviceMemoryOptions(action: String, commandLine: Array<String>, startIndex: Int64): HapHarmonyDeviceMemoryOptions {
    let options = HapHarmonyDeviceMemoryOptions()
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
        if ((current == "--memory" || current == "--memory-path") && i + 1 < commandLine.size) {
            options.memory = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--memory=")) {
            options.memory = substringFrom(current, 9)
            i += 1
            continue
        }
        if (startsWithText(current, "--memory-path=")) {
            options.memory = substringFrom(current, 14)
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
        if (current == "--ip" && i + 1 < commandLine.size) {
            options.ip = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--ip=")) {
            options.ip = substringFrom(current, 5)
            i += 1
            continue
        }
        if (current == "--port" && i + 1 < commandLine.size) {
            options.port = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--port=")) {
            options.port = substringFrom(current, 7)
            i += 1
            continue
        }
        if (current == "--stale-after-seconds" && i + 1 < commandLine.size) {
            options.staleAfterSeconds = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--stale-after-seconds=")) {
            options.staleAfterSeconds = substringFrom(current, 22)
            i += 1
            continue
        }
        if ((current == "--timestamp" || current == "--promoted-at") && i + 1 < commandLine.size) {
            options.timestamp = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--timestamp=")) {
            options.timestamp = substringFrom(current, 12)
            i += 1
            continue
        }
        if (startsWithText(current, "--promoted-at=")) {
            options.timestamp = substringFrom(current, 14)
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func runHarmonyDeviceMemoryPromote(options: HapHarmonyDeviceMemoryOptions): String {
    let receiptText = if (options.receipt.size > 0 && exists(options.receipt)) { String.fromUtf8(File.readFrom(options.receipt)) } else { "" }
    let schemaOk = containsReviewedExecutionReceiptSchema(receiptText)
    let okTrue = containsJsonTrue(receiptText, "ok")
    let deviceAction = containsJsonTrue(receiptText, "deviceActionTaken")
    let projectKind = extractFlatJsonString(receiptText, "projectKind")
    let action = extractFlatJsonString(receiptText, "action")
    let project = if (options.project.size > 0 && options.project != ".") { options.project } else { extractFlatJsonString(receiptText, "project") }
    let target = if (options.target.size > 0) { options.target } else { extractFlatJsonString(receiptText, "trustedWirelessTarget") }
    let ip = if (options.ip.size > 0) { options.ip } else { extractFlatJsonString(receiptText, "trustedWirelessIp") }
    let port = if (options.port.size > 0) { options.port } else { extractFlatJsonString(receiptText, "trustedWirelessPort") }
    let endpointOk = target.size > 0 && ip.size > 0 && port.size > 0
    let reviewOk = options.reviewToken.size > 0
    let actionOk = action == "dev" || action == "push"
    let canPromote = reviewOk && options.receipt.size > 0 && exists(options.receipt) && schemaOk && okTrue && deviceAction && projectKind == "harmonyos" && actionOk && endpointOk
    let status = harmonyDeviceMemoryPromoteStatus(options, schemaOk, okTrue, deviceAction, projectKind, actionOk, endpointOk, reviewOk)
    let writeResult = if (canPromote) {
        writeHarmonyDeviceMemory(options, project, target, ip, port, action)
    } else {
        let result = HapHarmonyDeviceMemoryWriteResult()
        result.path = resolveHarmonyDeviceMemoryCandidateForRead(options)
        result.pathSource = harmonyDeviceMemoryPathSource(options, result.path)
        result.written = false
        result.status = status
        result
    }
    renderHarmonyDeviceMemoryPromoteJson(options, writeResult, project, target, ip, port, action, status, canPromote)
}

public func renderHarmonyDeviceMemoryReadbackJson(options: HapHarmonyDeviceMemoryOptions): String {
    let trust = inspectHarmonyDeviceMemory(options)
    if (trust.memoryPath.size == 0 || !exists(trust.memoryPath)) {
        return renderHarmonyDeviceMemoryMissingJson(options, trust.memoryPath)
    }
    renderHarmonyDeviceMemoryReadbackBody(
        options,
        trust.memoryPath,
        trust.status,
        trust.trusted,
        trust.target,
        trust.ip,
        trust.port,
        trust.project,
        trust.projectFingerprint,
        trust.proofReceiptPath,
        trust.promotedAt,
        trust.promotedAtEpochSeconds,
        trust.staleAfterSeconds,
        trust.staleStatus
    )
}

public func inspectHarmonyDeviceMemory(options: HapHarmonyDeviceMemoryOptions): HapHarmonyDeviceMemoryTrust {
    let candidates = harmonyDeviceMemoryCandidates(options)
    var firstSeen = HapHarmonyDeviceMemoryTrust()
    var hasSeen = false
    var i: Int64 = 0
    while (i < candidates.size) {
        let candidate = candidates[i]
        if (exists(candidate)) {
            let trust = inspectHarmonyDeviceMemoryAtPath(options, candidate)
            if (!hasSeen) {
                firstSeen = trust
                hasSeen = true
            }
            if (trust.trusted) {
                return trust
            }
        }
        i += 1
    }
    if (hasSeen) {
        return firstSeen
    }
    let trust = HapHarmonyDeviceMemoryTrust()
    let memoryPath = resolveHarmonyDeviceMemoryCandidateForRead(options)
    trust.memoryPath = memoryPath
    trust.pathSource = harmonyDeviceMemoryPathSource(options, memoryPath)
    if (memoryPath.size == 0 || !exists(memoryPath)) {
        trust.status = "memory-not-found"
        return trust
    }
    trust
}

func inspectHarmonyDeviceMemoryAtPath(options: HapHarmonyDeviceMemoryOptions, memoryPath: String): HapHarmonyDeviceMemoryTrust {
    let trust = HapHarmonyDeviceMemoryTrust()
    trust.memoryPath = memoryPath
    trust.pathSource = harmonyDeviceMemoryPathSource(options, memoryPath)
    let text = String.fromUtf8(File.readFrom(memoryPath))
    let schemaOk = containsText(text, "\"schema\":\"happub-hapcli-harmony-device-memory-v0\"") ||
        containsText(text, "\"schema\": \"happub-hapcli-harmony-device-memory-v0\"")
    trust.target = extractFlatJsonString(text, "target")
    trust.ip = extractFlatJsonString(text, "ip")
    trust.port = extractFlatJsonString(text, "port")
    trust.project = extractFlatJsonString(text, "project")
    trust.projectFingerprint = extractFlatJsonString(text, "projectFingerprint")
    trust.proofReceiptPath = extractFlatJsonString(text, "proofReceiptPath")
    trust.promotedAt = extractFlatJsonString(text, "promotedAt")
    trust.promotedAtEpochSeconds = extractFlatJsonString(text, "promotedAtEpochSeconds")
    if (trust.proofReceiptPath.size == 0 && trust.promotedAt == "local-dev-auto-usb-proof") {
        trust.proofReceiptPath = "local-dev-auto-usb-proof"
    }
    trust.staleAfterSeconds = extractFlatJsonString(text, "staleAfterSeconds")
    let endpointOk = trust.target.size > 0 && trust.ip.size > 0 && trust.port.size > 0
    trust.staleStatus = harmonyDeviceMemoryStaleStatus(trust.promotedAt, trust.promotedAtEpochSeconds, trust.staleAfterSeconds)
    trust.trusted = schemaOk && endpointOk && trust.proofReceiptPath.size > 0 && trust.staleStatus == "active-policy"
    trust.status = if (!schemaOk) {
        "invalid-memory-schema"
    } else if (!endpointOk) {
        "missing-endpoint"
    } else if (trust.proofReceiptPath.size == 0) {
        "missing-proof-receipt"
    } else if (trust.staleStatus != "active-policy") {
        "trusted-device-memory-stale"
    } else {
        "trusted-device-memory"
    }
    trust
}

public func trustedHarmonyDeviceMemoryEndpoints(options: HapHarmonyDeviceMemoryOptions): ArrayList<HapHarmonyWirelessEndpointMemory> {
    let endpoints = ArrayList<HapHarmonyWirelessEndpointMemory>()
    let candidates = harmonyDeviceMemoryCandidates(options)
    var i: Int64 = 0
    while (i < candidates.size) {
        let candidate = candidates[i]
        if (exists(candidate)) {
            appendTrustedHarmonyDeviceMemoryEndpointsFromText(endpoints, String.fromUtf8(File.readFrom(candidate)))
        }
        i += 1
    }
    endpoints
}

func appendTrustedHarmonyDeviceMemoryEndpointsFromText(endpoints: ArrayList<HapHarmonyWirelessEndpointMemory>, text: String): Unit {
    let schemaOk = containsText(text, "\"schema\":\"happub-hapcli-harmony-device-memory-v0\"") ||
        containsText(text, "\"schema\": \"happub-hapcli-harmony-device-memory-v0\"")
    if (!schemaOk) {
        return
    }
    appendTrustedHarmonyDeviceMemoryEndpoint(endpoints, harmonyEndpointFromFlatText(text))
    let history = extractFlatJsonArrayText(text, "history")
    if (history.size == 0) {
        return
    }
    var rest = history
    while (true) {
        let start = indexOfText(rest, "{")
        if (start < 0) {
            break
        }
        let afterStart = substringFrom(rest, start)
        let end = indexOfText(afterStart, "}")
        if (end < 0) {
            break
        }
        let objectText = substringTo(afterStart, end + 1)
        appendTrustedHarmonyDeviceMemoryEndpoint(endpoints, harmonyEndpointFromFlatText(objectText))
        rest = substringFrom(afterStart, end + 1)
    }
}

func harmonyEndpointFromFlatText(text: String): HapHarmonyWirelessEndpointMemory {
    let endpoint = HapHarmonyWirelessEndpointMemory()
    endpoint.target = extractFlatJsonString(text, "target")
    endpoint.ip = extractFlatJsonString(text, "ip")
    endpoint.port = extractFlatJsonString(text, "port")
    endpoint.project = extractFlatJsonString(text, "project")
    endpoint.projectFingerprint = extractFlatJsonString(text, "projectFingerprint")
    endpoint.proofReceiptPath = extractFlatJsonString(text, "proofReceiptPath")
    endpoint.proofAction = extractFlatJsonString(text, "proofAction")
    endpoint.promotedAt = extractFlatJsonString(text, "promotedAt")
    endpoint.promotedAtEpochSeconds = extractFlatJsonString(text, "promotedAtEpochSeconds")
    if (endpoint.proofReceiptPath.size == 0 && endpoint.promotedAt == "local-dev-auto-usb-proof") {
        endpoint.proofReceiptPath = "local-dev-auto-usb-proof"
    }
    endpoint.staleAfterSeconds = extractFlatJsonString(text, "staleAfterSeconds")
    endpoint
}

func appendTrustedHarmonyDeviceMemoryEndpoint(endpoints: ArrayList<HapHarmonyWirelessEndpointMemory>, endpoint: HapHarmonyWirelessEndpointMemory): Unit {
    let endpointOk = endpoint.target.size > 0 && endpoint.ip.size > 0 && endpoint.port.size > 0
    let proofOk = endpoint.proofReceiptPath.size > 0
    let staleOk = harmonyDeviceMemoryStaleStatus(endpoint.promotedAt, endpoint.promotedAtEpochSeconds, endpoint.staleAfterSeconds) == "active-policy"
    if (!endpointOk || !proofOk || !staleOk || harmonyEndpointAlreadyListed(endpoints, endpoint)) {
        return
    }
    endpoints.add(endpoint)
}

func harmonyEndpointAlreadyListed(endpoints: ArrayList<HapHarmonyWirelessEndpointMemory>, endpoint: HapHarmonyWirelessEndpointMemory): Bool {
    for (existing in endpoints) {
        if (existing.ip == endpoint.ip && existing.port == endpoint.port) {
            return true
        }
        if (existing.target == endpoint.target && existing.ip == endpoint.ip && existing.port == endpoint.port) {
            return true
        }
    }
    false
}

func extractFlatJsonArrayText(text: String, key: String): String {
    let spaced = "\"" + key + "\": ["
    let compact = "\"" + key + "\":["
    var idx = indexOfText(text, spaced)
    var offset = Int64(spaced.size) - 1
    if (idx < 0) {
        idx = indexOfText(text, compact)
        offset = Int64(compact.size) - 1
    }
    if (idx < 0) {
        return ""
    }
    let rest = substringFrom(text, idx + offset)
    let end = indexOfText(rest, "]")
    if (end < 0) {
        return ""
    }
    substringTo(rest, end + 1)
}

func harmonyDeviceMemoryPromoteStatus(
    options: HapHarmonyDeviceMemoryOptions,
    schemaOk: Bool,
    okTrue: Bool,
    deviceAction: Bool,
    projectKind: String,
    actionOk: Bool,
    endpointOk: Bool,
    reviewOk: Bool
): String {
    if (!reviewOk) {
        return "missing-review-token"
    }
    if (options.receipt.size == 0) {
        return "missing-receipt"
    }
    if (!exists(options.receipt)) {
        return "receipt-not-found"
    }
    if (!schemaOk) {
        return "invalid-receipt-schema"
    }
    if (!okTrue) {
        return "receipt-not-ok"
    }
    if (projectKind != "harmonyos") {
        return "harmonyos-receipt-required"
    }
    if (!actionOk) {
        return "receipt-action-not-promotable"
    }
    if (!deviceAction) {
        return "receipt-not-device-action"
    }
    if (!endpointOk) {
        return "missing-endpoint"
    }
    "trusted-device-memory-promoted"
}

func writeHarmonyDeviceMemory(
    options: HapHarmonyDeviceMemoryOptions,
    project: String,
    target: String,
    ip: String,
    port: String,
    action: String
): HapHarmonyDeviceMemoryWriteResult {
    options.timestamp = resolveHarmonyDevicePromotionTimestamp(options.timestamp)
    let result = HapHarmonyDeviceMemoryWriteResult()
    let candidates = harmonyDeviceMemoryCandidates(options)
    var i: Int64 = 0
    while (i < candidates.size) {
        let candidate = candidates[i]
        let dir = parentPath(candidate)
        try {
            if (dir.size > 0 && !exists(dir)) {
                Directory.create(dir, recursive: true)
            }
            let previousText = if (exists(candidate)) { String.fromUtf8(File.readFrom(candidate)) } else { "" }
            File.writeTo(candidate, renderHarmonyDeviceMemoryFile(options, project, target, ip, port, action, previousText).toArray())
            result.path = candidate
            result.pathSource = harmonyDeviceMemoryPathSource(options, candidate)
            result.written = true
            result.status = "trusted-device-memory-promoted"
            return result
        } catch (_: Exception) {
            result.status = "memory-write-fallback-attempted"
        }
        i += 1
    }
    result.path = if (candidates.size > 0) { candidates[0] } else { "" }
    result.pathSource = harmonyDeviceMemoryPathSource(options, result.path)
    result.written = false
    result.status = "no-writable-memory-path"
    result
}

func renderHarmonyDeviceMemoryFile(
    options: HapHarmonyDeviceMemoryOptions,
    project: String,
    target: String,
    ip: String,
    port: String,
    action: String,
    previousText: String
): String {
    let proofReceiptPath = if (options.receipt.size > 0) { options.receipt } else { "local-dev-auto-usb-proof" }
    let latest = HapHarmonyWirelessEndpointMemory()
    latest.target = target
    latest.ip = ip
    latest.port = port
    latest.project = project
    latest.projectFingerprint = harmonyProjectFingerprint(project)
    latest.proofReceiptPath = proofReceiptPath
    latest.proofAction = action
    latest.promotedAt = options.timestamp
    latest.promotedAtEpochSeconds = harmonyDevicePromotionEpochSeconds(options.timestamp).toString()
    latest.staleAfterSeconds = options.staleAfterSeconds
    let history = ArrayList<HapHarmonyWirelessEndpointMemory>()
    appendTrustedHarmonyDeviceMemoryEndpoint(history, latest)
    appendTrustedHarmonyDeviceMemoryEndpointsFromText(history, previousText)
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-harmony-device-memory-v0\",\n")
    out.append("  \"trusted\": true,\n")
    out.append("  \"project\": \"" + escapeJson(project) + "\",\n")
    out.append("  \"projectFingerprint\": \"" + escapeJson(harmonyProjectFingerprint(project)) + "\",\n")
    out.append("  \"target\": \"" + escapeJson(target) + "\",\n")
    out.append("  \"ip\": \"" + escapeJson(ip) + "\",\n")
    out.append("  \"port\": \"" + escapeJson(port) + "\",\n")
    out.append("  \"proofReceiptPath\": \"" + escapeJson(proofReceiptPath) + "\",\n")
    out.append("  \"proofAction\": \"" + escapeJson(action) + "\",\n")
    out.append("  \"promotedAt\": \"" + escapeJson(options.timestamp) + "\",\n")
    out.append("  \"promotedAtEpochSeconds\": \"" + escapeJson(latest.promotedAtEpochSeconds) + "\",\n")
    out.append("  \"staleAfterSeconds\": \"" + escapeJson(options.staleAfterSeconds) + "\",\n")
    out.append("  \"promotionMode\": \"reviewed-human-final-interpretation\",\n")
    out.append("  \"history\": ")
    appendHarmonyDeviceMemoryHistory(out, history)
    out.append(",\n")
    out.append("  \"nonPromises\": [\"device memory does not prove current device online\", \"device memory does not authorize wireless execution without later reviewed gate\", \"device memory does not mutate workflows\"]\n")
    out.append("}")
    out.toString()
}

func appendHarmonyDeviceMemoryHistory(out: StringBuilder, history: ArrayList<HapHarmonyWirelessEndpointMemory>): Unit {
    out.append("[")
    var i: Int64 = 0
    var emitted: Int64 = 0
    while (i < history.size && emitted < 8) {
        if (emitted > 0) {
            out.append(", ")
        }
        appendHarmonyDeviceMemoryEndpointObject(out, history[i])
        emitted += 1
        i += 1
    }
    out.append("]")
}

func appendHarmonyDeviceMemoryEndpointObject(out: StringBuilder, endpoint: HapHarmonyWirelessEndpointMemory): Unit {
    out.append("{")
    out.append("\"target\":\"" + escapeJson(endpoint.target) + "\",")
    out.append("\"ip\":\"" + escapeJson(endpoint.ip) + "\",")
    out.append("\"port\":\"" + escapeJson(endpoint.port) + "\",")
    out.append("\"project\":\"" + escapeJson(endpoint.project) + "\",")
    out.append("\"projectFingerprint\":\"" + escapeJson(endpoint.projectFingerprint) + "\",")
    out.append("\"proofReceiptPath\":\"" + escapeJson(endpoint.proofReceiptPath) + "\",")
    out.append("\"proofAction\":\"" + escapeJson(endpoint.proofAction) + "\",")
    out.append("\"promotedAt\":\"" + escapeJson(endpoint.promotedAt) + "\",")
    out.append("\"promotedAtEpochSeconds\":\"" + escapeJson(endpoint.promotedAtEpochSeconds) + "\",")
    out.append("\"staleAfterSeconds\":\"" + escapeJson(endpoint.staleAfterSeconds) + "\"")
    out.append("}")
}

func renderHarmonyDeviceMemoryPromoteJson(
    options: HapHarmonyDeviceMemoryOptions,
    writeResult: HapHarmonyDeviceMemoryWriteResult,
    project: String,
    target: String,
    ip: String,
    port: String,
    action: String,
    status: String,
    canPromote: Bool
): String {
    let ok = canPromote && writeResult.written
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-harmony-device-memory-promote-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"reviewed-device-memory-promotion\",\n")
    out.append("  \"status\": \"" + escapeJson(if (ok) { writeResult.status } else { status }) + "\",\n")
    out.append("  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n")
    out.append("  \"memoryPath\": \"" + escapeJson(writeResult.path) + "\",\n")
    out.append("  \"memoryPathSource\": \"" + escapeJson(writeResult.pathSource) + "\",\n")
    out.append("  \"reviewTokenPresent\": " + boolJson(options.reviewToken.size > 0) + ",\n")
    out.append("  \"memoryMutationActionTaken\": " + boolJson(writeResult.written) + ",\n")
    out.append("  \"deviceActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"workflowMutationActionTaken\": false,\n")
    out.append("  \"project\": \"" + escapeJson(project) + "\",\n")
    out.append("  \"projectFingerprint\": \"" + escapeJson(harmonyProjectFingerprint(project)) + "\",\n")
    out.append("  \"proofAction\": \"" + escapeJson(action) + "\",\n")
    out.append("  \"target\": \"" + escapeJson(target) + "\",\n")
    out.append("  \"ip\": \"" + escapeJson(ip) + "\",\n")
    out.append("  \"port\": \"" + escapeJson(port) + "\",\n")
    out.append("  \"promotedAt\": \"" + escapeJson(options.timestamp) + "\",\n")
    out.append("  \"promotedAtEpochSeconds\": \"" + harmonyDevicePromotionEpochSeconds(options.timestamp).toString() + "\",\n")
    out.append("  \"staleAfterSeconds\": \"" + escapeJson(options.staleAfterSeconds) + "\",\n")
    out.append("  \"changedPaths\": ")
    appendDeviceMemoryChangedPaths(out, writeResult)
    out.append(",\n")
    out.append("  \"nextAllowed\": [\"read back device memory\", \"use memory only behind the reviewed wireless execution gate\"],\n")
    out.append("  \"nonPromises\": [\"does not execute hdc\", \"does not prove current device online\", \"does not authorize wireless execution by itself\", \"does not write shell rc or workflow files\"]\n")
    out.append("}")
    out.toString()
}

func renderHarmonyDeviceMemoryReadbackBody(
    options: HapHarmonyDeviceMemoryOptions,
    memoryPath: String,
    status: String,
    trusted: Bool,
    target: String,
    ip: String,
    port: String,
    project: String,
    fingerprint: String,
    proofReceipt: String,
    promotedAt: String,
    promotedAtEpochSeconds: String,
    staleAfterSeconds: String,
    staleStatus: String
): String {
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-harmony-device-memory-readback-v0\",\n")
    out.append("  \"ok\": " + boolJson(trusted) + ",\n")
    out.append("  \"mode\": \"read-only-device-memory-readback\",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"memoryPath\": \"" + escapeJson(memoryPath) + "\",\n")
    out.append("  \"memoryPathSource\": \"" + escapeJson(harmonyDeviceMemoryPathSource(options, memoryPath)) + "\",\n")
    out.append("  \"trusted\": " + boolJson(trusted) + ",\n")
    out.append("  \"target\": \"" + escapeJson(target) + "\",\n")
    out.append("  \"ip\": \"" + escapeJson(ip) + "\",\n")
    out.append("  \"port\": \"" + escapeJson(port) + "\",\n")
    out.append("  \"project\": \"" + escapeJson(project) + "\",\n")
    out.append("  \"projectFingerprint\": \"" + escapeJson(fingerprint) + "\",\n")
    out.append("  \"proofReceiptPath\": \"" + escapeJson(proofReceipt) + "\",\n")
    out.append("  \"promotedAt\": \"" + escapeJson(promotedAt) + "\",\n")
    out.append("  \"promotedAtEpochSeconds\": \"" + escapeJson(promotedAtEpochSeconds) + "\",\n")
    out.append("  \"staleAfterSeconds\": \"" + escapeJson(staleAfterSeconds) + "\",\n")
    out.append("  \"staleStatus\": \"" + escapeJson(staleStatus) + "\",\n")
    out.append("  \"wirelessReconnectAllowedForExecutionGate\": " + boolJson(trusted) + ",\n")
    out.append("  \"deviceActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"nonPromises\": [\"readback does not execute hdc\", \"readback does not prove current device online\", \"readback does not bypass reviewed execution\"]\n")
    out.append("}")
    out.toString()
}

func renderHarmonyDeviceMemoryMissingJson(options: HapHarmonyDeviceMemoryOptions, memoryPath: String): String {
    let path = if (memoryPath.size > 0) { memoryPath } else { resolveHarmonyDeviceMemoryCandidateForRead(options) }
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-harmony-device-memory-readback-v0\",\n")
    out.append("  \"ok\": false,\n")
    out.append("  \"mode\": \"read-only-device-memory-readback\",\n")
    out.append("  \"status\": \"memory-not-found\",\n")
    out.append("  \"memoryPath\": \"" + escapeJson(path) + "\",\n")
    out.append("  \"memoryPathSource\": \"" + escapeJson(harmonyDeviceMemoryPathSource(options, path)) + "\",\n")
    out.append("  \"trusted\": false,\n")
    out.append("  \"wirelessReconnectAllowedForExecutionGate\": false,\n")
    out.append("  \"deviceActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"nonPromises\": [\"readback does not create memory\", \"missing memory does not block plan-only receipt readback\"]\n")
    out.append("}")
    out.toString()
}

func harmonyDeviceMemoryCandidates(options: HapHarmonyDeviceMemoryOptions): Array<String> {
    let items = ArrayList<String>()
    if (options.memory.size > 0) {
        items.add(options.memory)
        return items.toArray()
    }
    match (getHomeForDeviceMemory()) {
        case Some(home) =>
            if (home.size > 0) {
                items.add(trimTrailingSlash(home) + "/.hap/harmony-device-memory.json")
            }
        case None => ()
    }
    let project = if (options.project.size > 0) { trimTrailingSlash(options.project) } else { "." }
    items.add(project + "/.hapData/harmony-device-memory.json")
    items.add(project + "/happub-device-memory.json")
    items.toArray()
}

func resolveHarmonyDeviceMemoryCandidateForRead(options: HapHarmonyDeviceMemoryOptions): String {
    let candidates = harmonyDeviceMemoryCandidates(options)
    var i: Int64 = 0
    while (i < candidates.size) {
        if (exists(candidates[i])) {
            return candidates[i]
        }
        i += 1
    }
    if (candidates.size > 0) {
        return candidates[0]
    }
    ""
}

func harmonyDeviceMemoryPathSource(options: HapHarmonyDeviceMemoryOptions, path: String): String {
    if (options.memory.size > 0) {
        return "explicit-memory"
    }
    match (getHomeForDeviceMemory()) {
        case Some(home) =>
            if (home.size > 0 && path == trimTrailingSlash(home) + "/.hap/harmony-device-memory.json") {
                return "home-private"
            }
        case None => ()
    }
    let project = if (options.project.size > 0) { trimTrailingSlash(options.project) } else { "." }
    if (path == project + "/.hapData/harmony-device-memory.json") {
        return "project-hapData-fallback"
    }
    if (path == project + "/happub-device-memory.json") {
        return "project-happub-fallback"
    }
    "unknown"
}

func getHomeForDeviceMemory(): Option<String> {
    getVariable("HOME")
}

func containsReviewedExecutionReceiptSchema(text: String): Bool {
    containsText(text, "\"schema\":\"happub-hapcli-harmony-reviewed-execution-receipt-v0\"") ||
        containsText(text, "\"schema\": \"happub-hapcli-harmony-reviewed-execution-receipt-v0\"")
}

func containsJsonTrue(text: String, key: String): Bool {
    containsText(text, "\"" + key + "\":true") || containsText(text, "\"" + key + "\": true")
}

func containsJsonFalse(text: String, key: String): Bool {
    containsText(text, "\"" + key + "\":false") || containsText(text, "\"" + key + "\": false")
}

func harmonyProjectFingerprint(project: String): String {
    if (project.size == 0) {
        return "path:unknown"
    }
    "path:" + project
}

func harmonyDeviceMemoryStaleStatus(promotedAt: String, promotedAtEpochSeconds: String, staleAfterSeconds: String): String {
    harmonyDeviceMemoryStaleStatusAt(
        promotedAt,
        promotedAtEpochSeconds,
        staleAfterSeconds,
        DateTime.nowUTC().toUnixTimeStamp().toSeconds()
    )
}

public func harmonyDeviceMemoryStaleStatusAt(
    promotedAt: String,
    promotedAtEpochSeconds: String,
    staleAfterSeconds: String,
    nowEpochSeconds: Int64
): String {
    let staleWindow = parseHarmonyNonNegativeInt64(staleAfterSeconds)
    if (staleAfterSeconds.size == 0) {
        return "stale-policy-missing"
    }
    if (staleWindow < 0) {
        return "stale-policy-invalid"
    }
    if (staleWindow == 0) {
        return "stale-by-policy"
    }
    let promotedEpoch = if (parseHarmonyNonNegativeInt64(promotedAtEpochSeconds) >= 0) {
        parseHarmonyNonNegativeInt64(promotedAtEpochSeconds)
    } else {
        harmonyDevicePromotionEpochSeconds(promotedAt)
    }
    if (promotedEpoch < 0) {
        return "stale-time-unverifiable"
    }
    if (promotedEpoch > nowEpochSeconds + 300) {
        return "stale-time-in-future"
    }
    let age = if (promotedEpoch > nowEpochSeconds) { Int64(0) } else { nowEpochSeconds - promotedEpoch }
    if (age >= staleWindow) {
        return "stale-by-policy"
    }
    "active-policy"
}

func resolveHarmonyDevicePromotionTimestamp(timestamp: String): String {
    let normalized = trimAsciiText(timestamp)
    if (normalized.size == 0 || normalized == "manual-review-time-not-supplied" || normalized == "local-dev-auto-usb-proof") {
        return DateTime.nowUTC().toString()
    }
    if (harmonyDevicePromotionEpochSeconds(normalized) < 0) {
        return DateTime.nowUTC().toString()
    }
    normalized
}

func harmonyDevicePromotionEpochSeconds(timestamp: String): Int64 {
    let normalized = trimAsciiText(timestamp)
    try {
        return DateTime.parse(normalized, DateTimeFormat.RFC3339).toUnixTimeStamp().toSeconds()
    } catch (_: Exception) {
        let withoutUtcFraction = stripHarmonyRfc3339UtcFraction(normalized)
        if (withoutUtcFraction == normalized) {
            return -1
        }
        try {
            DateTime.parse(withoutUtcFraction, DateTimeFormat.RFC3339).toUnixTimeStamp().toSeconds()
        } catch (_: Exception) {
            -1
        }
    }
}

func stripHarmonyRfc3339UtcFraction(timestamp: String): String {
    let dot = indexOfText(timestamp, ".")
    let utc = indexOfText(timestamp, "Z")
    if (dot > 0 && utc > dot) {
        return substringTo(timestamp, dot) + substringFrom(timestamp, utc)
    }
    timestamp
}

func parseHarmonyNonNegativeInt64(text: String): Int64 {
    try {
        let parsed = Int64.parse(trimAsciiText(text))
        if (parsed >= 0) { parsed } else { -1 }
    } catch (_: Exception) {
        -1
    }
}

func appendDeviceMemoryChangedPaths(out: StringBuilder, writeResult: HapHarmonyDeviceMemoryWriteResult): Unit {
    out.append("[")
    if (writeResult.written && writeResult.path.size > 0) {
        out.append("\"" + escapeJson(writeResult.path) + "\"")
    }
    out.append("]")
}
