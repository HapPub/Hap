package hapcli

import std.fs.{Directory, File, exists}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class HapCangjieSourceRouteTest {
    @TestCase
    public func globalRouteUsesGithubMirrorBeforeGitCode(): Unit {
        let route = resolveCangjieSourceRouteSignals("global", true, "", "", "", "", "", "")

        @Assert(route.valid, true)
        @Assert(route.selectedRegion, "global")
        @Assert(route.selectionSource, "cli")
        @Assert(route.primaryProvider, "github-mirror")
        @Assert(route.fallbackProvider, "gitcode-original")
        @Assert(cangjieSourceProviderUrl(route, "1.3.0-alpha.1", true), "https://github.com/HapPub/CangjieSDK-Mirror/releases/download/1.3.0-alpha.1")
    }

    @TestCase
    public func zhCnRouteUsesGitCodeBeforeGithubMirror(): Unit {
        let route = resolveCangjieSourceRouteSignals("auto", false, "", "/tmp/config.toml", "zh-cn", "", "", "")

        @Assert(route.valid, true)
        @Assert(route.selectedRegion, "zh-cn")
        @Assert(route.selectionSource, "config")
        @Assert(route.primaryProvider, "gitcode-original")
        @Assert(route.fallbackProvider, "github-mirror")
    }

    @TestCase
    public func explicitCliRegionPrecedesEnvironmentAndConfig(): Unit {
        let route = resolveCangjieSourceRouteSignals("global", true, "", "/tmp/config.toml", "zh-cn", "zh-cn", "zh_CN.UTF-8", "Asia/Shanghai")

        @Assert(route.selectedRegion, "global")
        @Assert(route.selectionSource, "cli")
    }

    @TestCase
    public func environmentPrecedesConfigAndLocale(): Unit {
        let route = resolveCangjieSourceRouteSignals("auto", false, "", "/tmp/config.toml", "global", "zh-cn", "en_US.UTF-8", "UTC")

        @Assert(route.selectedRegion, "zh-cn")
        @Assert(route.selectionSource, "environment")
    }

    @TestCase
    public func localeTimezoneHeuristicSelectsZhCnWithoutGeolocation(): Unit {
        let localeRoute = resolveCangjieSourceRouteSignals("auto", false, "", "", "", "", "zh_CN.UTF-8", "UTC")
        let timezoneRoute = resolveCangjieSourceRouteSignals("auto", false, "", "", "", "", "en_US.UTF-8", "Asia/Shanghai")

        @Assert(localeRoute.selectedRegion, "zh-cn")
        @Assert(timezoneRoute.selectedRegion, "zh-cn")
        @Assert(localeRoute.selectionSource, "locale-timezone-heuristic")
    }

    @TestCase
    public func customProviderDisablesSilentFallback(): Unit {
        let route = resolveCangjieSourceRouteSignals("zh-cn", true, "https://downloads.example.invalid/cangjie", "", "", "", "", "")

        @Assert(route.customProvider, true)
        @Assert(route.primaryProvider, "custom")
        @Assert(route.fallbackProvider, "none")
        @Assert(cangjieSourceProviderUrl(route, "1.3.0", true), "https://downloads.example.invalid/cangjie")
        @Assert(cangjieSourceManifestUrl(route, "1.3.0"), "")
    }

    @TestCase
    public func sdkAndStdxPlansUseMirrorManifestWithoutNetworkMutation(): Unit {
        let sdk = HapCangjieSdkGetOptions()
        sdk.target = "linux-amd64"
        sdk.version = "1.3.0-alpha.20260803010032"
        sdk.installRoot = "/tmp/cangjie"
        sdk.region = "global"
        sdk.regionExplicit = true
        let sdkJson = renderCangjieSdkGetPlanJson(sdk)

        let stdx = HapCangjieStdxGetOptions()
        stdx.target = "ohos-arm64"
        stdx.version = "1.3.0-alpha.20260803010032"
        stdx.installRoot = "/tmp/stdx"
        stdx.region = "zh-cn"
        stdx.regionExplicit = true
        let stdxJson = renderCangjieStdxGetPlanJson(stdx)

        @Assert(sdkJson.contains("\"primaryProvider\": \"github-mirror\""), true)
        @Assert(sdkJson.contains("\"fallbackProvider\": \"gitcode-original\""), true)
        @Assert(sdkJson.contains("manifest.v1.json"), true)
        @Assert(sdkJson.contains("\"status\": \"ready-for-manifest-checksum-resolution\""), true)
        @Assert(stdxJson.contains("\"primaryProvider\": \"gitcode-original\""), true)
        @Assert(stdxJson.contains("cangjie-stdx-ohos-aarch64-1.3.0-alpha.20260803010032.1.zip"), true)
        @Assert(stdxJson.contains("\"downloadAllowed\": false"), true)
    }

    @TestCase
    public func invalidExplicitRegionFailsClosed(): Unit {
        let route = resolveCangjieSourceRouteSignals("moon", true, "", "", "", "", "", "")
        @Assert(route.valid, false)
        @Assert(route.status, "invalid-cli-region")
    }

    @TestCase
    public func projectConfigRequiresRecognizedCangjieProject(): Unit {
        let unsupported = "/tmp/hap-cangjie-source-route-unsupported"
        if (!exists(unsupported)) {
            Directory.create(unsupported, recursive: true)
        }
        File.writeTo(unsupported + "/happub.toml", "downloadRegion = \"zh-cn\"\n".toArray())
        @Assert(findCangjieSourceConfigPathAt("", unsupported, ""), "")

        let supported = "/tmp/hap-cangjie-source-route-supported"
        let configDirectory = supported + "/.hapData"
        if (!exists(configDirectory)) {
            Directory.create(configDirectory, recursive: true)
        }
        File.writeTo(supported + "/cjpm.toml", "[package]\nname = \"fixture\"\n".toArray())
        File.writeTo(configDirectory + "/config.toml", "downloadRegion = \"global\"\n".toArray())
        @Assert(findCangjieSourceConfigPathAt("", supported, ""), configDirectory + "/config.toml")
    }
}
