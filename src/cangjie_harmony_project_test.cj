package hapcli

import std.fs.{Directory, File}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class HapCangjieHarmonyProjectTest {
    @TestCase
    public func detectsCangjieHarmonyWorkspaceAndRendersHapHspHarGraph(): Unit {
        let root = "/tmp/hapcli-cangjie-harmony-graph"
        createHarmonyFixtureDirectory(root + "/entry")
        createHarmonyFixtureDirectory(root + "/shared")
        createHarmonyFixtureDirectory(root + "/archive")
        File.writeTo(root + "/cjpm.toml", (
            "[app]\n" +
            "name = \"cn.example.native\"\n" +
            "runtime-OS = \"HarmonyOS\"\n" +
            "abi-filters = [\"arm64-v8a\", \"x86_64\"]\n\n" +
            "[workspace]\n" +
            "build-members = [\n" +
            "  \"entry\",\n" +
            "  \"shared\", # retained provider module\n" +
            "  \"archive\"\n" +
            "]\n"
        ).toArray())
        File.writeTo(root + "/entry/cjpm.toml", "[package]\nname = \"entry_code\"\n[hap]\nname = \"entry\"\nmain = \"EntryAbility\"\n".toArray())
        File.writeTo(root + "/shared/cjpm.toml", "[package]\nname = \"shared_code\"\n[hsp]\nname = \"shared\"\n".toArray())
        File.writeTo(root + "/archive/cjpm.toml", "[package]\nname = \"archive_code\"\n[har]\nname = \"archive\"\n".toArray())

        let options = HapProjectDetectOptions()
        options.project = root
        let json = renderProjectDetectJson(options)

        @Assert(containsText(json, "\"projectKind\": \"cangjie-harmonyos\""), true)
        @Assert(containsText(json, "\"buildSystem\": \"cjpm-harmony-package\""), true)
        @Assert(containsText(json, "\"deviceTool\": \"hdc\""), true)
        @Assert(containsText(json, "\"availablePlatforms\": [\"cangjie-harmonyos\"]"), true)
        @Assert(containsText(json, "\"appName\": \"cn.example.native\""), true)
        @Assert(containsText(json, "\"abiFilters\": [\"arm64-v8a\", \"x86_64\"]"), true)
        @Assert(containsText(json, "\"member\": \"entry\"") && containsText(json, "\"kind\": \"hap\""), true)
        @Assert(containsText(json, "\"member\": \"shared\"") && containsText(json, "\"kind\": \"hsp\""), true)
        @Assert(containsText(json, "\"member\": \"archive\"") && containsText(json, "\"kind\": \"har\""), true)
        @Assert(containsText(json, "\"adapterCandidates\": [\"cangjie-harmonyos-package-provider\"]"), true)
        @Assert(containsText(json, "\"executionActionTaken\": false"), true)
    }

    @TestCase
    public func cangjieHarmonyBuildPlanRequiresProviderAndNeverClaimsExecution(): Unit {
        let root = "/tmp/hapcli-cangjie-harmony-provider"
        createHarmonyFixtureDirectory(root + "/entry")
        File.writeTo(root + "/cjpm.toml", "[app]\nname = \"cn.example.plan\"\nruntime-OS = \"HarmonyOS\"\n[workspace]\nbuild-members = [\"entry\"]\n".toArray())
        File.writeTo(root + "/entry/cjpm.toml", "[package]\nname = \"entry_code\"\n[hap]\nname = \"entry\"\nmain = \"EntryAbility\"\n".toArray())

        let options = HapProjectActionOptions()
        options.project = root
        options.action = "build"
        options.platform = "cangjie-ohos"
        let json = renderProjectActionPlanJson(options)

        @Assert(containsText(json, "\"normalizedPlatform\": \"cangjie-harmonyos\""), true)
        @Assert(containsText(json, "\"ok\": false"), true)
        @Assert(containsText(json, "\"status\": \"package-provider-required\""), true)
        @Assert(containsText(json, "\"toolchainStatus\": \"package-provider-required\""), true)
        @Assert(containsText(json, "\"executionAvailable\": false"), true)
        @Assert(containsText(json, "cangjie-harmonyos-package-provider inspect --project <project> --receipt <inspect-receipt>"), true)
        @Assert(containsText(json, "\"executionActionTaken\": false"), true)

        options.executeReviewed = true
        let reviewed = renderProjectActionPlanJson(options)
        @Assert(containsText(reviewed, "\"status\": \"reviewed-execution-not-available-for-adapter\""), true)
        @Assert(containsText(reviewed, "\"ok\": false"), true)
    }

    @TestCase
    public func genericCangjieAndHvigorHarmonyDetectionStayDistinct(): Unit {
        let cangjie = "/tmp/hapcli-generic-cangjie"
        createHarmonyFixtureDirectory(cangjie)
        File.writeTo(cangjie + "/cjpm.toml", "[package]\nname = \"plain_cangjie\"\n".toArray())
        let cangjieOptions = HapProjectDetectOptions()
        cangjieOptions.project = cangjie
        let cangjieJson = renderProjectDetectJson(cangjieOptions)
        @Assert(containsText(cangjieJson, "\"projectKind\": \"cangjie\""), true)
        @Assert(containsText(cangjieJson, "\"adapterCandidates\": [\"cangjie-cjpm\"]"), true)

        let harmony = "/tmp/hapcli-hvigor-harmony"
        createHarmonyFixtureDirectory(harmony)
        File.writeTo(harmony + "/build-profile.json5", "{}".toArray())
        File.writeTo(harmony + "/hvigorfile.ts", "export default {}".toArray())
        let harmonyOptions = HapProjectDetectOptions()
        harmonyOptions.project = harmony
        let harmonyJson = renderProjectDetectJson(harmonyOptions)
        @Assert(containsText(harmonyJson, "\"projectKind\": \"harmonyos\""), true)
        @Assert(containsText(harmonyJson, "\"buildSystem\": \"hvigor\""), true)
    }

    @TestCase
    public func unsafeWorkspaceMemberIsReportedWithoutEscapingProjectRoot(): Unit {
        let root = "/tmp/hapcli-cangjie-harmony-unsafe"
        createHarmonyFixtureDirectory(root)
        File.writeTo(root + "/cjpm.toml", "[app]\nname = \"cn.example.unsafe\"\nruntime-OS = \"HarmonyOS\"\n[workspace]\nbuild-members = [\"../outside\"]\n".toArray())
        let options = HapProjectDetectOptions()
        options.project = root
        let json = renderProjectDetectJson(options)

        @Assert(containsText(json, "\"projectKind\": \"cangjie-harmonyos\""), true)
        @Assert(containsText(json, "../outside:unsafe-member-path"), true)
        @Assert(containsText(json, "\"modules\": [\n    ]"), true)
    }

    @TestCase
    public func reviewedBuildFailsClosedBeforeAnyHarmonyExecutorRouting(): Unit {
        let root = "/tmp/hapcli-cangjie-harmony-reviewed"
        createHarmonyFixtureDirectory(root + "/entry")
        File.writeTo(root + "/cjpm.toml", "[app]\nname = \"cn.example.reviewed\"\nruntime-OS = \"HarmonyOS\"\n[workspace]\nbuild-members = [\"entry\"]\n".toArray())
        File.writeTo(root + "/entry/cjpm.toml", "[package]\nname = \"entry_code\"\n[hap]\nname = \"entry\"\n".toArray())

        let code = runHapCli(["hap", "build", "--project", root, "--platform", "cangjie-harmonyos", "--execute-reviewed"])
        @Assert(code, Int64(3))
    }
}

func createHarmonyFixtureDirectory(path: String): Unit {
    try {
        Directory.create(path, recursive: true)
    } catch (_: Exception) {}
}
