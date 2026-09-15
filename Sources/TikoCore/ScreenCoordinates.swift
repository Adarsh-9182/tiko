import CoreGraphics

/// Converts between the three coordinate spaces a point passes through on its
/// way from Gemini's reply to the buddy on screen.
public enum ScreenCoordinates {
    /// Gemini's 0–1000 grid → points inside `region`, measured from the display's
    /// top-left corner. Pass the whole display as a region at (0, 0) for a
    /// full-screen screenshot, or a close-up's rectangle for a close-up.
    ///
    /// Coordinates outside the grid are clamped onto its edge, so a slightly
    /// off-screen guess still points at the nearest spot on screen.
    public static func point(fromNormalized normalizedPoint: CGPoint, in region: CGRect) -> CGPoint {
        let clampedX = min(max(normalizedPoint.x, 0), 1000)
        let clampedY = min(max(normalizedPoint.y, 0), 1000)
        return CGPoint(
            x: region.minX + clampedX / 1000 * region.width,
            y: region.minY + clampedY / 1000 * region.height
        )
    }

    /// Points from a display's top-left corner → AppKit's global space, whose
    /// origin is the bottom-left of the main display and which spans every
    /// connected display. This is the space the mouse and overlay windows use.
    public static func appKitGlobalPoint(fromDisplayPoint displayPoint: CGPoint, displayFrame: CGRect) -> CGPoint {
        CGPoint(
            x: displayFrame.minX + displayPoint.x,
            y: displayFrame.maxY - displayPoint.y
        )
    }
}
