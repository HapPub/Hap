package hapcli

import std.env.getVariable
import std.fs.{File, exists}

public class HapCangjieSourceRoute {
    public var valid: Bool = true
    public var status: String = "resolved"
    public var requestedRegion: String = "auto"
    public var selectedRegion: String = "global"
    public var selectionSource: String = "default-global"
    public var configPath: String = ""
    public var configRegion: String = ""
    public var localeSignal: String = ""
    public var timezoneSignal: String = ""
    public var primaryProvider: String = "github-mirror"
    public var fallbackProvider: String = "gitcode-original"
    public var primaryBaseUrl: String = "https://github.com/HapPub/CangjieSDK-Mirror/releases/download"
    public var fallbackBaseUrl: String = "https://gitcode.com/Cangjie/nightly_build/releases/download"
    public var customProvider: Bool = false

    public init() {}
}

public func resolveCangjieSourceRoute(
    requestedRegion: String,
    regionExplicit: Bool,
    explicitConfigPath: String,
    customProviderUrl: String
): HapCangjieSourceRoute {
    let configPath = findCangjieSourceConfigPath(explicitConfigPath)
    if (explicitConfigPath.size > 0 && configPath.size == 0) {
        let failed = HapCangjieSourceRoute()
        failed.valid = false
        failed.status = "explicit-config-not-found"
        failed.requestedRegion = requestedRegion
        failed.configPath = explicitConfigPath
        return failed
    }
    let configRegion = readCangjieSourceConfigRegion(configPath)
    let envRegion = cangjieSourceEnv("HAP_REGION")
    let locale = firstCangjieSourceEnv(["LC_ALL", "LC_MESSAGES", "LANG"])
    let timezone = cangjieSourceTimezone()
    let route = resolveCangjieSourceRouteSignals(
        requestedRegion,
        regionExplicit,
        customProviderUrl,
        configPath,
        configRegion,
        envRegion,
        locale,
        timezone
    )
    route
}

public func resolveCangjieSourceRouteSignals(
    requestedRegion: String,
    regionExplicit: Bool,
    customProviderUrl: String,
    configPath: String,
    configRegion: String,
    envRegion: String,
    locale: String,
    timezone: String
): HapCangjieSourceRoute {
    let route = HapCangjieSourceRoute()
    route.requestedRegion = requestedRegion
    route.configPath = configPath
    route.configRegion = configRegion
    route.localeSignal = locale
    route.timezoneSignal = timezone

    var selected = ""
    var source = ""
    if (regionExplicit) {
        let cliRegion = canonicalCangjieDownloadRegion(requestedRegion)
        if (cliRegion.size == 0) {
            route.valid = false
            route.status = "invalid-cli-region"
            return route
        }
        if (cliRegion != "auto") {
            selected = cliRegion
            source = "cli"
        }
    }

    if (selected.size == 0) {
        let environmentRegion = canonicalCangjieDownloadRegion(envRegion)
        if (environmentRegion == "global" || environmentRegion == "zh-cn") {
            selected = environmentRegion
            source = "environment"
        }
    }

    if (selected.size == 0 && configRegion.size > 0) {
        let configuredRegion = canonicalCangjieDownloadRegion(configRegion)
        if (configuredRegion.size == 0) {
            route.valid = false
            route.status = "invalid-config-region"
            return route
        }
        if (configuredRegion != "auto") {
            selected = configuredRegion
            source = "config"
        }
    }

    if (selected.size == 0 && (cangjieSourceLocaleIsZhCn(locale) || cangjieSourceTimezoneIsZhCn(timezone))) {
        selected = "zh-cn"
        source = "locale-timezone-heuristic"
    }
    if (selected.size == 0) {
        selected = "global"
        source = "default-global"
    }
    route.selectedRegion = selected
    route.selectionSource = source

    if (customProviderUrl.size > 0) {
        route.customProvider = true
        route.primaryProvider = "custom"
        route.fallbackProvider = "none"
        route.primaryBaseUrl = trimTrailingSlash(customProviderUrl)
        route.fallbackBaseUrl = ""
        return route
    }

    if (selected == "zh-cn") {
        route.primaryProvider = "gitcode-original"
        route.fallbackProvider = "github-mirror"
        route.primaryBaseUrl = "https://gitcode.com/Cangjie/nightly_build/releases/download"
        route.fallbackBaseUrl = "https://github.com/HapPub/CangjieSDK-Mirror/releases/download"
    }
    route
}

