package hapcli

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class HapNetworkPolicyTest {
    @TestCase
    public func projectActionsDefaultToNoProxyAndAcceptExplicitOverride(): Unit {
        let defaults = resolveProjectActionOptions("dev", ["hap", "dev"], 2)
        @Assert(defaults.networkMode, "no-proxy")

        let proxy = resolveProjectActionOptions("dev", ["hap", "dev", "--proxy"], 2)
        @Assert(proxy.networkMode, "proxy")

        let explicitNoProxy = resolveProjectActionOptions("dev", ["hap", "dev", "--proxy", "--no-proxy"], 2)
        @Assert(explicitNoProxy.networkMode, "no-proxy")
    }

    @TestCase
    public func cangjieBuildDefaultsToNoProxyAndAcceptsProxy(): Unit {
        let defaults = resolveBuildOptions(["hap", "build"], 2)
        @Assert(defaults.networkMode, "no-proxy")

        let proxy = resolveBuildOptions(["hap", "build", "--proxy"], 2)
        @Assert(proxy.networkMode, "proxy")
    }

    @TestCase
    public func dictionaryRefreshUsesTheSameDefaultAndOverride(): Unit {
        let defaults = resolveDictionaryRefreshOptions(["hap", "dictionary", "refresh"], 3)
        @Assert(defaults.networkMode, "no-proxy")

        let proxy = resolveDictionaryRefreshOptions(["hap", "dictionary", "refresh", "--proxy"], 3)
        @Assert(proxy.networkMode, "proxy")
    }

    @TestCase
    public func noProxyWrapsCommandWithStandardProxyEnvironmentUnsets(): Unit {
        let command = resolveHapNetworkCommand("no-proxy", "cjpm", ["build"])
        @Assert(command.program == "/usr/bin/env" || command.program == "/bin/env" || command.program == "env", true)
        @Assert(networkArgsContain(command.args.toArray(), "HTTP_PROXY"), true)
        @Assert(networkArgsContain(command.args.toArray(), "http_proxy"), true)
        @Assert(networkArgsContain(command.args.toArray(), "cjpm"), true)
        @Assert(networkArgsContain(command.args.toArray(), "build"), true)
    }

    @TestCase
    public func proxyModePreservesOriginalCommandForEnvironmentInheritance(): Unit {
        let command = resolveHapNetworkCommand("proxy", "cjpm", ["build"])
        @Assert(command.program, "cjpm")
        @Assert(command.args.size, Int64(1))
        @Assert(command.args[0], "build")
    }
}

func networkArgsContain(args: Array<String>, expected: String): Bool {
    for (arg in args) {
        if (arg == expected) {
            return true
        }
    }
    false
}
