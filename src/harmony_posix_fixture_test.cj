package hapcli

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{Directory, File, exists}
import std.process.executeWithOutput
import std.unittest.*
import std.unittest.testmacro.*

@When[os != "Windows"]
@Test
public class HapHarmonyReviewedBuildPosixFixtureTest {
    @TestCase
    public func harmonyReviewedExecutionRunsFixedBuildCommandAndWritesReceipt(): Unit {
        let root = "/tmp/hapcli-reviewed-exec-reviewed-exec-build-test"
        let config = root + "/happub.toml"
        let receipt = "/tmp/hapcli-reviewed-exec-reviewed-exec-build.receipt.json"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-local-dev-ok-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())

        let options = resolveProjectActionOptions("build", [
            "hap",
            "build",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--execute-reviewed",
            "--review-token",
            "SECRET_REVIEW_TOKEN_123",
            "--receipt",
            receipt,
            "--log-dir",
            "/tmp/hapcli-reviewed-exec-reviewed-exec-build-logs"
        ], 2)
        let json = renderHarmonyReviewedExecutionJson(options, true)
        let receiptText = String.fromUtf8(File.readFrom(receipt))

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"reviewed-execution-succeeded\""), true)
        @Assert(containsForTest(json, "\"executionActionTaken\": true"), true)
        @Assert(containsForTest(json, "\"memoryMutationActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"program\":\"/usr/bin/true\""), true)
        @Assert(containsForTest(json, "\"args\":[\"assembleApp\", \"--mode\", \"project\", \"-p\", \"product=default\", \"-p\", \"buildMode=debug\"]"), true)
        @Assert(containsForTest(json, "\"reviewTokenPresent\": true"), true)
        @Assert(containsForTest(json, "SECRET_REVIEW_TOKEN_123"), false)
        @Assert(containsForTest(receiptText, "\"schema\": \"happub-hapcli-harmony-reviewed-execution-receipt-v0\""), true)
        @Assert(containsForTest(receiptText, "SECRET_REVIEW_TOKEN_123"), false)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(0))
    }

}

@When[os != "Windows"]
@Test
public class HapHarmonyLocalDevPosixFixtureTest {
    @TestCase
    public func harmonyLocalDevAutoRunsBuildInstallLaunchAndPidofWithoutReviewToken(): Unit {
        let root = "/tmp/hapcli-local-dev-local-dev-auto-test"
        let config = root + "/happub.toml"
        let receipt = root + "/.hapData/receipts/harmony-dev-latest.receipt.json"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-local-dev-ok-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())

