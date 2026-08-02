package hapcli

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{Directory, File, Path, exists}
import std.process.executeWithOutput
import std.time.DateTime

class HapKmpIosDeviceResolution {
    var selectedDevice: String = ""
    var observedDevice: String = ""
    var xcodeDeviceId: String = ""
    var deviceName: String = ""
    var status: String = "ios-device-not-found"

    init() {}
}

class HapKmpIosConfig {
    var projectFile: String = "iosApp.xcodeproj"
    var iosDirectory: String = ""
    var scheme: String = "iosApp"
    var configuration: String = "Debug"
    var developmentTeam: String = ""
    var developmentTeamSource: String = "none"
    var derivedDataPath: String = ""
    var signingIdentityCount: Int64 = 0

    init() {}
}

class HapKmpIosExecutionState {
    var ok: Bool = false
    var status: String = "not-started"
    var artifactMode: String = "source-build"
    var artifact: String = ""
    var selectedDevice: String = ""
    var observedDevice: String = ""
    var xcodeDeviceId: String = ""
    var bundleId: String = ""
    var exitCode: Int64 = 2
    var sourceBuildActionTaken: Bool = false
    var installActionTaken: Bool = false
    var launchActionTaken: Bool = false
    var installResultPath: String = ""
    var installResultOutcome: String = ""
    var launchResultPath: String = ""
    var launchResultOutcome: String = ""
    var signingAutomationAttempted: Bool = false
    var allowProvisioningUpdates: Bool = false
    var developmentTeam: String = ""
    var developmentTeamSource: String = "none"
    var signingIdentityCount: Int64 = 0
    var scheme: String = ""
    var configuration: String = "Debug"
    var derivedDataPath: String = ""

    init() {}
}

