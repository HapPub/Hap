package hapcli

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.process.executeWithOutput

public class HapBuildOptions {
    public var action: String = "build"
    public var project: String = "."
    public var target: String = ""
    public var requestedTarget: String = ""
    public var configPath: String = ""
    public var verbose: Bool = false
    public var networkMode: String = "no-proxy"
    public var skipLint: Bool = false
    public var environmentAutoFix: Bool = true
    public var environmentAutoFixExplicit: Bool = false
    public var opensslLibPath: String = ""
    public var toolchainAutoBootstrap: Bool = true
    public var toolchainAutoBootstrapExplicit: Bool = false
    public var cangjieSdkVersion: String = "auto"
    public var downloadRegion: String = "auto"
    public var downloadRegionExplicit: Bool = false
    public var downloadAcceleration: String = "auto"
    public var toolchainCacheRoot: String = ""
    public var toolchainBootstrapTimeoutSeconds: Int64 = 900
    public var toolchainDownloadRetryCount: Int64 = 2
    public let downloadAccelerators: ArrayList<String> = ArrayList<String>()
    public var toolchainBootstrapAttempted: Bool = false
    public var toolchainBootstrapOk: Bool = false
    public var toolchainBootstrapStatus: String = "not-attempted"
    public var toolchainBootstrapVersion: String = ""
    public var toolchainBootstrapSdkPlatform: String = ""
    public var toolchainBootstrapStdxPlatform: String = ""
    public var toolchainBootstrapCacheRoot: String = ""
    public var toolchainBootstrapCacheRootSource: String = ""
    public var toolchainBootstrapManifestPath: String = ""
    public var toolchainBootstrapManifestUrl: String = ""
    public var toolchainBootstrapSdkAsset: String = ""
    public var toolchainBootstrapSdkSha256: String = ""
    public var toolchainBootstrapStdxAsset: String = ""
    public var toolchainBootstrapStdxSha256: String = ""
    public var toolchainBootstrapSdkInstallRoot: String = ""
    public var toolchainBootstrapStdxInstallRoot: String = ""
    public var toolchainBootstrapEnvsetupPath: String = ""
    public var toolchainBootstrapDownloadSource: String = ""
    public var toolchainBootstrapDownloadActionTaken: Bool = false
    public var toolchainBootstrapChecksumVerified: Bool = false
    public var toolchainBootstrapInstallActionTaken: Bool = false
    public var toolchainBootstrapCacheHit: Bool = false
    public var toolchainBootstrapDiagnostic: String = ""

    public init() {}
}

public class HapBuildCommandResult {
    public var ran: Bool = false
    public var exitCode: Int64 = -1
    public var stdout: String = ""
    public var stderr: String = ""

    public init() {}

    public init(exitCode: Int64, stdout: String, stderr: String) {
        this.ran = true
        this.exitCode = exitCode
        this.stdout = stdout
        this.stderr = stderr
    }
}

class HapBuildConfig {
    var path: String = ""
    var pathSource: String = ""
    var exists: Bool = false
    var alwaysFix: Bool = false
    var verbose: Bool = false
    var environmentAutoFix: Bool = true
    var opensslLibPath: String = ""
    var toolchainAutoBootstrap: Bool = true
    var cangjieSdkVersion: String = "auto"
    var downloadRegion: String = "auto"
    var downloadRegionExplicit: Bool = false
    var downloadAcceleration: String = "auto"
    var toolchainCacheRoot: String = ""
    var toolchainBootstrapTimeoutSeconds: Int64 = 900
    var toolchainDownloadRetryCount: Int64 = 2
    let downloadAccelerators: ArrayList<String> = ArrayList<String>()

    init() {}
}

