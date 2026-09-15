import Foundation

/// Prepares a reply for text-to-speech.
public enum SpokenText {
    /// Formatting symbols the model sometimes slips in would otherwise be read
    /// out ("asterisk") or cause odd pauses, and a spelled-out URL is useless
    /// to listen to.
    public static func prepare(_ replyText: String) -> String {
        replyText
            .replacingOccurrences(of: #"https?://\S+"#, with: "link", options: .regularExpression)
            .replacingOccurrences(of: #"[*`#>]+"#, with: "", options: .regularExpression)
            // "file_name" reads better as two words than with "underscore".
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
