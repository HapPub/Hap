package hapcli

import std.collection.ArrayList

public class HapCjpmPipelinePlanOptions {
    public var project: String = ""
    public var manifest: String = ""
    public var workflow: String = ""
    public var target: String = ""
    public var receipt: String = ""
    public var runTests: Bool = false

    public init() {}
}

public func resolveCjpmPipelinePlanOptions(commandLine: Array<String>, start: Int64): HapCjpmPipelinePlanOptions {
    let options = HapCjpmPipelinePlanOptions()
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
        if (current == "--manifest" && i + 1 < commandLine.size) {
            options.manifest = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--manifest=")) {
            options.manifest = substringFrom(current, 11)
            i += 1
            continue
        }
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
        if (current == "--run-tests") {
            options.runTests = true
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func renderCjpmPipelinePlanJson(options: HapCjpmPipelinePlanOptions): String {
    let missing = missingPipelineFields(options)
    let ok = missing.size == 0
    let steps = pipelinePlanSteps(options)

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cjpm-pipeline-plan-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"read-only-deep-cjpm-pipeline-plan\",\n")
    out.append("  \"project\": \"" + escapeJson(options.project) + "\",\n")
    out.append("  \"manifest\": \"" + escapeJson(options.manifest) + "\",\n")
    out.append("  \"workflow\": \"" + escapeJson(options.workflow) + "\",\n")
    out.append("  \"target\": \"" + escapeJson(options.target) + "\",\n")
    out.append("  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n")
    out.append("  \"runTests\": " + boolJson(options.runTests) + ",\n")
    out.append("  \"missingFields\": [\n")
    appendJsonStringArray(out, missing)
    out.append("  ],\n")
    out.append("  \"stepCount\": " + steps.size.toString() + ",\n")
    out.append("  \"steps\": [\n")
    appendJsonStringArray(out, steps)
    out.append("  ],\n")
    out.append("  \"executionActionTaken\": false,\n")
    out.append("  \"mutationActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-pipeline-plan\",\n")
    out.append("    \"run-action-doctor-if-workflow-provided\",\n")
    out.append("    \"generate-reviewed-fetch-recipe-if-toolchain-missing\",\n")
    out.append("    \"generate-project-bridge-recipe-after-review\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"pipeline plan does not execute cjpm\",\n")
    out.append("    \"pipeline plan does not mutate cjpm.toml\",\n")
    out.append("    \"pipeline plan does not download dependencies or toolchains\",\n")
    out.append("    \"pipeline plan is not hosted CI adoption proof\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func missingPipelineFields(options: HapCjpmPipelinePlanOptions): ArrayList<String> {
    let missing = ArrayList<String>()
    if (options.project.size == 0) {
        missing.add("project")
    }
    if (options.manifest.size == 0) {
        missing.add("manifest")
    }
    if (options.target.size == 0) {
        missing.add("target")
    }
    if (options.receipt.size == 0) {
        missing.add("receipt")
    }
    missing
}

func pipelinePlanSteps(options: HapCjpmPipelinePlanOptions): ArrayList<String> {
    let steps = ArrayList<String>()
    if (options.workflow.size > 0) {
        steps.add("ci-action-doctor --workflow " + options.workflow)
    }
    steps.add("inspect-cjpm " + options.manifest)
    steps.add("cjpm graph doctor --manifest " + options.manifest)
    steps.add("doctor stdx --project " + options.project + " --target " + options.target)
    steps.add("doctor runtime --project " + options.project + " --target " + options.target)
    steps.add("fetch reviewed-recipe if stdx/runtime doctor reports missing")
    steps.add("review optional profile switch or graph normalize plan")
    steps.add("ci project-bridge-recipe --project " + options.project + " --receipt " + options.receipt)
    if (options.runTests) {
        steps.add("execute reviewed project bridge script with cjpm build and cjpm test outside HapCLI")
    } else {
        steps.add("execute reviewed project bridge script with cjpm build outside HapCLI")
    }
    steps.add("inspect project bridge receipt before CI adoption")
    steps
}
