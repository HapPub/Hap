package hapcli

import std.process.executeWithOutput

public class HapCangjieNightlyRelease {
    public var valid: Bool = false
    public var version: String = ""
    public var publishedAt: String = ""
    public var manifestUrl: String = ""
    public var manifest: String = ""
    public var catalogActionTaken: Bool = false
    public var catalogSource: String = "none"
    public var catalogStatus: String = "not-requested"
    public var diagnostic: String = ""
    public var asset: HapCangjiePackageInstallAsset = HapCangjiePackageInstallAsset()

    public init() {}
}

public func isCangjieNightlyVersion(value: String): Bool {
    let parts = trimAsciiText(value).split("-alpha.")
    if (parts.size != 2) {
        return false
    }
    let versionParts = parts[0].split(".")
    if (versionParts.size != 3 || !allAsciiDigits(versionParts[0]) || !allAsciiDigits(versionParts[1]) || !allAsciiDigits(versionParts[2])) {
        return false
    }
    parts[1].toRuneArray().size == 14 && allAsciiDigits(parts[1])
}

func allAsciiDigits(value: String): Bool {
    if (value.size == 0) {
        return false
    }
    for (rune in value.toRuneArray()) {
        if (rune < r'0' || rune > r'9') {
            return false
        }
    }
    true
}

public func resolveCangjieNightlyFromSupplementaryCatalog(catalog: String): HapCangjieNightlyRelease {
    let release = HapCangjieNightlyRelease()
    release.catalogSource = "cli.hap.pub"
    if (jsonStringValueForKey(catalog, "schema") != "happub-hapcli-cangjie-install-catalog-v1") {
        release.catalogStatus = "dictionary-schema-rejected"
        release.diagnostic = "cli.hap.pub response is not the expected install catalog schema"
        return release
    }
    var channelIndex: Int64 = -1
    var cursor: Int64 = 0
    while (cursor < catalog.toRuneArray().size) {
        let next = indexOfTextFrom(catalog, "\"channel\"", cursor)
        if (next < 0) {
            break
        }
        let value = jsonStringValueAfter(catalog, next)
        if (value == "NIGHTLY" || value == "nightly") {
            channelIndex = next
            break
        }
        cursor = next + 1
    }
    if (channelIndex < 0) {
        release.catalogStatus = "dictionary-nightly-missing"
        release.diagnostic = "validated supplementary dictionary has no nightly release line"
        return release
    }
    let object = jsonObjectAround(catalog, channelIndex)
    let version = jsonStringValueForKey(object, "version")
    let manifestUrl = jsonStringValueForKey(object, "manifestUrl")
    if (!isCangjieNightlyVersion(version) || manifestUrl != cangjieNightlyManifestUrl(version)) {
        release.catalogStatus = "dictionary-nightly-invalid"
        release.diagnostic = "supplementary nightly entry has an invalid version or manifest URL"
        return release
    }
    release.valid = true
    release.version = version
    release.publishedAt = jsonStringValueForKey(object, "publishedAt")
    release.manifestUrl = manifestUrl
    release.catalogStatus = "dictionary-candidate"
    release
}

public func resolveLatestCangjieNightlyTag(tagsJson: String): String {
    var cursor: Int64 = 0
    while (cursor < tagsJson.toRuneArray().size) {
        let nameIndex = indexOfTextFrom(tagsJson, "\"name\"", cursor)
        if (nameIndex < 0) {
            return ""
        }
        let value = jsonStringValueAfter(tagsJson, nameIndex)
        if (isCangjieNightlyVersion(value)) {
            return value
        }
        cursor = nameIndex + 1
    }
    ""
}

public func resolveCangjieNightlyReleaseMetadata(releaseJson: String, expectedVersion: String): HapCangjieNightlyRelease {
    let release = HapCangjieNightlyRelease()
    release.catalogSource = "happub-mirror-index"
    let tag = jsonStringValueForKey(releaseJson, "tag_name")
    let draftIndex = indexOfText(releaseJson, "\"draft\"")
    let prereleaseIndex = indexOfText(releaseJson, "\"prerelease\"")
    if (tag != expectedVersion || !isCangjieNightlyVersion(tag) || draftIndex < 0 || prereleaseIndex < 0 ||
        jsonBoolValueAfter(releaseJson, draftIndex) != "false" || jsonBoolValueAfter(releaseJson, prereleaseIndex) != "true") {
        release.catalogStatus = "mirror-release-metadata-rejected"
        release.diagnostic = "mirror release is not an exact non-draft nightly prerelease"
        return release
    }
    release.valid = true
    release.version = tag
    release.publishedAt = jsonStringValueForKey(releaseJson, "published_at")
    release.manifestUrl = cangjieNightlyManifestUrl(tag)
    release.catalogStatus = "mirror-candidate"
    release
}

