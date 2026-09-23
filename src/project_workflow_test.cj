package hapcli

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{Directory, File, exists}
import std.process.executeWithOutput
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class HapCjpmProfileParserContinuationOneTest {
    @TestCase
    public func harmonyReviewedDevRejectsPlaceholderLaunchConfig(): Unit {
        let root = "/tmp/hapcli-reviewed-exec-reviewed-exec-dev-placeholder-test"
        let config = root + "/happub.toml"
        let receipt = "/tmp/hapcli-reviewed-exec-reviewed-exec-dev-placeholder.receipt.json"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/usr/bin/true\"\n"
        ).toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--execute-reviewed",
            "--review-token",
            "reviewed",
            "--receipt",
            receipt
        ], 2)
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"missing-harmony-launch-config\""), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(2))
    }

}

@Test
public class HapCjpmProfileParserContinuationTwoTest {
    @TestCase
    public func harmonyDeviceMemoryWritePreservesTrustedEndpointHistory(): Unit {
        let root = "/tmp/hapcli-device-history-device-memory-history-write-test"
        let memory = root + "/.hapData/harmony-device-memory.json"
        createDirForTest(root + "/.hapData")
        File.writeTo(memory, ("{\"schema\":\"happub-hapcli-harmony-device-memory-v0\",\"trusted\":true,\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"target\":\"USB-OLD\",\"ip\":\"192.168.0.141\",\"port\":\"5602\",\"proofReceiptPath\":\"/tmp/hap-proof-old.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-07-04T10:00:00+08:00\",\"staleAfterSeconds\":\"3153600000\"}").toArray())
        let options = HapHarmonyDeviceMemoryOptions()
        options.project = root
        options.memory = memory
        options.receipt = ""
        options.timestamp = "local-dev-auto-usb-proof"
        let writeResult = writeHarmonyDeviceMemory(options, root, "USB-NEW", "10.0.0.88", "5555", "dev")
        let memoryText = String.fromUtf8(File.readFrom(memory))
        let endpoints = trustedHarmonyDeviceMemoryEndpoints(options)

        @Assert(writeResult.written, true)
        @Assert(containsForTest(memoryText, "\"history\": ["), true)
        @Assert(containsForTest(memoryText, "\"ip\":\"10.0.0.88\""), true)
        @Assert(containsForTest(memoryText, "\"ip\":\"192.168.0.141\""), true)
        @Assert(containsForTest(memoryText, "\"proofReceiptPath\": \"local-dev-auto-usb-proof\""), true)
        @Assert(endpoints.size, Int64(2))
        @Assert(endpoints[0].ip, "10.0.0.88")
        @Assert(endpoints[1].ip, "192.168.0.141")
    }

    @TestCase
    public func harmonyDeviceMemoryRejectsLegacyLocalDevAutoProofWithoutTimestamp(): Unit {
        let root = "/tmp/hapcli-device-history-device-memory-legacy-local-dev-proof-test"
        let memory = root + "/.hapData/harmony-device-memory.json"
        createDirForTest(root + "/.hapData")
        File.writeTo(memory, ("{\"schema\":\"happub-hapcli-harmony-device-memory-v0\",\"trusted\":true,\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"target\":\"USB-LEGACY\",\"ip\":\"192.168.0.187\",\"port\":\"5555\",\"proofReceiptPath\":\"\",\"proofAction\":\"dev\",\"promotedAt\":\"local-dev-auto-usb-proof\",\"staleAfterSeconds\":\"86400\"}").toArray())
        let options = HapHarmonyDeviceMemoryOptions()
        options.project = root
        options.memory = memory
        let readbackJson = renderHarmonyDeviceMemoryReadbackJson(options)
        let endpoints = trustedHarmonyDeviceMemoryEndpoints(options)

        @Assert(containsForTest(readbackJson, "\"ok\": false"), true)
        @Assert(containsForTest(readbackJson, "\"status\": \"trusted-device-memory-stale\""), true)
        @Assert(containsForTest(readbackJson, "\"staleStatus\": \"stale-time-unverifiable\""), true)
        @Assert(containsForTest(readbackJson, "\"proofReceiptPath\": \"local-dev-auto-usb-proof\""), true)
        @Assert(endpoints.size, Int64(0))
    }

}

