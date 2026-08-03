package hapcli

import std.fs.{Directory, File, exists}
import std.time.*

public func runHapCli(commandLine: Array<String>): Int64 {
    if (commandLine.size <= 1) {
        println(renderHapCliHelp())
        return 0
    }

    let command = commandLine[1]
    if (command == "help" || command == "--help" || command == "-h") {
        println(renderHapCliHelp())
        return 0
    }
    if (command == "version" || command == "--version" || command == "-V") {
        println(version())
        return 0
    }
    if (command == "inspect-cjpm") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap inspect-cjpm <cjpm.toml>"))
            return 2
        }
        let input = commandLine[2]
        let text = String.fromUtf8(File.readFrom(input))
        println(renderCjpmProfileInspectJson(inspectCjpmProfileText(text, input)))
        return 0
    }
    if (command == "plan-switch") {
        if (commandLine.size <= 4) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap plan-switch <cjpm.toml> <profiles.toml> <target-profile>"))
            return 2
        }
        let input = commandLine[2]
        let profilePath = commandLine[3]
        let targetProfile = commandLine[4]
        let cjpmText = String.fromUtf8(File.readFrom(input))
        let profileText = String.fromUtf8(File.readFrom(profilePath))
        println(renderCjpmProfileSwitchPlanJson(cjpmText, profileText, input, profilePath, targetProfile))
        return 0
    }
    if (command == "apply-switch") {
        if (commandLine.size <= 4) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap apply-switch <cjpm.toml> <profiles.toml> <target-profile> --output=<path> --receipt=<path> --review-token=<token>"))
            return 2
        }
        println(runCjpmProfileSwitchApply(commandLine))
        return 0
    }
    if (command == "record") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap record [--target <target>] cangjie.stdx --project <path> [--config <path>] [--name <name>]"))
            return 2
        }
        println(runRecord(commandLine, 2))
        return 0
    }
    if (command == "doctorfix") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap doctorfix [--target <target>] cangjie.stdx --project <path> [--config <path>] [--plan|--write]"))
            return 2
        }
        println(runDoctorFix(commandLine, 2))
        return 0
    }
    if (command == "project") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap project detect --project <path> [--platform auto|harmonyos|ios|kmp|cangjie]"))
            return 2
        }
        let action = commandLine[2]
        if (action == "detect") {
            println(renderProjectDetectJson(resolveProjectDetectOptions(commandLine, 3)))
            return 0
        }
        println(renderInspectCjpmErrorJson("unknown-project-action", "unknown project action: " + action))
        return 2
    }
    if (command == "device") {
        if (commandLine.size > 2 && commandLine[2] == "set") {
            let output = runHapDeviceSet(resolveHapDeviceOptions("set", commandLine, 3))
            println(output)
            return hapDeviceCommandExitCode(output)
        }
        let output = runHapDeviceList(resolveHapDeviceOptions("list", commandLine, 2))
        println(output)
        return hapDeviceCommandExitCode(output)
    }
    if (command == "build") {
        if (shouldUseAutoProjectActionForBuild(commandLine, 2)) {
            let options = resolveProjectActionOptions("build", commandLine, 2)
            if (options.executeReviewed) {
                let output = runHarmonyReviewedExecution(options)
                println(output)
                return projectActionExecutionExitCodeFromJson(output)
            }
            println(renderProjectActionPlanJson(options))
            return 0
        }
        let options = resolveBuildOptions(commandLine, 2)
        let output = renderBuildJson(options, true, true)
        printCjpmExecutionOutput(output)
        return buildWrapperExitCodeFromJson(output)
    }
    if (command == "bundle") {
        let options = resolveBundleOptions(commandLine, 2)
        let output = renderBuildJson(options, true, true)
        printCjpmExecutionOutput(output)
        return buildWrapperExitCodeFromJson(output)
    }
    if (command == "test") {
        let options = resolveProjectActionOptions("test", commandLine, 2)
        if (options.executeReviewed) {
            let output = runHarmonyReviewedExecution(options)
            println(output)
            return projectActionExecutionExitCodeFromJson(output)
        }
        println(renderProjectActionPlanJson(options))
        return 0
    }
    if (command == "dev") {
        let deviceSetStart = hapDevDeviceSetStartIndex(commandLine)
        if (deviceSetStart >= 0) {
            let output = runHapDeviceSet(resolveHapDeviceOptions("set", commandLine, deviceSetStart))
            println(output)
            return hapDeviceCommandExitCode(output)
        }
        let options = resolveProjectActionOptions("dev", commandLine, 2)
        if (options.plan) {
            println(renderProjectActionPlanJson(options))
            return 0
        }
        if (shouldUseKmpLocalDesktopDevExecution(options)) {
            let output = if (options.verbose) {
                runKmpLocalDesktopDevExecution(options)
            } else {
                runKmpLocalDesktopDevExecutionWithSpinner(options)
            }
            if (options.verbose) {
                println(output)
            } else {
                println(renderKmpExecutionHumanSummary(output))
            }
            return projectActionExecutionExitCodeFromJson(output)
        }
        if (shouldUseKmpIosDevExecution(options)) {
            let output = if (options.verbose) {
                runKmpIosDevExecution(options)
            } else {
                runKmpIosDevExecutionWithSpinner(options)
            }
            if (options.verbose) {
                println(output)
            } else {
                println(renderKmpIosExecutionHumanSummary(output))
            }
            return projectActionExecutionExitCodeFromJson(output)
        }
        if (!shouldUseHarmonyLocalDevExecution(options)) {
            println(renderProjectActionPlanJson(options))
            return 0
        }
        if (options.executeReviewed) {
            let output = runHarmonyReviewedExecution(options)
            println(output)
            return projectActionExecutionExitCodeFromJson(output)
        }
        let output = if (options.verbose) {
            runHarmonyLocalDevAutoExecution(options)
        } else {
            runHarmonyLocalDevAutoExecutionWithSpinner(options)
        }
        if (options.verbose) {
            println(output)
        } else {
            println(renderHarmonyExecutionHumanSummary(output))
        }
        return projectActionExecutionExitCodeFromJson(output)
    }
    if (command == "push") {
        let options = resolveProjectActionOptions("push", commandLine, 2)
        if (options.executeReviewed) {
            let output = runHarmonyReviewedExecution(options)
            println(output)
            return projectActionExecutionExitCodeFromJson(output)
        }
        println(renderProjectActionPlanJson(options))
        return 0
    }
    if (command == "update") {
        println(renderUpdatePlanJson(resolveUpdatePlanOptions("update", commandLine, 2)))
        return 0
    }
    if (command == "upgrade") {
        println(renderUpdatePlanJson(resolveUpdatePlanOptions("upgrade", commandLine, 2)))
        return 0
    }
    if (command == "harmony") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap harmony <wireless-recipe|wireless-readback|device-status|device-memory> ..."))
            return 2
        }
        let action = commandLine[2]
        if (action == "wireless-recipe") {
            println(renderHarmonyWirelessRecipeJson(resolveHarmonyWirelessRecipeOptions(commandLine, 3)))
            return 0
        }
        if (action == "wireless-readback") {
            println(renderHarmonyWirelessReadbackJson(resolveHarmonyWirelessReadbackOptions(commandLine, 3)))
            return 0
        }
        if (action == "device-status") {
            println(renderHarmonyDeviceStatusJson(resolveHarmonyDeviceStatusOptions(commandLine, 3)))
            return 0
        }
        if (action == "device-memory") {
            if (commandLine.size <= 3) {
                println(renderInspectCjpmErrorJson("missing-input", "usage: hap harmony device-memory <promote|readback> ..."))
                return 2
            }
            let memoryAction = commandLine[3]
            if (memoryAction == "promote") {
                println(runHarmonyDeviceMemoryPromote(resolveHarmonyDeviceMemoryOptions("promote", commandLine, 4)))
                return 0
            }
            if (memoryAction == "readback") {
                println(renderHarmonyDeviceMemoryReadbackJson(resolveHarmonyDeviceMemoryOptions("readback", commandLine, 4)))
                return 0
            }
            println(renderInspectCjpmErrorJson("unknown-harmony-device-memory-action", "unknown harmony device-memory action: " + memoryAction))
            return 2
        }
        println(renderInspectCjpmErrorJson("unknown-harmony-action", "unknown harmony action: " + action))
        return 2
    }
    if (command == "doctor") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap doctor <stdx|runtime> --project <path> --target <target> [--search-root <path>] [--cjc-path <path>]"))
            return 2
        }
        let subject = commandLine[2]
        if (subject == "stdx") {
            println(renderStdxDoctorJson(resolveDoctorOptions(commandLine, 3)))
            return 0
        }
        if (subject == "runtime") {
            println(renderRuntimeDoctorJson(resolveDoctorOptions(commandLine, 3)))
            return 0
        }
        println(renderInspectCjpmErrorJson("unknown-doctor", "unknown doctor subject: " + subject))
        return 2
    }
    if (command == "cjpm") {
        if (commandLine.size <= 3) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap cjpm <graph|pipeline> ..."))
            return 2
        }
        let subject = commandLine[2]
        let action = commandLine[3]
        if (subject == "pipeline" && action == "plan") {
            println(renderCjpmPipelinePlanJson(resolveCjpmPipelinePlanOptions(commandLine, 4)))
            return 0
        }
        if (subject == "graph" && action == "doctor") {
            println(renderCjpmGraphDoctorJson(resolveGraphOptions(commandLine, 4)))
            return 0
        }
        if (subject == "graph" && action == "discover-manifests") {
            println(renderCjpmGraphDiscoverManifestsJson(resolveGraphOptions(commandLine, 4)))
            return 0
        }
        if (subject == "graph" && action == "manifest-list-export") {
            println(runCjpmGraphManifestListExport(commandLine, 4))
            return 0
        }
        if (subject == "graph" && action == "manifest-list-readback") {
            println(renderCjpmGraphManifestListReadbackJson(resolveGraphOptions(commandLine, 4)))
            return 0
        }
        if (subject == "graph" && action == "normalize-plan") {
            println(renderCjpmGraphNormalizePlanJson(resolveGraphOptions(commandLine, 4)))
            return 0
        }
        if (subject == "graph" && action == "apply-normalize") {
            println(runCjpmGraphNormalizeApply(commandLine, 4))
            return 0
        }
        if (subject == "graph" && action == "ci-preflight-recipe") {
            println(renderCjpmGraphCiPreflightRecipeJson(resolveGraphOptions(commandLine, 4)))
            return 0
        }
        if (subject == "graph" && action == "ci-workflow-export") {
            println(runCjpmGraphCiWorkflowExport(commandLine, 4))
            return 0
        }
        println(renderInspectCjpmErrorJson("unknown-cjpm-subcommand", "unknown cjpm subcommand: " + subject + " " + action))
        return 2
    }
    if (command == "ci") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap ci <action-doctor|bootstrap-snippet|bootstrap-packet|project-bridge-recipe|executor-recipe|executor-snippet|hosted-proof-pack> ..."))
            return 2
        }
        let action = commandLine[2]
        if (action == "action-doctor") {
            println(renderCiActionDoctorJson(resolveCiActionDoctorOptions(commandLine, 3)))
            return 0
        }
        if (action == "bootstrap-snippet") {
            println(renderCiBootstrapSnippetJson(resolveCiBootstrapOptions(commandLine, 3)))
            return 0
        }
        if (action == "bootstrap-packet") {
            println(renderCiBootstrapPacketJson(resolveCiBootstrapPacketOptions(commandLine, 3)))
            return 0
        }
        if (action == "project-bridge-recipe") {
            println(renderCiProjectBridgeRecipeJson(resolveCiProjectBridgeOptions(commandLine, 3)))
            return 0
        }
        if (action == "executor-recipe") {
            println(renderCiExecutorRecipeJson(resolveCiExecutorOptions(commandLine, 3)))
            return 0
        }
        if (action == "executor-snippet") {
            println(renderCiExecutorSnippetJson(resolveCiExecutorSnippetOptions(commandLine, 3)))
            return 0
        }
        if (action == "hosted-proof-pack") {
            println(renderCiHostedProofPackJson(resolveCiHostedProofPackOptions(commandLine, 3)))
            return 0
        }
        println(renderInspectCjpmErrorJson("unknown-ci-action", "unknown ci action: " + action))
        return 2
    }
    if (command == "install") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap install <doctor|replace-plan|restore-plan|receipt-readback> ..."))
            return 2
        }
        let action = commandLine[2]
        if (action == "doctor") {
            println(renderInstallDoctorJson(resolveInstallDoctorOptions(commandLine, 3)))
            return 0
        }
        if (action == "replace-plan") {
            println(renderInstallReplacePlanJson(resolveInstallReplacePlanOptions(commandLine, 3)))
            return 0
        }
        if (action == "restore-plan") {
            println(renderInstallRestorePlanJson(resolveInstallRestorePlanOptions(commandLine, 3)))
            return 0
        }
        if (action == "receipt-readback") {
            println(renderInstallReceiptReadbackJson(resolveInstallReceiptReadbackOptions(commandLine, 3)))
            return 0
        }
        println(renderInspectCjpmErrorJson("unknown-install-action", "unknown install action: " + action))
        return 2
    }
    if (command == "release") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap release manifest [--base-url <url>] [--channel preview]"))
            return 2
        }
        let action = commandLine[2]
        if (action == "manifest") {
            println(renderReleaseManifestJson(resolveReleaseManifestOptions(commandLine, 3)))
            return 0
        }
        println(renderInspectCjpmErrorJson("unknown-release-action", "unknown release action: " + action))
        return 2
    }
    if (command == "toolchain") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap toolchain <providers|doctor> [--project <path>] [--target <target>] [--prefer <provider>]"))
            return 2
        }
        let action = commandLine[2]
        if (action == "providers") {
            println(renderToolchainProvidersJson())
            return 0
        }
        if (action == "doctor") {
            println(renderToolchainDoctorJson(resolveToolchainDoctorOptions(commandLine, 3)))
            return 0
        }
        println(renderInspectCjpmErrorJson("unknown-toolchain-action", "unknown toolchain action: " + action))
        return 2
    }
    if (command == "env") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap env <print|apply> --subject runtime,stdx --shell zsh|bash|fish|powershell|cmd --install-root <path> --target <target>"))
            return 2
        }
        let action = commandLine[2]
        if (action == "print") {
            println(renderEnvPrintJson(resolveEnvPrintOptions(commandLine, 3)))
            return 0
        }
        if (action == "apply") {
            println(runEnvApply(commandLine, 3))
            return 0
        }
        println(renderInspectCjpmErrorJson("unknown-env-action", "unknown env action: " + action))
        return 2
    }
    if (command == "graph") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap graph <discover-manifests|manifest-list-export|manifest-list-readback|doctor|normalize-plan|apply-normalize|ci-preflight-recipe|ci-workflow-export> --manifest <cjpm.toml> [--local-map name=path]"))
            return 2
        }
        let action = commandLine[2]
        if (action == "doctor") {
            println(renderCjpmGraphDoctorJson(resolveGraphOptions(commandLine, 3)))
            return 0
        }
        if (action == "discover-manifests") {
            println(renderCjpmGraphDiscoverManifestsJson(resolveGraphOptions(commandLine, 3)))
            return 0
        }
        if (action == "manifest-list-export") {
            println(runCjpmGraphManifestListExport(commandLine, 3))
            return 0
        }
        if (action == "manifest-list-readback") {
            println(renderCjpmGraphManifestListReadbackJson(resolveGraphOptions(commandLine, 3)))
            return 0
        }
        if (action == "normalize-plan") {
            println(renderCjpmGraphNormalizePlanJson(resolveGraphOptions(commandLine, 3)))
            return 0
        }
        if (action == "apply-normalize") {
            println(runCjpmGraphNormalizeApply(commandLine, 3))
            return 0
        }
        if (action == "ci-preflight-recipe") {
            println(renderCjpmGraphCiPreflightRecipeJson(resolveGraphOptions(commandLine, 3)))
            return 0
        }
        if (action == "ci-workflow-export") {
            println(runCjpmGraphCiWorkflowExport(commandLine, 3))
            return 0
        }
        println(renderInspectCjpmErrorJson("unknown-graph-action", "unknown graph action: " + action))
        return 2
    }
    if (command == "stdx-doctor") {
        println(renderStdxDoctorJson(resolveDoctorOptions(commandLine, 2)))
        return 0
    }
    if (command == "runtime-doctor") {
        println(renderRuntimeDoctorJson(resolveDoctorOptions(commandLine, 2)))
        return 0
    }
    if (command == "get") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap get <cangjie-stdx|cangjie-sdk> --target=<target> --version=<version> [--region=auto|global|zh-cn | --provider-url=<url>] --install-root=<path> [--sha256=<sha256>|--allow-unverified]"))
            return 2
        }
        let subject = commandLine[2]
        if (subject == "cangjie-stdx") {
            println(renderCangjieStdxGetPlanJson(resolveCangjieStdxGetOptions(commandLine, 3)))
            return 0
        }
        if (subject == "cangjie-sdk") {
            println(renderCangjieSdkGetPlanJson(resolveCangjieSdkGetOptions(commandLine, 3)))
            return 0
        }
        println(renderInspectCjpmErrorJson("unknown-get-subject", "unknown get subject: " + subject))
        return 2
    }
    if (command == "fetch") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap fetch reviewed-recipe --subject=<cangjie-stdx|cangjie-runtime> --target=<target> --version=<version> --provider-url=<url> --install-root=<path> --receipt=<path> [--recipe-output=<path>] [--sha256=<sha256>|--allow-unverified] --review-token=<token>"))
            return 2
        }
        let action = commandLine[2]
        if (action == "reviewed-recipe") {
            println(renderReviewedFetchRecipeJson(resolveReviewedFetchOptions(commandLine, 3)))
            return 0
        }
        println(renderInspectCjpmErrorJson("unknown-fetch-action", "unknown fetch action: " + action))
        return 2
    }
    if (command == "handoff") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap handoff runtime --target=<target> --version=<version> --provider-url=<url> --install-root=<path> [--sha256=<sha256>|--allow-unverified]"))
            return 2
        }
        let subject = commandLine[2]
        if (subject == "runtime") {
            println(renderRuntimeHandoffJson(resolveRuntimeHandoffOptions(commandLine, 3)))
            return 0
        }
        println(renderInspectCjpmErrorJson("unknown-handoff-subject", "unknown handoff subject: " + subject))
        return 2
    }
    if (command == "dictionary") {
        if (commandLine.size <= 2) {
            println(renderInspectCjpmErrorJson("missing-input", "usage: hap dictionary refresh --cache=<path> --source=<path|file://|https://...> [--review-token=<token>]"))
            return 2
        }
        let action = commandLine[2]
        if (action == "refresh") {
            println(runDictionaryRefresh(commandLine, 3))
            return 0
        }
        println(renderInspectCjpmErrorJson("unknown-dictionary-action", "unknown dictionary action: " + action))
        return 2
    }

    println(renderInspectCjpmErrorJson("unknown-command", "unknown command: " + command))
    2
}

