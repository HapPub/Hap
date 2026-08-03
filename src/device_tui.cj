package hapcli

import std.env.{getStdIn, getStdOut}

@When[os != "Windows"]
private const hapDeviceTermiosWordCount: Int64 = 64
@When[os != "Windows"]
private const hapDeviceApplyFlush: Int32 = 2

@When[os != "Windows"]
foreign func tcgetattr(fd: Int32, state: CPointer<Unit>): Int32
@When[os != "Windows"]
foreign func cfmakeraw(state: CPointer<Unit>): Unit
@When[os != "Windows"]
foreign func tcsetattr(fd: Int32, action: Int32, state: CPointer<Unit>): Int32
@When[os != "Windows"]
foreign func read(fd: Int32, buffer: CPointer<UInt8>, count: UIntNative): IntNative
@When[os != "Windows"]
foreign func isatty(fd: Int32): Int32

class HapDeviceTuiAction {
    var kind: String = "quit"
    var selected: Int64 = 0

    init() {}
}

@When[os != "Windows"]
class HapDeviceRawTerminal {
    let originalState: CPointer<UInt64>
    var closed: Bool = false

    private init(originalState: CPointer<UInt64>) {
        this.originalState = originalState
    }

    static func open(): HapDeviceRawTerminal {
        let original = unsafe { LibC.malloc<UInt64>(count: hapDeviceTermiosWordCount) }
        let raw = unsafe { LibC.malloc<UInt64>(count: hapDeviceTermiosWordCount) }
        try {
            if (original.isNull() || raw.isNull()) {
                throw IllegalMemoryException("Hap device TUI failed to allocate terminal state")
            }
            if (unsafe { tcgetattr(0, CPointer<Unit>(original)) } != 0) {
                throw IllegalStateException("Hap device TUI cannot read terminal state")
            }
            if (unsafe { tcgetattr(0, CPointer<Unit>(raw)) } != 0) {
                throw IllegalStateException("Hap device TUI cannot clone terminal state")
            }
            unsafe { cfmakeraw(CPointer<Unit>(raw)) }
            if (unsafe { tcsetattr(0, hapDeviceApplyFlush, CPointer<Unit>(raw)) } != 0) {
                throw IllegalStateException("Hap device TUI cannot enter raw mode")
            }
            unsafe { LibC.free(raw) }
            HapDeviceRawTerminal(original)
        } catch (e: Exception) {
            if (!raw.isNull()) { unsafe { LibC.free(raw) } }
            if (!original.isNull()) { unsafe { LibC.free(original) } }
            throw e
        }
    }

    func write(content: String): Unit {
        let stdout = getStdOut()
        stdout.write(content)
        stdout.flush()
    }

    func readKey(): String {
        let buffer = unsafe { LibC.malloc<UInt8>(count: 8) }
        if (buffer.isNull()) {
            return "error"
        }
        try {
            let count = unsafe { read(0, buffer, 8) }
            if (count <= 0) {
                return "end"
            }
            let bytes = Array<UInt8>(Int64(count), repeat: 0)
            var i: Int64 = 0
            while (i < Int64(count)) {
                bytes[i] = unsafe { buffer.read(i) }
                i += 1
            }
            decodeHapDeviceTuiKey(bytes)
        } finally {
            unsafe { LibC.free(buffer) }
        }
    }

    func close(): Unit {
        if (!closed) {
            unsafe { tcsetattr(0, hapDeviceApplyFlush, CPointer<Unit>(originalState)) }
            unsafe { LibC.free(originalState) }
            closed = true
        }
    }
}

