package hapcli

import std.collection.ArrayList
import std.fs.{File, exists}

class HapCangjieHarmonyModule {
    var member: String = ""
    var manifest: String = ""
    var kind: String = "unknown"
    var name: String = ""
    var mainAbility: String = ""
    var status: String = "module-manifest-not-found"

    init() {}
}

class HapCangjieHarmonyProject {
    var recognized: Bool = false
    var status: String = "not-cangjie-harmonyos-project"
    var manifest: String = ""
    var appName: String = ""
    var runtimeOs: String = ""
    var workspaceMemberSource: String = "none"
    let abiFilters: ArrayList<String> = ArrayList<String>()
    let workspaceMembers: ArrayList<String> = ArrayList<String>()
    let modules: ArrayList<HapCangjieHarmonyModule> = ArrayList<HapCangjieHarmonyModule>()
    let skippedMembers: ArrayList<String> = ArrayList<String>()

    init() {}
}

func inspectCangjieHarmonyProject(project: String): HapCangjieHarmonyProject {
    let inspection = HapCangjieHarmonyProject()
    inspection.manifest = joinProjectPath(project, "cjpm.toml")
    if (!exists(inspection.manifest)) {
        inspection.status = "root-cjpm-manifest-not-found"
        return inspection
    }
    var text = ""
    try {
        text = String.fromUtf8(File.readFrom(inspection.manifest))
    } catch (_: Exception) {
        inspection.status = "root-cjpm-manifest-unreadable"
        return inspection
    }
    let hasApp = containsTomlSection(text, "app")
    let hasWorkspace = containsTomlSection(text, "workspace")
    inspection.runtimeOs = tomlSectionQuotedValue(text, "app", "runtime-OS")
    inspection.recognized = hasApp && hasWorkspace && inspection.runtimeOs == "HarmonyOS"
    if (!inspection.recognized) {
        return inspection
    }

    inspection.appName = tomlSectionQuotedValue(text, "app", "name")
    addTomlSectionStringArray(text, "app", "abi-filters", inspection.abiFilters)
    addTomlSectionStringArray(text, "workspace", "build-members", inspection.workspaceMembers)
    if (inspection.workspaceMembers.size > 0) {
        inspection.workspaceMemberSource = "build-members"
    } else {
        addTomlSectionStringArray(text, "workspace", "members", inspection.workspaceMembers)
        if (inspection.workspaceMembers.size > 0) {
            inspection.workspaceMemberSource = "members-fallback"
        }
    }

    for (member in inspection.workspaceMembers) {
        if (!isSafeCangjieHarmonyMember(member)) {
            inspection.skippedMembers.add(member + ":unsafe-member-path")
            continue
        }
        let module = inspectCangjieHarmonyModule(project, member)
        inspection.modules.add(module)
    }
    if (inspection.workspaceMembers.size == 0) {
        inspection.status = "workspace-members-missing"
    } else if (inspection.modules.size == 0) {
        inspection.status = "module-graph-empty"
    } else if (hasUsableCangjieHarmonyModule(inspection.modules)) {
        inspection.status = "module-graph-ready"
    } else {
        inspection.status = "module-kind-not-detected"
    }
    inspection
}

func inspectCangjieHarmonyModule(project: String, member: String): HapCangjieHarmonyModule {
    let module = HapCangjieHarmonyModule()
    module.member = member
    module.manifest = joinProjectPath(joinProjectPath(project, member), "cjpm.toml")
    if (!exists(module.manifest)) {
        return module
    }
    var text = ""
    try {
        text = String.fromUtf8(File.readFrom(module.manifest))
    } catch (_: Exception) {
        module.status = "module-manifest-unreadable"
        return module
    }
    if (containsTomlSection(text, "hap")) {
        module.kind = "hap"
    } else if (containsTomlSection(text, "hsp")) {
        module.kind = "hsp"
    } else if (containsTomlSection(text, "har")) {
        module.kind = "har"
    } else {
        module.status = "module-kind-not-detected"
        return module
    }
    module.name = tomlSectionQuotedValue(text, module.kind, "name")
    module.mainAbility = tomlSectionQuotedValue(text, module.kind, "main")
    module.status = "module-ready"
    module
}

func containsTomlSection(text: String, section: String): Bool {
    let header = "[" + section + "]"
    for (line in text.split("\n")) {
        if (trimAsciiText(line) == header) {
            return true
        }
    }
    false
}