func hapDevDeviceSetStartIndex(commandLine: Array<String>): Int64 {
    if (commandLine.size > 2 && commandLine[2] == "--set") {
        return 3
    }
    -1
}

func runKmpLocalDesktopDevExecutionWithSpinner(options: HapProjectActionOptions): String {
    let logDir = if (options.logDir.size > 0) {
        trimTrailingSlash(options.logDir)
    } else {
        trimTrailingSlash(options.project) + "/.hapData/logs/kmp-dev"
    }
    if (!exists(logDir)) {
        Directory.create(logDir, recursive: true)
    }
    File.writeTo(harmonyCurrentStepPath(logDir), "building and running KMP desktop application".toArray())
    let future: Future<String> = spawn {
        => runKmpLocalDesktopDevExecution(options)
    }
    var tick: Int64 = 0
    while (true) {
        match (future.tryGet()) {
            case Some(output) =>
                let ok = projectActionExecutionExitCodeFromJson(output) == 0
                print(renderHarmonyLocalDevSpinnerFrameForStage(tick, true, ok, "KMP desktop dev"), flush: true)
                println()
                return output
            case None =>
                print(renderHarmonyLocalDevSpinnerFrameForStage(tick, false, true, "building and running KMP desktop application"), flush: true)
                sleep(Duration.millisecond * 100)
                tick += 1
        }
    }
    ""
}

