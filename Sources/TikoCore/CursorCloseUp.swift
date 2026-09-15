import CoreGraphics

/// The small region around the mouse that Tiko sends in full detail, so
/// "what's this?" can be answered even when a full-screen screenshot is too
/// small to read.
public enum CursorCloseUp {
    /// A square of `closeUpSize` points centred on the cursor, slid back inside
    /// the display when the cursor is near an edge.
    ///
    /// - Parameters:
    ///   - mouseLocationInDisplay: Points from the display's top-left corner.
    /// - Returns: Points from the display's top-left corner.
    public static func captureRect(mouseLocationInDisplay: CGPoint, displaySize: CGSize, closeUpSize: CGFloat) -> CGRect {
        let closeUpWidth = min(closeUpSize, displaySize.width)
        let closeUpHeight = min(closeUpSize, displaySize.height)

        let originX = min(max(mouseLocationInDisplay.x - closeUpWidth / 2, 0), displaySize.width - closeUpWidth)
        let originY = min(max(mouseLocationInDisplay.y - closeUpHeight / 2, 0), displaySize.height - closeUpHeight)

        return CGRect(x: originX, y: originY, width: closeUpWidth, height: closeUpHeight)
    }
}
