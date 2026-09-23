package hapcli

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{Directory, File, exists}
import std.process.executeWithOutput
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class HapCjpmProfileParserTest {
    @TestCase
    public func parsesLocalCloudFixtureIntoContractModel(): Unit {
        let text = readFixture("examples/cjpm-profile-local-cloud-drift/cjpm.local.toml")
        let result = inspectCjpmProfileText(text, "cjpm.local.toml")

        @Assert(result.schema, "happub-hapcli-cjpm-profile-inspect-v0")
        @Assert(result.ok, true)
        @Assert(result.fixtureId, "local-cloud-cjpm-profile")
        @Assert(result.inferredProfile, "local-dev")
        @Assert(result.pathDependencies.size, Int64(2))
        @Assert(result.gitDependencies.size, Int64(1))
        @Assert(result.mixedProfile, true)
        @Assert(result.pathDependencies[0].name, "WebRuntime")
        @Assert(result.pathDependencies[0].path, "../deps/web-runtime")
        @Assert(result.pathDependencies[1].name, "CryptoContract")
        @Assert(result.gitDependencies[0].name, "JsonLib")
        @Assert(result.gitDependencies[0].git, "https://gitcode.com/example/json-lib-cangjie.git")
        @Assert(result.gitDependencies[0].branch, "main")
        @Assert(result.warnings.size, Int64(1))
        @Assert(result.nextAllowed.size, Int64(4))
    }

    @TestCase
    public func rendersShellCompatibleInspectionSchema(): Unit {
        let text = readFixture("examples/cjpm-profile-local-cloud-drift/cjpm.local.toml")
        let result = inspectCjpmProfileText(text, "cjpm.local.toml")
        let json = renderCjpmProfileInspectJson(result)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cjpm-profile-inspect-v0\""), true)
        @Assert(containsForTest(json, "\"fixtureId\": \"local-cloud-cjpm-profile\""), true)
        @Assert(containsForTest(json, "\"inferredProfile\": \"local-dev\""), true)
        @Assert(containsForTest(json, "\"path\": \"../deps/web-runtime\""), true)
        @Assert(containsForTest(json, "\"git\": \"https://gitcode.com/example/json-lib-cangjie.git\""), true)
        @Assert(containsForTest(json, "\"mixedProfile\": true"), true)
        @Assert(containsForTest(json, "\"local-path-dependency-not-cloud-safe\""), true)
        @Assert(containsForTest(json, "\"switch-cloud\""), true)
    }

    @TestCase
    public func rendersReadOnlyCloudSwitchPlan(): Unit {
        let cjpmText = readFixture("examples/cjpm-profile-local-cloud-drift/cjpm.local.toml")
        let profilesText = readFixture("examples/cjpm-profile-local-cloud-drift/profiles.toml")
        let json = renderCjpmProfileSwitchPlanJson(cjpmText, profilesText, "cjpm.local.toml", "profiles.toml", "cloud")

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cjpm-profile-switch-plan-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"read-only-plan\""), true)
        @Assert(containsForTest(json, "\"mutationApplied\": false"), true)
        @Assert(containsForTest(json, "\"targetProfile\": \"cloud\""), true)
        @Assert(containsForTest(json, "\"plannedDependencyCount\": 3"), true)
        @Assert(containsForTest(json, "\"value\": \"https://gitcode.com/example/web-runtime-cangjie.git\""), true)
        @Assert(containsForTest(json, "\"changed\": true"), true)
    }

    @TestCase
    public func rendersDiagnoseOnlyStdxDoctorWithoutStdxDependency(): Unit {
        let options = HapDoctorOptions()
        options.project = "examples/cjpm-profile-local-cloud-drift"
        options.target = "linux-amd64"
        options.searchRoot = "examples/toolchain-fixture"
        let json = renderStdxDoctorJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-stdx-doctor-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"diagnose-only\""), true)
        @Assert(containsForTest(json, "\"status\": \"found\""), true)
        @Assert(containsForTest(json, "\"detectedStdxRoot\": \"examples/toolchain-fixture/stdx_Build/linux_x86_64_cjnative\""), true)
        @Assert(containsForTest(json, "\"stdxDependencyRequired\": false"), true)
        @Assert(containsForTest(json, "\"doctor does not install stdx or runtime assets\""), true)
        @Assert(containsForTest(json, "\n,\n"), false)
    }

    @TestCase
    public func doctorAcceptsCommonLinuxAmd64TargetAliases(): Unit {
        let args = [
            "hap",
            "doctor",
            "stdx",
            "--project",
            "examples/cjpm-profile-local-cloud-drift",
            "--target",
            "x86_64-unknown-linux-gnu",
            "--search-root",
            "examples/toolchain-fixture"
        ]
        let options = resolveDoctorOptions(args, 3)
        let json = renderStdxDoctorJson(options)

        @Assert(options.target, "linux-amd64")
        @Assert(containsForTest(json, "\"target\": \"linux-amd64\""), true)
        @Assert(containsForTest(json, "\"expectedPlatform\": \"linux_x86_64_cjnative\""), true)
        @Assert(containsForTest(json, "\"status\": \"found\""), true)
    }

    @TestCase
    public func rendersDiagnoseOnlyRuntimeDoctor(): Unit {
        let options = HapDoctorOptions()
        options.project = "examples/cjpm-profile-local-cloud-drift"
        options.target = "linux-amd64"
        options.searchRoot = "examples/toolchain-fixture"
        let json = renderRuntimeDoctorJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-runtime-doctor-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"diagnose-only\""), true)
        @Assert(containsForTest(json, "\"status\": \"found\""), true)
        @Assert(containsForTest(json, "\"detectedRuntimeRoot\": \"examples/toolchain-fixture/runtime/lib/linux_x86_64_cjnative\""), true)
        @Assert(containsForTest(json, "\"downloadAllowed\": false"), true)
        @Assert(containsForTest(json, "\n,\n"), false)
    }

    @TestCase
    public func rendersPlanOnlyCangjieStdxGetContract(): Unit {
        let options = HapCangjieStdxGetOptions()
        options.target = "linux-amd64"
        options.version = "1.1.3.1"
        options.providerUrl = "https://example.invalid/cangjie-stdx"
        options.installRoot = "/tmp/hap-stdx"
        options.sha256 = "0123456789abcdef"
        let json = renderCangjieStdxGetPlanJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cangjie-stdx-get-plan-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"plan-only\""), true)
        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"downloadPlatform\": \"linux-x64\""), true)
        @Assert(containsForTest(json, "\"downloadFilename\": \"cangjie-stdx-linux-x64-1.1.3.1.zip\""), true)
        @Assert(containsForTest(json, "\"downloadAllowed\": false"), true)
        @Assert(containsForTest(json, "\"installAllowed\": false"), true)
        @Assert(containsForTest(json, "\"HapCLI does not depend on stdx for this contract\""), true)
    }

    @TestCase
    public func stdxGetPlanNormalizesDirectoryTargetAlias(): Unit {
        let args = [
            "hap",
            "get",
            "cangjie-stdx",
            "--target=linux_x86_64_cjnative",
            "--version=1.1.3.1",
            "--provider-url=https://example.invalid/cangjie-stdx",
            "--install-root=/tmp/hap-stdx",
            "--sha256=0123456789abcdef"
        ]
        let options = resolveCangjieStdxGetOptions(args, 3)
        let json = renderCangjieStdxGetPlanJson(options)

        @Assert(options.target, "linux-amd64")
        @Assert(containsForTest(json, "\"target\": \"linux-amd64\""), true)
        @Assert(containsForTest(json, "\"downloadPlatform\": \"linux-x64\""), true)
        @Assert(containsForTest(json, "\"expectedInstallPathHint\": \"stdx_Build/linux_x86_64_cjnative\""), true)
    }

    @TestCase
    public func stdxGetPlanRejectsExecuteAndMissingChecksum(): Unit {
        let options = HapCangjieStdxGetOptions()
        options.target = "linux-amd64"
        options.version = "1.1.3.1"
        options.providerUrl = "https://example.invalid/cangjie-stdx"
        options.installRoot = "/tmp/hap-stdx"
        options.executeRequested = true
        let json = renderCangjieStdxGetPlanJson(options)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"executeRequested\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"execute-not-supported-in-flagship-plan\""), true)
        @Assert(containsForTest(json, "\"downloadAllowed\": false"), true)
    }

    @TestCase
    public func rendersPlanOnlyHarmonyOsCangjieSdkGetContract(): Unit {
        let options = HapCangjieSdkGetOptions()
        options.target = "ohos-arm64"
        options.version = "1.1.0-alpha.20251227070000"
        options.providerUrl = "https://gitcode.com/Cangjie/nightly_build/releases/download/latest"
        options.installRoot = "/tmp/hap-cangjie"
        options.sha256 = "0123456789abcdef"
        let json = renderCangjieSdkGetPlanJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cangjie-sdk-get-plan-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"plan-only\""), true)
        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"target\": \"ohos-arm64\""), true)
        @Assert(containsForTest(json, "\"downloadPlatform\": \"ohos-aarch64\""), true)
        @Assert(containsForTest(json, "\"downloadFilename\": \"cangjie-sdk-ohos-aarch64-1.1.0-alpha.20251227070000.tar.gz\""), true)
        @Assert(containsForTest(json, "\"sdkRootHint\": \"/tmp/hap-cangjie/cangjie-sdk-ohos-aarch64-1.1.0-alpha.20251227070000\""), true)
        @Assert(containsForTest(json, "\"repair-envsetup-shebang-from-bash-to-sh-if-needed\""), true)
        @Assert(containsForTest(json, "\"self-sign-shared-objects-when-binary-sign-tool-is-available\""), true)
        @Assert(containsForTest(json, "\"materialize-ld-lld-from-lld-when-ld-lld-is-a-symlink\""), true)
        @Assert(containsForTest(json, "\"installAllowed\": false"), true)
    }

    @TestCase
    public func cangjieSdkGetPlanNormalizesHarmonyOsTargetAlias(): Unit {
        let args = [
            "hap",
            "get",
            "cangjie-sdk",
            "--target",
            "aarch64-linux-ohos-cjnative",
            "--version",
            "1.2.0-alpha.20260708020028",
            "--provider-url",
            "https://example.invalid/cangjie-sdk",
            "--install-root",
            "/tmp/hap-cangjie",
            "--allow-unverified"
        ]
        let options = resolveCangjieSdkGetOptions(args, 3)
        let json = renderCangjieSdkGetPlanJson(options)

        @Assert(options.target, "ohos-arm64")
        @Assert(containsForTest(json, "\"target\": \"ohos-arm64\""), true)
        @Assert(containsForTest(json, "\"downloadPlatform\": \"ohos-aarch64\""), true)
        @Assert(containsForTest(json, "\"allowUnverified\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"ready-for-hapup-review\""), true)
    }

    @TestCase
    public func cangjieSdkGetPlanRejectsUnknownTarget(): Unit {
        let options = HapCangjieSdkGetOptions()
        options.target = "plan9-riscv64"
        options.version = "1.1.3"
        options.providerUrl = "https://example.invalid/cangjie-sdk"
        options.installRoot = "/tmp/hap-cangjie"
        let json = renderCangjieSdkGetPlanJson(options)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"target\": \"plan9-riscv64\""), true)
        @Assert(containsForTest(json, "\"status\": \"unsupported-sdk-target\""), true)
        @Assert(containsForTest(json, "\"downloadAllowed\": false"), true)
    }

    @TestCase
    public func cangjieSdkGetPlanSupportsLinuxAndRejectsDirectExecute(): Unit {
        let options = HapCangjieSdkGetOptions()
        options.target = "linux-amd64"
        options.version = "1.3.0-alpha.20260803010032"
        options.installRoot = "/tmp/hap-cangjie"
        options.region = "global"
        options.regionExplicit = true
        options.executeRequested = true
        let json = renderCangjieSdkGetPlanJson(options)

        @Assert(containsForTest(json, "\"target\": \"linux-amd64\""), true)
        @Assert(containsForTest(json, "\"downloadPlatform\": \"linux-x64\""), true)
        @Assert(containsForTest(json, "cangjie-sdk-linux-x64-1.3.0-alpha.20260803010032.tar.gz"), true)
        @Assert(containsForTest(json, "\"status\": \"execute-not-supported-in-flagship-plan\""), true)
        @Assert(containsForTest(json, "\"executeRequested\": true"), true)
        @Assert(containsForTest(json, "\"downloadAllowed\": false"), true)
    }

    @TestCase
    public func rendersReviewedSwitchApplyOutputText(): Unit {
        let cjpmText = readFixture("examples/cjpm-profile-local-cloud-drift/cjpm.local.toml")
        let profilesText = readFixture("examples/cjpm-profile-local-cloud-drift/profiles.toml")
        let expected = readFixture("examples/cjpm-profile-local-cloud-drift/expected/switch-cloud.toml")
        let applied = renderAppliedCjpmProfileText(cjpmText, profilesText, "cloud")

        @Assert(applied, expected)
    }

    @TestCase
    public func rejectsSwitchApplyWithoutReviewGate(): Unit {
        let options = HapSwitchApplyOptions()
        options.input = "examples/cjpm-profile-local-cloud-drift/cjpm.local.toml"
        options.profiles = "examples/cjpm-profile-local-cloud-drift/profiles.toml"
        options.targetProfile = "cloud"
        let json = renderSwitchApplyRejectedJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cjpm-profile-switch-apply-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"mutationApplied\": false"), true)
        @Assert(containsForTest(json, "\"review-token, output, and receipt are required\""), true)
    }

    @TestCase
    public func rendersRuntimeOnlyHandoffForShell(): Unit {
        let options = HapRuntimeHandoffOptions()
        options.target = "linux-amd64"
        options.version = "1.1.3"
        options.providerUrl = "https://example.invalid/cangjie-runtime"
        options.installRoot = "/tmp/hap-runtime"
        options.sha256 = "abcdef0123456789"
        let json = renderRuntimeHandoffJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-runtime-handoff-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"handoff-only\""), true)
        @Assert(containsForTest(json, "\"handoffTo\": \"HapShell\""), true)
        @Assert(containsForTest(json, "\"downloadFilename\": \"cangjie-runtime-linux-x64-1.1.3.tar.gz\""), true)
        @Assert(containsForTest(json, "\"executeAllowed\": false"), true)
        @Assert(containsForTest(json, "\"downloadAllowedByFlagship\": false"), true)
        @Assert(containsForTest(json, "\"shell-may-download-and-deploy-runtime-only-after-reviewed-handoff\""), true)
    }

    @TestCase
    public func runtimeHandoffNormalizesAarch64TripleTargetAlias(): Unit {
        let args = [
            "hap",
            "handoff",
            "runtime",
            "--target",
            "aarch64-unknown-linux-gnu",
            "--version",
            "1.1.3",
            "--provider-url",
            "https://example.invalid/cangjie-runtime",
            "--install-root",
            "/tmp/hap-runtime",
            "--sha256",
            "abcdef0123456789"
        ]
        let options = resolveRuntimeHandoffOptions(args, 3)
        let json = renderRuntimeHandoffJson(options)

        @Assert(options.target, "linux-arm64")
        @Assert(containsForTest(json, "\"target\": \"linux-arm64\""), true)
        @Assert(containsForTest(json, "\"downloadPlatform\": \"linux-aarch64\""), true)
        @Assert(containsForTest(json, "\"downloadFilename\": \"cangjie-runtime-linux-aarch64-1.1.3.tar.gz\""), true)
    }

    @TestCase
    public func runtimeHandoffRejectsFlagshipExecute(): Unit {
        let options = HapRuntimeHandoffOptions()
        options.target = "linux-amd64"
        options.version = "1.1.3"
        options.providerUrl = "https://example.invalid/cangjie-runtime"
        options.installRoot = "/tmp/hap-runtime"
        options.executeRequested = true
        let json = renderRuntimeHandoffJson(options)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"executeRequested\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"execute-not-supported-in-flagship-handoff\""), true)
        @Assert(containsForTest(json, "\"deployAllowedByFlagship\": false"), true)
    }

    @TestCase
    public func ciBootstrapSnippetFailsClearlyWithoutInstalling(): Unit {
        let args = [
            "hap",
            "ci",
            "bootstrap-snippet",
            "--cli-bin",
            "hap",
            "--install-hint",
            "review hapup bootstrap packet"
        ]
        let options = resolveCiBootstrapOptions(args, 3)
        let json = renderCiBootstrapSnippetJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-ci-bootstrap-snippet-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"read-only-bootstrap-snippet\""), true)
        @Assert(containsForTest(json, "\"cliBin\": \"hap\""), true)
        @Assert(containsForTest(json, "command -v 'hap'"), true)
        @Assert(containsForTest(json, "exit 127"), true)
        @Assert(containsForTest(json, "\"bootstrap snippet does not install HapCLI\""), true)
    }

    @TestCase
    public func ciBootstrapPacketEmitsReviewedHapupTextWithoutExecuting(): Unit {
        let args = [
            "hap",
            "ci",
            "bootstrap-packet",
            "--cli-bin=hap",
            "--hapup-url=https://cli.hap.pub/install/hapup.sh",
            "--hapup-sha256=0123456789abcdef",
            "--hapup-output=/tmp/hapup",
            "--install-dir=/tmp/hap/bin",
            "--review-token-env=HAP_REVIEW_TOKEN"
        ]
        let options = resolveCiBootstrapPacketOptions(args, 3)
        let json = renderCiBootstrapPacketJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-ci-bootstrap-packet-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"ready-for-bootstrap-review\""), true)
        @Assert(containsForTest(json, "curl -fL -o '/tmp/hapup' 'https://cli.hap.pub/install/hapup.sh'"), true)
        @Assert(containsForTest(json, "sha256sum -c -"), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"installActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"bootstrap packet does not install HapCLI inside HapCLI\""), true)
    }

    @TestCase
    public func ciBootstrapPacketRequiresChecksumOrUnverifiedReview(): Unit {
        let args = [
            "hap",
            "ci",
            "bootstrap-packet",
            "--hapup-url=https://cli.hap.pub/install/hapup.sh"
        ]
        let options = resolveCiBootstrapPacketOptions(args, 3)
        let json = renderCiBootstrapPacketJson(options)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"missing-sha256-or-unverified-review\""), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"installActionTaken\": false"), true)
    }

    @TestCase
    public func releaseManifestEmitsPreviewAssetChecksumTruth(): Unit {
        let args = [
            "hap",
            "release",
            "manifest",
            "--base-url=https://cli.hap.pub/",
            "--channel=preview"
        ]
        let options = resolveReleaseManifestOptions(args, 3)
        let json = renderReleaseManifestJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-release-manifest-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"release-manifest-preview-ready\""), true)
        @Assert(containsForTest(json, "\"manifestUrl\": \"https://cli.hap.pub/release/manifest.v0.json\""), true)
        @Assert(containsForTest(json, "\"url\": \"https://cli.hap.pub/install/hapup.sh\""), true)
        @Assert(containsForTest(json, "\"sha256\": \"ea804ebf02376bcd691ae93c041e770abddd68685e6a634e21fd4c8c536879ce\""), true)
        @Assert(containsForTest(json, "\"downloadableAssetCount\": 1"), true)
        @Assert(containsForTest(json, "hap ci bootstrap-packet --cli-bin hap --hapup-url https://cli.hap.pub/install/hapup.sh --hapup-sha256 ea804ebf02376bcd691ae93c041e770abddd68685e6a634e21fd4c8c536879ce"), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"installActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"publicationActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"release manifest does not certify hosted CI adoption\""), true)
    }

    @TestCase
    public func releaseManifestRejectsUnsupportedChannelWithoutPublishing(): Unit {
        let args = [
            "hap",
            "release",
            "manifest",
            "--channel=stable"
        ]
        let options = resolveReleaseManifestOptions(args, 3)
        let json = renderReleaseManifestJson(options)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"channel\": \"stable\""), true)
        @Assert(containsForTest(json, "\"status\": \"unsupported-release-channel\""), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"installActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"publicationActionTaken\": false"), true)
    }

    @TestCase
    public func ciProjectBridgeRecipeWritesFixedBuildTestScriptAfterReview(): Unit {
        let script = "/tmp/hapcli-project-bridge-recipe-test.sh"
        let args = [
            "hap",
            "ci",
            "project-bridge-recipe",
            "--project=/tmp/hap project",
            "--reviewed-fetch-script=/tmp/hap fetch.sh",
            "--receipt=/tmp/hap receipt/project.json",
            "--recipe-output",
            script,
            "--cjpm-bin=/tmp/fake cjpm",
            "--run-tests",
            "--review-token=reviewed-project-bridge"
        ]
        let options = resolveCiProjectBridgeOptions(args, 3)
        let json = renderCiProjectBridgeRecipeJson(options)
        let written = String.fromUtf8(File.readFrom(script))

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-ci-project-bridge-recipe-v0\""), true)
        @Assert(containsForTest(json, "\"recipeFileWritten\": true"), true)
        @Assert(containsForTest(written, "PROJECT='/tmp/hap project'"), true)
        @Assert(containsForTest(written, "sh \"$REVIEWED_FETCH_SCRIPT\""), true)
        @Assert(containsForTest(written, "\"$CJPM_BIN\" build"), true)
        @Assert(containsForTest(written, "\"$CJPM_BIN\" test"), true)
        @Assert(containsForTest(written, "\"schema\":\"happub-hapcli-ci-project-bridge-receipt-v0\""), true)
        @Assert(containsForTest(written, "\"canonMutation\":false"), true)
        @Assert(containsForTest(json, "\"project bridge recipe does not execute inside HapCLI\""), true)
    }

    @TestCase
    public func ciProjectBridgeRecipeRequiresReviewToken(): Unit {
        let args = [
            "hap",
            "ci",
            "project-bridge-recipe",
            "--project=/tmp/hap-project",
            "--receipt=/tmp/hap-project.receipt.json",
            "--recipe-output=/tmp/hap-project-bridge.sh"
        ]
        let options = resolveCiProjectBridgeOptions(args, 3)
        let json = renderCiProjectBridgeRecipeJson(options)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"missing-review-token-for-project-bridge\""), true)
        @Assert(containsForTest(json, "\"recipeFileWritten\": false"), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
    }

    @TestCase
    public func ciExecutorRecipeRequiresReviewToken(): Unit {
        let args = [
            "hap",
            "ci",
            "executor-recipe",
            "--project-bridge-script=/tmp/hap-project-bridge.sh",
            "--receipt=/tmp/hap-executor.json",
            "--recipe-output=/tmp/hap-executor.sh"
        ]
        let options = resolveCiExecutorOptions(args, 3)
        let json = renderCiExecutorRecipeJson(options)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"missing-review-token-for-ci-executor\""), true)
        @Assert(containsForTest(json, "\"recipeFileWritten\": false"), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
    }

    @TestCase
    public func ciExecutorRecipeChainsReviewedScriptsAndWritesReceipt(): Unit {
        let script = "/tmp/hapcli-ci-executor-reviewed.sh"
        let args = [
            "hap",
            "ci",
            "executor-recipe",
            "--reviewed-fetch-script=/tmp/hap-fetch.sh",
            "--env-apply-script=/tmp/hap-env.sh",
            "--project-bridge-script=/tmp/hap-project-bridge.sh",
            "--receipt=/tmp/hap-executor.json",
            "--recipe-output",
            script,
            "--review-token=reviewed-executor"
        ]
        let options = resolveCiExecutorOptions(args, 3)
        let json = renderCiExecutorRecipeJson(options)
        let written = String.fromUtf8(File.readFrom(script))

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-ci-executor-recipe-v0\""), true)
        @Assert(containsForTest(json, "\"recipeFileWritten\": true"), true)
        @Assert(containsForTest(written, "REVIEWED_FETCH_SCRIPT='/tmp/hap-fetch.sh'"), true)
        @Assert(containsForTest(written, "ENV_APPLY_SCRIPT='/tmp/hap-env.sh'"), true)
        @Assert(containsForTest(written, "PROJECT_BRIDGE_SCRIPT='/tmp/hap-project-bridge.sh'"), true)
        @Assert(containsForTest(written, "\"schema\":\"happub-hapcli-ci-executor-receipt-v0\""), true)
        @Assert(containsForTest(written, "\"workflowMutationActionTaken\":false"), true)
        @Assert(containsForTest(json, "\"ci executor recipe does not execute inside HapCLI\""), true)
    }

    @TestCase
    public func ciExecutorSnippetEmitsWorkflowReviewTextWithoutMutation(): Unit {
        let args = [
            "hap",
            "ci",
            "executor-snippet",
            "--cli-bin=hapcli",
            "--reviewed-fetch-script=/tmp/hap-fetch.sh",
            "--project-bridge-script=/tmp/hap-project-bridge.sh",
            "--executor-script=/tmp/hap-executor.sh",
            "--executor-receipt=/tmp/hap-executor.json",
            "--review-token-env=HAP_REVIEW_TOKEN"
        ]
        let options = resolveCiExecutorSnippetOptions(args, 3)
        let json = renderCiExecutorSnippetJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-ci-executor-snippet-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "hapcli ci executor-recipe"), true)
        @Assert(containsForTest(json, "--review-token=\\\"$HAP_REVIEW_TOKEN\\\""), true)
        @Assert(containsForTest(json, "sh '/tmp/hap-executor.sh'"), true)
        @Assert(containsForTest(json, "test -f '/tmp/hap-executor.json'"), true)
        @Assert(containsForTest(json, "\"workflowMutationActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"executor snippet does not mutate workflow files\""), true)
    }

    @TestCase
    public func ciExecutorSnippetRequiresAtLeastOneChildScript(): Unit {
        let args = [
            "hap",
            "ci",
            "executor-snippet",
            "--executor-script=/tmp/hap-executor.sh",
            "--executor-receipt=/tmp/hap-executor.json"
        ]
        let options = resolveCiExecutorSnippetOptions(args, 3)
        let json = renderCiExecutorSnippetJson(options)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"missing-required-field-or-step\""), true)
        @Assert(containsForTest(json, "\"workflowMutationActionTaken\": false"), true)
    }

    @TestCase
    public func ciHostedProofPackWritesNonMutatingWorkflowPack(): Unit {
        let outputDir = "/tmp/hapcli-hosted-proof-pack-test"
        createDirForTest(outputDir)
        let options = resolveCiHostedProofPackOptions([
            "hap",
            "ci",
            "hosted-proof-pack",
            "--output-dir",
            outputDir,
            "--target",
            "x86_64-unknown-linux-gnu",
            "--hapup-sha256",
            "ea804ebf02376bcd691ae93c041e770abddd68685e6a634e21fd4c8c536879ce",
            "--run-tests"
        ], 3)
        let json = renderCiHostedProofPackJson(options)
        let workflow = String.fromUtf8(File.readFrom(outputDir + "/hap-hosted-proof.yml"))
        let manifest = String.fromUtf8(File.readFrom(outputDir + "/hosted-proof-pack.json"))

        @Assert(options.target, "linux-amd64")
        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-ci-hosted-proof-pack-v0\""), true)
        @Assert(containsForTest(json, "\"status\": \"ready-for-hosted-proof-review\""), true)
        @Assert(containsForTest(json, "\"workflowWritten\": true"), true)
        @Assert(containsForTest(json, "\"workflowMutationActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"hostedRunActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"installActionTaken\": false"), true)
        @Assert(containsForTest(workflow, "hapup.sh\" install-flagship"), true)
        @Assert(containsForTest(workflow, "hap ci project-bridge-recipe"), true)
        @Assert(containsForTest(workflow, "hap ci executor-recipe"), true)
        @Assert(containsForTest(workflow, "actions/upload-artifact@v4"), true)
        @Assert(containsForTest(manifest, "\"hostedRunActionTaken\": false"), true)
    }

    @TestCase
    public func ciActionDoctorFindsWorkflowRepairSuggestions(): Unit {
        let options = resolveCiActionDoctorOptions([
            "hap",
            "ci",
            "action-doctor",
            "--workflow",
            "examples/github-actions/soonlink-style-needs-hap.yml",
            "--project",
            ".",
            "--target",
            "x86_64-unknown-linux-gnu"
        ], 3)
        let json = renderCiActionDoctorJson(options)

        @Assert(options.target, "linux-amd64")
        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-ci-action-doctor-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"read-only-workflow-diagnosis\""), true)
        @Assert(containsForTest(json, "\"hasDevHapcli\": true"), true)
        @Assert(containsForTest(json, "\"hasCjpmBuild\": true"), true)
        @Assert(containsForTest(json, "\"dev-command-hapcli-present-in-workflow\""), true)
        @Assert(containsForTest(json, "\"missing-stdx-doctor-preflight\""), true)
        @Assert(containsForTest(json, "\"missing-receipt-artifact-upload\""), true)
        @Assert(containsForTest(json, "replace public CI command name hapcli with hap"), true)
        @Assert(containsForTest(json, "\"action doctor does not mutate workflow files\""), true)
    }

    @TestCase
    public func cjpmPipelinePlanEmitsReadOnlyDeepPlan(): Unit {
        let options = resolveCjpmPipelinePlanOptions([
            "hap",
            "cjpm",
            "pipeline",
            "plan",
            "--project",
            ".",
            "--manifest",
            "examples/cjpm-profile-local-cloud-drift/cjpm.local.toml",
            "--workflow",
            "examples/github-actions/soonlink-style-needs-hap.yml",
            "--target",
            "linux_x86_64_cjnative",
            "--receipt",
            "/tmp/hap-pipeline.receipt.json",
            "--run-tests"
        ], 4)
        let json = renderCjpmPipelinePlanJson(options)

        @Assert(options.target, "linux-amd64")
        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cjpm-pipeline-plan-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"read-only-deep-cjpm-pipeline-plan\""), true)
        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"mutationActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
        @Assert(containsForTest(json, "ci-action-doctor --workflow examples/github-actions/soonlink-style-needs-hap.yml"), true)
        @Assert(containsForTest(json, "doctor stdx --project . --target linux-amd64"), true)
        @Assert(containsForTest(json, "execute reviewed project bridge script with cjpm build and cjpm test outside HapCLI"), true)
        @Assert(containsForTest(json, "\"pipeline plan does not execute cjpm\""), true)
    }

    @TestCase
    public func installDoctorFindsTapAndFormulaBootstrapGaps(): Unit {
        let options = resolveInstallDoctorOptions([
            "hap",
            "install",
            "doctor",
            "--brewfile",
            "examples/install/Brewfile",
            "--formula",
            "examples/install/hap.rb",
            "--target",
            "linux_aarch64_cjnative"
        ], 3)
        let json = renderInstallDoctorJson(options)

        @Assert(options.target, "linux-arm64")
        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-install-doctor-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"read-only-install-bootstrap-diagnosis\""), true)
        @Assert(containsForTest(json, "\"mentionsBrewInstall\": false"), true)
        @Assert(containsForTest(json, "\"formula-missing-sha256\""), true)
        @Assert(containsForTest(json, "\"brewfile-missing-tap\""), true)
        @Assert(containsForTest(json, "add sha256 to Homebrew Formula"), true)
        @Assert(containsForTest(json, "\"install doctor does not install hap\""), true)
    }

    @TestCase
    public func installReplacePlanRejectsUnsafeDirWithoutExplicitAllow(): Unit {
        let asset = "/tmp/hapcli-install-replace-plan-asset"
        File.writeTo(asset, "fake hap asset".toArray())
        let options = resolveInstallReplacePlanOptions([
            "hap",
            "install",
            "replace-plan",
            "--asset",
            asset,
            "--sha256",
            "abcdef0123456789",
            "--install-dir",
            "/usr/local/bin",
            "--review-token",
            "reviewed-install-replace"
        ], 3)
        let json = renderInstallReplacePlanJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-install-replace-plan-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"unsafe-install-dir-needs-explicit-allow\""), true)
        @Assert(containsForTest(json, "\"unsafeInstallDir\": true"), true)
        @Assert(containsForTest(json, "\"replace plan does not install or replace hap\""), true)
    }

    @TestCase
    public func installReplacePlanAcceptsReviewedTmpInstallDir(): Unit {
        let asset = "/tmp/hapcli-install-replace-plan-reviewed-asset"
        File.writeTo(asset, "fake hap asset".toArray())
        let options = resolveInstallReplacePlanOptions([
            "hap",
            "install",
            "replace-plan",
            "--asset",
            asset,
            "--sha256",
            "abcdef0123456789",
            "--install-dir",
            "/tmp/hapcli-install-bin",
            "--receipt",
            "/tmp/hapcli-install.receipt.json",
            "--review-token",
            "reviewed-install-replace"
        ], 3)
        let json = renderInstallReplacePlanJson(options)

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"ready-for-hapup-install-flagship-review\""), true)
        @Assert(containsForTest(json, "\"installedBin\": \"/tmp/hapcli-install-bin/hap\""), true)
        @Assert(containsForTest(json, "hapup install-flagship --asset '/tmp/hapcli-install-replace-plan-reviewed-asset'"), true)
        @Assert(containsForTest(json, "\"installActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
    }

    @TestCase
    public func installRestorePlanRejectsMissingBackup(): Unit {
        let options = resolveInstallRestorePlanOptions([
            "hap",
            "install",
            "restore-plan",
            "--install-dir",
            "/tmp/hapcli-install-restore-missing",
            "--review-token",
            "reviewed-install-restore"
        ], 3)
        let json = renderInstallRestorePlanJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-install-restore-plan-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"backup-not-found\""), true)
        @Assert(containsForTest(json, "\"backupPath\": \"/tmp/hapcli-install-restore-missing/hap.prev\""), true)
        @Assert(containsForTest(json, "\"restore plan does not restore or replace hap\""), true)
    }

    @TestCase
    public func installRestorePlanRejectsUnsafeDirWithoutExplicitAllow(): Unit {
        let options = resolveInstallRestorePlanOptions([
            "hap",
            "install",
            "restore-plan",
            "--install-dir",
            "/usr/local/bin",
            "--review-token",
            "reviewed-install-restore"
        ], 3)
        let json = renderInstallRestorePlanJson(options)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"unsafe-install-dir-needs-explicit-allow\""), true)
        @Assert(containsForTest(json, "\"unsafeInstallDir\": true"), true)
        @Assert(containsForTest(json, "\"restoreActionTaken\": false"), true)
    }

    @TestCase
    public func installRestorePlanAcceptsReviewedTmpBackup(): Unit {
        let backup = "/tmp/hapcli-install-restore-reviewed-hap.prev"
        File.writeTo(backup, "fake previous hap".toArray())
        let options = resolveInstallRestorePlanOptions([
            "hap",
            "install",
            "restore-plan",
            "--install-dir",
            "/tmp/hapcli-install-restore-bin",
            "--backup",
            backup,
            "--receipt",
            "/tmp/hapcli-install-restore.receipt.json",
            "--review-token",
            "reviewed-install-restore"
        ], 3)
        let json = renderInstallRestorePlanJson(options)

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"ready-for-hapup-restore-flagship-review\""), true)
        @Assert(containsForTest(json, "\"backupFound\": true"), true)
        @Assert(containsForTest(json, "hapup restore-flagship --install-dir '/tmp/hapcli-install-restore-bin'"), true)
        @Assert(containsForTest(json, "--backup '/tmp/hapcli-install-restore-reviewed-hap.prev'"), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
    }

    @TestCase
    public func installReceiptReadbackRejectsMissingReceipt(): Unit {
        let json = renderInstallReceiptReadbackJson(resolveInstallReceiptReadbackOptions([
            "hap",
            "install",
            "receipt-readback",
            "--receipt",
            "/tmp/hapcli-install-receipt-missing.json"
        ], 3))

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-install-receipt-readback-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"receipt-not-found\""), true)
        @Assert(containsForTest(json, "\"receipt readback does not install or restore hap\""), true)
    }

    @TestCase
    public func installReceiptReadbackAcceptsInstallReceipt(): Unit {
        let receipt = "/tmp/hapcli-install-receipt-readback-install.json"
        File.writeTo(receipt, "{\"schema\":\"happub-hapup-install-receipt-v0\",\"ok\":true,\"asset\":\"/tmp/hap\",\"installDir\":\"/tmp/hap-bin\",\"installedBin\":\"/tmp/hap-bin/hap\",\"backupPath\":\"/tmp/hap-bin/hap.prev\",\"backupCreated\":true,\"installActionTaken\":true,\"atomicReplace\":true,\"canonMutation\":false}".toArray())
        let json = renderInstallReceiptReadbackJson(resolveInstallReceiptReadbackOptions([
            "hap",
            "install",
            "receipt-readback",
            "--receipt",
            receipt
        ], 3))

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"receiptKind\": \"install\""), true)
        @Assert(containsForTest(json, "\"status\": \"trusted-install-receipt\""), true)
        @Assert(containsForTest(json, "\"backupCreated\": true"), true)
        @Assert(containsForTest(json, "hap install restore-plan --install-dir '/tmp/hap-bin' --backup '/tmp/hap-bin/hap.prev'"), true)
        @Assert(containsForTest(json, "\"installActionTaken\": false"), true)
    }

    @TestCase
    public func installReceiptReadbackAcceptsRestoreReceipt(): Unit {
        let receipt = "/tmp/hapcli-install-receipt-readback-restore.json"
        File.writeTo(receipt, "{\"schema\":\"happub-hapup-restore-receipt-v0\",\"ok\":true,\"installDir\":\"/tmp/hap-bin\",\"restoredBin\":\"/tmp/hap-bin/hap\",\"backupPath\":\"/tmp/hap-bin/hap.prev\",\"currentBackupPath\":\"/tmp/hap-bin/hap.restore-prev\",\"currentBackupCreated\":true,\"restoreActionTaken\":true,\"atomicReplace\":true,\"canonMutation\":false}".toArray())
        let json = renderInstallReceiptReadbackJson(resolveInstallReceiptReadbackOptions([
            "hap",
            "install",
            "receipt-readback",
            "--receipt",
            receipt
        ], 3))

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"receiptKind\": \"restore\""), true)
        @Assert(containsForTest(json, "\"restoredBin\": \"/tmp/hap-bin/hap\""), true)
        @Assert(containsForTest(json, "\"currentBackupCreated\": true"), true)
        @Assert(containsForTest(json, "rerun hap install replace-plan before another reviewed replacement"), true)
        @Assert(containsForTest(json, "\"restoreActionTaken\": false"), true)
    }

    @TestCase
    public func installReceiptReadbackRejectsUnsupportedReceiptSchema(): Unit {
        let receipt = "/tmp/hapcli-install-receipt-readback-unsupported.json"
        File.writeTo(receipt, "{\"schema\":\"happub-unknown-receipt-v0\",\"ok\":true,\"installActionTaken\":true,\"atomicReplace\":true,\"canonMutation\":false}".toArray())
        let json = renderInstallReceiptReadbackJson(resolveInstallReceiptReadbackOptions([
            "hap",
            "install",
            "receipt-readback",
            "--receipt",
            receipt
        ], 3))

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"receiptKind\": \"unsupported\""), true)
        @Assert(containsForTest(json, "\"status\": \"unsupported-receipt-schema\""), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
    }

    @TestCase
    public func toolchainProvidersExposeReadOnlyProviderMatrix(): Unit {
        let json = renderToolchainProvidersJson()

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-toolchain-providers-v0\""), true)
        @Assert(containsForTest(json, "\"id\":\"cjv\""), true)
        @Assert(containsForTest(json, "\"id\":\"cjvs\""), true)
        @Assert(containsForTest(json, "\"providerCount\": 6"), true)
        @Assert(containsForTest(json, "\"id\":\"official-script\""), true)
        @Assert(containsForTest(json, "\"id\":\"hap-recipe\""), true)
        @Assert(containsForTest(json, "\"id\":\"harmonyos-pc-sdk\""), true)
        @Assert(containsForTest(json, "\"id\":\"local-sdk\""), true)
        @Assert(containsForTest(json, "\"capabilities\""), true)
        @Assert(containsForTest(json, "\"stdxFetch\":\"reviewed-fetch-recipe\""), true)
        @Assert(containsForTest(json, "\"runtimeFetch\":\"reviewed-fetch-recipe\""), true)
        @Assert(containsForTest(json, "\"install\":\"hapup-install-cangjie-sdk-after-review\""), true)
        @Assert(containsForTest(json, "\"ciSuitability\":\"best-for-ci-cloud-bridge\""), true)
        @Assert(containsForTest(json, "\"matrixBackedBy\": \"static-fixture-contract-v0\""), true)
        @Assert(containsForTest(json, "\"conflictRules\""), true)
        @Assert(containsForTest(json, "\"providerCommandExecution\":false"), true)
        @Assert(containsForTest(json, "\"providers does not execute provider commands\""), true)
    }

    @TestCase
    public func toolchainDoctorKeepsVersionManagerExternal(): Unit {
        let options = resolveToolchainDoctorOptions([
            "hap",
            "toolchain",
            "doctor",
            "--project",
            ".",
            "--target",
            "x86_64-unknown-linux-gnu",
            "--prefer",
            "cjv"
        ], 3)
        let json = renderToolchainDoctorJson(options)

        @Assert(options.target, "linux-amd64")
        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-toolchain-doctor-v0\""), true)
        @Assert(containsForTest(json, "\"recommendedProvider\": \"cjv\""), true)
        @Assert(containsForTest(json, "\"recommendedLane\""), true)
        @Assert(containsForTest(json, "\"nonRecommendedLanes\""), true)
        @Assert(containsForTest(json, "\"id\":\"cjv\",\"selected\": true"), true)
        @Assert(containsForTest(json, "\"id\":\"cjvs\",\"selected\": false"), true)
        @Assert(containsForTest(json, "\"id\":\"official-script\",\"selected\": false"), true)
        @Assert(containsForTest(json, "\"id\":\"hap-recipe\",\"selected\": false"), true)
        @Assert(containsForTest(json, "\"id\":\"harmonyos-pc-sdk\",\"selected\": false"), true)
        @Assert(containsForTest(json, "\"id\":\"local-sdk\",\"selected\": false"), true)
        @Assert(containsForTest(json, "external version manager wins SDK lifecycle"), true)
        @Assert(containsForTest(json, "\"versionManagementActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"toolchain doctor does not run cjv or cjvs\""), true)
    }

    @TestCase
    public func toolchainDoctorCanSelectHarmonyOsPcSdkLane(): Unit {
        let options = resolveToolchainDoctorOptions([
            "hap",
            "toolchain",
            "doctor",
            "--project",
            ".",
            "--target",
            "aarch64-linux-ohos",
            "--prefer",
            "harmonyos-pc-sdk"
        ], 3)
        let json = renderToolchainDoctorJson(options)

        @Assert(options.target, "ohos-arm64")
        @Assert(containsForTest(json, "\"recommendedProvider\": \"harmonyos-pc-sdk\""), true)
        @Assert(containsForTest(json, "\"platform\": \"linux_ohos_aarch64_cjnative\""), true)
        @Assert(containsForTest(json, "\"id\":\"harmonyos-pc-sdk\",\"selected\": true"), true)
        @Assert(containsForTest(json, "chmod/sign/ld.lld repair"), true)
        @Assert(containsForTest(json, "\"installActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"rcMutationActionTaken\": false"), true)
    }

    @TestCase
    public func envPrintEmitsZshSnippetWithoutRcMutation(): Unit {
        let options = resolveEnvPrintOptions([
            "hap",
            "env",
            "print",
            "--subject",
            "runtime,stdx",
            "--shell",
            "zsh",
            "--install-root",
            "/tmp/hap-env",
            "--target",
            "linux_x86_64_cjnative"
        ], 3)
        let json = renderEnvPrintJson(options)

        @Assert(options.target, "linux-amd64")
        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-env-print-v0\""), true)
        @Assert(containsForTest(json, "\"shell\": \"zsh\""), true)
        @Assert(containsForTest(json, "CANGJIE_STDX_PATH_DYNAMIC"), true)
        @Assert(containsForTest(json, "\"rcMutationActionTaken\": false"), true)
    }

    @TestCase
    public func envApplyRequiresReviewTokenBeforeRcMutation(): Unit {
        let rc = "/tmp/hapcli-env-apply-missing-review.zshrc"
        let receipt = "/tmp/hapcli-env-apply-missing-review.receipt.json"
        File.writeTo(rc, "# existing\n".toArray())
        let options = resolveEnvApplyOptions([
            "hap",
            "env",
            "apply",
            "--shell",
            "zsh",
            "--install-root",
            "/tmp/hap-env",
            "--target",
            "linux-amd64",
            "--rc",
            rc,
            "--receipt",
            receipt
        ], 3)
        let json = renderEnvApplyJson(options, true)
        let written = String.fromUtf8(File.readFrom(rc))

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-env-apply-v0\""), true)
        @Assert(containsForTest(json, "\"status\": \"missing-review-token-for-env-apply\""), true)
        @Assert(containsForTest(json, "\"rcMutationActionTaken\": false"), true)
        @Assert(written, "# existing\n")
    }

    @TestCase
    public func envApplyWritesExactRcBackupAndReceiptAfterReview(): Unit {
        let rc = "/tmp/hapcli-env-apply-reviewed.zshrc"
        let receipt = "/tmp/hapcli-env-apply-reviewed.receipt.json"
        File.writeTo(rc, "# before\n".toArray())
        let options = resolveEnvApplyOptions([
            "hap",
            "env",
            "apply",
            "--shell",
            "zsh",
            "--install-root",
            "/tmp/hap-env",
            "--target",
            "linux_x86_64_cjnative",
            "--rc",
            rc,
            "--receipt",
            receipt,
            "--review-token",
            "reviewed"
        ], 3)
        let json = renderEnvApplyJson(options, true)
        let written = String.fromUtf8(File.readFrom(rc))
        let backup = String.fromUtf8(File.readFrom(rc + ".hap-backup"))
        let receiptText = String.fromUtf8(File.readFrom(receipt))

        @Assert(options.target, "linux-amd64")
        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"rcMutationActionTaken\": true"), true)
        @Assert(backup, "# before\n")
        @Assert(containsForTest(written, "# >>> HapCLI env start"), true)
        @Assert(containsForTest(written, "CANGJIE_STDX_PATH_STATIC"), true)
        @Assert(containsForTest(receiptText, "\"schema\": \"happub-hapcli-env-apply-receipt-v0\""), true)
        @Assert(containsForTest(receiptText, "\"canonMutation\": false"), true)
    }

    @TestCase
    public func reviewedFetchRecipeRequiresReviewToken(): Unit {
        let args = [
            "hap",
            "fetch",
            "reviewed-recipe",
            "--subject=cangjie-stdx",
            "--target=linux_x86_64_cjnative",
            "--version=1.1.3.1",
            "--provider-url=https://example.invalid/cangjie-stdx",
            "--install-root=/tmp/hap-stdx",
            "--receipt=/tmp/hap-stdx.receipt.json",
            "--sha256=0123456789abcdef"
        ]
        let options = resolveReviewedFetchOptions(args, 3)
        let json = renderReviewedFetchRecipeJson(options)

        @Assert(options.target, "linux-amd64")
        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-reviewed-fetch-recipe-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"missing-review-token-for-recipe\""), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"installActionTaken\": false"), true)
    }

    @TestCase
    public func reviewedFetchRecipeEmitsControlledBashWithoutExecuting(): Unit {
        let args = [
            "hap",
            "fetch",
            "reviewed-recipe",
            "--subject",
            "runtime",
            "--target",
            "aarch64-unknown-linux-gnu",
            "--version",
            "1.1.3",
            "--provider-url",
            "https://example.invalid/cangjie-runtime",
            "--install-root",
            "/tmp/hap-runtime",
            "--receipt",
            "/tmp/hap-runtime.receipt.json",
            "--sha256",
            "abcdef0123456789",
            "--review-token",
            "reviewed-fetch-test"
        ]
        let options = resolveReviewedFetchOptions(args, 3)
        let json = renderReviewedFetchRecipeJson(options)

        @Assert(options.target, "linux-arm64")
        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"subject\": \"cangjie-runtime\""), true)
        @Assert(containsForTest(json, "\"downloadPlatform\": \"linux-aarch64\""), true)
        @Assert(containsForTest(json, "\"downloadFilename\": \"cangjie-runtime-linux-aarch64-1.1.3.tar.gz\""), true)
        @Assert(containsForTest(json, "curl -fsSL"), true)
        @Assert(containsForTest(json, "sha256sum -c -"), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"installActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"reviewed fetch recipe does not execute network actions\""), true)
    }

    @TestCase
    public func reviewedFetchRecipeRejectsDirectExecuteFlag(): Unit {
        let args = [
            "hap",
            "fetch",
            "reviewed-recipe",
            "--subject=runtime",
            "--target=linux-amd64",
            "--version=1.1.3",
            "--provider-url=https://example.invalid/cangjie-runtime",
            "--install-root=/tmp/hap-runtime",
            "--receipt=/tmp/hap-runtime.receipt.json",
            "--sha256=abcdef0123456789",
            "--review-token=reviewed-fetch-test",
            "--execute"
        ]
        let options = resolveReviewedFetchOptions(args, 3)
        let json = renderReviewedFetchRecipeJson(options)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"directExecuteRequested\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"direct-execute-not-supported\""), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"installActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"directExecuteActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"recipe\": \"\""), true)
        @Assert(containsForTest(json, "\"direct execution belongs to reviewed CI or hapup after human review, not this HapCLI surface\""), true)
    }

    @TestCase
    public func reviewedFetchRecipeCanWriteScriptFileAfterReview(): Unit {
        let script = "/tmp/hapcli-reviewed-fetch-recipe-test.sh"
        let args = [
            "hap",
            "fetch",
            "reviewed-recipe",
            "--subject=cangjie-stdx",
            "--target=linux-amd64",
            "--version=1.1.3.1",
            "--provider-url=file:///tmp/hap fixture",
            "--install-root=/tmp/hap install root",
            "--receipt=/tmp/hap receipt/out.json",
            "--recipe-output",
            script,
            "--allow-unverified",
            "--review-token=reviewed-fetch-test"
        ]
        let options = resolveReviewedFetchOptions(args, 3)
        let json = renderReviewedFetchRecipeJson(options)
        let written = String.fromUtf8(File.readFrom(script))

        @Assert(containsForTest(json, "\"recipeOutput\": \"" + script + "\""), true)
        @Assert(containsForTest(json, "\"recipeFileWritten\": true"), true)
        @Assert(containsForTest(written, "curl -fsSL 'file:///tmp/hap fixture/cangjie-stdx-linux-x64-1.1.3.1.zip'"), true)
        @Assert(containsForTest(written, "unzip -q \"$HAP_FETCH_ARCHIVE\" -d '/tmp/hap install root'"), true)
        @Assert(containsForTest(written, "> '/tmp/hap receipt/out.json'"), true)
        @Assert(containsForTest(written, "\"downloadActionTaken\":true"), true)
        @Assert(containsForTest(written, "\"networkActionTaken\":false"), true)
        @Assert(containsForTest(written, "\"deployActionTaken\":true"), true)
        @Assert(containsForTest(written, "\"canonMutation\":false"), true)
    }

    @TestCase
    public func dictionaryRefreshUpdatesLocalCacheAfterReview(): Unit {
        let source = "/tmp/hapcli-dictionary-source.json"
        let cache = "/tmp/hapcli-dictionary-cache.json"
        File.writeTo(source, "{\"schema\":\"happub-network-dictionary-v0\",\"dictionary_version\":\"test\"}\n".toArray())
        let args = [
            "hapcli",
            "dictionary",
            "refresh",
            "--source",
            source,
            "--cache",
            cache,
            "--review-token",
            "reviewed-dictionary-refresh"
        ]
        let json = runDictionaryRefresh(args, 3)
        let written = String.fromUtf8(File.readFrom(cache))

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-dictionary-refresh-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"local-first-cache-refresh\""), true)
        @Assert(containsForTest(json, "\"cacheWritten\": true"), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"reviewed-cache-updated\""), true)
        @Assert(containsForTest(written, "\"dictionary_version\":\"test\""), true)
    }

    @TestCase
    public func dictionaryRefreshRequiresReviewTokenForNetworkCacheWrite(): Unit {
        let options = HapDictionaryRefreshOptions()
        options.source = "https://cli.hap.pub/manifest.json"
        options.cachePath = "/tmp/hapcli-dictionary-cache.json"
        options.allowNetwork = true
        let json = renderDictionaryRefreshJson(options, false)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"sourceKind\": \"https-url\""), true)
        @Assert(containsForTest(json, "\"allowNetwork\": true"), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"cacheWritten\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"missing-review-token-for-network-cache-write\""), true)
        @Assert(containsForTest(json, "\"http sources require --allow-network and review-token before cache write\""), true)
    }

    @TestCase
    public func dictionaryRefreshWritesReviewedNetworkPayload(): Unit {
        let cache = "/tmp/hapcli-dictionary-network-cache.json"
        let options = HapDictionaryRefreshOptions()
        options.source = "https://cli.hap.pub/dictionaries/manifest.v0.json"
        options.cachePath = cache
        options.allowNetwork = true
        options.reviewToken = "reviewed-network-refresh"
        options.ttlSeconds = "3600"
        let payload = "{\"schema\":\"happub-network-dictionary-v0\",\"dictionary_version\":\"net-test\"}\n"
        let json = renderDictionaryRefreshJsonWithNetworkPayload(options, true, payload, 0)
        let written = String.fromUtf8(File.readFrom(cache))

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"ttlSeconds\": \"3600\""), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": true"), true)
        @Assert(containsForTest(json, "\"cacheWritten\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"reviewed-network-cache-updated\""), true)
        @Assert(containsForTest(written, "\"dictionary_version\":\"net-test\""), true)
    }

    @TestCase
    public func dictionaryRefreshRejectsMalformedNetworkPayloadWithoutOverwrite(): Unit {
        let cache = "/tmp/hapcli-dictionary-network-malformed-cache.json"
        File.writeTo(cache, "{\"schema\":\"happub-network-dictionary-v0\",\"dictionary_version\":\"old\"}\n".toArray())
        let options = HapDictionaryRefreshOptions()
        options.source = "https://cli.hap.pub/dictionaries/manifest.v0.json"
        options.cachePath = cache
        options.allowNetwork = true
        options.reviewToken = "reviewed-network-refresh"
        let json = renderDictionaryRefreshJsonWithNetworkPayload(options, true, "not-json", 0)
        let written = String.fromUtf8(File.readFrom(cache))

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": true"), true)
        @Assert(containsForTest(json, "\"cacheWritten\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"malformed-network-payload\""), true)
        @Assert(containsForTest(written, "\"dictionary_version\":\"old\""), true)
    }

    @TestCase
    public func graphDoctorDetectsPathGitImportTypeConflict(): Unit {
        let options = HapGraphOptions()
        options.manifests.add("examples/cjpm-graph-path-git-conflict/AppCore.cjpm.toml")
        options.manifests.add("examples/cjpm-graph-path-git-conflict/WebRuntime.cjpm.toml")
        options.manifests.add("examples/cjpm-graph-path-git-conflict/CryptoLib.cjpm.toml")
        let json = renderCjpmGraphDoctorJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cjpm-graph-doctor-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"dependencyConflictCount\": 1"), true)
        @Assert(containsForTest(json, "\"name\": \"crypto_core\""), true)
        @Assert(containsForTest(json, "\"code\": \"dependency-import-type-conflict\""), true)
        @Assert(containsForTest(json, "\"kind\": \"path\""), true)
        @Assert(containsForTest(json, "\"kind\": \"git\""), true)
        @Assert(containsForTest(json, "\"graph doctor does not mutate manifests\""), true)
    }

    @TestCase
    public func graphNormalizePlanConvergesExampleAppLocalBundleDeps(): Unit {
        let options = HapGraphOptions()
        options.manifests.add("examples/cjpm-graph-path-git-conflict/AppCore.cjpm.toml")
        options.manifests.add("examples/cjpm-graph-path-git-conflict/WebRuntime.cjpm.toml")
        options.manifests.add("examples/cjpm-graph-path-git-conflict/CryptoLib.cjpm.toml")
        options.localMaps.add(HapGraphLocalMap("crypto_core", "../CryptoCore"))
        let json = renderCjpmGraphNormalizePlanJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cjpm-graph-normalize-plan-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"profile\": \"local-bundle\""), true)
        @Assert(containsForTest(json, "\"plannedChangeCount\": 2"), true)
        @Assert(containsForTest(json, "\"preExistingConflictCount\": 1"), true)
        @Assert(containsForTest(json, "\"manifest\": \"examples/cjpm-graph-path-git-conflict/WebRuntime.cjpm.toml\""), true)
        @Assert(containsForTest(json, "\"manifest\": \"examples/cjpm-graph-path-git-conflict/CryptoLib.cjpm.toml\""), true)
        @Assert(containsForTest(json, "\"value\": \"../CryptoCore\""), true)
        @Assert(containsForTest(json, "\"normalize plan does not mutate manifests\""), true)
    }

    @TestCase
    public func graphNormalizeApplyRendersLocalBundleManifestCopy(): Unit {
        let text = readFixture("examples/cjpm-graph-path-git-conflict/CryptoLib.cjpm.toml")
        let localMaps = ArrayList<HapGraphLocalMap>()
        localMaps.add(HapGraphLocalMap("crypto_core", "../CryptoCore"))
        let normalized = renderNormalizedGraphManifestText(text, localMaps)

        @Assert(containsForTest(normalized, "crypto_core = { path = \"../CryptoCore\" }"), true)
        @Assert(containsForTest(normalized, "https://gitcode.com/CjKu/CryptoCore.git"), false)
        @Assert(containsForTest(normalized, "[dependencies]"), true)
    }

    @TestCase
    public func graphNormalizeApplyRejectsWorktreeOutputWithoutExplicitAllow(): Unit {
        let root = "/tmp/hapcli-graph-apply-worktree-guard"
        createDirForTest(root)
        let manifest = root + "/cjpm.toml"
        File.writeTo(manifest, "[package]\nname = \"guarded\"\n[dependencies]\ncrypto_core = { git = \"https://gitcode.com/CjKu/CryptoCore.git\" }\n".toArray())
        let args = [
            "hap",
            "cjpm",
            "graph",
            "apply-normalize",
            "--manifest",
            manifest,
            "--local-map",
            "crypto_core=../CryptoCore",
            "--output-dir",
            root + "/normalized",
            "--receipt",
            "/tmp/hapcli-graph-apply-worktree-guard.receipt.json",
            "--review-token",
            "reviewed-worktree-guard"
        ]
        let json = runCjpmGraphNormalizeApply(args, 4)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"worktree-output-needs-explicit-allow\""), true)
        @Assert(containsForTest(json, "\"outputDirInsideManifestDir\": true"), true)
        @Assert(containsForTest(json, "\"worktree output requires explicit allow-worktree-output\""), true)
    }

    @TestCase
    public func graphNormalizeApplyAllowsWorktreeOutputWhenExplicitlyReviewed(): Unit {
        let root = "/tmp/hapcli-graph-apply-worktree-allow"
        createDirForTest(root)
        let manifest = root + "/cjpm.toml"
        let output = root + "/normalized"
        File.writeTo(manifest, "[package]\nname = \"allowed\"\n[dependencies]\ncrypto_core = { git = \"https://gitcode.com/CjKu/CryptoCore.git\" }\n".toArray())
        let args = [
            "hap",
            "cjpm",
            "graph",
            "apply-normalize",
            "--manifest",
            manifest,
            "--local-map",
            "crypto_core=../CryptoCore",
            "--output-dir",
            output,
            "--receipt",
            "/tmp/hapcli-graph-apply-worktree-allow.receipt.json",
            "--review-token",
            "reviewed-worktree-allow",
            "--allow-worktree-output"
        ]
        let json = runCjpmGraphNormalizeApply(args, 4)
        let written = String.fromUtf8(File.readFrom(output + "/0-cjpm.toml"))

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"allowWorktreeOutput\": true"), true)
        @Assert(containsForTest(written, "crypto_core = { path = \"../CryptoCore\" }"), true)
    }

    @TestCase
    public func graphCiPreflightRecipeEmitsExampleAppCommandsWithoutExecuting(): Unit {
        let options = HapGraphOptions()
        options.manifests.add("examples/cjpm-graph-path-git-conflict/AppCore.cjpm.toml")
        options.manifests.add("examples/cjpm-graph-path-git-conflict/WebRuntime.cjpm.toml")
        options.manifests.add("examples/cjpm-graph-path-git-conflict/CryptoLib.cjpm.toml")
        options.localMaps.add(HapGraphLocalMap("crypto_core", "../CryptoCore"))
        options.outputDir = "/tmp/hapcli-ci-normalized"
        options.receipt = "/tmp/hapcli-ci-normalized.receipt.json"
        let json = renderCjpmGraphCiPreflightRecipeJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cjpm-graph-ci-preflight-recipe-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"read-only-ci-recipe\""), true)
        @Assert(containsForTest(json, "\"preExistingConflictCount\": 1"), true)
        @Assert(containsForTest(json, "\"plannedChangeCount\": 2"), true)
        @Assert(containsForTest(json, "\"cliBin\": \"hap\""), true)
        @Assert(containsForTest(json, "\"hasReviewedApplySurface\": true"), true)
        @Assert(containsForTest(json, "hap cjpm graph doctor --manifest 'examples/cjpm-graph-path-git-conflict/AppCore.cjpm.toml'"), true)
        @Assert(containsForTest(json, "hap cjpm graph apply-normalize"), true)
        @Assert(containsForTest(json, "--review-token $" + "{HAP_REVIEW_TOKEN}"), true)
        @Assert(containsForTest(json, "Hap cjpm graph preflight"), true)
        @Assert(containsForTest(json, "\"ci preflight recipe does not execute commands\""), true)
    }

    @TestCase
    public func graphCiWorkflowExportRequiresReviewForFileWrite(): Unit {
        let args = [
            "hapcli",
            "cjpm",
            "graph",
            "ci-workflow-export",
            "--manifest",
            "examples/cjpm-graph-path-git-conflict/AppCore.cjpm.toml",
            "--workflow-output",
            "/tmp/hapcli-workflow-missing-review.yml"
        ]
        let json = runCjpmGraphCiWorkflowExport(args, 4)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cjpm-graph-ci-workflow-export-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"workflowWritten\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"missing-review-token-for-workflow-output\""), true)
    }

    @TestCase
    public func graphCiWorkflowExportWritesReviewedSnippet(): Unit {
        let output = "/tmp/hapcli-workflow-reviewed.yml"
        let args = [
            "hapcli",
            "cjpm",
            "graph",
            "ci-workflow-export",
            "--manifest",
            "examples/cjpm-graph-path-git-conflict/AppCore.cjpm.toml",
            "--manifest",
            "examples/cjpm-graph-path-git-conflict/WebRuntime.cjpm.toml",
            "--local-map",
            "crypto_core=../CryptoCore",
            "--workflow-output",
            output,
            "--review-token",
            "reviewed-workflow-export-test"
        ]
        let json = runCjpmGraphCiWorkflowExport(args, 4)
        let written = String.fromUtf8(File.readFrom(output))

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"workflowWritten\": true"), true)
        @Assert(containsForTest(json, "\"workflowOutput\": \"" + output + "\""), true)
        @Assert(containsForTest(written, "- name: Hap cjpm graph preflight"), true)
        @Assert(containsForTest(written, "hap cjpm graph doctor"), true)
        @Assert(containsForTest(written, "hap cjpm graph normalize-plan"), true)
        @Assert(containsForTest(written, "hapcli cjpm graph"), false)
    }

    @TestCase
    public func graphCiWorkflowExportAllowsCliBinOverride(): Unit {
        let output = "/tmp/hapcli-workflow-reviewed-override.yml"
        let args = [
            "hapcli",
            "cjpm",
            "graph",
            "ci-workflow-export",
            "--manifest",
            "examples/cjpm-graph-path-git-conflict/AppCore.cjpm.toml",
            "--workflow-output",
            output,
            "--review-token",
            "reviewed-workflow-export-test",
            "--cli-bin",
            "hapcli"
        ]
        let json = runCjpmGraphCiWorkflowExport(args, 4)
        let written = String.fromUtf8(File.readFrom(output))

        @Assert(containsForTest(json, "\"cliBin\": \"hapcli\""), true)
        @Assert(containsForTest(written, "hapcli cjpm graph doctor"), true)
    }

    @TestCase
    public func graphDiscoverManifestsFindsExplicitRootManifestsOnly(): Unit {
        let root = prepareManifestDiscoveryFixtureForTest()

        let options = HapGraphOptions()
        options.roots.add(root)
        options.maxDepth = 3
        let json = renderCjpmGraphDiscoverManifestsJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cjpm-graph-discover-manifests-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"read-only-discovery\""), true)
        @Assert(containsForTest(json, "\"manifestCount\": 2"), true)
        @Assert(containsForTest(json, root + "/AppCore/cjpm.toml"), true)
        @Assert(containsForTest(json, root + "/deps/WebRuntime/WebRuntime.cjpm.toml"), true)
        @Assert(containsForTest(json, root + "/target/ignored/cjpm.toml"), false)
        @Assert(containsForTest(json, "\"discover manifests does not feed results into apply automatically\""), true)
    }

    @TestCase
    public func graphManifestListExportRequiresReviewForFileWrite(): Unit {
        let root = prepareManifestDiscoveryFixtureForTest()
        let args = [
            "hapcli",
            "cjpm",
            "graph",
            "manifest-list-export",
            "--root",
            root,
            "--manifest-list-output",
            "/tmp/hapcli-manifest-list-missing-review.json"
        ]
        let json = runCjpmGraphManifestListExport(args, 4)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cjpm-graph-manifest-list-export-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"manifestListWritten\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"missing-review-token-for-manifest-list-output\""), true)
    }

    @TestCase
    public func graphManifestListExportWritesReviewedArtifact(): Unit {
        let root = prepareManifestDiscoveryFixtureForTest()
        let output = testTempPathForTest("hapcli-manifest-list-reviewed.json")
        let args = [
            "hapcli",
            "cjpm",
            "graph",
            "manifest-list-export",
            "--root",
            root,
            "--max-depth",
            "3",
            "--manifest-list-output",
            output,
            "--review-token",
            "reviewed-manifest-list-test"
        ]
        let json = runCjpmGraphManifestListExport(args, 4)
        let written = String.fromUtf8(File.readFrom(output))

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cjpm-graph-manifest-list-export-v0\""), true)
        @Assert(containsForTest(json, "\"manifestListWritten\": true"), true)
        @Assert(containsForTest(written, "\"schema\": \"happub-hapcli-cjpm-graph-manifest-list-v0\""), true)
        @Assert(containsForTest(written, root + "/AppCore/cjpm.toml"), true)
        @Assert(containsForTest(written, root + "/deps/WebRuntime/WebRuntime.cjpm.toml"), true)
        @Assert(containsForTest(written, "\"manifest list does not feed results into apply automatically\""), true)
    }

    @TestCase
    public func graphManifestListReadbackSelectsPackageAndEmitsCommands(): Unit {
        let root = prepareManifestDiscoveryFixtureForTest()
        let output = testTempPathForTest("hapcli-manifest-list-readback-reviewed.json")
        let exportArgs = [
            "hapcli",
            "cjpm",
            "graph",
            "manifest-list-export",
            "--root",
            root,
            "--max-depth",
            "3",
            "--manifest-list-output",
            output,
            "--review-token",
            "reviewed-manifest-list-readback-test"
        ]
        let exportJson = runCjpmGraphManifestListExport(exportArgs, 4)
        let options = resolveGraphOptions([
            "hapcli",
            "cjpm",
            "graph",
            "manifest-list-readback",
            "--manifest-list",
            output,
            "--package",
            "web-runtime",
            "--cli-bin",
            "hapcli"
        ], 4)
        let json = renderCjpmGraphManifestListReadbackJson(options)

        @Assert(containsForTest(exportJson, "\"manifestListWritten\": true"), true)
        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-cjpm-graph-manifest-list-readback-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"selected-manifests-ready\""), true)
        @Assert(containsForTest(json, "\"selectedCount\": 1"), true)
        @Assert(containsForTest(json, "\"packageName\": \"web-runtime\""), true)
        @Assert(containsForTest(json, root + "/deps/WebRuntime/WebRuntime.cjpm.toml"), true)
        @Assert(containsForTest(json, "hapcli cjpm graph doctor --manifest '" + root + "/deps/WebRuntime/WebRuntime.cjpm.toml'"), true)
        @Assert(containsForTest(json, "\"manifest-list readback does not run graph doctor, apply, CI, or cjpm build\""), true)
    }

    @TestCase
    public func graphManifestListReadbackRejectsMissingArtifact(): Unit {
        let options = resolveGraphOptions([
            "hap",
            "cjpm",
            "graph",
            "manifest-list-readback",
            "--manifest-list",
            "/tmp/hapcli-manifest-list-not-found.json"
        ], 4)
        let json = renderCjpmGraphManifestListReadbackJson(options)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"manifest-list-not-found\""), true)
        @Assert(containsForTest(json, "\"artifactFound\": false"), true)
        @Assert(containsForTest(json, "\"selectedCount\": 0"), true)
    }

    @TestCase
    public func recordCangjieStdxLearnsOhosDynamicProfile(): Unit {
        let root = "/tmp/hapcli-stdx-record-test"
        createDirForTest(root)
        let config = root + "/config.toml"
        File.writeTo(root + "/cjpm.toml", (
            "[package]\n" +
            "name = \"demo\"\n\n" +
            "[target.aarch64-linux-ohos]\n" +
            "compile-option = \"-B \\\"\${DEVECO_CANGJIE_HOME}/compiler/third_party/llvm/bin\\\" --sysroot \\\"\${DEVECO_OH_NATIVE_HOME}/sysroot\\\"\"\n" +
            "[target.aarch64-linux-ohos.bin-dependencies]\n" +
            "path-option = [\"\${AARCH64_LIBS}\", \"\${AARCH64_MACRO_LIBS}\", \"\${CANGJIE_STDX_PATH}/linux_ohos_aarch64_cjnative/dynamic/stdx\"]\n"
        ).toArray())

        let json = renderRecordJson(resolveRecordOptions([
            "hap",
            "record",
            "--target",
            "aarch64-linux-ohos",
            "cangjie.stdx",
            "--project",
            root,
            "--config",
            config,
            "--name",
            "ohos-dynamic-aarch64",
            "--from-build-success"
        ], 2), true)
        let written = String.fromUtf8(File.readFrom(config))

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-record-cangjie-stdx-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"target\": \"ohos-arm64\""), true)
        @Assert(containsForTest(written, "subject = \"cangjie.stdx\""), true)
        @Assert(containsForTest(written, "name = \"ohos-dynamic-aarch64\""), true)
        @Assert(containsForTest(written, "target = \"ohos-arm64\""), true)
        @Assert(containsForTest(written, "source = \"recorded-from-build-success\""), true)
        @Assert(containsForTest(written, "\${CANGJIE_STDX_PATH}/linux_ohos_aarch64_cjnative/dynamic/stdx"), true)
    }

    @TestCase
    public func doctorfixCangjieStdxWritesRecordedLinuxProfile(): Unit {
        let root = "/tmp/hapcli-stdx-doctorfix-test"
        createDirForTest(root)
        let config = root + "/config.toml"
        let manifest = root + "/cjpm.toml"
        let original = (
            "[package]\n" +
            "name = \"demo\"\n\n" +
            "[target.x86_64-unknown-linux-gnu]\n" +
            "compile-option = \"-Woff unused --diagnostic-format=noColor -Woff deprecated -ldl\"\n" +
            "[target.x86_64-unknown-linux-gnu.bin-dependencies]\n" +
            "path-option = [\"\${CANGJIE_STDX_PATH}\"]\n"
        )
        File.writeTo(manifest, original.toArray())
        File.writeTo(config, (
            "[hap]\n" +
            "schema = \"happub-hapcli-config-v0\"\n" +
            "alwaysFix = true\n" +
            "verbose = false\n\n" +
            "[[records]]\n" +
            "subject = \"cangjie.stdx\"\n" +
            "name = \"linux-static\"\n" +
            "target = \"linux-amd64\"\n" +
            "sourceTarget = \"x86_64-unknown-linux-gnu\"\n" +
            "compileOption = \"-Woff unused -ldl\"\n" +
            "linkOption = \"\"\n" +
            "pathOption = [\"\${CANGJIE_STDX_PATH}/linux_x86_64_llvm/static/stdx\"]\n"
        ).toArray())

        let json = renderDoctorFixJson(resolveDoctorFixOptions([
            "hap",
            "doctorfix",
            "--target",
            "x86_64-unknown-linux-gnu",
            "cangjie.stdx",
            "--project",
            root,
            "--config",
            config,
            "--write"
        ], 2), true)
        let fixed = String.fromUtf8(File.readFrom(manifest))
        let backup = String.fromUtf8(File.readFrom(manifest + ".hap-backup"))
        let receipt = String.fromUtf8(File.readFrom(root + "/.hapData/receipts/doctorfix-cangjie-stdx.json"))

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-doctorfix-cangjie-stdx-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"reviewed-write\""), true)
        @Assert(containsForTest(json, "\"manifestMutationActionTaken\": true"), true)
        @Assert(containsForTest(fixed, "compile-option = \"-Woff unused -ldl\""), true)
        @Assert(containsForTest(fixed, "\${CANGJIE_STDX_PATH}/linux_x86_64_llvm/static/stdx"), true)
        @Assert(backup, original)
        @Assert(containsForTest(receipt, "\"schema\": \"happub-hapcli-doctorfix-cangjie-stdx-receipt-v0\""), true)
    }

    @TestCase
    public func buildWrapperDoesNotMutateWhenAlwaysFixDisabled(): Unit {
        let root = "/tmp/hapcli-build-wrapper-no-autofix-test"
        createDirForTest(root)
        let config = root + "/config.toml"
        let manifest = root + "/cjpm.toml"
        let original = (
            "[package]\n" +
            "name = \"demo\"\n\n" +
            "[target.x86_64-unknown-linux-gnu]\n" +
            "compile-option = \"-ldl\"\n" +
            "[target.x86_64-unknown-linux-gnu.bin-dependencies]\n" +
            "path-option = [\"\${CANGJIE_STDX_PATH}\"]\n"
        )
        File.writeTo(manifest, original.toArray())
        File.writeTo(config, (
            "[hap]\n" +
            "schema = \"happub-hapcli-config-v0\"\n" +
            "alwaysFix = false\n" +
            "verbose = false\n\n" +
            "[[records]]\n" +
            "subject = \"cangjie.stdx\"\n" +
            "name = \"linux-static\"\n" +
            "target = \"linux-amd64\"\n" +
            "sourceTarget = \"x86_64-unknown-linux-gnu\"\n" +
            "compileOption = \"-Woff unused -ldl\"\n" +
            "linkOption = \"\"\n" +
            "pathOption = [\"\${CANGJIE_STDX_PATH}/linux_x86_64_llvm/static/stdx\"]\n"
        ).toArray())

        let options = resolveBuildOptions([
            "hap",
            "build",
            "--project",
            root,
            "--target",
            "x86_64-unknown-linux-gnu",
            "--config",
            config
        ], 2)
        let json = renderBuildJsonFromResults(
            options,
            true,
            HapBuildCommandResult(1, "first out", "first err"),
            HapBuildCommandResult()
        )
        let after = String.fromUtf8(File.readFrom(manifest))

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-build-wrapper-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"alwaysFix\": false"), true)
        @Assert(containsForTest(json, "\"doctorfixApplied\": false"), true)
        @Assert(containsForTest(json, "\"retryBuildRan\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"build-failed-alwaysfix-disabled\""), true)
        @Assert(after, original)
        @Assert(buildWrapperExitCodeFromJson(json), Int64(1))
    }

    @TestCase
    public func buildWrapperReportsMissingProjectWithoutExecuting(): Unit {
        let options = resolveBuildOptions([
            "hap",
            "build",
            "--project",
            "/tmp/hapcli-build-wrapper-missing-project-for-test",
            "--target",
            "linux-amd64"
        ], 2)
        let json = renderBuildJson(options, true, true)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-build-wrapper-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"firstBuildRan\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"project-not-supported-missing-cjpm\""), true)
        @Assert(buildWrapperExitCodeFromJson(json), Int64(2))
    }

    @TestCase
    public func buildWrapperAppliesRecordedStdxAndRetriesOnce(): Unit {
        let root = "/tmp/hapcli-build-wrapper-autofix-test"
        createDirForTest(root)
        let config = root + "/config.toml"
        let manifest = root + "/cjpm.toml"
        let original = (
            "[package]\n" +
            "name = \"demo\"\n\n" +
            "[target.x86_64-unknown-linux-gnu]\n" +
            "compile-option = \"-ldl\"\n" +
            "[target.x86_64-unknown-linux-gnu.bin-dependencies]\n" +
            "path-option = [\"\${CANGJIE_STDX_PATH}\"]\n"
        )
        File.writeTo(manifest, original.toArray())
        File.writeTo(config, (
            "[hap]\n" +
            "schema = \"happub-hapcli-config-v0\"\n" +
            "alwaysFix = true\n" +
            "verbose = true\n\n" +
            "[[records]]\n" +
            "subject = \"cangjie.stdx\"\n" +
            "name = \"linux-static\"\n" +
            "target = \"linux-amd64\"\n" +
            "sourceTarget = \"x86_64-unknown-linux-gnu\"\n" +
            "compileOption = \"-Woff unused -ldl\"\n" +
            "linkOption = \"\"\n" +
            "pathOption = [\"\${CANGJIE_STDX_PATH}/linux_x86_64_llvm/static/stdx\"]\n"
        ).toArray())

        let options = resolveBuildOptions([
            "hap",
            "build",
            "--project",
            root,
            "--target=linux-amd64",
            "--config",
            config
        ], 2)
        let json = renderBuildJsonFromResults(
            options,
            true,
            HapBuildCommandResult(1, "first out", "first err"),
            HapBuildCommandResult(0, "retry out", "")
        )
        let fixed = String.fromUtf8(File.readFrom(manifest))
        let backup = String.fromUtf8(File.readFrom(manifest + ".hap-backup"))
        let receipt = String.fromUtf8(File.readFrom(root + "/.hapData/receipts/build-cangjie-stdx.json"))

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-build-wrapper-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"alwaysFix\": true"), true)
        @Assert(containsForTest(json, "\"doctorfixApplied\": true"), true)
        @Assert(containsForTest(json, "\"retryBuildRan\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"retry-succeeded-after-doctorfix\""), true)
        @Assert(containsForTest(json, "\"firstStdout\": \"first out\""), true)
        @Assert(containsForTest(json, "\"retryStdout\": \"retry out\""), true)
        @Assert(containsForTest(json, "\"cjpmTarget\": \"x86_64-unknown-linux-gnu\""), true)
        @Assert(containsForTest(fixed, "\${CANGJIE_STDX_PATH}/linux_x86_64_llvm/static/stdx"), true)
        @Assert(backup, original)
        @Assert(containsForTest(receipt, "\"schema\": \"happub-hapcli-build-wrapper-v0\""), true)
        @Assert(buildWrapperExitCodeFromJson(json), Int64(0))
    }

    @TestCase
    public func projectDetectFindsHarmonyAdapterSignals(): Unit {
        let root = "/tmp/hapcli-project-detect-harmony-test"
        createDirForTest(root + "/entry/src/main")
        createDirForTest(root + "/AppScope")
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(root + "/oh-package.json5", "{}".toArray())
        File.writeTo(root + "/entry/src/main/module.json5", "{}".toArray())

        let options = resolveProjectDetectOptions([
            "hap",
            "project",
            "detect",
            "--project",
            root
        ], 3)
        let json = renderProjectDetectJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-project-detect-v0\""), true)
        @Assert(containsForTest(json, "\"projectKind\": \"harmonyos\""), true)
        @Assert(containsForTest(json, "\"buildSystem\": \"hvigor\""), true)
        @Assert(containsForTest(json, "\"deviceTool\": \"hdc\""), true)
        @Assert(containsForTest(json, "\"confidence\": \"high\""), true)
        @Assert(containsForTest(json, "\"selectionStatus\": \"selected\""), true)
        @Assert(containsForTest(json, "\"needsPlatform\": false"), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
        @Assert(containsForTest(json, "hap dev --platform harmonyos --device auto"), true)
    }

    @TestCase
    public func projectDetectReportsAmbiguousMixedProjectAndRequestsPlatform(): Unit {
        let root = "/tmp/hapcli-project-detect-ambiguous-test"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(root + "/cjpm.toml", "[package]\nname = \"mixed\"\n".toArray())

        let json = renderProjectDetectJson(resolveProjectDetectOptions([
            "hap",
            "project",
            "detect",
            "--project",
            root
        ], 3))

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"selectionStatus\": \"ambiguous-project-platform\""), true)
        @Assert(containsForTest(json, "\"ambiguousProject\": true"), true)
        @Assert(containsForTest(json, "\"needsPlatform\": true"), true)
        @Assert(containsForTest(json, "\"availablePlatforms\": [\"harmonyos\", \"cangjie\"]"), true)
        @Assert(containsForTest(json, "add --platform harmonyos|cangjie|ios|kmp"), true)
    }

    @TestCase
    public func projectDetectFindsIosWorkspaceSignals(): Unit {
        let root = "/tmp/hapcli-project-detect-ios-test"
        createDirForTest(root + "/Demo.xcworkspace")
        File.writeTo(root + "/Podfile", "platform :ios, '15.0'".toArray())

        let options = resolveProjectDetectOptions([
            "hap",
            "project",
            "detect",
            "--project",
            root
        ], 3)
        let json = renderProjectDetectJson(options)

        @Assert(containsForTest(json, "\"projectKind\": \"ios\""), true)
        @Assert(containsForTest(json, "\"buildSystem\": \"xcodebuild\""), true)
        @Assert(containsForTest(json, "\"adapterCandidates\": [\"ios-xcodebuild\"]"), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
    }

    @TestCase
    public func projectDetectFindsKmpGradleSignals(): Unit {
        let root = "/tmp/hapcli-project-detect-kmp-test"
        createDirForTest(root + "/src/commonMain")
        File.writeTo(root + "/settings.gradle.kts", "pluginManagement {}".toArray())
        File.writeTo(root + "/build.gradle.kts", "plugins { kotlin(\"multiplatform\") }".toArray())
        File.writeTo(root + "/gradlew", "#!/bin/sh\n".toArray())

        let options = resolveProjectDetectOptions([
            "hap",
            "project",
            "detect",
            "--project",
            root
        ], 3)
        let json = renderProjectDetectJson(options)

        @Assert(containsForTest(json, "\"projectKind\": \"kotlin-multiplatform\""), true)
        @Assert(containsForTest(json, "\"buildSystem\": \"gradle\""), true)
        @Assert(containsForTest(json, "\"adapterCandidates\": [\"kmp-compose-gradle\", \"kmp-ios-xcodebuild-plan\"]"), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
    }

    @TestCase
    public func projectDetectFindsComposeMultiplatformDemoShape(): Unit {
        let root = "/tmp/hapcli-project-detect-kmp-demo-shape-test"
        createDirForTest(root + "/composeApp/src/commonMain")
        createDirForTest(root + "/composeApp/src/iosMain")
        createDirForTest(root + "/composeApp/src/androidMain")
        createDirForTest(root + "/iosApp/iosApp.xcodeproj")
        createDirForTest(root + "/iosApp/iosApp")
        createDirForTest(root + "/gradle")
        File.writeTo(root + "/settings.gradle.kts", "include(\":composeApp\")".toArray())
        File.writeTo(root + "/build.gradle.kts", "plugins { alias(libs.plugins.kotlinMultiplatform) apply false }".toArray())
        File.writeTo(root + "/composeApp/build.gradle.kts", "plugins { alias(libs.plugins.kotlinMultiplatform); alias(libs.plugins.composeMultiplatform) }\nkotlin { iosArm64() }".toArray())
        File.writeTo(root + "/iosApp/iosApp.xcodeproj/project.pbxproj", "/* PBXNativeTarget \"iosApp\" */".toArray())
        File.writeTo(root + "/iosApp/iosApp/Info.plist", "<plist/>".toArray())
        File.writeTo(root + "/gradle/libs.versions.toml", "[versions]\n".toArray())
        File.writeTo(root + "/gradlew", "#!/bin/sh\n".toArray())

        let options = resolveProjectDetectOptions([
            "hap",
            "project",
            "detect",
            "--project",
            root
        ], 3)
        let json = renderProjectDetectJson(options)

        @Assert(containsForTest(json, "\"projectKind\": \"kotlin-multiplatform\""), true)
        @Assert(containsForTest(json, "\"confidence\": \"high\""), true)
        @Assert(containsForTest(json, "composeApp/src/commonMain"), true)
        @Assert(containsForTest(json, "composeApp/build.gradle.kts:composeMultiplatform"), true)
        @Assert(containsForTest(json, "settings.gradle.kts:include-composeApp"), true)
        @Assert(containsForTest(json, "hap dev --platform kmp --plan"), true)
    }

    @TestCase
    public func projectDetectFindsCangjieCjpmSignalsAndPlatformOverride(): Unit {
        let root = "/tmp/hapcli-project-detect-cangjie-test"
        createDirForTest(root)
        File.writeTo(root + "/cjpm.toml", "[package]\nname = \"demo\"\n".toArray())

        let options = resolveProjectDetectOptions([
            "hap",
            "project",
            "detect",
            "--project",
            root,
            "--platform",
            "cjpm"
        ], 3)
        let json = renderProjectDetectJson(options)

        @Assert(containsForTest(json, "\"requestedPlatform\": \"cjpm\""), true)
        @Assert(containsForTest(json, "\"projectKind\": \"cangjie\""), true)
        @Assert(containsForTest(json, "\"buildSystem\": \"cjpm\""), true)
        @Assert(containsForTest(json, "\"adapterCandidates\": [\"cangjie-cjpm\"]"), true)
        @Assert(containsForTest(json, "\"mutationActionTaken\": false"), true)
    }

    @TestCase
    public func projectActionPlanRendersHarmonyBuildTemplateWithoutExecution(): Unit {
        let root = "/tmp/hapcli-project-action-harmony-build-plan-test"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())

        let options = resolveProjectActionOptions("build", [
            "hap",
            "build",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--output",
            "/tmp/hap-build",
            "--plan"
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-project-action-plan-v0\""), true)
        @Assert(containsForTest(json, "\"mode\": \"plan-only\""), true)
        @Assert(containsForTest(json, "\"action\": \"build\""), true)
        @Assert(containsForTest(json, "\"projectKind\": \"harmonyos\""), true)
        @Assert(containsForTest(json, "\"selectionStatus\": \"selected\""), true)
        let hvigorwDefault = "hvigorw"
        let nodeDefault = "node"
        let hvigorwJsDefault = "hvigorw.js"
        @Assert(containsForTest(json, "\"fixedCommandTemplates\": [\"" + hvigorwDefault + " assembleApp --mode project -p product=default -p buildMode=debug\""), true)
        @Assert(containsForTest(json, nodeDefault + " " + hvigorwJsDefault + " --mode module -p module=Product -p product=default -p buildMode=debug assembleHap"), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"outputDir\": \"/tmp/hap-build\""), true)
    }

    @TestCase
    public func projectActionPlanAutoSelectsHarmonyWithoutPlatform(): Unit {
        let root = "/tmp/hapcli-project-action-harmony-auto-plan-test"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--plan"
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(options.platform, "auto")
        @Assert(containsForTest(json, "\"requestedPlatform\": \"auto\""), true)
        @Assert(containsForTest(json, "\"selectionStatus\": \"selected\""), true)
        @Assert(containsForTest(json, "\"projectKind\": \"harmonyos\""), true)
        @Assert(containsForTest(json, "\"fixedCommandTemplates\": [\"hdc list targets\", \"hvigorw assembleApp --mode project -p product=default -p buildMode=debug\""), true)
        @Assert(containsForTest(json, "\"toolchainQuestions\""), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
    }

    @TestCase
    public func projectActionPlanReadsHarmonyConfigWithoutLeakingHostDefaults(): Unit {
        let root = "/tmp/hapcli-project-action-harmony-config-plan-test"
        let config = root + "/happub.toml"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"C:/HarmonyTools/hvigor/bin/hvigorw.bat\"\n" +
            "hdcPath = \"C:/HarmonyTools/hdc/hdc.exe\"\n" +
            "nodePath = \"C:/HarmonyTools/node/node.exe\"\n" +
            "hvigorwJsPath = \"C:/HarmonyTools/hvigor/bin/hvigorw.js\"\n" +
            "product = \"default\"\n" +
            "buildMode = \"debug\"\n" +
            "module = \"Product\"\n" +
            "artifactPath = \"Product/build/default/outputs/default/Product-default-signed.hap\"\n" +
            "bundle = \"cn.cryI.fileMgr\"\n" +
            "ability = \"ProductAbility\"\n"
        ).toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--plan"
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(containsForTest(json, "\"harmonyConfigPath\": \"" + config + "\""), true)
        @Assert(containsForTest(json, "\"harmonyConfigSource\": \"explicit-config\""), true)
        @Assert(containsForTest(json, "C:/HarmonyTools/hvigor/bin/hvigorw.bat assembleApp --mode project -p product=default -p buildMode=debug"), true)
        @Assert(containsForTest(json, "C:/HarmonyTools/hdc/hdc.exe install -r Product/build/default/outputs/default/Product-default-signed.hap"), true)
        @Assert(containsForTest(json, "C:/HarmonyTools/hdc/hdc.exe shell aa start -b cn.cryI.fileMgr -a ProductAbility"), true)
    }

    @TestCase
    public func projectActionPlanInfersHarmonyLaunchConfigFromProjectFiles(): Unit {
        let root = "/tmp/hapcli-project-action-harmony-inference-plan-test"
        createDirForTest(root + "/AppScope")
        createDirForTest(root + "/Product/src/main")
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(root + "/AppScope/app.json5", "{\"app\":{\"bundleName\":\"cn.cryI.fileMgr\"}}".toArray())
        File.writeTo(root + "/Product/src/main/module.json5", "{\"module\":{\"name\":\"Product\",\"mainElement\":\"ProductAbility\",\"abilities\":[{\"name\":\"FallbackAbility\"}]}}".toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--plan"
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(containsForTest(json, "\"harmonyConfigSource\": \"project-inference\""), true)
        @Assert(containsForTest(json, "hdc shell aa start -b cn.cryI.fileMgr -a ProductAbility"), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
    }

    @TestCase
    public func projectActionPlanDoesNotStealLegacyBuildForOutputOnly(): Unit {
        @Assert(shouldUseProjectActionPlan([
            "hap",
            "build",
            "--project",
            ".",
            "--output",
            "/tmp/hap-build"
        ], 2), false)
        @Assert(shouldUseAutoProjectActionForBuild([
            "hap",
            "build",
            "--project",
            ".",
            "--output",
            "/tmp/hap-build"
        ], 2), false)
        @Assert(shouldUseProjectActionPlan([
            "hap",
            "build",
            "--project",
            ".",
            "--platform",
            "harmonyos",
            "--output",
            "/tmp/hap-build"
        ], 2), true)
    }

    @TestCase
    public func projectActionBuildAutoRoutesHarmonyAndAmbiguousAwayFromCjpmWrapper(): Unit {
        let harmony = "/tmp/hapcli-build-auto-harmony-route-test"
        createDirForTest(harmony)
        File.writeTo(harmony + "/build-profile.json5", "{}".toArray())
        File.writeTo(harmony + "/hvigorfile.ts", "export default {}".toArray())

        let ambiguous = "/tmp/hapcli-build-auto-ambiguous-route-test"
        createDirForTest(ambiguous)
        File.writeTo(ambiguous + "/build-profile.json5", "{}".toArray())
        File.writeTo(ambiguous + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(ambiguous + "/cjpm.toml", "[package]\nname = \"mixed\"\n".toArray())

        let cangjie = "/tmp/hapcli-build-auto-cangjie-route-test"
        createDirForTest(cangjie)
        File.writeTo(cangjie + "/cjpm.toml", "[package]\nname = \"demo\"\n".toArray())

        @Assert(shouldUseAutoProjectActionForBuild(["hap", "build", "--project", harmony], 2), true)
        @Assert(shouldUseAutoProjectActionForBuild(["hap", "build", "--project", ambiguous], 2), true)
        @Assert(shouldUseAutoProjectActionForBuild(["hap", "build", "--project", cangjie], 2), false)
    }

    @TestCase
    public func projectActionPlanAutoSelectsCangjieBuildPlanWhenAskedForPlan(): Unit {
        let root = "/tmp/hapcli-project-action-cangjie-auto-plan-test"
        createDirForTest(root)
        File.writeTo(root + "/cjpm.toml", "[package]\nname = \"demo\"\n".toArray())

        let options = resolveProjectActionOptions("build", [
            "hap",
            "build",
            "--project",
            root,
            "--plan"
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(containsForTest(json, "\"requestedPlatform\": \"auto\""), true)
        @Assert(containsForTest(json, "\"selectionStatus\": \"selected\""), true)
        @Assert(containsForTest(json, "\"projectKind\": \"cangjie\""), true)
        @Assert(containsForTest(json, "\"fixedCommandTemplates\": [\"cjpm build\"]"), true)
        @Assert(containsForTest(json, "\"toolchainValidationCommands\": [\"cjpm --version\", \"cjc --version\""), true)
    }

    @TestCase
    public func harmonyLocalExecutionMissingToolchainAsksForPathInsteadOfThrowingOpaqueFailure(): Unit {
        let root = "/tmp/hapcli-missing-tool-harmony-missing-toolchain-test"
        let config = root + "/happub.toml"
        let receipt = root + "/receipt.json"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/tmp/hapcli-missing-hvigorw\"\n" +
            "hdcPath = \"/tmp/hapcli-missing-hdc\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--config",
            config,
            "--receipt",
            receipt
        ], 2)
        let json = renderHarmonyReviewedExecutionJson(prepareHarmonyLocalDevAutoOptions(options), true)

        @Assert(containsForTest(json, "\"status\": \"missing-harmony-hvigorw\""), true)
        @Assert(containsForTest(json, "\"toolchainStatus\": \"missing-harmony-hvigorw\""), true)
        @Assert(containsForTest(json, "请提供可执行 hvigorw 路径"), true)
        @Assert(containsForTest(json, "/tmp/hapcli-missing-hvigorw --version"), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
    }

    @TestCase
    public func cangjieBuildWrapperMissingCjpmAsksForToolchainPath(): Unit {
        let root = "/tmp/hapcli-missing-tool-cangjie-missing-cjpm-test"
        createDirForTest(root)
        File.writeTo(root + "/cjpm.toml", "[package]\nname = \"demo\"\n".toArray())
        let options = HapBuildOptions()
        options.project = root
        let first = HapBuildCommandResult(127, "", "missing required command: cjpm")
        let json = renderBuildJsonFromResults(options, true, first, HapBuildCommandResult())

        @Assert(containsForTest(json, "\"status\": \"missing-cangjie-cjpm\""), true)
        @Assert(containsForTest(json, "\"toolchainStatus\": \"missing-cangjie-cjpm\""), true)
        @Assert(containsForTest(json, "请提供 cjpm 所在路径"), true)
        @Assert(containsForTest(json, "\"toolchainValidationCommands\": [\"cjpm --version\", \"cjc --version\""), true)
    }

    @TestCase
    public func projectActionInteractiveAnswerValidatesHarmonyToolPath(): Unit {
        let root = "/tmp/hapcli-tool-answer-harmony-interactive-answer-test"
        let fakeHvigorw = "/tmp/hapcli-tool-answer-fake-hvigorw"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(fakeHvigorw, "#!/bin/sh\n".toArray())

        let options = resolveProjectActionOptions("build", [
            "hap",
            "build",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--plan",
            "--toolchain-answer",
            "hvigorw=" + fakeHvigorw
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(containsForTest(json, "\"interactiveToolchainRequested\": true"), true)
        @Assert(containsForTest(json, "\"interactiveRepairStatus\": \"valid-answers-accepted\""), true)
        @Assert(containsForTest(json, "hvigorw=" + fakeHvigorw + " valid=true"), true)
        @Assert(containsForTest(json, "happub.toml: hvigorwPath = \\\"" + fakeHvigorw + "\\\""), true)
        @Assert(containsForTest(json, fakeHvigorw + " assembleApp --mode project"), true)
    }

    @TestCase
    public func projectActionToolchainAnswerValidatesCangjiePathWithoutPrompt(): Unit {
        let root = testTempPathForTest("hapcli-tool-answer-cangjie-toolchain-answer-test")
        let fakeCjpm = testTempPathForTest("hapcli-tool-answer-fake-cjpm")
        createDirForTest(root)
        File.writeTo(root + "/cjpm.toml", "[package]\nname = \"demo\"\n".toArray())
        File.writeTo(fakeCjpm, "#!/bin/sh\n".toArray())

        let options = resolveProjectActionOptions("build", [
            "hap",
            "build",
            "--project",
            root,
            "--platform",
            "cangjie",
            "--plan",
            "--toolchain-answer",
            "cjpm=" + fakeCjpm
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(containsForTest(json, "\"interactiveToolchainRequested\": true"), true)
        @Assert(containsForTest(json, "\"interactiveRepairStatus\": \"valid-answers-accepted\""), true)
        @Assert(containsForTest(json, "cjpm=" + fakeCjpm + " valid=true"), true)
        @Assert(containsForTest(json, escapeJson(cangjiePathRepairSuggestion(parentPath(fakeCjpm)))), true)
        @Assert(containsForTest(json, "\"fixedCommandTemplates\": [\"cjpm build\"]"), true)
    }

    @TestCase
    public func projectActionPlanRendersKmpTestAndLintTemplatesWithoutExecution(): Unit {
        let root = "/tmp/hapcli-project-action-kmp-test-plan-test"
        createDirForTest(root + "/src/commonMain")
        File.writeTo(root + "/build.gradle.kts", "plugins { kotlin(\"multiplatform\") }".toArray())
        File.writeTo(root + "/gradlew", "#!/bin/sh\n".toArray())

        let options = resolveProjectActionOptions("test", [
            "hap",
            "test",
            "--project",
            root,
            "--platform",
            "kmp",
            "--lint",
            "--plan"
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(containsForTest(json, "\"action\": \"test\""), true)
        @Assert(containsForTest(json, "\"projectKind\": \"kotlin-multiplatform\""), true)
        @Assert(containsForTest(json, "\"lintRequested\": true"), true)
        @Assert(containsForTest(json, "\"fixedCommandTemplates\": [\"export JAVA_HOME=<jdk17-home>\""), true)
        @Assert(containsForTest(json, "./gradlew test --no-daemon -Dkotlin.compiler.execution.strategy=in-process"), true)
        @Assert(containsForTest(json, "./gradlew lint --no-daemon -Dkotlin.compiler.execution.strategy=in-process"), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
    }

    @TestCase
    public func projectActionPlanNormalizesKmpMacosDevToDesktopRun(): Unit {
        let root = "/tmp/hapcli-project-action-kmp-macos-dev-plan-test"
        createDirForTest(root + "/composeApp/src/commonMain")
        File.writeTo(root + "/settings.gradle.kts", "include(\":composeApp\")".toArray())
        File.writeTo(root + "/composeApp/build.gradle.kts", "plugins { alias(libs.plugins.kotlinMultiplatform); alias(libs.plugins.composeMultiplatform) }\nkotlin { jvm() }".toArray())
        File.writeTo(root + "/gradlew", "#!/bin/sh\n".toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "kmp",
            "--target",
            "macos",
            "--plan"
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(options.target, "macos")
        @Assert(containsForTest(json, "\"target\": \"macos\""), true)
        @Assert(containsForTest(json, "\"deviceTool\": \"gradle\""), true)
        @Assert(containsForTest(json, "./gradlew :composeApp:run --no-daemon -Dkotlin.compiler.execution.strategy=in-process"), true)
        @Assert(containsForTest(json, "xcrun devicectl"), false)
    }

    @TestCase
    public func kmpDesktopDevExecutesFixedGradleRunTask(): Unit {
        let root = "/tmp/hapcli-kmp-desktop-local-execution-test"
        createDirForTest(root + "/composeApp/src/commonMain")
        File.writeTo(root + "/settings.gradle.kts", "include(\":composeApp\")".toArray())
        File.writeTo(root + "/composeApp/build.gradle.kts", "plugins { alias(libs.plugins.kotlinMultiplatform); alias(libs.plugins.composeMultiplatform) }\nkotlin { jvm() }".toArray())
        writeExecutableForTest(root + "/gradlew", "#!/bin/sh\nprintf '%s\\n' \"$*\"\nexit 0\n")

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "kmp",
            "--target",
            "desktop",
            "--verbose"
        ], 2)
        let json = runKmpLocalDesktopDevExecution(options)

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"kmp-desktop-dev-succeeded\""), true)
        @Assert(containsForTest(String.fromUtf8(File.readFrom(root + "/.hapData/logs/kmp-dev/kmp-desktop-run.stdout.log")), ":composeApp:run --no-daemon -Dkotlin.compiler.execution.strategy=in-process"), true)
    }

    @TestCase
    public func projectActionPlanRendersKmpIosDevTemplatesWithoutExecution(): Unit {
        let root = "/tmp/hapcli-project-action-kmp-ios-dev-plan-test"
        createDirForTest(root + "/composeApp/src/commonMain")
        createDirForTest(root + "/composeApp/src/iosMain")
        createDirForTest(root + "/iosApp/iosApp.xcodeproj")
        File.writeTo(root + "/settings.gradle.kts", "include(\":composeApp\")".toArray())
        File.writeTo(root + "/composeApp/build.gradle.kts", "plugins { alias(libs.plugins.kotlinMultiplatform); alias(libs.plugins.composeMultiplatform) }\nkotlin { iosArm64() }".toArray())
        File.writeTo(root + "/iosApp/iosApp.xcodeproj/project.pbxproj", "/* PBXNativeTarget \"iosApp\" */".toArray())
        File.writeTo(root + "/gradlew", "#!/bin/sh\n".toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "kmp",
            "--plan"
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(containsForTest(json, "\"projectKind\": \"kotlin-multiplatform\""), true)
        @Assert(containsForTest(json, "\"status\": \"adapter-plan-ready\""), true)
        @Assert(containsForTest(json, "export KONAN_DATA_DIR=$HOME/.gradle/.konan"), true)
        @Assert(containsForTest(json, ":composeApp:compileKotlinJvm :composeApp:compileKotlinIosArm64 :composeApp:linkDebugFrameworkIosArm64"), true)
        @Assert(containsForTest(json, "xcodebuild -showdestinations -project iosApp/iosApp.xcodeproj -scheme iosApp"), true)
        @Assert(containsForTest(json, "xcrun devicectl device info details --device <core-device-id>"), true)
        @Assert(containsForTest(json, "JAVA_HOME=<jdk17-home> KONAN_DATA_DIR=$HOME/.gradle/.konan KOTLIN_DAEMON_DATA_DIR=/tmp/kotlin-daemon-$USER xcodebuild"), true)
        @Assert(containsForTest(json, "xcrun devicectl device install app --device <core-device-id>"), true)
        @Assert(containsForTest(json, "Device is busy"), true)
        @Assert(containsForTest(json, "KMP+iOS 构建建议设置 JAVA_HOME=JDK17"), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
    }

    @TestCase
    public func kmpIosSignedArtifactRoutesToLocalExecutorAndReadsBundleId(): Unit {
        let root = "/tmp/hapcli-kmp-ios-artifact-route-test"
        let artifact = root + "/DemoApp.app"
        createDirForTest(root + "/composeApp/src/commonMain")
        createDirForTest(artifact)
        File.writeTo(root + "/settings.gradle.kts", "include(\":composeApp\")".toArray())
        File.writeTo(root + "/composeApp/build.gradle.kts", "plugins { alias(libs.plugins.kotlinMultiplatform) }\nkotlin { iosArm64() }".toArray())
        File.writeTo(artifact + "/Info.plist", ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>cn.example.kmpios</string></dict></plist>\n").toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--target",
            "ipados",
            "--artifact",
            artifact
        ], 2)

        @Assert(shouldUseKmpIosArtifactDevExecution(options), true)
        @Assert(readIosAppBundleIdentifier(artifact), "cn.example.kmpios")
        @Assert(isKmpIosTarget(options.target), true)
    }

    @TestCase
    public func kmpIosDevDefaultsToSourceBuildAndUseOldIsExplicit(): Unit {
        let root = "/tmp/hapcli-kmp-ios-source-default-route-test"
        createDirForTest(root + "/composeApp/src/commonMain")
        createDirForTest(root + "/iosApp/iosApp.xcodeproj")
        File.writeTo(root + "/settings.gradle.kts", "include(\":composeApp\")".toArray())
        File.writeTo(root + "/composeApp/build.gradle.kts", "plugins { alias(libs.plugins.kotlinMultiplatform) }\nkotlin { iosArm64() }".toArray())
        File.writeTo(root + "/iosApp/iosApp.xcodeproj/project.pbxproj", "DEVELOPMENT_TEAM = TEAM123456;".toArray())

        let latest = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--target",
            "ios"
        ], 2)
        @Assert(shouldUseKmpIosDevExecution(latest), true)
        @Assert(shouldUseKmpIosArtifactDevExecution(latest), false)
        @Assert(latest.useOld, false)

        let old = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--target",
            "ios",
            "--useOld",
            "--scheme",
            "ExplorerScheme",
            "--configuration",
            "Release",
            "--development-team",
            "TEAM654321",
            "--derived-data-path",
            "/tmp/hap-ios-derived"
        ], 2)
        @Assert(shouldUseKmpIosDevExecution(old), true)
        @Assert(shouldUseKmpIosArtifactDevExecution(old), true)
        @Assert(old.useOld, true)
        @Assert(old.iosScheme, "ExplorerScheme")
        @Assert(old.iosConfiguration, "Release")
        @Assert(old.iosDevelopmentTeam, "TEAM654321")
        @Assert(old.iosDerivedDataPath, "/tmp/hap-ios-derived")
    }

    @TestCase
    public func kmpIosPlanSeparatesLatestBuildFromOldArtifactMode(): Unit {
        let root = "/tmp/hapcli-kmp-ios-plan-mode-test"
        let artifact = root + "/iosApp/build/Build/Products/Debug-iphoneos/Explorer.app"
        createDirForTest(root + "/composeApp/src/commonMain")
        createDirForTest(root + "/iosApp/iosApp.xcodeproj")
        createDirForTest(artifact)
        File.writeTo(root + "/settings.gradle.kts", "include(\":composeApp\")".toArray())
        File.writeTo(root + "/composeApp/build.gradle.kts", "plugins { alias(libs.plugins.kotlinMultiplatform) }\nkotlin { iosArm64() }".toArray())
        File.writeTo(root + "/iosApp/iosApp.xcodeproj/project.pbxproj", "DEVELOPMENT_TEAM = TEAM123456;".toArray())

        let latestJson = renderProjectActionPlanJson(resolveProjectActionOptions("dev", [
            "hap", "dev", "--project", root, "--target", "ios", "--plan"
        ], 2))
        @Assert(containsForTest(latestJson, "-allowProvisioningUpdates"), true)
        @Assert(containsForTest(latestJson, "CODE_SIGN_STYLE=Automatic"), true)
        @Assert(containsForTest(latestJson, "id=<xcode-device-udid>"), true)

        let oldJson = renderProjectActionPlanJson(resolveProjectActionOptions("dev", [
            "hap", "dev", "--project", root, "--target", "ios", "--use-old", "--artifact", artifact, "--plan"
        ], 2))
        @Assert(containsForTest(oldJson, artifact), true)
        @Assert(containsForTest(oldJson, "-allowProvisioningUpdates"), false)
    }

    @TestCase
    public func kmpIosDeviceIdentifierShapeRejectsAmbiguousTokens(): Unit {
        @Assert(isUuidShaped("123E4567-E89B-42D3-A456-426614174000"), true)
        @Assert(isUuidShaped("00008100-001234567890001E"), false)
        @Assert(isUuidShaped("Demo Tablet"), false)
    }

    @TestCase
    public func kmpIosDeviceListDistinguishesAvailableUnavailableAndAmbiguousDevices(): Unit {
        let available = parseKmpIosDeviceList(
            "Name         Hostname                                     Identifier                             State\n" +
            "Demo Tablet   device.coredevice.local                       123E4567-E89B-42D3-A456-426614174000   available (paired)\n"
        )
        @Assert(available.status, "ios-device-selected")
        @Assert(available.selectedDevice, "123E4567-E89B-42D3-A456-426614174000")

        let unavailable = parseKmpIosDeviceList(
            "Demo Tablet   device.coredevice.local                       123E4567-E89B-42D3-A456-426614174000   unavailable\n"
        )
        @Assert(unavailable.status, "ios-device-unavailable")
        @Assert(unavailable.selectedDevice, "")
        @Assert(unavailable.observedDevice, "123E4567-E89B-42D3-A456-426614174000")

        let ambiguous = parseKmpIosDeviceList(
            "PadOne   one.coredevice.local   123E4567-E89B-42D3-A456-426614174000   available (paired)\n" +
            "PadTwo   two.coredevice.local   1A2B3C4D-1111-2222-3333-444455556666   available (paired)\n"
        )
        @Assert(ambiguous.status, "ios-device-selection-ambiguous")
        @Assert(ambiguous.selectedDevice, "")
    }

    @TestCase
    public func kmpIosUnavailableDetailsClassifyCoreDeviceReadiness(): Unit {
        @Assert(classifyKmpIosUnavailableDetails("pairingState: unpaired"), "ios-device-not-paired")
        @Assert(classifyKmpIosUnavailableDetails("ddiServicesAvailable: false\ntunnelState: unavailable"), "ios-device-coredevice-services-unavailable")
        @Assert(classifyKmpIosUnavailableDetails("pairingState: paired\ntunnelState: unavailable"), "ios-device-tunnel-unavailable")
    }

    @TestCase
    public func kmpIosDeviceDetailsAndSigningFailuresAreClassified(): Unit {
        let details = "• identifier: 123E4567-E89B-42D3-A456-426614174000\n    • udid: 00008100-001234567890001E\n    • name: Demo Tablet\n"
        @Assert(extractKmpIosDetailValue(details, "identifier:"), "123E4567-E89B-42D3-A456-426614174000")
        @Assert(extractKmpIosDetailValue(details, "udid:"), "00008100-001234567890001E")
        @Assert(extractKmpIosDetailValue(details, "name:"), "Demo Tablet")
        @Assert(classifyKmpIosSourceBuildFailure("No Accounts: Add an account in Xcode"), "ios-signing-account-unavailable")
        @Assert(classifyKmpIosSourceBuildFailure("No signing certificate Apple Development found"), "ios-signing-identity-unavailable")
        @Assert(classifyKmpIosSourceBuildFailure("No profiles for 'cn.example.app' were found"), "ios-provisioning-profile-unavailable")
        @Assert(classifyKmpIosSourceBuildFailure("Unable to find a destination matching id"), "ios-xcode-destination-unavailable")
        @Assert(extractLastParenthesizedText("Apple Development: User (TEAM123456)"), "TEAM123456")
    }

    @TestCase
    public func kmpIosOldArtifactDiscoveryRequiresOneAppBundle(): Unit {
        let singleOutput = testTempPathForTest("hapcli-kmp-ios-old-artifact-single/Debug-iphoneos")
        createDirForTest(singleOutput + "/Explorer.app")
        @Assert(findKmpIosAppArtifact(singleOutput), singleOutput + "/Explorer.app")
        let ambiguousOutput = testTempPathForTest("hapcli-kmp-ios-old-artifact-ambiguous/Debug-iphoneos")
        createDirForTest(ambiguousOutput + "/Explorer.app")
        createDirForTest(ambiguousOutput + "/Second.app")
        @Assert(findKmpIosAppArtifact(ambiguousOutput), "")
    }

    @TestCase
    public func hapDevDoesNotRunHarmonyExecutorForKmpProject(): Unit {
        let root = "/tmp/hapcli-project-action-kmp-dev-route-test"
        createDirForTest(root + "/composeApp/src/commonMain")
        File.writeTo(root + "/settings.gradle.kts", "include(\":composeApp\")".toArray())
        File.writeTo(root + "/composeApp/build.gradle.kts", "plugins { alias(libs.plugins.kotlinMultiplatform) }".toArray())
        File.writeTo(root + "/gradlew", "#!/bin/sh\n".toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root
        ], 2)

        @Assert(shouldUseHarmonyLocalDevExecution(options), false)
    }

    @TestCase
    public func projectActionPlanRendersHarmonyDevUsbFirstTemplateWithoutExecution(): Unit {
        let root = "/tmp/hapcli-project-action-harmony-dev-plan-test"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--device",
            "auto",
            "--listen",
            "--allow-wireless",
            "--device-memory",
            root + "/.hapData/missing-device-memory.json",
            "--plan"
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(containsForTest(json, "\"action\": \"dev\""), true)
        @Assert(containsForTest(json, "\"projectKind\": \"harmonyos\""), true)
        @Assert(containsForTest(json, "\"listenRequested\": true"), true)
        @Assert(containsForTest(json, "\"allowWirelessRequested\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"memory-not-found\""), true)
        @Assert(containsForTest(json, "\"wirelessReconnectAllowed\": false"), true)
        @Assert(containsForTest(json, "\"wirelessReceiptTrusted\": false"), true)
        @Assert(containsForTest(json, "\"usbFirstRequired\": true"), true)
        @Assert(containsForTest(json, "\"trustedDeviceMemoryRequired\": true"), true)
        let hvigorwDefault = "hvigorw"
        let hdcDefault = "hdc"
        @Assert(containsForTest(json, "\"fixedCommandTemplates\": [\"" + hdcDefault + " list targets\", \"" + hvigorwDefault + " assembleApp --mode project -p product=default -p buildMode=debug\", \"" + hdcDefault + " install -r " + root + "/Product/build/default/outputs/default/Product-default-signed.hap\", \"" + hdcDefault + " shell aa start -b <bundle> -a <ability>\", \"" + hdcDefault + " hilog\"]"), true)
    }

    @TestCase
    public func harmonyDeviceAliasResolvesFromTomlAndLocksHdcTarget(): Unit {
        let root = "/tmp/hapcli-harmony-device-alias-plan-test"
        let config = root + "/happub.toml"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(config, (
            "bundle = \"cn.example.alias\"\n" +
            "ability = \"EntryAbility\"\n" +
            "[harmony.deviceAliases]\n" +
            "mate60 = \"USB-ALIAS-001\"\n"
        ).toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--device",
            "mate60",
            "--plan"
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(containsForTest(json, "hdc -t USB-ALIAS-001 install -r"), true)
        @Assert(containsForTest(json, "hdc -t USB-ALIAS-001 shell aa start"), true)
    }

    @TestCase
    public func projectActionOptionsAcceptVerboseAliasAndOneShotReceipt(): Unit {
        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            "/tmp/hapcli-dev-output-options-test",
            "-v",
            "--write-receipt"
        ], 2)
        let prepared = prepareHarmonyLocalDevAutoOptions(options)

        @Assert(prepared.verbose, true)
        @Assert(prepared.receiptRequested, true)
        @Assert(prepared.receipt, "/tmp/hapcli-dev-output-options-test/.hapData/receipts/harmony-dev-latest.receipt.json")
    }

    @TestCase
    public func harmonyLocalDevAutoDoesNotDefaultReceiptUnlessRequested(): Unit {
        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            "/tmp/hapcli-dev-output-no-receipt-test"
        ], 2)
        let prepared = prepareHarmonyLocalDevAutoOptions(options)

        @Assert(prepared.localDevAuto, true)
        @Assert(prepared.receiptRequested, false)
        @Assert(prepared.receipt, "")
        @Assert(prepared.logDir, "/tmp/hapcli-dev-output-no-receipt-test/.hapData/logs/harmony-dev")
    }

    @TestCase
    public func projectActionPlanAllowsHarmonyWirelessTemplateOnlyWithTrustedReceipt(): Unit {
        let root = "/tmp/hapcli-project-action-harmony-wireless-plan-test"
        let receipt = "/tmp/hapcli-project-action-harmony-wireless.receipt.json"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(receipt, "{\"schema\":\"happub-hapcli-harmony-wireless-receipt-v0\",\"ok\":true,\"target\":\"USB001\",\"ip\":\"192.0.2.40\",\"port\":\"5555\",\"stage\":\"complete\",\"usbFirstProof\":true,\"wirelessReconnectActionTaken\":true,\"deviceActionTaken\":true,\"networkActionTaken\":true}".toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--allow-wireless",
            "--wireless-receipt",
            receipt,
            "--plan"
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(containsForTest(json, "\"status\": \"adapter-plan-ready\""), true)
        @Assert(containsForTest(json, "\"wirelessReceiptTrusted\": true"), true)
        @Assert(containsForTest(json, "\"trustedWirelessIp\": \"192.0.2.40\""), true)
        @Assert(containsForTest(json, "\"trustedWirelessPort\": \"5555\""), true)
        @Assert(containsForTest(json, "\"wirelessReconnectAllowed\": true"), true)
        let hvigorwDefault = "hvigorw"
        let hdcDefault = "hdc"
        @Assert(containsForTest(json, "\"fixedCommandTemplates\": [\"" + hdcDefault + " list targets\", \"" + hdcDefault + " tconn 192.0.2.40:5555\", \"" + hvigorwDefault + " assembleApp --mode project -p product=default -p buildMode=debug\", \"" + hdcDefault + " install -r " + root + "/Product/build/default/outputs/default/Product-default-signed.hap\", \"" + hdcDefault + " shell aa start -b <bundle> -a <ability>\"]"), true)
    }

    @TestCase
    public func projectActionPlanAllowsHarmonyWirelessTemplateWithTrustedDeviceMemory(): Unit {
        let root = "/tmp/hapcli-project-action-harmony-device-memory-plan-test"
        let memory = "/tmp/hapcli-project-action-harmony-device-memory-plan.json"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(memory, ("{\"schema\":\"happub-hapcli-harmony-device-memory-v0\",\"trusted\":true,\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"target\":\"USB-MEM-PLAN\",\"ip\":\"192.168.0.140\",\"port\":\"5601\",\"proofReceiptPath\":\"/tmp/hap-proof.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-06-30T14:55:00+08:00\",\"staleAfterSeconds\":\"3153600000\"}").toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--allow-wireless",
            "--device-memory",
            memory,
            "--plan"
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(containsForTest(json, "\"status\": \"adapter-plan-ready\""), true)
        @Assert(containsForTest(json, "\"wirelessTrustSource\": \"device-memory\""), true)
        @Assert(containsForTest(json, "\"deviceMemoryTrusted\": true"), true)
        @Assert(containsForTest(json, "\"trustedWirelessIp\": \"192.168.0.140\""), true)
        @Assert(containsForTest(json, "\"wirelessReconnectAllowed\": true"), true)
        let hvigorwDefault = "hvigorw"
        let hdcDefault = "hdc"
        @Assert(containsForTest(json, "\"fixedCommandTemplates\": [\"" + hdcDefault + " list targets\", \"" + hdcDefault + " tconn 192.168.0.140:5601\", \"" + hvigorwDefault + " assembleApp --mode project -p product=default -p buildMode=debug\""), true)
    }

    @TestCase
    public func projectActionPlanRendersHarmonyPushArtifactTemplateWithoutExecution(): Unit {
        let root = "/tmp/hapcli-project-action-harmony-push-plan-test"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())

        let options = resolveProjectActionOptions("push", [
            "hap",
            "push",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--artifact",
            "/tmp/app.hap",
            "--plan"
        ], 2)
        let json = renderProjectActionPlanJson(options)

        @Assert(containsForTest(json, "\"action\": \"push\""), true)
        @Assert(containsForTest(json, "\"artifact\": \"/tmp/app.hap\""), true)
        let hdcDefault = "hdc"
        @Assert(containsForTest(json, "\"fixedCommandTemplates\": [\"" + hdcDefault + " list targets\", \"" + hdcDefault + " install -r /tmp/app.hap\"]"), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
    }

    @TestCase
    public func harmonyReviewedExecutionRejectsMissingReviewToken(): Unit {
        let root = "/tmp/hapcli-reviewed-exec-reviewed-exec-missing-review-test"
        let receipt = "/tmp/hapcli-reviewed-exec-reviewed-exec-missing-review.receipt.json"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())

        let options = resolveProjectActionOptions("build", [
            "hap",
            "build",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--execute-reviewed",
            "--receipt",
            receipt
        ], 2)
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-harmony-reviewed-execution-receipt-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"missing-review-token\""), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"changedPaths\": []"), true)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(2))
    }

}
