package hapcli

public func canonicalTargetName(target: String): String {
    match (target) {
        case "linux-amd64" => "linux-amd64"
        case "linux-x64" => "linux-amd64"
        case "x86_64-unknown-linux-gnu" => "linux-amd64"
        case "linux_x86_64_cjnative" => "linux-amd64"
        case "x86_64-linux-ohos" => "ohos-amd64"
        case "linux_ohos_x86_64_cjnative" => "ohos-amd64"
        case "linux-arm64" => "linux-arm64"
        case "linux-aarch64" => "linux-arm64"
        case "aarch64-unknown-linux-gnu" => "linux-arm64"
        case "linux_aarch64_cjnative" => "linux-arm64"
        case "aarch64-linux-ohos" => "ohos-arm64"
        case "aarch64-linux-ohos-cjnative" => "ohos-arm64"
        case "linux_ohos_aarch64_cjnative" => "ohos-arm64"
        case "macos-arm64" => "macos-arm64"
        case "darwin-aarch64" => "macos-arm64"
        case "aarch64-apple-darwin" => "macos-arm64"
        case "darwin_aarch64_cjnative" => "macos-arm64"
        case "macos-amd64" => "macos-amd64"
        case "x86_64-apple-darwin" => "macos-amd64"
        case "darwin_x86_64_cjnative" => "macos-amd64"
        case "windows-amd64" => "windows-amd64"
        case "x86_64-w64-mingw32" => "windows-amd64"
        case "windows_x86_64_cjnative" => "windows-amd64"
        case _ => target
    }
}

public func cangjiePlatformNameForTarget(target: String): String {
    match (canonicalTargetName(target)) {
        case "linux-amd64" => "linux_x86_64_cjnative"
        case "linux-arm64" => "linux_aarch64_cjnative"
        case "macos-arm64" => "darwin_aarch64_cjnative"
        case "macos-amd64" => "darwin_x86_64_cjnative"
        case "windows-amd64" => "windows_x86_64_cjnative"
        case "ohos-arm64" => "linux_ohos_aarch64_cjnative"
        case "ohos-amd64" => "linux_ohos_x86_64_cjnative"
        case _ => ""
    }
}

public func cangjieTargetTripleForTarget(target: String): String {
    match (canonicalTargetName(target)) {
        case "linux-amd64" => "x86_64-unknown-linux-gnu"
        case "linux-arm64" => "aarch64-unknown-linux-gnu"
        case "macos-arm64" => "aarch64-apple-darwin"
        case "macos-amd64" => "x86_64-apple-darwin"
        case "windows-amd64" => "x86_64-w64-mingw32"
        case "ohos-arm64" => "aarch64-linux-ohos"
        case "ohos-amd64" => "x86_64-linux-ohos"
        case _ => target
    }
}

public func stdxPathHintForTarget(target: String): String {
    let platform = cangjiePlatformNameForTarget(target)
    if (platform.size == 0) {
        return ""
    }
    "stdx_Build/" + platform
}

public func cangjieDownloadPlatformForTarget(target: String): String {
    match (canonicalTargetName(target)) {
        case "linux-amd64" => "linux-x64"
        case "linux-arm64" => "linux-aarch64"
        case "macos-arm64" => "mac-aarch64"
        case "macos-amd64" => "mac-x64"
        case "windows-amd64" => "windows-x64"
        case "ohos-arm64" => "ohos-aarch64"
        case "ohos-amd64" => "ohos-x64"
        case _ => ""
    }
}
