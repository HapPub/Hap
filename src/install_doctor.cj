package hapcli

import std.collection.ArrayList
import std.fs.{File, exists}

public class HapInstallDoctorOptions {
    public var workflow: String = ""
    public var brewfile: String = ""
    public var formula: String = ""
    public var target: String = ""

    public init() {}
}

class HapOptionalTextInput {
    var found: Bool = false
    var readable: Bool = false
    var text: String = ""

    init() {}
}

public class HapInstallReplacePlanOptions {
    public var asset: String = ""
    public var sha256: String = ""
    public var installDir: String = ""
    public var receipt: String = ""
    public var reviewToken: String = ""
    public var allowSystemDir: Bool = false
    public var allowUnverified: Bool = false

    public init() {}
}

public class HapInstallRestorePlanOptions {
    public var installDir: String = ""
    public var backup: String = ""
    public var receipt: String = ""
    public var reviewToken: String = ""
    public var allowSystemDir: Bool = false

    public init() {}
}

public class HapInstallReceiptReadbackOptions {
    public var receipt: String = ""

    public init() {}
}

public func resolveInstallDoctorOptions(commandLine: Array<String>, start: Int64): HapInstallDoctorOptions {
    let options = HapInstallDoctorOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--workflow" && i + 1 < commandLine.size) {
            options.workflow = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--workflow=")) {
            options.workflow = substringFrom(current, 11)
            i += 1
            continue
        }
        if (current == "--brewfile" && i + 1 < commandLine.size) {
            options.brewfile = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--brewfile=")) {
            options.brewfile = substringFrom(current, 11)
            i += 1
            continue
        }
        if (current == "--formula" && i + 1 < commandLine.size) {
            options.formula = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--formula=")) {
            options.formula = substringFrom(current, 10)
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
        i += 1
    }
    options
}

