package hapcli

import std.fs.{Directory, File, exists}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class HapRuntimeTruthRegressionTest {
    @TestCase
    public func sdkRootRepairUsesOnlyVerifiedMacOsSdk(): Unit {
        let sdkRoot = "/tmp/hapcli-runtime-truth-sdkroot/MacOSX.sdk"
        let sdkLib = sdkRoot + "/usr/lib"
        if (!exists(sdkLib)) {
            Directory.create(sdkLib, recursive: true)
        }
        File.writeTo(sdkLib + "/libSystem.tbd", "fixture".toArray())
        File.writeTo(sdkLib + "/libc++.tbd", "fixture".toArray())

        let plan = inspectCjpmEnvironmentValuesWithSdkRoot("", "", "", "", sdkRoot, "")

        @Assert(plan.sdkRootDriftDetected, true)
        @Assert(plan.sdkRootCandidateVerified, true)
        @Assert(plan.sdkRootRepairAvailable, true)
        @Assert(plan.repairAvailable, true)
        @Assert(plan.diagnosis, "missing-or-invalid-macos-sdkroot-repair-ready")
        @Assert(runtimeAssignmentsText(plan).contains("SDKROOT=" + sdkRoot), true)

        let rejected = inspectCjpmEnvironmentValuesWithSdkRoot("", "", "", "", sdkRoot + "-missing", "")
        @Assert(rejected.sdkRootCandidateVerified, false)
        @Assert(rejected.sdkRootRepairAvailable, false)
        @Assert(runtimeAssignmentsText(rejected).contains("SDKROOT="), false)
    }

    @TestCase
    public func deviceMemoryTtlExpiresAtBoundaryAndFailsClosed(): Unit {
        @Assert(harmonyDeviceMemoryStaleStatusAt("", "1000", "60", 1059), "active-policy")
        @Assert(harmonyDeviceMemoryStaleStatusAt("", "1000", "60", 1060), "stale-by-policy")
        @Assert(harmonyDeviceMemoryStaleStatusAt("", "1000", "", 1050), "stale-policy-missing")
        @Assert(harmonyDeviceMemoryStaleStatusAt("", "1000", "invalid", 1050), "stale-policy-invalid")
        @Assert(harmonyDeviceMemoryStaleStatusAt("not-a-time", "", "60", 1050), "stale-time-unverifiable")
        @Assert(harmonyDeviceMemoryStaleStatusAt("", "1401", "60", 1000), "stale-time-in-future")
    }

    @TestCase
    public func malformedTomlBoolDoesNotEnableAlwaysFix(): Unit {
        let root = "/tmp/hapcli-runtime-truth-strict-bool"
        if (!exists(root)) {
            Directory.create(root, recursive: true)
        }
        File.writeTo(root + "/cjpm.toml", "[package]\nname = \"fixture\"\nversion = \"0.1.0\"\n".toArray())
        File.writeTo(root + "/happub.toml", "alwaysFix = truejunk\nverbose = falsejunk\n".toArray())

        let options = HapBuildOptions()
        options.project = root
        options.configPath = root + "/happub.toml"
        let malformed = renderBuildJsonFromResults(
            options,
            false,
            HapBuildCommandResult(1, "", "fixture failure"),
            HapBuildCommandResult()
        )
        @Assert(malformed.contains("\"alwaysFix\": false"), true)
        @Assert(malformed.contains("\"doctorfixAttempted\": false"), true)

        File.writeTo(root + "/happub.toml", "alwaysFix = true # reviewed local policy\nverbose = false\n".toArray())
        let reviewed = renderBuildJsonFromResults(
            options,
            false,
            HapBuildCommandResult(1, "", "fixture failure"),
            HapBuildCommandResult()
        )
        @Assert(reviewed.contains("\"alwaysFix\": true"), true)
    }

    @TestCase
    public func installDoctorReportsMissingInputWithoutThrowing(): Unit {
        let options = HapInstallDoctorOptions()
        options.workflow = "/tmp/hapcli-runtime-truth-missing-workflow.yml"
        options.target = "darwin-arm64"

        let json = renderInstallDoctorJson(options)

        @Assert(json.contains("workflow-input-not-found"), true)
        @Assert(json.contains("\"workflowFound\": false"), true)
        @Assert(json.contains("provide an existing workflow path or omit --workflow"), true)
    }

    @TestCase
    public func installDoctorReportsUnreadableInputWithoutThrowing(): Unit {
        let path = "/tmp/hapcli-runtime-truth-workflow-directory"
        if (!exists(path)) {
            Directory.create(path, recursive: true)
        }
        let options = HapInstallDoctorOptions()
        options.workflow = path
        options.target = "darwin-arm64"

        let json = renderInstallDoctorJson(options)

        @Assert(json.contains("workflow-input-unreadable"), true)
        @Assert(json.contains("\"workflowFound\": true"), true)
        @Assert(json.contains("\"workflowReadable\": false"), true)
        @Assert(json.contains("provide a readable workflow file"), true)
    }

    @TestCase
    public func devicectlOutcomeAcceptsStructuredJsonSpacing(): Unit {
        let path = "/tmp/hapcli-runtime-truth-devicectl-result.json"
        File.writeTo(path, "{\"outcome\" : \"success\", \"localizedMessage\" : \"应用已启动\"}".toArray())

        @Assert(kmpIosDeviceCtlOutcome(path), "success")
    }

    @TestCase
    public func projectActionExitCodeReadsCompactStructuredFields(): Unit {
        @Assert(projectActionExecutionExitCodeFromJson("{\"ok\":true,\"executionActionTaken\":true}"), Int64(0))
        @Assert(projectActionExecutionExitCodeFromJson("{\"ok\":false,\"executionActionTaken\":false,\"status\":\"plan-only\"}"), Int64(2))
        @Assert(projectActionExecutionExitCodeFromJson("{\"ok\":false,\"executionActionTaken\":true,\"status\":\"reviewed-execution-failed\"}"), Int64(1))
    }

    @TestCase
    public func timeoutReceiptTruthDerivesFromReviewedCommand(): Unit {
        let unbounded = HapReviewedCommand("device-list", "hdc")
        let unboundedResult = HapReviewedCommandResult(unbounded)
        @Assert(unboundedResult.timeoutSeconds, Int64(0))
        @Assert(unboundedResult.timeoutEnforced, false)

        let bounded = HapReviewedCommand("device-list", "hdc")
        bounded.timeoutSeconds = 5
        let boundedResult = HapReviewedCommandResult(bounded)
        @Assert(boundedResult.timeoutSeconds, Int64(5))
        @Assert(boundedResult.timeoutEnforced, exists("/bin/sh"))
    }

    @TestCase
    public func graphNormalizePreservesPipeCharactersInTypedChange(): Unit {
        let root = "/tmp/hapcli-runtime-truth-graph|fixture"
        if (!exists(root)) {
            Directory.create(root, recursive: true)
        }
        let manifest = root + "/cjpm.toml"
        File.writeTo(
            manifest,
            ("[package]\nname = \"pipe_fixture\"\nversion = \"0.1.0\"\n\n" +
            "[dependencies]\npipe_dep = { git = \"https://example.invalid/repo|variant.git\" }\n").toArray()
        )

        let options = HapGraphOptions()
        options.manifests.add(manifest)
        options.localMaps.add(HapGraphLocalMap("pipe_dep", "../local|copy"))
        let json = renderCjpmGraphNormalizePlanJson(options)

        @Assert(json.contains("https://example.invalid/repo|variant.git"), true)
        @Assert(json.contains("../local|copy"), true)
        @Assert(json.contains("\"plannedChangeCount\": 1"), true)
    }

    @TestCase
    public func graphWorkflowShellTokensQuoteMetacharacters(): Unit {
        @Assert(shellToken("$HOME"), "'$HOME'")
        @Assert(shellToken("manifest`touch`"), "'manifest`touch`'")
        @Assert(shellToken("owner's manifest"), "'owner'\"'\"'s manifest'")
    }
}

func runtimeAssignmentsText(plan: HapCjpmEnvironmentPlan): String {
    let out = StringBuilder()
    for (assignment in plan.assignments) {
        out.append(assignment + "\n")
    }
    out.toString()
}