func runKmpIosDevExecutionWithSpinner(options: HapProjectActionOptions): String {
    let logDir = if (options.logDir.size > 0) {
        trimTrailingSlash(options.logDir)
    } else {
        trimTrailingSlash(options.project) + "/.hapData/logs/kmp-ios-dev"
    }
    if (!exists(logDir)) {
        Directory.create(logDir, recursive: true)
    }
    File.writeTo(harmonyCurrentStepPath(logDir), "preparing KMP iOS dev".toArray())
    let future: Future<String> = spawn {
        => runKmpIosDevExecution(options)
    }
    var tick: Int64 = 0
    while (true) {
        let stage = readHarmonySpinnerStage(logDir)
        match (future.tryGet()) {
            case Some(output) =>
                let ok = projectActionExecutionExitCodeFromJson(output) == 0
                print(renderHarmonyLocalDevSpinnerFrameForStage(tick, true, ok, stage), flush: true)
                println()
                return output
            case None =>
                print(renderHarmonyLocalDevSpinnerFrameForStage(tick, false, true, stage), flush: true)
                sleep(Duration.millisecond * 100)
                tick += 1
        }
    }
    ""
}

func runHarmonyLocalDevAutoExecutionWithSpinner(options: HapProjectActionOptions): String {
    let logDir = if (options.logDir.size > 0) {
        trimTrailingSlash(options.logDir)
    } else {
        trimTrailingSlash(options.project) + "/.hapData/logs/harmony-dev"
    }
    if (!exists(logDir)) {
        Directory.create(logDir, recursive: true)
    }
    File.writeTo(harmonyCurrentStepPath(logDir), "preparing Hap dev".toArray())
    let future: Future<String> = spawn {
        => runHarmonyLocalDevAutoExecution(options)
    }
    var stageTick: Int64 = 0
    var lastStage = "preparing Hap dev"
    while (true) {
        let stage = readHarmonySpinnerStage(logDir)
        if (stage != lastStage) {
            lastStage = stage
            stageTick = 0
        }
        match (future.tryGet()) {
            case Some(output) =>
                let ok = projectActionExecutionExitCodeFromJson(output) == 0
                print(renderHarmonyLocalDevSpinnerFrameForStage(stageTick, true, ok, stage), flush: true)
                println()
                return output
            case None =>
                print(renderHarmonyLocalDevSpinnerFrameForStage(stageTick, false, true, stage), flush: true)
                sleep(Duration.millisecond * 100)
                stageTick += 1
        }
    }
    ""
}

