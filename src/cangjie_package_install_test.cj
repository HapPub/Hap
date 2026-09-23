package hapcli

import std.collection.ArrayList
import std.fs.{Directory, File, exists, removeIfExists}
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
    public func explicitRoutesAreExactAndDoNotSilentlyFallback(): Unit {
        let asset = resolveOfficialCangjieSdkInstallAsset("1.1.3", "mac-aarch64")
        for (route in ["mirror", "ghfast", "ghproxy", "official"]) {
            let options = resolveCangjiePackageInstallOptions(["hap", "install", "cangjie@1.1.3", "--target", "macos-arm64", "--install-root", "/tmp/hc073-route", "--route", route, "--plan"], 2)
            @Assert(options.valid, true)
            @Assert(options.selectedRoute, route)
            let candidates = cangjiePackageTransferCandidatesForOptions(options, asset)
            @Assert(candidates.size, Int64(1))
            @Assert(candidates[0], cangjieInstallRouteUrl(route, asset))
        }
        @Assert(resolveCangjiePackageInstallOptions(["hap", "install", "cangjie", "--route", "unknown"], 2).errorCode, "invalid-install-route")
        @Assert(resolveCangjiePackageInstallOptions(["hap", "install", "cangjie", "--route", "auto", "--region", "global"], 2).errorCode, "conflicting-install-route")
        @Assert(resolveCangjiePackageInstallOptions(["hap", "install", "cangjie", "--proxy", "--plan"], 2).networkMode, "proxy")
    }

    @TestCase
    public func latencyParsingAndFastestSuccessfulRouteAreDeterministic(): Unit {
        @Assert(parseCurlTimeTotalMilliseconds("0.123"), Int64(123))
        @Assert(parseCurlTimeTotalMilliseconds("1.002901"), Int64(1002))
        @Assert(parseCurlTimeTotalMilliseconds("2"), Int64(2000))
        @Assert(parseCurlTimeTotalMilliseconds("not-a-time"), Int64(-1))

        let probes = ArrayList<HapCangjieRouteProbe>()
        let failed = HapCangjieRouteProbe()
        failed.route = "mirror"
        failed.status = "unreachable"
        probes.add(failed)
        let slow = HapCangjieRouteProbe()
        slow.route = "official"
        slow.ok = true
        slow.latencyMs = 230
        slow.status = "observed"
        probes.add(slow)
        let fast = HapCangjieRouteProbe()
        fast.route = "ghfast"
        fast.ok = true
        fast.latencyMs = 88
        fast.status = "observed"
        probes.add(fast)
        @Assert(fastestCangjieInstallRouteIndex(probes), Int64(2))
        let rows = renderCangjieInstallRouteRows(probes, 2)
        @Assert(containsText(rows[0], "88 ms"), true)
        @Assert(containsText(renderCangjieInstallRouteProbesJson(probes), "\"status\":\"unreachable\""), true)
    }

    @TestCase
    public func exactCommandOwnsTuiButExplicitAndPlanCommandsDoNot(): Unit {
        @Assert(shouldOfferCangjieInstallTui(["hap", "install", "cangjie"]), true)
        @Assert(shouldOfferCangjieInstallTui(["hap", "install", "cangjie@1.1.3"]), false)
        @Assert(shouldOfferCangjieInstallTui(["hap", "install", "cangjie", "--plan"]), false)
        let frame = renderCangjieInstallTuiFrame("Choose version", ["1.0.5 LTS", "1.1.3 STS"], 0, "Enter select")
        @Assert(containsText(frame, "Hap · Cangjie installer"), true)
        @Assert(containsText(frame, "1.0.5 LTS"), true)
    }

    @TestCase
    public func parsesDynamicNightlyAliasAndExactTagWithoutPlanNetwork(): Unit {
        let alias = resolveCangjiePackageInstallOptions(["hap", "install", "cangjie@nightly", "--target", "macos-arm64", "--install-root", "/tmp/hc074-nightly", "--plan"], 2)
        @Assert(alias.valid, true)
        @Assert(alias.dynamicRequested, true)
        @Assert(alias.releaseChannel, "NIGHTLY")
        @Assert(alias.resolvedVersion, "")
        let plan = renderCangjiePackageInstallPlanJson(alias)
        @Assert(containsText(plan, "\"status\": \"planned-dynamic-resolution\""), true)
        @Assert(containsText(plan, "\"catalogActionTaken\": false"), true)

        let exactTag = "1.3.0-alpha.20260828010050"
        let exact = resolveCangjiePackageInstallOptions(["hap", "install", "cangjie@" + exactTag, "--target", "macos-arm64", "--install-root", "/tmp/hc074-exact", "--plan"], 2)
        @Assert(exact.valid, true)
        @Assert(exact.resolvedVersion, exactTag)
        @Assert(exact.assetVersion, exactTag)
        @Assert(containsText(renderCangjiePackageInstallPlanJson(exact), cangjieNightlyManifestUrl(exactTag)), true)
        @Assert(resolveCangjiePackageInstallOptions(["hap", "install", "cangjie@1.3.0-alpha.today"], 2).errorCode, "unsupported-cangjie-version")
    }

    @TestCase
    public func validatesSupplementaryDictionaryAndMirrorNightlyMetadata(): Unit {
        let version = "1.3.0-alpha.20260828010050"
        let manifestUrl = cangjieNightlyManifestUrl(version)
        let dictionary = "{\"schema\": \"happub-hapcli-cangjie-install-catalog-v1\",\"releaseLines\":[{\"version\":\"" + version + "\",\"channel\": \"NIGHTLY\",\"publishedAt\":\"2026-08-28T02:33:47Z\",\"manifestUrl\":\"" + manifestUrl + "\"}]}"
        let fromDictionary = resolveCangjieNightlyFromSupplementaryCatalog(dictionary)
        @Assert(fromDictionary.valid, true)
        @Assert(fromDictionary.version, version)
        @Assert(fromDictionary.publishedAt, "2026-08-28T02:33:47Z")
        @Assert(resolveCangjieNightlyFromSupplementaryCatalog("<html>fallback</html>").catalogStatus, "dictionary-schema-rejected")

        let tags = "[{\"name\":\"stable\"},{\"name\":\"" + version + "\"},{\"name\":\"1.3.0-alpha.20260827010050\"}]"
        @Assert(resolveLatestCangjieNightlyTag(tags), version)
        let metadata = "{\"tag_name\":\"" + version + "\",\"draft\":false,\"prerelease\":true,\"published_at\":\"2026-08-28T02:33:47Z\"}"
        @Assert(resolveCangjieNightlyReleaseMetadata(metadata, version).valid, true)
        @Assert(resolveCangjieNightlyReleaseMetadata(metadata.replace("\"draft\":false", "\"draft\":true"), version).valid, false)
    }

    @TestCase
    public func resolvesExactNightlyAssetOnlyFromValidatedMirrorManifest(): Unit {
        let version = "1.3.0-alpha.20260828010050"
        let name = "cangjie-sdk-mac-aarch64-" + version + ".tar.gz"
        let manifest = "{\"schema\": \"happub-cangjie-sdk-mirror-manifest-v1\",\"ok\": true,\"status\": \"mirrored-verbatim\",\"upstream\":{\"tag\":\"" + version + "\"},\"mirror\":{\"tag\":\"" + version + "\"},\"assets\":[{\"name\": \"" + name + "\",\"classification\":\"sdk\",\"mirrorUrl\":\"https://github.com/HapPub/CangjieSDK-Mirror/releases/download/" + version + "/" + name + "\",\"sourceUrl\":\"https://gitcode.com/Cangjie/nightly_build/releases/download/" + version + "/" + name + "\",\"sha256\":\"" + "a" * 64 + "\"}],\"checksumPolicy\":{\"authority\": \"mirror-computed-sha256\"}}"
        let asset = resolveCangjieNightlyAsset(manifest, version, "cangjie-sdk", "mac-aarch64")
        @Assert(asset.valid, true)
        @Assert(asset.name, name)
        @Assert(asset.checksumAuthority, "happub-mirror-manifest-sha256")
        @Assert(resolveCangjieNightlyAsset(manifest, version, "cangjie-sdk", "windows-x64").valid, false)
        @Assert(resolveCangjieNightlyAsset(manifest.replace("mirrored-verbatim", "partial"), version, "cangjie-sdk", "mac-aarch64").valid, false)
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
        @Assert(containsText(json, "\"routeProbeActionTaken\": false"), true)
    }

    @TestCase
    public func fixtureTransactionRejectsChecksumThenInstallsAndHitsMarkerCache(): Unit {
        let fixture = testTempPathForTest("hapcli-package-install-fixture")
        let payload = fixture + "/payload/cangjie"
        let archive = fixture + "/fixture-sdk.tar.gz"
        let installRoot = fixture + "/install"
        createDirForTest(payload)
        File.writeTo(payload + "/envsetup.sh", "export CANGJIE_HOME=fixture\n".toArray())
        let (tarCode, _, _) = executeWithOutput("tar", ["-czf", archive, "-C", fixture + "/payload", "cangjie"])
        @Assert(tarCode, Int64(0))
        let shaProgram = if (isProgramResolvable("sha256sum")) { "sha256sum" } else { "shasum" }
        let shaArgs = if (shaProgram == "sha256sum") { [archive] } else { ["-a", "256", archive] }
        let (shaCode, shaOut, _) = executeWithOutput(shaProgram, shaArgs)
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

        let finalRoot = cangjiePackageFinalRoot(options)
        if (exists(finalRoot)) { removeIfExists(finalRoot, recursive: true) }

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
        @Assert(rejected.diagnostic, "")
        @Assert(rejected.status, "checksum-rejected")

        let asset = HapCangjiePackageInstallAsset()
        asset.valid = true
        asset.packageName = "cangjie-sdk"
        asset.name = "fixture-sdk.tar.gz"
        asset.version = "fixture"
        asset.url = "file://" + archive
        asset.mirrorUrl = "file://" + archive
        asset.sha256 = exactSha
        createDirForTest(finalRoot)
        File.writeTo(finalRoot + "/sentinel", "preserve".toArray())
        let incomplete = installResolvedCangjiePackage(options, asset)
        @Assert(incomplete.status, "incomplete-install-preserved")
        @Assert(exists(finalRoot + "/sentinel"), true)
        removeIfExists(finalRoot, recursive: true)
        createDirForTest(finalRoot + ".lock")
        @Assert(installResolvedCangjiePackage(options, asset).ok, false)
        @Assert(exists(finalRoot + ".lock"), true)
        removeIfExists(finalRoot + ".lock", recursive: true)
        let incompletePayload = fixture + "/incomplete-payload"
        createDirForTest(incompletePayload)
        File.writeTo(incompletePayload + "/not-an-sdk", "fixture".toArray())
        let incompleteArchive = fixture + "/incomplete-sdk.tar.gz"
        let (badTarCode, _, _) = executeWithOutput("tar", ["-czf", incompleteArchive, "-C", incompletePayload, "not-an-sdk"])
        @Assert(badTarCode, Int64(0))
        let savedUrl = asset.url
        let savedMirror = asset.mirrorUrl
        let savedSha = asset.sha256
        asset.url = "file://" + incompleteArchive
        asset.mirrorUrl = asset.url
        let incompleteShaArgs = if (shaProgram == "sha256sum") { [incompleteArchive] } else { ["-a", "256", incompleteArchive] }
        let (incompleteShaCode, incompleteShaOut, _) = executeWithOutput(shaProgram, incompleteShaArgs)
        @Assert(incompleteShaCode, Int64(0))
        asset.sha256 = firstBootstrapAsciiToken(String.fromUtf8(incompleteShaOut))
        let incompleteSdk = installResolvedCangjiePackage(options, asset)
        @Assert(incompleteSdk.status, "sdk-envsetup-not-found")
        @Assert(exists(finalRoot), false)
        @Assert(exists(finalRoot + ".staging"), false)
        @Assert(exists(finalRoot + ".lock"), false)
        asset.url = savedUrl
        asset.mirrorUrl = savedMirror
        asset.sha256 = savedSha
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
