package hapcli

// Compatibility boundary for legacy handlers which already return JSON. Nested
// component success must never override the command's top-level outcome.
public class HapCommandOutcome {
    public let output: String
    public let exitCode: Int64
    public init(output: String, exitCode: Int64) {
        this.output = output
        this.exitCode = exitCode
    }
}

func commandJsonOk(output: String): String {
    let chars = output.toRuneArray()
    var depth: Int64 = 0
    var quoted = false
    var escaped = false
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < chars.size) {
        let c = chars[i]
        if (quoted) {
            if (escaped) { escaped = false }
            else if (c == r'\\') { escaped = true }
            else if (c == r'"') {
                quoted = false
                if (depth == 1 && substringRange(output, start, i + 1) == "\"ok\"") {
                    var end = i + 1
                    while (end < chars.size && (chars[end] == r' ' || chars[end] == r'\n' || chars[end] == r'\r' || chars[end] == r'\t')) { end += 1 }
                    if (end < chars.size && chars[end] == r':') { return jsonBoolValueAfter(output, start) }
                }
            }
        } else if (c == r'"') { quoted = true; start = i }
        else if (c == r'{' || c == r'[') { depth += 1 }
        else if (c == r'}' || c == r']') { depth -= 1 }
        i += 1
    }
    ""
}

func legacyCommandOutcome(output: String): HapCommandOutcome {
    // Read-only legacy reports without an `ok` field keep their existing exit.
    HapCommandOutcome(output, if (commandJsonOk(output) == "false") { 2 } else { 0 })
}

func emitHapJson(output: String): Int64 {
    let outcome = legacyCommandOutcome(output)
    println(outcome.output)
    outcome.exitCode
}