public func resolveCangjieNightlyAsset(manifest: String, version: String, packageName: String, platform: String): HapCangjiePackageInstallAsset {
    let asset = HapCangjiePackageInstallAsset()
    if (!validateCangjieMirrorManifest(manifest, version)) {
        return asset
    }
    let mirrorAsset = if (packageName == "cangjie-sdk") {
        resolveCangjieManifestAsset(manifest, cangjieBootstrapSdkFilename(platform, version), "sdk")
    } else {
        resolveCangjieManifestAssetByPrefix(manifest, "cangjie-stdx-" + platform + "-" + version + ".1", "stdx")
    }
    if (!mirrorAsset.valid) {
        return asset
    }
    asset.valid = true
    asset.packageName = packageName
    asset.name = mirrorAsset.name
    asset.version = if (packageName == "cangjie-stdx") { version + ".1" } else { version }
    asset.url = mirrorAsset.mirrorUrl
    asset.mirrorUrl = mirrorAsset.mirrorUrl
    asset.sourceUrl = mirrorAsset.sourceUrl
    asset.sha256 = mirrorAsset.sha256
    asset.checksumAuthority = "happub-mirror-manifest-sha256"
    asset
}

public func discoverLatestCangjieNightly(packageName: String, platform: String, networkMode: String): HapCangjieNightlyRelease {
    let catalogUrl = "https://cli.hap.pub/manifests/cangjie-install-v1.json"
    let catalogFetch = fetchCangjieCatalogText(catalogUrl, networkMode, 5)
    var candidate = HapCangjieNightlyRelease()
    candidate.catalogActionTaken = true
    if (catalogFetch.exitCode == 0) {
        candidate = resolveCangjieNightlyFromSupplementaryCatalog(catalogFetch.stdout)
        candidate.catalogActionTaken = true
    } else {
        candidate.catalogSource = "cli.hap.pub"
        candidate.catalogStatus = "dictionary-fetch-failed"
        candidate.diagnostic = catalogFetch.stderr
    }
    if (candidate.valid && hydrateCangjieNightlyRelease(candidate, packageName, platform, networkMode)) {
        candidate.catalogStatus = "resolved-from-supplementary-dictionary"
        return candidate
    }

    let tagsFetch = fetchCangjieCatalogText("https://api.github.com/repos/HapPub/CangjieSDK-Mirror/tags?per_page=20", networkMode, 8)
    if (tagsFetch.exitCode != 0) {
        candidate.valid = false
        candidate.catalogSource = "happub-mirror-index"
        candidate.catalogStatus = "mirror-tag-index-fetch-failed"
        candidate.diagnostic = tagsFetch.stderr
        return candidate
    }
    let version = resolveLatestCangjieNightlyTag(tagsFetch.stdout)
    if (version.size == 0) {
        candidate.valid = false
        candidate.catalogSource = "happub-mirror-index"
        candidate.catalogStatus = "mirror-nightly-tag-not-found"
        candidate.diagnostic = "no bounded nightly tag was found in the mirror tag index"
        return candidate
    }
    let releaseFetch = fetchCangjieCatalogText("https://api.github.com/repos/HapPub/CangjieSDK-Mirror/releases/tags/" + version, networkMode, 8)
    if (releaseFetch.exitCode != 0) {
        candidate.valid = false
        candidate.catalogSource = "happub-mirror-index"
        candidate.catalogStatus = "mirror-release-metadata-fetch-failed"
        candidate.diagnostic = releaseFetch.stderr
        return candidate
    }
    candidate = resolveCangjieNightlyReleaseMetadata(releaseFetch.stdout, version)
    candidate.catalogActionTaken = true
    if (!candidate.valid || !hydrateCangjieNightlyRelease(candidate, packageName, platform, networkMode)) {
        candidate.valid = false
        if (candidate.catalogStatus == "mirror-candidate") {
            candidate.catalogStatus = "mirror-manifest-or-target-rejected"
        }
        return candidate
    }
    candidate.catalogStatus = "resolved-from-mirror-index"
    candidate
}

