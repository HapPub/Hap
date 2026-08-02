package hapcli

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{Directory, File, exists}
import std.process.executeWithOutput

public class HapDeviceOptions {
    public var action: String = "list"
    public var project: String = "."
    public var platform: String = "auto"
    public var registry: String = ""
    public var alias: String = ""
    public var target: String = ""
    public var name: String = ""
    public var deleteAlias: String = ""
    public var renameAlias: String = ""
    public var defaultAlias: String = ""
    public var json: Bool = false
    public var noProbe: Bool = false
    public var allPlatforms: Bool = false
    public var timeoutSeconds: Int64 = 8

    public init() {}
}

public class HapDeviceEntry {
    public var alias: String = ""
    public var platform: String = "unknown"
    public var target: String = ""
    public var name: String = ""
    public var status: String = "saved"
    public var backend: String = "registry"
    public var source: String = "registry"
    public var saved: Bool = false
    public var connected: Bool = false
    public var isDefault: Bool = false
    public var mutable: Bool = true

    public init() {}
}

public class HapDeviceRegistry {
    public var path: String = ""
    public var pathSource: String = "none"
    public var defaultHarmony: String = ""
    public var defaultAndroid: String = ""
    public var defaultIos: String = ""
    public let entries: ArrayList<HapDeviceEntry> = ArrayList<HapDeviceEntry>()

    public init() {}
}

public class HapDeviceSnapshot {
    public var project: String = "."
    public var projectKind: String = "unknown"
    public var selectionStatus: String = "project-not-detected"
    public var registryPath: String = ""
    public var registryPathSource: String = "none"
    public let requestedPlatforms: ArrayList<String> = ArrayList<String>()
    public let entries: ArrayList<HapDeviceEntry> = ArrayList<HapDeviceEntry>()
    public let backendNotes: ArrayList<String> = ArrayList<String>()
    public var probeRequested: Bool = false
    public var probeActionTaken: Bool = false

    public init() {}
}

public class HapDeviceWriteResult {
    public var ok: Bool = false
    public var status: String = "not-attempted"
    public var path: String = ""
    public var pathSource: String = "none"
    public var backupPath: String = ""
    public var backupWritten: Bool = false
    public var registryWritten: Bool = false
    public var message: String = ""

    public init() {}
}

public func resolveHapDeviceOptions(action: String, commandLine: Array<String>, startIndex: Int64): HapDeviceOptions {
    let options = HapDeviceOptions()
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
        if (current == "--registry" && i + 1 < commandLine.size) {
            options.registry = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--registry=")) {
            options.registry = substringFrom(current, 11)
            i += 1
            continue
        }
        if (current == "--alias" && i + 1 < commandLine.size) {
            options.alias = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--alias=")) {
            options.alias = substringFrom(current, 8)
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
        if (current == "--name" && i + 1 < commandLine.size) {
            options.name = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--name=")) {
            options.name = substringFrom(current, 7)
            i += 1
            continue
        }
        if (current == "--delete" && i + 1 < commandLine.size) {
            options.deleteAlias = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--delete=")) {
            options.deleteAlias = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--rename" && i + 1 < commandLine.size) {
            options.renameAlias = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--rename=")) {
            options.renameAlias = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--default" && i + 1 < commandLine.size) {
            options.defaultAlias = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--default=")) {
            options.defaultAlias = substringFrom(current, 10)
            i += 1
            continue
        }
        if (current == "--json" || current == "-j") {
            options.json = true
            i += 1
            continue
        }
        if (current == "--no-probe") {
            options.noProbe = true
            i += 1
            continue
        }
        if (current == "--all") {
            options.allPlatforms = true
            i += 1
            continue
        }
        if (current == "--timeout-seconds" && i + 1 < commandLine.size) {
            options.timeoutSeconds = parseHapDeviceTimeoutSeconds(commandLine[i + 1])
            i += 2
            continue
        }
        if (startsWithText(current, "--timeout-seconds=")) {
            options.timeoutSeconds = parseHapDeviceTimeoutSeconds(substringFrom(current, 18))
            i += 1
            continue
        }
        i += 1
    }
    options
}

func parseHapDeviceTimeoutSeconds(value: String): Int64 {
    let runes = trimAsciiText(value).toRuneArray()
    if (runes.size == 0) {
        return 8
    }
    var parsed: Int64 = 0
    for (rune in runes) {
        let digit = Int64(UInt32(rune)) - 48
        if (digit < 0 || digit > 9) {
            return 8
        }
        parsed = parsed * 10 + digit
        if (parsed > 120) {
            return 8
        }
    }
    if (parsed >= 1) { parsed } else { 8 }
}

public func runHapDeviceList(options: HapDeviceOptions): String {
    let snapshot = inspectHapDevices(options)
    if (options.json) {
        renderHapDeviceSnapshotJson(snapshot)
    } else {
        renderHapDeviceSnapshotHuman(snapshot)
    }
}

public func runHapDeviceSet(options: HapDeviceOptions): String {
    if (!hapDeviceHasNonInteractiveMutation(options)) {
        return runHapDeviceSetInteractive(options)
    }
    let registry = readHapDeviceRegistry(options)
    let result = applyHapDeviceMutation(options, registry)
    if (options.json) {
        renderHapDeviceWriteResultJson(options, result)
    } else {
        renderHapDeviceWriteResultHuman(options, result)
    }
}

