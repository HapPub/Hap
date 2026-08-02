package hapcli

import std.collection.ArrayList
import std.fs.File

public class HapSwitchApplyOptions {
    public var input: String = ""
    public var profiles: String = ""
    public var targetProfile: String = ""
    public var output: String = ""
    public var receipt: String = ""
    public var reviewToken: String = ""

    public init() {}
}

public func runCjpmProfileSwitchApply(commandLine: Array<String>): String {
    let options = resolveSwitchApplyOptions(commandLine)
    if (!switchApplyGateOk(options)) {
        return renderSwitchApplyRejectedJson(options)
    }

    let cjpmText = String.fromUtf8(File.readFrom(options.input))
    let profilesText = String.fromUtf8(File.readFrom(options.profiles))
    let appliedText = renderAppliedCjpmProfileText(cjpmText, profilesText, options.targetProfile)
    let receipt = renderSwitchApplyReceiptJson(options, appliedText.size)
    File.writeTo(options.output, appliedText.toArray())
    File.writeTo(options.receipt, receipt.toArray())
    renderSwitchApplyOkJson(options, appliedText.size)
}

public func resolveSwitchApplyOptions(commandLine: Array<String>): HapSwitchApplyOptions {
    let options = HapSwitchApplyOptions()
    if (commandLine.size > 2) {
        options.input = commandLine[2]
    }
    if (commandLine.size > 3) {
        options.profiles = commandLine[3]
    }
    if (commandLine.size > 4) {
        options.targetProfile = commandLine[4]
    }

    var i: Int64 = 5
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--output" && i + 1 < commandLine.size) {
            options.output = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--output=")) {
            options.output = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--receipt" && i + 1 < commandLine.size) {
            options.receipt = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--receipt=")) {
            options.receipt = substringFrom(current, 10)
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
        i += 1
    }
    options
}

public func renderAppliedCjpmProfileText(cjpmText: String, profilesText: String, targetProfile: String): String {
    let deps = parseProfileDependencies(profilesText, targetProfile)
    let out = StringBuilder()
    var inDependencies = false
    var inProfile = false

    for (line in cjpmText.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (inDependencies) {
            if (!startsWithText(trimmed, "[")) {
                continue
            }
            inDependencies = false
        }
        if (inProfile) {
            if (!startsWithText(trimmed, "[")) {
                if (startsWithText(trimmed, "current = ") || startsWithText(trimmed, "reason = ")) {
                    continue
                }
                appendLine(out, line)
                continue
            }
            inProfile = false
        }
        if (trimmed == "[dependencies]") {
            appendLine(out, line)
            appendDependencyLines(out, deps)
            appendLine(out, "")
            inDependencies = true
            continue
        }
        if (trimmed == "[tool.hap.profile]") {
            appendLine(out, line)
            appendLine(out, "current = \"" + targetProfile + "\"")
            appendLine(out, "reason = \"" + targetProfileReason(targetProfile) + "\"")
            inProfile = true
            continue
        }
        appendLine(out, line)
    }

    trimTrailingNewlines(out.toString()) + "\n"
}

func switchApplyGateOk(options: HapSwitchApplyOptions): Bool {
    options.input.size > 0 &&
    options.profiles.size > 0 &&
    options.targetProfile.size > 0 &&
    options.output.size > 0 &&
    options.receipt.size > 0 &&
    options.reviewToken.size > 0
}

func renderSwitchApplyRejectedJson(options: HapSwitchApplyOptions): String {
    "{\n" +
    "  \"schema\": \"happub-hapcli-cjpm-profile-switch-apply-v0\",\n" +
    "  \"ok\": false,\n" +
    "  \"mode\": \"review-gated-apply\",\n" +
    "  \"mutationApplied\": false,\n" +
    "  \"status\": \"missing-review-output-or-receipt\",\n" +
    "  \"input\": \"" + escapeJson(options.input) + "\",\n" +
    "  \"targetProfile\": \"" + escapeJson(options.targetProfile) + "\",\n" +
    "  \"nonPromises\": [\n" +
    "    \"apply-switch never rewrites input in place by default\",\n" +
    "    \"review-token, output, and receipt are required\",\n" +
    "    \"no network or stdx dependency is used\"\n" +
    "  ]\n" +
    "}"
}