public func runKmpIosDevExecution(options: HapProjectActionOptions): String {
    let project = trimTrailingSlash(options.project)
    let logDir = if (options.logDir.size > 0) {
        trimTrailingSlash(options.logDir)
    } else {
        project + "/.hapData/logs/kmp-ios-dev"
    }
    if (!exists(logDir)) {
        Directory.create(logDir, recursive: true)
    }
    let stdoutLog = logDir + "/kmp-ios-dev.stdout.log"
    let stderrLog = logDir + "/kmp-ios-dev.stderr.log"
    let stdoutText = StringBuilder()
    let stderrText = StringBuilder()
    let state = HapKmpIosExecutionState()
    state.artifactMode = if (options.useOld || options.artifact.size > 0) { "old-artifact" } else { "source-build" }

    if (!isProgramResolvable("xcrun")) {
        state.status = "missing-xcrun"
        return renderKmpIosExecutionJson(options, state, stdoutLog, stderrLog, logDir)
    }

    File.writeTo(harmonyCurrentStepPath(logDir), "selecting iOS device".toArray())
    let deviceResolution = resolveKmpIosDevice(options, stdoutText, stderrText)
    if (deviceResolution.selectedDevice.size == 0) {
        state.status = deviceResolution.status
        state.observedDevice = deviceResolution.observedDevice
        state.xcodeDeviceId = deviceResolution.xcodeDeviceId
        writeKmpIosLogs(stdoutLog, stderrLog, stdoutText, stderrText)
        return renderKmpIosExecutionJson(options, state, stdoutLog, stderrLog, logDir)
    }
    let device = deviceResolution.selectedDevice
    state.selectedDevice = device
    state.observedDevice = deviceResolution.observedDevice
    state.xcodeDeviceId = deviceResolution.xcodeDeviceId

    let config = resolveKmpIosConfig(options)
    state.developmentTeam = config.developmentTeam
    state.developmentTeamSource = config.developmentTeamSource
    state.signingIdentityCount = config.signingIdentityCount
    state.scheme = config.scheme
    state.configuration = config.configuration
    state.derivedDataPath = config.derivedDataPath

    if (state.artifactMode == "old-artifact") {
        state.artifact = resolveKmpIosOldArtifact(options, config)
        if (state.artifact.size == 0 || !exists(state.artifact)) {
            state.status = "missing-signed-app-artifact"
            writeKmpIosLogs(stdoutLog, stderrLog, stdoutText, stderrText)
            return renderKmpIosExecutionJson(options, state, stdoutLog, stderrLog, logDir)
        }
    } else {
        if (!isProgramResolvable("xcodebuild")) {
            state.status = "missing-xcodebuild"
            writeKmpIosLogs(stdoutLog, stderrLog, stdoutText, stderrText)
            return renderKmpIosExecutionJson(options, state, stdoutLog, stderrLog, logDir)
        }
        if (deviceResolution.xcodeDeviceId.size == 0) {
            state.status = "missing-xcode-device-udid"
            writeKmpIosLogs(stdoutLog, stderrLog, stdoutText, stderrText)
            return renderKmpIosExecutionJson(options, state, stdoutLog, stderrLog, logDir)
        }
        if (!runKmpIosSourceBuild(options, config, deviceResolution, state, stdoutText, stderrText, logDir)) {
            writeKmpIosLogs(stdoutLog, stderrLog, stdoutText, stderrText)
            return renderKmpIosExecutionJson(options, state, stdoutLog, stderrLog, logDir)
        }
    }

    state.bundleId = readIosAppBundleIdentifier(state.artifact)
    if (state.bundleId.size == 0) {
        state.status = "missing-ios-bundle-identifier"
        writeKmpIosLogs(stdoutLog, stderrLog, stdoutText, stderrText)
        return renderKmpIosExecutionJson(options, state, stdoutLog, stderrLog, logDir)
    }

    File.writeTo(harmonyCurrentStepPath(logDir), "installing iOS application".toArray())
    state.installActionTaken = true
    state.installResultPath = kmpIosDeviceCtlResultPath(logDir, "install")
    let (installCode, installOut, installErr) = executeWithOutput("xcrun", ["devicectl", "device", "install", "app", "--device", device, "--json-output", state.installResultPath, state.artifact], workingDirectory: Path(project))
    appendKmpIosCommandOutput(stdoutText, stderrText, "install", installOut, installErr)
    state.installResultOutcome = kmpIosDeviceCtlOutcome(state.installResultPath)
    if (installCode != 0 || state.installResultOutcome != "success") {
        state.status = "ios-app-install-failed"
        state.exitCode = if (installCode == 0) { 1 } else { installCode }
        writeKmpIosLogs(stdoutLog, stderrLog, stdoutText, stderrText)
        return renderKmpIosExecutionJson(options, state, stdoutLog, stderrLog, logDir)
    }

    File.writeTo(harmonyCurrentStepPath(logDir), "launching iOS application".toArray())
    state.launchActionTaken = true
    state.launchResultPath = kmpIosDeviceCtlResultPath(logDir, "launch")
    let (launchCode, launchOut, launchErr) = executeWithOutput("xcrun", ["devicectl", "device", "process", "launch", "--device", device, "--json-output", state.launchResultPath, state.bundleId], workingDirectory: Path(project))
    appendKmpIosCommandOutput(stdoutText, stderrText, "launch", launchOut, launchErr)
    writeKmpIosLogs(stdoutLog, stderrLog, stdoutText, stderrText)
    File.writeTo(harmonyLastStepPath(logDir), "launching iOS application".toArray())
    state.launchResultOutcome = kmpIosDeviceCtlOutcome(state.launchResultPath)
    let ok = launchCode == 0 && state.launchResultOutcome == "success"
    state.ok = ok
    state.status = if (ok) { if (state.artifactMode == "source-build") { "kmp-ios-source-build-dev-succeeded" } else { "kmp-ios-old-artifact-dev-succeeded" } } else { "ios-app-launch-failed" }
    state.exitCode = if (ok) { 0 } else if (launchCode == 0) { 1 } else { launchCode }
    renderKmpIosExecutionJson(options, state, stdoutLog, stderrLog, logDir)
}

func kmpIosDeviceCtlResultPath(logDir: String, action: String): String {
    trimTrailingSlash(logDir) + "/devicectl-" + action + "-" + DateTime.nowUTC().toUnixTimeStamp().toMilliseconds().toString() + ".json"
}

public func kmpIosDeviceCtlOutcome(path: String): String {
    if (path.size == 0 || !exists(path)) {
        return ""
    }
    try {
        extractFlatJsonString(String.fromUtf8(File.readFrom(path)), "outcome")
    } catch (_: Exception) {
        ""
    }
}

public func runKmpIosArtifactDevExecution(options: HapProjectActionOptions): String {
    options.useOld = true
    runKmpIosDevExecution(options)
}

