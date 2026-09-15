import CoreGraphics
import Foundation

/// Double-checks a pointing guess on a sharp close-up. The full-screen
/// screenshot Gemini first sees is scaled down, so its first guess can be a
/// little off; asking again about a small region shown in full detail
/// pins the element down.
public enum PointRefiner {
    /// - Parameters:
    ///   - regionRect: Where the close-up was taken, in points from the display's top-left corner.
    ///   - regionJPEG: The close-up image of `regionRect`.
    /// - Returns: The refined point in the same space as `regionRect`, or nil when
    ///   the element isn't in the close-up or the request fails — callers then
    ///   keep the first guess.
    public static func refinePoint(
        elementLabel: String,
        userQuestion: String,
        regionRect: CGRect,
        regionJPEG: Data,
        geminiClient: GeminiClient
    ) async -> CGPoint? {
        guard let refinementReply = try? await geminiClient.generateReply(
            systemInstruction: CompanionPrompt.pointRefinementInstruction,
            history: [],
            images: [GeminiImage(jpegData: regionJPEG, label: CompanionPrompt.pointRefinementImageLabel)],
            userText: CompanionPrompt.pointRefinementQuestion(elementLabel: elementLabel, userQuestion: userQuestion)
        ) else {
            return nil
        }

        guard let normalizedPointInRegion = PointTag.parse(refinementReply.text).normalizedPoint else {
            return nil
        }
        return ScreenCoordinates.point(fromNormalized: normalizedPointInRegion, in: regionRect)
    }
}
