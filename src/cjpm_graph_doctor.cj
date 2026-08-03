package hapcli

import std.collection.ArrayList
import std.fs.{Directory, File, exists}

public class HapGraphManifest {
    public let path: String
    public let packageName: String
    public let dependencies: ArrayList<HapDependencyRef>

    public init(path: String, packageName: String, dependencies: ArrayList<HapDependencyRef>) {
        this.path = path
        this.packageName = packageName
        this.dependencies = dependencies
    }
}

public class HapGraphLocalMap {
    public let name: String
    public let path: String

    public init(name: String, path: String) {
        this.name = name
        this.path = path
    }
}

class HapGraphNormalizeChange {
    let manifest: String
    let dependency: String
    let fromKind: String
    let fromValue: String
    let toKind: String
    let toValue: String

    init(manifest: String, dependency: String, fromKind: String, fromValue: String, toKind: String, toValue: String) {
        this.manifest = manifest
        this.dependency = dependency
        this.fromKind = fromKind
        this.fromValue = fromValue
        this.toKind = toKind
        this.toValue = toValue
    }
}

public class HapGraphApplyOutput {
    public let input: String
    public let output: String
    public let size: Int64

    public init(input: String, output: String, size: Int64) {
        this.input = input
        this.output = output
        this.size = size
    }
}

public class HapGraphOptions {
    public let manifests: ArrayList<String> = ArrayList<String>()
    public let roots: ArrayList<String> = ArrayList<String>()
    public let localMaps: ArrayList<HapGraphLocalMap> = ArrayList<HapGraphLocalMap>()
    public var profile: String = "local-bundle"
    public var outputDir: String = ""
    public var receipt: String = ""
    public var reviewToken: String = ""
    public var workflowOutput: String = ""
    public var manifestListOutput: String = ""
    public var manifestListInput: String = ""
    public var packageFilter: String = ""
    public var pathContains: String = ""
    public var cliBin: String = "hap"
    public var maxDepth: Int64 = 3
    public var includeHidden: Bool = false
    public var allowWorktreeOutput: Bool = false

    public init() {}
}