func resolveKmpIosDevice(options: HapProjectActionOptions, stdoutText: StringBuilder, stderrText: StringBuilder): HapKmpIosDeviceResolution {
    var requestedDevice = options.device
    if (requestedDevice.size == 0 || requestedDevice == "auto") {
        let defaultAlias = resolveHapDefaultDeviceAlias(options.project, "ios")
        if (defaultAlias.size > 0) {
            requestedDevice = defaultAlias
        }
    }
    if (requestedDevice.size > 0 && requestedDevice != "auto") {
        let resolvedDevice = resolveHapDeviceAlias(options.project, requestedDevice, "ios")
        let explicit = HapKmpIosDeviceResolution()
        explicit.selectedDevice = resolvedDevice
        explicit.observedDevice = resolvedDevice
        explicit.status = "ios-device-selected-explicitly"
        enrichKmpIosDeviceDetails(explicit, resolvedDevice, stdoutText, stderrText)
        return explicit
    }
    let (exitCode, stdoutBytes, stderrBytes) = executeWithOutput("xcrun", ["devicectl", "list", "devices"])
    appendKmpIosCommandOutput(stdoutText, stderrText, "device-list", stdoutBytes, stderrBytes)
    if (exitCode != 0) {
        let failed = HapKmpIosDeviceResolution()
        failed.status = "ios-device-list-failed"
        return failed
    }
    let resolution = parseKmpIosDeviceList(String.fromUtf8(stdoutBytes))
    if (resolution.selectedDevice.size > 0) {
        enrichKmpIosDeviceDetails(resolution, resolution.selectedDevice, stdoutText, stderrText)
    } else if (resolution.status == "ios-device-unavailable" && resolution.observedDevice.size > 0) {
        enrichKmpIosDeviceDetails(resolution, resolution.observedDevice, stdoutText, stderrText)
    }
    resolution
}

func enrichKmpIosDeviceDetails(resolution: HapKmpIosDeviceResolution, device: String, stdoutText: StringBuilder, stderrText: StringBuilder): Unit {
    let (detailCode, detailOut, detailErr) = executeWithOutput("xcrun", ["devicectl", "device", "info", "details", "--device", device])
    appendKmpIosCommandOutput(stdoutText, stderrText, "device-details", detailOut, detailErr)
    if (detailCode != 0) {
        return
    }
    let details = String.fromUtf8(detailOut) + "\n" + String.fromUtf8(detailErr)
    let identifier = extractKmpIosDetailValue(details, "identifier:")
    let udid = extractKmpIosDetailValue(details, "udid:")
    let name = extractKmpIosDetailValue(details, "name:")
    if (identifier.size > 0) {
        resolution.observedDevice = identifier
        if (resolution.selectedDevice.size > 0) {
            resolution.selectedDevice = identifier
        }
    }
    resolution.xcodeDeviceId = udid
    resolution.deviceName = name
    if (resolution.selectedDevice.size == 0) {
        resolution.status = classifyKmpIosUnavailableDetails(details)
    }
}

func extractKmpIosDetailValue(text: String, marker: String): String {
    for (line in splitAsciiLines(text)) {
        let trimmed = trimAsciiText(line)
        let markerIndex = indexOfText(trimmed, marker)
        if (markerIndex >= 0) {
            return trimAsciiText(substringFrom(trimmed, markerIndex + Int64(marker.size)))
        }
    }
    ""
}

func parseKmpIosDeviceList(text: String): HapKmpIosDeviceResolution {
    let resolution = HapKmpIosDeviceResolution()
    var selected = ""
    var observed = ""
    var observedCount: Int64 = 0
    for (line in splitAsciiLines(text)) {
        var lineDevice = ""
        for (token in trimAsciiText(line).split(" ")) {
            let candidate = trimAsciiText(token)
            if (isUuidShaped(candidate)) {
                lineDevice = candidate
                break
            }
        }
        if (lineDevice.size == 0) {
            continue
        }
        observedCount += 1
        if (observed.size == 0) {
            observed = lineDevice
        }
        let availablePaired = containsText(line, "available (paired)") ||
            (!containsText(line, "unavailable") && containsText(line, "available") && containsText(line, "paired"))
        if (availablePaired) {
            if (selected.size > 0 && selected != lineDevice) {
                resolution.observedDevice = observed
                resolution.status = "ios-device-selection-ambiguous"
                return resolution
            }
            selected = lineDevice
        }
    }
    resolution.observedDevice = observed
    if (selected.size > 0) {
        resolution.selectedDevice = selected
        resolution.observedDevice = selected
        resolution.status = "ios-device-selected"
    } else if (observedCount > 0) {
        resolution.status = "ios-device-unavailable"
    }
    resolution
}

