package hapcli

import std.collection.ArrayList

public func renderCjpmProfileSwitchPlanJson(
    cjpmText: String,
    profilesText: String,
    input: String,
    profilePath: String,
    targetProfile: String
): String {
    let inspect = inspectCjpmProfileText(cjpmText, input)
    let targetDeps = parseProfileDependencies(profilesText, targetProfile)
    let warnings = ArrayList<String>()
    if (targetDeps.size == 0) {
        warnings.add("target-profile-not-found-or-empty")
    }

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cjpm-profile-switch-plan-v0\",\n")
    out.append("  \"ok\": " + boolJson(targetDeps.size > 0) + ",\n")
    out.append("  \"mode\": \"read-only-plan\",\n")
    out.append("  \"mutationApplied\": false,\n")
    out.append("  \"input\": \"" + escapeJson(input) + "\",\n")
    out.append("  \"profiles\": \"" + escapeJson(profilePath) + "\",\n")
    out.append("  \"fromProfile\": \"" + escapeJson(inspect.inferredProfile) + "\",\n")
    out.append("  \"targetProfile\": \"" + escapeJson(targetProfile) + "\",\n")
    out.append("  \"plannedDependencyCount\": " + targetDeps.size.toString() + ",\n")
    out.append("  \"changes\": [\n")
    appendSwitchChanges(out, inspect, targetDeps)
    out.append("  ],\n")
    out.append("  \"warnings\": [\n")
    appendSwitchWarnings(out, warnings)
    out.append("  ],\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"inspect-cjpm\",\n")
    out.append("    \"plan-switch\",\n")
    out.append("    \"apply-switch-after-review\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

public func parseProfileDependencies(profilesText: String, targetProfile: String): ArrayList<HapDependencyRef> {
    let deps = ArrayList<HapDependencyRef>()
    let header = "[profiles." + targetProfile + ".dependencies]"
    var inTarget = false

    for (line in profilesText.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (trimmed == header) {
            inTarget = true
            continue
        }
        if (startsWithText(trimmed, "[") && trimmed != header) {
            inTarget = false
        }
        if (inTarget && containsText(trimmed, " = {")) {
            deps.add(parseDependencyLine(trimmed))
        }
    }

    deps
}

func appendSwitchChanges(out: StringBuilder, inspect: HapCjpmProfileInspectResult, targetDeps: ArrayList<HapDependencyRef>): Unit {
    var i: Int64 = 0
    while (i < targetDeps.size) {
        let target = targetDeps[i]
        let current = findCurrentDependency(inspect, target.name)
        out.append("    {\n")
        out.append("      \"name\": \"" + escapeJson(target.name) + "\",\n")
        out.append("      \"from\": {\n")
        out.append("        \"kind\": \"" + escapeJson(dependencyKind(current)) + "\",\n")
        out.append("        \"value\": \"" + escapeJson(dependencyValue(current)) + "\"\n")
        out.append("      },\n")
        out.append("      \"to\": {\n")
        out.append("        \"kind\": \"" + escapeJson(dependencyKind(target)) + "\",\n")
        out.append("        \"value\": \"" + escapeJson(dependencyValue(target)) + "\"")
        if (target.branch.size > 0) {
            out.append(",\n        \"branch\": \"" + escapeJson(target.branch) + "\"\n")
        } else if (target.tag.size > 0) {
            out.append(",\n        \"tag\": \"" + escapeJson(target.tag) + "\"\n")
        } else {
            out.append("\n")
        }
        out.append("      },\n")
        out.append("      \"changed\": " + boolJson(dependencySignature(current) != dependencySignature(target)) + "\n")
        out.append("    }")
        if (i + 1 < targetDeps.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
}

func appendSwitchWarnings(out: StringBuilder, warnings: ArrayList<String>): Unit {
    var i: Int64 = 0
    while (i < warnings.size) {
        out.append("    {\n")
        out.append("      \"code\": \"" + escapeJson(warnings[i]) + "\",\n")
        out.append("      \"message\": \"target profile could not produce dependency switch entries\"\n")
        out.append("    }")
        if (i + 1 < warnings.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
}

func findCurrentDependency(inspect: HapCjpmProfileInspectResult, name: String): HapDependencyRef {
    var i: Int64 = 0
    while (i < inspect.pathDependencies.size) {
        let dep = inspect.pathDependencies[i]
        if (dep.name == name) {
            return dep
        }
        i += 1
    }
    i = 0
    while (i < inspect.gitDependencies.size) {
        let dep = inspect.gitDependencies[i]
        if (dep.name == name) {
            return dep
        }
        i += 1
    }
    HapDependencyRef(name, "", "", "", "")
}

func dependencyKind(dep: HapDependencyRef): String {
    if (dep.path.size > 0) {
        return "path"
    }
    if (dep.git.size > 0) {
        return "git"
    }
    "missing"
}

func dependencyValue(dep: HapDependencyRef): String {
    if (dep.path.size > 0) {
        return dep.path
    }
    if (dep.git.size > 0) {
        return dep.git
    }
    ""
}

func dependencySignature(dep: HapDependencyRef): String {
    dependencyKind(dep) + ":" + dependencyValue(dep) + ":branch=" + dep.branch + ":tag=" + dep.tag
}
