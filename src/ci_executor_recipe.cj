package hapcli

import std.fs.File

public class HapCiExecutorOptions {
    public var receipt: String = ""
    public var recipeOutput: String = ""
    public var reviewedFetchScript: String = ""
    public var envApplyScript: String = ""
    public var projectBridgeScript: String = ""
    public var reviewToken: String = ""

    public init() {}
}

public class HapCiExecutorSnippetOptions {
    public var cliBin: String = "hap"
    public var reviewedFetchScript: String = ""
    public var envApplyScript: String = ""
    public var projectBridgeScript: String = ""
    public var executorScript: String = "/tmp/hap-executor.sh"
    public var executorReceipt: String = "/tmp/hap-executor.receipt.json"
    public var reviewTokenEnv: String = "HAP_REVIEW_TOKEN"

    public init() {}
}

public func resolveCiExecutorOptions(commandLine: Array<String>, start: Int64): HapCiExecutorOptions {
    let options = HapCiExecutorOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
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
        if (current == "--env-apply-script" && i + 1 < commandLine.size) {
            options.envApplyScript = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--env-apply-script=")) {
            options.envApplyScript = substringFrom(current, 19)
            i += 1
            continue
        }
        if (current == "--project-bridge-script" && i + 1 < commandLine.size) {
            options.projectBridgeScript = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--project-bridge-script=")) {
            options.projectBridgeScript = substringFrom(current, 24)
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

public func resolveCiExecutorSnippetOptions(commandLine: Array<String>, start: Int64): HapCiExecutorSnippetOptions {
    let options = HapCiExecutorSnippetOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--cli-bin" && i + 1 < commandLine.size) {
            options.cliBin = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--cli-bin=")) {
            options.cliBin = substringFrom(current, 10)
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
        if (current == "--env-apply-script" && i + 1 < commandLine.size) {
            options.envApplyScript = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--env-apply-script=")) {
            options.envApplyScript = substringFrom(current, 19)
            i += 1
            continue
        }
        if (current == "--project-bridge-script" && i + 1 < commandLine.size) {
            options.projectBridgeScript = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--project-bridge-script=")) {
            options.projectBridgeScript = substringFrom(current, 24)
            i += 1
            continue
        }
        if (current == "--executor-script" && i + 1 < commandLine.size) {
            options.executorScript = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--executor-script=")) {
            options.executorScript = substringFrom(current, 18)
            i += 1
            continue
        }
        if (current == "--executor-receipt" && i + 1 < commandLine.size) {
            options.executorReceipt = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--executor-receipt=")) {
            options.executorReceipt = substringFrom(current, 19)
            i += 1
            continue
        }
        if (current == "--review-token-env" && i + 1 < commandLine.size) {
            options.reviewTokenEnv = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--review-token-env=")) {
            options.reviewTokenEnv = substringFrom(current, 19)
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func renderCiExecutorRecipeJson(options: HapCiExecutorOptions): String {
    let requiredOk = options.receipt.size > 0 && options.recipeOutput.size > 0 && hasAnyExecutorStep(options)
    let reviewOk = options.reviewToken.size > 0
    let ok = requiredOk && reviewOk
    let status = if (!requiredOk) {
        "missing-required-field-or-step"
    } else if (!reviewOk) {
        "missing-review-token-for-ci-executor"
    } else {
        "ready-for-reviewed-ci-executor"
    }
    let recipe = renderCiExecutorBashRecipe(options)
    var recipeFileWritten = false
    if (ok && recipe.size > 0) {
        File.writeTo(options.recipeOutput, (recipe + "\n").toArray())
        recipeFileWritten = true
    }

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-ci-executor-recipe-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"reviewed-ci-executor-recipe-only\",\n")
    out.append("  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n")
    out.append("  \"recipeOutput\": \"" + escapeJson(options.recipeOutput) + "\",\n")
    out.append("  \"recipeFileWritten\": " + boolJson(recipeFileWritten) + ",\n")
    out.append("  \"reviewedFetchScript\": \"" + escapeJson(options.reviewedFetchScript) + "\",\n")
    out.append("  \"envApplyScript\": \"" + escapeJson(options.envApplyScript) + "\",\n")
    out.append("  \"projectBridgeScript\": \"" + escapeJson(options.projectBridgeScript) + "\",\n")
    out.append("  \"reviewTokenPresent\": " + boolJson(reviewOk) + ",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"executionActionTaken\": false,\n")
    out.append("  \"mutationActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"recipe\": \"" + escapeJson(recipe) + "\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-generated-ci-executor-script\",\n")
    out.append("    \"execute-executor-in-ci-or-sandbox\",\n")
    out.append("    \"inspect-executor-receipt-before-adoption\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"ci executor recipe does not execute inside HapCLI\",\n")
    out.append("    \"ci executor recipe only runs explicit reviewed script paths supplied by the caller\",\n")
    out.append("    \"ci executor receipt does not certify release readiness\",\n")
    out.append("    \"ci executor recipe does not install HapCLI or mutate workflow files\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

public func renderCiExecutorSnippetJson(options: HapCiExecutorSnippetOptions): String {
    let stepOk = options.reviewedFetchScript.size > 0 || options.envApplyScript.size > 0 || options.projectBridgeScript.size > 0
    let requiredOk = options.cliBin.size > 0 && options.executorScript.size > 0 && options.executorReceipt.size > 0 && options.reviewTokenEnv.size > 0 && stepOk
    let status = if (requiredOk) {
        "ready-for-workflow-review"
    } else {
        "missing-required-field-or-step"
    }
    let snippet = if (requiredOk) {
        renderCiExecutorWorkflowSnippet(options)
    } else {
        ""
    }
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-ci-executor-snippet-v0\",\n")
    out.append("  \"ok\": " + boolJson(requiredOk) + ",\n")
    out.append("  \"mode\": \"reviewed-workflow-snippet-only\",\n")
    out.append("  \"cliBin\": \"" + escapeJson(options.cliBin) + "\",\n")
    out.append("  \"executorScript\": \"" + escapeJson(options.executorScript) + "\",\n")
    out.append("  \"executorReceipt\": \"" + escapeJson(options.executorReceipt) + "\",\n")
    out.append("  \"reviewTokenEnv\": \"" + escapeJson(options.reviewTokenEnv) + "\",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"workflowMutationActionTaken\": false,\n")
    out.append("  \"executionActionTaken\": false,\n")
    out.append("  \"snippet\": \"" + escapeJson(snippet) + "\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-snippet-before-workflow-patch\",\n")
    out.append("    \"run-in-downstream-ci-as-non-mutating-preflight\",\n")
    out.append("    \"upload-executor-receipt-as-artifact\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"executor snippet does not mutate workflow files\",\n")
    out.append("    \"executor snippet does not install HapCLI\",\n")
    out.append("    \"executor snippet requires a review token environment variable at CI runtime\",\n")
    out.append("    \"executor snippet does not certify downstream adoption\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func hasAnyExecutorStep(options: HapCiExecutorOptions): Bool {
    options.reviewedFetchScript.size > 0 || options.envApplyScript.size > 0 || options.projectBridgeScript.size > 0
}

func renderCiExecutorBashRecipe(options: HapCiExecutorOptions): String {
    if (options.receipt.size == 0 || !hasAnyExecutorStep(options)) {
        return ""
    }
    let out = StringBuilder()
    appendLine(out, "set -u")
    appendLine(out, "RECEIPT=" + bridgeShellQuote(options.receipt))
    appendLine(out, "REVIEWED_FETCH_SCRIPT=" + bridgeShellQuote(options.reviewedFetchScript))
    appendLine(out, "ENV_APPLY_SCRIPT=" + bridgeShellQuote(options.envApplyScript))
    appendLine(out, "PROJECT_BRIDGE_SCRIPT=" + bridgeShellQuote(options.projectBridgeScript))
    appendLine(out, "FETCH_EXIT=0")
    appendLine(out, "ENV_EXIT=0")
    appendLine(out, "BRIDGE_EXIT=0")
    appendLine(out, "if [ -n \"$REVIEWED_FETCH_SCRIPT\" ]; then")
    appendLine(out, "  sh \"$REVIEWED_FETCH_SCRIPT\"")
    appendLine(out, "  FETCH_EXIT=$?")
    appendLine(out, "fi")
    appendLine(out, "if [ -n \"$ENV_APPLY_SCRIPT\" ]; then")
    appendLine(out, "  sh \"$ENV_APPLY_SCRIPT\"")
    appendLine(out, "  ENV_EXIT=$?")
    appendLine(out, "fi")
    appendLine(out, "if [ -n \"$PROJECT_BRIDGE_SCRIPT\" ]; then")
    appendLine(out, "  sh \"$PROJECT_BRIDGE_SCRIPT\"")
    appendLine(out, "  BRIDGE_EXIT=$?")
    appendLine(out, "fi")
    appendLine(out, "OK=false")
    appendLine(out, "if [ \"$FETCH_EXIT\" -eq 0 ] && [ \"$ENV_EXIT\" -eq 0 ] && [ \"$BRIDGE_EXIT\" -eq 0 ]; then")
    appendLine(out, "  OK=true")
    appendLine(out, "fi")
    appendLine(out, "mkdir -p \"$(dirname \"$RECEIPT\")\"")
    appendLine(out, "printf '{\"schema\":\"happub-hapcli-ci-executor-receipt-v0\",\"ok\":%s,\"reviewedFetchScript\":\"" + escapeJson(options.reviewedFetchScript) + "\",\"envApplyScript\":\"" + escapeJson(options.envApplyScript) + "\",\"projectBridgeScript\":\"" + escapeJson(options.projectBridgeScript) + "\",\"fetchExit\":%s,\"envExit\":%s,\"bridgeExit\":%s,\"executionActionTaken\":true,\"workflowMutationActionTaken\":false,\"canonMutation\":false}\\n' \"$OK\" \"$FETCH_EXIT\" \"$ENV_EXIT\" \"$BRIDGE_EXIT\" > \"$RECEIPT\"")
    appendLine(out, "if [ \"$OK\" = \"true\" ]; then")
    appendLine(out, "  exit 0")
    appendLine(out, "fi")
    appendLine(out, "exit 1")
    trimTrailingNewlines(out.toString())
}

func renderCiExecutorWorkflowSnippet(options: HapCiExecutorSnippetOptions): String {
    let out = StringBuilder()
    appendLine(out, "# Reviewed HapCLI executor preflight")
    appendLine(out, "test -n \"$" + options.reviewTokenEnv + "\"")
    appendLine(out, options.cliBin + " ci executor-recipe \\")
    if (options.reviewedFetchScript.size > 0) {
        appendLine(out, "  --reviewed-fetch-script=" + bridgeShellQuote(options.reviewedFetchScript) + " \\")
    }
    if (options.envApplyScript.size > 0) {
        appendLine(out, "  --env-apply-script=" + bridgeShellQuote(options.envApplyScript) + " \\")
    }
    if (options.projectBridgeScript.size > 0) {
        appendLine(out, "  --project-bridge-script=" + bridgeShellQuote(options.projectBridgeScript) + " \\")
    }
    appendLine(out, "  --receipt=" + bridgeShellQuote(options.executorReceipt) + " \\")
    appendLine(out, "  --recipe-output=" + bridgeShellQuote(options.executorScript) + " \\")
    appendLine(out, "  --review-token=\"$" + options.reviewTokenEnv + "\"")
    appendLine(out, "sh " + bridgeShellQuote(options.executorScript))
    appendLine(out, "test -f " + bridgeShellQuote(options.executorReceipt))
    trimTrailingNewlines(out.toString())
}