func classifyKmpIosUnavailableDetails(text: String): String {
    if (containsText(text, "pairingState: unpaired")) {
        return "ios-device-not-paired"
    }
    if (containsText(text, "ddiServicesAvailable: false") && containsText(text, "tunnelState: unavailable")) {
        return "ios-device-coredevice-services-unavailable"
    }
    if (containsText(text, "tunnelState: unavailable")) {
        return "ios-device-tunnel-unavailable"
    }
    "ios-device-unavailable"
}

func resolveKmpIosConfig(options: HapProjectActionOptions): HapKmpIosConfig {
    let project = trimTrailingSlash(options.project)
    let config = HapKmpIosConfig()
    config.iosDirectory = project + "/iosApp"
    config.scheme = inferKmpIosScheme(project)
    config.derivedDataPath = "/private/tmp/hap-kmp-ios-" + basenameText(project)
    config.developmentTeam = inferKmpIosProjectDevelopmentTeam(project)
    if (config.developmentTeam.size > 0) {
        config.developmentTeamSource = "xcode-project"
    }

    let configPath = findHarmonyConfigPath(options)
    if (configPath.size > 0 && exists(configPath)) {
        let text = String.fromUtf8(File.readFrom(configPath))
        config.scheme = tomlStringOrDefault(text, "iosScheme", config.scheme)
        config.configuration = tomlStringOrDefault(text, "iosConfiguration", config.configuration)
        let configuredTeam = tomlStringOrDefault(text, "iosDevelopmentTeam", config.developmentTeam)
        if (configuredTeam != config.developmentTeam) {
            config.developmentTeamSource = "config-file"
        }
        config.developmentTeam = configuredTeam
        config.derivedDataPath = tomlStringOrDefault(text, "iosDerivedDataPath", config.derivedDataPath)
    }
    applyKmpIosConfigEnv(config)
    if (options.iosScheme.size > 0) {
        config.scheme = options.iosScheme
    }
    if (options.iosConfiguration.size > 0) {
        config.configuration = options.iosConfiguration
    }
    if (options.iosDevelopmentTeam.size > 0) {
        config.developmentTeam = options.iosDevelopmentTeam
        config.developmentTeamSource = "argv"
    }
    if (options.iosDerivedDataPath.size > 0) {
        config.derivedDataPath = options.iosDerivedDataPath
    }

    let identityTeams = resolveKmpIosIdentityTeams()
    config.signingIdentityCount = Int64(identityTeams.size)
    if (identityTeams.size == 1 && !containsKmpIosString(identityTeams, config.developmentTeam)) {
        config.developmentTeam = identityTeams[0]
        config.developmentTeamSource = "local-signing-identity"
    } else if (containsKmpIosString(identityTeams, config.developmentTeam)) {
        config.developmentTeamSource = "matching-local-signing-identity"
    }
    config
}

func applyKmpIosConfigEnv(config: HapKmpIosConfig): Unit {
    match (getVariable("HAP_IOS_SCHEME")) {
        case Some(value) => if (value.size > 0) { config.scheme = value }
        case None => ()
    }
    match (getVariable("HAP_IOS_CONFIGURATION")) {
        case Some(value) => if (value.size > 0) { config.configuration = value }
        case None => ()
    }
    match (getVariable("HAP_IOS_DEVELOPMENT_TEAM")) {
        case Some(value) =>
            if (value.size > 0) {
                config.developmentTeam = value
                config.developmentTeamSource = "process-env"
            }
        case None => ()
    }
    match (getVariable("HAP_IOS_DERIVED_DATA_PATH")) {
        case Some(value) => if (value.size > 0) { config.derivedDataPath = value }
        case None => ()
    }
}

func inferKmpIosProjectDevelopmentTeam(project: String): String {
    let pbx = trimTrailingSlash(project) + "/iosApp/iosApp.xcodeproj/project.pbxproj"
    if (!exists(pbx)) {
        return ""
    }
    for (line in splitAsciiLines(String.fromUtf8(File.readFrom(pbx)))) {
        let trimmed = trimAsciiText(line)
        if (startsWithText(trimmed, "DEVELOPMENT_TEAM =")) {
            var value = trimAsciiText(substringFrom(trimmed, 18))
            if (endsWithText(value, ";")) {
                value = substringTo(value, Int64(value.size - 1))
            }
            if (value.size > 0) {
                return value
            }
        }
    }
    ""
}

