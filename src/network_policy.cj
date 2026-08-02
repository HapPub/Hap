package hapcli

import std.collection.ArrayList
import std.fs.exists

public class HapNetworkCommand {
    public var program: String = ""
    public let args: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func normalizeHapNetworkMode(mode: String): String {
    if (trimAsciiText(mode) == "proxy") { "proxy" } else { "no-proxy" }
}

public func resolveHapNetworkCommand(mode: String, program: String, args: Array<String>): HapNetworkCommand {
    resolveHapNetworkCommandWithAssignments(mode, [], program, args)
}

public func resolveHapNetworkCommandWithAssignments(
    mode: String,
    assignments: Array<String>,
    program: String,
    args: Array<String>
): HapNetworkCommand {
    let command = HapNetworkCommand()
    if (normalizeHapNetworkMode(mode) == "proxy" && assignments.size == 0) {
        command.program = program
        for (arg in args) {
            command.args.add(arg)
        }
        return command
    }

    command.program = hapEnvProgram()
    if (normalizeHapNetworkMode(mode) == "no-proxy") {
        for (name in hapProxyEnvironmentVariables()) {
            command.args.add("-u")
            command.args.add(name)
        }
    }
    for (assignment in assignments) {
        command.args.add(assignment)
    }
    command.args.add(program)
    for (arg in args) {
        command.args.add(arg)
    }
    command
}

public func hapProxyEnvironmentVariables(): Array<String> {
    [
        "HTTP_PROXY",
        "HTTPS_PROXY",
        "ALL_PROXY",
        "FTP_PROXY",
        "NO_PROXY",
        "http_proxy",
        "https_proxy",
        "all_proxy",
        "ftp_proxy",
        "no_proxy"
    ]
}

func hapEnvProgram(): String {
    if (exists("/usr/bin/env")) {
        return "/usr/bin/env"
    }
    if (exists("/bin/env")) {
        return "/bin/env"
    }
    "env"
}