        writeExecutableForTest("/tmp/hapcli-local-dev-ok-hdc", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"list\" ]; then echo USB001; exit 0; fi\n" +
            "if [ \"$1\" = \"shell\" ] && [ \"$2\" = \"pidof\" ]; then echo 12345; exit 0; fi\n" +
            "exit 0\n"
        ))

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--write-receipt"
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)
        let receiptText = String.fromUtf8(File.readFrom(receipt))

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"executionGate\": \"local-dev-auto\""), true)
        @Assert(containsForTest(json, "\"localDevAutoRequested\": true"), true)
        @Assert(containsForTest(json, "\"reviewTokenPresent\": false"), true)
        @Assert(containsForTest(json, "\"selfCheckActionTaken\": true"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-verify-pidof\""), true)
        @Assert(containsForTest(json, "\"args\":[\"shell\", \"pidof\", \"cn.example.demo\"]"), true)
        @Assert(containsForTest(json, "\"diagnosis\": \"fixed HarmonyOS dev chain completed\""), true)
        @Assert(containsForTest(json, "\"nextManualCommands\": [\"/tmp/hapcli-local-dev-ok-hdc list targets\", \"/usr/bin/true assembleApp --mode project -p product=default -p buildMode=debug\", \"/tmp/hapcli-local-dev-ok-hdc install -r /tmp/app.hap\", \"/tmp/hapcli-local-dev-ok-hdc shell aa start -b cn.example.demo -a EntryAbility\", \"/tmp/hapcli-local-dev-ok-hdc shell pidof cn.example.demo\"]"), true)
        @Assert(containsForTest(receiptText, "\"executionGate\": \"local-dev-auto\""), true)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(0))
    }

    @TestCase
    public func harmonyLocalDevAutoInfersLaunchConfigBeforeExecution(): Unit {
        let root = "/tmp/hapcli-local-dev-local-dev-auto-infer-test"
        let config = root + "/happub.toml"
        createDirForTest(root + "/AppScope")
        createDirForTest(root + "/Product/src/main")
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(root + "/AppScope/app.json5", "{\"app\":{\"bundleName\":\"cn.cryI.fileMgr\"}}".toArray())
        File.writeTo(root + "/Product/src/main/module.json5", "{\"module\":{\"name\":\"Product\",\"mainElement\":\"ProductAbility\"}}".toArray())
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-local-dev-infer-ok-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n"
        ).toArray())

        writeExecutableForTest("/tmp/hapcli-local-dev-infer-ok-hdc", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"list\" ]; then echo USB001; exit 0; fi\n" +
            "if [ \"$1\" = \"shell\" ] && [ \"$2\" = \"pidof\" ]; then echo 67890; exit 0; fi\n" +
            "exit 0\n"
        ))

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--device-memory",
            root + "/.hapData/missing-device-memory.json"
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"harmonyConfigSource\": \"explicit-config+project-inference\""), true)
        @Assert(containsForTest(json, "\"args\":[\"shell\", \"aa\", \"start\", \"-b\", \"cn.cryI.fileMgr\", \"-a\", \"ProductAbility\"]"), true)
        @Assert(containsForTest(json, "\"args\":[\"shell\", \"pidof\", \"cn.cryI.fileMgr\"]"), true)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(0))
    }

    @TestCase
    public func harmonyLocalDevAutoTreatsHdcFailTextAsFailure(): Unit {
        let root = "/tmp/hapcli-hdc-truth-local-dev-hdc-fail-text-test"
        let config = root + "/happub.toml"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest("/tmp/hapcli-hdc-truth-fail-text-hdc", (
            "#!/bin/sh\n" +
            "echo '[Fail]ExecuteCommand need connect-key? please confirm a device by help info'\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-hdc-truth-fail-text-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--device-memory",
            root + "/.hapData/missing-device-memory.json"
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"deviceActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"selfCheckActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"failedCommandLabel\": \"hdc-list-targets\""), true)
        @Assert(containsForTest(json, "\"rawExitCode\":0,\"exitCode\":1,\"semanticStatus\":\"hdc-output-failure\""), true)
        @Assert(containsForTest(json, root + "/Product/build"), false)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(1))
    }

    @TestCase
    public func harmonyLocalDevAutoRequiresPidofNumericPid(): Unit {
        let root = "/tmp/hapcli-hdc-truth-local-dev-pidof-numeric-test"
        let config = root + "/happub.toml"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest("/tmp/hapcli-hdc-truth-bad-pidof-hdc", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"list\" ]; then echo USB001; exit 0; fi\n" +
            "if [ \"$1\" = \"shell\" ] && [ \"$2\" = \"pidof\" ]; then echo ''; exit 0; fi\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-hdc-truth-bad-pidof-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"deviceActionTaken\": true"), true)
        @Assert(containsForTest(json, "\"selfCheckActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"failedCommandLabel\": \"hdc-verify-pidof\""), true)
        @Assert(containsForTest(json, "\"semanticStatus\":\"pidof-missing-numeric-pid\""), true)
        @Assert(containsForTest(json, "\"diagnosis\": \"HarmonyOS launch self-check failed because pidof did not return a numeric PID\""), true)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(1))
    }

    @TestCase
    public func harmonyLocalDevAutoUsesTrustedDeviceMemoryForWirelessReconnectBeforeListTargets(): Unit {
        let root = "/tmp/hapcli-hdc-truth-local-dev-auto-memory-reconnect-test"
        let config = root + "/happub.toml"
        let memory = root + "/.hapData/harmony-device-memory.json"
        createDirForTest(root + "/.hapData")
        File.writeTo(memory, "{}".toArray())
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest("/tmp/hapcli-hdc-truth-memory-hdc", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"tconn\" ]; then echo connected; exit 0; fi\n" +
            "if [ \"$1\" = \"list\" ]; then echo 192.168.0.141:5602; exit 0; fi\n" +
            "if [ \"$1\" = \"shell\" ] && [ \"$2\" = \"pidof\" ]; then echo 24680; exit 0; fi\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-hdc-truth-memory-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())
        File.writeTo(memory, ("{\"schema\":\"happub-hapcli-harmony-device-memory-v0\",\"trusted\":true,\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"target\":\"USB-MEM-AUTO\",\"ip\":\"192.168.0.141\",\"port\":\"5602\",\"proofReceiptPath\":\"/tmp/hap-proof.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-07-04T10:00:00+08:00\",\"staleAfterSeconds\":\"3153600000\"}").toArray())

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--device-memory",
            memory
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"wirelessTrustSource\": \"device-memory\""), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": true"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-trusted-wireless-reconnect\""), true)
        @Assert(containsForTest(json, "\"args\":[\"tconn\", \"192.168.0.141:5602\"]"), true)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(0))
    }

    @TestCase
    public func harmonyLocalDevAutoFallsBackToUsbWhenTrustedWirelessReconnectIsStale(): Unit {
        let root = "/tmp/hapcli-stale-wireless-local-dev-stale-wireless-usb-fallback-test"
        let config = root + "/happub.toml"
        let memory = root + "/.hapData/harmony-device-memory.json"
        createDirForTest(root + "/.hapData")
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest("/tmp/hapcli-stale-wireless-stale-wireless-fallback-hdc", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"tconn\" ] && [ \"$2\" = \"192.168.0.141:5602\" ]; then echo 'failed to connect'; exit 1; fi\n" +
            "if [ \"$1\" = \"list\" ]; then echo USB009; exit 0; fi\n" +
            "if [ \"$1\" = \"shell\" ] && [ \"$2\" = \"pidof\" ]; then echo 22446; exit 0; fi\n" +
            "if [ \"$1\" = \"-t\" ] && [ \"$3\" = \"shell\" ] && [ \"$4\" = \"ifconfig\" ]; then echo 'inet 10.0.0.88 netmask 255.255.255.0'; exit 0; fi\n" +
            "if [ \"$1\" = \"-t\" ] && [ \"$3\" = \"tmode\" ]; then echo 'OK'; exit 0; fi\n" +
            "if [ \"$1\" = \"tconn\" ]; then echo connected; exit 0; fi\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-stale-wireless-stale-wireless-fallback-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())
        File.writeTo(memory, ("{\"schema\":\"happub-hapcli-harmony-device-memory-v0\",\"trusted\":true,\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"target\":\"USB-MEM-STALE-IP\",\"ip\":\"192.168.0.141\",\"port\":\"5602\",\"proofReceiptPath\":\"/tmp/hap-proof.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-07-04T10:00:00+08:00\",\"staleAfterSeconds\":\"3153600000\"}").toArray())

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--device-memory",
            memory
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)
        let memoryText = String.fromUtf8(File.readFrom(memory))

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-trusted-wireless-reconnect\""), true)
        @Assert(containsForTest(json, "\"args\":[\"tconn\", \"192.168.0.141:5602\"]"), true)
        @Assert(containsForTest(json, "\"rawExitCode\":1,\"exitCode\":1,\"semanticStatus\":\"raw-exit-nonzero\""), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-list-targets\""), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-verify-pidof\""), true)
        @Assert(containsForTest(json, "\"failedCommandLabel\": \"\""), true)
        @Assert(containsForTest(json, "\"diagnosis\": \"fixed HarmonyOS dev chain completed\""), true)
        @Assert(containsForTest(json, "\"autoWirelessMemoryStatus\": \"trusted-device-memory-auto-cached\""), true)
        @Assert(containsForTest(json, "\"autoWirelessIp\": \"10.0.0.88\""), true)
        @Assert(containsForTest(memoryText, "\"target\": \"USB009\""), true)
        @Assert(containsForTest(memoryText, "\"ip\": \"10.0.0.88\""), true)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(0))
    }

    @TestCase
    public func harmonyLocalDevAutoTimesOutStaleWirelessBeforeUsbFallback(): Unit {
        let root = "/tmp/hapcli-wireless-timeout-local-dev-stale-wireless-timeout-usb-fallback-test"
        let config = root + "/happub.toml"
        let memory = root + "/.hapData/harmony-device-memory.json"
        createDirForTest(root + "/.hapData")
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest("/tmp/hapcli-wireless-timeout-stale-wireless-timeout-hdc", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"tconn\" ] && [ \"$2\" = \"192.168.0.141:5602\" ]; then sleep 5; echo late-connect; exit 0; fi\n" +
            "if [ \"$1\" = \"list\" ]; then echo USB049; exit 0; fi\n" +
            "if [ \"$1\" = \"shell\" ] && [ \"$2\" = \"pidof\" ]; then echo 49049; exit 0; fi\n" +
            "if [ \"$1\" = \"-t\" ] && [ \"$3\" = \"shell\" ] && [ \"$4\" = \"ifconfig\" ]; then echo 'inet 10.0.0.49 netmask 255.255.255.0'; exit 0; fi\n" +
            "if [ \"$1\" = \"-t\" ] && [ \"$3\" = \"tmode\" ]; then echo 'OK'; exit 0; fi\n" +
            "if [ \"$1\" = \"tconn\" ]; then echo connected; exit 0; fi\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-wireless-timeout-stale-wireless-timeout-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n" +
            "deviceProbeTimeoutSeconds = 1\n"
        ).toArray())
        File.writeTo(memory, ("{\"schema\":\"happub-hapcli-harmony-device-memory-v0\",\"trusted\":true,\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"target\":\"USB-MEM-TIMEOUT\",\"ip\":\"192.168.0.141\",\"port\":\"5602\",\"proofReceiptPath\":\"/tmp/hap-proof.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-07-04T10:00:00+08:00\",\"staleAfterSeconds\":\"3153600000\"}").toArray())

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--device-memory",
            memory
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"deviceProbeTimeoutSeconds\": \"1\""), true)
        @Assert(containsForTest(json, "\"deviceProbeTimeoutEnforced\": true"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-trusted-wireless-reconnect\""), true)
        @Assert(containsForTest(json, "\"rawExitCode\":124,\"exitCode\":1,\"semanticStatus\":\"raw-exit-nonzero\""), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-list-targets\""), true)
        @Assert(containsForTest(json, "\"label\":\"harmony-assemble-app\""), true)
        @Assert(containsForTest(json, "\"autoWirelessIp\": \"10.0.0.49\""), true)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(0))
    }

    @TestCase
    public func harmonyLocalDevAutoTriesDeviceMemoryHistoryBeforeUsbScan(): Unit {
        let root = "/tmp/hapcli-device-history-local-dev-history-wireless-test"
        let config = root + "/happub.toml"
        let memory = root + "/.hapData/harmony-device-memory.json"
        createDirForTest(root + "/.hapData")
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest("/tmp/hapcli-device-history-history-wireless-hdc", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"tconn\" ] && [ \"$2\" = \"192.168.0.141:5602\" ]; then echo 'failed to connect'; exit 1; fi\n" +
            "if [ \"$1\" = \"tconn\" ] && [ \"$2\" = \"10.0.0.88:5555\" ]; then echo connected; exit 0; fi\n" +
            "if [ \"$1\" = \"list\" ]; then exit 0; fi\n" +
            "if [ \"$1\" = \"shell\" ] && [ \"$2\" = \"pidof\" ]; then echo 77881; exit 0; fi\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-device-history-history-wireless-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())
        File.writeTo(memory, (
            "{\n" +
            "  \"schema\":\"happub-hapcli-harmony-device-memory-v0\",\n" +
            "  \"trusted\":true,\n" +
            "  \"project\":\"" + root + "\",\n" +
            "  \"projectFingerprint\":\"path:" + root + "\",\n" +
            "  \"target\":\"USB-OLD\",\n" +
            "  \"ip\":\"192.168.0.141\",\n" +
            "  \"port\":\"5602\",\n" +
            "  \"proofReceiptPath\":\"/tmp/hap-proof-old.json\",\n" +
            "  \"proofAction\":\"dev\",\n" +
            "  \"promotedAt\":\"2026-07-04T10:00:00+08:00\",\n" +
            "  \"staleAfterSeconds\":\"3153600000\",\n" +
            "  \"history\": [\n" +
            "    {\"target\":\"USB-OLD\",\"ip\":\"192.168.0.141\",\"port\":\"5602\",\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"proofReceiptPath\":\"/tmp/hap-proof-old.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-07-04T10:00:00+08:00\",\"staleAfterSeconds\":\"3153600000\"},\n" +
            "    {\"target\":\"USB-NEW\",\"ip\":\"10.0.0.88\",\"port\":\"5555\",\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"proofReceiptPath\":\"/tmp/hap-proof-new.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-07-05T10:00:00+08:00\",\"staleAfterSeconds\":\"3153600000\"}\n" +
            "  ]\n" +
            "}"
        ).toArray())

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--device-memory",
            memory
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-trusted-wireless-reconnect\""), true)
        @Assert(containsForTest(json, "\"args\":[\"tconn\", \"192.168.0.141:5602\"]"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-list-targets\""), false)
        @Assert(containsForTest(json, "\"label\":\"hdc-trusted-wireless-reconnect-2\""), true)
        @Assert(containsForTest(json, "\"args\":[\"tconn\", \"10.0.0.88:5555\"]"), true)
        @Assert(containsForTest(json, "\"label\":\"harmony-assemble-app\""), true)
        @Assert(containsForTest(json, "\"autoWirelessMemoryStatus\": \"already-using-trusted-wireless-memory\""), true)
        @Assert(containsForTest(json, "\"autoWirelessIp\": \"10.0.0.88\""), true)
        @Assert(containsForTest(json, "\"autoWirelessMemoryAttempted\": false"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-auto-wireless-tmode-port\""), false)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(0))
    }

    @TestCase
    public func harmonyLocalDevAutoTriesSameTargetOnlyOncePerProbeCycle(): Unit {
        let root = "/tmp/hapcli-device-dedupe-local-dev-same-target-dedupe-test"
        let config = root + "/happub.toml"
        let memory = root + "/.hapData/harmony-device-memory.json"
        createDirForTest(root + "/.hapData")
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest("/tmp/hapcli-device-dedupe-same-target-dedupe-hdc", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"tconn\" ]; then echo 'failed to connect'; exit 1; fi\n" +
            "if [ \"$1\" = \"list\" ]; then exit 0; fi\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-device-dedupe-same-target-dedupe-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())
        File.writeTo(memory, (
            "{\n" +
            "  \"schema\":\"happub-hapcli-harmony-device-memory-v0\",\n" +
            "  \"trusted\":true,\n" +
            "  \"project\":\"" + root + "\",\n" +
            "  \"projectFingerprint\":\"path:" + root + "\",\n" +
            "  \"target\":\"USB-SAME\",\n" +
            "  \"ip\":\"192.168.0.114\",\n" +
            "  \"port\":\"5555\",\n" +
            "  \"proofReceiptPath\":\"/tmp/hap-proof-latest.json\",\n" +
            "  \"proofAction\":\"dev\",\n" +
            "  \"promotedAt\":\"2026-07-05T10:00:00+08:00\",\n" +
            "  \"staleAfterSeconds\":\"3153600000\",\n" +
            "  \"history\": [\n" +
            "    {\"target\":\"USB-SAME\",\"ip\":\"192.168.0.114\",\"port\":\"5555\",\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"proofReceiptPath\":\"/tmp/hap-proof-latest.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-07-05T10:00:00+08:00\",\"staleAfterSeconds\":\"3153600000\"},\n" +
            "    {\"target\":\"USB-SAME\",\"ip\":\"192.168.0.106\",\"port\":\"5555\",\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"proofReceiptPath\":\"/tmp/hap-proof-old.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-07-04T10:00:00+08:00\",\"staleAfterSeconds\":\"3153600000\"}\n" +
            "  ]\n" +
            "}"
        ).toArray())

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--device-memory",
            memory
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-trusted-wireless-reconnect\""), true)
        @Assert(containsForTest(json, "\"args\":[\"tconn\", \"192.168.0.114:5555\"]"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-trusted-wireless-reconnect-2\""), false)
        @Assert(containsForTest(json, "192.168.0.106:5555"), false)
        @Assert(containsForTest(json, "\"label\":\"harmony-assemble-app\""), false)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(1))
    }

    @TestCase
    public func harmonyLocalDevAutoUsesIpHistoryBeforeUsbScan(): Unit {
        let root = "/tmp/hapcli-ip-history-local-dev-ip-history-before-usb-scan-test"
        let config = root + "/happub.toml"
        let memory = root + "/.hapData/harmony-device-memory.json"
        createDirForTest(root + "/.hapData")
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest("/tmp/hapcli-ip-history-ip-history-before-usb-scan", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"tconn\" ] && [ \"$2\" = \"192.168.0.141:5602\" ]; then echo 'failed to connect'; exit 1; fi\n" +
            "if [ \"$1\" = \"tconn\" ] && [ \"$2\" = \"10.0.0.88:5555\" ]; then echo connected; exit 0; fi\n" +
            "if [ \"$1\" = \"list\" ]; then echo SHOULD_NOT_SCAN_USB; exit 0; fi\n" +
            "if [ \"$1\" = \"shell\" ] && [ \"$2\" = \"pidof\" ]; then echo 50050; exit 0; fi\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-ip-history-ip-history-before-usb-scan\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())
        File.writeTo(memory, (
            "{\n" +
            "  \"schema\":\"happub-hapcli-harmony-device-memory-v0\",\n" +
            "  \"trusted\":true,\n" +
            "  \"project\":\"" + root + "\",\n" +
            "  \"projectFingerprint\":\"path:" + root + "\",\n" +
            "  \"target\":\"USB-OLD\",\n" +
            "  \"ip\":\"192.168.0.141\",\n" +
            "  \"port\":\"5602\",\n" +
            "  \"proofReceiptPath\":\"/tmp/hap-proof-old.json\",\n" +
            "  \"proofAction\":\"dev\",\n" +
            "  \"promotedAt\":\"2026-07-04T10:00:00+08:00\",\n" +
            "  \"staleAfterSeconds\":\"3153600000\",\n" +
            "  \"history\": [\n" +
            "    {\"target\":\"USB-OLD\",\"ip\":\"192.168.0.141\",\"port\":\"5602\",\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"proofReceiptPath\":\"/tmp/hap-proof-old.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-07-04T10:00:00+08:00\",\"staleAfterSeconds\":\"3153600000\"},\n" +
            "    {\"target\":\"USB-OLDER\",\"ip\":\"10.0.0.88\",\"port\":\"5555\",\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"proofReceiptPath\":\"/tmp/hap-proof-older.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-07-03T10:00:00+08:00\",\"staleAfterSeconds\":\"3153600000\"}\n" +
            "  ]\n" +
            "}"
        ).toArray())

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--device-memory",
            memory
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-trusted-wireless-reconnect\""), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-trusted-wireless-reconnect-2\""), true)
        @Assert(containsForTest(json, "\"args\":[\"tconn\", \"10.0.0.88:5555\"]"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-list-targets\""), false)
        @Assert(containsForTest(json, "SHOULD_NOT_SCAN_USB"), false)
        @Assert(containsForTest(json, "\"autoWirelessMemoryStatus\": \"already-using-trusted-wireless-memory\""), true)
        @Assert(containsForTest(json, "\"autoWirelessIp\": \"10.0.0.88\""), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-auto-wireless-tmode-port\""), false)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(0))
    }

    @TestCase
    public func harmonyLocalDevAutoTimesOutStuckCurrentHdcScanBeforeBuild(): Unit {
        let root = "/tmp/hapcli-hdc-timeout-local-dev-stuck-hdc-scan-timeout-test"
        let config = root + "/happub.toml"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest("/tmp/hapcli-hdc-timeout-stuck-hdc-scan", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"list\" ]; then sleep 5; echo LATE_USB; exit 0; fi\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-hdc-timeout-stuck-hdc-scan\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n" +
            "deviceProbeTimeoutSeconds = 1\n"
        ).toArray())

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--device-memory",
            root + "/.hapData/missing-device-memory.json"
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"deviceProbeTimeoutSeconds\": \"1\""), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-list-targets\""), true)
        @Assert(containsForTest(json, "\"rawExitCode\":124,\"exitCode\":1,\"semanticStatus\":\"raw-exit-nonzero\""), true)
        @Assert(containsForTest(json, "\"failedCommandLabel\": \"hdc-list-targets\""), true)
        @Assert(containsForTest(json, "\"label\":\"harmony-assemble-app\""), false)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(1))
    }

    @TestCase
    public func harmonyLocalDevAutoStopsBeforeBuildWhenDeviceProbeDisabledAndUnsatisfied(): Unit {
        let root = "/tmp/hapcli-probe-gate-device-probe-gate-stop-before-build-test"
        let config = root + "/happub.toml"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest("/tmp/hapcli-probe-gate-probe-disabled-hdc", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"list\" ]; then echo SHOULD_NOT_SCAN; exit 0; fi\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-probe-gate-probe-disabled-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n" +
            "deviceProbeFullScan = false\n" +
            "deviceProbeMaxHistory = 1\n" +
            "deviceProbeTimeoutSeconds = 2\n"
        ).toArray())

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--device-memory",
            root + "/.hapData/missing-device-memory.json"
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"deviceProbeFullScan\": \"false\""), true)
        @Assert(containsForTest(json, "\"deviceProbeTimeoutSeconds\": \"2\""), true)
        @Assert(containsForTest(json, "\"deviceProbeSatisfied\": false"), true)
        @Assert(containsForTest(json, "\"failedCommandLabel\": \"harmony-device-probe-not-satisfied\""), true)
        @Assert(containsForTest(json, "\"label\":\"harmony-assemble-app\""), false)
        @Assert(containsForTest(json, "\"label\":\"hdc-install\""), false)
        @Assert(containsForTest(json, "\"label\":\"hdc-list-targets\""), false)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(1))
    }

}

