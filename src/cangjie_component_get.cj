package hapcli

import std.collection.ArrayList
import std.env.getStdErr

func legacyComponentGetRequested(args: Array<String>): Bool {
    for (arg in args) {
        for (key in ["--legacy-plan", "--provider-url", "--allow-unverified", "--sha256", "--review-token"]) {
            if (arg == key || startsWithText(arg, key + "=")) { return true }
        }
    }
    false
}

func runCangjieComponentGet(args: Array<String>): String {
    if (legacyComponentGetRequested(args)) {
        getStdErr().writeln("Legacy recipe options select plan-only behavior. For installation use --version and optional --plan without recipe options.")
        if (args[2] == "cangjie-sdk") { return renderCangjieSdkGetPlanJson(resolveCangjieSdkGetOptions(args, 3)) }
        return renderCangjieStdxGetPlanJson(resolveCangjieStdxGetOptions(args, 3))
    }
    let forwarded = ArrayList<String>()
    var version = "latest"
    var versionSeen = false
    var i: Int64 = 3
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--version" || startsWithText(arg, "--version=")) {
            if (versionSeen) { return renderInspectCjpmErrorJson("duplicate-version", "--version must be specified once") }
            versionSeen = true
            if (arg == "--version") {
                i += 1
                if (i >= args.size) { return renderInspectCjpmErrorJson("missing-version", "--version needs a value") }
                version = args[i]
            } else { version = substringFrom(arg, 10) }
        } else if (arg != "--no-activate") { forwarded.add(arg) }
        i += 1
    }
    let component = ArrayList<String>()
    component.add(args[2] + "@" + version)
    for (arg in forwarded) { component.add(arg) }
    let options = resolveCangjiePackageInstallOptions(component.toArray(), 0)
    if (options.plan) { renderCangjiePackageInstallPlanJson(options) } else { runCangjiePackageInstall(options) }
}