func readHarmonySpinnerStage(logDir: String): String {
    let currentStep = harmonyCurrentStepPath(logDir)
    if (exists(currentStep)) {
        let text = trimAsciiText(String.fromUtf8(File.readFrom(currentStep)))
        if (text.size > 0) {
            return text
        }
    }
    "preparing Hap dev"
}

func shouldUseHarmonyLocalDevExecution(options: HapProjectActionOptions): Bool {
    let candidates = detectProjectCandidates(options.project)
    let selected = selectProjectDetection(candidates, options.platform)
    let selection = resolveProjectSelectionInfo(candidates, options.platform, selected)
    selection.status == "selected" && selected.projectKind == "harmonyos"
}

func shouldUseKmpLocalDesktopDevExecution(options: HapProjectActionOptions): Bool {
    if (!isKmpDesktopTarget(options.target)) {
        return false
    }
    let candidates = detectProjectCandidates(options.project)
    let selected = selectProjectDetection(candidates, options.platform)
    let selection = resolveProjectSelectionInfo(candidates, options.platform, selected)
    selection.status == "selected" && selected.projectKind == "kotlin-multiplatform"
}

func shouldUseKmpIosDevExecution(options: HapProjectActionOptions): Bool {
    if (!isKmpIosTarget(options.target)) {
        return false
    }
    let candidates = detectProjectCandidates(options.project)
    let selected = selectProjectDetection(candidates, options.platform)
    let selection = resolveProjectSelectionInfo(candidates, options.platform, selected)
    selection.status == "selected" && selected.projectKind == "kotlin-multiplatform"
}

