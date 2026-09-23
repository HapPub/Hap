package hapcli

public func resolveSdkToolchainAsset(o: HapSdkGetOptions): HapSdkAsset {
    let a = HapSdkAsset()
    a.version = o.version
    if (o.archive.size > 0 || o.url.size > 0) {
        a.url = o.url
        a.sha256 = o.sha256
        a.authority = "explicit-user-sha256"
        return a
    }
    if (o.subject == "jdk") { return resolveSemeruAsset(o) }
    if (o.subject == "android") {
        let build = "15859902"
        var host = ""
        match (o.target) {
            case "macos-arm64" => host = "mac_arm64"; a.sha256 = "835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e"
            case "macos-amd64" => host = "mac_x86_64"; a.sha256 = "c5a6378ab5cf7e0d5701921405115befff13e9ff7417fb588389338f8bd050f3"
            case "linux-amd64" => host = "linux"; a.sha256 = "4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583"
            case _ => throw Exception("Google command-line tools catalog has no native asset for " + o.target)
        }
        a.url = "https://dl.google.com/android/repository/commandlinetools-" + host + "-" + build + "_latest.zip"
        a.authority = "https://developer.android.com/studio#command-line-tools-only"
        return a
    }
    if (o.subject == "ohos") {
        if (o.version != "6.0") { throw Exception("built-in OpenHarmony catalog currently pins 6.0 / API 20; supply an official --url or --archive and --sha256 for another release") }
        var name = ""
        match (o.target) {
            case "macos-arm64" => name = "L2-SDK-MAC-M1-PUBLIC.tar.gz"
            case "macos-amd64" => name = "ohos-sdk-mac-public.tar.gz"
            case "linux-amd64" => name = "ohos-sdk-windows_linux-public.tar.gz"
            case _ => throw Exception("OpenHarmony 6.0 has no native public SDK asset for " + o.target)
        }
        a.url = "https://repo.huaweicloud.com/openharmony/os/6.0-Release/" + name
    } else if (o.subject == "harmonyos") {
        if (o.target != "linux-amd64" || o.version != "5.1.0.840") {
            throw Exception("Huawei public CLT mirror currently covers Linux x64 5.1.0.840; for this target/version obtain Command Line Tools from https://developer.huawei.com/consumer/cn/download/ and supply --archive or --url with --sha256. HapCLI will install the SDK and bundled toolchain.")
        }
        a.url = "https://repo.huaweicloud.com/openharmony/ohpm/5.1.0/commandline-tools-linux-x64-5.1.0.840.zip"
    }
    a.authority = a.url + ".sha256"
    a.sha256 = firstBootstrapAsciiToken(sdkCatalog(a.authority))
    return a
}

// GitHub's exact asset digest is authority, with the release's checksum sidecar
// as fallback. Select Open Edition JDK archives only; never JRE/debug/installers.
public func resolveSemeruAsset(o: HapSdkGetOptions): HapSdkAsset {
    let a = HapSdkAsset()
    var requested = o.version
    if (startsWithText(requested, "jdk-")) { requested = substringFrom(requested, 4) }
    let major = requested.split(".")[0].split("+")[0]
    if (major != "11" && major != "17" && major != "21" && major != "25") { throw Exception("Semeru major must be 11, 17, 21 or 25; exact jdk-* tags are also accepted") }
    let repo = "ibmruntimes/semeru" + major + "-binaries"
    let endpoint = "https://api.github.com/repos/" + repo + "/releases/" + if (o.version == major) { "latest" } else { "tags/" + if (startsWithText(o.version, "jdk-")) { o.version } else { "jdk-" + o.version } }
    let catalog = sdkCatalog(endpoint)
    let tag = jsonStringValueForKey(catalog, "tag_name")
    if (!startsWithText(tag, "jdk-" + major) || !sdkGetToken(tag) || jsonBoolValueAfter(catalog, indexOfText(catalog, "\"draft\"")) != "false" || jsonBoolValueAfter(catalog, indexOfText(catalog, "\"prerelease\"")) != "false") { throw Exception("Semeru release metadata does not identify a stable matching tag") }
    let arch = if (o.target.endsWith("arm64")) { "aarch64" } else { "x64" }
    let os = if (startsWithText(o.target, "macos-")) { "mac" } else if (startsWithText(o.target, "windows-")) { "windows" } else { "linux" }
    let prefix = "ibm-semeru-open-jdk_" + arch + "_" + os + "_"
    var cursor: Int64 = 0
    var count: Int64 = 0
    while (true) {
        let index = indexOfTextFrom(catalog, "\"name\"", cursor)
        if (index < 0) { break }
        cursor = index + 6
        let name = jsonStringValueAfter(catalog, index)
        let object = jsonObjectAround(catalog, index)
        let url = jsonStringValueForKey(object, "browser_download_url")
        // File naming changed across OpenJ9 releases; architecture/OS/JDK role
        // and extension remain exact while the pinned release binds the version.
        if (startsWithText(name, prefix) && name.endsWith(if (os == "windows") { ".zip" } else { ".tar.gz" })) {
            if (!startsWithText(url, "https://github.com/" + repo + "/releases/download/" + tag + "/")) { throw Exception("Semeru asset URL is outside its exact release") }
            count += 1
            a.url = url
            let digest = jsonStringValueForKey(object, "digest")
            a.sha256 = if (startsWithText(digest, "sha256:")) { substringFrom(digest, 7) } else { "" }
        }
    }
    if (count != 1) { throw Exception("Semeru release does not publish exactly one Open Edition JDK archive for " + o.target) }
    a.version = tag
    a.authority = endpoint
    if (!isLowerHexSha256(a.sha256)) {
        a.authority = a.url + ".sha256.txt"
        a.sha256 = firstBootstrapAsciiToken(sdkCatalog(a.authority))
    }
    return a
}
