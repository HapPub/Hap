package hapcli

import std.env.getCommandLine

public let HapCliVersion: String = "0.3.0"

public func version(): String {
    HapCliVersion
}

main(): Int64 {
    let commandLine = getCommandLine()
    runHapCli(commandLine)
}
