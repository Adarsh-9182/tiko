import Foundation

/// A multi-step task Tiko is walking the user through, one step at a time.
///
/// Only one step is given at a time because later steps usually aren't on
/// screen yet — a menu item appears only after the menu is opened — so each
/// next step is worked out from a fresh look at the screen.
public struct GuidedTour: Equatable, Sendable {
    /// What the user originally asked for.
    public let goal: String
    /// Every step shown so far, in order.
    public let shownSteps: [String]

    public init(goal: String, shownSteps: [String]) {
        self.goal = goal
        self.shownSteps = shownSteps
    }

    public var nextStepNumber: Int {
        shownSteps.count + 1
    }
}

/// Reads the `[MORE]` tag Gemini adds when a step has more steps after it.
public enum TourTag {
    private static let moreStepsExpression = try! NSRegularExpression(pattern: #"\[\s*MORE\s*\]"#, options: [.caseInsensitive])

    public static func strip(_ replyText: String) -> (text: String, hasMoreSteps: Bool) {
        let fullRange = NSRange(replyText.startIndex..., in: replyText)
        let hasMoreSteps = moreStepsExpression.firstMatch(in: replyText, range: fullRange) != nil
        let textWithoutTag = moreStepsExpression
            .stringByReplacingMatches(in: replyText, range: fullRange, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (textWithoutTag, hasMoreSteps)
    }

    private static let leadingStepNumberExpression = try! NSRegularExpression(pattern: #"^\s*step\s*\d+\s*[:.\-]\s*"#, options: [.caseInsensitive])

    /// Removes a leading "step 1:" from a reply that isn't part of a tour —
    /// models sometimes number a single action, which reads oddly on its own.
    public static func removingLeadingStepNumber(_ text: String) -> String {
        let fullRange = NSRange(text.startIndex..., in: text)
        return leadingStepNumberExpression.stringByReplacingMatches(in: text, range: fullRange, withTemplate: "")
    }
}

/// Recognises the short things people say to move a tour along.
public enum TourCommand {
    /// Kept to short, unambiguous phrases so a real new question is never
    /// mistaken for "next".
    private static let nextStepPhrases: Set<String> = [
        "next", "next step", "go on", "continue", "done", "ok next", "okay next", "then", "what next",
        "aage", "aage bolo", "aage batao", "agla", "agla step", "agla batao",
        "ho gaya", "hogaya", "ho gya", "kar liya", "phir", "phir kya", "uske baad", "ab kya"
    ]

    public static func isNextStepRequest(_ transcript: String) -> Bool {
        let normalizedTranscript = transcript
            .lowercased()
            // Speech recognition adds punctuation ("Next.") that shouldn't matter.
            .replacingOccurrences(of: #"[^\p{L}\p{N} ]"#, with: "", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return nextStepPhrases.contains(normalizedTranscript)
    }
}