func resolveKmpIosIdentityTeams(): ArrayList<String> {
    let teams = ArrayList<String>()
    if (!isProgramResolvable("security")) {
        return teams
    }
    let (_, stdoutBytes, stderrBytes) = executeWithOutput("security", ["find-identity", "-v", "-p", "codesigning"])
    for (line in splitAsciiLines(String.fromUtf8(stdoutBytes) + "\n" + String.fromUtf8(stderrBytes))) {
        if (!containsText(line, "Apple Development")) {
            continue
        }
        let team = extractLastParenthesizedText(line)
        if (team.size > 0 && !containsKmpIosString(teams, team)) {
            teams.add(team)
        }
    }
    teams
}

func extractLastParenthesizedText(text: String): String {
    let runes = text.toRuneArray()
    var open: Int64 = -1
    var close: Int64 = -1
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == r'(') {
            open = i
        } else if (runes[i] == r')' && open >= 0) {
            close = i
        }
        i += 1
    }
    if (open < 0 || close <= open + 1) {
        return ""
    }
    trimAsciiText(substringRange(text, open + 1, close))
}

func containsKmpIosString(values: ArrayList<String>, expected: String): Bool {
    if (expected.size == 0) {
        return false
    }
    for (value in values) {
        if (value == expected) {
            return true
        }
    }
    false
}

func runKmpIosSourceBuild(
    options: HapProjectActionOptions,
    config: HapKmpIosConfig,
    device: HapKmpIosDeviceResolution,
    state: HapKmpIosExecutionState,
    stdoutText: StringBuilder,
    stderrText: StringBuilder,
    logDir: String
): Bool {
    if (!exists(config.iosDirectory) || !exists(config.iosDirectory + "/" + config.projectFile + "/project.pbxproj")) {
        state.status = "missing-kmp-ios-xcode-project"
        return false
    }
    if (config.scheme.size == 0 || config.scheme == "<scheme>") {
        state.status = "missing-kmp-ios-scheme"
        return false
    }
    let javaHome = resolveKmpJavaHome()
    if (javaHome.home.size == 0) {
        state.status = "missing-jdk17"
        return false
    }
    let home = kmpIosEnvOrDefault("HOME", "")
    if (home.size == 0) {
        state.status = "missing-home-for-konan-data"
        return false
    }
    let user = kmpIosEnvOrDefault("USER", "hap")
    let daemonDir = "/tmp/kotlin-daemon-" + user
    if (!exists(daemonDir)) {
        Directory.create(daemonDir, recursive: true)
    }
    if (!exists(config.derivedDataPath)) {
        Directory.create(config.derivedDataPath, recursive: true)
    }

    let args = ArrayList<String>()
    args.add("JAVA_HOME=" + javaHome.home)
    args.add("KONAN_DATA_DIR=" + trimTrailingSlash(home) + "/.gradle/.konan")
    args.add("KOTLIN_DAEMON_DATA_DIR=" + daemonDir)
    args.add("xcodebuild")
    args.add("-project")
    args.add(config.projectFile)
    args.add("-scheme")
    args.add(config.scheme)
    args.add("-sdk")
    args.add("iphoneos")
    args.add("-configuration")
    args.add(config.configuration)
    args.add("-destination")
    args.add("id=" + device.xcodeDeviceId)
    args.add("-derivedDataPath")
    args.add(config.derivedDataPath)
    args.add("-allowProvisioningUpdates")
    args.add("-allowProvisioningDeviceRegistration")
    args.add("CODE_SIGN_STYLE=Automatic")
    args.add("CODE_SIGNING_ALLOWED=YES")
    if (config.developmentTeam.size > 0) {
        args.add("DEVELOPMENT_TEAM=" + config.developmentTeam)
    }
    args.add("build")

    File.writeTo(harmonyCurrentStepPath(logDir), "building and signing latest KMP iOS application".toArray())
    state.sourceBuildActionTaken = true
    state.signingAutomationAttempted = true
    state.allowProvisioningUpdates = true
    let assignments = [
        "JAVA_HOME=" + javaHome.home,
        "KONAN_DATA_DIR=" + trimTrailingSlash(home) + "/.gradle/.konan",
        "KOTLIN_DAEMON_DATA_DIR=" + daemonDir
    ]
    let xcodeArgs = ArrayList<String>()
    var commandStarted = false
    for (arg in args) {
        if (!commandStarted && arg == "xcodebuild") {
            commandStarted = true
            continue
        }
        if (commandStarted) {
            xcodeArgs.add(arg)
        }
    }
    let command = resolveHapNetworkCommandWithAssignments(options.networkMode, assignments, "xcodebuild", xcodeArgs.toArray())
    let (buildCode, buildOut, buildErr) = executeWithOutput(command.program, command.args.toArray(), workingDirectory: Path(config.iosDirectory))
    appendKmpIosCommandOutput(stdoutText, stderrText, "xcode-source-build", buildOut, buildErr)
    let combined = String.fromUtf8(buildOut) + "\n" + String.fromUtf8(buildErr)
    if (buildCode != 0 || !containsText(combined, "BUILD SUCCEEDED")) {
        state.status = classifyKmpIosSourceBuildFailure(combined)
        state.exitCode = if (buildCode == 0) { 1 } else { buildCode }
        return false
    }
    state.artifact = findKmpIosAppArtifact(config.derivedDataPath + "/Build/Products/" + config.configuration + "-iphoneos")
    if (state.artifact.size == 0) {
        state.status = "ios-built-artifact-not-found"
        state.exitCode = 1
        return false
    }
    true
}

