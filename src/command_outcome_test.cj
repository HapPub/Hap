package hapcli

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class HapCommandOutcomeTest {
    @TestCase
    public func topLevelFailureWinsOverNestedSuccess(): Unit {
        @Assert(legacyCommandOutcome("{\"component\":{\"ok\":true},\"ok\":false}").exitCode, Int64(2))
        @Assert(legacyCommandOutcome("{\"component\":{\"ok\":false},\"ok\":true}").exitCode, Int64(0))
        @Assert(legacyCommandOutcome("{\"detail\":\"escaped \\\"ok\\\": false\",\"ok\":true}").exitCode, Int64(0))
        @Assert(legacyCommandOutcome("{\"detail\":\"ok\",\"ok\" : false}").exitCode, Int64(2))
        @Assert(legacyCommandOutcome("{\"status\":\"planned\"}").exitCode, Int64(0))
    }
}