@When[os != "Windows"]
public func runHapDeviceSetInteractive(options: HapDeviceOptions): String {
    if (unsafe { isatty(0) } == 0 || unsafe { isatty(1) } == 0) {
        return "Hap device failed\nStatus: interactive-terminal-unavailable\nTry: hap device set --alias <name> --platform <harmonyos|android|ios> --target <id>\n"
    }
    var selected: Int64 = 0
    var message = ""
    while (true) {
        let snapshot = inspectHapDevices(options)
        if (snapshot.entries.size == 0) {
            selected = 0
        } else if (selected >= snapshot.entries.size) {
            selected = snapshot.entries.size - 1
        }
        let action = runHapDeviceTuiScreen(snapshot, selected, message)
        selected = action.selected
        if (action.kind == "quit") {
            return "Hap device set closed\nRegistry: " + snapshot.registryPath + "\n"
        }
        if (action.kind == "add") {
            if (snapshot.entries.size == 0) {
                message = "No discovered device is selected; press n to add one manually."
                continue
            }
            let entry = snapshot.entries[selected]
            let alias = promptHapDeviceLine("Alias for " + entry.name + ": ")
            if (alias.size == 0) {
                message = "Alias creation cancelled."
                continue
            }
            let mutation = copyHapDeviceOptions(options)
            mutation.alias = alias
            mutation.platform = entry.platform
            mutation.target = entry.target
            mutation.name = entry.name
            message = runHapDeviceSet(mutation).replace("\n", " ")
            continue
        }
        if (action.kind == "new") {
            let platform = promptHapDeviceLine("Platform (harmonyos/android/ios): ")
            let target = promptHapDeviceLine("Device target/id: ")
            let alias = promptHapDeviceLine("Alias: ")
            let name = promptHapDeviceLine("Display name (optional): ")
            let mutation = copyHapDeviceOptions(options)
            mutation.platform = platform
            mutation.target = target
            mutation.alias = alias
            mutation.name = name
            message = runHapDeviceSet(mutation).replace("\n", " ")
            continue
        }
        if (snapshot.entries.size == 0) {
            message = "No device entry is selected."
            continue
        }
        let selectedEntry = snapshot.entries[selected]
        if (action.kind == "rename") {
            if (!selectedEntry.saved || !selectedEntry.mutable || selectedEntry.alias.size == 0) {
                message = "This row is discovery-only; press a to create a managed alias first."
                continue
            }
            let newAlias = promptHapDeviceLine("Rename " + selectedEntry.alias + " to: ")
            if (newAlias.size == 0) {
                message = "Rename cancelled."
                continue
            }
            let mutation = copyHapDeviceOptions(options)
            mutation.renameAlias = selectedEntry.alias + ":" + newAlias
            message = runHapDeviceSet(mutation).replace("\n", " ")
            continue
        }
        if (action.kind == "delete") {
            if (!selectedEntry.saved || !selectedEntry.mutable || selectedEntry.alias.size == 0) {
                message = "This row is not managed by the universal Hap device registry."
                continue
            }
            let confirm = promptHapDeviceLine("Delete alias " + selectedEntry.alias + "? [y/N]: ")
            if (confirm != "y" && confirm != "Y" && confirm != "yes") {
                message = "Delete cancelled."
                continue
            }
            let mutation = copyHapDeviceOptions(options)
            mutation.deleteAlias = selectedEntry.alias
            message = runHapDeviceSet(mutation).replace("\n", " ")
            continue
        }
        if (action.kind == "default") {
            var alias = selectedEntry.alias
            if (alias.size == 0 || !selectedEntry.mutable) {
                alias = promptHapDeviceLine("Alias before setting default: ")
                if (alias.size == 0) {
                    message = "Default selection cancelled."
                    continue
                }
                let add = copyHapDeviceOptions(options)
                add.alias = alias
                add.platform = selectedEntry.platform
                add.target = selectedEntry.target
                add.name = selectedEntry.name
                let addOutput = runHapDeviceSet(add)
                if (containsText(addOutput, "Hap device failed")) {
                    message = addOutput.replace("\n", " ")
                    continue
                }
            }
            let mutation = copyHapDeviceOptions(options)
            mutation.defaultAlias = alias
            message = runHapDeviceSet(mutation).replace("\n", " ")
            continue
        }
    }
    ""
}

@When[os == "Windows"]
public func runHapDeviceSetInteractive(options: HapDeviceOptions): String {
    "Hap device failed\n" +
    "Status: interactive-terminal-unavailable-on-windows\n" +
    "Try: hap device set --alias <name> --platform <harmonyos|android|ios> --target <id>\n"
}

