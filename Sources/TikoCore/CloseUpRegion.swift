import CoreGraphics

/// A small square region of a display that Tiko captures in full detail — around
/// the cursor, so "what's this?" can be answered, and around a first pointing
/// guess, so the point can be double-checked.
public enum CloseUpRegion {
    /// A square of `regionSize` points centred on `centerInDisplay`, slid back
    /// inside the display when the centre is near an edge.
    ///
    /// Both the centre and the returned rectangle are in points from the
    /// display's top-left corner.
    public static func captureRect(centeredOn centerInDisplay: CGPoint, displaySize: CGSize, regionSize: CGFloat) -> CGRect {
        let regionWidth = min(regionSize, displaySize.width)
        let regionHeight = min(regionSize, displaySize.height)

        let originX = min(max(centerInDisplay.x - regionWidth / 2, 0), displaySize.width - regionWidth)
        let originY = min(max(centerInDisplay.y - regionHeight / 2, 0), displaySize.height - regionHeight)

        return CGRect(x: originX, y: originY, width: regionWidth, height: regionHeight)
    }
}
