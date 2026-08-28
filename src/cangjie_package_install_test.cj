package hapcli

import std.fs.{Directory, File, exists}
import std.process.executeWithOutput
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class HapCangjiePackageInstallTest {
    @TestCase
    public func parsesAliasesLatestLtsAndExactSts(): Unit {
        let alias = resolveCangjiePackageInstallOptions(["hap", "install", "cangjie", "--target", "macos-arm64", "--install-root", "/tmp/hc072-alias", "--plan"], 2)
        @Assert(alias.valid, true)
        @Assert(alias.requestedPackage, "cangjie")
        @Assert(alias.resolvedPackage, "cangjie-sdk")
        @Assert(alias.resolvedVersion, "1.0.5")
        @Assert(alias.releaseChannel, "LTS")

        let latest = resolveCangjiePackageInstallOptions(["hap", "install", "cangjie-sdk@latest", "--target=linux-amd64", "--install-root=/tmp/hc072-latest", "--plan"], 2)
        @Assert(latest.valid, true)
        @Assert(latest.assetVersion, "1.0.5")
        @Assert(latest.platform, "linux-x64")

        let sts = resolveCangjiePackageInstallOptions(["hap", "install", "cangjie-stdx@1.1.3", "--target", "macos-arm64", "--install-root", "/tmp/hc072-sts", "--plan"], 2)
        @Assert(sts.valid, true)
        @Assert(sts.resolvedVersion, "1.1.3")
        @Assert(sts.assetVersion, "1.1.3.1")
        @Assert(sts.releaseChannel, "STS")
    }

    @TestCase
    public func rejectsMalformedUnknownAndUnsupportedSpecs(): Unit {
        @Assert(resolveCangjiePackageInstallOptions(["hap", "install", "cangjie@"], 2).errorCode, "invalid-package-spec")
        @Assert(resolveCangjiePackageInstallOptions(["hap", "install", "cangjie@1.1.3@x"], 2).errorCode, "invalid-package-spec")
        @Assert(resolveCangjiePackageInstallOptions(["hap", "install", "cangjie-runtime"], 2).errorCode, "unknown-cangjie-package")
        @Assert(resolveCangjiePackageInstallOptions(["hap", "install", "cangjie@9.9.9"], 2).errorCode, "unsupported-cangjie-version")
        @Assert(resolveCangjiePackageInstallOptions(["hap", "install", "cangjie", "--install-root", "/usr/local/cangjie"], 2).errorCode, "install-root-not-private")
        @Assert(resolveCangjiePackageInstallOptions(["hap", "install", "cangjie", "--install-root", "/tmp/cangjie-private", "--receipt", "/tmp/outside.json"], 2).errorCode, "receipt-outside-install-root")
    }

    @TestCase
    public func resolvesChecksumGatedOfficialCatalogWithoutConflatingPackages(): Unit {
        let sdk = resolveOfficialCangjieSdkInstallAsset("1.1.3", "mac-aarch64")
        @Assert(sdk.valid, true)
        @Assert(sdk.name, "cangjie-sdk-mac-aarch64-1.1.3.tar.gz")
        @Assert(sdk.sha256, "7eff8d3b9119535cf3d05cb81526c5df391137dce908d744449f4edb99da3199")
        @Assert(sdk.checksumAuthority, "cangjie-lang-official-sha256")

        let stdx = resolveOfficialCangjieStdxInstallAsset("1.1.3.1", "mac-aarch64")
        @Assert(stdx.valid, true)
        @Assert(stdx.name, "cangjie-stdx-mac-aarch64-1.1.3.1.zip")
        @Assert(stdx.sha256, "97b21c94907eade61c031567694da9e9f41121824ea9f5276f0f3975b3cb55ef")
        @Assert(stdx.checksumAuthority, "hapcli-pinned-official-release-download-sha256")
        @Assert(stdx.mirrorUrl.startsWith("https://github.com/HapPub/CangjieSDK-Mirror/releases/download/"), true)
        @Assert(stdx.sourceUrl.startsWith("https://gitcode.com/Cangjie/cangjie_stdx/releases/download/"), true)
        @Assert(resolveOfficialCangjieSdkInstallAsset("1.0.5", "mac-x64").valid, false)
        @Assert(resolveOfficialCangjieStdxInstallAsset("1.0.5.1", "mac-x64").valid, false)
    }

    @TestCase
    public func regionRoutePrependsAllowlistedAcceleratorsOnlyForZhCn(): Unit {
        let mirror = "https://github.com/HapPub/CangjieSDK-Mirror/releases/download/1.1.3/a.tar.gz"
        let source = "https://cangjie-lang.cn/a.tar.gz"
        let china = cangjiePackageTransferCandidates("zh-cn", mirror, source)
        let global = cangjiePackageTransferCandidates("global", mirror, source)
        @Assert(china[0], "https://ghfast.top/" + mirror)
        @Assert(china[1], "https://ghproxy.link/" + mirror)
        @Assert(china[2], mirror)
        @Assert(china[3], source)
        @Assert(global[0], mirror)
        @Assert(global[1], source)
    }

    @TestCase
    public func planReportsPinnedLtsAndTakesNoAction(): Unit {
        let options = resolveCangjiePackageInstallOptions(["hap", "install", "cangjie@latest", "--target", "macos-arm64", "--install-root", "/tmp/hc072-plan-no-mutation", "--plan"], 2)
        let json = renderCangjiePackageInstallPlanJson(options)
        @Assert(containsText(json, "\"status\": \"planned\""), true)
        @Assert(containsText(json, "\"releaseChannel\": \"LTS\""), true)
        @Assert(containsText(json, "\"latestPolicy\": \"latest-is-pinned-lts\""), true)
        @Assert(containsText(json, "\"downloadActionTaken\": false"), true)
        @Assert(containsText(json, "\"installActionTaken\": false"), true)
        @Assert(containsText(json, "\"systemMutation\": false"), true)
    }

    @TestCase
    public func fixtureTransactionRejectsChecksumThenInstallsAndHitsMarkerCache(): Unit {
        let fixture = "/tmp/hapcli-package-install-fixture"
        let payload = fixture + "/payload/cangjie"
        let archive = fixture + "/fixture-sdk.tar.gz"
        let installRoot = fixture + "/install"
        createDirForTest(payload)
        File.writeTo(payload + "/envsetup.sh", "export CANGJIE_HOME=fixture\n".toArray())
        let (tarCode, _, _) = executeWithOutput("tar", ["-czf", archive, "-C", fixture + "/payload", "cangjie"])
        @Assert(tarCode, Int64(0))
        let (shaCode, shaOut, _) = executeWithOutput("shasum", ["-a", "256", archive])
        @Assert(shaCode, Int64(0))
        let exactSha = firstBootstrapAsciiToken(String.fromUtf8(shaOut))

        let options = HapCangjiePackageInstallOptions()
        options.valid = true
        options.requestedSpec = "cangjie@fixture"
        options.requestedPackage = "cangjie"
        options.resolvedPackage = "cangjie-sdk"
        options.requestedVersion = "fixture"
        options.resolvedVersion = "fixture"
        options.assetVersion = "fixture"
        options.releaseChannel = "fixture"
        options.target = "macos-arm64"
        options.platform = "mac-aarch64"
        options.installRoot = installRoot
        options.receipt = fixture + "/receipt.json"

        // Keep this transaction replayable even when a previous focused test left
        // a valid final tree behind: a stale marker must force the verified
        // archive path to run again before the cache-hit assertion below.
        let finalRoot = installRoot + "/cangjie/cangjie-sdk/fixture/macos-arm64"
        createDirForTest(finalRoot)
        File.writeTo(finalRoot + "/.hap-complete", "stale\n".toArray())

        let rejectedAsset = HapCangjiePackageInstallAsset()
        rejectedAsset.valid = true
        rejectedAsset.packageName = "cangjie-sdk"
        rejectedAsset.name = "fixture-sdk.tar.gz"
        rejectedAsset.version = "fixture"
        rejectedAsset.url = "file://" + archive
        rejectedAsset.mirrorUrl = "file://" + archive
        rejectedAsset.sha256 = "0" * 64
        let rejected = installResolvedCangjiePackage(options, rejectedAsset)
        @Assert(rejected.ok, false)
        @Assert(rejected.status, "checksum-rejected")

        let asset = HapCangjiePackageInstallAsset()
        asset.valid = true
        asset.packageName = "cangjie-sdk"
        asset.name = "fixture-sdk.tar.gz"
        asset.version = "fixture"
        asset.url = "file://" + archive
        asset.mirrorUrl = "file://" + archive
        asset.sha256 = exactSha
        let installed = installResolvedCangjiePackage(options, asset)
        @Assert(installed.diagnostic, "")
        @Assert(installed.status, "verified-and-installed")
        @Assert(installed.ok, true)
        @Assert(installed.checksumVerified, true)
        @Assert(installed.installActionTaken, true)
        @Assert(exists(installed.envsetupPath), true)

        let cached = installResolvedCangjiePackage(options, asset)
        @Assert(cached.ok, true)
        @Assert(cached.status, "verified-marker-cache-hit")
        @Assert(cached.cacheHit, true)
        @Assert(cached.downloadActionTaken, false)
        @Assert(cached.installActionTaken, false)
    }
}