@When[os != "Windows"]
func runHapDeviceTuiScreen(snapshot: HapDeviceSnapshot, initial: Int64, message: String): HapDeviceTuiAction {
    var selected = initial
    let terminal = HapDeviceRawTerminal.open()
    try {
        terminal.write("\u{001B}[?25l")
        while (true) {
            terminal.write(renderHapDeviceTuiFrame(snapshot, selected, message))
            let key = terminal.readKey()
            if (key == "up" || key == "k") {
                if (snapshot.entries.size > 0) {
                    selected = if (selected <= 0) { snapshot.entries.size - 1 } else { selected - 1 }
                }
            } else if (key == "down" || key == "j") {
                if (snapshot.entries.size > 0) {
                    selected = if (selected + 1 >= snapshot.entries.size) { 0 } else { selected + 1 }
                }
            } else if (key == "a") {
                return hapDeviceTuiAction("add", selected)
            } else if (key == "n") {
                return hapDeviceTuiAction("new", selected)
            } else if (key == "r") {
                return hapDeviceTuiAction("rename", selected)
            } else if (key == "d" || key == "delete") {
                return hapDeviceTuiAction("delete", selected)
            } else if (key == "s" || key == "enter") {
                return hapDeviceTuiAction("default", selected)
            } else if (key == "q" || key == "escape" || key == "end") {
                return hapDeviceTuiAction("quit", selected)
            }
        }
    } finally {
        terminal.write("\u{001B}[?25h\u{001B}[0m\n")
        terminal.close()
    }
    hapDeviceTuiAction("quit", selected)
}

func hapDeviceTuiAction(kind: String, selected: Int64): HapDeviceTuiAction {
    let action = HapDeviceTuiAction()
    action.kind = kind
    action.selected = selected
    action
}

public func renderHapDeviceTuiFrame(snapshot: HapDeviceSnapshot, selected: Int64, message: String): String {
    let cyan = "\u{001B}[0;36m"
    let green = "\u{001B}[0;32m"
    let yellow = "\u{001B}[0;33m"
    let dim = "\u{001B}[2m"
    let reverse = "\u{001B}[7m"
    let reset = "\u{001B}[0m"
    let out = StringBuilder()
    out.append("\u{001B}[2J\u{001B}[H")
    out.append(cyan + "Hap Device Manager" + reset + "\n")
    out.append(dim + snapshot.projectKind + " | " + snapshot.registryPath + reset + "\n\n")
    if (snapshot.entries.size == 0) {
        out.append(yellow + "No discovered or saved devices." + reset + "\n")
    } else {
        var i: Int64 = 0
        while (i < snapshot.entries.size) {
            let entry = snapshot.entries[i]
            let cursor = if (i == selected) { "›" } else { " " }
            let defaultMark = if (entry.isDefault) { "*" } else { " " }
            let connectedMark = if (entry.connected) { green + "●" + reset } else { dim + "○" + reset }
            let alias = if (entry.alias.size > 0) { entry.alias } else { "<no alias>" }
            let line = cursor + " " + connectedMark + defaultMark + " " + padHapDeviceText(alias, 16) + " " + padHapDeviceText(entry.platform, 10) + " " + entry.name + "  " + dim + entry.target + reset
            if (i == selected) {
                out.append(reverse + line + reset + "\n")
            } else {
                out.append(line + "\n")
            }
            i += 1
        }
    }
    out.append("\n")
    out.append(cyan + "↑/k ↓/j" + reset + " move   " + cyan + "a" + reset + " alias   " + cyan + "n" + reset + " new   " + cyan + "r" + reset + " rename   " + cyan + "d" + reset + " delete   " + cyan + "s/Enter" + reset + " default   " + cyan + "q" + reset + " quit\n")
    if (message.size > 0) {
        out.append("\n" + yellow + message + reset + "\n")
    }
    out.toString()
}

public func decodeHapDeviceTuiKey(bytes: Array<UInt8>): String {
    if (bytes.size == 0) { return "" }
    if (bytes[0] == 0x1B) {
        if (bytes.size >= 3 && bytes[1] == 0x5B) {
            return match (bytes[2]) {
                case 0x41 => "up"
                case 0x42 => "down"
                case 0x43 => "right"
                case 0x44 => "left"
                case 0x33 => "delete"
                case _ => "escape"
            }
        }
        return "escape"
    }
    if (bytes[0] == 0x0D || bytes[0] == 0x0A) { return "enter" }
    if (bytes[0] == 0x03) { return "end" }
    if (bytes[0] < 0x80) {
        return String.fromUtf8([bytes[0]])
    }
    "unknown"
}

func promptHapDeviceLine(prompt: String): String {
    let stdout = getStdOut()
    stdout.write(prompt)
    stdout.flush()
    match (getStdIn().readln()) {
        case Some(value) => trimAsciiText(value)
        case None => ""
    }
}

func copyHapDeviceOptions(source: HapDeviceOptions): HapDeviceOptions {
    let copy = HapDeviceOptions()
    copy.action = "set"
    copy.project = source.project
    copy.platform = source.platform
    copy.registry = source.registry
    copy.json = false
    copy.noProbe = true
    copy.allPlatforms = source.allPlatforms
    copy
}
