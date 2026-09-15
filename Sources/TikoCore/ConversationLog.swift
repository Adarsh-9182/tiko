import Foundation

public struct ConversationLogEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let question: String
    public let reply: String

    public init(id: UUID = UUID(), date: Date = Date(), question: String, reply: String) {
        self.id = id
        self.date = date
        self.question = question
        self.reply = reply
    }
}

/// Every question and answer, kept only on this Mac so an earlier answer can
/// be found again. It's for the user to look back at — it is not sent to Gemini.
public struct ConversationLog: Codable, Equatable, Sendable {
    /// Oldest first.
    public private(set) var entries: [ConversationLogEntry]

    /// Enough to find last week's answer without the file growing forever.
    public static let maximumEntryCount = 200

    public init(entries: [ConversationLogEntry] = []) {
        self.entries = entries
    }

    public mutating func append(_ entry: ConversationLogEntry) {
        entries.append(entry)
        if entries.count > Self.maximumEntryCount {
            entries.removeFirst(entries.count - Self.maximumEntryCount)
        }
    }

    public mutating func removeAll() {
        entries.removeAll()
    }

    public static var defaultFileURL: URL {
        PrivateFile.tikoFolderURL.appendingPathComponent("history.json")
    }

    public static func load(from fileURL: URL = ConversationLog.defaultFileURL) -> ConversationLog {
        guard let logData = try? Data(contentsOf: fileURL),
              let loadedLog = try? JSONDecoder().decode(ConversationLog.self, from: logData) else {
            return ConversationLog()
        }
        return loadedLog
    }

    public func save(to fileURL: URL = ConversationLog.defaultFileURL) throws {
        try PrivateFile.write(try JSONEncoder().encode(self), to: fileURL)
    }
}
