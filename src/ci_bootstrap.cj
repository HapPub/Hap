package hapcli

public class HapCiBootstrapOptions {
    public var cliBin: String = "hap"
    public var installHint: String = ""

    public init() {}
}

public class HapCiBootstrapPacketOptions {
    public var cliBin: String = "hap"
    public var hapupUrl: String = ""
    public var hapupSha256: String = ""
    public var hapupOutput: String = "/tmp/hapup"
    public var installDir: String = "/tmp/hap/bin"
    public var reviewTokenEnv: String = "HAP_REVIEW_TOKEN"
    public var allowUnverified: Bool = false

    public init() {}
}

public func resolveCiBootstrapOptions(commandLine: Array<String>, start: Int64): HapCiBootstrapOptions {
    let options = HapCiBootstrapOptions()
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
        if (current == "--install-hint" && i + 1 < commandLine.size) {
            options.installHint = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--install-hint=")) {
            options.installHint = substringFrom(current, 15)
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func resolveCiBootstrapPacketOptions(commandLine: Array<String>, start: Int64): HapCiBootstrapPacketOptions {
    let options = HapCiBootstrapPacketOptions()
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
        if (current == "--hapup-url" && i + 1 < commandLine.size) {
            options.hapupUrl = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--hapup-url=")) {
            options.hapupUrl = substringFrom(current, 12)
            i += 1
            continue
        }
        if (current == "--hapup-sha256" && i + 1 < commandLine.size) {
            options.hapupSha256 = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--hapup-sha256=")) {
            options.hapupSha256 = substringFrom(current, 16)
            i += 1
            continue
        }
        if (current == "--hapup-output" && i + 1 < commandLine.size) {
            options.hapupOutput = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--hapup-output=")) {
            options.hapupOutput = substringFrom(current, 15)
            i += 1
            continue
        }
        if (current == "--install-dir" && i + 1 < commandLine.size) {
            options.installDir = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--install-dir=")) {
            options.installDir = substringFrom(current, 14)
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
        if (current == "--allow-unverified") {
            options.allowUnverified = true
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func renderCiBootstrapSnippetJson(options: HapCiBootstrapOptions): String {
    let snippet = renderCiBootstrapSnippet(options)
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-ci-bootstrap-snippet-v0\",\n")
    out.append("  \"ok\": true,\n")
    out.append("  \"mode\": \"read-only-bootstrap-snippet\",\n")
    out.append("  \"cliBin\": \"" + escapeJson(options.cliBin) + "\",\n")
    out.append("  \"installHint\": \"" + escapeJson(options.installHint) + "\",\n")
    out.append("  \"snippet\": \"" + escapeJson(snippet) + "\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"copy-snippet-into-ci-after-review\",\n")
    out.append("    \"provide-reviewed-hapup-install-packet-if-missing\",\n")
    out.append("    \"run-preflight-only-before-fetch-or-deploy\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"bootstrap snippet does not install HapCLI\",\n")
    out.append("    \"bootstrap snippet does not download dependencies\",\n")
    out.append("    \"bootstrap snippet fails clearly when the command is missing\",\n")
    out.append("    \"installer hint is guidance text, not an executed command\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

public func renderCiBootstrapPacketJson(options: HapCiBootstrapPacketOptions): String {
    let requiredOk = options.cliBin.size > 0 && options.hapupUrl.size > 0 && options.hapupOutput.size > 0 && options.installDir.size > 0 && options.reviewTokenEnv.size > 0
    let verificationOk = options.hapupSha256.size > 0 || options.allowUnverified
    let ok = requiredOk && verificationOk
    let status = if (!requiredOk) {
        "missing-required-bootstrap-field"
    } else if (!verificationOk) {
        "missing-sha256-or-unverified-review"
    } else {
        "ready-for-bootstrap-review"
    }
    let snippet = if (ok) {
        renderCiBootstrapPacketSnippet(options)
    } else {
        ""
    }
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-ci-bootstrap-packet-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"reviewed-bootstrap-packet-only\",\n")
    out.append("  \"cliBin\": \"" + escapeJson(options.cliBin) + "\",\n")
    out.append("  \"hapupUrl\": \"" + escapeJson(options.hapupUrl) + "\",\n")
    out.append("  \"hapupOutput\": \"" + escapeJson(options.hapupOutput) + "\",\n")
    out.append("  \"installDir\": \"" + escapeJson(options.installDir) + "\",\n")
    out.append("  \"reviewTokenEnv\": \"" + escapeJson(options.reviewTokenEnv) + "\",\n")
    out.append("  \"sha256Present\": " + boolJson(options.hapupSha256.size > 0) + ",\n")
    out.append("  \"allowUnverified\": " + boolJson(options.allowUnverified) + ",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"workflowMutationActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"installActionTaken\": false,\n")
    out.append("  \"snippet\": \"" + escapeJson(snippet) + "\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-bootstrap-source-and-checksum\",\n")
    out.append("    \"copy-snippet-into-hosted-ci-after-review\",\n")
    out.append("    \"run-bootstrap-before-hap-executor-snippet\",\n")
    out.append("    \"upload-bootstrap-log-or-receipt-as-artifact\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"bootstrap packet does not download inside HapCLI\",\n")
    out.append("    \"bootstrap packet does not install HapCLI inside HapCLI\",\n")
    out.append("    \"bootstrap packet does not mutate workflow files\",\n")
    out.append("    \"bootstrap packet does not publish release artifacts or certify hosted CI adoption\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func renderCiBootstrapSnippet(options: HapCiBootstrapOptions): String {
    let out = StringBuilder()
    let cli = bridgeShellQuote(options.cliBin)
    appendLine(out, "if ! command -v " + cli + " >/dev/null 2>&1; then")
    appendLine(out, "  echo \"::error::" + options.cliBin + " is required before HapCLI preflight can run\"")
    if (options.installHint.size > 0) {
        appendLine(out, "  echo \"Install hint: " + options.installHint + "\"")
    } else {
        appendLine(out, "  echo \"Install hint: add a reviewed hapup/bootstrap step before this preflight\"")
    }
    appendLine(out, "  exit 127")
    appendLine(out, "fi")
    appendLine(out, cli + " version")
    trimTrailingNewlines(out.toString())
}

func renderCiBootstrapPacketSnippet(options: HapCiBootstrapPacketOptions): String {
    let out = StringBuilder()
    appendLine(out, "# Reviewed Hap bootstrap packet")
    appendLine(out, "set -eu")
    let cli = bridgeShellQuote(options.cliBin)
    appendLine(out, "test -n \"$" + options.reviewTokenEnv + "\"")
    appendLine(out, "if command -v " + cli + " >/dev/null 2>&1; then")
    appendLine(out, "  " + cli + " version")
    appendLine(out, "  exit 0")
    appendLine(out, "fi")
    appendLine(out, "mkdir -p " + bridgeShellQuote(options.installDir) + " \"$(dirname " + bridgeShellQuote(options.hapupOutput) + ")\"")
    appendLine(out, "curl -fL -o " + bridgeShellQuote(options.hapupOutput) + " " + bridgeShellQuote(options.hapupUrl))
    if (options.hapupSha256.size > 0) {
        appendLine(out, "if command -v sha256sum >/dev/null 2>&1; then")
        appendLine(out, "  printf '%s  %s\\n' " + bridgeShellQuote(options.hapupSha256) + " " + bridgeShellQuote(options.hapupOutput) + " | sha256sum -c -")
        appendLine(out, "else")
        appendLine(out, "  printf '%s  %s\\n' " + bridgeShellQuote(options.hapupSha256) + " " + bridgeShellQuote(options.hapupOutput) + " | shasum -a 256 -c -")
        appendLine(out, "fi")
    } else {
        appendLine(out, "echo \"::warning::hapup checksum was explicitly marked unverified by review\"")
    }
    appendLine(out, "chmod +x " + bridgeShellQuote(options.hapupOutput))
    appendLine(out, "echo \"hapup downloaded for reviewed bootstrap; run the reviewed flagship install command for this release\"")
    trimTrailingNewlines(out.toString())
}
