package hapcli

import std.fs.File

public class HapCiProjectBridgeOptions {
    public var project: String = ""
    public var receipt: String = ""
    public var recipeOutput: String = ""
    public var reviewedFetchScript: String = ""
    public var cjpmBin: String = "cjpm"
    public var runTests: Bool = false
    public var reviewToken: String = ""

    public init() {}
}

public func resolveCiProjectBridgeOptions(commandLine: Array<String>, start: Int64): HapCiProjectBridgeOptions {
    let options = HapCiProjectBridgeOptions()
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
        if (current == "--recipe-output" && i + 1 < commandLine.size) {
            options.recipeOutput = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--recipe-output=")) {
            options.recipeOutput = substringFrom(current, 16)
            i += 1
            continue
        }
        if (current == "--reviewed-fetch-script" && i + 1 < commandLine.size) {
            options.reviewedFetchScript = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--reviewed-fetch-script=")) {
            options.reviewedFetchScript = substringFrom(current, 24)
            i += 1
            continue
        }
        if (current == "--cjpm-bin" && i + 1 < commandLine.size) {
            options.cjpmBin = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--cjpm-bin=")) {
            options.cjpmBin = substringFrom(current, 11)
            i += 1
            continue
        }
        if (current == "--run-tests") {
            options.runTests = true
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

public func renderCiProjectBridgeRecipeJson(options: HapCiProjectBridgeOptions): String {
    let requiredOk = options.project.size > 0 && options.receipt.size > 0 && options.recipeOutput.size > 0 && options.cjpmBin.size > 0
    let reviewOk = options.reviewToken.size > 0
    let ok = requiredOk && reviewOk
    let status = if (!requiredOk) {
        "missing-required-field"
    } else if (!reviewOk) {
        "missing-review-token-for-project-bridge"
    } else {
        "ready-for-reviewed-ci-execution"
    }
    let recipe = renderCiProjectBridgeBashRecipe(options)
    var recipeFileWritten = false
    if (ok && recipe.size > 0) {
        File.writeTo(options.recipeOutput, (recipe + "\n").toArray())
        recipeFileWritten = true
    }

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-ci-project-bridge-recipe-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"reviewed-ci-project-bridge-recipe-only\",\n")
    out.append("  \"project\": \"" + escapeJson(options.project) + "\",\n")
    out.append("  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n")
    out.append("  \"recipeOutput\": \"" + escapeJson(options.recipeOutput) + "\",\n")
    out.append("  \"recipeFileWritten\": " + boolJson(recipeFileWritten) + ",\n")
    out.append("  \"reviewedFetchScript\": \"" + escapeJson(options.reviewedFetchScript) + "\",\n")
    out.append("  \"cjpmBin\": \"" + escapeJson(options.cjpmBin) + "\",\n")
    out.append("  \"runTests\": " + boolJson(options.runTests) + ",\n")
    out.append("  \"reviewTokenPresent\": " + boolJson(reviewOk) + ",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"executionActionTaken\": false,\n")
    out.append("  \"mutationActionTaken\": false,\n")
    out.append("  \"recipe\": \"" + escapeJson(recipe) + "\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-generated-project-bridge-script\",\n")
    out.append("    \"execute-project-bridge-in-ci-or-sandbox\",\n")
    out.append("    \"inspect-project-bridge-receipt-before-adoption\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"project bridge recipe does not execute inside HapCLI\",\n")
    out.append("    \"project bridge recipe only runs reviewed fetch script plus cjpm build/test\",\n")
    out.append("    \"project bridge receipt does not certify release readiness\",\n")
    out.append("    \"project bridge recipe does not mutate cjpm.toml\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func renderCiProjectBridgeBashRecipe(options: HapCiProjectBridgeOptions): String {
    if (options.project.size == 0 || options.receipt.size == 0 || options.cjpmBin.size == 0) {
        return ""
    }
    let out = StringBuilder()
    appendLine(out, "set -u")
    appendLine(out, "PROJECT=" + bridgeShellQuote(options.project))
    appendLine(out, "RECEIPT=" + bridgeShellQuote(options.receipt))
    appendLine(out, "REVIEWED_FETCH_SCRIPT=" + bridgeShellQuote(options.reviewedFetchScript))
    appendLine(out, "CJPM_BIN=" + bridgeShellQuote(options.cjpmBin))
    appendLine(out, "RUN_TESTS=" + bridgeShellQuote(boolJson(options.runTests)))
    appendLine(out, "FETCH_EXIT=0")
    appendLine(out, "BUILD_EXIT=0")
    appendLine(out, "TEST_EXIT=0")
    appendLine(out, "if [ -n \"$REVIEWED_FETCH_SCRIPT\" ]; then")
    appendLine(out, "  sh \"$REVIEWED_FETCH_SCRIPT\"")
    appendLine(out, "  FETCH_EXIT=$?")
    appendLine(out, "fi")
    appendLine(out, "cd \"$PROJECT\"")
    appendLine(out, "\"$CJPM_BIN\" build")
    appendLine(out, "BUILD_EXIT=$?")
    appendLine(out, "if [ \"$RUN_TESTS\" = \"true\" ]; then")
    appendLine(out, "  \"$CJPM_BIN\" test")
    appendLine(out, "  TEST_EXIT=$?")
    appendLine(out, "fi")
    appendLine(out, "OK=false")
    appendLine(out, "if [ \"$FETCH_EXIT\" -eq 0 ] && [ \"$BUILD_EXIT\" -eq 0 ] && { [ \"$RUN_TESTS\" != \"true\" ] || [ \"$TEST_EXIT\" -eq 0 ]; }; then")
    appendLine(out, "  OK=true")
    appendLine(out, "fi")
    appendLine(out, "mkdir -p \"$(dirname \"$RECEIPT\")\"")
    appendLine(out, "printf '{\"schema\":\"happub-hapcli-ci-project-bridge-receipt-v0\",\"ok\":%s,\"project\":\"" + escapeJson(options.project) + "\",\"reviewedFetchScript\":\"" + escapeJson(options.reviewedFetchScript) + "\",\"fetchExit\":%s,\"buildExit\":%s,\"testExit\":%s,\"runTests\":" + boolJson(options.runTests) + ",\"buildActionTaken\":true,\"testActionTaken\":" + boolJson(options.runTests) + ",\"canonMutation\":false}\\n' \"$OK\" \"$FETCH_EXIT\" \"$BUILD_EXIT\" \"$TEST_EXIT\" > \"$RECEIPT\"")
    appendLine(out, "if [ \"$OK\" = \"true\" ]; then")
    appendLine(out, "  exit 0")
    appendLine(out, "fi")
    appendLine(out, "exit 1")
    trimTrailingNewlines(out.toString())
}

func bridgeShellQuote(value: String): String {
    let out = StringBuilder()
    out.append("'")
    for (r in value.toRuneArray()) {
        if (r == r'\'') {
            out.append("'\\''")
        } else {
            out.append(r.toString())
        }
    }
    out.append("'")
    out.toString()
}