public func shouldUseKmpIosArtifactDevExecution(options: HapProjectActionOptions): Bool {
    shouldUseKmpIosDevExecution(options) && (options.useOld || options.artifact.size > 0)
}

public func renderHapCliHelp(): String {
    "HapCLI " + version() + "\n\nCommands:\n" +
    "  inspect-cjpm <cjpm.toml>                         Inspect Cangjie cjpm dependency profile and emit JSON\n" +
    "  plan-switch <cjpm.toml> <profiles.toml> <target>  Preview a read-only dependency profile switch plan\n" +
    "  apply-switch <cjpm.toml> <profiles.toml> <target> Write reviewed switch output and receipt, never in-place by default\n" +
    "  project detect --project <path>                  Detect HarmonyOS/iOS/KMP/Cangjie project adapter candidates\n" +
    "  device [--project <path>] [--all] [--json]      List project-relevant HDC/ADB/CoreDevice targets and aliases\n" +
    "         [--no-probe] [--timeout-seconds N]       Bound fixed backend probes or read aliases without probing\n" +
    "  device set                                      Open keyboard device alias/default manager\n" +
    "  device set --alias <name> --platform <kind> --target <id>\n" +
    "  device set --default <alias> | --rename old:new | --delete <alias>\n" +
    "                                                     Manage the same registry non-interactively for agents/CI\n" +
    "  build --plan --platform <kind>                   Plan fixed adapter build command templates without executing\n" +
    "  build --platform harmonyos --execute-reviewed    Run fixed HarmonyOS adapter only after review token and receipt\n" +
    "  test --project <path> [--lint]                   Plan fixed adapter test command templates without executing\n" +
    "  dev --project <path> [-v|--verbose] [--write-receipt]\n" +
    "                                                     Run HarmonyOS, KMP desktop, or KMP iOS build/deploy\n" +
    "  dev --set                                        Open the same device manager as `hap device set`\n" +
    "       [--proxy|--no-proxy]                         Inherit proxy env explicitly; default clears proxy env\n" +
    "  dev --target ios [--useOld] [--artifact <app>]    Rebuild/sign iOS by default; explicitly reuse an old signed app\n" +
    "  --toolchain-answer key=path                      Validate a missing hvigorw/hdc/cjpm/cjc path without stdin\n" +
    "  push --project <path> --artifact <path>          Plan HarmonyOS artifact install without executing\n" +
    "  harmony wireless-recipe --receipt <path>         Write reviewed USB-first hdc tconn recipe after review\n" +
    "  harmony wireless-readback --receipt <path>       Read and validate wireless receipt without executing hdc\n" +
    "  harmony device-status [--check-hdc] [--hdc-timeout-seconds N]\n" +
    "                                                     Read trusted memory and optionally probe hdc targets\n" +
    "  harmony device-memory promote --receipt <path>   Promote successful reviewed dev/push receipt into trusted memory\n" +
    "  harmony device-memory readback                   Read trusted device memory without executing hdc\n" +
    "  update [dependencies|toolchain]                  Plan recommended updates without mutating dependencies\n" +
    "  upgrade [dependencies|hap|toolchain]             Plan reviewed upgrades without installing or mutating now\n" +
    "  record cangjie.stdx --target <target>            Learn stdx target parameters from an existing cjpm project\n" +
    "  doctorfix cangjie.stdx --target <target>         Plan or write a recorded stdx target repair with backup\n" +
    "  build --project <path> --target <target>          Run fixed cjpm build with bounded environment/stdx repair\n" +
    "  bundle --project <path> [--skip-lint]             Run fixed cjpm bundle after central dependency topology diagnosis\n" +
    "       [--env-fix|--no-env-fix] [--openssl-lib P]   Use verified child-process-only OpenSSL environment repair\n" +
    "  cjpm graph discover-manifests --root <dir>        Discover cjpm manifests under explicit roots\n" +
    "  cjpm graph manifest-list-export --root <dir>      Write reviewed manifest-list handoff artifact\n" +
    "  cjpm graph manifest-list-readback --manifest-list <path> Read and select manifest-list artifacts\n" +
    "  cjpm graph doctor --manifest <cjpm.toml>          Diagnose path/git conflicts across explicit manifests\n" +
    "  cjpm graph normalize-plan --local-map n=p         Plan local-bundle import type convergence\n" +
    "  cjpm graph apply-normalize --output-dir <dir>     Write reviewed normalized copies outside manifest dirs by default\n" +
    "  cjpm graph ci-preflight-recipe                    Emit a read-only CI preflight recipe for graph doctor/apply\n" +
    "  cjpm graph ci-workflow-export                     Export reviewed GitHub Actions snippet text\n" +
    "  cjpm pipeline plan --project <path>               Emit a read-only deep cjpm pipeline plan\n" +
    "  ci action-doctor --workflow <path>                Diagnose an existing CI workflow and suggest HapCLI repairs\n" +
    "  ci bootstrap-snippet                              Emit a clear missing-hap CI bootstrap snippet\n" +
    "  ci bootstrap-packet                               Emit reviewed hapup bootstrap packet text without executing it\n" +
    "  ci project-bridge-recipe                          Emit a reviewed fetch/build/test bridge script without executing it\n" +
    "  ci executor-recipe                                Chain reviewed fetch/env/project scripts without executing in HapCLI\n" +
    "  ci executor-snippet                               Emit a reviewed CI snippet for executor adoption review\n" +
    "  ci hosted-proof-pack                              Write a non-mutating hosted CI proof workflow pack\n" +
    "  release manifest                                  Emit release asset/checksum truth without publishing assets\n" +
    "  install doctor --brewfile <path>|--formula <path> Diagnose tap/brew/action bootstrap config without installing\n" +
    "  install replace-plan --asset <path|url>           Review hapup flagship replacement inputs without installing\n" +
    "  install restore-plan --install-dir <dir>          Review hapup flagship restore inputs without restoring\n" +
    "  install receipt-readback --receipt <path>         Read install/restore receipts without taking action\n" +
    "  toolchain providers                              List compatible SDK/provider families without executing them\n" +
    "  toolchain doctor --prefer <provider>             Recommend provider lane without SDK version management\n" +
    "  env print --shell zsh --install-root <path>      Print shell env snippet without mutating rc files\n" +
    "  env apply --rc <path> --receipt <path>            Patch exact rc path after review, with backup and receipt\n" +
    "  doctor stdx --project <path> --target <target>    Diagnose stdx path shape without installing anything\n" +
    "  doctor runtime --project <path> --target <target> Diagnose Cangjie runtime path shape without installing anything\n" +
    "  get cangjie-stdx --target=<target> --version=<v>  Route GitHub/GitCode and emit a checksum-gated stdx plan\n" +
    "  get cangjie-sdk --target=<target> --version=<v>   Route GitHub/GitCode and emit an SDK install/repair plan\n" +
    "       [--region auto|global|zh-cn]                 CLI > HAP_REGION > Hap TOML > locale/timezone > global\n" +
    "  fetch reviewed-recipe --recipe-output=<path>      Emit or write a reviewed bash fetch/deploy recipe without executing it\n" +
    "  handoff runtime --target=<target> --version=<v>   Emit a runtime-only handoff envelope for HapShell\n" +
    "  dictionary refresh --cache=<path> --source=<src>  Refresh local dictionary cache; proxy env is opt-in\n" +
    "  version                                          Print HapCLI version\n" +
    "  help                                             Show this help"
}

func printCjpmExecutionOutput(output: String): Unit {
    if (containsText(output, "\"verbose\": true")) {
        println(output)
    } else {
        println(renderCjpmExecutionHumanSummary(output))
    }
}

public func renderInspectCjpmErrorJson(code: String, message: String): String {
    "{\n" +
    "  \"schema\": \"happub-hapcli-error-v0\",\n" +
    "  \"ok\": false,\n" +
    "  \"code\": \"" + escapeJson(code) + "\",\n" +
    "  \"message\": \"" + escapeJson(message) + "\"\n" +
    "}"
}
