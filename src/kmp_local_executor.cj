package hapcli

import std.env.getVariable
import std.fs.{Directory, File, Path, exists}
import std.process.executeWithOutput

class HapKmpJavaHomeResolution {
    var home: String = ""
    var source: String = "unresolved"

    init() {}
}

public func runKmpLocalDesktopDevExecution(options: HapProjectActionOptions): String {
    let project = trimTrailingSlash(options.project)
    let logDir = if (options.logDir.size > 0) {
        trimTrailingSlash(options.logDir)
    } else {
        project + "/.hapData/logs/kmp-dev"
    }
    if (!exists(logDir)) {
        Directory.create(logDir, recursive: true)
    }
    let stdoutLog = logDir + "/kmp-desktop-run.stdout.log"
    let stderrLog = logDir + "/kmp-desktop-run.stderr.log"
    File.writeTo(harmonyCurrentStepPath(logDir), "building and running KMP desktop application".toArray())

    let runner = if (exists(project + "/gradlew")) { "./gradlew" } else { "gradle" }
    let javaHome = resolveKmpJavaHome()
    if (!exists(project + "/gradlew") && !isProgramResolvable("gradle")) {
        return renderKmpLocalDesktopExecutionJson(options, false, "missing-kmp-gradle-runner", runner, 2, stdoutLog, stderrLog, logDir, javaHome)
    }
    let task = if (isKmpComposeAppProject(project)) { ":composeApp:run" } else { "run" }
    let args = [task, "--no-daemon", "-Dkotlin.compiler.execution.strategy=in-process"]
    let assignments = if (javaHome.home.size > 0) { ["JAVA_HOME=" + javaHome.home] } else { Array<String>() }
    let command = resolveHapNetworkCommandWithAssignments(options.networkMode, assignments, runner, args)
    let (exitCode, stdoutBytes, stderrBytes) = executeWithOutput(command.program, command.args.toArray(), workingDirectory: Path(project))
    File.writeTo(stdoutLog, stdoutBytes)
    File.writeTo(stderrLog, stderrBytes)
    File.writeTo(harmonyLastStepPath(logDir), "building and running KMP desktop application".toArray())
    let ok = exitCode == 0
    let status = if (ok) { "kmp-desktop-dev-succeeded" } else { "kmp-desktop-dev-failed" }
    renderKmpLocalDesktopExecutionJson(options, ok, status, runner + " " + task, exitCode, stdoutLog, stderrLog, logDir, javaHome)
}

func resolveKmpJavaHome(): HapKmpJavaHomeResolution {
    let resolution = HapKmpJavaHomeResolution()
    match (getVariable("JAVA_HOME")) {
        case Some(value) =>
            if (kmpJavaHomeIsValid(value)) {
                resolution.home = trimTrailingSlash(value)
                resolution.source = "process-env"
                return resolution
            }
        case None => ()
    }
    if (exists("/usr/libexec/java_home")) {
        let (exitCode, stdoutBytes, _) = executeWithOutput("/usr/libexec/java_home", ["-v", "17"])
        let candidate = trimAsciiText(String.fromUtf8(stdoutBytes))
        if (exitCode == 0 && kmpJavaHomeIsValid(candidate)) {
            resolution.home = trimTrailingSlash(candidate)
            resolution.source = "macos-java-home"
            return resolution
        }
    }
    if (isProgramResolvable("java")) {
        let (_, stdoutBytes, stderrBytes) = executeWithOutput("java", ["-XshowSettings:properties", "-version"])
        let candidate = extractJavaHomeProperty(String.fromUtf8(stdoutBytes) + "\n" + String.fromUtf8(stderrBytes))
        if (kmpJavaHomeIsValid(candidate)) {
            resolution.home = trimTrailingSlash(candidate)
            resolution.source = "java-properties"
        }
    }
    resolution
}

func kmpJavaHomeIsValid(home: String): Bool {
    let value = trimTrailingSlash(trimAsciiText(home))
    value.size > 0 && (exists(value + "/bin/java") || exists(value + "\\bin\\java.exe"))
}

func extractJavaHomeProperty(text: String): String {
    for (line in splitAsciiLines(text)) {
        let trimmed = trimAsciiText(line)
        if (startsWithText(trimmed, "java.home =")) {
            return trimAsciiText(substringFrom(trimmed, 11))
        }
    }
    ""
}

func renderKmpLocalDesktopExecutionJson(
    options: HapProjectActionOptions,
    ok: Bool,
    status: String,
    command: String,
    exitCode: Int64,
    stdoutLog: String,
    stderrLog: String,
    logDir: String,
    javaHome: HapKmpJavaHomeResolution
): String {
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-kmp-local-dev-execution-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"local-execution\",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"project\": \"" + escapeJson(options.project) + "\",\n")
    out.append("  \"platform\": \"kmp\",\n")
    out.append("  \"target\": \"desktop\",\n")
    out.append("  \"command\": \"" + escapeJson(command) + "\",\n")
    out.append("  \"javaHome\": \"" + escapeJson(javaHome.home) + "\",\n")
    out.append("  \"javaHomeSource\": \"" + escapeJson(javaHome.source) + "\",\n")
    out.append("  \"networkMode\": \"" + escapeJson(normalizeHapNetworkMode(options.networkMode)) + "\",\n")
    out.append("  \"proxyEnvironmentInherited\": " + boolJson(normalizeHapNetworkMode(options.networkMode) == "proxy") + ",\n")
    out.append("  \"proxyEnvironmentCleared\": " + boolJson(normalizeHapNetworkMode(options.networkMode) == "no-proxy") + ",\n")
    out.append("  \"exitCode\": " + exitCode.toString() + ",\n")
    out.append("  \"stdoutLog\": \"" + escapeJson(stdoutLog) + "\",\n")
    out.append("  \"stderrLog\": \"" + escapeJson(stderrLog) + "\",\n")
    out.append("  \"logDir\": \"" + escapeJson(logDir) + "\",\n")
    out.append("  \"diagnosis\": \"" + escapeJson(if (ok) { "KMP desktop application built and exited successfully" } else if (status == "missing-kmp-gradle-runner") { "provide project gradlew or install Gradle" } else { "KMP desktop Gradle run failed; inspect stderrLog and stdoutLog" }) + "\",\n")
    out.append("  \"nextManualCommands\": [\"cd " + escapeJson(options.project) + " && ./gradlew :composeApp:run --no-daemon\"]\n")
    out.append("}")
    out.toString()
}

public func renderKmpExecutionHumanSummary(json: String): String {
    let ok = containsJsonTrue(json, "ok")
    let status = extractFlatJsonString(json, "status")
    let diagnosis = extractFlatJsonString(json, "diagnosis")
    let logDir = extractFlatJsonString(json, "logDir")
    let out = StringBuilder()
    out.append(if (ok) { "Hap dev succeeded\n" } else { "Hap dev failed\n" })
    out.append("Target: KMP desktop\n")
    if (status.size > 0) {
        out.append("Status: " + status + "\n")
    }
    if (diagnosis.size > 0) {
        out.append("Diagnosis: " + diagnosis + "\n")
    }
    if (!ok && logDir.size > 0) {
        out.append("Logs: " + logDir + "\n")
    }
    out.append("Use -v or --verbose for the full execution JSON.")
    out.toString()
}