public func resolveInstallReplacePlanOptions(commandLine: Array<String>, start: Int64): HapInstallReplacePlanOptions {
    let options = HapInstallReplacePlanOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--asset" && i + 1 < commandLine.size) {
            options.asset = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--asset=")) {
            options.asset = substringFrom(current, 8)
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
        if (current == "--allow-system-dir") {
            options.allowSystemDir = true
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

public func resolveInstallRestorePlanOptions(commandLine: Array<String>, start: Int64): HapInstallRestorePlanOptions {
    let options = HapInstallRestorePlanOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
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
        if (current == "--backup" && i + 1 < commandLine.size) {
            options.backup = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--backup=")) {
            options.backup = substringFrom(current, 9)
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
        if (current == "--allow-system-dir") {
            options.allowSystemDir = true
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func resolveInstallReceiptReadbackOptions(commandLine: Array<String>, start: Int64): HapInstallReceiptReadbackOptions {
    let options = HapInstallReceiptReadbackOptions()
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
        i += 1
    }
    options
}

public func renderInstallDoctorJson(options: HapInstallDoctorOptions): String {
    let workflowInput = inspectOptionalText(options.workflow)
    let brewfileInput = inspectOptionalText(options.brewfile)
    let formulaInput = inspectOptionalText(options.formula)
    let workflowText = workflowInput.text
    let brewfileText = brewfileInput.text
    let formulaText = formulaInput.text
    let findings = installDoctorFindings(
        options,
        workflowText,
        brewfileText,
        formulaText,
        workflowInput.readable,
        brewfileInput.readable,
        formulaInput.readable
    )
    let suggestions = installDoctorSuggestions(findings)
    let ok = findings.size == 0

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-install-doctor-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"read-only-install-bootstrap-diagnosis\",\n")
    out.append("  \"workflow\": \"" + escapeJson(options.workflow) + "\",\n")
    out.append("  \"brewfile\": \"" + escapeJson(options.brewfile) + "\",\n")
    out.append("  \"formula\": \"" + escapeJson(options.formula) + "\",\n")
    out.append("  \"target\": \"" + escapeJson(options.target) + "\",\n")
    out.append("  \"signals\": {\n")
    out.append("    \"hasWorkflow\": " + boolJson(options.workflow.size > 0) + ",\n")
    out.append("    \"hasBrewfile\": " + boolJson(options.brewfile.size > 0) + ",\n")
    out.append("    \"hasFormula\": " + boolJson(options.formula.size > 0) + ",\n")
    out.append("    \"workflowFound\": " + boolJson(options.workflow.size == 0 || workflowInput.found) + ",\n")
    out.append("    \"brewfileFound\": " + boolJson(options.brewfile.size == 0 || brewfileInput.found) + ",\n")
    out.append("    \"formulaFound\": " + boolJson(options.formula.size == 0 || formulaInput.found) + ",\n")
    out.append("    \"workflowReadable\": " + boolJson(options.workflow.size == 0 || workflowInput.readable) + ",\n")
    out.append("    \"brewfileReadable\": " + boolJson(options.brewfile.size == 0 || brewfileInput.readable) + ",\n")
    out.append("    \"formulaReadable\": " + boolJson(options.formula.size == 0 || formulaInput.readable) + ",\n")
    out.append("    \"mentionsTap\": " + boolJson(containsText(brewfileText + formulaText, "tap ")) + ",\n")
    out.append("    \"mentionsBrewInstall\": " + boolJson(containsText(workflowText + brewfileText, "brew install")) + ",\n")
    out.append("    \"mentionsHapup\": " + boolJson(containsText(workflowText + brewfileText + formulaText, "hapup")) + ",\n")
    out.append("    \"mentionsUnsafeCurlPipe\": " + boolJson(containsText(workflowText + brewfileText + formulaText, "curl") && containsText(workflowText + brewfileText + formulaText, "| sh")) + ",\n")
    out.append("    \"mentionsSha256\": " + boolJson(containsText(formulaText, "sha256")) + "\n")
    out.append("  },\n")
    out.append("  \"findingCount\": " + findings.size.toString() + ",\n")
    out.append("  \"findings\": [\n")
    appendJsonStringArray(out, findings)
    out.append("  ],\n")
    out.append("  \"repairSuggestions\": [\n")
    appendJsonStringArray(out, suggestions)
    out.append("  ],\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-install-doctor-findings\",\n")
    out.append("    \"choose-homebrew-tap-or-hapup-bootstrap\",\n")
    out.append("    \"generate-reviewed-bootstrap-snippet\",\n")
    out.append("    \"publish-install-config-only-after-release-artifact-exists\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"install doctor does not install hap\",\n")
    out.append("    \"install doctor does not write Brewfile or Formula files\",\n")
    out.append("    \"install doctor does not fetch network resources\",\n")
    out.append("    \"install doctor does not certify tap publication\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

public func renderInstallReplacePlanJson(options: HapInstallReplacePlanOptions): String {
    let requiredOk = options.asset.size > 0 && options.installDir.size > 0
    let verificationOk = options.sha256.size > 0 || options.allowUnverified
    let reviewOk = options.reviewToken.size > 0
    let unsafeDir = installReplaceUnsafeInstallDir(options.installDir)
    let assetLocal = installReplaceAssetIsLocal(options.asset)
    let assetFound = !assetLocal || installReplaceLocalAssetExists(options.asset)
    let safeDirOk = !unsafeDir || options.allowSystemDir
    let ok = requiredOk && verificationOk && reviewOk && safeDirOk && assetFound
    let status = installReplacePlanStatus(requiredOk, verificationOk, reviewOk, unsafeDir, options.allowSystemDir, assetFound)
    let installedBin = trimTrailingSlashInstall(options.installDir) + "/hap"
    let backupPath = trimTrailingSlashInstall(options.installDir) + "/hap.prev"
    let commandHint = installReplaceCommandHint(options)

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-install-replace-plan-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"read-only-install-replace-preflight\",\n")
    out.append("  \"asset\": \"" + escapeJson(options.asset) + "\",\n")
    out.append("  \"assetKind\": \"" + escapeJson(installReplaceAssetKind(options.asset)) + "\",\n")
    out.append("  \"localAssetFound\": " + boolJson(assetFound) + ",\n")
    out.append("  \"installDir\": \"" + escapeJson(options.installDir) + "\",\n")
    out.append("  \"installedBin\": \"" + escapeJson(installedBin) + "\",\n")
    out.append("  \"backupPath\": \"" + escapeJson(backupPath) + "\",\n")
    out.append("  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n")
    out.append("  \"sha256Present\": " + boolJson(options.sha256.size > 0) + ",\n")
    out.append("  \"allowUnverified\": " + boolJson(options.allowUnverified) + ",\n")
    out.append("  \"reviewTokenPresent\": " + boolJson(reviewOk) + ",\n")
    out.append("  \"unsafeInstallDir\": " + boolJson(unsafeDir) + ",\n")
    out.append("  \"allowSystemDir\": " + boolJson(options.allowSystemDir) + ",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"installActionTaken\": false,\n")
    out.append("  \"replaceActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"commandHint\": \"" + escapeJson(commandHint) + "\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review asset source and checksum\",\n")
    out.append("    \"run hapup install-flagship after review\",\n")
    out.append("    \"verify installed hap version and receipt\",\n")
    out.append("    \"restore backupPath manually if the replacement is rejected\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"replace plan does not install or replace hap\",\n")
    out.append("    \"replace plan does not download assets\",\n")
    out.append("    \"replace plan does not mutate shell rc files or PATH\",\n")
    out.append("    \"system install directories require explicit allow-system-dir review\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

public func renderInstallRestorePlanJson(options: HapInstallRestorePlanOptions): String {
    let requiredOk = options.installDir.size > 0
    let reviewOk = options.reviewToken.size > 0
    let unsafeDir = installReplaceUnsafeInstallDir(options.installDir)
    let safeDirOk = !unsafeDir || options.allowSystemDir
    let installedBin = trimTrailingSlashInstall(options.installDir) + "/hap"
    let backupPath = installRestoreBackupPath(options)
    let backupFound = backupPath.size > 0 && exists(backupPath)
    let installedBinPresent = requiredOk && exists(installedBin)
    let ok = requiredOk && reviewOk && safeDirOk && backupFound
    let status = installRestorePlanStatus(requiredOk, reviewOk, unsafeDir, options.allowSystemDir, backupFound)
    let commandHint = installRestoreCommandHint(options, backupPath)

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-install-restore-plan-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"read-only-install-restore-preflight\",\n")
    out.append("  \"installDir\": \"" + escapeJson(options.installDir) + "\",\n")
    out.append("  \"installedBin\": \"" + escapeJson(installedBin) + "\",\n")
    out.append("  \"installedBinPresent\": " + boolJson(installedBinPresent) + ",\n")
    out.append("  \"backupPath\": \"" + escapeJson(backupPath) + "\",\n")
    out.append("  \"backupFound\": " + boolJson(backupFound) + ",\n")
    out.append("  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n")
    out.append("  \"reviewTokenPresent\": " + boolJson(reviewOk) + ",\n")
    out.append("  \"unsafeInstallDir\": " + boolJson(unsafeDir) + ",\n")
    out.append("  \"allowSystemDir\": " + boolJson(options.allowSystemDir) + ",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"restoreActionTaken\": false,\n")
    out.append("  \"replaceActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"commandHint\": \"" + escapeJson(commandHint) + "\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review backup provenance and installed target\",\n")
    out.append("    \"run hapup restore-flagship after review\",\n")
    out.append("    \"verify restored hap version and receipt\",\n")
    out.append("    \"re-run install replace-plan before another replacement\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"restore plan does not restore or replace hap\",\n")
    out.append("    \"restore plan does not download assets\",\n")
    out.append("    \"restore plan does not mutate shell rc files or PATH\",\n")
    out.append("    \"system install directories require explicit allow-system-dir review\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

public func renderInstallReceiptReadbackJson(options: HapInstallReceiptReadbackOptions): String {
    let receiptFound = options.receipt.size > 0 && exists(options.receipt)
    let text = if (receiptFound) { readOptionalText(options.receipt) } else { "" }
    let schema = extractFlatJsonString(text, "schema")
    let receiptKind = installReceiptKind(schema)
    let supported = receiptKind == "install" || receiptKind == "restore"
    let receiptOk = installReceiptBool(text, "ok")
    let actionTaken = if (receiptKind == "restore") {
        installReceiptBool(text, "restoreActionTaken")
    } else {
        installReceiptBool(text, "installActionTaken")
    }
    let atomicReplace = installReceiptBool(text, "atomicReplace")
    let canonMutation = installReceiptBool(text, "canonMutation")
    let ok = receiptFound && supported && receiptOk && actionTaken && atomicReplace && !canonMutation
    let status = installReceiptReadbackStatus(options.receipt, receiptFound, supported, receiptOk, actionTaken, atomicReplace, canonMutation)

    let installDir = extractFlatJsonString(text, "installDir")
    let installedBin = extractFlatJsonString(text, "installedBin")
    let restoredBin = extractFlatJsonString(text, "restoredBin")
    let backupPath = extractFlatJsonString(text, "backupPath")
    let currentBackupPath = extractFlatJsonString(text, "currentBackupPath")
    let backupCreated = installReceiptBool(text, "backupCreated")
    let currentBackupCreated = installReceiptBool(text, "currentBackupCreated")

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-install-receipt-readback-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"read-only-install-receipt-readback\",\n")
    out.append("  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n")
    out.append("  \"receiptFound\": " + boolJson(receiptFound) + ",\n")
    out.append("  \"receiptSchema\": \"" + escapeJson(schema) + "\",\n")
    out.append("  \"receiptKind\": \"" + escapeJson(receiptKind) + "\",\n")
    out.append("  \"receiptOk\": " + boolJson(receiptOk) + ",\n")
    out.append("  \"installDir\": \"" + escapeJson(installDir) + "\",\n")
    out.append("  \"installedBin\": \"" + escapeJson(installedBin) + "\",\n")
    out.append("  \"restoredBin\": \"" + escapeJson(restoredBin) + "\",\n")
    out.append("  \"backupPath\": \"" + escapeJson(backupPath) + "\",\n")
    out.append("  \"backupCreated\": " + boolJson(backupCreated) + ",\n")
    out.append("  \"currentBackupPath\": \"" + escapeJson(currentBackupPath) + "\",\n")
    out.append("  \"currentBackupCreated\": " + boolJson(currentBackupCreated) + ",\n")
    out.append("  \"actionTaken\": " + boolJson(actionTaken) + ",\n")
    out.append("  \"atomicReplace\": " + boolJson(atomicReplace) + ",\n")
    out.append("  \"canonMutation\": " + boolJson(canonMutation) + ",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"installActionTaken\": false,\n")
    out.append("  \"restoreActionTaken\": false,\n")
    out.append("  \"nextAllowed\": [\n")
    appendJsonStringArray(out, installReceiptReadbackNextAllowed(receiptKind, ok, backupPath, installDir))
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"receipt readback does not install or restore hap\",\n")
    out.append("    \"receipt readback does not execute hapup\",\n")
    out.append("    \"receipt readback does not prove installed binary is currently on PATH\",\n")
    out.append("    \"receipt readback does not fetch network resources\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func inspectOptionalText(path: String): HapOptionalTextInput {
    let input = HapOptionalTextInput()
    if (path.size == 0) {
        input.found = true
        input.readable = true
        return input
    }
    input.found = exists(path)
    if (!input.found) {
        return input
    }
    try {
        input.text = String.fromUtf8(File.readFrom(path))
        input.readable = true
    } catch (_: Exception) {
        input.readable = false
    }
    input
}

func readOptionalText(path: String): String {
    inspectOptionalText(path).text
}

func installReceiptKind(schema: String): String {
    if (schema == "happub-hapup-install-receipt-v0") {
        return "install"
    }
    if (schema == "happub-hapup-restore-receipt-v0") {
        return "restore"
    }
    if (schema.size > 0) {
        return "unsupported"
    }
    "missing"
}

func installReceiptBool(text: String, key: String): Bool {
    containsText(text, "\"" + key + "\":true") || containsText(text, "\"" + key + "\": true")
}

func installReceiptReadbackStatus(
    receipt: String,
    receiptFound: Bool,
    supported: Bool,
    receiptOk: Bool,
    actionTaken: Bool,
    atomicReplace: Bool,
    canonMutation: Bool
): String {
    if (receipt.size == 0) {
        return "missing-receipt"
    }
    if (!receiptFound) {
        return "receipt-not-found"
    }
    if (!supported) {
        return "unsupported-receipt-schema"
    }
    if (!receiptOk) {
        return "receipt-not-ok"
    }
    if (!actionTaken) {
        return "receipt-action-not-taken"
    }
    if (!atomicReplace) {
        return "receipt-not-atomic-replace"
    }
    if (canonMutation) {
        return "receipt-reports-canon-mutation"
    }
    "trusted-install-receipt"
}

func installReceiptReadbackNextAllowed(receiptKind: String, ok: Bool, backupPath: String, installDir: String): ArrayList<String> {
    let items = ArrayList<String>()
    if (!ok) {
        items.add("inspect receipt source and rerun the matching hapup command only after review")
        items.add("rerun hap install replace-plan or restore-plan before taking action")
        return items
    }
    if (receiptKind == "install") {
        items.add("run installed hap version from the recorded installDir")
        if (backupPath.size > 0) {
            items.add("run hap install restore-plan --install-dir " + installShellQuote(installDir) + " --backup " + installShellQuote(backupPath))
        }
        items.add("archive receipt with release or CI artifact evidence")
        return items
    }
    if (receiptKind == "restore") {
        items.add("run restored hap version from the recorded installDir")
        items.add("rerun hap install replace-plan before another reviewed replacement")
        items.add("archive restore receipt with rollback evidence")
        return items
    }
    items.add("review receipt manually")
    items
}

func installDoctorFindings(
    options: HapInstallDoctorOptions,
    workflowText: String,
    brewfileText: String,
    formulaText: String,
    workflowReadable: Bool,
    brewfileReadable: Bool,
    formulaReadable: Bool
): ArrayList<String> {
    let findings = ArrayList<String>()
    let allText = workflowText + brewfileText + formulaText
    if (options.workflow.size == 0 && options.brewfile.size == 0 && options.formula.size == 0) {
        findings.add("missing-install-config")
    }
    if (options.workflow.size > 0 && !exists(options.workflow)) {
        findings.add("workflow-input-not-found")
    }
    if (options.brewfile.size > 0 && !exists(options.brewfile)) {
        findings.add("brewfile-input-not-found")
    }
    if (options.formula.size > 0 && !exists(options.formula)) {
        findings.add("formula-input-not-found")
    }
    if (options.workflow.size > 0 && exists(options.workflow) && !workflowReadable) {
        findings.add("workflow-input-unreadable")
    }
    if (options.brewfile.size > 0 && exists(options.brewfile) && !brewfileReadable) {
        findings.add("brewfile-input-unreadable")
    }
    if (options.formula.size > 0 && exists(options.formula) && !formulaReadable) {
        findings.add("formula-input-unreadable")
    }
    if (options.target.size == 0) {
        findings.add("missing-target-context")
    }
    if (!containsText(allText, "hap") && !containsText(allText, "hapup")) {
        findings.add("missing-hap-install-surface")
    }
    if (containsText(allText, "curl") && containsText(allText, "| sh") && !containsText(allText, "sha256")) {
        findings.add("unsafe-curl-pipe-without-checksum-context")
    }
    if (options.formula.size > 0 && !containsText(formulaText, "sha256")) {
        findings.add("formula-missing-sha256")
    }
    if (options.brewfile.size > 0 && !containsText(brewfileText, "tap ")) {
        findings.add("brewfile-missing-tap")
    }
    findings
}

func installDoctorSuggestions(findings: ArrayList<String>): ArrayList<String> {
    let suggestions = ArrayList<String>()
    if (stringListContains(findings, "missing-install-config")) {
        suggestions.add("provide --workflow, --brewfile, or --formula so HapCLI can inspect an install surface")
    }
    if (stringListContains(findings, "workflow-input-not-found")) {
        suggestions.add("provide an existing workflow path or omit --workflow")
    }
    if (stringListContains(findings, "brewfile-input-not-found")) {
        suggestions.add("provide an existing Brewfile path or omit --brewfile")
    }
    if (stringListContains(findings, "formula-input-not-found")) {
        suggestions.add("provide an existing Formula path or omit --formula")
    }
    if (stringListContains(findings, "workflow-input-unreadable")) {
        suggestions.add("provide a readable workflow file instead of a directory or inaccessible path")
    }
    if (stringListContains(findings, "brewfile-input-unreadable")) {
        suggestions.add("provide a readable Brewfile instead of a directory or inaccessible path")
    }
    if (stringListContains(findings, "formula-input-unreadable")) {
        suggestions.add("provide a readable Formula file instead of a directory or inaccessible path")
    }
    if (stringListContains(findings, "missing-target-context")) {
        suggestions.add("rerun install doctor with --target <target> for platform-specific bootstrap review")
    }
    if (stringListContains(findings, "missing-hap-install-surface")) {
        suggestions.add("add reviewed hapup bootstrap or Homebrew tap install surface after release artifact exists")
    }
    if (stringListContains(findings, "unsafe-curl-pipe-without-checksum-context")) {
        suggestions.add("avoid raw curl pipe unless checksum/version/source truth is reviewed and recorded")
    }
    if (stringListContains(findings, "formula-missing-sha256")) {
        suggestions.add("add sha256 to Homebrew Formula before treating tap install as trusted")
    }
    if (stringListContains(findings, "brewfile-missing-tap")) {
        suggestions.add("add tap declaration before brew install hap")
    }
    if (suggestions.size == 0) {
        suggestions.add("install bootstrap surface has basic tap/checksum/hap signals; continue with release artifact review")
    }
    suggestions
}

func installReplacePlanStatus(
    requiredOk: Bool,
    verificationOk: Bool,
    reviewOk: Bool,
    unsafeDir: Bool,
    allowSystemDir: Bool,
    assetFound: Bool
): String {
    if (!requiredOk) {
        return "missing-required-install-replace-field"
    }
    if (!verificationOk) {
        return "missing-checksum-or-unverified-review"
    }
    if (!reviewOk) {
        return "missing-review-token-for-install-replace"
    }
    if (unsafeDir && !allowSystemDir) {
        return "unsafe-install-dir-needs-explicit-allow"
    }
    if (!assetFound) {
        return "local-asset-not-found"
    }
    "ready-for-hapup-install-flagship-review"
}

func installRestorePlanStatus(
    requiredOk: Bool,
    reviewOk: Bool,
    unsafeDir: Bool,
    allowSystemDir: Bool,
    backupFound: Bool
): String {
    if (!requiredOk) {
        return "missing-required-install-restore-field"
    }
    if (!reviewOk) {
        return "missing-review-token-for-install-restore"
    }
    if (unsafeDir && !allowSystemDir) {
        return "unsafe-install-dir-needs-explicit-allow"
    }
    if (!backupFound) {
        return "backup-not-found"
    }
    "ready-for-hapup-restore-flagship-review"
}

func installReplaceCommandHint(options: HapInstallReplacePlanOptions): String {
    if (options.asset.size == 0 || options.installDir.size == 0) {
        return ""
    }
    let out = StringBuilder()
    out.append("hapup install-flagship --asset ")
    out.append(installShellQuote(options.asset))
    if (options.sha256.size > 0) {
        out.append(" --sha256 ")
        out.append(installShellQuote(options.sha256))
    } else {
        out.append(" --sha256 <reviewed-sha256>")
    }
    out.append(" --install-dir ")
    out.append(installShellQuote(options.installDir))
    if (options.receipt.size > 0) {
        out.append(" --receipt ")
        out.append(installShellQuote(options.receipt))
    }
    if (options.allowSystemDir) {
        out.append(" --allow-system-dir")
    }
    out.append(" --review-token <review-token>")
    out.toString()
}

func installRestoreCommandHint(options: HapInstallRestorePlanOptions, backupPath: String): String {
    if (options.installDir.size == 0) {
        return ""
    }
    let out = StringBuilder()
    out.append("hapup restore-flagship --install-dir ")
    out.append(installShellQuote(options.installDir))
    if (backupPath.size > 0) {
        out.append(" --backup ")
        out.append(installShellQuote(backupPath))
    }
    if (options.receipt.size > 0) {
        out.append(" --receipt ")
        out.append(installShellQuote(options.receipt))
    }
    if (options.allowSystemDir) {
        out.append(" --allow-system-dir")
    }
    out.append(" --review-token <review-token>")
    out.toString()
}

func installRestoreBackupPath(options: HapInstallRestorePlanOptions): String {
    if (options.backup.size > 0) {
        return options.backup
    }
    if (options.installDir.size == 0) {
        return ""
    }
    trimTrailingSlashInstall(options.installDir) + "/hap.prev"
}

func installReplaceUnsafeInstallDir(path: String): Bool {
    let trimmed = trimTrailingSlashInstall(path)
    trimmed == "/" ||
        trimmed == "/bin" ||
        trimmed == "/sbin" ||
        trimmed == "/usr/bin" ||
        trimmed == "/usr/sbin" ||
        trimmed == "/usr/local/bin" ||
        trimmed == "/opt/homebrew/bin" ||
        startsWithText(trimmed, "/System/")
}

func installReplaceAssetIsLocal(asset: String): Bool {
    asset.size > 0 && !startsWithText(asset, "http://") && !startsWithText(asset, "https://")
}

func installReplaceLocalAssetExists(asset: String): Bool {
    if (startsWithText(asset, "file://")) {
        return exists(substringFrom(asset, 7))
    }
    exists(asset)
}

func installReplaceAssetKind(asset: String): String {
    if (startsWithText(asset, "https://")) {
        return "https-url"
    }
    if (startsWithText(asset, "http://")) {
        return "http-url"
    }
    if (startsWithText(asset, "file://")) {
        return "file-url"
    }
    if (asset.size > 0) {
        return "local-path"
    }
    "missing"
}

func trimTrailingSlashInstall(path: String): String {
    var out = path
    while (out.size > 1 && endsWithText(out, "/")) {
        out = substringTo(out, Int64(out.size - 1))
    }
    out
}

func installShellQuote(value: String): String {
    "'" + value.replace("'", "'\"'\"'") + "'"
}
