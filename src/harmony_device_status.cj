package hapcli

import std.collection.ArrayList
import std.fs.exists
import std.process.executeWithOutput

public class HapHarmonyDeviceStatusOptions {
    public var project: String = "."
    public var memory: String = ""
    public var hdcPath: String = "hdc"
    public var checkHdc: Bool = false
    public var hdcTimeoutSeconds: String = "3"
    public var staleAfterSeconds: String = "86400"

    public init() {}
}

class HapHarmonyHdcTargetProbe {
    var actionTaken: Bool = false
    var status: String = "not-requested"
    var rawExitCode: Int64 = -1
    var semanticStatus: String = "not-run"
    var stdoutText: String = ""
    var stderrText: String = ""
    var targets: ArrayList<String> = ArrayList<String>()

    init() {}
}

public func resolveHarmonyDeviceStatusOptions(commandLine: Array<String>, startIndex: Int64): HapHarmonyDeviceStatusOptions {
    let options = HapHarmonyDeviceStatusOptions()
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
        if ((current == "--hdc" || current == "--hdc-path") && i + 1 < commandLine.size) {
            options.hdcPath = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--hdc=")) {
            options.hdcPath = substringFrom(current, 6)
            i += 1
            continue
        }
        if (startsWithText(current, "--hdc-path=")) {
            options.hdcPath = substringFrom(current, 11)
            i += 1
            continue
        }
        if (current == "--check-hdc") {
            options.checkHdc = true
            i += 1
            continue
        }
        if (current == "--hdc-timeout-seconds" && i + 1 < commandLine.size) {
            options.hdcTimeoutSeconds = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--hdc-timeout-seconds=")) {
            options.hdcTimeoutSeconds = substringFrom(current, 22)
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
        i += 1
    }
    options
}

public func renderHarmonyDeviceStatusJson(options: HapHarmonyDeviceStatusOptions): String {
    let memoryOptions = HapHarmonyDeviceMemoryOptions()
    memoryOptions.project = options.project
    memoryOptions.memory = options.memory
    memoryOptions.staleAfterSeconds = options.staleAfterSeconds
    let memoryTrust = inspectHarmonyDeviceMemory(memoryOptions)
    let hdcProbe = if (options.checkHdc) { probeHarmonyHdcTargets(options.hdcPath, harmonyConfigInt(options.hdcTimeoutSeconds, 3)) } else { HapHarmonyHdcTargetProbe() }
    let status = harmonyDeviceStatus(memoryTrust, hdcProbe, options.checkHdc)
    let ok = status == "ready-with-live-target" || status == "ready-with-trusted-memory"
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-harmony-device-status-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"read-only-device-status\",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"project\": \"" + escapeJson(options.project) + "\",\n")
    out.append("  \"memoryPath\": \"" + escapeJson(memoryTrust.memoryPath) + "\",\n")
    out.append("  \"memoryPathSource\": \"" + escapeJson(memoryTrust.pathSource) + "\",\n")
    out.append("  \"deviceMemoryStatus\": \"" + escapeJson(memoryTrust.status) + "\",\n")
    out.append("  \"deviceMemoryTrusted\": " + boolJson(memoryTrust.trusted) + ",\n")
    out.append("  \"trustedWirelessTarget\": \"" + escapeJson(memoryTrust.target) + "\",\n")
    out.append("  \"trustedWirelessIp\": \"" + escapeJson(memoryTrust.ip) + "\",\n")
    out.append("  \"trustedWirelessPort\": \"" + escapeJson(memoryTrust.port) + "\",\n")
    out.append("  \"staleStatus\": \"" + escapeJson(memoryTrust.staleStatus) + "\",\n")
    out.append("  \"hdcCheckRequested\": " + boolJson(options.checkHdc) + ",\n")
    out.append("  \"hdcPath\": \"" + escapeJson(options.hdcPath) + "\",\n")
    out.append("  \"hdcTimeoutSeconds\": \"" + escapeJson(options.hdcTimeoutSeconds) + "\",\n")
    out.append("  \"hdcActionTaken\": " + boolJson(hdcProbe.actionTaken) + ",\n")
    out.append("  \"hdcStatus\": \"" + escapeJson(hdcProbe.status) + "\",\n")
    out.append("  \"hdcRawExitCode\": " + hdcProbe.rawExitCode.toString() + ",\n")
    out.append("  \"hdcSemanticStatus\": \"" + escapeJson(hdcProbe.semanticStatus) + "\",\n")
    out.append("  \"hdcTargets\": ")
    appendHarmonyDeviceStatusStringArray(out, hdcProbe.targets)
    out.append(",\n")
    out.append("  \"nextRecommended\": ")
    appendHarmonyDeviceStatusStringArray(out, harmonyDeviceStatusNextRecommended(status, memoryTrust, hdcProbe, options))
    out.append(",\n")
    out.append("  \"nonPromises\": [\"does not build the project\", \"does not install or launch the app\", \"does not scan the local network\", \"does not mutate device memory\"]\n")
    out.append("}")
    out.toString()
}

