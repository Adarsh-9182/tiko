import SwiftUI

/// Tiko's accent colour. The panel and the cursor buddy share it so they read
/// as the same character.
let tikoAccentColor = Color(red: 1.0, green: 0.45, blue: 0.16)

/// The buddy's body: an equilateral triangle that, rotated -35°, looks like a
/// mouse pointer.
struct BuddyTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sideLength = min(rect.width, rect.height)
        let triangleHeight = sideLength * sqrt(3.0) / 2.0

        var path = Path()
        // Place the vertices around the centroid (not the bounding box centre)
        // so the triangle rotates around its visual middle without wobbling.
        path.move(to: CGPoint(x: rect.midX, y: rect.midY - triangleHeight * 2.0 / 3.0))
        path.addLine(to: CGPoint(x: rect.midX - sideLength / 2.0, y: rect.midY + triangleHeight / 3.0))
        path.addLine(to: CGPoint(x: rect.midX + sideLength / 2.0, y: rect.midY + triangleHeight / 3.0))
        path.closeSubpath()
        return path
    }
}
