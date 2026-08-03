package hapcli

import std.collection.ArrayList
import std.env.getVariable
import std.fs.exists

public class HapDoctorOptions {
    public var project: String = "."
    public var target: String = "linux-amd64"
    public var searchRoot: String = ""
    public var cjcPath: String = ""

    public init() {}
}

public class HapDoctorProbe {
    public let status: String
    public let confidence: String
    public let detectedPath: String
    public let detectedFrom: String

    public init(status: String, confidence: String, detectedPath: String, detectedFrom: String) {
        this.status = status
        this.confidence = confidence
        this.detectedPath = detectedPath
        this.detectedFrom = detectedFrom
    }
}

public func resolveDoctorOptions(commandLine: Array<String>, start: Int64): HapDoctorOptions {
    let options = HapDoctorOptions()
    var i = start
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
        if (current == "--search-root" && i + 1 < commandLine.size) {
            options.searchRoot = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--search-root=")) {
            options.searchRoot = substringFrom(current, 14)
            i += 1
            continue
        }
        if (current == "--cjc-path" && i + 1 < commandLine.size) {
            options.cjcPath = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--cjc-path=")) {
            options.cjcPath = substringFrom(current, 11)
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func renderStdxDoctorJson(options: HapDoctorOptions): String {
    let hint = targetPathHint(options.target)
    let platform = targetPlatformName(options.target)
    let roots = collectDoctorRoots(options)
    let probe = findFirstExistingCandidate(roots, stdxCandidateSuffixes(hint, platform), "stdx")
    let ok = hint.size > 0
    let status = if (ok) { probe.status } else { "unsupported-target" }

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-stdx-doctor-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"diagnose-only\",\n")
    out.append("  \"target\": \"" + escapeJson(options.target) + "\",\n")
    out.append("  \"expectedPlatform\": \"" + escapeJson(platform) + "\",\n")
    out.append("  \"expectedPathHint\": \"" + escapeJson(hint) + "\",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"confidence\": " + probe.confidence + ",\n")
    out.append("  \"detectedStdxRoot\": \"" + escapeJson(if (ok) { probe.detectedPath } else { "" }) + "\",\n")
    out.append("  \"detectedFrom\": \"" + escapeJson(if (ok) { probe.detectedFrom } else { "target-profile-missing" }) + "\",\n")
    appendDoctorScanPolicy(out, roots)
    out.append(",\n")
    out.append("  \"repairAllowed\": false,\n")
    out.append("  \"downloadAllowed\": false,\n")
    appendDoctorNext(out, "stdx")
    out.append("\n}")
    out.toString()
}

public func renderRuntimeDoctorJson(options: HapDoctorOptions): String {
    let platform = targetPlatformName(options.target)
    let roots = collectDoctorRoots(options)
    let probe = findFirstExistingCandidate(roots, runtimeCandidateSuffixes(platform), "runtime")
    let ok = platform.size > 0
    let status = if (ok) { probe.status } else { "unsupported-target" }

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-runtime-doctor-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"diagnose-only\",\n")
    out.append("  \"target\": \"" + escapeJson(options.target) + "\",\n")
    out.append("  \"expectedPlatform\": \"" + escapeJson(platform) + "\",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"confidence\": " + probe.confidence + ",\n")
    out.append("  \"detectedRuntimeRoot\": \"" + escapeJson(if (ok) { probe.detectedPath } else { "" }) + "\",\n")
    out.append("  \"detectedFrom\": \"" + escapeJson(if (ok) { probe.detectedFrom } else { "target-profile-missing" }) + "\",\n")
    appendDoctorScanPolicy(out, roots)
    out.append(",\n")
    out.append("  \"repairAllowed\": false,\n")
    out.append("  \"downloadAllowed\": false,\n")
    appendDoctorNext(out, "runtime")
    out.append("\n}")
    out.toString()
}

func targetPathHint(target: String): String {
    stdxPathHintForTarget(target)
}

func targetPlatformName(target: String): String {
    cangjiePlatformNameForTarget(target)
}

func stdxCandidateSuffixes(hint: String, platform: String): ArrayList<String> {
    let suffixes = ArrayList<String>()
    if (hint.size > 0) {
        suffixes.add(hint)
    }
    if (platform.size > 0) {
        suffixes.add("stdx_Build/" + platform)
        suffixes.add("runtime/lib/" + platform)
        suffixes.add("lib/" + platform)
        suffixes.add(platform)
    }
    suffixes
}

func runtimeCandidateSuffixes(platform: String): ArrayList<String> {
    let suffixes = ArrayList<String>()
    if (platform.size > 0) {
        suffixes.add("runtime/lib/" + platform)
        suffixes.add("lib/" + platform)
        suffixes.add(platform)
    }
    suffixes
}

