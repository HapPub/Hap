package hapcli

import std.collection.ArrayList
import std.fs.File

public class HapCiActionDoctorOptions {
    public var workflow: String = ""
    public var project: String = ""
    public var target: String = ""

    public init() {}
}

public func resolveCiActionDoctorOptions(commandLine: Array<String>, start: Int64): HapCiActionDoctorOptions {
    let options = HapCiActionDoctorOptions()
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
        i += 1
    }
    options
}

public func renderCiActionDoctorJson(options: HapCiActionDoctorOptions): String {
    if (options.workflow.size == 0) {
        return renderInspectCjpmErrorJson("missing-workflow", "usage: hap ci action-doctor --workflow <path> [--project <path>] [--target <target>]")
    }

    let workflowText = String.fromUtf8(File.readFrom(options.workflow))
    let findings = actionDoctorFindings(workflowText, options)
    let suggestions = actionDoctorSuggestions(workflowText, options, findings)
    let ok = findings.size == 0

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-ci-action-doctor-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"read-only-workflow-diagnosis\",\n")
    out.append("  \"workflow\": \"" + escapeJson(options.workflow) + "\",\n")
    out.append("  \"project\": \"" + escapeJson(options.project) + "\",\n")
    out.append("  \"target\": \"" + escapeJson(options.target) + "\",\n")
    out.append("  \"signals\": {\n")
    out.append("    \"hasHap\": " + boolJson(containsText(workflowText, "hap ")) + ",\n")
    out.append("    \"hasHapup\": " + boolJson(containsText(workflowText, "hapup")) + ",\n")
    out.append("    \"hasDevHapcli\": " + boolJson(containsText(workflowText, "hapcli")) + ",\n")
    out.append("    \"hasCjpmBuild\": " + boolJson(containsText(workflowText, "cjpm build")) + ",\n")
    out.append("    \"hasCjpmTest\": " + boolJson(containsText(workflowText, "cjpm test")) + ",\n")
    out.append("    \"hasStdxDoctor\": " + boolJson(containsText(workflowText, "doctor stdx")) + ",\n")
    out.append("    \"hasReviewedFetchRecipe\": " + boolJson(containsText(workflowText, "fetch reviewed-recipe")) + ",\n")
    out.append("    \"hasProjectBridgeRecipe\": " + boolJson(containsText(workflowText, "project-bridge-recipe")) + ",\n")
    out.append("    \"hasReceiptArtifact\": " + boolJson(containsText(workflowText, "receipt") && containsText(workflowText, "upload-artifact")) + "\n")
    out.append("  },\n")
    out.append("  \"findingCount\": " + findings.size.toString() + ",\n")
    out.append("  \"findings\": [\n")
    appendJsonStringArray(out, findings)
    out.append("  ],\n")
    out.append("  \"repairSuggestions\": [\n")
    appendJsonStringArray(out, suggestions)
    out.append("  ],\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-action-doctor-findings\",\n")
    out.append("    \"generate-cjpm-pipeline-plan\",\n")
    out.append("    \"generate-reviewed-project-bridge-recipe\",\n")
    out.append("    \"patch-workflow-only-after-owner-review\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"action doctor does not mutate workflow files\",\n")
    out.append("    \"action doctor does not install hap or hapup\",\n")
    out.append("    \"action doctor does not run GitHub Actions\",\n")
    out.append("    \"action doctor does not certify hosted CI success\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func actionDoctorFindings(workflowText: String, options: HapCiActionDoctorOptions): ArrayList<String> {
    let findings = ArrayList<String>()
    if (containsText(workflowText, "hapcli")) {
        findings.add("dev-command-hapcli-present-in-workflow")
    }
    if (!containsText(workflowText, "hap ") && !containsText(workflowText, "hapup")) {
        findings.add("missing-hap-or-hapup-bootstrap")
    }
    if (!containsText(workflowText, "cjpm build")) {
        findings.add("missing-cjpm-build-step")
    }
    if (!containsText(workflowText, "doctor stdx")) {
        findings.add("missing-stdx-doctor-preflight")
    }
    if (!containsText(workflowText, "project-bridge-recipe")) {
        findings.add("missing-hap-project-bridge-recipe")
    }
    if (!containsText(workflowText, "upload-artifact") || !containsText(workflowText, "receipt")) {
        findings.add("missing-receipt-artifact-upload")
    }
    if (options.target.size == 0) {
        findings.add("missing-target-context")
    }
    findings
}

func actionDoctorSuggestions(workflowText: String, options: HapCiActionDoctorOptions, findings: ArrayList<String>): ArrayList<String> {
    let suggestions = ArrayList<String>()
    if (stringListContains(findings, "dev-command-hapcli-present-in-workflow")) {
        suggestions.add("replace public CI command name hapcli with hap unless this is repo-local development")
    }
    if (stringListContains(findings, "missing-hap-or-hapup-bootstrap")) {
        suggestions.add("add hap ci bootstrap-snippet output or reviewed hapup bootstrap step before HapCLI commands")
    }
    if (stringListContains(findings, "missing-stdx-doctor-preflight")) {
        suggestions.add("add hap doctor stdx --project <project> --target <target> before cjpm build")
    }
    if (stringListContains(findings, "missing-hap-project-bridge-recipe")) {
        suggestions.add("generate hap ci project-bridge-recipe and execute the reviewed script in CI after owner review")
    }
    if (stringListContains(findings, "missing-receipt-artifact-upload")) {
        suggestions.add("upload HapCLI bridge receipt as CI artifact before treating preflight as adopted")
    }
    if (stringListContains(findings, "missing-target-context")) {
        suggestions.add("rerun action-doctor with --target <target> so alias normalization can be checked")
    }
    if (suggestions.size == 0) {
        suggestions.add("workflow has basic HapCLI/cjpm preflight signals; continue with cjpm pipeline plan")
    }
    suggestions
}
