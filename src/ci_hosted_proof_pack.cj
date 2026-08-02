package hapcli

import std.fs.{Directory, File, exists}

public class HapCiHostedProofPackOptions {
    public var outputDir: String = ""
    public var project: String = "."
    public var target: String = "linux-amd64"
    public var cliBin: String = "hap"
    public var hapupUrl: String = "https://cli.hap.pub/install/hapup.sh"
    public var hapupSha256: String = ""
    public var installDir: String = "/tmp/hap/bin"
    public var reviewTokenEnv: String = "HAP_REVIEW_TOKEN"
    public var assetUrlEnv: String = "HAP_FLAGSHIP_ASSET_URL"
    public var assetSha256Env: String = "HAP_FLAGSHIP_ASSET_SHA256"
    public var runTests: Bool = false
    public var allowUnverifiedHapup: Bool = false

    public init() {}
}

public func resolveCiHostedProofPackOptions(commandLine: Array<String>, start: Int64): HapCiHostedProofPackOptions {
    let options = HapCiHostedProofPackOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--output-dir" && i + 1 < commandLine.size) {
            options.outputDir = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--output-dir=")) {
            options.outputDir = substringFrom(current, 13)
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
        if (current == "--asset-url-env" && i + 1 < commandLine.size) {
            options.assetUrlEnv = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--asset-url-env=")) {
            options.assetUrlEnv = substringFrom(current, 16)
            i += 1
            continue
        }
        if (current == "--asset-sha256-env" && i + 1 < commandLine.size) {
            options.assetSha256Env = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--asset-sha256-env=")) {
            options.assetSha256Env = substringFrom(current, 19)
            i += 1
            continue
        }
        if (current == "--run-tests") {
            options.runTests = true
            i += 1
            continue
        }
        if (current == "--allow-unverified-hapup") {
            options.allowUnverifiedHapup = true
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func renderCiHostedProofPackJson(options: HapCiHostedProofPackOptions): String {
    let target = canonicalTargetName(options.target)
    let platform = cangjiePlatformNameForTarget(target)
    let requiredOk = options.cliBin.size > 0 && options.hapupUrl.size > 0 && options.installDir.size > 0 && options.reviewTokenEnv.size > 0 && options.assetUrlEnv.size > 0 && options.assetSha256Env.size > 0 && platform.size > 0
    let verificationOk = options.hapupSha256.size > 0 || options.allowUnverifiedHapup
    let ok = requiredOk && verificationOk
    let status = if (!requiredOk) {
        "missing-required-hosted-proof-field"
    } else if (!verificationOk) {
        "missing-hapup-sha256-or-unverified-review"
    } else {
        "ready-for-hosted-proof-review"
    }
    let workflow = if (ok) {
        renderCiHostedProofWorkflow(options, target, platform)
    } else {
        ""
    }
    let readme = if (ok) {
        renderCiHostedProofReadme(options, target)
    } else {
        ""
    }
    var workflowWritten = false
    var readmeWritten = false
    var manifestWritten = false
    let workflowPath = proofPackPath(options.outputDir, "hap-hosted-proof.yml")
    let readmePath = proofPackPath(options.outputDir, "README_HOSTED_PROOF.md")
    let manifestPath = proofPackPath(options.outputDir, "hosted-proof-pack.json")
    if (ok && options.outputDir.size > 0) {
        if (!exists(options.outputDir)) {
            Directory.create(options.outputDir, recursive: true)
        }
        File.writeTo(workflowPath, (workflow + "\n").toArray())
        workflowWritten = true
        File.writeTo(readmePath, readme.toArray())
        readmeWritten = true
        File.writeTo(manifestPath, renderCiHostedProofManifest(options, target, platform, workflowPath, readmePath).toArray())
        manifestWritten = true
    }

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-ci-hosted-proof-pack-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"reviewed-hosted-ci-proof-pack-only\",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"project\": \"" + escapeJson(options.project) + "\",\n")
    out.append("  \"target\": \"" + escapeJson(target) + "\",\n")
    out.append("  \"platform\": \"" + escapeJson(platform) + "\",\n")
    out.append("  \"outputDir\": \"" + escapeJson(options.outputDir) + "\",\n")
    out.append("  \"workflowPath\": \"" + escapeJson(workflowPath) + "\",\n")
    out.append("  \"readmePath\": \"" + escapeJson(readmePath) + "\",\n")
    out.append("  \"manifestPath\": \"" + escapeJson(manifestPath) + "\",\n")
    out.append("  \"workflowWritten\": " + boolJson(workflowWritten) + ",\n")
    out.append("  \"readmeWritten\": " + boolJson(readmeWritten) + ",\n")
    out.append("  \"manifestWritten\": " + boolJson(manifestWritten) + ",\n")
    out.append("  \"workflowMutationActionTaken\": false,\n")
    out.append("  \"hostedRunActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"installActionTaken\": false,\n")
    out.append("  \"workflow\": \"" + escapeJson(workflow) + "\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-generated-hosted-proof-workflow\",\n")
    out.append("    \"run-on-disposable-branch-or-sandbox-project\",\n")
    out.append("    \"return-uploaded-hap-proof-artifact\",\n")
    out.append("    \"do-not-replace-green-workflow-without-owner-approval\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"hosted proof pack does not mutate workflow files\",\n")
    out.append("    \"hosted proof pack does not execute CI from HapCLI\",\n")
    out.append("    \"hosted proof pack does not download or install inside HapCLI\",\n")
    out.append("    \"hosted proof pack does not certify downstream adoption or release readiness\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func proofPackPath(outputDir: String, name: String): String {
    if (outputDir.size == 0) {
        return ""
    }
    outputDir + "/" + name
}

func renderCiHostedProofWorkflow(options: HapCiHostedProofPackOptions, target: String, platform: String): String {
    let out = StringBuilder()
    appendLine(out, "name: Hap hosted proof")
    appendLine(out, "")
    appendLine(out, "on:")
    appendLine(out, "  workflow_dispatch:")
    appendLine(out, "")
    appendLine(out, "jobs:")
    appendLine(out, "  hap-hosted-proof:")
    appendLine(out, "    runs-on: ubuntu-latest")
    appendLine(out, "    env:")
    appendLine(out, "      HAP_REVIEW_TOKEN: " + githubExpr("secrets." + options.reviewTokenEnv))
    appendLine(out, "      HAP_FLAGSHIP_ASSET_URL: " + githubExpr("vars." + options.assetUrlEnv))
    appendLine(out, "      HAP_FLAGSHIP_ASSET_SHA256: " + githubExpr("vars." + options.assetSha256Env))
    appendLine(out, "      HAP_INSTALL_DIR: " + options.installDir)
    appendLine(out, "      HAP_PROOF_DIR: " + githubExpr("runner.temp") + "/hap-hosted-proof")
    appendLine(out, "      HAP_TARGET: " + target)
    appendLine(out, "      HAP_PLATFORM: " + platform)
    appendLine(out, "    steps:")
    appendLine(out, "      - uses: actions/checkout@v4")
    appendLine(out, "      - name: Prepare proof directory")
    appendLine(out, "        shell: bash")
    appendLine(out, "        run: |")
    appendLine(out, "          set -eu")
    appendLine(out, "          mkdir -p \"$HAP_PROOF_DIR\" \"$HAP_INSTALL_DIR\"")
    appendLine(out, "          test -n \"$HAP_REVIEW_TOKEN\"")
    appendLine(out, "          test -n \"$HAP_FLAGSHIP_ASSET_URL\"")
    appendLine(out, "          test -n \"$HAP_FLAGSHIP_ASSET_SHA256\"")
    appendLine(out, "      - name: Reviewed hapup bootstrap")
    appendLine(out, "        shell: bash")
    appendLine(out, "        run: |")
    appendLine(out, "          set -eu")
    appendLine(out, "          curl -fL -o \"$HAP_PROOF_DIR/hapup.sh\" " + bridgeShellQuote(options.hapupUrl))
    if (options.hapupSha256.size > 0) {
        appendLine(out, "          printf '%s  %s\\n' " + bridgeShellQuote(options.hapupSha256) + " \"$HAP_PROOF_DIR/hapup.sh\" | sha256sum -c -")
    } else {
        appendLine(out, "          echo \"::warning::hapup checksum was explicitly marked unverified by review\"")
    }
    appendLine(out, "          chmod +x \"$HAP_PROOF_DIR/hapup.sh\"")
    appendLine(out, "          \"$HAP_PROOF_DIR/hapup.sh\" install-flagship --asset \"$HAP_FLAGSHIP_ASSET_URL\" --sha256 \"$HAP_FLAGSHIP_ASSET_SHA256\" --install-dir \"$HAP_INSTALL_DIR\" --receipt \"$HAP_PROOF_DIR/bootstrap.receipt.json\" --review-token \"$HAP_REVIEW_TOKEN\"")
    appendLine(out, "          echo \"$HAP_INSTALL_DIR\" >> \"$GITHUB_PATH\"")
    appendLine(out, "      - name: Generate reviewed project bridge and executor")
    appendLine(out, "        shell: bash")
    appendLine(out, "        run: |")
    appendLine(out, "          set -eu")
    appendLine(out, "          " + options.cliBin + " version")
    appendLine(out, "          " + options.cliBin + " ci project-bridge-recipe --project " + bridgeShellQuote(options.project) + " --receipt \"$HAP_PROOF_DIR/project-bridge.receipt.json\" --recipe-output \"$HAP_PROOF_DIR/project-bridge.sh\" --review-token \"$HAP_REVIEW_TOKEN\"" + runTestsSuffix(options.runTests))
    appendLine(out, "          " + options.cliBin + " ci executor-recipe --project-bridge-script \"$HAP_PROOF_DIR/project-bridge.sh\" --receipt \"$HAP_PROOF_DIR/executor.receipt.json\" --recipe-output \"$HAP_PROOF_DIR/executor.sh\" --review-token \"$HAP_REVIEW_TOKEN\"")
    appendLine(out, "          sh \"$HAP_PROOF_DIR/executor.sh\"")
    appendLine(out, "          test -s \"$HAP_PROOF_DIR/bootstrap.receipt.json\"")
    appendLine(out, "          test -s \"$HAP_PROOF_DIR/project-bridge.receipt.json\"")
    appendLine(out, "          test -s \"$HAP_PROOF_DIR/executor.receipt.json\"")
    appendLine(out, "      - name: Upload Hap proof receipts")
    appendLine(out, "        uses: actions/upload-artifact@v4")
    appendLine(out, "        with:")
    appendLine(out, "          name: hap-hosted-proof-receipts")
    appendLine(out, "          path: " + githubExpr("runner.temp") + "/hap-hosted-proof")
    trimTrailingNewlines(out.toString())
}

func githubExpr(value: String): String {
    "$" + "{{ " + value + " }}"
}

func runTestsSuffix(runTests: Bool): String {
    if (runTests) {
        return " --run-tests"
    }
    ""
}

func renderCiHostedProofReadme(options: HapCiHostedProofPackOptions, target: String): String {
    "# Hap Hosted Proof Pack\n\n" +
    "This pack is a reviewed hosted CI proof candidate. It does not mutate an existing workflow by itself.\n\n" +
    "Required hosted variables/secrets:\n\n" +
    "- secret `" + options.reviewTokenEnv + "`: review token consumed by reviewed HapCLI recipe commands.\n" +
    "- variable `" + options.assetUrlEnv + "`: URL or file-like hosted path for the flagship `hap` asset.\n" +
    "- variable `" + options.assetSha256Env + "`: sha256 for the flagship `hap` asset.\n\n" +
    "Target: `" + target + "`\n\n" +
    "Expected returned artifact: `hap-hosted-proof-receipts`, containing bootstrap, executor, and project bridge receipts.\n\n" +
    "Boundary: run this on a disposable branch or sandbox project first. Do not replace a green downstream workflow without owner approval and returned receipts.\n"
}

func renderCiHostedProofManifest(options: HapCiHostedProofPackOptions, target: String, platform: String, workflowPath: String, readmePath: String): String {
    "{\n" +
    "  \"schema\": \"happub-hapcli-ci-hosted-proof-pack-manifest-v0\",\n" +
    "  \"ok\": true,\n" +
    "  \"target\": \"" + escapeJson(target) + "\",\n" +
    "  \"platform\": \"" + escapeJson(platform) + "\",\n" +
    "  \"workflowPath\": \"" + escapeJson(workflowPath) + "\",\n" +
    "  \"readmePath\": \"" + escapeJson(readmePath) + "\",\n" +
    "  \"workflowMutationActionTaken\": false,\n" +
    "  \"hostedRunActionTaken\": false,\n" +
    "  \"installActionTaken\": false,\n" +
    "  \"nextExactMove\": \"copy the workflow into a disposable hosted branch, run it manually, and return the uploaded hap-hosted-proof-receipts artifact\"\n" +
    "}\n"
}
