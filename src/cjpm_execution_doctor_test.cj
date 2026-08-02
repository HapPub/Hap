package hapcli

import std.fs.{Directory, File, exists}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class HapCjpmExecutionDoctorTest {
    @TestCase
    public func preparesVerifiedChildEnvironmentForStaleCellarPath(): Unit {
        let stable = "/tmp/hapcli-environment-repair-openssl/lib"
        if (!exists(stable)) {
            Directory.create(stable, recursive: true)
        }
        File.writeTo(stable + "/libcrypto.dylib", "fixture".toArray())
        let stale = "/tmp/hapcli-environment-repair/Cellar/openssl@3/3.6.1/lib"

        let plan = inspectCjpmEnvironmentValues(stale, stale, "", stable)

        @Assert(plan.stalePathDetected, true)
        @Assert(plan.repairAvailable, true)
        @Assert(plan.candidateVerified, true)
        @Assert(plan.candidatePath, stable)
        @Assert(plan.diagnosis, "stale-openssl-cellar-path-repair-ready")
        @Assert(cjpmDoctorAssignmentsText(plan).contains("DYLD_LIBRARY_PATH=" + stable), true)
        @Assert(cjpmDoctorAssignmentsText(plan).contains("LIBRARY_PATH=" + stable), true)
        @Assert(cjpmDoctorAssignmentsText(plan).contains("3.6.1"), false)
    }

    @TestCase
    public func classifiesKnownCryptoChecksumAbort(): Unit {
        let result = HapBuildCommandResult(
            134,
            "",
            "cjpm is loading libcrypto in an unsafe way during stdx.crypto.digest.SHA256"
        )

        @Assert(cjpmFailureLooksLikeCryptoEnvironmentDrift(result), true)
        @Assert(cjpmFailureLooksLikeCryptoEnvironmentDrift(HapBuildCommandResult(1, "compile error", "")), false)
    }

    @TestCase
    public func blocksGitAndPathDependenciesBeforeCentralBundle(): Unit {
        let root = "/tmp/hapcli-environment-repair-central-blocker"
        if (!exists(root)) {
            Directory.create(root, recursive: true)
        }
        File.writeTo(
            root + "/cjpm.toml",
            ("[package]\n" +
            "name = \"jinguissl_contract\"\n" +
            "version = \"0.7.7\"\n\n" +
            "[dependencies]\n" +
            "jinguissl_core = { git = \"https://gitcode.com/CjKu/JinguiCore.git\" }\n" +
            "local_helper = { path = \"../local-helper\" }\n" +
            "json = \"1.0.0\"\n").toArray()
        )

        let blockers = centralDependencyBlockers(root + "/cjpm.toml")
        @Assert(blockers.size, Int64(2))
        @Assert(blockers[0].name, "jinguissl_core")
        @Assert(blockers[0].sourceKind, "git")
        @Assert(blockers[1].sourceKind, "path")

        let options = HapBuildOptions()
        options.action = "bundle"
        options.project = root
        let json = renderBuildJson(options, true, false)

        @Assert(json.contains("\"status\": \"central-repository-dependency-blocked\""), true)
        @Assert(json.contains("\"firstBuildRan\": false"), true)
        @Assert(json.contains("publish-and-verify-central-dependency"), true)
        @Assert(json.contains("switch-consumer-to-version-dependency"), true)
        @Assert(json.contains("\"package\":\"jinguissl_contract\""), true)
        @Assert(json.contains("\"version\":\"0.7.7\""), true)
    }

    @TestCase
    public func acceptsCentralVersionDependencyShape(): Unit {
        let root = "/tmp/hapcli-environment-repair-central-version"
        if (!exists(root)) {
            Directory.create(root, recursive: true)
        }
        File.writeTo(
            root + "/cjpm.toml",
            ("[package]\nname = \"consumer\"\nversion = \"1.0.0\"\n\n" +
            "[dependencies]\njinguissl_core = \"0.7.6\"\n").toArray()
        )

        @Assert(centralDependencyBlockers(root + "/cjpm.toml").size, Int64(0))
    }

    @TestCase
    public func blocksCompactAndMultilineDependencySources(): Unit {
        let root = "/tmp/hapcli-environment-repair-central-source-shapes"
        if (!exists(root)) {
            Directory.create(root, recursive: true)
        }
        File.writeTo(
            root + "/cjpm.toml",
            ("[package]\nname=\"consumer\"\nversion=\"1.0.0\"\n\n" +
            "[dependencies]\n" +
            "compact_git = {git=\"https://example.invalid/compact.git\"}\n" +
            "multiline_path = {\n" +
            "  path = \"../multiline-path\"\n" +
            "  version = \"1.0.0\"\n" +
            "}\n" +
            "central = \"1.2.3\"\n").toArray()
        )

        let blockers = centralDependencyBlockers(root + "/cjpm.toml")
        @Assert(blockers.size, Int64(2))
        @Assert(blockers[0].name, "compact_git")
        @Assert(blockers[0].sourceKind, "git")
        @Assert(blockers[0].sourceValue, "https://example.invalid/compact.git")
        @Assert(blockers[1].name, "multiline_path")
        @Assert(blockers[1].sourceKind, "path")
        @Assert(blockers[1].sourceValue, "../multiline-path")

        let options = HapBuildOptions()
        options.action = "bundle"
        options.project = root
        let json = renderBuildJson(options, true, false)
        @Assert(json.contains("\"package\":\"consumer\""), true)
        @Assert(json.contains("\"version\":\"1.0.0\""), true)
    }

    @TestCase
    public func ignoresTargetBinaryDependencyPaths(): Unit {
        let root = "/tmp/hapcli-environment-repair-bin-dependency-boundary"
        if (!exists(root)) {
            Directory.create(root, recursive: true)
        }
        File.writeTo(
            root + "/cjpm.toml",
            ("[package]\nname = \"consumer\"\nversion = \"1.0.0\"\n\n" +
            "[dependencies]\ncentral = \"1.2.3\"\n\n" +
            "[target.aarch64-apple-darwin.bin-dependencies]\n" +
            "path-option = [\"/opt/cangjie-stdx/darwin/static/stdx\"]\n").toArray()
        )

        @Assert(centralDependencyBlockers(root + "/cjpm.toml").size, Int64(0))
    }

    @TestCase
    public func rendersHumanSummaryWithoutClaimingManifestRewrite(): Unit {
        let json = "{\"ok\":false,\"action\":\"bundle\",\"status\":\"central-repository-dependency-blocked\",\"primaryDependencyBlocker\":\"jinguissl_core\",\"filesChanged\":false}"
        let summary = renderCjpmExecutionHumanSummary(json)

        @Assert(summary.contains("Hap bundle failed"), true)
        @Assert(summary.contains("Central dependency blocker: jinguissl_core"), true)
        @Assert(summary.contains("Hap did not rewrite cjpm.toml."), true)
    }

    @TestCase
    public func preservesProxyModeWhenAddingChildEnvironmentAssignments(): Unit {
        let command = resolveHapNetworkCommandWithAssignments(
            "proxy",
            ["LIBRARY_PATH=/stable/lib"],
            "cjpm",
            ["bundle"]
        )
        let args = cjpmDoctorCommandArgsText(command)

        @Assert(command.program.endsWith("env"), true)
        @Assert(args.contains("LIBRARY_PATH=/stable/lib"), true)
        @Assert(args.contains("-u"), false)
        @Assert(args.contains("cjpm"), true)
        @Assert(args.contains("bundle"), true)
    }

    @TestCase
    public func explicitCliEnvironmentFlagOverridesConfigDefault(): Unit {
        let root = "/tmp/hapcli-environment-repair-config-override"
        if (!exists(root)) {
            Directory.create(root, recursive: true)
        }
        let configPath = root + "/happub.toml"
        File.writeTo(configPath, "environmentAutoFix = false\n".toArray())

        let configured = HapBuildOptions()
        configured.project = root
        configured.configPath = configPath
        let configuredJson = renderBuildJsonFromResults(
            configured,
            false,
            HapBuildCommandResult(0, "", ""),
            HapBuildCommandResult()
        )
        @Assert(configuredJson.contains("\"environmentAutoFix\": false"), true)

        configured.environmentAutoFix = true
        configured.environmentAutoFixExplicit = true
        let overriddenJson = renderBuildJsonFromResults(
            configured,
            false,
            HapBuildCommandResult(0, "", ""),
            HapBuildCommandResult()
        )
        @Assert(overriddenJson.contains("\"environmentAutoFix\": true"), true)
    }
}

func cjpmDoctorAssignmentsText(plan: HapCjpmEnvironmentPlan): String {
    let out = StringBuilder()
    for (assignment in plan.assignments) {
        out.append(assignment + "\n")
    }
    out.toString()
}

func cjpmDoctorCommandArgsText(command: HapNetworkCommand): String {
    let out = StringBuilder()
    for (arg in command.args) {
        out.append(arg + "\n")
    }
    out.toString()
}
