package hapcli

public class HapReleaseManifestOptions {
    public var baseUrl: String = "https://cli.hap.pub"
    public var channel: String = "preview"

    public init() {}
}

public func resolveReleaseManifestOptions(commandLine: Array<String>, start: Int64): HapReleaseManifestOptions {
    let options = HapReleaseManifestOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--base-url" && i + 1 < commandLine.size) {
            options.baseUrl = trimReleaseBaseUrlTrailingSlash(commandLine[i + 1])
            i += 2
            continue
        }
        if (startsWithText(current, "--base-url=")) {
            options.baseUrl = trimReleaseBaseUrlTrailingSlash(substringFrom(current, 11))
            i += 1
            continue
        }
        if (current == "--channel" && i + 1 < commandLine.size) {
            options.channel = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--channel=")) {
            options.channel = substringFrom(current, 10)
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func renderReleaseManifestJson(options: HapReleaseManifestOptions): String {
    let baseUrl = if (options.baseUrl.size > 0) {
        trimReleaseBaseUrlTrailingSlash(options.baseUrl)
    } else {
        "https://cli.hap.pub"
    }
    let ok = options.channel == "preview"
    let status = if (ok) {
        "release-manifest-preview-ready"
    } else {
        "unsupported-release-channel"
    }
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-release-manifest-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"channel\": \"" + escapeJson(options.channel) + "\",\n")
    out.append("  \"version\": \"0.1.0-preview.2\",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"baseUrl\": \"" + escapeJson(baseUrl) + "\",\n")
    out.append("  \"manifestUrl\": \"" + escapeJson(baseUrl + "/release/manifest.v0.json") + "\",\n")
    out.append("  \"downloadableAssetCount\": 1,\n")
    out.append("  \"downloadableAssets\": [\n")
    out.append("    {\n")
    out.append("      \"id\": \"hapup-sh\",\n")
    out.append("      \"kind\": \"bootstrap-shell\",\n")
    out.append("      \"target\": \"portable-posix-shell\",\n")
    out.append("      \"name\": \"hapup.sh\",\n")
    out.append("      \"url\": \"" + escapeJson(baseUrl + "/install/hapup.sh") + "\",\n")
    out.append("      \"sha256\": \"b0fbdc2faba124573e5c4c6b930bb4a7205d2122f7c163611a4cc2ae30ef1fcd\",\n")
    out.append("      \"installRole\": \"thin-bootstrap-companion\",\n")
    out.append("      \"downloadable\": true,\n")
    out.append("      \"executable\": true\n")
    out.append("    }\n")
    out.append("  ],\n")
    out.append("  \"plannedAssets\": [\n")
    out.append("    {\n")
    out.append("      \"id\": \"hap-linux-amd64\",\n")
    out.append("      \"kind\": \"flagship-binary\",\n")
    out.append("      \"target\": \"linux-amd64\",\n")
    out.append("      \"os\": \"linux\",\n")
    out.append("      \"arch\": \"amd64\",\n")
    out.append("      \"name\": \"hap-0.1.0-preview.2-linux-amd64.tar.gz\",\n")
    out.append("      \"status\": \"planned-not-published\",\n")
    out.append("      \"downloadable\": false\n")
    out.append("    },\n")
    out.append("    {\n")
    out.append("      \"id\": \"hap-darwin-arm64\",\n")
    out.append("      \"kind\": \"flagship-binary\",\n")
    out.append("      \"target\": \"darwin-arm64\",\n")
    out.append("      \"os\": \"darwin\",\n")
    out.append("      \"arch\": \"arm64\",\n")
    out.append("      \"name\": \"hap-0.1.0-preview.2-darwin-arm64.tar.gz\",\n")
    out.append("      \"status\": \"planned-not-published\",\n")
    out.append("      \"downloadable\": false\n")
    out.append("    }\n")
    out.append("  ],\n")
    out.append("  \"manifestInstallStatus\": \"blocked-no-downloadable-flagship-binary\",\n")
    out.append("  \"manifestInstallCommand\": \"\",\n")
    out.append("  \"sourceBuildSupported\": true,\n")
    out.append("  \"bootstrapPacketCommand\": \"hap ci bootstrap-packet --cli-bin hap --hapup-url " + escapeJson(baseUrl + "/install/hapup.sh") + " --hapup-sha256 b0fbdc2faba124573e5c4c6b930bb4a7205d2122f7c163611a4cc2ae30ef1fcd --hapup-output /tmp/hapup --install-dir /tmp/hap/bin --review-token-env HAP_REVIEW_TOKEN\",\n")
    out.append("  \"checksumPolicy\": \"every downloadable asset must carry sha256 before bootstrap or CI adoption\",\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"installActionTaken\": false,\n")
    out.append("  \"publicationActionTaken\": false,\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"publish-reviewed-flagship-assets\",\n")
    out.append("    \"verify-hosted-file-and-checksum-parity\",\n")
    out.append("    \"run-downstream-ci-receipt-proof-after-publication\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"release manifest does not publish a package registry\",\n")
    out.append("    \"release manifest does not publish flagship hap binaries\",\n")
    out.append("    \"release manifest does not provide a working flagship binary install until one planned asset becomes downloadable\",\n")
    out.append("    \"release manifest does not certify hosted CI adoption\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func trimReleaseBaseUrlTrailingSlash(value: String): String {
    if (endsWithText(value, "/")) {
        return releaseSubstringBeforeLastSlash(value)
    }
    value
}

func releaseSubstringBeforeLastSlash(value: String): String {
    if (value.size <= 1) {
        return value
    }
    value[0..value.size - 1]
}