func probeHarmonyHdcTargets(hdcPath: String, timeoutSeconds: Int64): HapHarmonyHdcTargetProbe {
    let probe = HapHarmonyHdcTargetProbe()
    probe.actionTaken = true
    let (exitCode, stdoutBytes, stderrBytes) = executeHarmonyHdcListTargetsWithTimeout(hdcPath, timeoutSeconds)
    probe.rawExitCode = exitCode
    probe.stdoutText = String.fromUtf8(stdoutBytes)
    probe.stderrText = String.fromUtf8(stderrBytes)
    probe.semanticStatus = harmonyCommandSemanticStatus(simpleCommand("hdc-list-targets", hdcPath, ["list", "targets"]), exitCode, probe.stdoutText, probe.stderrText)
    probe.status = if (probe.semanticStatus == "ok") { "targets-present" } else { probe.semanticStatus }
    probe.targets = harmonyDeviceStatusTargetsFromStdout(probe.stdoutText)
    probe
}

func executeHarmonyHdcListTargetsWithTimeout(hdcPath: String, timeoutSeconds: Int64): (Int64, Array<Byte>, Array<Byte>) {
    if (timeoutSeconds <= 0 || !exists("/bin/sh")) {
        return executeWithOutput(hdcPath, ["list", "targets"])
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
        "    echo \"hap hdc status timeout after $timeout seconds\" >&2\n" +
        "    exit 124\n" +
        "  fi\n" +
        "  sleep 1\n" +
        "  elapsed=$((elapsed + 1))\n" +
        "done\n" +
        "wait \"$pid\"\n" +
        "exit \"$?\""
    executeWithOutput("/bin/sh", ["-c", script, "hapcli-device-status-timeout", timeoutSeconds.toString(), hdcPath, "list", "targets"])
}

func harmonyDeviceStatus(memoryTrust: HapHarmonyDeviceMemoryTrust, hdcProbe: HapHarmonyHdcTargetProbe, checkHdc: Bool): String {
    if (checkHdc && hdcProbe.semanticStatus == "ok") {
        return "ready-with-live-target"
    }
    if (memoryTrust.trusted) {
        return "ready-with-trusted-memory"
    }
    if (checkHdc && hdcProbe.actionTaken && hdcProbe.semanticStatus == "hdc-no-targets") {
        return "needs-usb-or-trusted-wireless-memory"
    }
    if (checkHdc && hdcProbe.actionTaken && hdcProbe.semanticStatus != "ok") {
        return "hdc-check-failed"
    }
    if (memoryTrust.memoryPath.size == 0 || !exists(memoryTrust.memoryPath)) {
        return "needs-first-usb-dev"
    }
    memoryTrust.status
}

func harmonyDeviceStatusNextRecommended(
    status: String,
    memoryTrust: HapHarmonyDeviceMemoryTrust,
    hdcProbe: HapHarmonyHdcTargetProbe,
    options: HapHarmonyDeviceStatusOptions
): ArrayList<String> {
    let items = ArrayList<String>()
    if (status == "ready-with-live-target") {
        items.add("run hap dev to build, install, launch, self-check, and refresh wireless memory")
        items.add("if you want field acceptance, unplug USB after success and run hap dev again")
        return items
    }
    if (status == "ready-with-trusted-memory") {
        items.add("run hap dev to reconnect " + memoryTrust.ip + ":" + memoryTrust.port + " before hdc list targets")
        items.add("if reconnect fails, plug USB once and rerun hap dev to refresh memory")
        return items
    }
    if (status == "needs-usb-or-trusted-wireless-memory") {
        items.add("connect and authorize one HarmonyOS device over USB, then run hap dev")
        items.add("or provide trusted memory with hap harmony device-memory readback --project " + options.project)
        return items
    }
    if (status == "hdc-check-failed") {
        items.add("verify hdc path with " + options.hdcPath + " list targets")
        items.add("if hdc prints a connect-key failure, unlock the device and approve debugging")
        return items
    }
    if (status == "trusted-device-memory-stale") {
        items.add("plug USB and run hap dev once to refresh the stale wireless endpoint")
        return items
    }
    if (hdcProbe.status.size > 0 && hdcProbe.status != "not-requested") {
        items.add("inspect hdc status: " + hdcProbe.status)
    }
    items.add("run hap harmony device-status --project " + options.project + " --check-hdc before hap dev")
    items.add("run hap dev with USB connected to create the first trusted wireless memory")
    items
}

func harmonyDeviceStatusTargetsFromStdout(stdoutText: String): ArrayList<String> {
    let targets = ArrayList<String>()
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
        targets.add(firstAsciiToken(trimmed))
    }
    targets
}

func appendHarmonyDeviceStatusStringArray(out: StringBuilder, values: ArrayList<String>): Unit {
    out.append("[")
    var i: Int64 = 0
    while (i < values.size) {
        if (i > 0) {
            out.append(", ")
        }
        out.append("\"" + escapeJson(values[i]) + "\"")
        i += 1
    }
    out.append("]")
}
