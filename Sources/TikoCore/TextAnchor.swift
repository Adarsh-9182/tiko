import CoreGraphics
import Foundation
import Vision

/// A piece of text read off the screen, and where it sits.
public struct RecognizedText: Equatable, Sendable {
    public let text: String
    /// Points from the top-left of the area that was read.
    public let rect: CGRect
    /// True for a whole line as read; false for one word picked out of a longer line.
    public let isWholeLine: Bool

    public init(text: String, rect: CGRect, isWholeLine: Bool = true) {
        self.text = text
        self.rect = rect
        self.isWholeLine = isWholeLine
    }
}

/// Snaps a pointing guess onto the element's own label when that label is
/// readable text on screen.
///
/// Gemini often names the right element and still gives coordinates that land
/// somewhere else — the benchmark caught guesses 600 points from a sidebar item
/// the model had named correctly. When the element carries its name as text,
/// reading the screen on the Mac finds exactly where that text is: free, in
/// well under a second, and without a second request to the model. Icons,
/// switches and text fields are left to the model's close-up check, because
/// the text beside them is a caption, not the thing to click.
public enum TextAnchor {
    /// Labels mentioning these name something that isn't its own text.
    private static let wordsNamingNonTextTargets: Set<String> = [
        "switch", "toggle", "slider", "knob", "icon", "image", "picture", "logo",
        "field", "input", "textbox", "box", "bar"
    ]

    /// Words that describe what kind of element it is rather than what it says.
    private static let genericWords: Set<String> = [
        "a", "an", "the", "button", "menu", "item", "option", "link", "tab", "row",
        "sidebar", "pane", "entry", "checkbox", "label", "text", "section", "setting"
    ]

    /// The words to look for on screen, or nil when the label names something
    /// that isn't its own text, or nothing specific enough to find.
    public static func searchPhrase(for elementLabel: String) -> String? {
        let labelWords = normalizedWords(in: elementLabel)
        guard !labelWords.contains(where: { word in wordsNamingNonTextTargets.contains(word) }) else { return nil }
        let meaningfulWords = labelWords.filter { word in !genericWords.contains(word) }
        guard meaningfulWords.joined().count >= 2 else { return nil }
        return meaningfulWords.joined(separator: " ")
    }

    /// Reads every line of text in an image, plus each word of multi-word lines
    /// on its own, with positions scaled to `imageAreaSize` from the top-left.
    public static func recognizeText(in image: CGImage, imageAreaSize: CGSize) -> [RecognizedText] {
        recognizeText(using: VNImageRequestHandler(cgImage: image, options: [:]), imageAreaSize: imageAreaSize)
    }

    public static func recognizeText(inImageData imageData: Data, imageAreaSize: CGSize) -> [RecognizedText] {
        recognizeText(using: VNImageRequestHandler(data: imageData, options: [:]), imageAreaSize: imageAreaSize)
    }

    /// The centre of the text that best matches the label, in the same space as
    /// `recognizedTexts`, or nil when the label isn't readable text there.
    ///
    /// A line that says exactly the label — a button's "Save" — beats the same
    /// word inside a sentence or a longer label like "Don't Save", which is
    /// almost never the thing to click. Among equals, the one nearest the
    /// model's guess wins.
    public static func anchorPoint(forLabel elementLabel: String, among recognizedTexts: [RecognizedText], nearGuess guess: CGPoint) -> CGPoint? {
        guard let searchPhrase = searchPhrase(for: elementLabel) else { return nil }

        let matchingTexts = recognizedTexts.compactMap { recognizedText -> (rect: CGRect, isWholeLineMatch: Bool)? in
            let joinedWords = normalizedWords(in: recognizedText.text).joined(separator: " ")
            if joinedWords == searchPhrase {
                return (recognizedText.rect, recognizedText.isWholeLine)
            }
            // Whole words only, so "save" doesn't match "saved".
            if " \(joinedWords) ".contains(" \(searchPhrase) ") {
                return (recognizedText.rect, false)
            }
            return nil
        }

        let bestMatch = matchingTexts.min { firstMatch, secondMatch in
            if firstMatch.isWholeLineMatch != secondMatch.isWholeLineMatch {
                return firstMatch.isWholeLineMatch
            }
            return distance(from: guess, toCentreOf: firstMatch.rect) < distance(from: guess, toCentreOf: secondMatch.rect)
        }
        return bestMatch.map { match in CGPoint(x: match.rect.midX, y: match.rect.midY) }
    }

    // MARK: - Helpers

    /// Lowercased words with apostrophes dropped, so "Don’t" and "don't" both read "dont".
    static func normalizedWords(in text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "[’'`]", with: "", options: .regularExpression)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { word in !word.isEmpty }
    }

    private static func recognizeText(using requestHandler: VNImageRequestHandler, imageAreaSize: CGSize) -> [RecognizedText] {
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        // Interface labels are names, not sentences; "correcting" them changes the names.
        textRequest.usesLanguageCorrection = false

        do {
            try requestHandler.perform([textRequest])
        } catch {
            return []
        }

        var recognizedTexts: [RecognizedText] = []
        for observation in textRequest.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            recognizedTexts.append(RecognizedText(
                text: candidate.string,
                rect: areaRect(for: observation.boundingBox, in: imageAreaSize),
                isWholeLine: true
            ))

            // Each word of a longer line is also offered on its own, so a label
            // sharing a line with other text can still be pinned to its own spot.
            let lineText = candidate.string
            let wordRanges = lineText.split(whereSeparator: \.isWhitespace).map { word in word.startIndex..<word.endIndex }
            guard wordRanges.count > 1 else { continue }
            for wordRange in wordRanges {
                guard let wordBox = try? candidate.boundingBox(for: wordRange) else { continue }
                recognizedTexts.append(RecognizedText(
                    text: String(lineText[wordRange]),
                    rect: areaRect(for: wordBox.boundingBox, in: imageAreaSize),
                    isWholeLine: false
                ))
            }
        }
        return recognizedTexts
    }

    /// Vision's boxes are 0–1 with a bottom-left origin; turn them into top-left area points.
    private static func areaRect(for normalizedBox: CGRect, in imageAreaSize: CGSize) -> CGRect {
        CGRect(
            x: normalizedBox.minX * imageAreaSize.width,
            y: (1 - normalizedBox.maxY) * imageAreaSize.height,
            width: normalizedBox.width * imageAreaSize.width,
            height: normalizedBox.height * imageAreaSize.height
        )
    }

    private static func distance(from point: CGPoint, toCentreOf rect: CGRect) -> CGFloat {
        hypot(point.x - rect.midX, point.y - rect.midY)
    }
}
