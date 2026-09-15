import CoreGraphics
import Foundation

/// Where the buddy is and how it's oriented at one moment.
public struct BuddyPose: Equatable {
    public let position: CGPoint
    public let rotationDegrees: Double
    public let scale: CGFloat

    public init(position: CGPoint, rotationDegrees: Double, scale: CGFloat) {
        self.position = position
        self.rotationDegrees = rotationDegrees
        self.scale = scale
    }
}

/// The buddy's swooping flight from one point to another: a curved arc that
/// eases in and out, facing its direction of travel and growing a little
/// mid-air. Positions use SwiftUI's space, where y grows downward.
public struct BuddyFlight: Equatable {
    /// The tilt that makes the triangle look like a mouse pointer.
    public static let restingRotationDegrees: Double = -35

    public let startPosition: CGPoint
    public let endPosition: CGPoint
    /// Pulls the straight line up into an arc.
    public let controlPoint: CGPoint
    public let duration: TimeInterval

    public init(from startPosition: CGPoint, to endPosition: CGPoint) {
        self.startPosition = startPosition
        self.endPosition = endPosition

        let flightDistance = hypot(endPosition.x - startPosition.x, endPosition.y - startPosition.y)
        // Short hops are quick and long flights take their time, but never drag.
        duration = min(max(flightDistance / 800, 0.6), 1.4)

        let arcHeight = min(flightDistance * 0.2, 80)
        controlPoint = CGPoint(
            x: (startPosition.x + endPosition.x) / 2,
            y: (startPosition.y + endPosition.y) / 2 - arcHeight
        )
    }

    public func pose(afterSeconds elapsedSeconds: TimeInterval) -> BuddyPose {
        let linearProgress = duration > 0 ? min(max(elapsedSeconds / duration, 0), 1) : 1
        // Smoothstep: the buddy accelerates away and settles gently.
        let easedProgress = linearProgress * linearProgress * (3 - 2 * linearProgress)
        let remainingProgress = 1 - easedProgress

        // Quadratic Bézier curve through the control point.
        let position = CGPoint(
            x: remainingProgress * remainingProgress * startPosition.x
                + 2 * remainingProgress * easedProgress * controlPoint.x
                + easedProgress * easedProgress * endPosition.x,
            y: remainingProgress * remainingProgress * startPosition.y
                + 2 * remainingProgress * easedProgress * controlPoint.y
                + easedProgress * easedProgress * endPosition.y
        )

        // Face along the curve's tangent. The triangle's tip points up at 0°,
        // while atan2 gives 0° for "rightward", hence the extra 90°.
        let tangentX = 2 * remainingProgress * (controlPoint.x - startPosition.x) + 2 * easedProgress * (endPosition.x - controlPoint.x)
        let tangentY = 2 * remainingProgress * (controlPoint.y - startPosition.y) + 2 * easedProgress * (endPosition.y - controlPoint.y)
        let rotationDegrees = tangentX == 0 && tangentY == 0
            ? Self.restingRotationDegrees
            : atan2(Double(tangentY), Double(tangentX)) * 180 / .pi + 90

        // Swell to 1.3× at the top of the arc and back to normal on landing.
        let scale = 1 + CGFloat(sin(linearProgress * .pi)) * 0.3

        return BuddyPose(position: position, rotationDegrees: rotationDegrees, scale: scale)
    }
}