@Test
public class HapCjpmProfileParserContinuationThreeTest {
    @TestCase
    public func harmonyExecutionHumanSummaryHidesRawJsonByDefault(): Unit {
        let json = (
            "{\n" +
            "  \"ok\": true,\n" +
            "  \"status\": \"reviewed-execution-succeeded\",\n" +
            "  \"diagnosis\": \"fixed HarmonyOS dev chain completed\",\n" +
            "  \"autoWirelessMemoryStatus\": \"trusted-device-memory-auto-cached\",\n" +
            "  \"autoWirelessIp\": \"192.168.0.77\",\n" +
            "  \"receiptPath\": \"/tmp/hap-dev.receipt.json\",\n" +
            "  \"nextManualCommands\": [\"hdc list targets\"]\n" +
            "}"
        )
        let summary = renderHarmonyExecutionHumanSummary(json)

        @Assert(containsForTest(summary, "Hap dev succeeded"), true)
        @Assert(containsForTest(summary, "Wireless memory: trusted-device-memory-auto-cached 192.168.0.77"), true)
        @Assert(containsForTest(summary, "Receipt: /tmp/hap-dev.receipt.json"), true)
        @Assert(containsForTest(summary, "\"ok\""), false)
        @Assert(containsForTest(renderHarmonyLocalDevProgressText(), ".... checking HarmonyOS device"), true)
        let frame = renderHarmonyLocalDevSpinnerFrame(0, false, true)
        let pulseFrame = renderHarmonyLocalDevSpinnerFrame(7, false, true)
        let doneFrame = renderHarmonyLocalDevSpinnerFrame(4, true, true)
        let failedFrame = renderHarmonyLocalDevSpinnerFrame(4, true, false)
        @Assert(containsForTest(frame, "\u{001B}[0;32m"), true)
        @Assert(containsForTest(frame, "⠋"), true)
        @Assert(containsForTest(frame, "⠁"), true)
        @Assert(containsForTest(pulseFrame, "⣿"), true)
        @Assert(containsForTest(frame, "⣀"), false)
        @Assert(containsForTest(doneFrame, "Hap dev completed"), true)
        @Assert(containsForTest(doneFrame, "100%"), true)
        @Assert(containsForTest(failedFrame, "\u{001B}[0;31m"), true)
        @Assert(containsForTest(failedFrame, "Hap dev failed"), true)
    }

    @TestCase
    public func harmonyExecutionHumanSummaryPrefersRealErrorOverMinifiedSource(): Unit {
        let logDir = "/tmp/hapcli-harmony-summary-priority-log-test"
        if (!exists(logDir)) {
            Directory.create(logDir, recursive: true)
        }
        File.writeTo((logDir + "/harmony-assemble-app.stderr.log"), (
            "/Applications/DevTools/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/@ohos/hvigor-common/src/util/file-lock.js:1\n" +
            "\"use strict\";function lockSync(e){throw new Error('The registration information of the daemon cannot be obtained. Delete daemon-sec.json.lock and try again')}\n" +
            "\n" +
            "Error: The registration information of the daemon cannot be obtained. Delete /Users/example/.hvigor/daemon/cache/daemon-sec.json.lock and try again\n" +
            "    at lockSync (/Applications/DevTools/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/@ohos/hvigor-common/src/util/file-lock.js:1:1071)\n" +
            "Node.js v23.4.0\n"
        ).toArray())
        let json = (
            "{\n" +
            "  \"ok\": false,\n" +
            "  \"status\": \"reviewed-execution-failed\",\n" +
            "  \"diagnosis\": \"fixed HarmonyOS dev chain failed at harmony-assemble-app; inspect stdoutLog and stderrLog for that command\",\n" +
            "  \"failedCommandLabel\": \"harmony-assemble-app\",\n" +
            "  \"logDir\": \"" + logDir + "\",\n" +
            "  \"nextManualCommands\": [\"hdc list targets\"]\n" +
            "}"
        )
        let summary = renderHarmonyExecutionHumanSummary(json)

        @Assert(containsForTest(summary, "Log excerpt (stderr):"), true)
        @Assert(containsForTest(summary, "Error: The registration information of the daemon cannot be obtained."), true)
        @Assert(containsForTest(summary, "daemon-sec.json.lock"), true)
        @Assert(containsForTest(summary, "\"use strict\""), false)
    }

