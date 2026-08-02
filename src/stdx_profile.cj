package hapcli

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{Directory, File, exists}

public class HapRecordOptions {
    public var subject: String = ""
    public var project: String = "."
    public var target: String = ""
    public var name: String = ""
    public var configPath: String = ""
    public var fromBuildSuccess: Bool = false

    public init() {}
}

public class HapDoctorFixOptions {
    public var subject: String = ""
    public var project: String = "."
    public var target: String = ""
    public var configPath: String = ""
    public var plan: Bool = true
    public var write: Bool = false

    public init() {}
}

public class HapStdxProfile {
    public var name: String = ""
    public var subject: String = "cangjie.stdx"
    public var target: String = ""
    public var sourceTarget: String = ""
    public var compileOption: String = ""
    public var linkOption: String = ""
    public let pathOptions: ArrayList<String> = ArrayList<String>()

    public init() {}
}

class HapConfigWriteResult {
    var path: String = ""
    var pathSource: String = ""
    var written: Bool = false
    var status: String = "not-attempted"

    init() {}
}

public func resolveRecordOptions(commandLine: Array<String>, start: Int64): HapRecordOptions {
    let options = HapRecordOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (!startsWithText(current, "--") && options.subject.size == 0) {
            options.subject = current
            i += 1
            continue
        }
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
        if (current == "--target" && i + 1 < commandLine.size) {
            options.target = canonicalTargetName(commandLine[i + 1])
            i += 2
            continue
        }
        if (startsWithText(current, "--target=")) {
            options.target = canonicalTargetName(substringFrom(current, 9))
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
        if (current == "--config" && i + 1 < commandLine.size) {
            options.configPath = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--config=")) {
            options.configPath = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--from-build-success") {
            options.fromBuildSuccess = true
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func resolveDoctorFixOptions(commandLine: Array<String>, start: Int64): HapDoctorFixOptions {
    let options = HapDoctorFixOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (!startsWithText(current, "--") && options.subject.size == 0) {
            options.subject = current
            i += 1
            continue
        }
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
        if (current == "--target" && i + 1 < commandLine.size) {
            options.target = canonicalTargetName(commandLine[i + 1])
            i += 2
            continue
        }
        if (startsWithText(current, "--target=")) {
            options.target = canonicalTargetName(substringFrom(current, 9))
            i += 1
            continue
        }
        if (current == "--config" && i + 1 < commandLine.size) {
            options.configPath = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--config=")) {
            options.configPath = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--plan") {
            options.plan = true
            options.write = false
            i += 1
            continue
        }
        if (current == "--write") {
            options.write = true
            options.plan = false
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func runRecord(commandLine: Array<String>, start: Int64): String {
    renderRecordJson(resolveRecordOptions(commandLine, start), true)
}

public func runDoctorFix(commandLine: Array<String>, start: Int64): String {
    renderDoctorFixJson(resolveDoctorFixOptions(commandLine, start), true)
}

public func renderRecordJson(options: HapRecordOptions, canWrite: Bool): String {
    let subjectOk = normalizeHapSubject(options.subject) == "cangjie.stdx"
    let project = if (options.project.size > 0) { options.project } else { "." }
    let manifest = projectManifestPath(project)
    let projectOk = exists(manifest)
    let text = if (projectOk) { String.fromUtf8(File.readFrom(manifest)) } else { "" }
    let profile = extractStdxProfileFromCjpm(text, options.target, options.name)
    let profileOk = subjectOk && projectOk && profile.target.size > 0 && profile.pathOptions.size > 0
    let configResult = HapConfigWriteResult()
    if (profileOk && canWrite) {
        let result = writeStdxProfileRecordWithFallback(project, options.configPath, profile, options.fromBuildSuccess, manifest)
        configResult.path = result.path
        configResult.pathSource = result.pathSource
        configResult.written = result.written
        configResult.status = result.status
    } else {
        configResult.path = resolveHapConfigPath(project, options.configPath)
        configResult.pathSource = configPathSource(project, options.configPath, configResult.path)
    }

    "{\n" +
    "  \"schema\": \"happub-hapcli-record-cangjie-stdx-v0\",\n" +
    "  \"ok\": " + boolJson(profileOk && configResult.written) + ",\n" +
    "  \"mode\": \"record-learned-profile\",\n" +
    "  \"subject\": \"" + escapeJson(normalizeHapSubject(options.subject)) + "\",\n" +
    "  \"project\": \"" + escapeJson(project) + "\",\n" +
    "  \"manifest\": \"" + escapeJson(manifest) + "\",\n" +
    "  \"target\": \"" + escapeJson(profile.target) + "\",\n" +
    "  \"sourceTarget\": \"" + escapeJson(profile.sourceTarget) + "\",\n" +
    "  \"profileName\": \"" + escapeJson(profile.name) + "\",\n" +
    "  \"configPath\": \"" + escapeJson(configResult.path) + "\",\n" +
    "  \"configPathSource\": \"" + escapeJson(configResult.pathSource) + "\",\n" +
    "  \"configPathPolicy\": \"~/.hap/config.toml -> ./.hapData/config.toml -> ./happub.toml when Hap-supported project fallback is required\",\n" +
    "  \"pathOptionCount\": " + profile.pathOptions.size.toString() + ",\n" +
    "  \"configWritten\": " + boolJson(configResult.written) + ",\n" +
    "  \"fromBuildSuccess\": " + boolJson(options.fromBuildSuccess) + ",\n" +
    "  \"status\": \"" + escapeJson(recordStatus(subjectOk, projectOk, profileOk, configResult.written)) + "\",\n" +
    "  \"nextAllowed\": [\"doctorfix-cangjie-stdx-plan\", \"doctorfix-cangjie-stdx-write\", \"hap-build-auto-fix-preview\"],\n" +
    "  \"nonPromises\": [\"record does not download stdx\", \"record does not mutate cjpm.toml\", \"record stores reusable parameters only\", \"profile confidence still depends on a real build receipt when used for release\"]\n" +
    "}"
}

public func renderDoctorFixJson(options: HapDoctorFixOptions, canWrite: Bool): String {
    let subjectOk = normalizeHapSubject(options.subject) == "cangjie.stdx"
    let project = if (options.project.size > 0) { options.project } else { "." }
    let manifest = projectManifestPath(project)
    let projectOk = exists(manifest)
    let configPath = resolveHapConfigPath(project, options.configPath)
    let configOk = exists(configPath)
    let configText = if (configOk) { String.fromUtf8(File.readFrom(configPath)) } else { "" }
    let target = canonicalTargetName(options.target)
    let profile = findRecordedStdxProfile(configText, target)
    let profileOk = profile.target.size > 0 && profile.pathOptions.size > 0
    let before = if (projectOk) { String.fromUtf8(File.readFrom(manifest)) } else { "" }
    let fixed = if (profileOk) { applyStdxProfileToCjpm(before, profile) } else { before }
    let changed = before != fixed
    let backupPath = manifest + ".hap-backup"
    let receiptPath = project + "/.hapData/receipts/doctorfix-cangjie-stdx.json"
    var backupWritten = false
    var manifestWritten = false
    var receiptWritten = false

    if (subjectOk && projectOk && profileOk && options.write && canWrite) {
        let receiptDir = parentPath(receiptPath)
        if (receiptDir.size > 0 && !exists(receiptDir)) {
            Directory.create(receiptDir, recursive: true)
        }
        File.writeTo(backupPath, before.toArray())
        backupWritten = true
        File.writeTo(manifest, fixed.toArray())
        manifestWritten = true
        File.writeTo(receiptPath, renderDoctorFixReceipt(options, profile, manifest, backupPath, changed).toArray())
        receiptWritten = true
    }

    let ok = subjectOk && projectOk && configOk && profileOk && (!options.write || (manifestWritten && receiptWritten))
    "{\n" +
    "  \"schema\": \"happub-hapcli-doctorfix-cangjie-stdx-v0\",\n" +
    "  \"ok\": " + boolJson(ok) + ",\n" +
    "  \"mode\": \"" + escapeJson(if (options.write) { "reviewed-write" } else { "plan-only" }) + "\",\n" +
    "  \"subject\": \"" + escapeJson(normalizeHapSubject(options.subject)) + "\",\n" +
    "  \"project\": \"" + escapeJson(project) + "\",\n" +
    "  \"manifest\": \"" + escapeJson(manifest) + "\",\n" +
    "  \"configPath\": \"" + escapeJson(configPath) + "\",\n" +
    "  \"target\": \"" + escapeJson(profile.target) + "\",\n" +
    "  \"profileName\": \"" + escapeJson(profile.name) + "\",\n" +
    "  \"status\": \"" + escapeJson(doctorFixStatus(subjectOk, projectOk, configOk, profileOk, options.write, manifestWritten)) + "\",\n" +
    "  \"plannedMutation\": " + boolJson(profileOk) + ",\n" +
    "  \"manifestChanged\": " + boolJson(changed) + ",\n" +
    "  \"backupPath\": \"" + escapeJson(backupPath) + "\",\n" +
    "  \"receiptPath\": \"" + escapeJson(receiptPath) + "\",\n" +
    "  \"backupWritten\": " + boolJson(backupWritten) + ",\n" +
    "  \"manifestMutationActionTaken\": " + boolJson(manifestWritten) + ",\n" +
    "  \"receiptWritten\": " + boolJson(receiptWritten) + ",\n" +
    "  \"nextAllowed\": [\"run-cjpm-build\", \"hap-build-auto-fix-preview\", \"restore-cjpm-from-hap-backup\"],\n" +
    "  \"nonPromises\": [\"doctorfix does not download stdx\", \"doctorfix does not certify build success\", \"--plan never mutates cjpm.toml\", \"--write only rewrites the detected cjpm.toml after writing a backup\"]\n" +
    "}"
}

public func normalizeHapSubject(subject: String): String {
    match (subject) {
        case "cangjie.stdx" => "cangjie.stdx"
        case "stdx" => "cangjie.stdx"
        case "cangjie-stdx" => "cangjie.stdx"
        case _ => subject
    }
}

public func extractStdxProfileFromCjpm(text: String, requestedTarget: String, requestedName: String): HapStdxProfile {
    let profile = HapStdxProfile()
    let target = canonicalTargetName(requestedTarget)
    var currentTarget = ""
    var currentSourceTarget = ""
    var inTarget = false
    var inBinDeps = false

    for (line in text.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (startsWithText(trimmed, "[") && trimmed.endsWith("]")) {
            let header = substringTo(substringFrom(trimmed, 1), Int64(trimmed.size - 2))
            currentSourceTarget = targetFromHeader(header)
            currentTarget = canonicalTargetName(currentSourceTarget)
            inTarget = startsWithText(header, "target.") && !containsText(header, ".bin-dependencies") && !containsText(header, "Deprecated")
            inBinDeps = startsWithText(header, "target.") && containsText(header, ".bin-dependencies") && !containsText(header, "Deprecated")
            continue
        }
        if (target.size > 0 && currentTarget != target) {
            continue
        }
        if (target.size == 0 && profile.target.size > 0 && currentTarget != profile.target) {
            continue
        }
        if (inTarget) {
            if (startsWithText(trimmed, "compile-option")) {
                profile.compileOption = extractQuotedValue(trimmed)
                profile.target = currentTarget
                profile.sourceTarget = currentSourceTarget
            } else if (startsWithText(trimmed, "link-option")) {
                profile.linkOption = extractQuotedValue(trimmed)
                profile.target = currentTarget
                profile.sourceTarget = currentSourceTarget
            }
        }
        if (inBinDeps && startsWithText(trimmed, "path-option")) {
            let values = extractQuotedValues(trimmed)
            for (value in values) {
                addUniqueStdxProfilePath(profile.pathOptions, value)
            }
            profile.target = currentTarget
            profile.sourceTarget = currentSourceTarget
        }
    }
    if (profile.name.size == 0) {
        profile.name = if (requestedName.size > 0) { requestedName } else { "recorded-" + profile.target }
    }
    profile
}

public func findRecordedStdxProfile(configText: String, requestedTarget: String): HapStdxProfile {
    let target = canonicalTargetName(requestedTarget)
    var active = HapStdxProfile()
    var found = HapStdxProfile()
    var inProfile = false
    for (line in configText.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (trimmed == "[[records]]") {
            if (profileMatchesTarget(active, target)) {
                found = active
            }
            active = HapStdxProfile()
            inProfile = true
            continue
        }
        if (!inProfile) {
            continue
        }
        if (startsWithText(trimmed, "name = ")) {
            active.name = extractQuotedValue(trimmed)
        } else if (startsWithText(trimmed, "subject = ")) {
            active.subject = normalizeHapSubject(extractQuotedValue(trimmed))
        } else if (startsWithText(trimmed, "target = ")) {
            active.target = canonicalTargetName(extractQuotedValue(trimmed))
        } else if (startsWithText(trimmed, "sourceTarget = ")) {
            active.sourceTarget = extractQuotedValue(trimmed)
        } else if (startsWithText(trimmed, "compileOption = ")) {
            active.compileOption = extractQuotedValue(trimmed)
        } else if (startsWithText(trimmed, "linkOption = ")) {
            active.linkOption = extractQuotedValue(trimmed)
        } else if (startsWithText(trimmed, "pathOption = ")) {
            active.pathOptions.clear()
            for (value in extractQuotedValues(trimmed)) {
                active.pathOptions.add(value)
            }
        }
    }
    if (profileMatchesTarget(active, target)) {
        found = active
    }
    found
}

public func applyStdxProfileToCjpm(text: String, profile: HapStdxProfile): String {
    let out = StringBuilder()
    var skip = false
    for (line in text.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (startsWithText(trimmed, "[") && trimmed.endsWith("]")) {
            let header = substringTo(substringFrom(trimmed, 1), Int64(trimmed.size - 2))
            let headerTarget = targetFromHeader(header)
            let matchTarget = canonicalTargetName(headerTarget) == profile.target && !containsText(header, "Deprecated")
            skip = startsWithText(header, "target.") && matchTarget
        }
        if (!skip) {
            out.append(line)
            out.append("\n")
        }
    }
    if (!out.toString().endsWith("\n")) {
        out.append("\n")
    }
    out.append(renderStdxTargetBlock(profile))
    out.toString()
}

public func resolveHapConfigPath(project: String, explicitPath: String): String {
    let candidates = resolveHapConfigPathCandidates(project, explicitPath)
    if (explicitPath.size > 0) {
        return explicitPath
    }
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
    trimTrailingSlash(project) + "/happub.toml"
}

func resolveHapConfigPathCandidates(project: String, explicitPath: String): ArrayList<String> {
    let candidates = ArrayList<String>()
    if (explicitPath.size > 0) {
        candidates.add(explicitPath)
        return candidates
    }
    match (getVariable("HOME")) {
        case Some(home) =>
            if (home.size > 0) {
                candidates.add(trimTrailingSlash(home) + "/.hap/config.toml")
            }
        case None => ()
    }
    if (exists(projectManifestPath(project))) {
        candidates.add(trimTrailingSlash(project) + "/.hapData/config.toml")
        candidates.add(trimTrailingSlash(project) + "/happub.toml")
    }
    candidates
}

func configPathSource(project: String, explicitPath: String, path: String): String {
    if (explicitPath.size > 0) {
        return "explicit-config"
    }
    match (getVariable("HOME")) {
        case Some(home) =>
            if (home.size > 0 && path == trimTrailingSlash(home) + "/.hap/config.toml") {
                return "home-private"
            }
        case None => ()
    }
    if (path == trimTrailingSlash(project) + "/.hapData/config.toml") {
        return "project-hapData-fallback"
    }
    if (path == trimTrailingSlash(project) + "/happub.toml") {
        return "project-happub-fallback"
    }
    "unknown"
}

func writeStdxProfileRecordWithFallback(
    project: String,
    explicitPath: String,
    profile: HapStdxProfile,
    fromBuildSuccess: Bool,
    manifest: String
): HapConfigWriteResult {
    let result = HapConfigWriteResult()
    let candidates = resolveHapConfigPathCandidates(project, explicitPath)
    var i: Int64 = 0
    while (i < candidates.size) {
        let candidate = candidates[i]
        let configDir = parentPath(candidate)
        try {
            if (configDir.size > 0 && !exists(configDir)) {
                Directory.create(configDir, recursive: true)
            }
            let before = if (exists(candidate)) { String.fromUtf8(File.readFrom(candidate)) } else { renderHapConfigHeader() }
            File.writeTo(candidate, appendStdxProfileRecord(before, profile, fromBuildSuccess, manifest).toArray())
            result.path = candidate
            result.pathSource = configPathSource(project, explicitPath, candidate)
            result.written = true
            result.status = "recorded"
            return result
        } catch (_: Exception) {
            result.status = "config-write-fallback-attempted"
        }
        i += 1
    }
    result.path = if (candidates.size > 0) { candidates[0] } else { trimTrailingSlash(project) + "/happub.toml" }
    result.pathSource = configPathSource(project, explicitPath, result.path)
    result.written = false
    result.status = "no-writable-config-path"
    result
}

func projectManifestPath(project: String): String {
    let base = if (project.size > 0) { trimTrailingSlash(project) } else { "." }
    if (base.endsWith("cjpm.toml")) {
        return base
    }
    base + "/cjpm.toml"
}

func targetFromHeader(header: String): String {
    if (!startsWithText(header, "target.")) {
        return ""
    }
    let raw = substringFrom(header, 7)
    let marker = ".bin-dependencies"
    let idx = indexOfText(raw, marker)
    if (idx >= 0) {
        return substringTo(raw, idx)
    }
    raw
}

func appendStdxProfileRecord(before: String, profile: HapStdxProfile, fromBuildSuccess: Bool, manifest: String): String {
    let prefix = if (before.size > 0 && !before.endsWith("\n")) { before + "\n" } else { before }
    prefix +
    "\n[[records]]\n" +
    "subject = \"cangjie.stdx\"\n" +
    "name = \"" + escapeToml(profile.name) + "\"\n" +
    "target = \"" + escapeToml(profile.target) + "\"\n" +
    "sourceTarget = \"" + escapeToml(profile.sourceTarget) + "\"\n" +
    "source = \"" + if (fromBuildSuccess) { "recorded-from-build-success" } else { "recorded-from-existing-cjpm" } + "\"\n" +
    "sourceManifest = \"" + escapeToml(manifest) + "\"\n" +
    "compileOption = \"" + escapeToml(profile.compileOption) + "\"\n" +
    "linkOption = \"" + escapeToml(profile.linkOption) + "\"\n" +
    "pathOption = [" + renderTomlStringArrayInline(profile.pathOptions) + "]\n"
}

func renderHapConfigHeader(): String {
    "[hap]\n" +
    "schema = \"happub-hapcli-config-v0\"\n" +
    "alwaysFix = false\n" +
    "verbose = false\n"
}

func renderStdxTargetBlock(profile: HapStdxProfile): String {
    let target = if (profile.sourceTarget.size > 0) { profile.sourceTarget } else { profile.target }
    let out = StringBuilder()
    out.append("\n[target." + target + "]\n")
    if (profile.compileOption.size > 0) {
        out.append("compile-option = \"" + escapeToml(profile.compileOption) + "\"\n")
    }
    if (profile.linkOption.size > 0) {
        out.append("link-option = \"" + escapeToml(profile.linkOption) + "\"\n")
    }
    out.append("[target." + target + ".bin-dependencies]\n")
    out.append("path-option = [" + renderTomlStringArrayInline(profile.pathOptions) + "]\n")
    out.toString()
}

func renderDoctorFixReceipt(options: HapDoctorFixOptions, profile: HapStdxProfile, manifest: String, backupPath: String, changed: Bool): String {
    "{\n" +
    "  \"schema\": \"happub-hapcli-doctorfix-cangjie-stdx-receipt-v0\",\n" +
    "  \"ok\": true,\n" +
    "  \"subject\": \"cangjie.stdx\",\n" +
    "  \"target\": \"" + escapeJson(profile.target) + "\",\n" +
    "  \"profileName\": \"" + escapeJson(profile.name) + "\",\n" +
    "  \"manifest\": \"" + escapeJson(manifest) + "\",\n" +
    "  \"backupPath\": \"" + escapeJson(backupPath) + "\",\n" +
    "  \"manifestChanged\": " + boolJson(changed) + ",\n" +
    "  \"canonMutation\": true,\n" +
    "  \"restoreHint\": \"copy backupPath back to manifest if rollback is needed\"\n" +
    "}\n"
}

func recordStatus(subjectOk: Bool, projectOk: Bool, profileOk: Bool, configWritten: Bool): String {
    if (!subjectOk) {
        return "unsupported-subject"
    }
    if (!projectOk) {
        return "project-not-supported-missing-cjpm"
    }
    if (!profileOk) {
        return "no-target-stdx-path-option-found"
    }
    if (!configWritten) {
        return "profile-detected-not-written"
    }
    "recorded"
}

func doctorFixStatus(subjectOk: Bool, projectOk: Bool, configOk: Bool, profileOk: Bool, write: Bool, written: Bool): String {
    if (!subjectOk) {
        return "unsupported-subject"
    }
    if (!projectOk) {
        return "project-not-supported-missing-cjpm"
    }
    if (!configOk) {
        return "config-not-found"
    }
    if (!profileOk) {
        return "recorded-profile-not-found"
    }
    if (write && written) {
        return "doctorfix-written"
    }
    if (write) {
        return "doctorfix-write-not-applied"
    }
    "doctorfix-plan-ready"
}

func profileMatchesTarget(profile: HapStdxProfile, target: String): Bool {
    profile.subject == "cangjie.stdx" && profile.target.size > 0 && (target.size == 0 || profile.target == target)
}

func extractQuotedValues(line: String): ArrayList<String> {
    let values = ArrayList<String>()
    var rest = line
    while (true) {
        let first = indexOfText(rest, "\"")
        if (first < 0) {
            break
        }
        let afterFirst = substringFrom(rest, first + 1)
        let second = indexOfText(afterFirst, "\"")
        if (second < 0) {
            break
        }
        values.add(substringTo(afterFirst, second))
        rest = substringFrom(afterFirst, second + 1)
    }
    values
}

func renderTomlStringArrayInline(values: ArrayList<String>): String {
    let out = StringBuilder()
    var i: Int64 = 0
    while (i < values.size) {
        out.append("\"" + escapeToml(values[i]) + "\"")
        if (i + 1 < values.size) {
            out.append(", ")
        }
        i += 1
    }
    out.toString()
}

func addUniqueStdxProfilePath(values: ArrayList<String>, value: String): Unit {
    if (value.size == 0) {
        return
    }
    var i: Int64 = 0
    while (i < values.size) {
        if (values[i] == value) {
            return
        }
        i += 1
    }
    values.add(value)
}

func escapeToml(text: String): String {
    let out = StringBuilder()
    for (r in text.toRuneArray()) {
        if (r == r'\\') {
            out.append("\\\\")
        } else if (r == r'"') {
            out.append("\\\"")
        } else if (r == r'\n') {
            out.append("\\n")
        } else if (r == r'\r') {
            out.append("\\r")
        } else if (r == r'\t') {
            out.append("\\t")
        } else {
            out.append(r.toString())
        }
    }
    out.toString()
}
