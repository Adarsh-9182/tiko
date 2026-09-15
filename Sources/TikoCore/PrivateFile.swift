import Foundation

/// Writes files that only the current user may read — for the API key and the
/// conversation history.
public enum PrivateFile {
    public static func write(_ fileData: Data, to fileURL: URL) throws {
        // The folder is private too, so the file is never readable by others,
        // even in the instant between writing it and tightening its permissions.
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileData.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    /// Tiko's folder in Application Support.
    public static var tikoFolderURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tiko", isDirectory: true)
    }
}