    @TestCase
    public func harmonyWirelessRecipeRequiresReviewTokenBeforeWriting(): Unit {
        let options = resolveHarmonyWirelessRecipeOptions([
            "hap",
            "harmony",
            "wireless-recipe",
            "--receipt",
            "/tmp/hap-harmony-wireless.receipt.json",
            "--recipe-output",
            "/tmp/hap-harmony-wireless.sh"
        ], 3)
        let json = renderHarmonyWirelessRecipeJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-harmony-wireless-recipe-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"missing-review-token-for-harmony-wireless-recipe\""), true)
        @Assert(containsForTest(json, "\"recipeFileWritten\": false"), true)
        @Assert(containsForTest(json, "\"wirelessReconnectActionTaken\": false"), true)
    }

    @TestCase
    public func harmonyWirelessRecipeWritesUsbFirstTconnScriptAfterReview(): Unit {
        let output = "/tmp/hapcli-harmony-wireless-recipe-test.sh"
        let receipt = "/tmp/hapcli-harmony-wireless-recipe-test.receipt.json"
        let options = resolveHarmonyWirelessRecipeOptions([
            "hap",
            "harmony",
            "wireless-recipe",
            "--port",
            "5566",
            "--receipt",
            receipt,
            "--recipe-output",
            output,
            "--review-token",
            "reviewed-harmony-wireless"
        ], 3)
        let json = renderHarmonyWirelessRecipeJson(options)
        let script = String.fromUtf8(File.readFrom(output))

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"recipeFileWritten\": true"), true)
        @Assert(containsForTest(json, "\"deviceActionTaken\": false"), true)
        @Assert(containsForTest(script, "run_capture() {"), true)
        @Assert(containsForTest(script, "LAST_STAGE=\"$LABEL\""), true)
        @Assert(containsForTest(script, "\"stage\":\"%s\",\"lastLogPath\":\"%s\""), true)
        @Assert(containsForTest(script, "if run_capture 4 list-targets \"$TARGETS_FILE\" hdc list targets; then"), true)
        @Assert(containsForTest(script, "while [ \"$ATTEMPT\" -lt 5 ]; do"), true)
        @Assert(containsForTest(script, "write_failure no-usb-target"), true)
        @Assert(containsForTest(script, "current hdc target looks like TCP"), true)
        @Assert(containsForTest(script, "ifconfig wlan0"), true)
        @Assert(containsForTest(script, "ip addr show wlan0"), true)
        @Assert(containsForTest(script, "run_capture 6 read-ifconfig"), true)
        @Assert(containsForTest(script, "run_capture 6 read-ip-addr"), true)
        @Assert(containsForTest(script, "run_capture 8 tmode-port \"$TMODE_FILE\" hdc -t \"$TARGET\" tmode port \"$PORT\""), true)
        @Assert(containsForTest(script, "hdc tconn \"$IP:$PORT\""), true)
        @Assert(containsForTest(script, "try_tconn_once"), true)
        @Assert(containsForTest(script, "grep -qi 'connected\\|repeat operation' \"$TCONN_FILE\""), true)
        @Assert(containsForTest(script, "kill -9 \"$RUN_PID\""), true)
        @Assert(containsForTest(script, "return 124"), true)
        @Assert(containsForTest(script, "write_failure tconn-failed"), true)
        @Assert(containsForTest(script, "run_capture 4 final-targets"), true)
        @Assert(containsForTest(script, "\"happub-hapcli-harmony-wireless-receipt-v0\""), true)
        @Assert(containsForTest(script, "DEFAULT_PORT='5566'"), true)
    }

    @TestCase
    public func harmonyWirelessReadbackAcceptsTrustedReceiptWithoutDeviceAction(): Unit {
        let receipt = "/tmp/hapcli-harmony-wireless-readback.receipt.json"
        File.writeTo(receipt, "{\"schema\":\"happub-hapcli-harmony-wireless-receipt-v0\",\"ok\":true,\"target\":\"USB002\",\"ip\":\"192.168.0.112\",\"port\":\"5566\",\"stage\":\"complete\",\"usbFirstProof\":true,\"wirelessReconnectActionTaken\":true,\"deviceActionTaken\":true,\"networkActionTaken\":true}".toArray())
        let options = resolveHarmonyWirelessReadbackOptions([
            "hap",
            "harmony",
            "wireless-readback",
            "--receipt",
            receipt
        ], 3)
        let json = renderHarmonyWirelessReadbackJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-harmony-wireless-readback-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"trusted-wireless-receipt\""), true)
        @Assert(containsForTest(json, "\"target\": \"USB002\""), true)
        @Assert(containsForTest(json, "\"ip\": \"192.168.0.112\""), true)
        @Assert(containsForTest(json, "\"wirelessReconnectAllowedForPlan\": true"), true)
        @Assert(containsForTest(json, "\"deviceActionTaken\": false"), true)
    }

    @TestCase
    public func harmonyDeviceMemoryPromoteRequiresReviewToken(): Unit {
        let receipt = "/tmp/hapcli-device-memory-device-memory-missing-token.receipt.json"
        let memory = "/tmp/hapcli-device-memory-device-memory-missing-token.memory.json"
        File.writeTo(receipt, "{\"schema\":\"happub-hapcli-harmony-reviewed-execution-receipt-v0\",\"ok\":true,\"action\":\"dev\",\"project\":\"/tmp/harmony-demo\",\"projectKind\":\"harmonyos\",\"executionActionTaken\":true,\"deviceActionTaken\":true,\"trustedWirelessIp\":\"192.168.0.120\",\"trustedWirelessPort\":\"5555\"}".toArray())
        let options = resolveHarmonyDeviceMemoryOptions("promote", [
            "hap",
            "harmony",
            "device-memory",
            "promote",
            "--receipt",
            receipt,
            "--memory",
            memory,
            "--target",
            "USB003"
        ], 4)
        let json = runHarmonyDeviceMemoryPromote(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-harmony-device-memory-promote-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"missing-review-token\""), true)
        @Assert(containsForTest(json, "\"memoryMutationActionTaken\": false"), true)
    }

    @TestCase
    public func harmonyDeviceMemoryRejectsBuildReceiptAndNonDeviceAction(): Unit {
        let receipt = "/tmp/hapcli-device-memory-device-memory-build.receipt.json"
        let memory = "/tmp/hapcli-device-memory-device-memory-build.memory.json"
        File.writeTo(receipt, "{\"schema\":\"happub-hapcli-harmony-reviewed-execution-receipt-v0\",\"ok\":true,\"action\":\"build\",\"project\":\"/tmp/harmony-demo\",\"projectKind\":\"harmonyos\",\"executionActionTaken\":true,\"deviceActionTaken\":false,\"trustedWirelessIp\":\"192.168.0.121\",\"trustedWirelessPort\":\"5555\"}".toArray())
        let options = resolveHarmonyDeviceMemoryOptions("promote", [
            "hap",
            "harmony",
            "device-memory",
            "promote",
            "--receipt",
            receipt,
            "--memory",
            memory,
            "--target",
            "USB004",
            "--review-token",
            "reviewed-build-should-not-promote"
        ], 4)
        let json = runHarmonyDeviceMemoryPromote(options)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"receipt-action-not-promotable\""), true)
        @Assert(containsForTest(json, "\"memoryMutationActionTaken\": false"), true)
        @Assert(containsForTest(json, "reviewed-build-should-not-promote"), false)
    }

    @TestCase
    public func harmonyDeviceMemoryPromotesReviewedDevReceiptAndReadback(): Unit {
        let receipt = "/tmp/hapcli-device-memory-device-memory-dev.receipt.json"
        let memory = "/tmp/hapcli-device-memory-device-memory-dev.memory.json"
        File.writeTo(receipt, "{\"schema\":\"happub-hapcli-harmony-reviewed-execution-receipt-v0\",\"ok\":true,\"action\":\"dev\",\"project\":\"/tmp/harmony-demo\",\"projectKind\":\"harmonyos\",\"executionActionTaken\":true,\"deviceActionTaken\":true,\"trustedWirelessIp\":\"192.168.0.122\",\"trustedWirelessPort\":\"5577\"}".toArray())
        let promoteOptions = resolveHarmonyDeviceMemoryOptions("promote", [
            "hap",
            "harmony",
            "device-memory",
            "promote",
            "--receipt",
            receipt,
            "--memory",
            memory,
            "--target",
            "USB005",
            "--review-token",
            "SECRET_DEVICE_MEMORY_TOKEN",
            "--timestamp",
            "2026-06-30T17:10:00+08:00",
            "--stale-after-seconds",
            "3153600000"
        ], 4)
        let promoteJson = runHarmonyDeviceMemoryPromote(promoteOptions)
        let written = String.fromUtf8(File.readFrom(memory))
        let readbackJson = renderHarmonyDeviceMemoryReadbackJson(resolveHarmonyDeviceMemoryOptions("readback", [
            "hap",
            "harmony",
            "device-memory",
            "readback",
            "--memory",
            memory
        ], 4))

        @Assert(containsForTest(promoteJson, "\"ok\": true"), true)
        @Assert(containsForTest(promoteJson, "\"status\": \"trusted-device-memory-promoted\""), true)
        @Assert(containsForTest(promoteJson, "\"memoryMutationActionTaken\": true"), true)
        @Assert(containsForTest(promoteJson, "\"deviceActionTaken\": false"), true)
        @Assert(containsForTest(promoteJson, "\"target\": \"USB005\""), true)
        @Assert(containsForTest(promoteJson, "\"ip\": \"192.168.0.122\""), true)
        @Assert(containsForTest(written, "\"schema\": \"happub-hapcli-harmony-device-memory-v0\""), true)
        @Assert(containsForTest(written, "SECRET_DEVICE_MEMORY_TOKEN"), false)
        @Assert(containsForTest(promoteJson, "SECRET_DEVICE_MEMORY_TOKEN"), false)
        @Assert(containsForTest(readbackJson, "\"schema\": \"happub-hapcli-harmony-device-memory-readback-v0\""), true)
        @Assert(containsForTest(readbackJson, "\"ok\": true"), true)
        @Assert(containsForTest(readbackJson, "\"status\": \"trusted-device-memory\""), true)
        @Assert(containsForTest(readbackJson, "\"wirelessReconnectAllowedForExecutionGate\": true"), true)
    }

    @TestCase
    public func harmonyDeviceMemoryStalePolicyBlocksTrustedReadback(): Unit {
        let receipt = "/tmp/hapcli-device-memory-device-memory-stale.receipt.json"
        let memory = "/tmp/hapcli-device-memory-device-memory-stale.memory.json"
        File.writeTo(receipt, "{\"schema\":\"happub-hapcli-harmony-reviewed-execution-receipt-v0\",\"ok\":true,\"action\":\"push\",\"project\":\"/tmp/harmony-demo\",\"projectKind\":\"harmonyos\",\"executionActionTaken\":true,\"deviceActionTaken\":true,\"trustedWirelessIp\":\"192.168.0.123\",\"trustedWirelessPort\":\"5588\"}".toArray())
        let promoteOptions = resolveHarmonyDeviceMemoryOptions("promote", [
            "hap",
            "harmony",
            "device-memory",
            "promote",
            "--receipt",
            receipt,
            "--memory",
            memory,
            "--target",
            "USB006",
            "--review-token",
            "reviewed-stale-memory",
            "--stale-after-seconds",
            "0"
        ], 4)
        let promoteJson = runHarmonyDeviceMemoryPromote(promoteOptions)
        let readbackJson = renderHarmonyDeviceMemoryReadbackJson(resolveHarmonyDeviceMemoryOptions("readback", [
            "hap",
            "harmony",
            "device-memory",
            "readback",
            "--memory",
            memory
        ], 4))

        @Assert(containsForTest(promoteJson, "\"ok\": true"), true)
        @Assert(containsForTest(readbackJson, "\"ok\": false"), true)
        @Assert(containsForTest(readbackJson, "\"status\": \"trusted-device-memory-stale\""), true)
        @Assert(containsForTest(readbackJson, "\"staleStatus\": \"stale-by-policy\""), true)
        @Assert(containsForTest(readbackJson, "\"wirelessReconnectAllowedForExecutionGate\": false"), true)
    }

    @TestCase
    public func harmonyDeviceStatusReportsNeedsFirstUsbWhenNoMemory(): Unit {
        let memory = "/tmp/hapcli-device-status-device-status-missing.memory.json"
        let options = resolveHarmonyDeviceStatusOptions([
            "hap",
            "harmony",
            "device-status",
            "--project",
            "/tmp/harmony-demo",
            "--memory",
            memory
        ], 3)
        let json = renderHarmonyDeviceStatusJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-harmony-device-status-v0\""), true)
        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"needs-first-usb-dev\""), true)
        @Assert(containsForTest(json, "\"hdcActionTaken\": false"), true)
        @Assert(containsForTest(json, "run hap dev with USB connected"), true)
    }

    @TestCase
    public func harmonyDeviceStatusUsesTrustedMemoryWithoutTouchingDevice(): Unit {
        let receipt = "/tmp/hapcli-device-status-device-status-trusted.receipt.json"
        let memory = "/tmp/hapcli-device-status-device-status-trusted.memory.json"
        File.writeTo(receipt, "{\"schema\":\"happub-hapcli-harmony-reviewed-execution-receipt-v0\",\"ok\":true,\"action\":\"dev\",\"project\":\"/tmp/harmony-demo\",\"projectKind\":\"harmonyos\",\"executionActionTaken\":true,\"deviceActionTaken\":true,\"trustedWirelessIp\":\"192.168.0.124\",\"trustedWirelessPort\":\"5555\"}".toArray())
        let promoteOptions = resolveHarmonyDeviceMemoryOptions("promote", [
            "hap",
            "harmony",
            "device-memory",
            "promote",
            "--receipt",
            receipt,
            "--memory",
            memory,
            "--target",
            "USB007",
            "--review-token",
            "reviewed-status-memory"
        ], 4)
        let promoteJson = runHarmonyDeviceMemoryPromote(promoteOptions)
        let statusJson = renderHarmonyDeviceStatusJson(resolveHarmonyDeviceStatusOptions([
            "hap",
            "harmony",
            "device-status",
            "--project",
            "/tmp/harmony-demo",
            "--memory",
            memory
        ], 3))

        @Assert(containsForTest(promoteJson, "\"ok\": true"), true)
        @Assert(containsForTest(statusJson, "\"ok\": true"), true)
        @Assert(containsForTest(statusJson, "\"status\": \"ready-with-trusted-memory\""), true)
        @Assert(containsForTest(statusJson, "\"trustedWirelessIp\": \"192.168.0.124\""), true)
        @Assert(containsForTest(statusJson, "\"hdcActionTaken\": false"), true)
        @Assert(containsForTest(statusJson, "run hap dev to reconnect 192.168.0.124:5555"), true)
    }

}

