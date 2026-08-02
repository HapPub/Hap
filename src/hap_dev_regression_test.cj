package hapcli

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class HapDevRegressionTest {
    @TestCase
    public func devSetRoutesToDeviceManagerArguments(): Unit {
        @Assert(hapDevDeviceSetStartIndex(["hap", "dev", "--set"]), Int64(3))
        @Assert(hapDevDeviceSetStartIndex(["hap", "dev", "--device", "tablet"]), Int64(-1))
    }

    @TestCase
    public func directWirelessPlanConnectsBeforeTargetValidation(): Unit {
        let options = HapProjectActionOptions()
        options.action = "dev"
        let config = HapHarmonyAdapterConfig()
        config.hdcPath = "hdc"
        config.hvigorwPath = "hvigorw"
        config.selectedDeviceTarget = "192.0.2.40:5555"
        config.artifactPath = "/tmp/app.hap"
        config.bundle = "cn.example.app"
        config.ability = "EntryAbility"
        let commands = projectActionCommands("harmonyos", "dev", options, HapHarmonyWirelessGateTrust(), config)

        @Assert(commands[0], "hdc tconn 192.0.2.40:5555")
        @Assert(commands[1], "hdc list targets")
        @Assert(containsText(commands[3], "hdc -t 192.0.2.40:5555 install"), true)
    }

    @TestCase
    public func hdcInstallUnauthorizedTextFailsBeforeLaunch(): Unit {
        let command = HapReviewedCommand("hdc-install", "hdc")
        let output = "msg:error: failed to install bundle. code:9568423 error: Failed to install the HAP because the device is unauthorized, make sure the UDID of your device is configured in the signing profile."
        @Assert(harmonyCommandSemanticStatus(command, 0, output, ""), "hdc-install-device-unauthorized")

        let result = HapReviewedCommandResult(command)
        result.exitCode = 1
        result.semanticStatus = "hdc-install-device-unauthorized"
        let results = ArrayList<HapReviewedCommandResult>()
        results.add(result)
        let options = HapProjectActionOptions()
        options.action = "dev"
        let config = HapHarmonyAdapterConfig()
        config.selectedDeviceTarget = "192.0.2.40:5555"
        let diagnosis = harmonyExecutionDiagnosis("reviewed-execution-failed", results, options, config)
        @Assert(containsText(diagnosis, "signing profile"), true)
        @Assert(containsText(diagnosis, "192.0.2.40:5555"), true)
    }

    @TestCase
    public func progressIsStageBasedMonotonicAndOnlyDoneIsHundredPercent(): Unit {
        let preparing = harmonyLocalDevStageFill("preparing Hap dev", 0)
        let checking = harmonyLocalDevStageFill("checking HarmonyOS device", 1000)
        let building = harmonyLocalDevStageFill("building application", 0)
        let buildingLater = harmonyLocalDevStageFill("building application", 1000)
        let installing = harmonyLocalDevStageFill("installing HarmonyOS app", 0)
        let launching = harmonyLocalDevStageFill("launching HarmonyOS app", 0)
        let verifying = harmonyLocalDevStageFill("verifying HarmonyOS process", 0)
        let refreshing = harmonyLocalDevStageFill("refreshing wireless device memory", 0)

        @Assert(preparing < checking, true)
        @Assert(checking < building, true)
        @Assert(building, buildingLater)
        @Assert(building < installing, true)
        @Assert(installing < launching, true)
        @Assert(launching < verifying, true)
        @Assert(verifying < refreshing, true)
        @Assert(refreshing < Int64(20), true)
        @Assert(containsText(renderHarmonyLocalDevSpinnerFrameForStage(1000, false, true, "building application"), "100%"), false)
        @Assert(containsText(renderHarmonyLocalDevSpinnerFrameForStage(0, true, true, "building application"), "100%"), true)
    }
}
