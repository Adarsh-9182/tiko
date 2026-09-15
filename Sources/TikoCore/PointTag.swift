import CoreGraphics
import Foundation

public struct PointTagParseResult: Equatable {
    /// The reply with every [POINT:…] tag removed — what the user reads.
    public let displayText: String
    /// Gemini's 0–1000 grid with a top-left origin, exactly as the model wrote
    /// it. Nil for [POINT:none] or when there was no tag.
    public let normalizedPoint: CGPoint?
    public let elementLabel: String?
    /// 1-based screen number from the screenshot labels; nil means the cursor's screen.
    public let screenNumber: Int?
}

/// Reads the `[POINT:x,y:label:screenN]` tag Gemini adds when it wants the buddy to point.
public enum PointTag {
    // Tolerates the spaces models sometimes add, and a minus sign on a
    // coordinate. Slightly off-screen points are clamped onto the screen later
    // rather than being thrown away.
    private static let pointTagExpression = try! NSRegularExpression(
        pattern: #"\[POINT:\s*(?:none|(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)(?:\s*:\s*([^\]:]+?))?(?:\s*:\s*screen\s*(\d+))?)\s*\]"#,
        options: [.caseInsensitive]
    )

    public static func parse(_ replyText: String) -> PointTagParseResult {
        let fullRange = NSRange(replyText.startIndex..., in: replyText)
        let tagMatches = pointTagExpression.matches(in: replyText, range: fullRange)

        let textWithoutTags = pointTagExpression.stringByReplacingMatches(in: replyText, range: fullRange, withTemplate: "")
        let displayText = textWithoutTags
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // The prompt asks for one tag at the end; if several arrive, the last
        // is the one the model settled on.
        guard let lastTagMatch = tagMatches.last,
              let xRange = Range(lastTagMatch.range(at: 1), in: replyText),
              let yRange = Range(lastTagMatch.range(at: 2), in: replyText),
              let normalizedX = Double(replyText[xRange]),
              let normalizedY = Double(replyText[yRange]) else {
            return PointTagParseResult(displayText: displayText, normalizedPoint: nil, elementLabel: nil, screenNumber: nil)
        }

        let elementLabel = Range(lastTagMatch.range(at: 3), in: replyText).map { labelRange in
            replyText[labelRange].trimmingCharacters(in: .whitespaces)
        }
        let screenNumber = Range(lastTagMatch.range(at: 4), in: replyText).flatMap { screenNumberRange in
            Int(replyText[screenNumberRange])
        }

        return PointTagParseResult(
            displayText: displayText,
            normalizedPoint: CGPoint(x: normalizedX, y: normalizedY),
            elementLabel: elementLabel,
            screenNumber: screenNumber
        )
    }
}
