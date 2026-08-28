package hapcli

import std.collection.ArrayList
import std.convert.*
import std.process.executeWithOutput

public class HapCangjieRouteProbe {
    public var route: String = ""
    public var label: String = ""
    public var url: String = ""
    public var ok: Bool = false
    public var latencyMs: Int64 = -1
    public var status: String = "not-probed"

    public init() {}
}

class HapCangjieInstallTuiChoice {
    var selected: Int64 = 0
    var cancelled: Bool = false

    init() {}
}

public func shouldOfferCangjieInstallTui(commandLine: Array<String>): Bool {
    commandLine.size == 3 && commandLine[0].size > 0 && commandLine[1] == "install" && commandLine[2] == "cangjie"
}

@When[os != "Windows"]
public func cangjieInstallInteractiveTerminalAvailable(): Bool {
    unsafe { isatty(0) } != 0 && unsafe { isatty(1) } != 0
}

@When[os == "Windows"]
public func cangjieInstallInteractiveTerminalAvailable(): Bool {
    false
}

@When[os != "Windows"]
public func runCangjiePackageInstallTui(): String {
    if (!cangjieInstallInteractiveTerminalAvailable()) {
        return renderInspectCjpmErrorJson("interactive-terminal-unavailable", "use an explicit version and --route for non-interactive execution")
    }
    let versionRows = [
        "1.0.5  LTS  latest/default",
        "1.1.3  STS  exact release"
    ]
    let versionChoice = selectCangjieInstallTuiRow("Choose Cangjie version", versionRows, 0, "↑/↓ move  Enter select  q cancel")
    if (versionChoice.cancelled) {
        return renderCangjieInstallTuiCancelled("version-selection")
    }
    let version = if (versionChoice.selected == 0) { "1.0.5" } else { "1.1.3" }
    let options = resolveCangjiePackageInstallOptions(["hap", "install", "cangjie@" + version], 2)
    if (!options.valid) {
        return renderInspectCjpmErrorJson(options.errorCode, options.errorMessage)
    }
    let asset = resolveCangjiePackageInstallAsset(options)
    if (!asset.valid) {
        return renderCangjiePackageInstallJson(options, asset, unsupportedCangjiePackageInstallResult(options))
    }

    renderCangjieInstallProbePrelude(version, options.target)
    let probes = probeCangjieInstallRoutes(options, asset)
    let fastest = fastestCangjieInstallRouteIndex(probes)
    let routeRows = renderCangjieInstallRouteRows(probes, fastest)
    let routeChoice = selectCangjieInstallTuiRow("Choose download route", routeRows, if (fastest >= 0) { 0 } else { 1 }, "Observed latency is transport evidence only; Enter select  q cancel")
    if (routeChoice.cancelled) {
        copyCangjieInstallRouteProbes(options, probes)
        return renderCangjieInstallTuiCancelledAfterProbe(options, asset, "route-selection")
    }
    if (routeChoice.selected == 0) {
        if (fastest < 0) {
            return renderCangjieInstallRouteProbeFailure(options, asset, probes)
        }
        applyCangjieInstallProbeSelection(options, probes[fastest], "interactive-auto-fastest")
        options.requestedRoute = "auto"
    } else {
        let exact = routeChoice.selected - 1
        if (exact < 0 || exact >= probes.size) {
            return renderCangjieInstallRouteProbeFailure(options, asset, probes)
        }
        applyCangjieInstallProbeSelection(options, probes[exact], "interactive-explicit-route")
        options.requestedRoute = probes[exact].route
    }
    copyCangjieInstallRouteProbes(options, probes)

    let confirmationRows = [
        "Install now",
        "Cancel"
    ]
    let latency = if (options.selectedRouteLatencyMs >= 0) { options.selectedRouteLatencyMs.toString() + " ms" } else { "unreachable in probe; forced route" }
    let summary = "SDK " + options.resolvedVersion + " " + options.releaseChannel + " | " + options.target + " | " + options.selectedRoute + " · " + latency + "\n" + options.installRoot
    let confirmation = selectCangjieInstallTuiRow("Confirm private install", confirmationRows, 0, summary)
    if (confirmation.cancelled || confirmation.selected != 0) {
        return renderCangjieInstallTuiCancelledAfterProbe(options, asset, "install-confirmation")
    }
    runCangjiePackageInstall(options)
}