public func hapDeviceCommandExitCode(output: String): Int64 {
    if (containsText(output, "\"ok\": false") || containsText(output, "Hap device failed")) { 2 } else { 0 }
}

public func inspectHapDevices(options: HapDeviceOptions): HapDeviceSnapshot {
    let snapshot = HapDeviceSnapshot()
    snapshot.project = options.project
    let projectCandidates = detectProjectCandidates(options.project)
    let selected = selectProjectDetection(projectCandidates, options.platform)
    let selection = resolveProjectSelectionInfo(projectCandidates, options.platform, selected)
    snapshot.projectKind = selected.projectKind
    snapshot.selectionStatus = selection.status
    if (snapshot.projectKind == "unknown" && hapDeviceProjectHasAndroid(options.project)) {
        snapshot.projectKind = "android"
        snapshot.selectionStatus = "selected"
    }
    appendHapDevicePlatforms(options, snapshot.projectKind, snapshot.requestedPlatforms)
    snapshot.probeRequested = !options.noProbe && snapshot.requestedPlatforms.size > 0

    let registry = readHapDeviceRegistry(options)
    snapshot.registryPath = registry.path
    snapshot.registryPathSource = registry.pathSource
    for (entry in registry.entries) {
        snapshot.entries.add(copyHapDeviceEntry(entry))
    }
    appendLegacyHarmonyAliases(options, snapshot.entries)

    if (!options.noProbe) {
        for (platform in snapshot.requestedPlatforms) {
            if (platform == "harmonyos") {
                probeHarmonyDevices(options, snapshot)
            } else if (platform == "android") {
                probeAndroidDevices(options, snapshot)
            } else if (platform == "ios") {
                probeIosDevices(options, snapshot)
            }
        }
    }
    applyHapDeviceDefaults(snapshot.entries, registry)
    snapshot
}

func appendHapDevicePlatforms(options: HapDeviceOptions, projectKind: String, out: ArrayList<String>): Unit {
    let requested = normalizeHapDevicePlatform(options.platform)
    if (options.allPlatforms) {
        out.add("harmonyos")
        out.add("android")
        out.add("ios")
        return
    }
    if (requested == "kotlin-multiplatform") {
        out.add("android")
        out.add("ios")
        return
    }
    if (requested != "auto") {
        out.add(requested)
        return
    }
    if (projectKind == "harmonyos") {
        out.add("harmonyos")
    } else if (projectKind == "android") {
        out.add("android")
    } else if (projectKind == "ios") {
        out.add("ios")
    } else if (projectKind == "kotlin-multiplatform") {
        if (hapDeviceProjectHasAndroid(options.project)) {
            out.add("android")
        }
        if (hapDeviceProjectHasIos(options.project)) {
            out.add("ios")
        }
        if (out.size == 0) {
            out.add("android")
            out.add("ios")
        }
    } else if (hapDeviceProjectHasAndroid(options.project)) {
        out.add("android")
    }
}

func normalizeHapDevicePlatform(platform: String): String {
    let normalized = normalizeProjectPlatform(platform)
    match (normalized) {
        case "harmonyos" => "harmonyos"
        case "ios" => "ios"
        case "android" => "android"
        case "kotlin-multiplatform" => "kotlin-multiplatform"
        case "auto" => "auto"
        case _ => platform
    }
}

func hapDeviceProjectHasAndroid(project: String): Bool {
    exists(joinProjectPath(project, "app/src/main/AndroidManifest.xml")) ||
        exists(joinProjectPath(project, "composeApp/src/androidMain")) ||
        exists(joinProjectPath(project, "src/androidMain"))
}

func hapDeviceProjectHasIos(project: String): Bool {
    exists(joinProjectPath(project, "iosApp")) ||
        exists(joinProjectPath(project, "composeApp/src/iosMain")) ||
        exists(joinProjectPath(project, "src/iosMain"))
}

func probeHarmonyDevices(options: HapDeviceOptions, snapshot: HapDeviceSnapshot): Unit {
    let actionOptions = HapProjectActionOptions()
    actionOptions.project = options.project
    let config = resolveHarmonyAdapterConfig(actionOptions)
    let hdc = config.hdcPath
    if (!isProgramResolvable(hdc)) {
        snapshot.backendNotes.add("harmonyos: hdc unavailable")
        return
    }
    try {
        snapshot.probeActionTaken = true
        let (code, stdoutBytes, stderrBytes) = executeHapDeviceCommandWithTimeout(hdc, ["list", "targets"], options.timeoutSeconds)
        let stdoutText = String.fromUtf8(stdoutBytes)
        let stderrText = String.fromUtf8(stderrBytes)
        if (code != 0 || hdcOutputLooksFailed(stdoutText + "\n" + stderrText)) {
            snapshot.backendNotes.add("harmonyos: hdc probe failed")
            return
        }
        let discovered = parseHdcDeviceList(stdoutText)
        mergeDiscoveredHapDevices(snapshot.entries, discovered)
        snapshot.backendNotes.add("harmonyos: hdc listed " + discovered.size.toString() + " device(s)")
    } catch (_: Exception) {
        snapshot.backendNotes.add("harmonyos: hdc probe unavailable")
    }
}