public func resolveExactCangjieNightly(version: String, packageName: String, platform: String, networkMode: String): HapCangjieNightlyRelease {
    let release = HapCangjieNightlyRelease()
    release.catalogActionTaken = true
    release.catalogSource = "exact-nightly-tag"
    if (!isCangjieNightlyVersion(version)) {
        release.catalogStatus = "invalid-exact-nightly-tag"
        return release
    }
    release.valid = true
    release.version = version
    release.manifestUrl = cangjieNightlyManifestUrl(version)
    release.catalogStatus = "exact-tag-candidate"
    if (!hydrateCangjieNightlyRelease(release, packageName, platform, networkMode)) {
        release.valid = false
        release.catalogStatus = "exact-nightly-manifest-or-target-rejected"
        return release
    }
    release.catalogStatus = "resolved-from-exact-tag"
    release
}

func hydrateCangjieNightlyRelease(release: HapCangjieNightlyRelease, packageName: String, platform: String, networkMode: String): Bool {
    let manifestFetch = fetchCangjieCatalogText(release.manifestUrl, networkMode, 12)
    if (manifestFetch.exitCode != 0) {
        release.diagnostic = manifestFetch.stderr
        return false
    }
    release.manifest = manifestFetch.stdout
    release.asset = resolveCangjieNightlyAsset(release.manifest, release.version, packageName, platform)
    if (!release.asset.valid) {
        release.diagnostic = "nightly mirror manifest has no exact checksum-gated asset for the requested package and target"
        return false
    }
    true
}

func fetchCangjieCatalogText(url: String, networkMode: String, timeoutSeconds: Int64): HapBuildCommandResult {
    if (!startsWithText(url, "https://") || !isProgramResolvable("curl")) {
        return HapBuildCommandResult(127, "", "HTTPS catalog resolution requires curl")
    }
    let args = [
        "--proto", "=https", "--tlsv1.2", "--location", "--fail", "--silent", "--show-error",
        "--connect-timeout", "4", "--max-time", timeoutSeconds.toString(), url
    ]
    let command = resolveHapNetworkCommand(networkMode, "curl", args)
    let (code, stdoutBytes, stderrBytes) = executeWithOutput(command.program, command.args.toArray())
    HapBuildCommandResult(code, String.fromUtf8(stdoutBytes), String.fromUtf8(stderrBytes))
}

func cangjieNightlyManifestUrl(version: String): String {
    "https://github.com/HapPub/CangjieSDK-Mirror/releases/download/" + version + "/manifest.v1.json"
}

public func bindCangjieNightlyRelease(options: HapCangjiePackageInstallOptions, release: HapCangjieNightlyRelease): Unit {
    options.catalogActionTaken = release.catalogActionTaken
    options.catalogSource = release.catalogSource
    options.catalogStatus = release.catalogStatus
    options.catalogPublishedAt = release.publishedAt
    options.catalogManifestUrl = release.manifestUrl
    options.catalogDiagnostic = release.diagnostic
    if (!release.valid) {
        return
    }
    options.resolvedVersion = release.version
    options.assetVersion = if (options.resolvedPackage == "cangjie-stdx") { release.version + ".1" } else { release.version }
    options.releaseChannel = "NIGHTLY"
    options.dynamicManifest = release.manifest
    if (!options.receiptExplicit) {
        options.receipt = options.installRoot + "/receipts/" + options.resolvedPackage + "-" + options.assetVersion + "-" + options.target + ".json"
    }
}

public func copyCangjieCatalogMetadata(options: HapCangjiePackageInstallOptions, release: HapCangjieNightlyRelease): Unit {
    options.catalogActionTaken = release.catalogActionTaken
    options.catalogSource = release.catalogSource
    options.catalogStatus = release.catalogStatus
    options.catalogPublishedAt = release.publishedAt
    options.catalogManifestUrl = release.manifestUrl
    options.catalogDiagnostic = release.diagnostic
}
