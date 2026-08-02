package hapcli

import std.fs.File

public class HapHarmonyWirelessRecipeOptions {
    public var port: String = "5555"
    public var recipeOutput: String = ""
    public var receipt: String = ""
    public var reviewToken: String = ""
    public var requestExecute: Bool = false

    public init() {}
}

public func resolveHarmonyWirelessRecipeOptions(commandLine: Array<String>, startIndex: Int64): HapHarmonyWirelessRecipeOptions {
    let options = HapHarmonyWirelessRecipeOptions()
    var i = startIndex
    while (i < commandLine.size) {
        let current = commandLine[i]
        if (current == "--port" && i + 1 < commandLine.size) {
            options.port = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--port=")) {
            options.port = substringFrom(current, 7)
            i += 1
            continue
        }
        if (current == "--recipe-output" && i + 1 < commandLine.size) {
            options.recipeOutput = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--recipe-output=")) {
            options.recipeOutput = substringFrom(current, 16)
            i += 1
            continue
        }
        if (current == "--receipt" && i + 1 < commandLine.size) {
            options.receipt = commandLine[i + 1]
            i += 2
            continue
        }
        if (startsWithText(current, "--receipt=")) {
            options.receipt = substringFrom(current, 10)
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
        if (current == "--execute" || current == "--run") {
            options.requestExecute = true
            i += 1
            continue
        }
        i += 1
    }
    options
}

public func renderHarmonyWirelessRecipeJson(options: HapHarmonyWirelessRecipeOptions): String {
    let requiredOk = options.port.size > 0 && options.receipt.size > 0
    let reviewOk = options.reviewToken.size > 0
    let ok = requiredOk && reviewOk && !options.requestExecute
    let status = harmonyWirelessStatus(requiredOk, reviewOk, options.requestExecute)
    let recipe = if (options.requestExecute) {
        ""
    } else {
        renderHarmonyWirelessBashRecipe(options)
    }
    var recipeFileWritten = false
    if (ok && options.recipeOutput.size > 0 && recipe.size > 0) {
        File.writeTo(options.recipeOutput, (recipe + "\n").toArray())
        recipeFileWritten = true
    }

    let out = StringBuilder()
    out.append("{\n")
    out.append("  \"schema\": \"happub-hapcli-harmony-wireless-recipe-v0\",\n")
    out.append("  \"ok\": " + boolJson(ok) + ",\n")
    out.append("  \"mode\": \"reviewed-bash-recipe-only\",\n")
    out.append("  \"port\": \"" + escapeJson(options.port) + "\",\n")
    out.append("  \"receipt\": \"" + escapeJson(options.receipt) + "\",\n")
    out.append("  \"recipeOutput\": \"" + escapeJson(options.recipeOutput) + "\",\n")
    out.append("  \"recipeFileWritten\": " + boolJson(recipeFileWritten) + ",\n")
    out.append("  \"reviewTokenPresent\": " + boolJson(reviewOk) + ",\n")
    out.append("  \"directExecuteRequested\": " + boolJson(options.requestExecute) + ",\n")
    out.append("  \"status\": \"" + escapeJson(status) + "\",\n")
    out.append("  \"usbFirstRequired\": true,\n")
    out.append("  \"wirelessReconnectActionTaken\": false,\n")
    out.append("  \"deviceActionTaken\": false,\n")
    out.append("  \"networkActionTaken\": false,\n")
    out.append("  \"recipe\": \"" + escapeJson(recipe) + "\",\n")
    out.append("  \"nextAllowed\": [\n")
    out.append("    \"review-generated-harmony-wireless-recipe\",\n")
    out.append("    \"execute-recipe-output-only-after-device-owner-review\",\n")
    out.append("    \"record harmony wireless receipt before enabling allow-wireless reconnect\"\n")
    out.append("  ],\n")
    out.append("  \"nonPromises\": [\n")
    out.append("    \"harmony wireless recipe does not execute hdc from HapCLI\",\n")
    out.append("    \"wireless reconnect requires an existing USB-connected device at execution time\",\n")
    out.append("    \"the generated receipt records device bridge proof but does not certify app deploy success\",\n")
    out.append("    \"HapCLI does not silently remember or reuse device IP without a future trusted receipt layer\"\n")
    out.append("  ]\n")
    out.append("}")
    out.toString()
}

func harmonyWirelessStatus(requiredOk: Bool, reviewOk: Bool, requestExecute: Bool): String {
    if (requestExecute) {
        return "direct-execute-not-supported"
    }
    if (!requiredOk) {
        return "missing-required-field"
    }
    if (!reviewOk) {
        return "missing-review-token-for-harmony-wireless-recipe"
    }
    "ready-for-reviewed-shell-execution"
}

func renderHarmonyWirelessBashRecipe(options: HapHarmonyWirelessRecipeOptions): String {
    if (options.receipt.size == 0 || options.port.size == 0) {
        return ""
    }
    let out = StringBuilder()
    appendLine(out, "#!/bin/sh")
    appendLine(out, "set -eu")
    appendLine(out, "DEFAULT_PORT=" + shellQuote(options.port))
    appendLine(out, "PORT=$" + "{1:-$DEFAULT_PORT}")
    appendLine(out, "RECEIPT=" + shellQuote(options.receipt))
    appendLine(out, "WORK_DIR=$" + "{TMPDIR:-/tmp}/hap-harmony-wireless-$$")
    appendLine(out, "mkdir -p \"$WORK_DIR\"")
    appendLine(out, "LAST_STAGE=init")
    appendLine(out, "LAST_LOG=\"$WORK_DIR/init.log\"")
    appendLine(out, "need_cmd() { command -v \"$1\" >/dev/null 2>&1 || { echo \"missing required command: $1\" >&2; exit 127; }; }")
    appendLine(out, "write_failure() {")
    appendLine(out, "  STATUS=\"$1\"")
    appendLine(out, "  MESSAGE=\"$2\"")
    appendLine(out, "  mkdir -p \"$(dirname \"$RECEIPT\")\"")
    appendLine(out, "  printf '{\"schema\":\"happub-hapcli-harmony-wireless-receipt-v0\",\"ok\":false,\"status\":\"%s\",\"message\":\"%s\",\"stage\":\"%s\",\"lastLogPath\":\"%s\",\"usbFirstProof\":false,\"wirelessReconnectActionTaken\":false,\"deviceActionTaken\":true,\"networkActionTaken\":false}\\n' \"$STATUS\" \"$MESSAGE\" \"$LAST_STAGE\" \"$LAST_LOG\" > \"$RECEIPT\"")
    appendLine(out, "  cat \"$RECEIPT\" >&2")
    appendLine(out, "  exit 1")
    appendLine(out, "}")
    appendLine(out, "run_capture() {")
    appendLine(out, "  TIMEOUT_SECONDS=\"$1\"")
    appendLine(out, "  LABEL=\"$2\"")
    appendLine(out, "  OUT_FILE=\"$3\"")
    appendLine(out, "  shift 3")
    appendLine(out, "  LAST_STAGE=\"$LABEL\"")
    appendLine(out, "  LAST_LOG=\"$OUT_FILE\"")
    appendLine(out, "  \"$@\" > \"$OUT_FILE\" 2>&1 &")
    appendLine(out, "  RUN_PID=$!")
    appendLine(out, "  RUN_WAIT=0")
    appendLine(out, "  while kill -0 \"$RUN_PID\" 2>/dev/null; do")
    appendLine(out, "    if [ \"$RUN_WAIT\" -ge \"$TIMEOUT_SECONDS\" ]; then")
    appendLine(out, "      {")
    appendLine(out, "      kill \"$RUN_PID\" 2>/dev/null || true")
    appendLine(out, "      sleep 1")
    appendLine(out, "      kill -9 \"$RUN_PID\" 2>/dev/null || true")
    appendLine(out, "      wait \"$RUN_PID\" 2>/dev/null || true")
    appendLine(out, "      } 2>/dev/null")
    appendLine(out, "      return 124")
    appendLine(out, "    fi")
    appendLine(out, "    RUN_WAIT=$((RUN_WAIT + 1))")
    appendLine(out, "    sleep 1")
    appendLine(out, "  done")
    appendLine(out, "  wait \"$RUN_PID\"")
    appendLine(out, "}")
    appendLine(out, "need_cmd hdc")
    appendLine(out, "TARGET=\"\"")
    appendLine(out, "ATTEMPT=0")
    appendLine(out, "TARGETS_FILE=\"$WORK_DIR/targets.txt\"")
    appendLine(out, "while [ \"$ATTEMPT\" -lt 5 ]; do")
    appendLine(out, "  if run_capture 4 list-targets \"$TARGETS_FILE\" hdc list targets; then")
    appendLine(out, "    TARGET=$(sed -n '1p' \"$TARGETS_FILE\" || true)")
    appendLine(out, "  else")
    appendLine(out, "    TARGET=\"\"")
    appendLine(out, "  fi")
    appendLine(out, "  if [ -n \"$TARGET\" ]; then")
    appendLine(out, "    break")
    appendLine(out, "  fi")
    appendLine(out, "  ATTEMPT=$((ATTEMPT + 1))")
    appendLine(out, "  sleep 1")
    appendLine(out, "done")
    appendLine(out, "if [ -z \"$TARGET\" ]; then")
    appendLine(out, "  write_failure no-usb-target \"connect exactly one USB device first\"")
    appendLine(out, "fi")
    appendLine(out, "EXTRA=$(sed -n '2p' \"$TARGETS_FILE\" || true)")
    appendLine(out, "if [ -n \"$EXTRA\" ]; then")
    appendLine(out, "  write_failure multiple-targets \"keep exactly one USB device connected\"")
    appendLine(out, "fi")
    appendLine(out, "case \"$TARGET\" in")
    appendLine(out, "  *:*)")
    appendLine(out, "    write_failure tcp-target-not-usb \"current hdc target looks like TCP; connect USB first\"")
    appendLine(out, "    ;;")
    appendLine(out, "esac")
    appendLine(out, "IFCONFIG_FILE=\"$WORK_DIR/ifconfig-wlan0.txt\"")
    appendLine(out, "IP_ADDR_FILE=\"$WORK_DIR/ip-addr-wlan0.txt\"")
    appendLine(out, "if run_capture 6 read-ifconfig \"$IFCONFIG_FILE\" hdc -t \"$TARGET\" shell \"ifconfig wlan0 2>/dev/null\"; then")
    appendLine(out, "  IP=$(grep -w 'inet' \"$IFCONFIG_FILE\" | awk '{print $2}' | tr -d 'addr:' || true)")
    appendLine(out, "else")
    appendLine(out, "  IP=\"\"")
    appendLine(out, "fi")
    appendLine(out, "if [ -z \"$IP\" ]; then")
    appendLine(out, "  if run_capture 6 read-ip-addr \"$IP_ADDR_FILE\" hdc -t \"$TARGET\" shell \"ip addr show wlan0 2>/dev/null\"; then")
    appendLine(out, "    IP=$(grep 'inet ' \"$IP_ADDR_FILE\" | awk '{print $2}' | cut -d/ -f1 || true)")
    appendLine(out, "  else")
    appendLine(out, "    IP=\"\"")
    appendLine(out, "  fi")
    appendLine(out, "fi")
    appendLine(out, "if [ -z \"$IP\" ]; then")
    appendLine(out, "  write_failure missing-wifi-ip \"confirm the device is connected to Wi-Fi\"")
    appendLine(out, "fi")
    appendLine(out, "TMODE_FILE=\"$WORK_DIR/tmode-port.log\"")
    appendLine(out, "if ! run_capture 8 tmode-port \"$TMODE_FILE\" hdc -t \"$TARGET\" tmode port \"$PORT\"; then")
    appendLine(out, "  write_failure tmode-port-failed \"hdc tmode port did not finish successfully\"")
    appendLine(out, "fi")
    appendLine(out, "sleep 2")
    appendLine(out, "TCONN_FILE=\"$WORK_DIR/tconn.log\"")
    appendLine(out, "try_tconn_once() {")
    appendLine(out, "  if run_capture 5 tconn \"$TCONN_FILE\" hdc tconn \"$IP:$PORT\"; then")
    appendLine(out, "    return 0")
    appendLine(out, "  fi")
    appendLine(out, "  if grep -qi 'connected\\|repeat operation' \"$TCONN_FILE\" 2>/dev/null; then")
    appendLine(out, "    return 0")
    appendLine(out, "  fi")
    appendLine(out, "  return 1")
    appendLine(out, "}")
    appendLine(out, "TCONN_OK=false")
    appendLine(out, "ATTEMPT=0")
    appendLine(out, "while [ \"$ATTEMPT\" -lt 3 ]; do")
    appendLine(out, "  if try_tconn_once; then")
    appendLine(out, "    TCONN_OK=true")
    appendLine(out, "    break")
    appendLine(out, "  fi")
    appendLine(out, "  ATTEMPT=$((ATTEMPT + 1))")
    appendLine(out, "  sleep 2")
    appendLine(out, "done")
    appendLine(out, "if [ \"$TCONN_OK\" != \"true\" ]; then")
    appendLine(out, "  write_failure tconn-failed \"hdc tconn did not succeed after retries\"")
    appendLine(out, "fi")
    appendLine(out, "FINAL_TARGETS_FILE=\"$WORK_DIR/final-targets.txt\"")
    appendLine(out, "if run_capture 4 final-targets \"$FINAL_TARGETS_FILE\" hdc list targets; then")
    appendLine(out, "  FINAL_TARGETS=$(tr '\\n' ';' < \"$FINAL_TARGETS_FILE\" || true)")
    appendLine(out, "else")
    appendLine(out, "  FINAL_TARGETS=\"final-targets-timeout\"")
    appendLine(out, "fi")
    appendLine(out, "mkdir -p \"$(dirname \"$RECEIPT\")\"")
    appendLine(out, "printf '{\"schema\":\"happub-hapcli-harmony-wireless-receipt-v0\",\"ok\":true,\"target\":\"%s\",\"ip\":\"%s\",\"port\":\"%s\",\"stage\":\"complete\",\"workDir\":\"%s\",\"usbFirstProof\":true,\"wirelessReconnectActionTaken\":true,\"deviceActionTaken\":true,\"networkActionTaken\":true,\"finalTargets\":\"%s\"}\\n' \"$TARGET\" \"$IP\" \"$PORT\" \"$WORK_DIR\" \"$FINAL_TARGETS\" > \"$RECEIPT\"")
    appendLine(out, "cat \"$RECEIPT\"")
    trimTrailingNewlines(out.toString())
}