@When[os != "Windows"]
@Test
public class HapHarmonyWirelessPosixFixtureTest {
    @TestCase
    public func harmonyReviewedWirelessExecutionKeepsTrustedReconnectFailureHard(): Unit {
        let root = "/tmp/hapcli-stale-wireless-reviewed-stale-wireless-hard-fail-test"
        let config = root + "/happub.toml"
        let memory = "/tmp/hapcli-stale-wireless-reviewed-stale-wireless-hard-fail-memory.json"
        let receipt = "/tmp/hapcli-stale-wireless-reviewed-stale-wireless-hard-fail.receipt.json"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest("/tmp/hapcli-stale-wireless-reviewed-stale-wireless-hdc", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"tconn\" ]; then echo 'failed to connect'; exit 1; fi\n" +
            "if [ \"$1\" = \"list\" ]; then echo USB010; exit 0; fi\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-stale-wireless-reviewed-stale-wireless-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())
        File.writeTo(memory, ("{\"schema\":\"happub-hapcli-harmony-device-memory-v0\",\"trusted\":true,\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"target\":\"USB-MEM-HARD\",\"ip\":\"192.168.0.150\",\"port\":\"5604\",\"proofReceiptPath\":\"/tmp/hap-proof.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-07-04T10:00:00+08:00\",\"staleAfterSeconds\":\"3153600000\"}").toArray())

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
            "reviewed",
            "--receipt",
            receipt
        ], 2)
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"failedCommandLabel\": \"hdc-trusted-wireless-reconnect\""), true)
        @Assert(containsForTest(json, "\"diagnosis\": \"trusted wireless reconnect failed; refresh USB-first wireless proof before rerunning hap dev\""), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-list-targets\""), false)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(1))
    }

    @TestCase
    public func harmonyLocalDevAutoCachesUsbWirelessMemoryAfterSuccessfulDev(): Unit {
        let root = "/tmp/hapcli-wireless-cache-local-dev-auto-cache-wireless-test"
        let config = root + "/happub.toml"
        let memory = root + "/.hapData/harmony-device-memory.json"
        createDirForTest(root + "/.hapData")
        File.writeTo(memory, "{}".toArray())
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest("/tmp/hapcli-wireless-cache-cache-wireless-hdc", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"list\" ]; then echo USB007; exit 0; fi\n" +
            "if [ \"$1\" = \"shell\" ] && [ \"$2\" = \"pidof\" ]; then echo 11223; exit 0; fi\n" +
            "if [ \"$1\" = \"-t\" ] && [ \"$3\" = \"shell\" ] && [ \"$4\" = \"ifconfig\" ]; then echo 'inet 192.168.0.77 netmask 255.255.255.0'; exit 0; fi\n" +
            "if [ \"$1\" = \"-t\" ] && [ \"$3\" = \"tmode\" ]; then echo 'OK'; exit 0; fi\n" +
            "if [ \"$1\" = \"tconn\" ]; then echo connected; exit 0; fi\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-wireless-cache-cache-wireless-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--device-memory",
            memory
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)
        let memoryText = String.fromUtf8(File.readFrom(memory))

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"autoWirelessMemoryAttempted\": true"), true)
        @Assert(containsForTest(json, "\"autoWirelessMemoryWritten\": true"), true)
        @Assert(containsForTest(json, "\"autoWirelessMemoryStatus\": \"trusted-device-memory-auto-cached\""), true)
        @Assert(containsForTest(json, "\"autoWirelessIp\": \"192.168.0.77\""), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-auto-wireless-tmode-port\""), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-auto-wireless-tconn\""), true)
        @Assert(containsForTest(memoryText, "\"target\": \"USB007\""), true)
        @Assert(containsForTest(memoryText, "\"ip\": \"192.168.0.77\""), true)
        @Assert(containsForTest(memoryText, "\"port\": \"5555\""), true)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(0))
    }

    @TestCase
    public func harmonyLocalDevAutoReportsManualFallbackWhenSelfCheckFails(): Unit {
        let root = "/tmp/hapcli-local-dev-local-dev-auto-fail-test"
        let config = root + "/happub.toml"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/usr/bin/false\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())

        let options = prepareHarmonyLocalDevAutoOptions(resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--config",
            config,
            "--device-memory",
            root + "/.hapData/missing-device-memory.json"
        ], 2))
        let json = renderHarmonyReviewedExecutionJson(options, true)

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"executionGate\": \"local-dev-auto\""), true)
        @Assert(containsForTest(json, "\"failedCommandLabel\": \"hdc-list-targets\""), true)
        @Assert(containsForTest(json, "\"diagnosis\": \"no HarmonyOS device target is connected; connect USB/debug authorization or provide trusted wireless device memory before rerunning hap dev\""), true)
        @Assert(containsForTest(json, "\"/usr/bin/false shell pidof cn.example.demo\""), true)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(1))
    }

}

