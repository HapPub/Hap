package hapcli

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{File, exists}
import std.process.executeWithOutput

public class HapCjpmEnvironmentPlan {
    public var stalePathDetected: Bool = false
    public var repairAvailable: Bool = false
    public var candidateVerified: Bool = false
    public var candidatePath: String = ""
    public var sdkRootBefore: String = ""
    public var sdkRootCandidate: String = ""
    public var sdkRootDriftDetected: Bool = false
    public var sdkRootCandidateVerified: Bool = false
    public var sdkRootRepairAvailable: Bool = false
    public var diagnosis: String = "environment-no-known-drift"
    public var dyldBefore: String = ""
    public var libraryBefore: String = ""
    public var ldBefore: String = ""
    public let stalePaths: ArrayList<String> = ArrayList<String>()
    public let assignments: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class HapCentralDependencyBlocker {
    public var name: String = ""
    public var sourceKind: String = "unknown"
    public var sourceValue: String = ""

    public init() {}
}

public func inspectCurrentCjpmEnvironment(configuredOpenSslLib: String): HapCjpmEnvironmentPlan {
    inspectCjpmEnvironmentValuesWithSdkRoot(
        readCjpmEnvironmentVariable("DYLD_LIBRARY_PATH"),
        readCjpmEnvironmentVariable("LIBRARY_PATH"),
        readCjpmEnvironmentVariable("LD_LIBRARY_PATH"),
        readCjpmEnvironmentVariable("SDKROOT"),
        discoverMacOsSdkRoot(),
        configuredOpenSslLib
    )
}

public func inspectCjpmEnvironmentValues(
    dyld: String,
    library: String,
    ld: String,
    configuredOpenSslLib: String
): HapCjpmEnvironmentPlan {
    inspectCjpmEnvironmentValuesInternal(dyld, library, ld, "", "", configuredOpenSslLib, false)
}

public func inspectCjpmEnvironmentValuesWithSdkRoot(
    dyld: String,
    library: String,
    ld: String,
    sdkRootBefore: String,
    sdkRootCandidate: String,
    configuredOpenSslLib: String
): HapCjpmEnvironmentPlan {
    inspectCjpmEnvironmentValuesInternal(dyld, library, ld, sdkRootBefore, sdkRootCandidate, configuredOpenSslLib, true)
}

func inspectCjpmEnvironmentValuesInternal(
    dyld: String,
    library: String,
    ld: String,
    sdkRootBefore: String,
    sdkRootCandidate: String,
    configuredOpenSslLib: String,
    inspectSdkRoot: Bool
): HapCjpmEnvironmentPlan {
    let plan = HapCjpmEnvironmentPlan()
    plan.dyldBefore = dyld
    plan.libraryBefore = library
    plan.ldBefore = ld
    collectStaleOpenSslPaths(plan, dyld)
    collectStaleOpenSslPaths(plan, library)
    collectStaleOpenSslPaths(plan, ld)
    plan.stalePathDetected = plan.stalePaths.size > 0
    plan.candidatePath = resolveStableOpenSslLib(configuredOpenSslLib)
    plan.candidateVerified = verifyOpenSslLibDirectory(plan.candidatePath)
    let opensslRepairAvailable = plan.candidateVerified && plan.stalePathDetected
    let sdkRootRelevant = inspectSdkRoot && (plan.sdkRootCandidate.size > 0 || plan.sdkRootBefore.size > 0 || exists("/usr/bin/xcrun"))
    if (sdkRootRelevant) {
        plan.sdkRootBefore = trimAsciiText(sdkRootBefore)
        plan.sdkRootCandidate = trimAsciiText(sdkRootCandidate)
        plan.sdkRootDriftDetected = !verifyMacOsSdkRoot(plan.sdkRootBefore)
        plan.sdkRootCandidateVerified = verifyMacOsSdkRoot(plan.sdkRootCandidate)
        plan.sdkRootRepairAvailable = plan.sdkRootDriftDetected && plan.sdkRootCandidateVerified
        if (plan.sdkRootRepairAvailable) {
            plan.assignments.add("SDKROOT=" + plan.sdkRootCandidate)
        }
    }
    plan.repairAvailable = opensslRepairAvailable || plan.sdkRootRepairAvailable

    if (opensslRepairAvailable && plan.sdkRootRepairAvailable) {
        plan.diagnosis = "openssl-and-macos-sdkroot-repair-ready"
        appendOpenSslEnvironmentAssignments(plan)
    } else if (opensslRepairAvailable) {
        plan.diagnosis = "stale-openssl-cellar-path-repair-ready"
        appendOpenSslEnvironmentAssignments(plan)
    } else if (plan.sdkRootRepairAvailable) {
        plan.diagnosis = "missing-or-invalid-macos-sdkroot-repair-ready"
    } else if (plan.stalePathDetected) {
        plan.diagnosis = "stale-openssl-cellar-path-no-verified-replacement"
    } else if (plan.sdkRootDriftDetected && sdkRootRelevant) {
        plan.diagnosis = "missing-or-invalid-macos-sdkroot-no-verified-replacement"
    } else if (plan.candidateVerified) {
        plan.diagnosis = "stable-openssl-candidate-available"
        appendOpenSslEnvironmentAssignments(plan)
    }
    plan
}

func discoverMacOsSdkRoot(): String {
    if (!isProgramResolvable("xcrun")) {
        return ""
    }
    let (exitCode, stdoutBytes, _) = executeWithOutput("xcrun", ["--show-sdk-path"])
    if (exitCode != 0) {
        return ""
    }
    trimAsciiText(String.fromUtf8(stdoutBytes))
}

func verifyMacOsSdkRoot(path: String): Bool {
    let normalized = trimAsciiText(path)
    normalized.size > 0 && exists(normalized) &&
        exists(normalized + "/usr/lib/libSystem.tbd") &&
        exists(normalized + "/usr/lib/libc++.tbd")
}

public func cjpmFailureLooksLikeCryptoEnvironmentDrift(result: HapBuildCommandResult): Bool {
    if (!result.ran || result.exitCode == 0) {
        return false
    }
    let text = result.stdout + "\n" + result.stderr
    result.exitCode == 134 ||
        containsText(text, "SIGABRT") || containsText(text, "sigabrt") ||
        containsText(text, "stdx.crypto.digest.SHA256") || containsText(text, "stdx.crypto.digest.sha256") ||
        containsText(text, "loading libcrypto in an unsafe way") ||
        containsText(text, "libcrypto") && (containsText(text, "unsafe") || containsText(text, "Unsafe"))
}

public func centralDependencyBlockers(manifestPath: String): Array<HapCentralDependencyBlocker> {
    if (!exists(manifestPath)) {
        return []
    }
    let blockers = ArrayList<HapCentralDependencyBlocker>()
    let text = String.fromUtf8(File.readFrom(manifestPath))
    var inDependencies = false
    var pendingName = ""
    var pendingValue = ""
    var pendingBlocked = false
    for (line in text.split("\n")) {
        let trimmed = trimAsciiText(line)
        if (trimmed == "[dependencies]") {
            inDependencies = true
            pendingName = ""
            pendingValue = ""
            pendingBlocked = false
            continue
        }
        if (startsWithText(trimmed, "[") && trimmed != "[dependencies]") {
            inDependencies = false
            pendingName = ""
            pendingValue = ""
            pendingBlocked = false
        }
        if (!inDependencies || trimmed.size == 0 || startsWithText(trimmed, "#")) {
            continue
        }
        if (pendingName.size > 0) {
            pendingValue += " " + trimmed
            if (!pendingBlocked) {
                let sourceKind = dependencySourceKind(pendingValue)
                if (sourceKind.size > 0) {
                    addCentralDependencyBlocker(blockers, pendingName, sourceKind, dependencySourceValue(pendingValue, sourceKind))
                    pendingBlocked = true
                }
            }
            if (containsText(trimmed, "}")) {
                pendingName = ""
                pendingValue = ""
                pendingBlocked = false
            }
            continue
        }
        let equal = indexOfText(trimmed, "=")
        if (equal <= 0) {
            continue
        }
        let name = trimAsciiText(substringTo(trimmed, equal))
        let value = trimAsciiText(substringFrom(trimmed, equal + 1))
        let sourceKind = dependencySourceKind(value)
        if (sourceKind.size > 0) {
            addCentralDependencyBlocker(blockers, name, sourceKind, dependencySourceValue(value, sourceKind))
        } else if (startsWithText(value, "{") && !containsText(value, "}")) {
            pendingName = name
            pendingValue = value
            pendingBlocked = false
        }
    }
    blockers.toArray()
}

func dependencySourceKind(text: String): String {
    if (tomlAssignmentValueStart(text, "git") >= 0) {
        return "git"
    }
    if (tomlAssignmentValueStart(text, "path") >= 0) {
        return "path"
    }
    ""
}

func dependencySourceValue(text: String, sourceKind: String): String {
    let start = tomlAssignmentValueStart(text, sourceKind)
    if (start < 0) {
        return ""
    }
    extractQuotedValue(substringFrom(text, start))
}

func tomlAssignmentValueStart(text: String, key: String): Int64 {
    let spaced = key + " ="
    let spacedIndex = indexOfText(text, spaced)
    if (spacedIndex >= 0) {
        return spacedIndex + spaced.size
    }
    let compact = key + "="
    let compactIndex = indexOfText(text, compact)
    if (compactIndex >= 0) {
        return compactIndex + compact.size
    }
    -1
}

func addCentralDependencyBlocker(
    blockers: ArrayList<HapCentralDependencyBlocker>,
    name: String,
    sourceKind: String,
    sourceValue: String
): Unit {
    let blocker = HapCentralDependencyBlocker()
    blocker.name = name
    blocker.sourceKind = sourceKind
    blocker.sourceValue = sourceValue
    blockers.add(blocker)
}

public func cjpmManifestPackageName(manifestPath: String): String {
    readPackageScalar(manifestPath, "name")
}

public func cjpmManifestPackageVersion(manifestPath: String): String {
    readPackageScalar(manifestPath, "version")
}

public func renderCjpmExecutionHumanSummary(json: String): String {
    let ok = containsText(json, "\"ok\": true")
    let action = extractFlatJsonString(json, "action")
    let status = extractFlatJsonString(json, "status")
    let repaired = containsText(json, "\"environmentRepairApplied\": true")
    let candidate = extractFlatJsonString(json, "environmentCandidatePath")
    let sdkRoot = extractFlatJsonString(json, "environmentSdkRootCandidate")
    let blocker = extractFlatJsonString(json, "primaryDependencyBlocker")
    let filesChanged = containsText(json, "\"filesChanged\": true")
    let out = StringBuilder()
    out.append(if (ok) { "Hap " + action + " succeeded" } else { "Hap " + action + " failed" })
    out.append("\nStatus: " + status)
    if (repaired) {
        out.append("\nEnvironment: repaired for this CJPM child process only")
        if (candidate.size > 0) {
            out.append("\nOpenSSL: " + candidate)
        }
        if (sdkRoot.size > 0) {
            out.append("\nSDKROOT: " + sdkRoot)
        }
    }
    if (blocker.size > 0) {
        out.append("\nCentral dependency blocker: " + blocker)
        out.append("\nRequired order: publish and verify " + blocker + " in the central repository, switch the consumer to a version dependency, then rerun Hap bundle")
    }
    out.append("\nFiles changed: " + if (filesChanged) { "yes" } else { "no" })
    if (!ok && blocker.size == 0) {
        out.append("\nUse -v or --verbose for the structured diagnosis and original CJPM output.")
    } else if (blocker.size > 0) {
        out.append("\nHap did not rewrite cjpm.toml.")
    }
    out.toString()
}

func collectStaleOpenSslPaths(plan: HapCjpmEnvironmentPlan, raw: String): Unit {
    for (path in raw.split(":")) {
        let normalized = trimAsciiText(path)
        if (normalized.size == 0 || exists(normalized)) {
            continue
        }
        if (containsText(normalized, "/Cellar/openssl@3/") || containsText(normalized, "/Cellar/openssl/")) {
            addUniqueCjpmText(plan.stalePaths, normalized)
        }
    }
}

func resolveStableOpenSslLib(configured: String): String {
    let candidates = ArrayList<String>()
    addUniqueCjpmText(candidates, trimAsciiText(configured))
    addUniqueCjpmText(candidates, readCjpmEnvironmentVariable("HAP_OPENSSL_STABLE_LIB"))
    addUniqueCjpmText(candidates, "/opt/homebrew/opt/openssl@3/lib")
    addUniqueCjpmText(candidates, "/usr/local/opt/openssl@3/lib")
    addUniqueCjpmText(candidates, "/opt/homebrew/opt/openssl/lib")
    addUniqueCjpmText(candidates, "/usr/local/opt/openssl/lib")
    for (candidate in candidates) {
        if (verifyOpenSslLibDirectory(candidate)) {
            return candidate
        }
    }
    ""
}

func verifyOpenSslLibDirectory(path: String): Bool {
    if (path.size == 0 || !exists(path)) {
        return false
    }
    exists(path + "/libcrypto.dylib") || exists(path + "/libcrypto.3.dylib") ||
        exists(path + "/libcrypto.so") || exists(path + "/libcrypto.so.3")
}

func appendOpenSslEnvironmentAssignments(plan: HapCjpmEnvironmentPlan): Unit {
    let dyld = repairedLibraryPath(plan.candidatePath, plan.dyldBefore)
    let library = repairedLibraryPath(plan.candidatePath, plan.libraryBefore)
    let ld = repairedLibraryPath(plan.candidatePath, plan.ldBefore)
    if (exists(plan.candidatePath + "/libcrypto.dylib") || exists(plan.candidatePath + "/libcrypto.3.dylib")) {
        plan.assignments.add("DYLD_LIBRARY_PATH=" + dyld)
    }
    if (exists(plan.candidatePath + "/libcrypto.so") || exists(plan.candidatePath + "/libcrypto.so.3")) {
        plan.assignments.add("LD_LIBRARY_PATH=" + ld)
    }
    plan.assignments.add("LIBRARY_PATH=" + library)
}

func repairedLibraryPath(candidate: String, raw: String): String {
    let parts = ArrayList<String>()
    addUniqueCjpmText(parts, candidate)
    for (path in raw.split(":")) {
        let normalized = trimAsciiText(path)
        if (normalized.size == 0 || normalized == candidate) {
            continue
        }
        if (!exists(normalized) && (containsText(normalized, "/Cellar/openssl@3/") || containsText(normalized, "/Cellar/openssl/"))) {
            continue
        }
        addUniqueCjpmText(parts, normalized)
    }
    joinCjpmText(parts, ":")
}

func readPackageScalar(manifestPath: String, key: String): String {
    if (!exists(manifestPath)) {
        return ""
    }
    var inPackage = false
    for (line in String.fromUtf8(File.readFrom(manifestPath)).split("\n")) {
        let trimmed = trimAsciiText(line)
        if (trimmed == "[package]") {
            inPackage = true
            continue
        }
        if (startsWithText(trimmed, "[") && trimmed != "[package]") {
            inPackage = false
        }
        if (inPackage) {
            let equal = indexOfText(trimmed, "=")
            if (equal > 0 && trimAsciiText(substringTo(trimmed, equal)) == key) {
                return extractQuotedValue(substringFrom(trimmed, equal + 1))
            }
        }
    }
    ""
}

func extractInlineTomlValue(text: String, key: String): String {
    let marker = key + " ="
    let index = indexOfText(text, marker)
    if (index < 0) {
        return ""
    }
    extractQuotedValue(substringFrom(text, index + marker.size))
}

func readCjpmEnvironmentVariable(name: String): String {
    match (getVariable(name)) {
        case Some(value) => trimAsciiText(value)
        case None => ""
    }
}

func addUniqueCjpmText(items: ArrayList<String>, value: String): Unit {
    let normalized = trimAsciiText(value)
    if (normalized.size == 0) {
        return
    }
    for (existing in items) {
        if (existing == normalized) {
            return
        }
    }
    items.add(normalized)
}

func joinCjpmText(items: ArrayList<String>, separator: String): String {
    let out = StringBuilder()
    var index: Int64 = 0
    while (index < items.size) {
        if (index > 0) {
            out.append(separator)
        }
        out.append(items[index])
        index += 1
    }
    out.toString()
}
