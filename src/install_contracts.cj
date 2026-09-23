package hapcli

import std.env.getProcessId
import std.fs.File
import std.time.DateTime

// Shared transport contract. The caller still owns URL authority and SHA checks.
func hapHttpsDownloadArgs(url: String, destination: String, timeoutSeconds: Int64, retries: Int64): Array<String> {
    ["--disable", "--proto", "=https", "--proto-redir", "=https", "--tlsv1.2",
     "--location", "--fail", "--show-error", "--silent", "--connect-timeout", "10",
     "--max-time", timeoutSeconds.toString(), "--speed-limit", "16384", "--speed-time", "15",
     "--retry", retries.toString(), "--retry-delay", "2", "--output", destination, url]
}

func writeHapInstallLockOwner(lock: String, operation: String): Unit {
    File.writeTo(lock + "/owner.json", ("{\"pid\":" + getProcessId().toString() +
        ",\"operation\":\"" + escapeJson(operation) + "\",\"createdAt\":\"" +
        DateTime.nowUTC().toString() + "\",\"recovery\":\"Confirm the owning process has stopped before removing this lock.\"}").toArray())
}
