package hapcli

import std.fs.File

public class HapReviewedFetchOptions {
    public var subject: String = ""
    public var target: String = "linux-amd64"
    public var version: String = ""
    public var providerUrl: String = ""
    public var installRoot: String = ""
    public var sha256: String = ""
    public var allowUnverified: Bool = false
    public var receipt: String = ""
    public var executor: String = "hapup"
    public var recipeOutput: String = ""
    public var reviewToken: String = ""
    public var requestExecute: Bool = false

    public init() {}
}

public func resolveReviewedFetchOptions(commandLine: Array<String>, start: Int64): HapReviewedFetchOptions {
    let options = HapReviewedFetchOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
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
        if (current == "--version" && i + 1 < commandLine.size) {
            options.version = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--version=")) {
            options.version = substringFrom(current, 10)
            i += 1
            continue
        }
        if (current == "--provider-url" && i + 1 < commandLine.size) {
            options.providerUrl = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--provider-url=")) {
            options.providerUrl = substringFrom(current, 15)
            i += 1
            continue
        }
        if (current == "--install-root" && i + 1 < commandLine.size) {
            options.installRoot = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--install-root=")) {
            options.installRoot = substringFrom(current, 15)
            i += 1
            continue
        }
        if (current == "--sha256" && i + 1 < commandLine.size) {
            options.sha256 = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--sha256=")) {
            options.sha256 = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--allow-unverified") {
            options.allowUnverified = true
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
        if (current == "--executor" && i + 1 < commandLine.size) {
            options.executor = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--executor=")) {
            options.executor = substringFrom(current, 11)
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
        if (current == "--execute" || current == "--run") {
            options.requestExecute = true
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func renderReviewedFetchRecipeJson(options: HapReviewedFetchOptions): String {
    let normalizedSubject = normalizeFetchSubject(options.subject)
    let platform = cangjieDownloadPlatformForTarget(options.target)
    let filename = reviewedFetchFilename(normalizedSubject, platform, options.version)
    let downloadUrl = buildProviderDownloadUrl(options.providerUrl, filename)
    let hasChecksum = options.sha256.size > 0
    let requiredOk = normalizedSubject.size > 0 && platform.size > 0 && options.version.size > 0 && options.providerUrl.size > 0 && options.installRoot.size > 0 && options.receipt.size > 0
    let verificationOk = hasChecksum || options.allowUnverified
    let reviewOk = options.reviewToken.size > 0
    let ok = requiredOk && verificationOk && reviewOk && !options.requestExecute
    let status = reviewedFetchStatus(requiredOk, verificationOk, reviewOk, options.requestExecute)
    let recipe = if (options.requestExecute) {
        ""
    } else {
        renderReviewedFetchBashRecipe(options, normalizedSubject, filename, downloadUrl)
    }
    var recipeFileWritten = false
    if (ok && options.recipeOutput.size > 0 && recipe.size > 0) {
        File.writeTo(options.recipeOutput, (recipe + "\n").toArray())
        recipeFileWritten = true
    }

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-reviewed-fetch-recipe-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"reviewed-bash-recipe-only\",\n")
    out.append("  \"subject\": \"" + escapeJson(normalizedSubject) + "\",\n")
    out.append("  \"target\": \"" + escapeJson(options.target) + "\",\n")
    out.append("  \"downloadPlatform\": \"" + escapeJson(platform) + "\",\n")
    out.append("  \"version\": \"" + escapeJson(options.version) + "\",\n")
    out.append("  \"providerUrl\": \"" + escapeJson(options.providerUrl) + "\",\n")
    out.append("  \"downloadFilename\": \"" + escapeJson(filename) + "\",\n")
    out.append("  \"downloadUrl\": \"" + escapeJson(downloadUrl) + "\",\n")
    out.append("  \"installRoot\": \"" + escapeJson(options.installRoot) + "\",\n")
    out.append("  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n")
    out.append("  \"executor\": \"" + escapeJson(options.executor) + "\",\n")
    out.append("  \"recipeOutput\": \"" + escapeJson(options.recipeOutput) + "\",\n")
    out.append("  \"recipeFileWritten\": " + boolJson(recipeFileWritten) + ",\n")
    out.append("  \"sha256\": \"" + escapeJson(options.sha256) + "\",\n")
    out.append("  \"allowUnverified\": " + boolJson(options.allowUnverified) + ",\n")
    out.append("  \"reviewTokenPresent\": " + boolJson(reviewOk) + ",\n")
    out.append("  \"directExecuteRequested\": " + boolJson(options.requestExecute) + ",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"installActionTaken\": false,\n")
    out.append("  \"directExecuteActionTaken\": false,\n")
    out.append("  \"recipe\": \"" + escapeJson(recipe) + "\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-generated-bash-recipe\",\n")
    out.append("    \"execute-recipe-output-after-review\",\n")
    out.append("    \"execute-with-hapup-or-ci-after-human-review\",\n")
    out.append("    \"record-fetch-receipt-before-cjpm-build\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"reviewed fetch recipe does not execute network actions\",\n")
    out.append("    \"direct execution belongs to reviewed CI or hapup after human review, not this HapCLI surface\",\n")
    out.append("    \"reviewed fetch recipe does not mutate global SDK paths by default\",\n")
    out.append("    \"receipt records the shell bridge action but does not certify project build success\",\n")
    out.append("    \"unverified downloads require explicit allow-unverified approval\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func normalizeFetchSubject(subject: String): String {
    match (subject) {
        case "cangjie-stdx" => "cangjie-stdx"
        case "stdx" => "cangjie-stdx"
        case "cangjie-runtime" => "cangjie-runtime"
        case "runtime" => "cangjie-runtime"
        case _ => ""
    }
}

func reviewedFetchFilename(subject: String, platform: String, version: String): String {
    if (subject.size == 0 || platform.size == 0 || version.size == 0) {
        return ""
    }
    subject + "-" + platform + "-" + version + reviewedFetchExtension(subject)
}

func reviewedFetchExtension(subject: String): String {
    match (subject) {
        case "cangjie-stdx" => ".zip"
        case "cangjie-runtime" => ".tar.gz"
        case _ => ""
    }
}

func reviewedFetchStatus(requiredOk: Bool, verificationOk: Bool, reviewOk: Bool, requestExecute: Bool): String {
    if (requestExecute) {
        return "direct-execute-not-supported"
    }
    if (!requiredOk) {
        return "missing-required-field"
    }
    if (!verificationOk) {
        return "missing-checksum-or-unverified-approval"
    }
    if (!reviewOk) {
        return "missing-review-token-for-recipe"
    }
    "ready-for-reviewed-shell-execution"
}

func renderReviewedFetchBashRecipe(
    options: HapReviewedFetchOptions,
    subject: String,
    filename: String,
    downloadUrl: String
): String {
    if (subject.size == 0 || filename.size == 0 || downloadUrl.size == 0) {
        return ""
    }
    let out = StringBuilder()
    appendLine(out, "set -eu")
    appendLine(out, "HAP_FETCH_WORK=\"" + "$" + "{TMPDIR:-/tmp}/hap-reviewed-fetch-" + subject + "\"")
    appendLine(out, "HAP_FETCH_ARCHIVE=\"$HAP_FETCH_WORK/" + filename + "\"")
    appendLine(out, "mkdir -p \"$HAP_FETCH_WORK\" " + shellQuote(options.installRoot))
    appendLine(out, "if command -v curl >/dev/null 2>&1; then")
    appendLine(out, "  curl -fsSL " + shellQuote(downloadUrl) + " -o \"$HAP_FETCH_ARCHIVE\"")
    appendLine(out, "elif command -v wget >/dev/null 2>&1; then")
    appendLine(out, "  wget -q " + shellQuote(downloadUrl) + " -O \"$HAP_FETCH_ARCHIVE\"")
    appendLine(out, "else")
    appendLine(out, "  echo \"curl or wget is required for reviewed fetch\"")
    appendLine(out, "  exit 127")
    appendLine(out, "fi")
    if (options.sha256.size > 0) {
        appendLine(out, "printf '%s  %s\\n' " + shellQuote(options.sha256) + " \"$HAP_FETCH_ARCHIVE\" | sha256sum -c -")
    } else {
        appendLine(out, "echo \"WARNING: reviewed fetch is running without sha256 because allow-unverified was set\"")
    }
    appendLine(out, "case \"" + filename + "\" in")
    appendLine(out, "  *.zip) unzip -q \"$HAP_FETCH_ARCHIVE\" -d " + shellQuote(options.installRoot) + " ;;")
    appendLine(out, "  *.tar.gz) tar -xzf \"$HAP_FETCH_ARCHIVE\" -C " + shellQuote(options.installRoot) + " ;;")
    appendLine(out, "  *) echo \"unsupported archive extension\"; exit 64 ;;")
    appendLine(out, "esac")
    appendLine(out, "mkdir -p \"$(dirname " + shellQuote(options.receipt) + ")\"")
    appendLine(out, "printf '{\"schema\":\"happub-hapcli-reviewed-fetch-receipt-v0\",\"ok\":true,\"subject\":\"" + subject + "\",\"target\":\"" + options.target + "\",\"version\":\"" + options.version + "\",\"downloadUrl\":\"" + escapeJson(downloadUrl) + "\",\"archive\":\"%s\",\"installRoot\":\"" + escapeJson(options.installRoot) + "\",\"checksumStatus\":\"" + reviewedChecksumStatus(options) + "\",\"downloadActionTaken\":true,\"networkActionTaken\":" + boolJson(reviewedFetchUsesNetwork(downloadUrl)) + ",\"deployActionTaken\":true,\"canonMutation\":false}\\n' \"$HAP_FETCH_ARCHIVE\" > " + shellQuote(options.receipt))
    trimTrailingNewlines(out.toString())
}

func reviewedChecksumStatus(options: HapReviewedFetchOptions): String {
    if (options.sha256.size > 0) {
        return "verified"
    }
    if (options.allowUnverified) {
        return "allowed-unverified"
    }
    "not-provided"
}

func reviewedFetchUsesNetwork(downloadUrl: String): Bool {
    !startsWithText(downloadUrl, "file://")
}

func shellQuote(value: String): String {
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
