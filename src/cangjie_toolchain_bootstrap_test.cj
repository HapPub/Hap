package hapcli

import std.fs.File
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class HapCangjieToolchainBootstrapTest {
    @TestCase
    public func routesRegionsAndAllowlistedAccelerators(): Unit {
        let global = cangjieBootstrapTransferCandidates(
            "global",
            "https://github.com/HapPub/CangjieSDK-Mirror/releases/download/v/a.tar.gz",
            "https://gitcode.com/Cangjie/nightly_build/releases/download/v/a.tar.gz",
            "auto",
            defaultCangjieDownloadAccelerators()
        )
        let china = cangjieBootstrapTransferCandidates(
            "zh-cn",
            "https://github.com/HapPub/CangjieSDK-Mirror/releases/download/v/a.tar.gz",
            "https://gitcode.com/Cangjie/nightly_build/releases/download/v/a.tar.gz",
            "auto",
            defaultCangjieDownloadAccelerators()
        )
        @Assert(global[0].startsWith("https://github.com/"), true)
        @Assert(global[1].startsWith("https://ghfast.top/https://github.com/"), true)
        @Assert(china[0].startsWith("https://gitcode.com/"), true)
        @Assert(rewriteGithubDownloadUrl("https://evil.example", global[0]), "")
    }

    @TestCase
    public func resolvesHostTargetSdkProfilesAndOhosAlias(): Unit {
        @Assert(canonicalTargetName("ohos"), "ohos-arm64")
        @Assert(resolveCangjieBootstrapSdkPlatform("Linux", "x86_64", "ohos"), "linux-x64-ohos")
        @Assert(resolveCangjieBootstrapSdkPlatform("Darwin", "arm64", "ohos"), "mac-aarch64")
        @Assert(cangjieBootstrapStdxPrefix("ohos", "1.3.0-alpha.x"), "cangjie-stdx-ohos-aarch64-1.3.0-alpha.x")
    }

    @TestCase
    public func validatesManifestAndExactChecksums(): Unit {
        let tag = "1.3.0-alpha.fixture"
        let sdk = "cangjie-sdk-linux-x64-ohos-" + tag + ".tar.gz"
        let stdx = "cangjie-stdx-ohos-aarch64-" + tag + ".1.zip"
        let manifest = "{\"schema\": \"happub-cangjie-sdk-mirror-manifest-v1\",\"ok\": true,\"status\": \"mirrored-verbatim\",\"upstream\":{\"tag\":\"" + tag + "\"},\"mirror\":{\"tag\":\"" + tag + "\"},\"assets\":[" +
            "{\"name\": \"" + sdk + "\",\"classification\":\"sdk\",\"mirrorUrl\":\"https://github.com/HapPub/CangjieSDK-Mirror/releases/download/" + tag + "/" + sdk + "\",\"sourceUrl\":\"https://gitcode.com/Cangjie/nightly_build/releases/download/" + tag + "/" + sdk + "\",\"sha256\":\"" + "a" * 64 + "\"}," +
            "{\"name\": \"" + stdx + "\",\"classification\":\"stdx\",\"mirrorUrl\":\"https://github.com/HapPub/CangjieSDK-Mirror/releases/download/" + tag + "/" + stdx + "\",\"sourceUrl\":\"https://gitcode.com/Cangjie/nightly_build/releases/download/" + tag + "/" + stdx + "\",\"sha256\":\"" + "b" * 64 + "\"}],\"checksumPolicy\":{\"authority\": \"mirror-computed-sha256\"}}"
        @Assert(validateCangjieMirrorManifest(manifest, tag), true)
        @Assert(resolveCangjieManifestAsset(manifest, sdk, "sdk").valid, true)
        @Assert(resolveCangjieManifestAssetByPrefix(manifest, "cangjie-stdx-ohos-aarch64-" + tag, "stdx").valid, true)
        @Assert(validateCangjieMirrorManifest(manifest, "other"), false)
    }

    @TestCase
    public func resolvesNewestNonDraftRelease(): Unit {
        let releases = "[{\"tag_name\":\"draft\",\"draft\":true},{\"tag_name\":\"1.3.0-alpha.latest\",\"draft\":false}]"
        @Assert(resolveLatestCangjieMirrorTag(releases), "1.3.0-alpha.latest")
    }

    @TestCase
    public func cacheCompletionMarkersBindVersionAndAssetChecksum(): Unit {
        let root = "/tmp/hapcli-bootstrap-completion-marker-test"
        let marker = root + "/.hap-complete"
        let version = "1.3.0-alpha.fixture"
        let checksum = "a" * 64
        createDirForTest(root)
        writeBootstrapCompletionMarker(marker, version, checksum)

        @Assert(bootstrapCompletionMarkerMatches(marker, version, checksum), true)
        @Assert(bootstrapCompletionMarkerMatches(marker, "other", checksum), false)
        @Assert(bootstrapCompletionMarkerMatches(marker, version, "b" * 64), false)
    }

    @TestCase
    public func bootstrapSuccessOwnsReceiptStatusAndQuestions(): Unit {
        let root = "/tmp/hapcli-bootstrap-receipt-success-test"
        createDirForTest(root)
        File.writeTo(root + "/cjpm.toml", "[package]\nname = \"demo\"\n".toArray())
        let options = HapBuildOptions()
        options.project = root
        options.target = "ohos-arm64"
        options.requestedTarget = "ohos"
        options.toolchainBootstrapAttempted = true
        options.toolchainBootstrapOk = true
        options.toolchainBootstrapStatus = "manifest-bound-toolchain-cache-hit"
        options.toolchainBootstrapVersion = "1.3.0-alpha.fixture"
        options.toolchainBootstrapCacheRootSource = "configured"
        options.toolchainBootstrapCacheHit = true
        options.toolchainBootstrapChecksumVerified = false
        options.toolchainBootstrapDiagnostic = "cache hit accepted by manifest-bound envsetup and .hap-complete markers; installed files were not rehashed"

        let json = renderBuildJsonFromResults(options, false, HapBuildCommandResult(0, "ok", ""), HapBuildCommandResult())

        @Assert(containsForTest(json, "\"status\": \"build-succeeded-after-toolchain-bootstrap\""), true)
        @Assert(containsForTest(json, "\"toolchainStatus\": \"bootstrap-provided-cangjie-toolchain\""), true)
        @Assert(containsForTest(json, "\"toolchainQuestions\": []"), true)
        @Assert(containsForTest(json, "\"cjpmTarget\": \"aarch64-linux-ohos\""), true)
        @Assert(containsForTest(json, "\"toolchainBootstrapCacheHit\": true"), true)
        @Assert(containsForTest(json, "\"toolchainBootstrapChecksumVerified\": false"), true)
        @Assert(containsForTest(json, "installed files were not rehashed"), true)
        let summary = renderCjpmExecutionHumanSummary(json)
        @Assert(containsForTest(summary, "Toolchain: Hap bootstrap 1.3.0-alpha.fixture (manifest-bound-toolchain-cache-hit)"), true)
        @Assert(containsForTest(summary, "Toolchain cache source: configured"), true)
    }

    @TestCase
    public func bootstrapRetryPreventsSecondDoctorfixRetry(): Unit {
        let options = HapBuildOptions()
        let config = HapBuildConfig()
        let profile = HapStdxProfile()
        config.alwaysFix = true
        profile.target = "aarch64-linux-ohos"
        let first = HapBuildCommandResult(1, "", "missing stdx")
        let bootstrapRetry = HapBuildCommandResult(0, "ok", "")

        @Assert(shouldAttemptBuildDoctorfixRetry(options, config, profile, first, bootstrapRetry, true), false)
        @Assert(shouldAttemptBuildDoctorfixRetry(options, config, profile, first, HapBuildCommandResult(), true), true)
    }
}