func probeAndroidDevices(options: HapDeviceOptions, snapshot: HapDeviceSnapshot): Unit {
    let adb = envOrDefault("HAP_ANDROID_ADB", "adb")
    if (!isProgramResolvable(adb)) {
        snapshot.backendNotes.add("android: adb unavailable")
        return
    }
    try {
        snapshot.probeActionTaken = true
        let (code, stdoutBytes, stderrBytes) = executeHapDeviceCommandWithTimeout(adb, ["devices", "-l"], options.timeoutSeconds)
        if (code != 0) {
            snapshot.backendNotes.add("android: adb probe failed" + hapDeviceProbeFailureSuffix(code, stderrBytes))
            return
        }
        let discovered = parseAdbDeviceList(String.fromUtf8(stdoutBytes))
        mergeDiscoveredHapDevices(snapshot.entries, discovered)
        snapshot.backendNotes.add("android: adb listed " + discovered.size.toString() + " device(s)")
    } catch (_: Exception) {
        snapshot.backendNotes.add("android: adb probe unavailable")
    }
}

func probeIosDevices(options: HapDeviceOptions, snapshot: HapDeviceSnapshot): Unit {
    if (!isProgramResolvable("xcrun")) {
        snapshot.backendNotes.add("ios: xcrun unavailable")
        return
    }
    try {
        snapshot.probeActionTaken = true
        let (code, stdoutBytes, stderrBytes) = executeHapDeviceCommandWithTimeout("xcrun", ["devicectl", "list", "devices"], options.timeoutSeconds)
        if (code != 0) {
            snapshot.backendNotes.add("ios: devicectl probe failed" + hapDeviceProbeFailureSuffix(code, stderrBytes))
            return
        }
        let discovered = parseDevicectlDeviceList(String.fromUtf8(stdoutBytes))
        mergeDiscoveredHapDevices(snapshot.entries, discovered)
        snapshot.backendNotes.add("ios: devicectl listed " + discovered.size.toString() + " device(s)")
    } catch (_: Exception) {
        snapshot.backendNotes.add("ios: devicectl probe unavailable")
    }
}