public func cangjieSourceProviderUrl(route: HapCangjieSourceRoute, version: String, primary: Bool): String {
    let base = if (primary) { route.primaryBaseUrl } else { route.fallbackBaseUrl }
    if (base.size == 0 || version.size == 0) {
        return base
    }
    if (route.customProvider && primary) {
        return base
    }
    trimTrailingSlash(base) + "/" + version
}

public func cangjieSourceManifestUrl(route: HapCangjieSourceRoute, version: String): String {
    if (route.customProvider || version.size == 0) {
        return ""
    }
    "https://github.com/HapPub/CangjieSDK-Mirror/releases/download/" + version + "/manifest.v1.json"
}

func canonicalCangjieDownloadRegion(region: String): String {
    match (trimAsciiText(region)) {
        case "" => "auto"
        case "auto" => "auto"
        case "global" => "global"
        case "world" => "global"
        case "zh-cn" => "zh-cn"
        case "zh_CN" => "zh-cn"
        case "zh_cn" => "zh-cn"
        case "cn" => "zh-cn"
        case "china" => "zh-cn"
        case _ => ""
    }
}

func findCangjieSourceConfigPath(explicitPath: String): String {
    findCangjieSourceConfigPathAt(explicitPath, ".", cangjieSourceEnv("HOME"))
}

func findCangjieSourceConfigPathAt(explicitPath: String, project: String, home: String): String {
    if (explicitPath.size > 0) {
        return if (exists(explicitPath)) { explicitPath } else { "" }
    }
    if (home.size > 0) {
        let homeConfig = trimTrailingSlash(home) + "/.hap/config.toml"
        if (exists(homeConfig)) {
            return homeConfig
        }
    }
    if (!exists(projectManifestPath(project))) {
        return ""
    }
    let projectConfig = trimTrailingSlash(project) + "/.hapData/config.toml"
    if (exists(projectConfig)) {
        return projectConfig
    }
    let happubConfig = trimTrailingSlash(project) + "/happub.toml"
    if (exists(happubConfig)) {
        return happubConfig
    }
    ""
}

func readCangjieSourceConfigRegion(path: String): String {
    if (path.size == 0 || !exists(path)) {
        return ""
    }
    try {
        return readTomlString(String.fromUtf8(File.readFrom(path)), "downloadRegion")
    } catch (_: Exception) {
        return ""
    }
}

func cangjieSourceEnv(name: String): String {
    match (getVariable(name)) {
        case Some(value) => trimAsciiText(value)
        case None => ""
    }
}

func firstCangjieSourceEnv(names: Array<String>): String {
    for (name in names) {
        let value = cangjieSourceEnv(name)
        if (value.size > 0) {
            return value
        }
    }
    ""
}

func cangjieSourceTimezone(): String {
    let environment = cangjieSourceEnv("TZ")
    if (environment.size > 0) {
        return environment
    }
    if (exists("/etc/timezone")) {
        try {
            return trimAsciiText(String.fromUtf8(File.readFrom("/etc/timezone")))
        } catch (_: Exception) {
            return ""
        }
    }
    ""
}

func cangjieSourceLocaleIsZhCn(locale: String): Bool {
    containsText(locale, "zh_CN") || containsText(locale, "zh-CN") ||
        containsText(locale, "zh_cn") || containsText(locale, "zh-cn")
}

func cangjieSourceTimezoneIsZhCn(timezone: String): Bool {
    timezone == "Asia/Shanghai" || timezone == "Asia/Chongqing" ||
        timezone == "Asia/Harbin" || timezone == "PRC"
}