@When[os == "Windows"]
public func runCangjiePackageInstallTui(): String {
    renderInspectCjpmErrorJson("interactive-terminal-unavailable-on-windows", "use hap install cangjie@<version> --route <auto|mirror|ghfast|ghproxy|official>")
}

@When[os != "Windows"]
func selectCangjieInstallTuiRow(title: String, rows: Array<String>, initial: Int64, footer: String): HapCangjieInstallTuiChoice {
    let result = HapCangjieInstallTuiChoice()
    var selected = initial
    let terminal = HapDeviceRawTerminal.open()
    try {
        terminal.write("\u{001B}[?25l")
        while (true) {
            terminal.write(renderCangjieInstallTuiFrame(title, rows, selected, footer))
            let key = terminal.readKey()
            if (key == "up" || key == "k") {
                selected = if (selected <= 0) { rows.size - 1 } else { selected - 1 }
            } else if (key == "down" || key == "j") {
                selected = if (selected + 1 >= rows.size) { 0 } else { selected + 1 }
            } else if (key == "enter") {
                result.selected = selected
                return result
            } else if (key == "q" || key == "escape" || key == "end") {
                result.selected = selected
                result.cancelled = true
                return result
            }
        }
    } finally {
        terminal.write("\u{001B}[?25h\u{001B}[0m\n")
        terminal.close()
    }
    result
}

public func renderCangjieInstallTuiFrame(title: String, rows: Array<String>, selected: Int64, footer: String): String {
    let cyan = "\u{001B}[0;36m"
    let dim = "\u{001B}[2m"
    let reverse = "\u{001B}[7m"
    let reset = "\u{001B}[0m"
    let out = StringBuilder()
    out.append("\u{001B}[2J\u{001B}[H")
    out.append(cyan + "Hap · Cangjie installer" + reset + "\n")
    out.append(title + "\n\n")
    var i: Int64 = 0
    while (i < rows.size) {
        let line = (if (i == selected) { "› " } else { "  " }) + rows[i]
        out.append(if (i == selected) { reverse + line + reset + "\n" } else { line + "\n" })
        i += 1
    }
    out.append("\n" + dim + footer + reset + "\n")
    out.toString()
}

@When[os != "Windows"]
func renderCangjieInstallProbePrelude(version: String, target: String): Unit {
    let terminal = HapDeviceRawTerminal.open()
    try {
        terminal.write("\u{001B}[2J\u{001B}[HHap · Cangjie installer\nTesting reviewed routes for " + version + " on " + target + "…\n")
    } finally {
        terminal.close()
    }
}

public func probeCangjieInstallRoutes(options: HapCangjiePackageInstallOptions, asset: HapCangjiePackageInstallAsset): ArrayList<HapCangjieRouteProbe> {
    let probes = cangjieInstallRouteCatalog(asset)
    for (probe in probes) {
        probeCangjieInstallRoute(options, probe)
    }
    probes
}

public func cangjieInstallRouteCatalog(asset: HapCangjiePackageInstallAsset): ArrayList<HapCangjieRouteProbe> {
    let probes = ArrayList<HapCangjieRouteProbe>()
    addCangjieInstallRouteProbe(probes, "mirror", "HapPub mirror", asset.mirrorUrl)
    addCangjieInstallRouteProbe(probes, "ghfast", "Mainland accelerator · ghfast", rewriteGithubDownloadUrl("https://ghfast.top/", asset.mirrorUrl))
    addCangjieInstallRouteProbe(probes, "ghproxy", "Mainland accelerator · ghproxy", rewriteGithubDownloadUrl("https://ghproxy.link/", asset.mirrorUrl))
    addCangjieInstallRouteProbe(probes, "official", "Official source", asset.sourceUrl)
    probes
}