func executeHapDeviceCommandWithTimeout(program: String, args: Array<String>, timeoutSeconds: Int64): (Int64, Array<Byte>, Array<Byte>) {
    if (timeoutSeconds <= 0 || !exists("/bin/sh")) {
        return executeWithOutput(program, args)
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
        "    echo \"hap device probe timeout after $timeout seconds\" >&2\n" +
        "    exit 124\n" +
        "  fi\n" +
        "  sleep 1\n" +
        "  elapsed=$((elapsed + 1))\n" +
        "done\n" +
        "wait \"$pid\"\n" +
        "exit \"$?\""
    let commandArgs = ArrayList<String>()
    commandArgs.add("-c")
    commandArgs.add(script)
    commandArgs.add("hapcli-device-probe-timeout")
    commandArgs.add(timeoutSeconds.toString())
    commandArgs.add(program)
    for (arg in args) {
        commandArgs.add(arg)
    }
    executeWithOutput("/bin/sh", commandArgs.toArray())
}

func hapDeviceProbeFailureSuffix(code: Int64, stderrBytes: Array<Byte>): String {
    let detail = trimAsciiText(String.fromUtf8(stderrBytes)).replace("\n", " | ")
    if (detail.size > 0) {
        ": " + detail
    } else if (code == 124) {
        ": timed out"
    } else {
        " (exit " + code.toString() + ")"
    }
}

public func parseHdcDeviceList(text: String): ArrayList<HapDeviceEntry> {
    let out = ArrayList<HapDeviceEntry>()
    for (line in splitAsciiLines(text)) {
        let target = trimAsciiText(line)
        if (target.size == 0 || containsText(target, "List of devices") || containsText(target, "attached")) {
            continue
        }
        let entry = HapDeviceEntry()
        entry.platform = "harmonyos"
        entry.target = firstWhitespaceToken(target)
        entry.name = entry.target
        entry.status = "connected"
        entry.backend = "hdc"
        entry.source = "probe"
        entry.connected = true
        entry.mutable = false
        out.add(entry)
    }
    out
}

public func parseAdbDeviceList(text: String): ArrayList<HapDeviceEntry> {
    let out = ArrayList<HapDeviceEntry>()
    for (line in splitAsciiLines(text)) {
        let trimmed = trimAsciiText(line)
        if (trimmed.size == 0 || startsWithText(trimmed, "List of devices")) {
            continue
        }
        let tokens = nonEmptyWhitespaceTokens(trimmed)
        if (tokens.size < 2) {
            continue
        }
        let entry = HapDeviceEntry()
        entry.platform = "android"
        entry.target = tokens[0]
        entry.status = tokens[1]
        entry.name = adbModelName(tokens, entry.target)
        entry.backend = "adb"
        entry.source = "probe"
        entry.connected = entry.status == "device"
        entry.mutable = false
        out.add(entry)
    }
    out
}

public func parseDevicectlDeviceList(text: String): ArrayList<HapDeviceEntry> {
    let out = ArrayList<HapDeviceEntry>()
    for (line in splitAsciiLines(text)) {
        let trimmed = trimAsciiText(line)
        var target = ""
        for (token in trimmed.split(" ")) {
            let candidate = trimAsciiText(token)
            if (isUuidShaped(candidate)) {
                target = candidate
                break
            }
        }
        if (target.size == 0) {
            continue
        }
        let entry = HapDeviceEntry()
        entry.platform = "ios"
        entry.target = target
        let targetIndex = indexOfText(trimmed, target)
        entry.name = if (targetIndex > 0) { devicectlDisplayName(trimAsciiText(substringTo(trimmed, targetIndex)), target) } else { target }
        entry.status = if (containsText(trimmed, "available (paired)")) {
            "available-paired"
        } else if (containsText(trimmed, "unavailable")) {
            "unavailable"
        } else if (containsText(trimmed, "unpaired")) {
            "unpaired"
        } else {
            "observed"
        }
        entry.backend = "devicectl"
        entry.source = "probe"
        entry.connected = entry.status == "available-paired"
        entry.mutable = false
        out.add(entry)
    }
    out
}

func devicectlDisplayName(prefix: String, fallback: String): String {
    let tokens = nonEmptyWhitespaceTokens(prefix)
    if (tokens.size <= 1) {
        return if (tokens.size == 1) { tokens[0] } else { fallback }
    }
    let out = StringBuilder()
    var i: Int64 = 0
    let end = if (containsText(tokens[tokens.size - 1], ".coredevice.")) { tokens.size - 1 } else { tokens.size }
    while (i < end) {
        if (i > 0) { out.append(" ") }
        out.append(tokens[i])
        i += 1
    }
    let rendered = trimAsciiText(out.toString())
    if (rendered.size > 0) { rendered } else { fallback }
}

func firstWhitespaceToken(text: String): String {
    let tokens = nonEmptyWhitespaceTokens(text)
    if (tokens.size > 0) { tokens[0] } else { "" }
}

func nonEmptyWhitespaceTokens(text: String): ArrayList<String> {
    let out = ArrayList<String>()
    for (token in text.split(" ")) {
        let trimmed = trimAsciiText(token)
        if (trimmed.size > 0) {
            out.add(trimmed)
        }
    }
    out
}

func adbModelName(tokens: ArrayList<String>, fallback: String): String {
    for (token in tokens) {
        if (startsWithText(token, "model:")) {
            return substringFrom(token, 6).replace("_", " ")
        }
    }
    fallback
}

func mergeDiscoveredHapDevices(entries: ArrayList<HapDeviceEntry>, discovered: ArrayList<HapDeviceEntry>): Unit {
    for (device in discovered) {
        var matched = false
        for (saved in entries) {
            if (saved.platform == device.platform && saved.target == device.target) {
                saved.status = device.status
                saved.backend = device.backend
                saved.connected = device.connected
                if (saved.name.size == 0 || saved.name == saved.target) {
                    saved.name = device.name
                }
                matched = true
            }
        }
        if (!matched) {
            entries.add(device)
        }
    }
}

func copyHapDeviceEntry(source: HapDeviceEntry): HapDeviceEntry {
    let entry = HapDeviceEntry()
    entry.alias = source.alias
    entry.platform = source.platform
    entry.target = source.target
    entry.name = source.name
    entry.status = source.status
    entry.backend = source.backend
    entry.source = source.source
    entry.saved = source.saved
    entry.connected = source.connected
    entry.isDefault = source.isDefault
    entry.mutable = source.mutable
    entry
}

public func readHapDeviceRegistry(options: HapDeviceOptions): HapDeviceRegistry {
    let registry = HapDeviceRegistry()
    let candidates = hapDeviceRegistryCandidates(options)
    var chosen = ""
    for (candidate in candidates) {
        if (exists(candidate)) {
            chosen = candidate
            break
        }
    }
    if (chosen.size == 0 && candidates.size > 0) {
        chosen = candidates[0]
    }
    registry.path = chosen
    registry.pathSource = hapDeviceRegistryPathSource(options, chosen)
    if (chosen.size == 0 || !exists(chosen)) {
        return registry
    }
    parseHapDeviceRegistryText(String.fromUtf8(File.readFrom(chosen)), registry)
    registry
}

public func parseHapDeviceRegistryText(text: String, registry: HapDeviceRegistry): Unit {
    var section = ""
    var current: ?HapDeviceEntry = None
    for (line in splitAsciiLines(text)) {
        let trimmed = trimAsciiText(line)
        if (trimmed == "[[devices]]") {
            match (current) {
                case Some(entry) => appendValidRegistryDevice(registry, entry)
                case None => ()
            }
            current = Some(HapDeviceEntry())
            section = "devices"
            continue
        }
        if (startsWithText(trimmed, "[")) {
            match (current) {
                case Some(entry) => appendValidRegistryDevice(registry, entry)
                case None => ()
            }
            current = None
            section = if (trimmed == "[defaults]") { "defaults" } else { "" }
            continue
        }
        let key = tomlLineKey(trimmed)
        let value = tomlLineStringValue(trimmed)
        if (key.size == 0) {
            continue
        }
        if (section == "defaults") {
            setHapDeviceRegistryDefault(registry, key, value)
        } else if (section == "devices") {
            match (current) {
                case Some(entry) => applyRegistryDeviceField(entry, key, value)
                case None => ()
            }
        }
    }
    match (current) {
        case Some(entry) => appendValidRegistryDevice(registry, entry)
        case None => ()
    }
}

func appendValidRegistryDevice(registry: HapDeviceRegistry, entry: HapDeviceEntry): Unit {
    if (entry.alias.size > 0 && entry.target.size > 0 && hapDevicePlatformSupported(entry.platform)) {
        entry.saved = true
        entry.source = "registry"
        entry.backend = "registry"
        entry.mutable = true
        registry.entries.add(entry)
    }
}

func applyRegistryDeviceField(entry: HapDeviceEntry, key: String, value: String): Unit {
    if (key == "alias") {
        entry.alias = value
    } else if (key == "platform") {
        entry.platform = normalizeHapDevicePlatform(value)
    } else if (key == "target") {
        entry.target = value
    } else if (key == "name") {
        entry.name = value
    }
}

func tomlLineKey(line: String): String {
    let eq = indexOfText(line, "=")
    if (eq <= 0) { "" } else { trimAsciiText(substringTo(line, eq)) }
}

func tomlLineStringValue(line: String): String {
    let eq = indexOfText(line, "=")
    if (eq < 0) {
        return ""
    }
    let raw = trimAsciiText(substringFrom(line, eq + 1))
    if (startsWithText(raw, "\"") && endsWithText(raw, "\"") && raw.size >= 2) {
        return substringTo(substringFrom(raw, 1), Int64(raw.size - 2)).replace("\\\"", "\"").replace("\\\\", "\\")
    }
    raw
}

func setHapDeviceRegistryDefault(registry: HapDeviceRegistry, platform: String, alias: String): Unit {
    if (platform == "harmonyos") {
        registry.defaultHarmony = alias
    } else if (platform == "android") {
        registry.defaultAndroid = alias
    } else if (platform == "ios") {
        registry.defaultIos = alias
    }
}

func hapDeviceRegistryDefault(registry: HapDeviceRegistry, platform: String): String {
    if (platform == "harmonyos") {
        registry.defaultHarmony
    } else if (platform == "android") {
        registry.defaultAndroid
    } else if (platform == "ios") {
        registry.defaultIos
    } else {
        ""
    }
}

func applyHapDeviceDefaults(entries: ArrayList<HapDeviceEntry>, registry: HapDeviceRegistry): Unit {
    for (entry in entries) {
        entry.isDefault = entry.alias.size > 0 && entry.alias == hapDeviceRegistryDefault(registry, entry.platform)
    }
}

func hapDeviceRegistryCandidates(options: HapDeviceOptions): ArrayList<String> {
    let out = ArrayList<String>()
    if (options.registry.size > 0) {
        out.add(options.registry)
        return out
    }
    match (getVariable("HOME")) {
        case Some(home) =>
            if (home.size > 0) {
                out.add(trimTrailingSlash(home) + "/.hap/devices.toml")
            }
        case None => ()
    }
    if (hapDeviceProjectSupported(options.project)) {
        out.add(trimTrailingSlash(options.project) + "/.hapData/devices.toml")
        out.add(trimTrailingSlash(options.project) + "/happub.devices.toml")
    }
    out
}

func hapDeviceProjectSupported(project: String): Bool {
    let candidates = detectProjectCandidates(project)
    for (candidate in candidates) {
        if (candidate.projectKind != "unknown") {
            return true
        }
    }
    hapDeviceProjectHasAndroid(project)
}

func hapDeviceRegistryPathSource(options: HapDeviceOptions, path: String): String {
    if (path.size == 0) {
        return "none"
    }
    if (options.registry.size > 0 && path == options.registry) {
        return "explicit"
    }
    if (containsText(path, "/.hap/devices.toml")) {
        return "user-private"
    }
    if (containsText(path, "/.hapData/devices.toml")) {
        return "project-private"
    }
    "project-fallback"
}

public func resolveHapDeviceAlias(project: String, requested: String, platform: String): String {
    if (requested.size == 0 || requested == "auto") {
        return requested
    }
    let options = HapDeviceOptions()
    options.project = project
    let registry = readHapDeviceRegistry(options)
    resolveHapDeviceAliasFromRegistry(registry, requested, platform)
}

public func resolveHapDeviceAliasFromRegistry(registry: HapDeviceRegistry, requested: String, platform: String): String {
    if (requested.size == 0 || requested == "auto") {
        return requested
    }
    let normalizedPlatform = normalizeHapDevicePlatform(platform)
    for (entry in registry.entries) {
        if (entry.alias == requested && (normalizedPlatform == "auto" || entry.platform == normalizedPlatform)) {
            return entry.target
        }
    }
    requested
}

public func resolveHapDefaultDeviceAlias(project: String, platform: String): String {
    let options = HapDeviceOptions()
    options.project = project
    let registry = readHapDeviceRegistry(options)
    resolveHapDefaultDeviceAliasFromRegistry(registry, platform)
}

public func resolveHapDefaultDeviceAliasFromRegistry(registry: HapDeviceRegistry, platform: String): String {
    hapDeviceRegistryDefault(registry, normalizeHapDevicePlatform(platform))
}

func appendLegacyHarmonyAliases(options: HapDeviceOptions, entries: ArrayList<HapDeviceEntry>): Unit {
    let actionOptions = HapProjectActionOptions()
    actionOptions.project = options.project
    let path = findHarmonyConfigPath(actionOptions)
    if (path.size == 0 || !exists(path)) {
        return
    }
    let text = String.fromUtf8(File.readFrom(path))
    var inAliases = false
    for (line in splitAsciiLines(text)) {
        let trimmed = trimAsciiText(line)
        if (startsWithText(trimmed, "[")) {
            inAliases = trimmed == "[harmony.deviceAliases]"
            continue
        }
        if (!inAliases) {
            continue
        }
        let alias = tomlLineKey(trimmed)
        let target = tomlLineStringValue(trimmed)
        if (alias.size == 0 || target.size == 0 || hapDeviceEntryAliasExists(entries, alias)) {
            continue
        }
        let entry = HapDeviceEntry()
        entry.alias = alias
        entry.platform = "harmonyos"
        entry.target = target
        entry.name = target
        entry.status = "legacy-saved"
        entry.backend = "hdc"
        entry.source = "legacy-harmony-config"
        entry.saved = true
        entry.mutable = false
        entries.add(entry)
    }
}

func hapDeviceEntryAliasExists(entries: ArrayList<HapDeviceEntry>, alias: String): Bool {
    for (entry in entries) {
        if (entry.alias == alias) {
            return true
        }
    }
    false
}

func hapDeviceHasNonInteractiveMutation(options: HapDeviceOptions): Bool {
    options.alias.size > 0 || options.deleteAlias.size > 0 || options.renameAlias.size > 0 || options.defaultAlias.size > 0
}

public func applyHapDeviceMutation(options: HapDeviceOptions, registry: HapDeviceRegistry): HapDeviceWriteResult {
    let result = HapDeviceWriteResult()
    if (options.deleteAlias.size > 0) {
        if (!removeHapDeviceAlias(registry, options.deleteAlias)) {
            result.status = "alias-not-found"
            result.message = "device alias not found: " + options.deleteAlias
            return result
        }
        result.message = "deleted device alias " + options.deleteAlias
    } else if (options.renameAlias.size > 0) {
        let colon = indexOfText(options.renameAlias, ":")
        if (colon <= 0 || colon + 1 >= options.renameAlias.size) {
            result.status = "invalid-rename"
            result.message = "rename must use old:new"
            return result
        }
        let oldAlias = substringTo(options.renameAlias, colon)
        let newAlias = substringFrom(options.renameAlias, colon + 1)
        if (!validHapDeviceAlias(newAlias)) {
            result.status = "invalid-alias"
            result.message = "new alias must use letters, digits, dot, dash, or underscore"
            return result
        }
        if (!renameHapDeviceAlias(registry, oldAlias, newAlias)) {
            result.status = "alias-not-found-or-conflict"
            result.message = "rename source is missing or destination already exists"
            return result
        }
        result.message = "renamed device alias " + oldAlias + " to " + newAlias
    } else if (options.defaultAlias.size > 0) {
        let entry = findHapDeviceRegistryEntry(registry, options.defaultAlias)
        if (entry.alias.size == 0) {
            result.status = "alias-not-found"
            result.message = "default alias is not registered: " + options.defaultAlias
            return result
        }
        setHapDeviceRegistryDefault(registry, entry.platform, entry.alias)
        result.message = "set " + entry.alias + " as default " + entry.platform + " device"
    } else {
        let platform = normalizeHapDevicePlatform(options.platform)
        if (!validHapDeviceAlias(options.alias)) {
            result.status = "invalid-alias"
            result.message = "alias must use letters, digits, dot, dash, or underscore"
            return result
        }
        if (!hapDevicePlatformSupported(platform)) {
            result.status = "unsupported-platform"
            result.message = "device platform must be harmonyos, android, or ios"
            return result
        }
        if (trimAsciiText(options.target).size == 0) {
            result.status = "missing-target"
            result.message = "device target is required"
            return result
        }
        upsertHapDeviceRegistryEntry(registry, options.alias, platform, options.target, options.name)
        result.message = "saved device alias " + options.alias
    }
    writeHapDeviceRegistry(options, registry, result)
    result
}

func validHapDeviceAlias(alias: String): Bool {
    let runes = alias.toRuneArray()
    if (runes.size == 0) {
        return false
    }
    for (rune in runes) {
        let value = UInt32(rune)
        let allowed = (value >= 48 && value <= 57) || (value >= 65 && value <= 90) ||
            (value >= 97 && value <= 122) || value == 45 || value == 46 || value == 95
        if (!allowed) {
            return false
        }
    }
    true
}

func hapDevicePlatformSupported(platform: String): Bool {
    platform == "harmonyos" || platform == "android" || platform == "ios"
}

func findHapDeviceRegistryEntry(registry: HapDeviceRegistry, alias: String): HapDeviceEntry {
    for (entry in registry.entries) {
        if (entry.alias == alias) {
            return entry
        }
    }
    HapDeviceEntry()
}

func upsertHapDeviceRegistryEntry(registry: HapDeviceRegistry, alias: String, platform: String, target: String, name: String): Unit {
    for (entry in registry.entries) {
        if (entry.alias == alias) {
            entry.platform = platform
            entry.target = target
            entry.name = if (name.size > 0) { name } else { target }
            entry.saved = true
            entry.source = "registry"
            entry.mutable = true
            return
        }
    }
    let entry = HapDeviceEntry()
    entry.alias = alias
    entry.platform = platform
    entry.target = target
    entry.name = if (name.size > 0) { name } else { target }
    entry.saved = true
    entry.source = "registry"
    entry.mutable = true
    registry.entries.add(entry)
}

func removeHapDeviceAlias(registry: HapDeviceRegistry, alias: String): Bool {
    let kept = ArrayList<HapDeviceEntry>()
    var removed = false
    for (entry in registry.entries) {
        if (entry.alias == alias) {
            removed = true
        } else {
            kept.add(entry)
        }
    }
    if (!removed) {
        return false
    }
    registry.entries.clear()
    for (entry in kept) {
        registry.entries.add(entry)
    }
    if (registry.defaultHarmony == alias) { registry.defaultHarmony = "" }
    if (registry.defaultAndroid == alias) { registry.defaultAndroid = "" }
    if (registry.defaultIos == alias) { registry.defaultIos = "" }
    true
}

func renameHapDeviceAlias(registry: HapDeviceRegistry, oldAlias: String, newAlias: String): Bool {
    if (hapDeviceEntryAliasExists(registry.entries, newAlias)) {
        return false
    }
    for (entry in registry.entries) {
        if (entry.alias == oldAlias) {
            entry.alias = newAlias
            if (registry.defaultHarmony == oldAlias) { registry.defaultHarmony = newAlias }
            if (registry.defaultAndroid == oldAlias) { registry.defaultAndroid = newAlias }
            if (registry.defaultIos == oldAlias) { registry.defaultIos = newAlias }
            return true
        }
    }
    false
}

func writeHapDeviceRegistry(options: HapDeviceOptions, registry: HapDeviceRegistry, result: HapDeviceWriteResult): Unit {
    let candidates = hapDeviceRegistryCandidates(options)
    for (candidate in candidates) {
        try {
            let dir = parentPath(candidate)
            if (dir.size > 0 && !exists(dir)) {
                Directory.create(dir, recursive: true)
            }
            let backupPath = candidate + ".hap-backup"
            if (exists(candidate)) {
                File.writeTo(backupPath, File.readFrom(candidate))
                result.backupPath = backupPath
                result.backupWritten = true
            }
            File.writeTo(candidate, renderHapDeviceRegistryToml(registry).toArray())
            result.ok = true
            result.status = "device-registry-written"
            result.path = candidate
            result.pathSource = hapDeviceRegistryPathSource(options, candidate)
            result.registryWritten = true
            return
        } catch (_: Exception) {
            result.status = "device-registry-write-fallback"
        }
    }
    result.ok = false
    result.status = "no-writable-device-registry"
    result.message = "no writable Hap device registry path"
}

public func renderHapDeviceRegistryToml(registry: HapDeviceRegistry): String {
    let out = StringBuilder()
    out.append("schema = \"happub-hapcli-device-registry-v0\"\n\n")
    out.append("[defaults]\n")
    out.append("harmonyos = \"" + escapeHapToml(registry.defaultHarmony) + "\"\n")
    out.append("android = \"" + escapeHapToml(registry.defaultAndroid) + "\"\n")
    out.append("ios = \"" + escapeHapToml(registry.defaultIos) + "\"\n")
    for (entry in registry.entries) {
        out.append("\n[[devices]]\n")
        out.append("alias = \"" + escapeHapToml(entry.alias) + "\"\n")
        out.append("platform = \"" + escapeHapToml(entry.platform) + "\"\n")
        out.append("target = \"" + escapeHapToml(entry.target) + "\"\n")
        out.append("name = \"" + escapeHapToml(entry.name) + "\"\n")
    }
    out.toString()
}

func escapeHapToml(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ").replace("\r", " ")
}

public func renderHapDeviceSnapshotHuman(snapshot: HapDeviceSnapshot): String {
    let out = StringBuilder()
    out.append("Hap devices\n")
    out.append("Project: " + snapshot.project + " (" + snapshot.projectKind + ")\n")
    out.append("Registry: " + if (snapshot.registryPath.size > 0) { snapshot.registryPath } else { "unavailable" } + "\n\n")
    if (snapshot.entries.size == 0) {
        out.append("No devices found. Connect a device or run `hap device set --alias <name> --platform <kind> --target <id>`.\n")
    } else {
        out.append("  Alias          Platform    Status              Name / Target\n")
        out.append("  -------------  ----------  ------------------  ------------------------------\n")
        for (entry in snapshot.entries) {
            let alias = if (entry.alias.size > 0) { entry.alias + if (entry.isDefault) { "*" } else { "" } } else { "-" }
            out.append("  " + padHapDeviceText(alias, 13) + "  " + padHapDeviceText(entry.platform, 10) + "  " + padHapDeviceText(entry.status, 18) + "  " + entry.name + " [" + entry.target + "]\n")
        }
    }
    if (snapshot.backendNotes.size > 0) {
        out.append("\nBackends:\n")
        for (note in snapshot.backendNotes) {
            out.append("- " + note + "\n")
        }
    }
    out.append("\nManage aliases: hap device set\n")
    out.toString()
}

func padHapDeviceText(value: String, width: Int64): String {
    let runes = value.toRuneArray()
    if (runes.size >= width) {
        return value
    }
    let out = StringBuilder()
    out.append(value)
    var i = runes.size
    while (i < width) {
        out.append(" ")
        i += 1
    }
    out.toString()
}

public func renderHapDeviceSnapshotJson(snapshot: HapDeviceSnapshot): String {
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-device-list-v0\",\n")
    out.append("  \"ok\": true,\n")
    out.append("  \"mode\": \"project-aware-device-probe\",\n")
    out.append("  \"project\": \"" + escapeJson(snapshot.project) + "\",\n")
    out.append("  \"projectKind\": \"" + escapeJson(snapshot.projectKind) + "\",\n")
    out.append("  \"selectionStatus\": \"" + escapeJson(snapshot.selectionStatus) + "\",\n")
    out.append("  \"registryPath\": \"" + escapeJson(snapshot.registryPath) + "\",\n")
    out.append("  \"registryPathSource\": \"" + escapeJson(snapshot.registryPathSource) + "\",\n")
    out.append("  \"requestedPlatforms\": ")
    appendProjectJsonStringArray(out, snapshot.requestedPlatforms)
    out.append(",\n")
    out.append("  \"devices\": [\n")
    var i: Int64 = 0
    while (i < snapshot.entries.size) {
        let entry = snapshot.entries[i]
        out.append("    {\"alias\": \"" + escapeJson(entry.alias) + "\", \"platform\": \"" + escapeJson(entry.platform) + "\", \"target\": \"" + escapeJson(entry.target) + "\", \"name\": \"" + escapeJson(entry.name) + "\", \"status\": \"" + escapeJson(entry.status) + "\", \"backend\": \"" + escapeJson(entry.backend) + "\", \"source\": \"" + escapeJson(entry.source) + "\", \"saved\": " + boolJson(entry.saved) + ", \"connected\": " + boolJson(entry.connected) + ", \"default\": " + boolJson(entry.isDefault) + "}")
        if (i + 1 < snapshot.entries.size) { out.append(",") }
        out.append("\n")
        i += 1
    }
    out.append("  ],\n")
    out.append("  \"backendNotes\": ")
    appendProjectJsonStringArray(out, snapshot.backendNotes)
    out.append(",\n")
    out.append("  \"probeRequested\": " + boolJson(snapshot.probeRequested) + ",\n")
    out.append("  \"executionActionTaken\": " + boolJson(snapshot.probeActionTaken) + ",\n")
    out.append("  \"mutationActionTaken\": false,\n")
    out.append("  \"networkScanActionTaken\": false,\n")
    out.append("  \"nonPromises\": [\"device probe only runs the project-selected local tool backends\", \"no LAN scan is performed\", \"saved aliases do not prove a device is currently connected\"]\n")
    out.append("}")
    out.toString()
}

