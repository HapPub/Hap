package hapcli

import std.collection.ArrayList

public class HapUpdatePlanOptions {
    public var action: String = "update"
    public var subject: String = "dependencies"
    public var project: String = "."
    public var target: String = "auto"
    public var plan: Bool = false
    public var reviewToken: String = ""

    public init() {}
}

public func resolveUpdatePlanOptions(action: String, commandLine: Array<String>, startIndex: Int64): HapUpdatePlanOptions {
    let options = HapUpdatePlanOptions()
    options.action = action
    var i = startIndex
    if (i < commandLine.size && !startsWithText(commandLine[i], "-")) {
        options.subject = commandLine[i]
        i += 1
    }
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
            options.target = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--target=")) {
            options.target = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--subject" && i + 1 < commandLine.size) {
            options.subject = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--subject=")) {
            options.subject = substringFrom(current, 10)
            i += 1
            continue
        }
        if (current == "--review-token" && i + 1 < commandLine.size) {
            options.reviewToken = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--review-token=")) {
            options.reviewToken = substringFrom(current, 15)
            i += 1
            continue
        }
        if (current == "--plan") {
            options.plan = true
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func renderUpdatePlanJson(options: HapUpdatePlanOptions): String {
    let normalizedSubject = normalizeUpdateSubject(options.subject)
    let ok = normalizedSubject != "unsupported"
    let status = if (!ok) {
        "unsupported-update-subject"
    } else if (options.action == "upgrade") {
        "review-required-plan-ready"
    } else {
        "recommendation-plan-ready"
    }
    let commands = updatePlanCommands(options.action, normalizedSubject)

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-update-plan-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"plan-only\",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"action\": \"" + escapeJson(options.action) + "\",\n")
    out.append("  \"subject\": \"" + escapeJson(normalizedSubject) + "\",\n")
    out.append("  \"project\": \"" + escapeJson(options.project) + "\",\n")
    out.append("  \"target\": \"" + escapeJson(options.target) + "\",\n")
    out.append("  \"reviewTokenProvided\": " + boolJson(options.reviewToken.size > 0) + ",\n")
    out.append("  \"executionActionTaken\": false,\n")
    out.append("  \"mutationActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"selfUpgradeActionTaken\": false,\n")
    out.append("  \"workflowMutationActionTaken\": false,\n")
    out.append("  \"fixedCommandTemplates\": ")
    appendProjectJsonStringArray(out, commands)
    out.append(",\n")
    out.append("  \"reviewGate\": {\n")
    out.append("    \"requiredForMutation\": true,\n")
    out.append("    \"acceptedNow\": false,\n")
    out.append("    \"reason\": \"this slice emits update or upgrade plans only\"\n")
    out.append("  },\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"turn update recommendations into reviewed patch candidates\",\n")
    out.append("    \"route hap self-upgrade through hapup install-flagship with checksum proof\",\n")
    out.append("    \"keep dependency mutation separate from project build/test execution\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"this plan does not download, install, mutate manifests, or replace hap\",\n")
    out.append("    \"upgrade remains review-gated even when a review token is provided\",\n")
    out.append("    \"HapCLI is not a package manager or SDK version manager\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func normalizeUpdateSubject(subject: String): String {
    if (subject == "" || subject == "deps" || subject == "dependencies" || subject == "dependency") {
        return "dependencies"
    }
    if (subject == "hap" || subject == "self" || subject == "self-upgrade") {
        return "hap"
    }
    if (subject == "toolchain" || subject == "runtime" || subject == "stdx") {
        return "toolchain"
    }
    "unsupported"
}

func updatePlanCommands(action: String, subject: String): ArrayList<String> {
    let commands = ArrayList<String>()
    if (subject == "dependencies") {
        commands.add("hap ci action-doctor --workflow <workflow> --project <project>")
        commands.add("hap cjpm graph doctor --manifest <cjpm.toml>")
        if (action == "upgrade") {
            commands.add("write reviewed dependency patch candidate")
        } else {
            commands.add("emit recommended dependency update candidates")
        }
    } else if (subject == "hap") {
        commands.add("hap release manifest --base-url <source>")
        commands.add("hapup install-flagship --asset <reviewed-hap-asset> --sha256 <sha256>")
    } else if (subject == "toolchain") {
        commands.add("hap toolchain providers")
        commands.add("hap toolchain doctor --project <project> --target <target>")
        commands.add("emit reviewed runtime/stdx acquisition plan")
    }
    commands
}