@When[os != "Windows"]
@Test
public class HapHarmonyStatusPosixFixtureTest {
    @TestCase
    public func harmonyDeviceStatusCheckHdcTreatsEmptyTargetsAsNeedsUsb(): Unit {
        let hdc = "/tmp/hapcli-device-status-empty-targets-hdc"
        writeExecutableForTest(hdc, "#!/bin/sh\necho '[Empty]'\nexit 0\n")
        let json = renderHarmonyDeviceStatusJson(resolveHarmonyDeviceStatusOptions([
            "hap",
            "harmony",
            "device-status",
            "--project",
            "/tmp/harmony-demo",
            "--memory",
            "/tmp/hapcli-device-status-empty-targets.memory.json",
            "--hdc",
            hdc,
            "--check-hdc"
        ], 3))

        @Assert(containsForTest(json, "\"status\": \"needs-usb-or-trusted-wireless-memory\""), true)
        @Assert(containsForTest(json, "\"hdcActionTaken\": true"), true)
        @Assert(containsForTest(json, "\"hdcSemanticStatus\": \"hdc-no-targets\""), true)
        @Assert(containsForTest(json, "connect and authorize one HarmonyOS device over USB"), true)
    }

    @TestCase
    public func harmonyDeviceStatusCheckHdcTimesOutStuckTargetsProbe(): Unit {
        let hdc = "/tmp/hapcli-device-status-stuck-targets-hdc"
        writeExecutableForTest(hdc, "#!/bin/sh\nsleep 5\necho USB-LATE\nexit 0\n")
        let json = renderHarmonyDeviceStatusJson(resolveHarmonyDeviceStatusOptions([
            "hap",
            "harmony",
            "device-status",
            "--project",
            "/tmp/harmony-demo",
            "--memory",
            "/tmp/hapcli-device-status-stuck-targets.memory.json",
            "--hdc",
            hdc,
            "--check-hdc",
            "--hdc-timeout-seconds",
            "1"
        ], 3))

        @Assert(containsForTest(json, "\"ok\": false"), true)
        @Assert(containsForTest(json, "\"status\": \"hdc-check-failed\""), true)
        @Assert(containsForTest(json, "\"hdcTimeoutSeconds\": \"1\""), true)
        @Assert(containsForTest(json, "\"hdcRawExitCode\": 124"), true)
        @Assert(containsForTest(json, "\"hdcSemanticStatus\": \"raw-exit-nonzero\""), true)
        @Assert(containsForTest(json, "verify hdc path"), true)
    }

