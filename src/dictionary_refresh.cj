package hapcli

import std.fs.{File, exists}
import std.process.executeWithOutput

public class HapDictionaryRefreshOptions {
    public var cachePath: String = ""
    public var source: String = ""
    public var reviewToken: String = ""
    public var ttlSeconds: String = "86400"
    public var allowNetwork: Bool = false
    public var networkMode: String = "no-proxy"

    public init() {}
}

public func resolveDictionaryRefreshOptions(commandLine: Array<String>, start: Int64): HapDictionaryRefreshOptions {
    let options = HapDictionaryRefreshOptions()
    var i = start
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--cache" && i + 1 < commandLine.size) {
            options.cachePath = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--cache=")) {
            options.cachePath = substringFrom(current, 8)
            i += 1
            continue
        }
        if (current == "--source" && i + 1 < commandLine.size) {
            options.source = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--source=")) {
            options.source = substringFrom(current, 9)
            i += 1
            continue
        }
        if (current == "--review-token" && i + 1 < commandLine.size) {
            options.reviewToken = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--review-token=")) {
            options.reviewToken = substringFrom(current, 15)
            i += 1
            continue
        }
        if (current == "--ttl-seconds" && i + 1 < commandLine.size) {
            options.ttlSeconds = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--ttl-seconds=")) {
            options.ttlSeconds = substringFrom(current, 14)
            i += 1
            continue
        }
        if (current == "--allow-network") {
            options.allowNetwork = true
            i += 1
            continue
        }
        if (current == "--proxy") {
            options.networkMode = "proxy"
            i += 1
            continue
        }
        if (current == "--no-proxy") {
            options.networkMode = "no-proxy"
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func runDictionaryRefresh(commandLine: Array<String>, start: Int64): String {
    let options = resolveDictionaryRefreshOptions(commandLine, start)
    renderDictionaryRefreshJson(options, true)
}

public func renderDictionaryRefreshJson(options: HapDictionaryRefreshOptions, canWrite: Bool): String {
    renderDictionaryRefreshJsonWithNetworkPayload(options, canWrite, "", -1)
}

public func renderDictionaryRefreshJsonWithNetworkPayload(
    options: HapDictionaryRefreshOptions,
    canWrite: Bool,
    networkPayload: String,
    networkExitCode: Int64
): String {
    let sourceKind = dictionarySourceKind(options.source)
    let localSource = localDictionarySourcePath(options.source)
    let requiredOk = options.cachePath.size > 0 && options.source.size > 0
    var cacheWritten = false
    var networkActionTaken = false
    var sourceBytes: Int64 = 0
    var status = "ready-for-local-refresh-review"

    if (!requiredOk) {
        status = "missing-required-field"
    } else if (sourceKind == "http-url" || sourceKind == "https-url") {
        if (!options.allowNetwork) {
            status = "network-source-requires-fetcher"
        } else if (options.reviewToken.size == 0) {
            status = "missing-review-token-for-network-cache-write"
        } else if (canWrite) {
            let result = resolveNetworkDictionaryPayload(options.source, networkPayload, networkExitCode, options.networkMode)
            networkActionTaken = true
            sourceBytes = result.payload.size
            if (!result.ok) {
                status = result.status
            } else if (!looksLikeDictionaryPayload(result.payload)) {
                status = "malformed-network-payload"
            } else {
                File.writeTo(options.cachePath, result.payload.toArray())
                cacheWritten = true
                status = "reviewed-network-cache-updated"
            }
        } else {
            status = "network-refresh-ready-for-reviewed-fetch"
        }
    } else if (sourceKind == "unsupported") {
        status = "unsupported-source"
    } else if (!exists(localSource)) {
        status = "source-file-not-found"
    } else if (options.reviewToken.size == 0) {
        status = "missing-review-token-for-cache-write"
    } else if (canWrite) {
        let bytes = File.readFrom(localSource)
        sourceBytes = bytes.size
        File.writeTo(options.cachePath, bytes)
        cacheWritten = true
        status = "reviewed-cache-updated"
    }

    let ok = cacheWritten || status == "network-source-requires-fetcher" || status == "network-refresh-ready-for-reviewed-fetch"
    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-dictionary-refresh-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"local-first-cache-refresh\",\n")
    out.append("  \"cachePath\": \"" + escapeJson(options.cachePath) + "\",\n")
    out.append("  \"source\": \"" + escapeJson(options.source) + "\",\n")
    out.append("  \"sourceKind\": \"" + escapeJson(sourceKind) + "\",\n")
    out.append("  \"ttlSeconds\": \"" + escapeJson(options.ttlSeconds) + "\",\n")
    out.append("  \"allowNetwork\": " + boolJson(options.allowNetwork) + ",\n")
    out.append("  \"networkMode\": \"" + escapeJson(normalizeHapNetworkMode(options.networkMode)) + "\",\n")
    out.append("  \"proxyEnvironmentInherited\": " + boolJson(normalizeHapNetworkMode(options.networkMode) == "proxy") + ",\n")
    out.append("  \"proxyEnvironmentCleared\": " + boolJson(normalizeHapNetworkMode(options.networkMode) == "no-proxy") + ",\n")
    out.append("  \"networkActionTaken\": " + boolJson(networkActionTaken) + ",\n")
    out.append("  \"cacheWritten\": " + boolJson(cacheWritten) + ",\n")
    out.append("  \"sourceBytes\": " + sourceBytes.toString() + ",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"read-local-cache-first\",\n")
    out.append("    \"refresh-cache-with-reviewed-local-source\",\n")
    out.append("    \"fetch-network-dictionary-with-explicit-fetcher\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"dictionary refresh does not silently access network\",\n")
    out.append("    \"http sources require --allow-network and review-token before cache write\",\n")
    out.append("    \"cache write requires review-token\",\n")
    out.append("    \"local cache remains the first read surface\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func dictionarySourceKind(source: String): String {
    if (startsWithText(source, "https://")) {
        return "https-url"
    }
    if (startsWithText(source, "http://")) {
        return "http-url"
    }
    if (startsWithText(source, "file://")) {
        return "file-url"
    }
    if (source.size > 0) {
        return "local-file"
    }
    "unsupported"
}

func localDictionarySourcePath(source: String): String {
    if (startsWithText(source, "file://")) {
        return substringFrom(source, 7)
    }
    source
}

class NetworkDictionaryFetchResult {
    var ok: Bool = false
    var status: String = "network-fetch-failed"
    var payload: String = ""

    init(ok: Bool, status: String, payload: String) {
        this.ok = ok
        this.status = status
        this.payload = payload
    }
}

func resolveNetworkDictionaryPayload(source: String, injectedPayload: String, injectedExitCode: Int64, networkMode: String): NetworkDictionaryFetchResult {
    if (injectedExitCode >= 0) {
        if (injectedExitCode == 0) {
            return NetworkDictionaryFetchResult(true, "network-fetch-ok", injectedPayload)
        }
        return NetworkDictionaryFetchResult(false, "network-fetch-failed", injectedPayload)
    }

    let curlCommand = resolveHapNetworkCommand(networkMode, "curl", ["-fsSL", "--max-time", "20", source])
    let (curlCode, curlOut, _) = executeWithOutput(curlCommand.program, curlCommand.args.toArray())
    if (curlCode == 0) {
        return NetworkDictionaryFetchResult(true, "network-fetch-ok", String.fromUtf8(curlOut))
    }

    let wgetCommand = resolveHapNetworkCommand(networkMode, "wget", ["-q", "-O", "-", source])
    let (wgetCode, wgetOut, _) = executeWithOutput(wgetCommand.program, wgetCommand.args.toArray())
    if (wgetCode == 0) {
        return NetworkDictionaryFetchResult(true, "network-fetch-ok", String.fromUtf8(wgetOut))
    }

    return NetworkDictionaryFetchResult(false, "network-fetch-failed", "")
}

func looksLikeDictionaryPayload(payload: String): Bool {
    if (payload.size == 0) {
        return false
    }
    containsText(payload, "\"schema\"") && containsText(payload, "happub-network-dictionary-v0")
}
