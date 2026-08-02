package hapcli

import std.collection.ArrayList

public func inspectCjpmProfileText(text: String, input: String): HapCjpmProfileInspectResult {
    let pathDeps = ArrayList<HapDependencyRef>()
    let gitDeps = ArrayList<HapDependencyRef>()
    var inDependencies = false
    var profile = ""

    for (line in text.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (trimmed == "[dependencies]") {
            inDependencies = true
            continue
        }
        if (startsWithText(trimmed, "[") && trimmed != "[dependencies]") {
            inDependencies = false
        }
        if (trimmed == "[tool.hap.profile]") {
            profile = ""
            continue
        }
        if (startsWithText(trimmed, "current = ")) {
            profile = extractQuotedValue(trimmed)
        }
        if (inDependencies && containsText(trimmed, " = {")) {
            let dep = parseDependencyLine(trimmed)
            if (dep.isPathDependency()) {
                pathDeps.add(dep)
            } else if (dep.isGitDependency()) {
                gitDeps.add(dep)
            }
        }
    }

    let warnings = ArrayList<String>()
    if (pathDeps.size > 0) {
        warnings.add("local-path-dependency-not-cloud-safe")
    }

    let nextAllowed = ArrayList<String>()
    nextAllowed.add("switch-cloud")
    nextAllowed.add("switch-review")
    nextAllowed.add("stdx-doctor")
    nextAllowed.add("runtime-doctor")

    let inferred = if (profile.size > 0) {
        profile
    } else if (pathDeps.size > 0 && gitDeps.size > 0) {
        "local-dev"
    } else if (pathDeps.size > 0) {
        "local-dev"
    } else {
        "cloud"
    }

    HapCjpmProfileInspectResult(
        "happub-hapcli-cjpm-profile-inspect-v0",
        true,
        "local-cloud-cjpm-profile",
        input,
        inferred,
        pathDeps,
        gitDeps,
        pathDeps.size > 0 && gitDeps.size > 0,
        warnings,
        nextAllowed
    )
}