    @TestCase
    public func harmonyReviewedDevConsumesTrustedDeviceMemoryForWirelessGate(): Unit {
        let root = "/tmp/hapcli-reviewed-wireless-reviewed-dev-device-memory-test"
        let config = root + "/happub.toml"
        let memory = "/tmp/hapcli-reviewed-wireless-reviewed-dev-device-memory.json"
        let receipt = "/tmp/hapcli-reviewed-wireless-reviewed-dev-device-memory.receipt.json"
        createDirForTest(root)
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest("/tmp/hapcli-reviewed-wireless-device-memory-ok-hdc", (
            "#!/bin/sh\n" +
            "if [ \"$1\" = \"tconn\" ]; then echo connected; exit 0; fi\n" +
            "if [ \"$1\" = \"list\" ]; then echo 192.168.0.141:5602; exit 0; fi\n" +
            "if [ \"$1\" = \"shell\" ] && [ \"$2\" = \"pidof\" ]; then echo 13579; exit 0; fi\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"/tmp/hapcli-reviewed-wireless-device-memory-ok-hdc\"\n" +
            "artifactPath = \"/tmp/app.hap\"\n" +
            "bundle = \"cn.example.demo\"\n" +
            "ability = \"EntryAbility\"\n"
        ).toArray())
        File.writeTo(memory, ("{\"schema\":\"happub-hapcli-harmony-device-memory-v0\",\"trusted\":true,\"project\":\"" + root + "\",\"projectFingerprint\":\"path:" + root + "\",\"target\":\"USB-MEM-EXEC\",\"ip\":\"192.168.0.141\",\"port\":\"5602\",\"proofReceiptPath\":\"/tmp/hap-proof.json\",\"proofAction\":\"dev\",\"promotedAt\":\"2026-06-30T14:56:00+08:00\",\"staleAfterSeconds\":\"3153600000\"}").toArray())

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
            "SYNTHETIC_REVIEW_TOKEN",
            "--receipt",
            receipt,
            "--log-dir",
            "/tmp/hapcli-reviewed-wireless-reviewed-dev-device-memory-logs"
        ], 2)
        let json = renderHarmonyReviewedExecutionJson(options, true)
        let receiptText = String.fromUtf8(File.readFrom(receipt))

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"status\": \"reviewed-execution-succeeded\""), true)
        @Assert(containsForTest(json, "\"wirelessTrustSource\": \"device-memory\""), true)
        @Assert(containsForTest(json, "\"deviceMemoryTrusted\": true"), true)
        @Assert(containsForTest(json, "\"networkActionTaken\": true"), true)
        @Assert(containsForTest(json, "\"memoryMutationActionTaken\": false"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-trusted-wireless-reconnect\""), true)
        @Assert(containsForTest(json, "\"args\":[\"tconn\", \"192.168.0.141:5602\"]"), true)
        @Assert(containsForTest(json, "SYNTHETIC_REVIEW_TOKEN"), false)
        @Assert(containsForTest(receiptText, "SYNTHETIC_REVIEW_TOKEN"), false)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(0))
    }

}