func renderHapDeviceWriteResultHuman(options: HapDeviceOptions, result: HapDeviceWriteResult): String {
    if (result.ok) {
        let out = StringBuilder()
        out.append("Hap device updated\n")
        out.append(result.message + "\n")
        out.append("Registry: " + result.path + "\n")
        if (result.backupWritten) {
            out.append("Backup: " + result.backupPath + "\n")
        }
        return out.toString()
    }
    "Hap device failed\nStatus: " + result.status + "\n" + result.message + "\n"
}

func renderHapDeviceWriteResultJson(options: HapDeviceOptions, result: HapDeviceWriteResult): String {
    "{\n" +
    "  \"schema\": \"happub-hapcli-device-set-v0\",\n" +
    "  \"ok\": " + boolJson(result.ok) + ",\n" +
    "  \"status\": \"" + escapeJson(result.status) + "\",\n" +
    "  \"project\": \"" + escapeJson(options.project) + "\",\n" +
    "  \"registryPath\": \"" + escapeJson(result.path) + "\",\n" +
    "  \"registryPathSource\": \"" + escapeJson(result.pathSource) + "\",\n" +
    "  \"backupPath\": \"" + escapeJson(result.backupPath) + "\",\n" +
    "  \"backupWritten\": " + boolJson(result.backupWritten) + ",\n" +
    "  \"mutationActionTaken\": " + boolJson(result.registryWritten) + ",\n" +
    "  \"message\": \"" + escapeJson(result.message) + "\"\n" +
    "}"
}