public func resolveGraphOptions(commandLine: Array<String>, start: Int64): HapGraphOptions {
    let options = HapGraphOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--manifest" && i + 1 < commandLine.size) {
            options.manifests.add(commandLine[i + 1])
            i += 2
            continue
        }
        if (startsWithText(current, "--manifest=")) {
            options.manifests.add(substringFrom(current, 11))
            i += 1
            continue
        }
        if (current == "--root" && i + 1 < commandLine.size) {
            options.roots.add(commandLine[i + 1])
            i += 2
            continue
        }
        if (startsWithText(current, "--root=")) {
            options.roots.add(substringFrom(current, 7))
            i += 1
            continue
        }
        if (current == "--max-depth" && i + 1 < commandLine.size) {
            options.maxDepth = parseGraphMaxDepth(commandLine[i + 1])
            i += 2
            continue
        }
        if (startsWithText(current, "--max-depth=")) {
            options.maxDepth = parseGraphMaxDepth(substringFrom(current, 12))
            i += 1
            continue
        }
        if (current == "--include-hidden") {
            options.includeHidden = true
            i += 1
            continue
        }
        if (current == "--allow-worktree-output") {
            options.allowWorktreeOutput = true
            i += 1
            continue
        }
        if (current == "--local-map" && i + 1 < commandLine.size) {
            addLocalMap(options, commandLine[i + 1])
            i += 2
            continue
        }
        if (startsWithText(current, "--local-map=")) {
            addLocalMap(options, substringFrom(current, 12))
            i += 1
            continue
        }
        if (current == "--profile" && i + 1 < commandLine.size) {
            options.profile = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--profile=")) {
            options.profile = substringFrom(current, 10)
            i += 1
            continue
        }
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
        if (current == "--workflow-output" && i + 1 < commandLine.size) {
            options.workflowOutput = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--workflow-output=")) {
            options.workflowOutput = substringFrom(current, 18)
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
        if (current == "--manifest-list-output" && i + 1 < commandLine.size) {
            options.manifestListOutput = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--manifest-list-output=")) {
            options.manifestListOutput = substringFrom(current, 23)
            i += 1
            continue
        }
        if ((current == "--manifest-list" || current == "--manifest-list-input") && i + 1 < commandLine.size) {
            options.manifestListInput = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--manifest-list=")) {
            options.manifestListInput = substringFrom(current, 16)
            i += 1
            continue
        }
        if (startsWithText(current, "--manifest-list-input=")) {
            options.manifestListInput = substringFrom(current, 22)
            i += 1
            continue
        }
        if (current == "--package" && i + 1 < commandLine.size) {
            options.packageFilter = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--package=")) {
            options.packageFilter = substringFrom(current, 10)
            i += 1
            continue
        }
        if (current == "--path-contains" && i + 1 < commandLine.size) {
            options.pathContains = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--path-contains=")) {
            options.pathContains = substringFrom(current, 16)
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func renderCjpmGraphDoctorJson(options: HapGraphOptions): String {
    let manifests = readGraphManifests(options.manifests)
    let conflicts = graphConflictNames(manifests)
    let ok = options.manifests.size > 0 && conflicts.size == 0

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cjpm-graph-doctor-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"diagnose-only\",\n")
    out.append("  \"manifestCount\": " + manifests.size.toString() + ",\n")
    out.append("  \"dependencyConflictCount\": " + conflicts.size.toString() + ",\n")
    out.append("  \"manifests\": [\n")
    appendGraphManifestArray(out, manifests)
    out.append("  ],\n")
    out.append("  \"conflicts\": [\n")
    appendGraphConflicts(out, manifests, conflicts)
    out.append("  ],\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"cjpm-graph-normalize-plan\",\n")
    out.append("    \"manual-manifest-review\",\n")
    out.append("    \"review-gated-apply\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"graph doctor does not mutate manifests\",\n")
    out.append("    \"graph doctor does not run cjpm build\",\n")
    out.append("    \"graph doctor does not fetch dependencies\",\n")
    out.append("    \"graph doctor only inspects the explicitly provided manifests\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

public func renderCjpmGraphNormalizePlanJson(options: HapGraphOptions): String {
    let manifests = readGraphManifests(options.manifests)
    let changes = graphNormalizeChanges(manifests, options.localMaps)
    let conflicts = graphConflictNames(manifests)
    let ok = options.manifests.size > 0 && options.localMaps.size > 0

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cjpm-graph-normalize-plan-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"read-only-plan\",\n")
    out.append("  \"profile\": \"" + escapeJson(options.profile) + "\",\n")
    out.append("  \"manifestCount\": " + manifests.size.toString() + ",\n")
    out.append("  \"localMapCount\": " + options.localMaps.size.toString() + ",\n")
    out.append("  \"plannedChangeCount\": " + changes.size.toString() + ",\n")
    out.append("  \"preExistingConflictCount\": " + conflicts.size.toString() + ",\n")
    out.append("  \"localMaps\": [\n")
    appendLocalMaps(out, options.localMaps)
    out.append("  ],\n")
    out.append("  \"changes\": [\n")
    appendNormalizeChanges(out, changes)
    out.append("  ],\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-normalize-plan\",\n")
    out.append("    \"apply-normalize-after-review\",\n")
    out.append("    \"rerun-cjpm-graph-doctor\",\n")
    out.append("    \"rerun-cjpm-build\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"normalize plan does not mutate manifests\",\n")
    out.append("    \"normalize plan does not run cjpm update or cjpm build\",\n")
    out.append("    \"normalize plan does not fetch git dependencies\",\n")
    out.append("    \"local-bundle means dependency graph import type convergence, not release certification\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

public func renderCjpmGraphCiPreflightRecipeJson(options: HapGraphOptions): String {
    let manifests = readGraphManifests(options.manifests)
    let conflicts = graphConflictNames(manifests)
    let changes = graphNormalizeChanges(manifests, options.localMaps)
    let hasApplySurface = options.localMaps.size > 0 && options.outputDir.size > 0 && options.receipt.size > 0
    let ok = options.manifests.size > 0

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cjpm-graph-ci-preflight-recipe-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"read-only-ci-recipe\",\n")
    out.append("  \"profile\": \"" + escapeJson(options.profile) + "\",\n")
    out.append("  \"cliBin\": \"" + escapeJson(options.cliBin) + "\",\n")
    out.append("  \"manifestCount\": " + manifests.size.toString() + ",\n")
    out.append("  \"localMapCount\": " + options.localMaps.size.toString() + ",\n")
    out.append("  \"preExistingConflictCount\": " + conflicts.size.toString() + ",\n")
    out.append("  \"plannedChangeCount\": " + changes.size.toString() + ",\n")
    out.append("  \"hasReviewedApplySurface\": " + boolJson(hasApplySurface) + ",\n")
    out.append("  \"commands\": [\n")
    appendCiRecipeCommands(out, options, hasApplySurface)
    out.append("  ],\n")
    out.append("  \"githubActionsStep\": \"" + escapeJson(renderGithubActionsStep(options, hasApplySurface)) + "\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"copy-recipe-into-ci-after-human-review\",\n")
    out.append("    \"run-cjpm-graph-doctor-before-cjpm-build\",\n")
    out.append("    \"optionally-run-apply-normalize-to-reviewed-output-dir\",\n")
    out.append("    \"run-cjpm-build-after-manifest-review\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"ci preflight recipe does not execute commands\",\n")
    out.append("    \"ci preflight recipe does not mutate manifests\",\n")
    out.append("    \"ci preflight recipe does not fetch dependencies\",\n")
    out.append("    \"ci preflight recipe does not certify build or release success\",\n")
    out.append("    \"reviewed apply output must be copied into a workspace by the caller if desired\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

public func renderCjpmGraphDiscoverManifestsJson(options: HapGraphOptions): String {
    let manifests = ArrayList<String>()
    let skipped = ArrayList<String>()
    collectGraphManifestCandidates(options, manifests, skipped)
    let ok = options.roots.size > 0

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cjpm-graph-discover-manifests-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"read-only-discovery\",\n")
    out.append("  \"rootCount\": " + options.roots.size.toString() + ",\n")
    out.append("  \"maxDepth\": " + options.maxDepth.toString() + ",\n")
    out.append("  \"includeHidden\": " + boolJson(options.includeHidden) + ",\n")
    out.append("  \"manifestCount\": " + manifests.size.toString() + ",\n")
    out.append("  \"roots\": [\n")
    appendJsonStringArray(out, options.roots)
    out.append("  ],\n")
    out.append("  \"manifests\": [\n")
    appendJsonStringArray(out, manifests)
    out.append("  ],\n")
    out.append("  \"skippedDirectories\": [\n")
    appendJsonStringArray(out, skipped)
    out.append("  ],\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-discovered-manifest-list\",\n")
    out.append("    \"rerun-cjpm-graph-doctor-with-explicit-manifests\",\n")
    out.append("    \"rerun-ci-preflight-recipe-with-explicit-manifests\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"discover manifests does not mutate files\",\n")
    out.append("    \"discover manifests does not run cjpm build\",\n")
    out.append("    \"discover manifests does not feed results into apply automatically\",\n")
    out.append("    \"hidden directories, target, .git, and node_modules are skipped unless explicitly allowed where applicable\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

public func runCjpmGraphManifestListExport(commandLine: Array<String>, start: Int64): String {
    let options = resolveGraphOptions(commandLine, start)
    let manifests = ArrayList<String>()
    let skipped = ArrayList<String>()
    collectGraphManifestCandidates(options, manifests, skipped)
    let artifact = renderCjpmGraphManifestListArtifactJson(options, manifests, skipped)
    if (options.manifestListOutput.size > 0 && options.reviewToken.size == 0) {
        return renderCjpmGraphManifestListExportRejectedJson(options, manifests, skipped, artifact)
    }
    var written = false
    if (options.manifestListOutput.size > 0) {
        File.writeTo(options.manifestListOutput, (artifact + "\n").toArray())
        written = true
    }
    renderCjpmGraphManifestListExportJson(options, manifests, skipped, artifact, written)
}

public func renderCjpmGraphManifestListReadbackJson(options: HapGraphOptions): String {
    let artifactExists = options.manifestListInput.size > 0 && exists(options.manifestListInput)
    let artifactText = if (artifactExists) { String.fromUtf8(File.readFrom(options.manifestListInput)) } else { "" }
    let schemaOk = containsText(artifactText, "\"schema\": \"happub-hapcli-cjpm-graph-manifest-list-v0\"") ||
        containsText(artifactText, "\"schema\":\"happub-hapcli-cjpm-graph-manifest-list-v0\"")
    let manifestPaths = if (schemaOk) { extractGraphManifestListPaths(artifactText) } else { ArrayList<String>() }
    let manifests = readGraphManifests(manifestPaths)
    let selected = filterGraphManifestListReadback(manifests, options)
    let status = graphManifestListReadbackStatus(options, artifactExists, schemaOk, manifestPaths, selected)
    let ok = status == "selected-manifests-ready"

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cjpm-graph-manifest-list-readback-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"read-only-manifest-list-selection\",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"manifestListInput\": \"" + escapeJson(options.manifestListInput) + "\",\n")
    out.append("  \"artifactFound\": " + boolJson(artifactExists) + ",\n")
    out.append("  \"artifactSchemaOk\": " + boolJson(schemaOk) + ",\n")
    out.append("  \"packageFilter\": \"" + escapeJson(options.packageFilter) + "\",\n")
    out.append("  \"pathContains\": \"" + escapeJson(options.pathContains) + "\",\n")
    out.append("  \"manifestCount\": " + manifestPaths.size.toString() + ",\n")
    out.append("  \"selectedCount\": " + selected.size.toString() + ",\n")
    out.append("  \"selectedManifests\": [\n")
    appendGraphManifestArray(out, selected)
    out.append("  ],\n")
    out.append("  \"commandHints\": [\n")
    appendGraphManifestReadbackCommands(out, options, selected)
    out.append("  ],\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"copy selected command hints after review\",\n")
    out.append("    \"rerun cjpm graph doctor with explicit selected manifests\",\n")
    out.append("    \"rerun manifest-list-export if selection is stale\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"manifest-list readback does not mutate manifests\",\n")
    out.append("    \"manifest-list readback does not run graph doctor, apply, CI, or cjpm build\",\n")
    out.append("    \"manifest-list readback does not feed selections into apply automatically\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

public func runCjpmGraphNormalizeApply(commandLine: Array<String>, start: Int64): String {
    let options = resolveGraphOptions(commandLine, start)
    if (!graphApplyGateOk(options)) {
        return renderCjpmGraphNormalizeApplyRejectedJson(options)
    }

    if (!exists(options.outputDir)) {
        Directory.create(options.outputDir, recursive: true)
    }
    let outputs = ArrayList<HapGraphApplyOutput>()
    var i: Int64 = 0
    while (i < options.manifests.size) {
        let input = options.manifests[i]
        let text = String.fromUtf8(File.readFrom(input))
        let normalized = renderNormalizedGraphManifestText(text, options.localMaps)
        let output = options.outputDir + "/" + i.toString() + "-" + basenameText(input)
        File.writeTo(output, normalized.toArray())
        outputs.add(HapGraphApplyOutput(input, output, normalized.size))
        i += 1
    }

    let receipt = renderCjpmGraphNormalizeApplyReceiptJson(options, outputs)
    File.writeTo(options.receipt, receipt.toArray())
    renderCjpmGraphNormalizeApplyOkJson(options, outputs)
}

public func runCjpmGraphCiWorkflowExport(commandLine: Array<String>, start: Int64): String {
    let options = resolveGraphOptions(commandLine, start)
    let hasApplySurface = options.localMaps.size > 0 && options.outputDir.size > 0 && options.receipt.size > 0
    let workflow = renderGithubActionsStep(options, hasApplySurface)
    if (options.workflowOutput.size > 0 && options.reviewToken.size == 0) {
        return renderCjpmGraphCiWorkflowExportRejectedJson(options, workflow)
    }
    var written = false
    if (options.workflowOutput.size > 0) {
        File.writeTo(options.workflowOutput, (workflow + "\n").toArray())
        written = true
    }
    renderCjpmGraphCiWorkflowExportJson(options, workflow, written)
}

public func renderNormalizedGraphManifestText(text: String, localMaps: ArrayList<HapGraphLocalMap>): String {
    let out = StringBuilder()
    var inDependencies = false

    for (line in text.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (trimmed == "[dependencies]") {
            inDependencies = true
            appendLine(out, line)
            continue
        }
        if (startsWithText(trimmed, "[") && trimmed != "[dependencies]") {
            inDependencies = false
        }
        if (inDependencies && containsText(trimmed, " = {")) {
            let dep = parseDependencyLine(trimmed)
            let targetPath = localPathFor(localMaps, dep.name)
            if (targetPath.size > 0) {
                appendLine(out, leadingWhitespace(line) + dep.name + " = { path = \"" + targetPath + "\" }")
                continue
            }
        }
        appendLine(out, line)
    }

    trimTrailingNewlines(out.toString()) + "\n"
}

func graphApplyGateOk(options: HapGraphOptions): Bool {
    options.manifests.size > 0 &&
    options.localMaps.size > 0 &&
    options.outputDir.size > 0 &&
    options.receipt.size > 0 &&
    options.reviewToken.size > 0 &&
    graphApplyOutputPolicyOk(options)
}

func renderCjpmGraphNormalizeApplyRejectedJson(options: HapGraphOptions): String {
    let outputBlocked = graphApplyOutputInsideManifestDir(options)
    "{\n" +
    "  \"schema\": \"happub-hapcli-cjpm-graph-normalize-apply-v0\",\n" +
    "  \"ok\": false,\n" +
    "  \"mode\": \"review-gated-output-apply\",\n" +
    "  \"mutationApplied\": false,\n" +
    "  \"inPlaceMutation\": false,\n" +
    "  \"status\": \"" + escapeJson(graphApplyRejectedStatus(options)) + "\",\n" +
    "  \"manifestCount\": " + options.manifests.size.toString() + ",\n" +
    "  \"localMapCount\": " + options.localMaps.size.toString() + ",\n" +
    "  \"outputDir\": \"" + escapeJson(options.outputDir) + "\",\n" +
    "  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n" +
    "  \"allowWorktreeOutput\": " + boolJson(options.allowWorktreeOutput) + ",\n" +
    "  \"outputDirInsideManifestDir\": " + boolJson(outputBlocked) + ",\n" +
    "  \"nonPromises\": [\n" +
    "    \"graph normalize apply never rewrites input manifests in place by default\",\n" +
    "    \"review-token, output-dir, and receipt are required\",\n" +
    "    \"worktree output requires explicit allow-worktree-output\",\n" +
    "    \"no network, cjpm update, or cjpm build is run\"\n" +
    "  ]\n" +
    "}"
}

func renderCjpmGraphNormalizeApplyOkJson(options: HapGraphOptions, outputs: ArrayList<HapGraphApplyOutput>): String {
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cjpm-graph-normalize-apply-v0\",\n")
    out.append("  \"ok\": true,\n")
    out.append("  \"mode\": \"review-gated-output-apply\",\n")
    out.append("  \"profile\": \"" + escapeJson(options.profile) + "\",\n")
    out.append("  \"mutationApplied\": true,\n")
    out.append("  \"inPlaceMutation\": false,\n")
    out.append("  \"allowWorktreeOutput\": " + boolJson(options.allowWorktreeOutput) + ",\n")
    out.append("  \"outputDir\": \"" + escapeJson(options.outputDir) + "\",\n")
    out.append("  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n")
    out.append("  \"writtenManifestCount\": " + outputs.size.toString() + ",\n")
    out.append("  \"outputs\": [\n")
    appendApplyOutputs(out, outputs)
    out.append("  ],\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-output-manifests\",\n")
    out.append("    \"copy-reviewed-outputs-into-workspace\",\n")
    out.append("    \"rerun-cjpm-graph-doctor\",\n")
    out.append("    \"rerun-cjpm-build\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"input manifests were not changed in place\",\n")
    out.append("    \"apply did not run cjpm update or cjpm build\",\n")
    out.append("    \"apply did not fetch dependencies\",\n")
    out.append("    \"receipt records outputs but does not certify release build success\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func renderCjpmGraphNormalizeApplyReceiptJson(options: HapGraphOptions, outputs: ArrayList<HapGraphApplyOutput>): String {
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cjpm-graph-normalize-apply-receipt-v0\",\n")
    out.append("  \"ok\": true,\n")
    out.append("  \"profile\": \"" + escapeJson(options.profile) + "\",\n")
    out.append("  \"outputDir\": \"" + escapeJson(options.outputDir) + "\",\n")
    out.append("  \"inPlaceMutation\": false,\n")
    out.append("  \"allowWorktreeOutput\": " + boolJson(options.allowWorktreeOutput) + ",\n")
    out.append("  \"reviewTokenPresent\": true,\n")
    out.append("  \"outputs\": [\n")
    appendApplyOutputs(out, outputs)
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"receipt does not prove cjpm build success\",\n")
    out.append("    \"receipt does not prove dependency availability\",\n")
    out.append("    \"receipt does not authorize unreviewed in-place replacement\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func graphApplyOutputPolicyOk(options: HapGraphOptions): Bool {
    options.allowWorktreeOutput || !graphApplyOutputInsideManifestDir(options)
}

func graphApplyRejectedStatus(options: HapGraphOptions): String {
    if (options.manifests.size > 0 &&
        options.localMaps.size > 0 &&
        options.outputDir.size > 0 &&
        options.receipt.size > 0 &&
        options.reviewToken.size > 0 &&
        graphApplyOutputInsideManifestDir(options) &&
        !options.allowWorktreeOutput) {
        return "worktree-output-needs-explicit-allow"
    }
    "missing-review-output-or-receipt"
}

func graphApplyOutputInsideManifestDir(options: HapGraphOptions): Bool {
    let output = trimTrailingSlashText(options.outputDir)
    if (output.size == 0) {
        return false
    }
    for (manifest in options.manifests) {
        let parent = parentPathText(manifest)
        if (parent.size == 0) {
            continue
        }
        if (output == parent || startsWithText(output, parent + "/")) {
            return true
        }
    }
    false
}

func renderCjpmGraphCiWorkflowExportRejectedJson(options: HapGraphOptions, workflow: String): String {
    "{\n" +
    "  \"schema\": \"happub-hapcli-cjpm-graph-ci-workflow-export-v0\",\n" +
    "  \"ok\": false,\n" +
    "  \"mode\": \"review-gated-workflow-export\",\n" +
    "  \"cliBin\": \"" + escapeJson(options.cliBin) + "\",\n" +
    "  \"workflowWritten\": false,\n" +
    "  \"workflowOutput\": \"" + escapeJson(options.workflowOutput) + "\",\n" +
    "  \"status\": \"missing-review-token-for-workflow-output\",\n" +
    "  \"workflowSnippet\": \"" + escapeJson(workflow) + "\",\n" +
    "  \"nonPromises\": [\n" +
    "    \"workflow export does not install a GitHub Actions workflow\",\n" +
    "    \"workflow export does not mutate project manifests\",\n" +
    "    \"workflow-output writes require review-token\"\n" +
    "  ]\n" +
    "}"
}

func renderCjpmGraphCiWorkflowExportJson(options: HapGraphOptions, workflow: String, written: Bool): String {
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cjpm-graph-ci-workflow-export-v0\",\n")
    out.append("  \"ok\": true,\n")
    out.append("  \"mode\": \"review-gated-workflow-export\",\n")
    out.append("  \"cliBin\": \"" + escapeJson(options.cliBin) + "\",\n")
    out.append("  \"workflowWritten\": " + boolJson(written) + ",\n")
    out.append("  \"workflowOutput\": \"" + escapeJson(options.workflowOutput) + "\",\n")
    out.append("  \"workflowSnippet\": \"" + escapeJson(workflow) + "\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-workflow-snippet\",\n")
    out.append("    \"copy-reviewed-snippet-into-github-actions\",\n")
    out.append("    \"run-ci-after-human-review\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"workflow export does not install a GitHub Actions workflow\",\n")
    out.append("    \"workflow export does not run CI\",\n")
    out.append("    \"workflow export does not mutate manifests\",\n")
    out.append("    \"workflow export does not certify build or release success\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func renderCjpmGraphManifestListArtifactJson(options: HapGraphOptions, manifests: ArrayList<String>, skipped: ArrayList<String>): String {
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cjpm-graph-manifest-list-v0\",\n")
    out.append("  \"ok\": " + boolJson(manifests.size > 0) + ",\n")
    out.append("  \"mode\": \"reviewed-manifest-list-handoff\",\n")
    out.append("  \"manifestCount\": " + manifests.size.toString() + ",\n")
    out.append("  \"rootCount\": " + options.roots.size.toString() + ",\n")
    out.append("  \"maxDepth\": " + options.maxDepth.toString() + ",\n")
    out.append("  \"includeHidden\": " + boolJson(options.includeHidden) + ",\n")
    out.append("  \"roots\": [\n")
    appendJsonStringArray(out, options.roots)
    out.append("  ],\n")
    out.append("  \"manifests\": [\n")
    appendJsonStringArray(out, manifests)
    out.append("  ],\n")
    out.append("  \"skippedDirectories\": [\n")
    appendJsonStringArray(out, skipped)
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"manifest list is a handoff artifact, not an execution instruction\",\n")
    out.append("    \"manifest list does not mutate files\",\n")
    out.append("    \"manifest list does not feed results into apply automatically\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func renderCjpmGraphManifestListExportRejectedJson(
    options: HapGraphOptions,
    manifests: ArrayList<String>,
    skipped: ArrayList<String>,
    artifact: String
): String {
    "{\n" +
    "  \"schema\": \"happub-hapcli-cjpm-graph-manifest-list-export-v0\",\n" +
    "  \"ok\": false,\n" +
    "  \"mode\": \"review-gated-manifest-list-export\",\n" +
    "  \"manifestListWritten\": false,\n" +
    "  \"manifestListOutput\": \"" + escapeJson(options.manifestListOutput) + "\",\n" +
    "  \"manifestCount\": " + manifests.size.toString() + ",\n" +
    "  \"skippedDirectoryCount\": " + skipped.size.toString() + ",\n" +
    "  \"status\": \"missing-review-token-for-manifest-list-output\",\n" +
    "  \"manifestListArtifact\": " + artifact + ",\n" +
    "  \"nonPromises\": [\n" +
    "    \"manifest list export does not mutate manifests\",\n" +
    "    \"manifest list export does not run graph doctor or apply\",\n" +
    "    \"manifest-list-output writes require review-token\"\n" +
    "  ]\n" +
    "}"
}

func renderCjpmGraphManifestListExportJson(
    options: HapGraphOptions,
    manifests: ArrayList<String>,
    skipped: ArrayList<String>,
    artifact: String,
    written: Bool
): String {
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-cjpm-graph-manifest-list-export-v0\",\n")
    out.append("  \"ok\": " + boolJson(manifests.size > 0) + ",\n")
    out.append("  \"mode\": \"review-gated-manifest-list-export\",\n")
    out.append("  \"manifestListWritten\": " + boolJson(written) + ",\n")
    out.append("  \"manifestListOutput\": \"" + escapeJson(options.manifestListOutput) + "\",\n")
    out.append("  \"manifestCount\": " + manifests.size.toString() + ",\n")
    out.append("  \"skippedDirectoryCount\": " + skipped.size.toString() + ",\n")
    out.append("  \"manifestListArtifact\": " + artifact + ",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-manifest-list-artifact\",\n")
    out.append("    \"copy-selected-manifests-into-explicit-flags\",\n")
    out.append("    \"rerun-cjpm-graph-doctor-with-explicit-manifests\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"manifest list export does not mutate manifests\",\n")
    out.append("    \"manifest list export does not run CI\",\n")
    out.append("    \"manifest list export does not feed results into apply automatically\",\n")
    out.append("    \"manifest list export does not certify build or release success\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func graphManifestListReadbackStatus(
    options: HapGraphOptions,
    artifactExists: Bool,
    schemaOk: Bool,
    manifestPaths: ArrayList<String>,
    selected: ArrayList<HapGraphManifest>
): String {
    if (options.manifestListInput.size == 0) {
        return "missing-manifest-list-input"
    }
    if (!artifactExists) {
        return "manifest-list-not-found"
    }
    if (!schemaOk) {
        return "invalid-manifest-list-schema"
    }
    if (manifestPaths.size == 0) {
        return "manifest-list-empty"
    }
    if (selected.size == 0) {
        return "no-selected-manifests"
    }
    "selected-manifests-ready"
}

func extractGraphManifestListPaths(text: String): ArrayList<String> {
    let paths = ArrayList<String>()
    let key = "\"manifests\": ["
    let start = indexOfText(text, key)
    if (start < 0) {
        return paths
    }
    let rest = substringFrom(text, start + Int64(key.size))
    let end = indexOfText(rest, "]")
    if (end < 0) {
        return paths
    }
    let body = substringTo(rest, end)
    let runes = body.toRuneArray()
    var inString = false
    var escaped = false
    var current = ""
    for (r in runes) {
        if (!inString) {
            if (r == r'"') {
                inString = true
                current = ""
            }
            continue
        }
        if (escaped) {
            current += r.toString()
            escaped = false
            continue
        }
        if (r == r'\\') {
            escaped = true
            continue
        }
        if (r == r'"') {
            if (current.size > 0) {
                paths.add(current)
            }
            inString = false
            continue
        }
        current += r.toString()
    }
    paths
}

func filterGraphManifestListReadback(manifests: ArrayList<HapGraphManifest>, options: HapGraphOptions): ArrayList<HapGraphManifest> {
    let selected = ArrayList<HapGraphManifest>()
    for (manifest in manifests) {
        if (options.packageFilter.size > 0 && manifest.packageName != options.packageFilter) {
            continue
        }
        if (options.pathContains.size > 0 && !containsText(manifest.path, options.pathContains)) {
            continue
        }
        selected.add(manifest)
    }
    selected
}

func appendGraphManifestReadbackCommands(out: StringBuilder, options: HapGraphOptions, selected: ArrayList<HapGraphManifest>): Unit {
    if (selected.size == 0) {
        return
    }
    out.append("    \"" + escapeJson(options.cliBin + " cjpm graph doctor" + graphManifestFlagsForManifests(selected)) + "\",\n")
    out.append("    \"" + escapeJson(options.cliBin + " cjpm graph ci-preflight-recipe" + graphManifestFlagsForManifests(selected)) + "\"\n")
}

func graphManifestFlagsForManifests(manifests: ArrayList<HapGraphManifest>): String {
    let out = StringBuilder()
    for (manifest in manifests) {
        out.append(" --manifest ")
        out.append(shellToken(manifest.path))
    }
    out.toString()
}

func addLocalMap(options: HapGraphOptions, value: String): Unit {
    let eq = indexOfText(value, "=")
    if (eq <= 0) {
        return
    }
    let name = substringTo(value, eq)
    let path = substringFrom(value, eq + 1)
    if (name.size > 0 && path.size > 0) {
        options.localMaps.add(HapGraphLocalMap(name, path))
    }
}

func readGraphManifests(paths: ArrayList<String>): ArrayList<HapGraphManifest> {
    let manifests = ArrayList<HapGraphManifest>()
    var i: Int64 = 0
    while (i < paths.size) {
        let path = paths[i]
        let text = String.fromUtf8(File.readFrom(path))
        manifests.add(parseGraphManifestText(text, path))
        i += 1
    }
    manifests
}

func collectGraphManifestCandidates(options: HapGraphOptions, manifests: ArrayList<String>, skipped: ArrayList<String>): Unit {
    var i: Int64 = 0
    while (i < options.manifests.size) {
        addUniqueString(manifests, options.manifests[i])
        i += 1
    }
    var j: Int64 = 0
    while (j < options.roots.size) {
        discoverGraphManifests(options.roots[j], 0, options.maxDepth, options.includeHidden, manifests, skipped)
        j += 1
    }
}

func discoverGraphManifests(
    root: String,
    depth: Int64,
    maxDepth: Int64,
    includeHidden: Bool,
    manifests: ArrayList<String>,
    skipped: ArrayList<String>
): Unit {
    try {
        let entries = Directory.readFrom(root)
        for (entry in entries) {
            let path = portableGraphPathText(entry.path.toString())
            let name = basenameText(path)
            if (entry.isDirectory()) {
                if (shouldSkipDiscoveryDirectory(name, includeHidden)) {
                    addUniqueString(skipped, path)
                } else if (depth < maxDepth) {
                    discoverGraphManifests(path, depth + 1, maxDepth, includeHidden, manifests, skipped)
                }
            } else if (isCjpmGraphManifestName(name)) {
                addUniqueString(manifests, path)
            }
        }
    } catch (_: Exception) {
        addUniqueString(skipped, root)
    }
}

public func parseGraphManifestText(text: String, path: String): HapGraphManifest {
    let deps = ArrayList<HapDependencyRef>()
    var packageName = ""
    var inDependencies = false

    for (line in text.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (packageName.size == 0 && startsWithText(trimmed, "name = ")) {
            packageName = extractQuotedValue(trimmed)
        }
        if (trimmed == "[dependencies]") {
            inDependencies = true
            continue
        }
        if (startsWithText(trimmed, "[") && trimmed != "[dependencies]") {
            inDependencies = false
        }
        if (inDependencies && containsText(trimmed, " = {")) {
            deps.add(parseDependencyLine(trimmed))
        }
    }

    HapGraphManifest(path, packageName, deps)
}

func graphConflictNames(manifests: ArrayList<HapGraphManifest>): ArrayList<String> {
    let names = graphDependencyNames(manifests)
    let conflicts = ArrayList<String>()
    var i: Int64 = 0
    while (i < names.size) {
        let name = names[i]
        if (graphHasKind(manifests, name, "path") && graphHasKind(manifests, name, "git")) {
            conflicts.add(name)
        }
        i += 1
    }
    conflicts
}

func graphDependencyNames(manifests: ArrayList<HapGraphManifest>): ArrayList<String> {
    let names = ArrayList<String>()
    var i: Int64 = 0
    while (i < manifests.size) {
        let deps = manifests[i].dependencies
        var j: Int64 = 0
        while (j < deps.size) {
            if (!stringListContains(names, deps[j].name)) {
                names.add(deps[j].name)
            }
            j += 1
        }
        i += 1
    }
    names
}

func graphHasKind(manifests: ArrayList<HapGraphManifest>, name: String, kind: String): Bool {
    var i: Int64 = 0
    while (i < manifests.size) {
        let deps = manifests[i].dependencies
        var j: Int64 = 0
        while (j < deps.size) {
            let dep = deps[j]
            if (dep.name == name && dependencyKind(dep) == kind) {
                return true
            }
            j += 1
        }
        i += 1
    }
    false
}

func graphNormalizeChanges(manifests: ArrayList<HapGraphManifest>, localMaps: ArrayList<HapGraphLocalMap>): ArrayList<HapGraphNormalizeChange> {
    let changes = ArrayList<HapGraphNormalizeChange>()
    var i: Int64 = 0
    while (i < manifests.size) {
        let manifest = manifests[i]
        var j: Int64 = 0
        while (j < manifest.dependencies.size) {
            let dep = manifest.dependencies[j]
            let targetPath = localPathFor(localMaps, dep.name)
            if (targetPath.size > 0 && dependencyKind(dep) != "path") {
                changes.add(HapGraphNormalizeChange(manifest.path, dep.name, dependencyKind(dep), dependencyValue(dep), "path", targetPath))
            } else if (targetPath.size > 0 && dep.path != targetPath) {
                changes.add(HapGraphNormalizeChange(manifest.path, dep.name, "path", dep.path, "path", targetPath))
            }
            j += 1
        }
        i += 1
    }
    changes
}

func localPathFor(localMaps: ArrayList<HapGraphLocalMap>, name: String): String {
    var i: Int64 = 0
    while (i < localMaps.size) {
        if (localMaps[i].name == name) {
            return localMaps[i].path
        }
        i += 1
    }
    ""
}

func appendGraphManifestArray(out: StringBuilder, manifests: ArrayList<HapGraphManifest>): Unit {
    var i: Int64 = 0
    while (i < manifests.size) {
        let manifest = manifests[i]
        out.append("    {\n")
        out.append("      \"path\": \"" + escapeJson(manifest.path) + "\",\n")
        out.append("      \"packageName\": \"" + escapeJson(manifest.packageName) + "\",\n")
        out.append("      \"dependencyCount\": " + manifest.dependencies.size.toString() + ",\n")
        out.append("      \"dependencies\": [\n")
        appendManifestDependencyEntries(out, manifest.dependencies)
        out.append("      ]\n")
        out.append("    }")
        if (i + 1 < manifests.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
}

func appendManifestDependencyEntries(out: StringBuilder, deps: ArrayList<HapDependencyRef>): Unit {
    var i: Int64 = 0
    while (i < deps.size) {
        let dep = deps[i]
        out.append("        {\n")
        out.append("          \"name\": \"" + escapeJson(dep.name) + "\",\n")
        out.append("          \"kind\": \"" + escapeJson(dependencyKind(dep)) + "\",\n")
        out.append("          \"value\": \"" + escapeJson(dependencyValue(dep)) + "\"\n")
        out.append("        }")
        if (i + 1 < deps.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
}

func appendGraphConflicts(out: StringBuilder, manifests: ArrayList<HapGraphManifest>, conflicts: ArrayList<String>): Unit {
    var i: Int64 = 0
    while (i < conflicts.size) {
        let name = conflicts[i]
        out.append("    {\n")
        out.append("      \"name\": \"" + escapeJson(name) + "\",\n")
        out.append("      \"code\": \"dependency-import-type-conflict\",\n")
        out.append("      \"message\": \"same dependency appears as both path and git in the provided cjpm graph\",\n")
        out.append("      \"occurrences\": [\n")
        appendConflictOccurrences(out, manifests, name)
        out.append("      ]\n")
        out.append("    }")
        if (i + 1 < conflicts.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
}

func appendConflictOccurrences(out: StringBuilder, manifests: ArrayList<HapGraphManifest>, name: String): Unit {
    var printed: Int64 = 0
    var i: Int64 = 0
    while (i < manifests.size) {
        let manifest = manifests[i]
        var j: Int64 = 0
        while (j < manifest.dependencies.size) {
            let dep = manifest.dependencies[j]
            if (dep.name == name) {
                if (printed > 0) {
                    out.append(",\n")
                }
                out.append("        {\n")
                out.append("          \"manifest\": \"" + escapeJson(manifest.path) + "\",\n")
                out.append("          \"packageName\": \"" + escapeJson(manifest.packageName) + "\",\n")
                out.append("          \"kind\": \"" + escapeJson(dependencyKind(dep)) + "\",\n")
                out.append("          \"value\": \"" + escapeJson(dependencyValue(dep)) + "\"\n")
                out.append("        }")
                printed += 1
            }
            j += 1
        }
        i += 1
    }
    if (printed > 0) {
        out.append("\n")
    }
}

func appendLocalMaps(out: StringBuilder, localMaps: ArrayList<HapGraphLocalMap>): Unit {
    var i: Int64 = 0
    while (i < localMaps.size) {
        out.append("    {\n")
        out.append("      \"name\": \"" + escapeJson(localMaps[i].name) + "\",\n")
        out.append("      \"path\": \"" + escapeJson(localMaps[i].path) + "\"\n")
        out.append("    }")
        if (i + 1 < localMaps.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
}

func appendNormalizeChanges(out: StringBuilder, changes: ArrayList<HapGraphNormalizeChange>): Unit {
    var i: Int64 = 0
    while (i < changes.size) {
        let change = changes[i]
        out.append("    {\n")
        out.append("      \"manifest\": \"" + escapeJson(change.manifest) + "\",\n")
        out.append("      \"dependency\": \"" + escapeJson(change.dependency) + "\",\n")
        out.append("      \"from\": {\n")
        out.append("        \"kind\": \"" + escapeJson(change.fromKind) + "\",\n")
        out.append("        \"value\": \"" + escapeJson(change.fromValue) + "\"\n")
        out.append("      },\n")
        out.append("      \"to\": {\n")
        out.append("        \"kind\": \"" + escapeJson(change.toKind) + "\",\n")
        out.append("        \"value\": \"" + escapeJson(change.toValue) + "\"\n")
        out.append("      },\n")
        out.append("      \"mutation\": true,\n")
        out.append("      \"requiresReview\": true\n")
        out.append("    }")
        if (i + 1 < changes.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
}

func stringListContains(items: ArrayList<String>, value: String): Bool {
    var i: Int64 = 0
    while (i < items.size) {
        if (items[i] == value) {
            return true
        }
        i += 1
    }
    false
}

func appendApplyOutputs(out: StringBuilder, outputs: ArrayList<HapGraphApplyOutput>): Unit {
    var i: Int64 = 0
    while (i < outputs.size) {
        out.append("    {\n")
        out.append("      \"input\": \"" + escapeJson(outputs[i].input) + "\",\n")
        out.append("      \"output\": \"" + escapeJson(outputs[i].output) + "\",\n")
        out.append("      \"size\": " + outputs[i].size.toString() + "\n")
        out.append("    }")
        if (i + 1 < outputs.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
}

func appendJsonStringArray(out: StringBuilder, items: ArrayList<String>): Unit {
    var i: Int64 = 0
    while (i < items.size) {
        out.append("    \"" + escapeJson(items[i]) + "\"")
        if (i + 1 < items.size) {
            out.append(",")
        }
        out.append("\n")
        i += 1
    }
}

func appendCiRecipeCommands(out: StringBuilder, options: HapGraphOptions, hasApplySurface: Bool): Unit {
    let doctor = options.cliBin + " cjpm graph doctor" + graphManifestFlags(options)
    let plan = options.cliBin + " cjpm graph normalize-plan" + graphManifestFlags(options) + graphLocalMapFlags(options)
    out.append("    {\n")
    out.append("      \"phase\": \"preflight-diagnose\",\n")
    out.append("      \"required\": true,\n")
    out.append("      \"command\": \"" + escapeJson(doctor) + "\"\n")
    out.append("    },\n")
    out.append("    {\n")
    out.append("      \"phase\": \"normalize-plan\",\n")
    out.append("      \"required\": false,\n")
    out.append("      \"command\": \"" + escapeJson(plan) + "\"\n")
    out.append("    }")
    if (hasApplySurface) {
        out.append(",\n")
        out.append("    {\n")
        out.append("      \"phase\": \"reviewed-output-apply\",\n")
        out.append("      \"required\": false,\n")
        out.append("      \"command\": \"" + escapeJson(options.cliBin + " cjpm graph apply-normalize" + graphManifestFlags(options) + graphLocalMapFlags(options) + " --output-dir " + options.outputDir + " --receipt " + options.receipt + " --review-token $" + "{HAP_REVIEW_TOKEN}") + "\"\n")
        out.append("    }")
    }
    out.append("\n")
}

func renderGithubActionsStep(options: HapGraphOptions, hasApplySurface: Bool): String {
    let out = StringBuilder()
    appendLine(out, "- name: Hap cjpm graph preflight")
    appendLine(out, "  shell: bash")
    appendLine(out, "  run: |")
    appendLine(out, "    set -eu")
    appendLine(out, "    " + options.cliBin + " cjpm graph doctor" + graphManifestFlags(options))
    appendLine(out, "    " + options.cliBin + " cjpm graph normalize-plan" + graphManifestFlags(options) + graphLocalMapFlags(options))
    if (hasApplySurface) {
        appendLine(out, "    " + options.cliBin + " cjpm graph apply-normalize" + graphManifestFlags(options) + graphLocalMapFlags(options) + " --output-dir " + options.outputDir + " --receipt " + options.receipt + " --review-token \"$" + "{HAP_REVIEW_TOKEN}\"")
        appendLine(out, "    # Review generated files before copying them over source manifests.")
    }
    trimTrailingNewlines(out.toString())
}

func graphManifestFlags(options: HapGraphOptions): String {
    let out = StringBuilder()
    var i: Int64 = 0
    while (i < options.manifests.size) {
        out.append(" --manifest " + shellToken(options.manifests[i]))
        i += 1
    }
    out.toString()
}

func graphLocalMapFlags(options: HapGraphOptions): String {
    let out = StringBuilder()
    var i: Int64 = 0
    while (i < options.localMaps.size) {
        out.append(" --local-map " + shellToken(options.localMaps[i].name + "=" + options.localMaps[i].path))
        i += 1
    }
    out.toString()
}

func shellToken(value: String): String {
    "'" + value.replace("'", "'\"'\"'") + "'"
}

func shouldSkipDiscoveryDirectory(name: String, includeHidden: Bool): Bool {
    if (!includeHidden && startsWithText(name, ".")) {
        return true
    }
    name == "target" ||
    name == "node_modules" ||
    name == ".git" ||
    name == ".idea" ||
    name == ".vscode" ||
    name == "dist" ||
    name == "build"
}

func isCjpmGraphManifestName(name: String): Bool {
    name == "cjpm.toml" || endsWithText(name, ".cjpm.toml")
}

func addUniqueString(items: ArrayList<String>, value: String): Unit {
    if (!stringListContains(items, value)) {
        items.add(value)
    }
}

func parseGraphMaxDepth(text: String): Int64 {
    let trimmed = trimAsciiText(text)
    let runes = trimmed.toRuneArray()
    var value: Int64 = 0
    var i: Int64 = 0
    while (i < runes.size) {
        let d = digitValue(runes[i])
        if (d < 0) {
            return 3
        }
        value = value * 10 + d
        i += 1
    }
    if (value < 0) {
        return 3
    }
    if (value > 8) {
        return 8
    }
    value
}

func digitValue(r: Rune): Int64 {
    if (r == r'0') { return 0 }
    if (r == r'1') { return 1 }
    if (r == r'2') { return 2 }
    if (r == r'3') { return 3 }
    if (r == r'4') { return 4 }
    if (r == r'5') { return 5 }
    if (r == r'6') { return 6 }
    if (r == r'7') { return 7 }
    if (r == r'8') { return 8 }
    if (r == r'9') { return 9 }
    -1
}

func endsWithText(text: String, suffix: String): Bool {
    if (suffix.size > text.size) {
        return false
    }
    substringRange(text, Int64(text.size - suffix.size), Int64(text.size)) == suffix
}

func basenameText(path: String): String {
    let portable = portableGraphPathText(path)
    let runes = portable.toRuneArray()
    var last: Int64 = -1
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == r'/') {
            last = i
        }
        i += 1
    }
    if (last < 0 || last + 1 >= runes.size) {
        return portable
    }
    substringFrom(portable, last + 1)
}

func parentPathText(path: String): String {
    let trimmed = trimTrailingSlashText(portableGraphPathText(path))
    let runes = trimmed.toRuneArray()
    var last: Int64 = -1
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == r'/') {
            last = i
        }
        i += 1
    }
    if (last <= 0) {
        return if (last == 0) { "/" } else { "" }
    }
    substringTo(trimmed, last)
}

func trimTrailingSlashText(path: String): String {
    var out = portableGraphPathText(path)
    while (out.size > 1 && endsWithText(out, "/")) {
        out = substringTo(out, Int64(out.size - 1))
    }
    out
}

func portableGraphPathText(path: String): String {
    path.replace("\\", "/")
}

func leadingWhitespace(text: String): String {
    let runes = text.toRuneArray()
    var i: Int64 = 0
    while (i < runes.size && isAsciiWhitespace(runes[i])) {
        i += 1
    }
    substringTo(text, i)
}