func classifyKmpIosSourceBuildFailure(text: String): String {
    if (containsText(text, "No Accounts") || containsText(text, "No account for team") || containsText(text, "add an account")) {
        return "ios-signing-account-unavailable"
    }
    if (containsText(text, "No signing certificate") || containsText(text, "signing certificate \"Apple Development\"") || containsText(text, "0 valid identities")) {
        return "ios-signing-identity-unavailable"
    }
    if (containsText(text, "No profiles for") || containsText(text, "requires a provisioning profile") || containsText(text, "Provisioning profile")) {
        return "ios-provisioning-profile-unavailable"
    }
    if (containsText(text, "requires a development team") || containsText(text, "DEVELOPMENT_TEAM")) {
        return "ios-signing-team-unavailable"
    }
    if (containsText(text, "Unable to find a destination") || containsText(text, "Device is busy") || containsText(text, "destination timeout")) {
        return "ios-xcode-destination-unavailable"
    }
    if (containsText(text, "SDK") && containsText(text, "cannot be located")) {
        return "ios-sdk-unavailable"
    }
    "ios-source-build-failed"
}

func resolveKmpIosOldArtifact(options: HapProjectActionOptions, config: HapKmpIosConfig): String {
    if (options.artifact.size > 0) {
        return options.artifact
    }
    let projectOutput = trimTrailingSlash(options.project) + "/iosApp/build/Build/Products/" + config.configuration + "-iphoneos"
    findKmpIosAppArtifact(projectOutput)
}

func findKmpIosAppArtifact(directory: String): String {
    if (!exists(directory)) {
        return ""
    }
    var selected = ""
    try {
        let entries = Directory.readFrom(directory)
        for (entry in entries) {
            let path = entry.path.toString()
            if (entry.isDirectory() && endsWithText(basenameText(path), ".app")) {
                if (selected.size > 0 && selected != path) {
                    return ""
                }
                selected = path
            }
        }
    } catch (_: Exception) {
        return ""
    }
    selected
}

func kmpIosEnvOrDefault(name: String, fallback: String): String {
    match (getVariable(name)) {
        case Some(value) => if (value.size > 0) { value } else { fallback }
        case None => fallback
    }
}

func isUuidShaped(value: String): Bool {
    let parts = value.split("-")
    parts.size == 5 && parts[0].size == 8 && parts[1].size == 4 && parts[2].size == 4 && parts[3].size == 4 && parts[4].size == 12
}

func readIosAppBundleIdentifier(artifact: String): String {
    let plistPath = trimTrailingSlash(artifact) + "/Info.plist"
    if (!exists(plistPath)) {
        return ""
    }
    if (exists("/usr/libexec/PlistBuddy")) {
        let (exitCode, stdoutBytes, _) = executeWithOutput("/usr/libexec/PlistBuddy", ["-c", "Print :CFBundleIdentifier", plistPath])
        if (exitCode == 0) {
            return trimAsciiText(String.fromUtf8(stdoutBytes))
        }
    }
    let text = String.fromUtf8(File.readFrom(plistPath))
    let keyIndex = indexOfText(text, "<key>CFBundleIdentifier</key>")
    if (keyIndex >= 0) {
        let rest = substringFrom(text, keyIndex)
        let start = indexOfText(rest, "<string>")
        if (start >= 0) {
            let valueRest = substringFrom(rest, start + 8)
            let end = indexOfText(valueRest, "</string>")
            if (end >= 0) {
                let value = trimAsciiText(substringTo(valueRest, end))
                if (value.size > 0 && !containsText(value, "$(")) {
                    return value
                }
            }
        }
    }
    ""
}