func tomlSectionQuotedValue(text: String, section: String, key: String): String {
    let raw = tomlSectionRawValue(text, section, key)
    extractQuotedValue(raw)
}

func addTomlSectionStringArray(text: String, section: String, key: String, out: ArrayList<String>): Unit {
    let raw = tomlSectionRawValue(text, section, key)
    var inQuote = false
    var current = ""
    for (r in raw.toRuneArray()) {
        if (r == r'"') {
            if (inQuote) {
                if (current.size > 0 && !projectStringListContains(out, current)) {
                    out.add(current)
                }
                current = ""
            }
            inQuote = !inQuote
        } else if (inQuote) {
            current += r.toString()
        }
    }
}

func tomlSectionRawValue(text: String, section: String, key: String): String {
    let header = "[" + section + "]"
    var inSection = false
    var collectingArray = false
    var raw = ""
    for (line in text.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (!collectingArray && startsWithText(trimmed, "[")) {
            inSection = trimmed == header
            continue
        }
        if (!inSection) {
            continue
        }
        if (collectingArray) {
            raw += " " + stripTomlComment(trimmed)
            if (containsText(trimmed, "]")) {
                return raw
            }
            continue
        }
        if (startsWithText(trimmed, key + " ") || startsWithText(trimmed, key + "=")) {
            let equal = indexOfText(trimmed, "=")
            if (equal < 0) {
                return ""
            }
            raw = stripTomlComment(trimAsciiText(substringFrom(trimmed, equal + 1)))
            if (startsWithText(raw, "[") && !containsText(raw, "]")) {
                collectingArray = true
                continue
            }
            return raw
        }
    }
    raw
}

func stripTomlComment(text: String): String {
    var inQuote = false
    let runes = text.toRuneArray()
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == r'"') {
            inQuote = !inQuote
        } else if (runes[i] == r'#' && !inQuote) {
            return trimAsciiText(substringRange(text, 0, i))
        }
        i += 1
    }
    trimAsciiText(text)
}

func isSafeCangjieHarmonyMember(member: String): Bool {
    let value = trimAsciiText(member)
    value.size > 0 && !startsWithText(value, "/") && !containsText(value, "\\") &&
        !containsText(value, "..") && !containsText(value, ":")
}

func hasUsableCangjieHarmonyModule(modules: ArrayList<HapCangjieHarmonyModule>): Bool {
    for (module in modules) {
        if (module.status == "module-ready") {
            return true
        }
    }
    false
}

func renderCangjieHarmonyInspectionJson(out: StringBuilder, inspection: HapCangjieHarmonyProject, indent: String): Unit {
    out.append(indent + "{\n")
    out.append(indent + "  \"status\": \"" + escapeJson(inspection.status) + "\",\n")
    out.append(indent + "  \"manifest\": \"" + escapeJson(inspection.manifest) + "\",\n")
    out.append(indent + "  \"appName\": \"" + escapeJson(inspection.appName) + "\",\n")
    out.append(indent + "  \"runtimeOs\": \"" + escapeJson(inspection.runtimeOs) + "\",\n")
    out.append(indent + "  \"workspaceMemberSource\": \"" + escapeJson(inspection.workspaceMemberSource) + "\",\n")
    out.append(indent + "  \"abiFilters\": ")
    appendProjectJsonStringArray(out, inspection.abiFilters)
    out.append(",\n")
    out.append(indent + "  \"workspaceMembers\": ")
    appendProjectJsonStringArray(out, inspection.workspaceMembers)
    out.append(",\n")
    out.append(indent + "  \"skippedMembers\": ")
    appendProjectJsonStringArray(out, inspection.skippedMembers)
    out.append(",\n")
    out.append(indent + "  \"modules\": [\n")
    var i: Int64 = 0
    while (i < inspection.modules.size) {
        let module = inspection.modules[i]
        out.append(indent + "    {\"member\": \"" + escapeJson(module.member) + "\", \"manifest\": \"" + escapeJson(module.manifest) + "\", \"kind\": \"" + escapeJson(module.kind) + "\", \"name\": \"" + escapeJson(module.name) + "\", \"main\": \"" + escapeJson(module.mainAbility) + "\", \"status\": \"" + escapeJson(module.status) + "\"}")
        if (i + 1 < inspection.modules.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
    out.append(indent + "  ]\n")
    out.append(indent + "}")
}