func addCangjieInstallRouteProbe(probes: ArrayList<HapCangjieRouteProbe>, route: String, label: String, url: String): Unit {
    if (url.size == 0) {
        return
    }
    let probe = HapCangjieRouteProbe()
    probe.route = route
    probe.label = label
    probe.url = url
    probes.add(probe)
}

func probeCangjieInstallRoute(options: HapCangjiePackageInstallOptions, probe: HapCangjieRouteProbe): Unit {
    if (!startsWithText(probe.url, "https://") || !isProgramResolvable("curl")) {
        probe.status = if (isProgramResolvable("curl")) { "refused-non-https" } else { "curl-unavailable" }
        return
    }
    let args = [
        "--proto", "=https", "--tlsv1.2", "--location", "--fail", "--silent", "--show-error", "--head",
        "--connect-timeout", "3", "--max-time", "8", "--output", cangjieInstallNullDevice(),
        "--write-out", "%{time_total}", probe.url
    ]
    let command = resolveHapNetworkCommand(options.networkMode, "curl", args)
    let (code, stdoutBytes, _) = executeWithOutput(command.program, command.args.toArray())
    let latency = parseCurlTimeTotalMilliseconds(String.fromUtf8(stdoutBytes))
    if (code == 0 && latency >= 0) {
        probe.ok = true
        probe.latencyMs = if (latency == 0) { 1 } else { latency }
        probe.status = "observed"
    } else {
        probe.status = "unreachable"
    }
}

@When[os != "Windows"]
func cangjieInstallNullDevice(): String { "/dev/null" }

@When[os == "Windows"]
func cangjieInstallNullDevice(): String { "NUL" }

public func parseCurlTimeTotalMilliseconds(value: String): Int64 {
    let normalized = trimAsciiText(value)
    if (normalized.size == 0) { return -1 }
    let parts = normalized.split(".")
    if (parts.size > 2 || parts.size == 0) { return -1 }
    try {
        let seconds = Int64.parse(parts[0])
        if (seconds < 0) { return -1 }
        var fraction = if (parts.size == 2) { parts[1] } else { "" }
        while (fraction.size < 3) { fraction += "0" }
        let millis = if (fraction.size == 0) { Int64(0) } else { Int64.parse(substringRange(fraction, 0, 3)) }
        seconds * 1000 + millis
    } catch (_: Exception) {
        -1
    }
}

public func fastestCangjieInstallRouteIndex(probes: ArrayList<HapCangjieRouteProbe>): Int64 {
    var selected: Int64 = -1
    var latency: Int64 = 0
    var i: Int64 = 0
    while (i < probes.size) {
        if (probes[i].ok && probes[i].latencyMs >= 0 && (selected < 0 || probes[i].latencyMs < latency)) {
            selected = i
            latency = probes[i].latencyMs
        }
        i += 1
    }
    selected
}

public func selectFastestCangjieInstallRoute(options: HapCangjiePackageInstallOptions, asset: HapCangjiePackageInstallAsset): Bool {
    let probes = probeCangjieInstallRoutes(options, asset)
    copyCangjieInstallRouteProbes(options, probes)
    let index = fastestCangjieInstallRouteIndex(probes)
    if (index < 0) {
        options.routeProbeActionTaken = true
        options.routeProbeStatus = "all-failed"
        return false
    }
    applyCangjieInstallProbeSelection(options, probes[index], "latency-fastest")
    true
}

func applyCangjieInstallProbeSelection(options: HapCangjiePackageInstallOptions, probe: HapCangjieRouteProbe, source: String): Unit {
    options.selectedRoute = probe.route
    options.routeSelectionSource = source
    options.selectedRouteUrl = probe.url
    options.selectedRouteLatencyMs = probe.latencyMs
    options.routeProbeActionTaken = true
    options.routeProbeStatus = "completed"
}