func renderSwitchApplyOkJson(options: HapSwitchApplyOptions, outputSize: Int64): String {
    "{\n" +
    "  \"schema\": \"happub-hapcli-cjpm-profile-switch-apply-v0\",\n" +
    "  \"ok\": true,\n" +
    "  \"mode\": \"review-gated-apply\",\n" +
    "  \"mutationApplied\": true,\n" +
    "  \"inPlaceMutation\": false,\n" +
    "  \"input\": \"" + escapeJson(options.input) + "\",\n" +
    "  \"profiles\": \"" + escapeJson(options.profiles) + "\",\n" +
    "  \"targetProfile\": \"" + escapeJson(options.targetProfile) + "\",\n" +
    "  \"output\": \"" + escapeJson(options.output) + "\",\n" +
    "  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n" +
    "  \"reviewToken\": \"" + escapeJson(options.reviewToken) + "\",\n" +
    "  \"outputSize\": " + outputSize.toString() + ",\n" +
    "  \"nextAllowed\": [\n" +
    "    \"review-output\",\n" +
    "    \"replace-input-manually\",\n" +
    "    \"restore-from-receipt\"\n" +
    "  ]\n" +
    "}"
}

func renderSwitchApplyReceiptJson(options: HapSwitchApplyOptions, outputSize: Int64): String {
    "{\n" +
    "  \"schema\": \"happub-hapcli-cjpm-profile-switch-receipt-v0\",\n" +
    "  \"input\": \"" + escapeJson(options.input) + "\",\n" +
    "  \"profiles\": \"" + escapeJson(options.profiles) + "\",\n" +
    "  \"targetProfile\": \"" + escapeJson(options.targetProfile) + "\",\n" +
    "  \"output\": \"" + escapeJson(options.output) + "\",\n" +
    "  \"reviewToken\": \"" + escapeJson(options.reviewToken) + "\",\n" +
    "  \"outputSize\": " + outputSize.toString() + ",\n" +
    "  \"inPlaceMutation\": false,\n" +
    "  \"restoreMeaning\": \"input was not overwritten; discard output to restore\"\n" +
    "}"
}

func appendDependencyLines(out: StringBuilder, deps: ArrayList<HapDependencyRef>): Unit {
    var i: Int64 = 0
    while (i < deps.size) {
        appendLine(out, renderDependencyLine(deps[i]))
        i += 1
    }
}

func renderDependencyLine(dep: HapDependencyRef): String {
    if (dep.path.size > 0) {
        return dep.name + " = { path = \"" + dep.path + "\" }"
    }
    var line = dep.name + " = { git = \"" + dep.git + "\""
    if (dep.branch.size > 0) {
        line += ", branch = \"" + dep.branch + "\""
    }
    if (dep.tag.size > 0) {
        line += ", tag = \"" + dep.tag + "\""
    }
    line + " }"
}

func targetProfileReason(targetProfile: String): String {
    match (targetProfile) {
        case "cloud" => "cloud build uses remote dependencies"
        case "review" => "review uses remote dependencies and public mirror profile"
        case "release" => "release uses pinned remote dependencies"
        case "local-dev" => "local development uses sibling checkouts; cloud and review should use remote dependencies"
        case _ => "profile switched by reviewed HapCLI apply"
    }
}

func appendLine(out: StringBuilder, line: String): Unit {
    out.append(line)
    out.append("\n")
}

func trimTrailingNewlines(text: String): String {
    var out = text
    while (out.size > 0 && out.endsWith("\n")) {
        out = substringTo(out, Int64(out.size - 1))
    }
    out
}