@When[os != "Windows"]
@Test
public class HapHarmonyTimeoutPosixFixtureTest {
    @TestCase
    public func boundsDeviceProbeTimeoutAndOptionParsing(): Unit {
        let options = resolveHapDeviceOptions("list", [
            "hap",
            "device",
            "--all",
            "--timeout-seconds",
            "3",
            "--json"
        ], 2)
        @Assert(options.allPlatforms, true)
        @Assert(options.timeoutSeconds, Int64(3))
        @Assert(options.json, true)

        let invalid = resolveHapDeviceOptions("list", ["hap", "device", "--timeout-seconds=999"], 2)
        @Assert(invalid.timeoutSeconds, Int64(8))
        let (code, _, stderrBytes) = executeHapDeviceCommandWithTimeout("/bin/sh", ["-c", "sleep 3"], 1)
        @Assert(code, Int64(124))
        @Assert(containsForTest(String.fromUtf8(stderrBytes), "hap device probe timeout after 1 seconds"), true)
    }

    @TestCase
    public func directWirelessDeviceTimeoutRestartsHdcAndRetriesOnce(): Unit {
        let root = "/tmp/hapcli-hdc-restart-hdc-restart-project"
        let config = root + "/happub.toml"
        let fakeHdc = root + "/fake-hdc"
        let marker = root + "/first-tconn.marker"
        createDirForTest(root)
        let (_, _, _) = executeWithOutput("/bin/rm", ["-f", marker])
        File.writeTo(root + "/build-profile.json5", "{}".toArray())
        File.writeTo(root + "/hvigorfile.ts", "export default {}".toArray())
        writeExecutableForTest(fakeHdc, (
            "#!/bin/sh\n" +
            "marker=\"" + marker + "\"\n" +
            "if [ \"$1\" = \"tconn\" ]; then\n" +
            "  if [ ! -f \"$marker\" ]; then touch \"$marker\"; sleep 4; exit 0; fi\n" +
            "  echo 'Connect OK'; exit 0\n" +
            "fi\n" +
            "if [ \"$1\" = \"kill\" ] && [ \"$2\" = \"-r\" ]; then echo 'server restarted'; exit 0; fi\n" +
            "if [ \"$1\" = \"list\" ]; then echo '192.0.2.40:5555'; exit 0; fi\n" +
            "if [ \"$1\" = \"-t\" ] && [ \"$3\" = \"shell\" ] && [ \"$4\" = \"pidof\" ]; then echo '24680'; exit 0; fi\n" +
            "exit 0\n"
        ))
        File.writeTo(config, (
            "[harmonyos]\n" +
            "hvigorwPath = \"/usr/bin/true\"\n" +
            "hdcPath = \"" + fakeHdc + "\"\n" +
            "artifactPath = \"/tmp/hdc-restart-app.hap\"\n" +
            "bundle = \"cn.example.hdc-restart\"\n" +
            "ability = \"EntryAbility\"\n" +
            "deviceProbeTimeoutSeconds = 1\n" +
            "hdcRestartOnTconnTimeout = true\n" +
            "hdcRestartTimeoutSeconds = 1\n" +
            "hdcReconnectRetryCount = 1\n"
        ).toArray())

        let options = resolveProjectActionOptions("dev", [
            "hap",
            "dev",
            "--project",
            root,
            "--platform",
            "harmonyos",
            "--device",
            "192.0.2.40:5555",
            "--config",
            config,
            "--log-dir",
            root + "/logs"
        ], 2)
        let json = runHarmonyLocalDevAutoExecution(options)

        @Assert(containsForTest(json, "\"ok\": true"), true)
        @Assert(containsForTest(json, "\"selectedDeviceTarget\": \"192.0.2.40:5555\""), true)
        @Assert(containsForTest(json, "\"hdcRestartOnTconnTimeout\": \"true\""), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-trusted-wireless-reconnect\""), true)
        @Assert(containsForTest(json, "\"rawExitCode\":124"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-server-restart-after-tconn-timeout\""), true)
        @Assert(containsForTest(json, "\"args\":[\"kill\", \"-r\"]"), true)
        @Assert(containsForTest(json, "\"label\":\"hdc-trusted-wireless-reconnect-retry-1\""), true)
        @Assert(containsForTest(json, "\"args\":[\"-t\", \"192.0.2.40:5555\", \"install\""), true)
        @Assert(projectActionExecutionExitCodeFromJson(json), Int64(0))
    }

}
