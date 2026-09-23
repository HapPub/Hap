package hapcli

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{Directory, File, exists}
import std.process.executeWithOutput
import std.unittest.*
import std.unittest.testmacro.*

func readFixture(path: String): String {
    String.fromUtf8(File.readFrom(path)).replace("\r\n", "\n").replace("\r", "\n")
}

func createDirForTest(path: String): Unit {
    if (!exists(path)) {
        Directory.create(path, recursive: true)
    }
}

func writeExecutableForTest(path: String, body: String): Unit {
    File.writeTo(path, body.toArray())
    let (_, _, _) = executeWithOutput("chmod", ["+x", path])
}

func prepareManifestDiscoveryFixtureForTest(): String {
    let root = testTempPathForTest("hapcli-public-discover-fixture")
    createDirForTest(root + "/AppCore")
    createDirForTest(root + "/deps/WebRuntime")
    createDirForTest(root + "/target/ignored")
    File.writeTo(root + "/AppCore/cjpm.toml", "[package]\nname = \"example_app_core\"\n".toArray())
    File.writeTo(root + "/deps/WebRuntime/WebRuntime.cjpm.toml", "[package]\nname = \"web-runtime\"\n".toArray())
    File.writeTo(root + "/target/ignored/cjpm.toml", "[package]\nname = \"ignored\"\n".toArray())
    root
}

func testTempPathForTest(name: String): String {
    let root = match (getVariable("RUNNER_TEMP")) {
        case Some(value) => if (value.size > 0) { value } else { "/tmp" }
        case None => "/tmp"
    }
    trimTrailingSlash(root.replace("\\", "/")) + "/" + name
}

func containsForTest(text: String, needle: String): Bool {
    let textRunes = text.toRuneArray()
    let needleRunes = needle.toRuneArray()
    if (needleRunes.size == 0) {
        return true
    }
    if (needleRunes.size > textRunes.size) {
        return false
    }
    var i: Int64 = 0
    while (i <= textRunes.size - needleRunes.size) {
        var j: Int64 = 0
        var matched = true
        while (j < needleRunes.size) {
            if (textRunes[i + j] != needleRunes[j]) {
                matched = false
                break
            }
            j += 1
        }
        if (matched) {
            return true
        }
        i += 1
    }
    false
}