func appendKmpIosCommandOutput(stdoutText: StringBuilder, stderrText: StringBuilder, label: String, stdoutBytes: Array<Byte>, stderrBytes: Array<Byte>): Unit {
    stdoutText.append("[" + label + "]\n" + String.fromUtf8(stdoutBytes) + "\n")
    stderrText.append("[" + label + "]\n" + String.fromUtf8(stderrBytes) + "\n")
}

func writeKmpIosLogs(stdoutLog: String, stderrLog: String, stdoutText: StringBuilder, stderrText: StringBuilder): Unit {
    File.writeTo(stdoutLog, stdoutText.toString().toArray())
    File.writeTo(stderrLog, stderrText.toString().toArray())
}

func renderKmpIosExecutionJson(options: HapProjectActionOptions, state: HapKmpIosExecutionState, stdoutLog: String, stderrLog: String, logDir: String): String {
    let diagnosis = if (state.ok) {
        if (state.artifactMode == "source-build") { "latest KMP iOS source built, automatically signed, installed, and launched" } else { "existing signed iOS application installed and launched" }
    } else if (state.status == "missing-signed-app-artifact") {
        "provide a signed .app with --artifact or run once without --useOld to build the latest source"
    } else if (state.status == "ios-device-not-found") {
        "connect exactly one paired iOS device or select one with --device"
    } else if (state.status == "ios-device-selection-ambiguous") {
        "multiple paired iOS devices are available; select one with --device"
    } else if (state.status == "ios-device-not-paired") {
        "pair and trust the iOS device before rerunning hap dev"
    } else if (state.status == "ios-device-coredevice-services-unavailable") {
        "the paired device is offline or CoreDevice DDI/tunnel services are not ready; reconnect and unlock it, then retry after Xcode Devices and Simulators shows it available"
    } else if (state.status == "ios-device-tunnel-unavailable" || state.status == "ios-device-unavailable") {
        "the paired iOS device is currently unavailable; reconnect and unlock it before rerunning hap dev"
    } else if (state.status == "ios-device-list-failed") {
        "CoreDevice enumeration failed; inspect logs and verify xcrun devicectl can list devices"
    } else if (state.status == "missing-xcode-device-udid") {
        "CoreDevice is selected but its Xcode UDID could not be read; inspect devicectl device details"
    } else if (state.status == "missing-xcodebuild") {
        "install or select Xcode command-line tools before rebuilding KMP iOS source"
    } else if (state.status == "missing-jdk17") {
        "install JDK 17 or set JAVA_HOME to a valid JDK 17 before rebuilding the KMP framework"
    } else if (state.status == "ios-signing-account-unavailable") {
        "signing automation reached Xcode but no matching Apple developer account is configured; sign in once in Xcode Accounts and retry"
    } else if (state.status == "ios-signing-identity-unavailable") {
        "no usable Apple Development signing identity is available; let Xcode create or download one for the selected team, then retry"
    } else if (state.status == "ios-provisioning-profile-unavailable") {
        "automatic signing could not obtain a matching provisioning profile for the bundle, team, and device; repair Xcode account and team registration, then retry"
    } else if (state.status == "ios-signing-team-unavailable") {
        "no usable development team was resolved from argv, environment, TOML, project settings, or local signing identities"
    } else if (state.status == "ios-xcode-destination-unavailable") {
        "Xcode cannot currently use the selected device destination; reconnect and unlock it, then wait for Xcode device preparation"
    } else if (state.status == "ios-built-artifact-not-found") {
        "Xcode reported success but no unique iphoneos .app was found under DerivedData"
    } else if (state.status == "missing-ios-bundle-identifier") {
        "the signed .app does not expose a readable CFBundleIdentifier"
    } else {
        "KMP iOS build or deployment failed; inspect execution logs"
    }
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-kmp-ios-dev-execution-v0\",\n")
    out.append("  \"ok\": " + boolJson(state.ok) + ",\n")
    out.append("  \"mode\": \"local-execution\",\n")
    out.append("  \"status\": \"" + escapeJson(state.status) + "\",\n")
    out.append("  \"project\": \"" + escapeJson(options.project) + "\",\n")
    out.append("  \"target\": \"ios\",\n")
    out.append("  \"artifactMode\": \"" + escapeJson(state.artifactMode) + "\",\n")
    out.append("  \"useOldRequested\": " + boolJson(options.useOld) + ",\n")
    out.append("  \"artifact\": \"" + escapeJson(state.artifact) + "\",\n")
    out.append("  \"selectedDevice\": \"" + escapeJson(state.selectedDevice) + "\",\n")
    out.append("  \"observedDevice\": \"" + escapeJson(state.observedDevice) + "\",\n")
    out.append("  \"xcodeDeviceId\": \"" + escapeJson(state.xcodeDeviceId) + "\",\n")
    out.append("  \"bundleId\": \"" + escapeJson(state.bundleId) + "\",\n")
    out.append("  \"scheme\": \"" + escapeJson(state.scheme) + "\",\n")
    out.append("  \"configuration\": \"" + escapeJson(state.configuration) + "\",\n")
    out.append("  \"derivedDataPath\": \"" + escapeJson(state.derivedDataPath) + "\",\n")
    out.append("  \"developmentTeam\": \"" + escapeJson(state.developmentTeam) + "\",\n")
    out.append("  \"developmentTeamSource\": \"" + escapeJson(state.developmentTeamSource) + "\",\n")
    out.append("  \"signingIdentityCount\": " + state.signingIdentityCount.toString() + ",\n")
    out.append("  \"signingAutomationAttempted\": " + boolJson(state.signingAutomationAttempted) + ",\n")
    out.append("  \"allowProvisioningUpdates\": " + boolJson(state.allowProvisioningUpdates) + ",\n")
    out.append("  \"networkMode\": \"" + escapeJson(normalizeHapNetworkMode(options.networkMode)) + "\",\n")
    out.append("  \"proxyEnvironmentInherited\": " + boolJson(normalizeHapNetworkMode(options.networkMode) == "proxy") + ",\n")
    out.append("  \"proxyEnvironmentCleared\": " + boolJson(normalizeHapNetworkMode(options.networkMode) == "no-proxy") + ",\n")
    out.append("  \"exitCode\": " + state.exitCode.toString() + ",\n")
    out.append("  \"stdoutLog\": \"" + escapeJson(stdoutLog) + "\",\n")
    out.append("  \"stderrLog\": \"" + escapeJson(stderrLog) + "\",\n")
    out.append("  \"logDir\": \"" + escapeJson(logDir) + "\",\n")
    out.append("  \"diagnosis\": \"" + escapeJson(diagnosis) + "\",\n")
    out.append("  \"sourceBuildActionTaken\": " + boolJson(state.sourceBuildActionTaken) + ",\n")
    out.append("  \"installActionTaken\": " + boolJson(state.installActionTaken) + ",\n")
    out.append("  \"launchActionTaken\": " + boolJson(state.launchActionTaken) + ",\n")
    out.append("  \"installResultPath\": \"" + escapeJson(state.installResultPath) + "\",\n")
    out.append("  \"installResultOutcome\": \"" + escapeJson(state.installResultOutcome) + "\",\n")
    out.append("  \"launchResultPath\": \"" + escapeJson(state.launchResultPath) + "\",\n")
    out.append("  \"launchResultOutcome\": \"" + escapeJson(state.launchResultOutcome) + "\"\n")
    out.append("}")
    out.toString()
}

public func renderKmpIosExecutionHumanSummary(json: String): String {
    let ok = containsJsonTrue(json, "ok")
    let status = extractFlatJsonString(json, "status")
    let diagnosis = extractFlatJsonString(json, "diagnosis")
    let logDir = extractFlatJsonString(json, "logDir")
    let out = StringBuilder()
    out.append(if (ok) { "Hap dev succeeded\n" } else { "Hap dev failed\n" })
    out.append("Target: KMP iOS\n")
    out.append("Status: " + status + "\n")
    out.append("Diagnosis: " + diagnosis + "\n")
    if (!ok && logDir.size > 0) {
        out.append("Logs: " + logDir + "\n")
    }
    out.append("Use -v or --verbose for the full execution JSON.")
    out.toString()
}