@Test
public class HapCjpmProfileParserContinuationFourTest {
    @TestCase
    public func harmonyReviewedWirelessExecutionRejectsStaleDeviceMemoryBeforeCommands(): Unit {
        let root = "/tmp/hapcli-reviewed-wireless-reviewed-dev-stale-memory-test"
        let config = root + "/happub.toml"
        let memory = "/tmp/hapcli-reviewed-wireless-reviewed-dev-stale-memory.json"
        let receipt = "/tmp/hapcli-reviewed-wireless-reviewed-dev-stale-memory.receipt.json"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/usr/bin/true\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())
        File.writeTo(memory, ("{\"schema\":\"happub-hapcli-harmony-device-memory-v0\",\"trusted\":true,\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"target\":\"USB-MEM-STALE\",\"ip\":\"192.168.0.142\",\"port\":\"5603\",\"proofReceiptPath\":\"/tmp/hap-proof.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-06-30T14:57:00+08:00\",\"staleAfterSeconds\":\"0\"}").toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--allow-wireless",
            "--device-memory",
            memory,
            "--execute-reviewed",
            "--review-token",
            "reviewed-stale-reviewed-wireless",
            "--receipt",
            receipt
        ], 2)
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"trusted-device-memory-stale\""), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"deviceMemoryTrusted\": false"), true)
        @Assert(containsForTest(json, "\"commands\": []"), true)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(2))
    }

    @TestCase
    public func updatePlanRendersDependencyRecommendationsWithoutMutation(): Unit {
        let options = resolveUpdatePlanOptions("update", [
            "hap",
            "update",
            "dependencies",
            "--project",
            ".",
            "--target",
            "linux-amd64",
            "--plan"
        ], 2)
        let json = renderUpdatePlanJson(options)

        @Assert(containsForTest(json, "\"schema\": \"happub-hapcli-update-plan-v0\""), true)
        @Assert(containsForTest(json, "\"action\": \"update\""), true)
        @Assert(containsForTest(json, "\"subject\": \"dependencies\""), true)
        @Assert(containsForTest(json, "\"target\": \"linux-amd64\""), true)
        @Assert(containsForTest(json, "\"mutationActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"fixedCommandTemplates\": [\"hap ci action-doctor --workflow <workflow> --project <project>\", \"hap cjpm graph doctor --manifest <cjpm.toml>\", \"emit recommended dependency update candidates\"]"), true)
    }

    @TestCase
    public func upgradePlanRoutesHapSelfUpgradeThroughHapupWithoutExecuting(): Unit {
        let options = resolveUpdatePlanOptions("upgrade", [
            "hap",
            "upgrade",
            "hap",
            "--review-token",
            "reviewed",
            "--plan"
        ], 2)
        let json = renderUpdatePlanJson(options)

        @Assert(containsForTest(json, "\"action\": \"upgrade\""), true)
        @Assert(containsForTest(json, "\"subject\": \"hap\""), true)
        @Assert(containsForTest(json, "\"reviewTokenProvided\": true"), true)
        @Assert(containsForTest(json, "\"selfUpgradeActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"acceptedNow\": false"), true)
        @Assert(containsForTest(json, "\"hapup install-flagship --asset <reviewed-hap-asset> --sha256 <sha256>\""), true)
    }

    @TestCase
    public func updatePlanRejectsUnsupportedSubjectWithoutMutation(): Unit {
        let options = resolveUpdatePlanOptions("update", [
            "hap",
            "update",
            "brew",
            "--plan"
        ], 2)
        let json = renderUpdatePlanJson(options)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"unsupported-update-subject\""), true)
        @Assert(containsForTest(json, "\"mutationActionTaken\": false"), true)
    }

    @TestCase
    public func parsesHarmonyAndroidAndIosDeviceBackends(): Unit {
        let harmony = parseHdcDeviceList("USB001\n192.168.0.7:5555\n")
        @Assert(harmony.size, Int64(2))
        @Assert(harmony[0].platform, "harmonyos")
        @Assert(harmony[0].target, "USB001")
        @Assert(harmony[0].connected, true)

        let android = parseAdbDeviceList(
            "List of devices attached\n" +
            "emulator-5554 device product:sdk model:Pixel_8 transport_id:1\n" +
            "R3CN offline product:phone model:Galaxy_Tab transport_id:2\n"
        )
        @Assert(android.size, Int64(2))
        @Assert(android[0].name, "Pixel 8")
        @Assert(android[0].connected, true)
        @Assert(android[1].status, "offline")
        @Assert(android[1].connected, false)

        let ios = parseDevicectlDeviceList(
            "Demo Tablet   device.coredevice.local   123E4567-E89B-42D3-A456-426614174000   available (paired)\n"
        )
        @Assert(ios.size, Int64(1))
        @Assert(ios[0].name, "Demo Tablet")
        @Assert(ios[0].status, "available-paired")
        @Assert(ios[0].connected, true)
    }

    @TestCase
    public func roundTripsUniversalDeviceRegistryAndAliasResolution(): Unit {
        let registry = HapDeviceRegistry()
        registry.defaultHarmony = "tablet"
        registry.defaultIos = "ipad"
        let harmony = HapDeviceEntry()
        harmony.alias = "tablet"
        harmony.platform = "harmonyos"
        harmony.target = "USB001"
        harmony.name = "Harmony Tablet"
        registry.entries.add(harmony)
        let ios = HapDeviceEntry()
        ios.alias = "ipad"
        ios.platform = "ios"
        ios.target = "123E4567-E89B-42D3-A456-426614174000"
        ios.name = "Test iPad"
        registry.entries.add(ios)

        let rendered = renderHapDeviceRegistryToml(registry)
        let parsed = HapDeviceRegistry()
        parseHapDeviceRegistryText(rendered, parsed)

        @Assert(parsed.entries.size, Int64(2))
        @Assert(resolveHapDefaultDeviceAliasFromRegistry(parsed, "harmonyos"), "tablet")
        @Assert(resolveHapDefaultDeviceAliasFromRegistry(parsed, "ios"), "ipad")
        @Assert(resolveHapDeviceAliasFromRegistry(parsed, "tablet", "harmonyos"), "USB001")
        @Assert(resolveHapDeviceAliasFromRegistry(parsed, "tablet", "ios"), "tablet")
        @Assert(containsForTest(rendered, "schema = \"happub-hapcli-device-registry-v0\""), true)
    }

    @TestCase
    public func mutatesDeviceRegistryWithBackupRenameDefaultAndDelete(): Unit {
        let root = "/tmp/hapcli-device-registry-device-registry-test"
        let registryPath = root + "/devices.toml"
        createDirForTest(root)
        File.writeTo(registryPath, "schema = \"happub-hapcli-device-registry-v0\"\n\n[defaults]\nharmonyos = \"\"\nandroid = \"\"\nios = \"\"\n".toArray())

        let add = HapDeviceOptions()
        add.registry = registryPath
        add.alias = "tablet"
        add.platform = "harmonyos"
        add.target = "USB001"
        add.name = "Harmony Tablet"
        let addResult = applyHapDeviceMutation(add, readHapDeviceRegistry(add))
        @Assert(addResult.ok, true)
        @Assert(addResult.backupWritten, true)
        @Assert(exists(registryPath + ".hap-backup"), true)

        let makeDefault = HapDeviceOptions()
        makeDefault.registry = registryPath
        makeDefault.defaultAlias = "tablet"
        let defaultResult = applyHapDeviceMutation(makeDefault, readHapDeviceRegistry(makeDefault))
        @Assert(defaultResult.ok, true)

        let rename = HapDeviceOptions()
        rename.registry = registryPath
        rename.renameAlias = "tablet:living-room"
        let renameResult = applyHapDeviceMutation(rename, readHapDeviceRegistry(rename))
        @Assert(renameResult.ok, true)
        let renamedRegistry = readHapDeviceRegistry(rename)
        @Assert(resolveHapDefaultDeviceAliasFromRegistry(renamedRegistry, "harmonyos"), "living-room")
        @Assert(resolveHapDeviceAliasFromRegistry(renamedRegistry, "living-room", "harmonyos"), "USB001")

        let delete = HapDeviceOptions()
        delete.registry = registryPath
        delete.deleteAlias = "living-room"
        let deleteResult = applyHapDeviceMutation(delete, readHapDeviceRegistry(delete))
        @Assert(deleteResult.ok, true)
        let deletedRegistry = readHapDeviceRegistry(delete)
        @Assert(deletedRegistry.entries.size, Int64(0))
        @Assert(resolveHapDefaultDeviceAliasFromRegistry(deletedRegistry, "harmonyos"), "")
    }

    @TestCase
    public func rendersDeviceTuiKeysAndSelectionFrame(): Unit {
        @Assert(decodeHapDeviceTuiKey([0x1B, 0x5B, 0x41]), "up")
        @Assert(decodeHapDeviceTuiKey([0x1B, 0x5B, 0x42]), "down")
        @Assert(decodeHapDeviceTuiKey([0x0D]), "enter")
        @Assert(decodeHapDeviceTuiKey([0x71]), "q")

        let snapshot = HapDeviceSnapshot()
        snapshot.projectKind = "harmonyos"
        snapshot.registryPath = "/tmp/devices.toml"
        let entry = HapDeviceEntry()
        entry.alias = "tablet"
        entry.platform = "harmonyos"
        entry.target = "USB001"
        entry.name = "Harmony Tablet"
        entry.connected = true
        entry.isDefault = true
        snapshot.entries.add(entry)
        let frame = renderHapDeviceTuiFrame(snapshot, 0, "ready")
        @Assert(containsForTest(frame, "Hap Device Manager"), true)
        @Assert(containsForTest(frame, "tablet"), true)
        @Assert(containsForTest(frame, "a" + "\u{001B}[0m" + " alias"), true)
        @Assert(containsForTest(frame, "s/Enter"), true)
        @Assert(containsForTest(frame, "ready"), true)
    }

    @TestCase
    public func noProbeReceiptDoesNotClaimExecution(): Unit {
        let root = "/tmp/hapcli-device-registry-no-probe-project"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        let options = HapDeviceOptions()
        options.project = root
        options.platform = "harmonyos"
        options.noProbe = true
        options.registry = root + "/devices.toml"
        let json = renderHapDeviceSnapshotJson(inspectHapDevices(options))
        @Assert(containsForTest(json, "\"probeRequested\": false"), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"mutationActionTaken\": false"), true)
    }

    @TestCase
    public func deviceSubsystemRecognizesPlainAndroidProject(): Unit {
        let root = "/tmp/hapcli-device-registry-android-project"
        createDirForTest(root + "/app/src/main")
        File.writeTo(root + "/app/src/main/AndroidManifest.xml", "<manifest package=\"dev.hap.demo\"/>".toArray())
        let options = HapDeviceOptions()
        options.project = root
        options.noProbe = true
        options.registry = root + "/devices.toml"
        let json = renderHapDeviceSnapshotJson(inspectHapDevices(options))
        @Assert(containsForTest(json, "\"projectKind\": \"android\""), true)
        @Assert(containsForTest(json, "\"selectionStatus\": \"selected\""), true)
        @Assert(containsForTest(json, "\"requestedPlatforms\": [\"android\"]"), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": false"), true)
    }

}
