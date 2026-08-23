package hapcli

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class HarmonyWindowCaptureTest {
    @TestCase
    public func phonePresetsUsePortraitGeometry(): Unit {
        let sixteen = HapPrntOptions()
        sixteen.layoutType = "Phone"
        sixteen.ratio = "16:9"
        let sixteenLayout = resolveHapPrntLayout(sixteen)
        @Assert(sixteenLayout.ok, true)
        @Assert(sixteenLayout.width, Int64(516))
        @Assert(sixteenLayout.height, Int64(918))

        let twentyOne = HapPrntOptions()
        twentyOne.layoutType = "Phone/21:9"
        let twentyOneLayout = resolveHapPrntLayout(twentyOne)
        @Assert(twentyOneLayout.variant, "21:9")
        @Assert(twentyOneLayout.width, Int64(516))
        @Assert(twentyOneLayout.height, Int64(1204))
    }

    @TestCase
    public func tabletAndFoldPresetsRemainDistinct(): Unit {
        let fold = HapPrntOptions()
        fold.layoutType = "Tablet"
        fold.ratio = "√2:1"
        let foldLayout = resolveHapPrntLayout(fold)
        @Assert(foldLayout.ok, true)
        @Assert(foldLayout.variant, "Fold√2:1")
        @Assert(foldLayout.width, Int64(1273))
        @Assert(foldLayout.height, Int64(900))

        let tablet = HapPrntOptions()
        tablet.layoutType = "Tablet/7:5"
        let tabletLayout = resolveHapPrntLayout(tablet)
        @Assert(tabletLayout.variant, "7:5")
        @Assert(tabletLayout.width, Int64(1260))
        @Assert(tabletLayout.height, Int64(900))
    }

    @TestCase
    public func pcTwoInOneHasDefaultButTribleNeedsExplicitGeometry(): Unit {
        let twoInOne = HapPrntOptions()
        twoInOne.layoutType = "PC/2in1"
        let twoInOneLayout = resolveHapPrntLayout(twoInOne)
        @Assert(twoInOneLayout.ok, true)
        @Assert(twoInOneLayout.width, Int64(1440))
        @Assert(twoInOneLayout.height, Int64(900))

        let ambiguous = HapPrntOptions()
        ambiguous.layoutType = "PC/trible"
        let ambiguousLayout = resolveHapPrntLayout(ambiguous)
        @Assert(ambiguousLayout.ok, false)
        @Assert(containsText(ambiguousLayout.message, "requires explicit --width and --height"), true)

        ambiguous.width = 2400
        ambiguous.height = 900
        let explicitLayout = resolveHapPrntLayout(ambiguous)
        @Assert(explicitLayout.ok, true)
        @Assert(explicitLayout.variant, "trible")
        @Assert(explicitLayout.width, Int64(2400))
        @Assert(explicitLayout.height, Int64(900))
    }

    @TestCase
    public func explicitGeometryMustBeCompleteAndPositive(): Unit {
        let incomplete = HapPrntOptions()
        incomplete.width = 800
        let incompleteLayout = resolveHapPrntLayout(incomplete)
        @Assert(incompleteLayout.ok, false)
        @Assert(containsText(incompleteLayout.message, "supplied together"), true)

        let negativeOrigin = HapPrntOptions()
        negativeOrigin.left = -1
        @Assert(resolveHapPrntLayout(negativeOrigin).ok, false)
    }

    @TestCase
    public func unsupportedFamilyAndRatioFailBeforeExecution(): Unit {
        let family = HapPrntOptions()
        family.layoutType = "Watch"
        @Assert(resolveHapPrntLayout(family).ok, false)

        let ratio = HapPrntOptions()
        ratio.layoutType = "Phone"
        ratio.ratio = "4:3"
        let ratioLayout = resolveHapPrntLayout(ratio)
        @Assert(ratioLayout.ok, false)
        @Assert(containsText(ratioLayout.message, "unsupported layout variant"), true)
    }

    @TestCase
    public func wmsParserBindsPidAndPrefersFocusedWindow(): Unit {
        let text = "WindowName DisplayId Pid WinId Type Mode Flag ZOrd Orientation [ x y w h ]\n" +
            "corePlayerSub 0 18359 700 1 1 1 2 0 [ 20 30 640 480 ]\n" +
            "corePlayer0 0 18359 724 1 1 1 3 0 [ 100 100 1440 900 ]\n" +
            "other0 0 99999 800 1 1 1 4 0 [ 0 0 1920 1080 ]\n" +
            "Focus window: 724\n"
        let window = parseHapPrntWmsWindow(text, "18359")
        @Assert(window.ok, true)
        @Assert(window.windowName, "corePlayer0")
        @Assert(window.windowId, Int64(724))
        @Assert(window.displayId, Int64(0))
        @Assert(window.left, Int64(100))
        @Assert(window.top, Int64(100))
        @Assert(window.width, Int64(1440))
        @Assert(window.height, Int64(900))
    }

    @TestCase
    public func wmsParserRejectsForeignOrZeroRectangles(): Unit {
        let text = "foreign0 0 99999 724 1 1 1 3 0 [ 100 100 1440 900 ]\n" +
            "corePlayer0 0 18359 725 1 1 1 2 0 [ 0 0 0 0 ]\n"
        @Assert(parseHapPrntWmsWindow(text, "18359").ok, false)
        @Assert(parseHapPrntWmsWindow(text, "not-a-pid").ok, false)
    }

    @TestCase
    public func multiPidSelectionUsesTheFocusedWmsWindow(): Unit {
        let text = "worker0 0 111 701 1 1 1 2 0 [ 10 20 300 200 ]\n" +
            "product0 0 222 702 1 1 1 3 0 [ 40 50 800 600 ]\n" +
            "Focus window: 702\n"
        let pids = hapPrntPidList("111 222\n")
        let window = parseHapPrntWmsWindowForPids(text, pids)
        @Assert(pids.size, Int64(2))
        @Assert(window.ok, true)
        @Assert(window.pid, "222")
        @Assert(window.windowId, Int64(702))
    }

    @TestCase
    public func planOrdersWindowBeforeWmsAndCapture(): Unit {
        let options = HapPrntOptions()
        options.device = "192.0.2.10:5555"
        options.bundle = "cc.example.player"
        options.ability = "ProductAbility"
        options.module = "product"
        options.layoutType = "Tablet/3:2"
        let json = renderHapPrntPlanJson(options)
        let launch = indexOfText(json, "shell aa start")
        let wms = indexOfText(json, "WindowManagerService")
        let snapshot = indexOfText(json, "snapshot_display")
        let crop = indexOfText(json, "crop <wms-x>")
        @Assert(containsText(json, "\"status\": \"plan-ready\""), true)
        @Assert(launch >= 0 && launch < wms, true)
        @Assert(wms < snapshot && snapshot < crop, true)
        @Assert(containsText(json, "--ww 1350 --wh 900"), true)
    }

    @TestCase
    public func planPreservesExternalCaptureNonClaims(): Unit {
        let options = HapPrntOptions()
        options.device = "USB001"
        options.bundle = "cc.example.player"
        options.ability = "ProductAbility"
        options.module = "product"
        let json = renderHapPrntPlanJson(options)
        @Assert(containsText(json, "wms-rect-crop-of-display"), true)
        @Assert(containsText(json, "can contain windows that occlude"), true)
        @Assert(containsText(json, "not visual acceptance or release approval"), true)
        @Assert(containsText(json, "requested geometry is not substituted"), true)
        @Assert(containsText(json, "\"installedArtifactIdentityVerified\": false"), true)
        @Assert(containsText(json, "\"visualAcceptance\": false"), true)
        @Assert(containsText(json, "\"ownerAcceptance\": false"), true)
    }

    @TestCase
    public func missingExplicitDeviceFailsWithoutExecution(): Unit {
        let options = HapPrntOptions()
        options.bundle = "cc.example.player"
        options.ability = "ProductAbility"
        options.module = "product"
        let json = renderHapPrntPlanJson(options)
        @Assert(containsText(json, "\"status\": \"invalid-capture-contract\""), true)
        @Assert(containsText(json, "\"executionActionTaken\": false"), true)
        @Assert(hapPrntExitCode(json), Int64(2))
    }
}
