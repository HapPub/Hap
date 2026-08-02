package hapcli

import std.collection.ArrayList
import std.fs.{Directory, File, exists}

public class HapProjectDetectOptions {
    public var project: String = "."
    public var platform: String = "auto"

    public init() {}
}

class HapProjectDetection {
    var projectKind: String = "unknown"
    var buildSystem: String = "unknown"
    var deviceTool: String = "none"
    var confidence: String = "low"
    var score: Int64 = 0
    let signals: ArrayList<String> = ArrayList<String>()
    let adapterCandidates: ArrayList<String> = ArrayList<String>()
    let commandCandidates: ArrayList<String> = ArrayList<String>()

    init() {}
}

class HapProjectSelectionInfo {
    var status: String = "project-not-detected"
    var ambiguous: Bool = false
    var needsPlatform: Bool = false
    let availablePlatforms: ArrayList<String> = ArrayList<String>()

    init() {}
}

public func resolveProjectDetectOptions(commandLine: Array<String>, startIndex: Int64): HapProjectDetectOptions {
    let options = HapProjectDetectOptions()
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
        i += 1
    }
    options
}

public func renderProjectDetectJson(options: HapProjectDetectOptions): String {
    let candidates = detectProjectCandidates(options.project)
    let selected = selectProjectDetection(candidates, options.platform)
    let selection = resolveProjectSelectionInfo(candidates, options.platform, selected)
    let ok = selection.status == "selected"

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-project-detect-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"read-only-detect\",\n")
    out.append("  \"project\": \"" + escapeJson(options.project) + "\",\n")
    out.append("  \"requestedPlatform\": \"" + escapeJson(options.platform) + "\",\n")
    out.append("  \"normalizedPlatform\": \"" + escapeJson(normalizeProjectPlatform(options.platform)) + "\",\n")
    out.append("  \"selectionStatus\": \"" + escapeJson(selection.status) + "\",\n")
    out.append("  \"ambiguousProject\": " + boolJson(selection.ambiguous) + ",\n")
    out.append("  \"needsPlatform\": " + boolJson(selection.needsPlatform) + ",\n")
    out.append("  \"projectKind\": \"" + escapeJson(selected.projectKind) + "\",\n")
    out.append("  \"buildSystem\": \"" + escapeJson(selected.buildSystem) + "\",\n")
    out.append("  \"deviceTool\": \"" + escapeJson(selected.deviceTool) + "\",\n")
    out.append("  \"confidence\": \"" + escapeJson(selected.confidence) + "\",\n")
    out.append("  \"executionActionTaken\": false,\n")
    out.append("  \"mutationActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"wirelessReconnectAllowed\": false,\n")
    out.append("  \"signals\": ")
    appendProjectJsonStringArray(out, selected.signals)
    out.append(",\n")
    out.append("  \"adapterCandidates\": ")
    appendProjectJsonStringArray(out, selected.adapterCandidates)
    out.append(",\n")
    out.append("  \"commandCandidates\": ")
    appendProjectJsonStringArray(out, selected.commandCandidates)
    out.append(",\n")
    out.append("  \"availablePlatforms\": ")
    appendProjectJsonStringArray(out, selection.availablePlatforms)
    out.append(",\n")
    out.append("  \"allCandidates\": [\n")
    var i: Int64 = 0
    while (i < candidates.size) {
        let c = candidates[i]
        out.append("    {\"projectKind\": \"" + escapeJson(c.projectKind) + "\", \"buildSystem\": \"" + escapeJson(c.buildSystem) + "\", \"confidence\": \"" + escapeJson(c.confidence) + "\", \"score\": " + c.score.toString() + "}")
        if (i + 1 < candidates.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
    out.append("  ],\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"run hap dev/build/test from a supported project root without --platform when only one project type is detected\",\n")
    out.append("    \"add --platform harmonyos|cangjie|ios|kmp when availablePlatforms has more than one item\",\n")
    out.append("    \"use hap project detect --project <path> before mutating configs when detection is unclear\",\n")
    out.append("    \"hap push requires explicit artifact or trusted last-build memory\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"project detect does not build, test, install, launch, update dependencies, or reconnect devices\",\n")
    out.append("    \"HarmonyOS wireless reconnect requires future prior USB proof and explicit allow-wireless\",\n")
    out.append("    \"iOS and Kotlin Multiplatform adapters are detection-only in this slice\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func detectProjectCandidates(project: String): ArrayList<HapProjectDetection> {
    let candidates = ArrayList<HapProjectDetection>()
    candidates.add(detectHarmonyProject(project))
    candidates.add(detectIosProject(project))
    candidates.add(detectKmpProject(project))
    candidates.add(detectCangjieProject(project))
    candidates
}

func selectProjectDetection(candidates: ArrayList<HapProjectDetection>, platform: String): HapProjectDetection {
    let normalized = normalizeProjectPlatform(platform)
    var selected = HapProjectDetection()
    var selectedScore: Int64 = -1
    var i: Int64 = 0
    while (i < candidates.size) {
        let candidate = candidates[i]
        let platformMatches = normalized == "auto" || candidate.projectKind == normalized
        if (platformMatches && candidate.score > selectedScore) {
            selected = candidate
            selectedScore = candidate.score
        }
        i += 1
    }
    selected
}

func resolveProjectSelectionInfo(candidates: ArrayList<HapProjectDetection>, platform: String, selected: HapProjectDetection): HapProjectSelectionInfo {
    let info = HapProjectSelectionInfo()
    let normalized = normalizeProjectPlatform(platform)
    collectAvailableProjectPlatforms(candidates, info.availablePlatforms)
    if (normalized != "auto") {
        if (selected.projectKind == "unknown") {
            info.status = "requested-platform-not-detected"
            info.needsPlatform = true
        } else {
            info.status = "selected"
        }
        return info
    }
    if (info.availablePlatforms.size == 0) {
        info.status = "project-not-detected"
        info.needsPlatform = true
        return info
    }
    if (info.availablePlatforms.size > 1) {
        info.status = "ambiguous-project-platform"
        info.ambiguous = true
        info.needsPlatform = true
        return info
    }
    info.status = "selected"
    info
}

func collectAvailableProjectPlatforms(candidates: ArrayList<HapProjectDetection>, out: ArrayList<String>): Unit {
    for (candidate in candidates) {
        if (candidate.projectKind != "unknown" && !projectStringListContains(out, candidate.projectKind)) {
            out.add(candidate.projectKind)
        }
    }
}

func projectStringListContains(items: ArrayList<String>, value: String): Bool {
    for (item in items) {
        if (item == value) {
            return true
        }
    }
    false
}

func detectHarmonyProject(project: String): HapProjectDetection {
    let d = HapProjectDetection()
    d.projectKind = "harmonyos"
    d.buildSystem = "hvigor"
    d.deviceTool = "hdc"
    addSignalIfExists(d, project, "build-profile.json5", 3)
    addSignalIfExists(d, project, "hvigorfile.ts", 3)
    addSignalIfExists(d, project, "hvigorfile.js", 3)
    addSignalIfExists(d, project, "oh-package.json5", 2)
    addSignalIfExists(d, project, "AppScope/app.json5", 2)
    addSignalIfExists(d, project, "entry/src/main/module.json5", 2)
    addSignalIfExists(d, project, "product/src/main/module.json5", 2)
    if (d.score > 0) {
        d.adapterCandidates.add("harmonyos-hvigor")
        d.commandCandidates.add("hap build --platform harmonyos")
        d.commandCandidates.add("hap test --platform harmonyos --lint")
        d.commandCandidates.add("hap dev --platform harmonyos --device auto")
        d.commandCandidates.add("hap push --platform harmonyos --artifact <path>")
    }
    finalizeConfidence(d)
    d
}

func detectIosProject(project: String): HapProjectDetection {
    let d = HapProjectDetection()
    d.projectKind = "ios"
    d.buildSystem = "xcodebuild"
    d.deviceTool = "simctl-or-devicectl"
    addSignalIfExists(d, project, "Package.swift", 1)
    addSignalIfExists(d, project, "Podfile", 1)
    addSignalIfExists(d, project, "Info.plist", 1)
    addSignalIfExists(d, project, "ios/Info.plist", 1)
    addDirectorySuffixSignals(d, project, ".xcodeproj", 4)
    addDirectorySuffixSignals(d, project, ".xcworkspace", 4)
    if (d.score > 0) {
        d.adapterCandidates.add("ios-xcodebuild")
        d.commandCandidates.add("hap build --platform ios")
        d.commandCandidates.add("hap test --platform ios")
    }
    finalizeConfidence(d)
    d
}

func detectKmpProject(project: String): HapProjectDetection {
    let d = HapProjectDetection()
    d.projectKind = "kotlin-multiplatform"
    d.buildSystem = "gradle"
    d.deviceTool = "gradle-xcodebuild-devicectl"
    addSignalIfExists(d, project, "settings.gradle", 1)
    addSignalIfExists(d, project, "settings.gradle.kts", 1)
    addSignalIfExists(d, project, "build.gradle", 1)
    addSignalIfExists(d, project, "build.gradle.kts", 1)
    addSignalIfExists(d, project, "gradlew", 2)
    addSignalIfExists(d, project, "gradle/libs.versions.toml", 1)
    addSignalIfExists(d, project, "src/commonMain", 3)
    addSignalIfExists(d, project, "src/androidMain", 2)
    addSignalIfExists(d, project, "src/iosMain", 2)
    addSignalIfExists(d, project, "composeApp/build.gradle.kts", 3)
    addSignalIfExists(d, project, "composeApp/src/commonMain", 4)
    addSignalIfExists(d, project, "composeApp/src/iosMain", 3)
    addSignalIfExists(d, project, "composeApp/src/androidMain", 2)
    addSignalIfExists(d, project, "iosApp/iosApp.xcodeproj/project.pbxproj", 2)
    addSignalIfExists(d, project, "iosApp/iosApp/Info.plist", 1)
    addTextSignalIfContains(d, project, "build.gradle.kts", "multiplatform", "build.gradle.kts:multiplatform", 4)
    addTextSignalIfContains(d, project, "build.gradle", "multiplatform", "build.gradle:multiplatform", 4)
    addTextSignalIfContains(d, project, "build.gradle.kts", "kotlinMultiplatform", "build.gradle.kts:kotlinMultiplatform", 4)
    addTextSignalIfContains(d, project, "composeApp/build.gradle.kts", "multiplatform", "composeApp/build.gradle.kts:multiplatform", 5)
    addTextSignalIfContains(d, project, "composeApp/build.gradle.kts", "composeMultiplatform", "composeApp/build.gradle.kts:composeMultiplatform", 5)
    addTextSignalIfContains(d, project, "composeApp/build.gradle.kts", "iosArm64", "composeApp/build.gradle.kts:iosArm64", 3)
    addTextSignalIfContains(d, project, "settings.gradle.kts", "include(\":composeApp\")", "settings.gradle.kts:include-composeApp", 3)
    if (d.score > 0) {
        d.adapterCandidates.add("kmp-compose-gradle")
        d.adapterCandidates.add("kmp-ios-xcodebuild-plan")
        d.commandCandidates.add("hap build --platform kmp")
        d.commandCandidates.add("hap test --platform kmp --lint")
        d.commandCandidates.add("hap dev --platform kmp --plan")
    }
    finalizeConfidence(d)
    d
}

func detectCangjieProject(project: String): HapProjectDetection {
    let d = HapProjectDetection()
    d.projectKind = "cangjie"
    d.buildSystem = "cjpm"
    d.deviceTool = "none"
    addSignalIfExists(d, project, "cjpm.toml", 5)
    addDirectorySuffixSignals(d, project, ".cjpm.toml", 3)
    if (d.score > 0) {
        d.adapterCandidates.add("cangjie-cjpm")
        d.commandCandidates.add("hap build --platform cangjie")
        d.commandCandidates.add("hap test --platform cangjie")
        d.commandCandidates.add("hap record cangjie.stdx --project <path>")
        d.commandCandidates.add("hap doctorfix cangjie.stdx --project <path> --plan")
    }
    finalizeConfidence(d)
    d
}

func addSignalIfExists(d: HapProjectDetection, project: String, relative: String, score: Int64): Unit {
    let path = joinProjectPath(project, relative)
    if (exists(path)) {
        d.signals.add(relative)
        d.score += score
    }
}

func addTextSignalIfContains(d: HapProjectDetection, project: String, relative: String, needle: String, signal: String, score: Int64): Unit {
    let path = joinProjectPath(project, relative)
    if (!exists(path)) {
        return
    }
    try {
        let text = String.fromUtf8(File.readFrom(path))
        if (containsText(text, needle)) {
            d.signals.add(signal)
            d.score += score
        }
    } catch (_: Exception) {}
}

func addDirectorySuffixSignals(d: HapProjectDetection, project: String, suffix: String, score: Int64): Unit {
    try {
        let entries = Directory.readFrom(project)
        for (entry in entries) {
            let path = entry.path.toString()
            let name = basenameText(path)
            if (endsWithText(name, suffix)) {
                d.signals.add(name)
                d.score += score
            }
        }
    } catch (_: Exception) {}
}

func finalizeConfidence(d: HapProjectDetection): Unit {
    if (d.score >= 6) {
        d.confidence = "high"
    } else if (d.score >= 3) {
        d.confidence = "medium"
    } else if (d.score > 0) {
        d.confidence = "low"
    } else {
        d.projectKind = "unknown"
        d.buildSystem = "unknown"
        d.deviceTool = "none"
        d.confidence = "low"
    }
}

func normalizeProjectPlatform(platform: String): String {
    match (platform) {
        case "auto" => "auto"
        case "harmony" => "harmonyos"
        case "harmonyos" => "harmonyos"
        case "openharmony" => "harmonyos"
        case "ohos" => "harmonyos"
        case "ios" => "ios"
        case "kmp" => "kotlin-multiplatform"
        case "kotlin" => "kotlin-multiplatform"
        case "kotlin-multiplatform" => "kotlin-multiplatform"
        case "cangjie" => "cangjie"
        case "cjpm" => "cangjie"
        case _ => platform
    }
}

func joinProjectPath(project: String, relative: String): String {
    if (project == "." || project.size == 0) {
        relative
    } else if (endsWithText(project, "/")) {
        project + relative
    } else {
        project + "/" + relative
    }
}

func appendProjectJsonStringArray(out: StringBuilder, items: ArrayList<String>): Unit {
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
