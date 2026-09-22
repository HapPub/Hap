package hapcli

import std.collection.ArrayList
import std.process.{execute, executeWithOutput}

// -I ignores Python environment/startup imports and the current working directory.
// The helpers are compiled into this executable; no downloaded code is evaluated.
public func runHostTools(commandLine: Array<String>): Int64 {
    var python = ""
    for (candidate in ["python3", "python"]) {
        try {
            let (code, _, _) = executeWithOutput(candidate, ["-I", "-c", "import sys;sys.exit(0 if sys.version_info >= (3,11) else 2)"])
            if (code == 0) { python = candidate; break }
        } catch (_: Exception) {}
    }
    if (python.size == 0) {
        println(renderInspectCjpmErrorJson("python-required", "Host tools require Python 3.11 or newer on PATH."))
        return 2
    }
    let args = ArrayList<String>()
    args.add("-I")
    args.add("-c")
    args.add(embeddedHostTools())
    for (i in 1..commandLine.size) { args.add(commandLine[i]) }
    return execute(python, args.toArray())
}