public func renderCjpmProfileInspectJson(result: HapCjpmProfileInspectResult): String {
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"" + escapeJson(result.schema) + "\",\n")
    out.append("  \"ok\": " + boolJson(result.ok) + ",\n")
    out.append("  \"fixtureId\": \"" + escapeJson(result.fixtureId) + "\",\n")
    out.append("  \"input\": \"" + escapeJson(result.input) + "\",\n")
    out.append("  \"inferredProfile\": \"" + escapeJson(result.inferredProfile) + "\",\n")
    out.append("  \"dependencySummary\": {\n")
    out.append("    \"pathDependencies\": [\n")
    appendDependencyArray(out, result.pathDependencies, true)
    out.append("    ],\n")
    out.append("    \"gitDependencies\": [\n")
    appendDependencyArray(out, result.gitDependencies, false)
    out.append("    ],\n")
    out.append("    \"mixedProfile\": " + boolJson(result.mixedProfile) + "\n")
    out.append("  },\n")
    out.append("  \"warnings\": [\n")
    appendWarnings(out, result.warnings)
    out.append("  ],\n")
    out.append("  \"nextAllowed\": [\n")
    appendStrings(out, result.nextAllowed)
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func appendDependencyArray(out: StringBuilder, deps: ArrayList<HapDependencyRef>, pathMode: Bool): Unit {
    var i: Int64 = 0
    while (i < deps.size) {
        let dep = deps[i]
        out.append("      {\n")
        out.append("        \"name\": \"" + escapeJson(dep.name) + "\"")
        if (pathMode) {
            out.append(",\n        \"path\": \"" + escapeJson(dep.path) + "\"\n")
        } else {
            out.append(",\n        \"git\": \"" + escapeJson(dep.git) + "\"")
            if (dep.branch.size > 0) {
                out.append(",\n        \"branch\": \"" + escapeJson(dep.branch) + "\"\n")
            } else if (dep.tag.size > 0) {
                out.append(",\n        \"tag\": \"" + escapeJson(dep.tag) + "\"\n")
            } else {
                out.append("\n")
            }
        }
        out.append("      }")
        if (i + 1 < deps.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
}

func appendWarnings(out: StringBuilder, warnings: ArrayList<String>): Unit {
    var i: Int64 = 0
    while (i < warnings.size) {
        out.append("    {\n")
        out.append("      \"code\": \"" + escapeJson(warnings[i]) + "\",\n")
        out.append("      \"message\": \"local path dependencies should be switched before cloud or review handoff\"\n")
        out.append("    }")
        if (i + 1 < warnings.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
}

func appendStrings(out: StringBuilder, items: ArrayList<String>): Unit {
    var i: Int64 = 0
    while (i < items.size) {
        out.append("    \"" + escapeJson(items[i]) + "\"")
        if (i + 1 < items.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
}

func parseDependencyLine(line: String): HapDependencyRef {
    let eq = indexOfText(line, " = ")
    let name = if (eq >= 0) { substringTo(line, eq) } else { "" }
    HapDependencyRef(
        name,
        extractInlineField(line, "path"),
        extractInlineField(line, "git"),
        extractInlineField(line, "branch"),
        extractInlineField(line, "tag")
    )
}

func extractInlineField(line: String, key: String): String {
    let marker = key + " = \""
    let start = indexOfText(line, marker)
    if (start < 0) {
        return ""
    }
    let valueStart = start + Int64(marker.size)
    let rest = substringFrom(line, valueStart)
    let end = indexOfText(rest, "\"")
    if (end < 0) {
        return ""
    }
    substringTo(rest, end)
}

func extractQuotedValue(line: String): String {
    let first = indexOfText(line, "\"")
    if (first < 0) {
        return ""
    }
    let rest = substringFrom(line, first + 1)
    let second = indexOfText(rest, "\"")
    if (second < 0) {
        return ""
    }
    substringTo(rest, second)
}

func boolJson(value: Bool): String {
    if (value) { "true" } else { "false" }
}

public func escapeJson(text: String): String {
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

func containsText(text: String, needle: String): Bool {
    indexOfText(text, needle) >= 0
}

func startsWithText(text: String, prefix: String): Bool {
    if (prefix.size > text.size) {
        return false
    }
    substringTo(text, Int64(prefix.size)) == prefix
}

func indexOfText(text: String, needle: String): Int64 {
    if (needle.size == 0) {
        return 0
    }
    let textRunes = text.toRuneArray()
    let needleRunes = needle.toRuneArray()
    if (needleRunes.size > textRunes.size) {
        return -1
    }
    var i: Int64 = 0
    while (i <= textRunes.size - needleRunes.size) {
        var j: Int64 = 0
        var matched = true
        while (j < needleRunes.size) {
            if (textRunes[i + j] != needleRunes[j]) {
                matched = false
                break
            }
            j += 1
        }
        if (matched) {
            return i
        }
        i += 1
    }
    -1
}

func trimAsciiText(text: String): String {
    let runes = text.toRuneArray()
    var start: Int64 = 0
    var end: Int64 = runes.size
    while (start < end && isAsciiWhitespace(runes[start])) {
        start += 1
    }
    while (end > start && isAsciiWhitespace(runes[end - 1])) {
        end -= 1
    }
    substringRange(text, start, end)
}

func isAsciiWhitespace(r: Rune): Bool {
    r == r' ' || r == r'\t' || r == r'\n' || r == r'\r'
}

func substringTo(text: String, end: Int64): String {
    substringRange(text, 0, end)
}

func substringFrom(text: String, start: Int64): String {
    substringRange(text, start, Int64(text.toRuneArray().size))
}

func substringRange(text: String, start: Int64, end: Int64): String {
    let runes = text.toRuneArray()
    var out = ""
    var i = start
    while (i < end && i < runes.size) {
        out += runes[i].toString()
        i += 1
    }
    out
}