public func resolveBuildOptions(commandLine: Array<String>, start: Int64): HapBuildOptions {
    let options = HapBuildOptions()
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
        if (current == "--target" && i + 1 < commandLine.size) {
            options.requestedTarget = commandLine[i + 1]
            options.target = canonicalTargetName(commandLine[i + 1])
            i += 2
            continue
        }
        if (startsWithText(current, "--target=")) {
            options.requestedTarget = substringFrom(current, 9)
            options.target = canonicalTargetName(options.requestedTarget)
            i += 1
            continue
        }
        if (current == "--config" && i + 1 < commandLine.size) {
            options.configPath = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--config=")) {
            options.configPath = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--verbose" || current == "-v") {
            options.verbose = true
            i += 1
            continue
        }
        if (current == "--skip-lint") {
            options.skipLint = true
            i += 1
            continue
        }
        if (current == "--no-env-fix") {
            options.environmentAutoFix = false
            options.environmentAutoFixExplicit = true
            i += 1
            continue
        }
        if (current == "--env-fix") {
            options.environmentAutoFix = true
            options.environmentAutoFixExplicit = true
            i += 1
            continue
        }
        if (current == "--no-toolchain-bootstrap") {
            options.toolchainAutoBootstrap = false
            options.toolchainAutoBootstrapExplicit = true
            i += 1
            continue
        }
        if (current == "--toolchain-bootstrap") {
            options.toolchainAutoBootstrap = true
            options.toolchainAutoBootstrapExplicit = true
            i += 1
            continue
        }
        if (current == "--sdk-version" && i + 1 < commandLine.size) {
            options.cangjieSdkVersion = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--sdk-version=")) {
            options.cangjieSdkVersion = substringFrom(current, 14)
            i += 1
            continue
        }
        if (current == "--region" && i + 1 < commandLine.size) {
            options.downloadRegion = commandLine[i + 1]
            options.downloadRegionExplicit = true
            i += 2
            continue
        }
        if (startsWithText(current, "--region=")) {
            options.downloadRegion = substringFrom(current, 9)
            options.downloadRegionExplicit = true
            i += 1
            continue
        }
        if (current == "--download-acceleration" && i + 1 < commandLine.size) {
            options.downloadAcceleration = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--download-acceleration=")) {
            options.downloadAcceleration = substringFrom(current, 24)
            i += 1
            continue
        }
        if (current == "--toolchain-cache-root" && i + 1 < commandLine.size) {
            options.toolchainCacheRoot = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--toolchain-cache-root=")) {
            options.toolchainCacheRoot = substringFrom(current, 23)
            i += 1
            continue
        }
        if (current == "--accelerator" && i + 1 < commandLine.size) {
            options.downloadAccelerators.add(commandLine[i + 1])
            i += 2
            continue
        }
        if (startsWithText(current, "--accelerator=")) {
            options.downloadAccelerators.add(substringFrom(current, 14))
            i += 1
            continue
        }
        if (current == "--openssl-lib" && i + 1 < commandLine.size) {
            options.opensslLibPath = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--openssl-lib=")) {
            options.opensslLibPath = substringFrom(current, 14)
            i += 1
            continue
        }
        if (current == "--proxy") {
            options.networkMode = "proxy"
            i += 1
            continue
        }
        if (current == "--no-proxy") {
            options.networkMode = "no-proxy"
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func runBuild(commandLine: Array<String>, start: Int64): String {
    renderBuildJson(resolveBuildOptions(commandLine, start), true, true)
}

public func resolveBundleOptions(commandLine: Array<String>, start: Int64): HapBuildOptions {
    let options = resolveBuildOptions(commandLine, start)
    options.action = "bundle"
    options
}

public func runBundle(commandLine: Array<String>, start: Int64): String {
    renderBuildJson(resolveBundleOptions(commandLine, start), true, true)
}

public func buildWrapperExitCodeFromJson(json: String): Int64 {
    if (containsText(json, "\"ok\": true")) {
        return 0
    }
    if (containsText(json, "\"status\": \"project-not-supported-missing-cjpm\"") ||
        containsText(json, "\"status\": \"execution-disabled\"")) {
        return 2
    }
    1
}

public func renderBuildJson(options: HapBuildOptions, canExecute: Bool, canWrite: Bool): String {
    if (!exists(projectManifestPath(options.project))) {
        return renderBuildJsonFromResults(
            options,
            false,
            HapBuildCommandResult(),
            HapBuildCommandResult()
        )
    }
    if (!canExecute) {
        return renderBuildJsonFromResults(
            options,
            canWrite,
            HapBuildCommandResult(),
            HapBuildCommandResult()
        )
    }

    let config = readHapBuildConfig(options)
    if (config.toolchainAutoBootstrap && !isProgramResolvable("cjpm")) {
        applyCangjieBootstrapResult(options, prepareCangjieToolchainBootstrap(options, config))
    }
    let environment = inspectCurrentCjpmEnvironment(config.opensslLibPath)
    let blockers = if (options.action == "bundle") {
        centralDependencyBlockers(projectManifestPath(options.project))
    } else {
        Array<HapCentralDependencyBlocker>()
    }
    if (blockers.size > 0) {
        return renderCjpmExecutionReceiptJson(
            options,
            config,
            readBuildStdxProfile(options, config),
            HapBuildCommandResult(),
            HapBuildCommandResult(),
            false,
            false,
            canWrite,
            environment,
            false,
            "none",
            blockers
        )
    }

    let preflightEnvironmentRepair = config.environmentAutoFix && environment.repairAvailable
    let firstAssignments = if (preflightEnvironmentRepair) {
        environment.assignments.toArray()
    } else {
        Array<String>()
    }
    let first = executeCjpmAction(options, "", firstAssignments)
    var retry = HapBuildCommandResult()
    let profile = readBuildStdxProfile(options, config)
    var manifestRepairApplied = false
    var environmentRepairApplied = preflightEnvironmentRepair
    var environmentRepairStage = if (preflightEnvironmentRepair) { "preflight-child-overlay" } else { "none" }
    if (first.ran && first.exitCode != 0 && config.toolchainAutoBootstrap && !options.toolchainBootstrapAttempted &&
        cjpmFailureLooksLikeMissingTargetToolchain(first)) {
        applyCangjieBootstrapResult(options, prepareCangjieToolchainBootstrap(options, config))
        if (options.toolchainBootstrapOk) {
            retry = executeCjpmAction(options, profile.sourceTarget, firstAssignments)
        }
    }
    let canRetryEnvironment = !retry.ran && first.ran && first.exitCode != 0 && config.environmentAutoFix &&
        environment.candidateVerified && !preflightEnvironmentRepair && cjpmFailureLooksLikeCryptoEnvironmentDrift(first)
    if (canRetryEnvironment) {
        retry = executeCjpmAction(options, profile.sourceTarget, environment.assignments.toArray())
        environmentRepairApplied = true
        environmentRepairStage = "failure-classified-retry"
    } else if (shouldAttemptBuildDoctorfixRetry(options, config, profile, first, retry, canWrite)) {
        let doctorOptions = buildDoctorFixOptions(options, config)
        let repairJson = renderDoctorFixJson(doctorOptions, true)
        manifestRepairApplied = containsText(repairJson, "\"manifestMutationActionTaken\": true")
        if (manifestRepairApplied) {
            retry = executeCjpmAction(options, profile.sourceTarget, firstAssignments)
        }
    }

    renderCjpmExecutionReceiptJson(
        options,
        config,
        profile,
        first,
        retry,
        manifestRepairApplied,
        false,
        canWrite,
        environment,
        environmentRepairApplied,
        environmentRepairStage,
        Array<HapCentralDependencyBlocker>()
    )
}

func shouldAttemptBuildDoctorfixRetry(
    options: HapBuildOptions,
    config: HapBuildConfig,
    profile: HapStdxProfile,
    first: HapBuildCommandResult,
    retry: HapBuildCommandResult,
    canWrite: Bool
): Bool {
    !retry.ran && options.action == "build" && first.ran && first.exitCode != 0 &&
        config.alwaysFix && profile.target.size > 0 && canWrite
}

public func renderBuildJsonFromResults(
    options: HapBuildOptions,
    canWrite: Bool,
    first: HapBuildCommandResult,
    retry: HapBuildCommandResult
): String {
    let config = readHapBuildConfig(options)
    let profile = readBuildStdxProfile(options, config)
    let shouldRepair = first.ran && first.exitCode != 0 && config.alwaysFix && profile.target.size > 0
    var repairApplied = false
    if (shouldRepair && canWrite) {
        let doctorOptions = buildDoctorFixOptions(options, config)
        let repairJson = renderDoctorFixJson(doctorOptions, true)
        repairApplied = containsText(repairJson, "\"manifestMutationActionTaken\": true")
    }
    renderBuildReceiptJson(options, config, profile, first, retry, repairApplied, true, canWrite)
}

func executeCjpmBuild(options: HapBuildOptions, profileSourceTarget: String): HapBuildCommandResult {
    executeCjpmAction(options, profileSourceTarget, Array<String>())
}

func executeCjpmAction(
    options: HapBuildOptions,
    profileSourceTarget: String,
    assignments: Array<String>
): HapBuildCommandResult {
    if (!isProgramResolvable("cjpm") && options.toolchainBootstrapEnvsetupPath.size == 0) {
        return HapBuildCommandResult(127, "", "missing required command: cjpm")
    }
    let args = ArrayList<String>()
    args.add(options.action)
    let targetArg = if (options.action == "build") { buildCjpmTargetArg(options, profileSourceTarget) } else { "" }
    if (options.action == "bundle" && options.skipLint) {
        args.add("--skip-lint")
    }
    if (options.action == "build" && targetArg.size > 0) {
        args.add("--target")
        args.add(targetArg)
    }
    let workingDir = buildWorkingDirectory(options.project)
    let command = if (options.toolchainBootstrapEnvsetupPath.size > 0) {
        let shellArgs = ArrayList<String>()
        shellArgs.add("-c")
        shellArgs.add("set -e; . \"$1\"; shift; export CANGJIE_STDX_PATH=\"$1\"; shift; exec \"$@\"")
        shellArgs.add("hap-toolchain-child")
        shellArgs.add(options.toolchainBootstrapEnvsetupPath)
        shellArgs.add(options.toolchainBootstrapStdxInstallRoot)
        shellArgs.add("cjpm")
        for (arg in args.toArray()) {
            shellArgs.add(arg)
        }
        resolveHapNetworkCommandWithAssignments(options.networkMode, assignments, "/bin/sh", shellArgs.toArray())
    } else {
        resolveHapNetworkCommandWithAssignments(options.networkMode, assignments, "cjpm", args.toArray())
    }
    let (exitCode, stdoutBytes, stderrBytes) = executeWithOutput(command.program, command.args.toArray(), workingDirectory: Path(workingDir))
    HapBuildCommandResult(exitCode, String.fromUtf8(stdoutBytes), String.fromUtf8(stderrBytes))
}

func readHapBuildConfig(options: HapBuildOptions): HapBuildConfig {
    let config = HapBuildConfig()
    config.path = resolveHapConfigPath(options.project, options.configPath)
    config.pathSource = configPathSource(options.project, options.configPath, config.path)
    config.exists = exists(config.path)
    if (config.exists) {
        let text = String.fromUtf8(File.readFrom(config.path))
        config.alwaysFix = readTomlBool(text, "alwaysFix")
        config.verbose = readTomlBool(text, "verbose")
        config.environmentAutoFix = readTomlBoolOr(text, "environmentAutoFix", true)
        config.opensslLibPath = readTomlString(text, "opensslLibPath")
        config.toolchainAutoBootstrap = readTomlBoolOr(text, "toolchainAutoBootstrap", true)
        config.cangjieSdkVersion = readTomlString(text, "cangjieSdkVersion")
        if (config.cangjieSdkVersion.size == 0) {
            config.cangjieSdkVersion = "auto"
        }
        config.downloadRegion = readTomlString(text, "downloadRegion")
        if (config.downloadRegion.size > 0) {
            config.downloadRegionExplicit = true
        }
        config.downloadAcceleration = readTomlString(text, "downloadAcceleration")
        if (config.downloadAcceleration.size == 0) {
            config.downloadAcceleration = "auto"
        }
        config.toolchainCacheRoot = readTomlString(text, "toolchainCacheRoot")
        config.toolchainBootstrapTimeoutSeconds = readHapBootstrapTomlInt(text, "toolchainBootstrapTimeoutSeconds", 900)
        config.toolchainDownloadRetryCount = readHapBootstrapTomlInt(text, "toolchainDownloadRetryCount", 2)
        for (accelerator in readHapBootstrapStringArray(text, "downloadAccelerators")) {
            config.downloadAccelerators.add(accelerator)
        }
    }
    if (options.verbose) {
        config.verbose = true
    }
    if (options.environmentAutoFixExplicit) {
        config.environmentAutoFix = options.environmentAutoFix
    }
    if (options.opensslLibPath.size > 0) {
        config.opensslLibPath = options.opensslLibPath
    }
    if (options.toolchainAutoBootstrapExplicit) {
        config.toolchainAutoBootstrap = options.toolchainAutoBootstrap
    }
    if (options.cangjieSdkVersion != "auto") {
        config.cangjieSdkVersion = options.cangjieSdkVersion
    }
    if (options.downloadRegionExplicit) {
        config.downloadRegion = options.downloadRegion
        config.downloadRegionExplicit = true
    }
    if (options.downloadAcceleration != "auto") {
        config.downloadAcceleration = options.downloadAcceleration
    }
    if (options.toolchainCacheRoot.size > 0) {
        config.toolchainCacheRoot = options.toolchainCacheRoot
    }
    if (options.downloadAccelerators.size > 0) {
        config.downloadAccelerators.clear()
        for (accelerator in options.downloadAccelerators) {
            config.downloadAccelerators.add(accelerator)
        }
    }
    config
}

func readBuildStdxProfile(options: HapBuildOptions, config: HapBuildConfig): HapStdxProfile {
    if (!config.exists) {
        return HapStdxProfile()
    }
    let text = String.fromUtf8(File.readFrom(config.path))
    findRecordedStdxProfile(text, options.target)
}

func buildDoctorFixOptions(options: HapBuildOptions, config: HapBuildConfig): HapDoctorFixOptions {
    let doctor = HapDoctorFixOptions()
    doctor.subject = "cangjie.stdx"
    doctor.project = options.project
    doctor.target = options.target
    doctor.configPath = config.path
    doctor.plan = false
    doctor.write = true
    doctor
}

func renderBuildReceiptJson(
    options: HapBuildOptions,
    config: HapBuildConfig,
    profile: HapStdxProfile,
    first: HapBuildCommandResult,
    retry: HapBuildCommandResult,
    repairApplied: Bool,
    injectedResults: Bool,
    canWrite: Bool
): String {
    renderCjpmExecutionReceiptJson(
        options,
        config,
        profile,
        first,
        retry,
        repairApplied,
        injectedResults,
        canWrite,
        HapCjpmEnvironmentPlan(),
        false,
        "none",
        Array<HapCentralDependencyBlocker>()
    )
}

func renderCjpmExecutionReceiptJson(
    options: HapBuildOptions,
    config: HapBuildConfig,
    profile: HapStdxProfile,
    first: HapBuildCommandResult,
    retry: HapBuildCommandResult,
    repairApplied: Bool,
    injectedResults: Bool,
    canWrite: Bool,
    environment: HapCjpmEnvironmentPlan,
    environmentRepairApplied: Bool,
    environmentRepairStage: String,
    dependencyBlockers: Array<HapCentralDependencyBlocker>
): String {
    let project = if (options.project.size > 0) { options.project } else { "." }
    let manifest = projectManifestPath(project)
    let projectOk = exists(manifest)
    let receiptPath = cjpmExecutionReceiptPath(project, options.action)
    let finalExit = if (retry.ran) { retry.exitCode } else { first.exitCode }
    let ok = dependencyBlockers.size == 0 && first.ran && finalExit == 0
    let verbose = config.verbose
    var receiptWritten = false

    var status = "execution-disabled"
    if (!projectOk) {
        status = "project-not-supported-missing-cjpm"
    } else if (dependencyBlockers.size > 0) {
        status = "central-repository-dependency-blocked"
    } else if (!first.ran) {
        status = "execution-disabled"
    } else if (options.toolchainBootstrapAttempted && !options.toolchainBootstrapOk) {
        status = "toolchain-bootstrap-failed"
    } else if (options.toolchainBootstrapOk && finalExit == 0) {
        status = options.action + "-succeeded-after-toolchain-bootstrap"
    } else if (options.toolchainBootstrapOk) {
        status = options.action + "-failed-after-toolchain-bootstrap"
    } else if (first.exitCode == 127 && containsText(first.stderr, "missing required command: cjpm")) {
        status = "missing-cangjie-cjpm"
    } else if (first.exitCode == 0 && environmentRepairApplied) {
        status = options.action + "-succeeded-after-environment-repair"
    } else if (first.exitCode == 0) {
        status = options.action + "-succeeded"
    } else if (environmentRepairApplied && retry.ran && retry.exitCode == 0) {
        status = "retry-succeeded-after-environment-repair"
    } else if (environmentRepairApplied && retry.ran) {
        status = "retry-failed-after-environment-repair"
    } else if (environmentRepairApplied) {
        status = options.action + "-failed-after-environment-repair"
    } else if (options.action == "bundle") {
        status = "bundle-failed"
    } else if (!config.alwaysFix) {
        status = "build-failed-alwaysfix-disabled"
    } else if (profile.target.size == 0) {
        status = "build-failed-recorded-profile-not-found"
    } else if (repairApplied && retry.ran && retry.exitCode == 0) {
        status = "retry-succeeded-after-doctorfix"
    } else if (repairApplied && retry.ran) {
        status = "retry-failed-after-doctorfix"
    } else if (repairApplied) {
        status = "doctorfix-applied-retry-not-run"
    } else {
        status = "doctorfix-not-applied"
    }

    let bodyWithoutReceipt = buildReceiptBody(
        options,
        config,
        profile,
        first,
        retry,
        repairApplied,
        injectedResults,
        project,
        manifest,
        receiptPath,
        ok,
        status,
        verbose,
        false,
        environment,
        environmentRepairApplied,
        environmentRepairStage,
        dependencyBlockers
    )

    if (canWrite && projectOk) {
        let receiptDir = parentPath(receiptPath)
        if (receiptDir.size > 0 && !exists(receiptDir)) {
            Directory.create(receiptDir, recursive: true)
        }
        File.writeTo(receiptPath, bodyWithoutReceipt.toArray())
        receiptWritten = true
    }

    buildReceiptBody(
        options,
        config,
        profile,
        first,
        retry,
        repairApplied,
        injectedResults,
        project,
        manifest,
        receiptPath,
        ok,
        status,
        verbose,
        receiptWritten,
        environment,
        environmentRepairApplied,
        environmentRepairStage,
        dependencyBlockers
    )
}

func buildReceiptBody(
    options: HapBuildOptions,
    config: HapBuildConfig,
    profile: HapStdxProfile,
    first: HapBuildCommandResult,
    retry: HapBuildCommandResult,
    repairApplied: Bool,
    injectedResults: Bool,
    project: String,
    manifest: String,
    receiptPath: String,
    ok: Bool,
    status: String,
    verbose: Bool,
    receiptWritten: Bool,
    environment: HapCjpmEnvironmentPlan,
    environmentRepairApplied: Bool,
    environmentRepairStage: String,
    dependencyBlockers: Array<HapCentralDependencyBlocker>
): String {
    let backupPath = manifest + ".hap-backup"
    let out = StringBuilder()
    out.append("{\n")
    let schema = if (options.action == "build") { "happub-hapcli-build-wrapper-v0" } else { "happub-hapcli-cjpm-execution-v1" }
    out.append("  \"schema\": \"" + schema + "\",\n")
    out.append("  \"executionSchema\": \"happub-hapcli-cjpm-execution-v1\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"fixed-cjpm-execution-with-bounded-diagnostics\",\n")
    out.append("  \"action\": \"" + escapeJson(options.action) + "\",\n")
    out.append("  \"project\": \"" + escapeJson(project) + "\",\n")
    out.append("  \"manifest\": \"" + escapeJson(manifest) + "\",\n")
    out.append("  \"configPath\": \"" + escapeJson(config.path) + "\",\n")
    out.append("  \"configPathSource\": \"" + escapeJson(config.pathSource) + "\",\n")
    out.append("  \"configExists\": " + boolJson(config.exists) + ",\n")
    out.append("  \"target\": \"" + escapeJson(options.target) + "\",\n")
    out.append("  \"requestedTarget\": \"" + escapeJson(options.requestedTarget) + "\",\n")
    out.append("  \"cjpmTarget\": \"" + escapeJson(buildCjpmTargetArg(options, profile.sourceTarget)) + "\",\n")
    out.append("  \"skipLint\": " + boolJson(options.skipLint) + ",\n")
    out.append("  \"alwaysFix\": " + boolJson(config.alwaysFix) + ",\n")
    out.append("  \"verbose\": " + boolJson(verbose) + ",\n")
    out.append("  \"networkMode\": \"" + escapeJson(normalizeHapNetworkMode(options.networkMode)) + "\",\n")
    out.append("  \"proxyEnvironmentInherited\": " + boolJson(normalizeHapNetworkMode(options.networkMode) == "proxy") + ",\n")
    out.append("  \"proxyEnvironmentCleared\": " + boolJson(normalizeHapNetworkMode(options.networkMode) == "no-proxy") + ",\n")
    out.append("  \"environmentAutoFix\": " + boolJson(config.environmentAutoFix) + ",\n")
    out.append("  \"environmentDiagnosis\": \"" + escapeJson(environment.diagnosis) + "\",\n")
    out.append("  \"environmentStalePathDetected\": " + boolJson(environment.stalePathDetected) + ",\n")
    out.append("  \"environmentCandidateVerified\": " + boolJson(environment.candidateVerified) + ",\n")
    out.append("  \"environmentCandidatePath\": \"" + escapeJson(environment.candidatePath) + "\",\n")
    out.append("  \"environmentSdkRootBefore\": \"" + escapeJson(environment.sdkRootBefore) + "\",\n")
    out.append("  \"environmentSdkRootDriftDetected\": " + boolJson(environment.sdkRootDriftDetected) + ",\n")
    out.append("  \"environmentSdkRootCandidate\": \"" + escapeJson(environment.sdkRootCandidate) + "\",\n")
    out.append("  \"environmentSdkRootCandidateVerified\": " + boolJson(environment.sdkRootCandidateVerified) + ",\n")
    out.append("  \"environmentSdkRootRepairAvailable\": " + boolJson(environment.sdkRootRepairAvailable) + ",\n")
    out.append("  \"environmentRepairApplied\": " + boolJson(environmentRepairApplied) + ",\n")
    out.append("  \"environmentRepairStage\": \"" + escapeJson(environmentRepairStage) + "\",\n")
    out.append("  \"environmentMutationScope\": \"child-process-only\",\n")
    out.append("  \"toolchainAutoBootstrap\": " + boolJson(config.toolchainAutoBootstrap) + ",\n")
    out.append("  \"toolchainBootstrapAttempted\": " + boolJson(options.toolchainBootstrapAttempted) + ",\n")
    out.append("  \"toolchainBootstrapOk\": " + boolJson(options.toolchainBootstrapOk) + ",\n")
    out.append("  \"toolchainBootstrapStatus\": \"" + escapeJson(options.toolchainBootstrapStatus) + "\",\n")
    out.append("  \"toolchainBootstrapVersion\": \"" + escapeJson(options.toolchainBootstrapVersion) + "\",\n")
    out.append("  \"toolchainBootstrapSdkPlatform\": \"" + escapeJson(options.toolchainBootstrapSdkPlatform) + "\",\n")
    out.append("  \"toolchainBootstrapStdxPlatform\": \"" + escapeJson(options.toolchainBootstrapStdxPlatform) + "\",\n")
    out.append("  \"toolchainBootstrapCacheRoot\": \"" + escapeJson(options.toolchainBootstrapCacheRoot) + "\",\n")
    out.append("  \"toolchainBootstrapCacheRootSource\": \"" + escapeJson(options.toolchainBootstrapCacheRootSource) + "\",\n")
    out.append("  \"toolchainBootstrapManifestPath\": \"" + escapeJson(options.toolchainBootstrapManifestPath) + "\",\n")
    out.append("  \"toolchainBootstrapManifestUrl\": \"" + escapeJson(options.toolchainBootstrapManifestUrl) + "\",\n")
    out.append("  \"toolchainBootstrapSdkAsset\": \"" + escapeJson(options.toolchainBootstrapSdkAsset) + "\",\n")
    out.append("  \"toolchainBootstrapSdkSha256\": \"" + escapeJson(options.toolchainBootstrapSdkSha256) + "\",\n")
    out.append("  \"toolchainBootstrapStdxAsset\": \"" + escapeJson(options.toolchainBootstrapStdxAsset) + "\",\n")
    out.append("  \"toolchainBootstrapStdxSha256\": \"" + escapeJson(options.toolchainBootstrapStdxSha256) + "\",\n")
    out.append("  \"toolchainBootstrapDownloadSource\": \"" + escapeJson(options.toolchainBootstrapDownloadSource) + "\",\n")
    out.append("  \"toolchainBootstrapDownloadActionTaken\": " + boolJson(options.toolchainBootstrapDownloadActionTaken) + ",\n")
    out.append("  \"toolchainBootstrapChecksumVerified\": " + boolJson(options.toolchainBootstrapChecksumVerified) + ",\n")
    out.append("  \"toolchainBootstrapInstallActionTaken\": " + boolJson(options.toolchainBootstrapInstallActionTaken) + ",\n")
    out.append("  \"toolchainBootstrapCacheHit\": " + boolJson(options.toolchainBootstrapCacheHit) + ",\n")
    out.append("  \"toolchainBootstrapDiagnostic\": \"" + escapeJson(options.toolchainBootstrapDiagnostic) + "\",\n")
    out.append("  \"staleEnvironmentPaths\": ")
    appendReviewedJsonStringArray(out, environment.stalePaths)
    out.append(",\n")
    out.append("  \"firstBuildRan\": " + boolJson(first.ran) + ",\n")
    out.append("  \"firstBuildExitCode\": " + first.exitCode.toString() + ",\n")
    out.append("  \"recordedProfileFound\": " + boolJson(profile.target.size > 0) + ",\n")
    out.append("  \"doctorfixAttempted\": " + boolJson(first.ran && first.exitCode != 0 && config.alwaysFix) + ",\n")
    out.append("  \"doctorfixApplied\": " + boolJson(repairApplied) + ",\n")
    out.append("  \"retryBuildRan\": " + boolJson(retry.ran) + ",\n")
    out.append("  \"retryBuildExitCode\": " + retry.exitCode.toString() + ",\n")
    out.append("  \"finalExitCode\": " + (if (retry.ran) { retry.exitCode } else { first.exitCode }).toString() + ",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"dependencyBlockers\": ")
    appendCentralDependencyBlockersJson(out, dependencyBlockers)
    out.append(",\n")
    out.append("  \"primaryDependencyBlocker\": \"" + escapeJson(if (dependencyBlockers.size > 0) { dependencyBlockers[0].name } else { "" }) + "\",\n")
    out.append("  \"releaseOrder\": ")
    appendCentralReleaseOrderJson(out, dependencyBlockers, cjpmManifestPackageName(manifest), cjpmManifestPackageVersion(manifest))
    out.append(",\n")
    out.append("  \"toolchainStatus\": \"" + escapeJson(if (options.toolchainBootstrapOk) { "bootstrap-provided-cangjie-toolchain" } else if (status == "missing-cangjie-cjpm") { "missing-cangjie-cjpm" } else { projectToolchainStatus("cangjie", "build", project, "auto", HapHarmonyAdapterConfig()) }) + "\",\n")
    out.append("  \"toolchainQuestions\": ")
    appendReviewedJsonStringArray(out, buildToolchainQuestions(status, options.toolchainBootstrapOk))
    out.append(",\n")
    out.append("  \"toolchainValidationCommands\": ")
    appendReviewedJsonStringArray(out, projectToolchainValidationCommands("cangjie", "build", project, "auto", HapHarmonyAdapterConfig()))
    out.append(",\n")
    out.append("  \"backupPath\": \"" + escapeJson(backupPath) + "\",\n")
    out.append("  \"receiptPath\": \"" + escapeJson(receiptPath) + "\",\n")
    out.append("  \"receiptWritten\": " + boolJson(receiptWritten) + ",\n")
    out.append("  \"filesChanged\": " + boolJson(repairApplied) + ",\n")
    out.append("  \"injectedResults\": " + boolJson(injectedResults) + ",\n")
    out.append("  \"stdoutBytes\": " + first.stdout.size.toString() + ",\n")
    out.append("  \"stderrBytes\": " + first.stderr.size.toString() + ",\n")
    out.append("  \"retryStdoutBytes\": " + retry.stdout.size.toString() + ",\n")
    out.append("  \"retryStderrBytes\": " + retry.stderr.size.toString() + ",\n")
    if (verbose) {
        out.append("  \"firstStdout\": \"" + escapeJson(first.stdout) + "\",\n")
        out.append("  \"firstStderr\": \"" + escapeJson(first.stderr) + "\",\n")
        out.append("  \"retryStdout\": \"" + escapeJson(retry.stdout) + "\",\n")
        out.append("  \"retryStderr\": \"" + escapeJson(retry.stderr) + "\",\n")
    }
    out.append("  \"rollbackHint\": \"copy backupPath back to manifest if doctorfixApplied=true and rollback is needed\",\n")
    out.append("  \"nextAllowed\": ")
    appendCjpmExecutionNextAllowed(out, options.action, dependencyBlockers)
    out.append(",\n")
    out.append("  \"nonPromises\": [\"fixed CJPM actions only; no arbitrary shell or argv\", \"toolchain bootstrap writes only Hap private cache and never mutates shell profiles or the parent process\", \"public accelerators are transport candidates and never checksum authorities\", \"Cangjie SDK and stdx bootstrap does not install or prove the OpenHarmony native sysroot\", \"central dependency diagnosis never rewrites cjpm.toml automatically\", \"at most one build retry follows a classified repair\", \"command success does not certify publication or release readiness\"]\n")
    out.append("}")
    out.toString()
}

func buildToolchainQuestions(status: String, bootstrapProvided: Bool): ArrayList<String> {
    if (bootstrapProvided) {
        return ArrayList<String>()
    }
    let questions = projectToolchainQuestions("cangjie", "build", ".", "auto", HapHarmonyAdapterConfig())
    if (status == "missing-cangjie-cjpm" && questions.size == 0) {
        questions.add("请提供 cjpm 所在路径并放入 PATH；HapCLI 当前按固定 cjpm build/test 调用，不接收任意 shell。")
    }
    questions
}

func buildCjpmTargetArg(options: HapBuildOptions, profileSourceTarget: String): String {
    if (profileSourceTarget.size > 0) {
        return profileSourceTarget
    }
    if (options.requestedTarget.size > 0) {
        return cangjieTargetTripleForTarget(options.target)
    }
    cangjieTargetTripleForTarget(options.target)
}

func buildWorkingDirectory(project: String): String {
    let base = if (project.size > 0) { trimTrailingSlash(project) } else { "." }
    if (base.endsWith("cjpm.toml")) {
        let parent = parentPath(base)
        return if (parent.size > 0) { parent } else { "." }
    }
    base
}

func buildReceiptPath(project: String): String {
    let dir = if (project.endsWith("cjpm.toml")) { parentPath(project) } else { trimTrailingSlash(project) }
    let base = if (dir.size > 0) { dir } else { "." }
    base + "/.hapData/receipts/build-cangjie-stdx.json"
}

func readTomlBool(text: String, key: String): Bool {
    readTomlBoolOr(text, key, false)
}

func readTomlBoolOr(text: String, key: String, fallback: Bool): Bool {
    for (line in text.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (startsWithText(trimmed, key + " ") || startsWithText(trimmed, key + "=")) {
            let equal = indexOfText(trimmed, "=")
            if (equal >= 0) {
                let rawValue = trimAsciiText(substringFrom(trimmed, equal + 1))
                let comment = indexOfText(rawValue, "#")
                let value = trimAsciiText(if (comment >= 0) { substringTo(rawValue, comment) } else { rawValue })
                if (value == "true") {
                    return true
                }
                if (value == "false") {
                    return false
                }
                return fallback
            }
        }
    }
    fallback
}

func readTomlString(text: String, key: String): String {
    for (line in text.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (startsWithText(trimmed, key + " ") || startsWithText(trimmed, key + "=")) {
            let equal = indexOfText(trimmed, "=")
            if (equal >= 0) {
                return extractQuotedValue(substringFrom(trimmed, equal + 1))
            }
        }
    }
    ""
}

func cjpmExecutionReceiptPath(project: String, action: String): String {
    if (action == "build") {
        return buildReceiptPath(project)
    }
    let dir = if (project.endsWith("cjpm.toml")) { parentPath(project) } else { trimTrailingSlash(project) }
    let base = if (dir.size > 0) { dir } else { "." }
    base + "/.hapData/receipts/" + action + "-cangjie.json"
}

func appendCentralDependencyBlockersJson(out: StringBuilder, blockers: Array<HapCentralDependencyBlocker>): Unit {
    out.append("[")
    var i: Int64 = 0
    while (i < blockers.size) {
        if (i > 0) {
            out.append(", ")
        }
        let blocker = blockers[i]
        out.append("{\"name\":\"" + escapeJson(blocker.name) + "\",\"sourceKind\":\"" + escapeJson(blocker.sourceKind) + "\",\"sourceValue\":\"" + escapeJson(blocker.sourceValue) + "\"}")
        i += 1
    }
    out.append("]")
}

func appendCentralReleaseOrderJson(
    out: StringBuilder,
    blockers: Array<HapCentralDependencyBlocker>,
    packageName: String,
    packageVersion: String
): Unit {
    out.append("[")
    var step: Int64 = 1
    var i: Int64 = 0
    while (i < blockers.size) {
        let blocker = blockers[i]
        if (step > 1) {
            out.append(", ")
        }
        appendCentralReleaseStep(out, step, "publish-and-verify-central-dependency", blocker.name, "")
        step += 1
        out.append(", ")
        appendCentralReleaseStep(out, step, "switch-consumer-to-version-dependency", blocker.name, "")
        step += 1
        i += 1
    }
    if (blockers.size > 0) {
        out.append(", ")
        appendCentralReleaseStep(out, step, "bundle-consumer", packageName, packageVersion)
    }
    out.append("]")
}

func appendCentralReleaseStep(out: StringBuilder, step: Int64, action: String, packageName: String, version: String): Unit {
    out.append("{\"step\":" + step.toString() + ",\"action\":\"" + escapeJson(action) + "\",\"package\":\"" + escapeJson(packageName) + "\"")
    if (version.size > 0) {
        out.append(",\"version\":\"" + escapeJson(version) + "\"")
    }
    out.append("}")
}

func appendCjpmExecutionNextAllowed(
    out: StringBuilder,
    action: String,
    blockers: Array<HapCentralDependencyBlocker>
): Unit {
    let moves = ArrayList<String>()
    if (blockers.size > 0) {
        moves.add("publish and verify each blocked dependency in the central repository")
        moves.add("replace each git/path dependency with an explicit central version")
        moves.add("rerun hap bundle after the dependency topology is central-repository compatible")
    } else if (action == "bundle") {
        moves.add("review the bundle receipt and generated package metadata")
        moves.add("publish only after central repository and package verification pass")
    } else {
        moves.add("review the build receipt")
        moves.add("run project tests before release or publication")
    }
    appendReviewedJsonStringArray(out, moves)
}