func copyCangjieInstallRouteProbes(options: HapCangjiePackageInstallOptions, probes: ArrayList<HapCangjieRouteProbe>): Unit {
    options.routeProbes.clear()
    for (probe in probes) {
        options.routeProbes.add(probe)
    }
    options.routeProbeActionTaken = true
    if (options.routeProbeStatus == "not-requested" || options.routeProbeStatus == "pending-execution") {
        options.routeProbeStatus = if (fastestCangjieInstallRouteIndex(probes) >= 0) { "completed" } else { "all-failed" }
    }
}

public func cangjieInstallRouteUrl(route: String, asset: HapCangjiePackageInstallAsset): String {
    if (route == "mirror") { asset.mirrorUrl }
    else if (route == "ghfast") { rewriteGithubDownloadUrl("https://ghfast.top/", asset.mirrorUrl) }
    else if (route == "ghproxy") { rewriteGithubDownloadUrl("https://ghproxy.link/", asset.mirrorUrl) }
    else if (route == "official") { asset.sourceUrl }
    else { "" }
}

public func bindCangjieInstallRouteMetadata(options: HapCangjiePackageInstallOptions, asset: HapCangjiePackageInstallAsset): Unit {
    if (options.selectedRoute == "mirror" || options.selectedRoute == "ghfast" || options.selectedRoute == "ghproxy" || options.selectedRoute == "official") {
        options.selectedRouteUrl = cangjieInstallRouteUrl(options.selectedRoute, asset)
    }
}

public func renderCangjieInstallRouteRows(probes: ArrayList<HapCangjieRouteProbe>, fastest: Int64): Array<String> {
    let rows = ArrayList<String>()
    rows.add(if (fastest >= 0) { "Automatic · fastest now: " + probes[fastest].label + " · " + probes[fastest].latencyMs.toString() + " ms" } else { "Automatic · no route reachable" })
    for (probe in probes) {
        rows.add(probe.label + " · " + if (probe.ok) { probe.latencyMs.toString() + " ms" } else { "unreachable" })
    }
    rows.toArray()
}

public func renderCangjieInstallRouteProbesJson(probes: ArrayList<HapCangjieRouteProbe>): String {
    let out = StringBuilder()
    out.append("[")
    var i: Int64 = 0
    while (i < probes.size) {
        if (i > 0) { out.append(", ") }
        let probe = probes[i]
        out.append("{\"route\":\"" + escapeJson(probe.route) + "\",\"url\":\"" + escapeJson(probe.url) + "\",\"ok\":" + boolJson(probe.ok) + ",\"latencyMs\":" + probe.latencyMs.toString() + ",\"status\":\"" + escapeJson(probe.status) + "\"}")
        i += 1
    }
    out.append("]")
    out.toString()
}

func renderCangjieInstallRouteProbeFailure(options: HapCangjiePackageInstallOptions, asset: HapCangjiePackageInstallAsset, probes: ArrayList<HapCangjieRouteProbe>): String {
    copyCangjieInstallRouteProbes(options, probes)
    let result = HapCangjiePackageInstallResult()
    result.status = "route-probe-failed"
    result.finalRoot = cangjiePackageFinalRoot(options)
    result.diagnostic = "selected route is unreachable; no download or install was attempted"
    renderCangjiePackageInstallJson(options, asset, result)
}

func renderCangjieInstallTuiCancelled(stage: String): String {
    "{\n  \"schema\": \"happub-hapcli-cangjie-install-tui-v1\",\n  \"ok\": false,\n  \"status\": \"cancelled\",\n  \"stage\": \"" + escapeJson(stage) + "\",\n  \"routeProbeActionTaken\": false,\n  \"downloadActionTaken\": false,\n  \"installActionTaken\": false,\n  \"systemMutation\": false\n}"
}

func renderCangjieInstallTuiCancelledAfterProbe(options: HapCangjiePackageInstallOptions, asset: HapCangjiePackageInstallAsset, stage: String): String {
    let result = HapCangjiePackageInstallResult()
    result.status = "cancelled"
    result.finalRoot = cangjiePackageFinalRoot(options)
    result.diagnostic = "interactive install cancelled during " + stage + "; latency probes may have run but no archive download or install was attempted"
    renderCangjiePackageInstallJson(options, asset, result)
}
