import Foundation

/// A plain-text record of what Tiko did, kept on this Mac, so a problem can be
/// traced instead of guessed at. It records what happened and how long it took —
/// never the API key, screenshots, or what the user said.
public enum TikoLog {
    /// Where the log is written. Replaceable so checks can write somewhere temporary.
    public static var fileURL: URL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Logs/Tiko", isDirectory: true)
        .appendingPathComponent("tiko.log")

    /// Past this size the older half is dropped, so the log never grows without limit.
    public static var maximumFileSize = 1_000_000

    private static let writeQueue = DispatchQueue(label: "tiko.log")

    public static func write(_ message: String) {
        let timestamp = ISO8601DateFormatter.string(
            from: Date(),
            timeZone: .current,
            formatOptions: [.withInternetDateTime, .withFractionalSeconds]
        )
        let line = "\(timestamp) \(message)\n"
        let logFileURL = fileURL
        let sizeLimit = maximumFileSize
        writeQueue.async {
            append(line, to: logFileURL, sizeLimit: sizeLimit)
        }
    }

    /// Waits until every pending line is on disk.
    public static func flush() {
        writeQueue.sync {}
    }

    private static func append(_ line: String, to logFileURL: URL, sizeLimit: Int) {
        let fileManager = FileManager.default
        // Logging must never be the reason Tiko breaks, so failures here are ignored.
        do {
            try fileManager.createDirectory(at: logFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !fileManager.fileExists(atPath: logFileURL.path) {
                fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
            }

            let currentFileSize = (try? fileManager.attributesOfItem(atPath: logFileURL.path)[.size] as? Int) ?? 0
            if currentFileSize > sizeLimit {
                let existingLog = try Data(contentsOf: logFileURL)
                var keptLog = existingLog.suffix(sizeLimit / 2)
                // Start at a line boundary rather than halfway through a line.
                if let firstNewline = keptLog.firstIndex(of: UInt8(ascii: "\n")) {
                    keptLog = keptLog[keptLog.index(after: firstNewline)...]
                }
                try Data(keptLog).write(to: logFileURL)
            }

            let fileHandle = try FileHandle(forWritingTo: logFileURL)
            defer { try? fileHandle.close() }
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: Data(line.utf8))
        } catch {
            return
        }
    }
}