func collectDoctorRoots(options: HapDoctorOptions): ArrayList<String> {
    let roots = ArrayList<String>()
    addUniqueRoot(roots, options.searchRoot)
    addProjectParents(roots, options.project, 4)
    addUniqueRoot(roots, readEnvOrEmpty("CANGJIE_STDX_PATH"))
    addUniqueRoot(roots, readEnvOrEmpty("CANGJIE_HOME"))
    addUniqueRoot(roots, readEnvOrEmpty("CJ_HOME"))
    addUniqueRoot(roots, readEnvOrEmpty("CJC_PATH"))
    if (options.cjcPath.size > 0) {
        addUniqueRoot(roots, parentPath(parentPath(options.cjcPath)))
    }
    roots
}

func findFirstExistingCandidate(roots: ArrayList<String>, suffixes: ArrayList<String>, kind: String): HapDoctorProbe {
    var i: Int64 = 0
    while (i < roots.size) {
        var j: Int64 = 0
        while (j < suffixes.size) {
            let candidate = joinPath(roots[i], suffixes[j])
            if (candidate.size > 0 && exists(candidate)) {
                let confidence = if (suffixes[j].size == 0) { "0.72" } else { "0.86" }
                return HapDoctorProbe("found", confidence, candidate, kind + "-path-layout")
            }
            j += 1
        }
        i += 1
    }
    HapDoctorProbe("missing", "0.12", "", "target-profile-only")
}

func addProjectParents(roots: ArrayList<String>, project: String, maxDepth: Int64): Unit {
    var current = if (project.size > 0) { project } else { "." }
    var depth: Int64 = 0
    while (depth <= maxDepth) {
        addUniqueRoot(roots, current)
        let parent = parentPath(current)
        if (parent.size == 0 || parent == current) {
            return
        }
        current = parent
        depth += 1
    }
}

func addUniqueRoot(roots: ArrayList<String>, root: String): Unit {
    let normalized = trimTrailingSlash(trimAsciiText(root))
    if (normalized.size == 0) {
        return
    }
    var i: Int64 = 0
    while (i < roots.size) {
        if (roots[i] == normalized) {
            return
        }
        i += 1
    }
    roots.add(normalized)
}

func readEnvOrEmpty(key: String): String {
    match (getVariable(key)) {
        case Some(value) => trimAsciiText(value)
        case None => ""
    }
}

func appendDoctorScanPolicy(out: StringBuilder, roots: ArrayList<String>): Unit {
    out.append("  \"scanPolicy\": {\n")
    out.append("    \"projectParentDepth\": 4,\n")
    out.append("    \"searchRootEnabled\": true,\n")
    out.append("    \"cjcNearbyScan\": true,\n")
    out.append("    \"stdxDependencyRequired\": false,\n")
    out.append("    \"scannedRootCount\": " + roots.size.toString() + "\n")
    out.append("  }")
}

func appendDoctorNext(out: StringBuilder, subject: String): Unit {
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"register-dictionary-candidate\",\n")
    out.append("    \"plan-repair-temporary\",\n")
    out.append("    \"get-cangjie-" + subject + "-plan\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"doctor does not mutate cjpm.toml\",\n")
    out.append("    \"doctor does not install stdx or runtime assets\",\n")
    out.append("    \"candidate is not canon until proof or human promotion\",\n")
    out.append("    \"HapCLI does not depend on stdx for this diagnostic\"\n")
    out.append("  ]")
}

func parentPath(path: String): String {
    let trimmed = trimTrailingSlash(path)
    let forwardSlash = lastIndexOfText(trimmed, "/")
    let backwardSlash = lastIndexOfText(trimmed, "\\")
    let slash = if (forwardSlash > backwardSlash) { forwardSlash } else { backwardSlash }
    if (slash <= 0) {
        return ""
    }
    substringTo(trimmed, slash)
}

func joinPath(root: String, suffix: String): String {
    let left = trimTrailingSlash(root)
    if (left.size == 0) {
        return suffix
    }
    if (suffix.size == 0) {
        return left
    }
    left + "/" + trimLeadingSlash(suffix)
}

func trimTrailingSlash(path: String): String {
    var out = path
    while (out.size > 1 && (out.endsWith("/") || out.endsWith("\\"))) {
        out = substringTo(out, Int64(out.size - 1))
    }
    out
}

func trimLeadingSlash(path: String): String {
    var out = path
    while (out.size > 0 && startsWithText(out, "/")) {
        out = substringFrom(out, 1)
    }
    out
}

func lastIndexOfText(text: String, needle: String): Int64 {
    if (needle.size == 0) {
        return Int64(text.size)
    }
    var last: Int64 = -1
    var offset: Int64 = 0
    while (offset < text.size) {
        let found = indexOfText(substringFrom(text, offset), needle)
        if (found < 0) {
            return last
        }
        last = offset + found
        offset = last + 1
    }
    last
}
