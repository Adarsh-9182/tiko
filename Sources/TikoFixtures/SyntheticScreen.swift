import AppKit
import CoreGraphics

/// A made-up app screen drawn in code, with the exact position of every
/// element Tiko could be asked to point at.
public struct SyntheticScreen {
    public let name: String
    /// Size in points, like a Mac display.
    public let pointSize: CGSize
    /// Pixels per point; 2 renders like a Retina display.
    public let scale: CGFloat
    public let fullResolutionImage: CGImage
    /// Where each element is, in points from the top-left, keyed like "sidebar:Bluetooth".
    public let elementRects: [String: CGRect]

    /// The whole screen scaled so its longest side is `longestSide` pixels —
    /// the same kind of screenshot the app sends to Gemini.
    public func screenshotJPEG(longestSide: CGFloat = 1280) -> Data? {
        guard let resizedImage = resizedFullImage(longestSide: longestSide) else { return nil }
        return ImageEncoding.jpegData(from: resizedImage)
    }

    public func screenshotPNG(longestSide: CGFloat) -> Data? {
        guard let resizedImage = resizedFullImage(longestSide: longestSide) else { return nil }
        return ImageEncoding.pngData(from: resizedImage)
    }

    /// A full-detail crop of part of the screen, like the app's close-ups.
    ///
    /// - Parameter rectInPoints: Points from the top-left of the screen.
    public func regionJPEG(rectInPoints: CGRect) -> Data? {
        let rectInPixels = CGRect(
            x: rectInPoints.minX * scale,
            y: rectInPoints.minY * scale,
            width: rectInPoints.width * scale,
            height: rectInPoints.height * scale
        ).integral
        // CGImage crops measure from the top-left, the same way these points do.
        guard let croppedImage = fullResolutionImage.cropping(to: rectInPixels) else { return nil }
        return ImageEncoding.jpegData(from: croppedImage)
    }

    private func resizedFullImage(longestSide: CGFloat) -> CGImage? {
        let aspectRatio = pointSize.width / max(pointSize.height, 1)
        let pixelWidth = aspectRatio >= 1 ? longestSide : longestSide * aspectRatio
        let pixelHeight = aspectRatio >= 1 ? longestSide / aspectRatio : longestSide
        return ImageEncoding.resizedImage(fullResolutionImage, pixelWidth: Int(pixelWidth), pixelHeight: Int(pixelHeight))
    }
}

enum ImageEncoding {
    static func resizedImage(_ image: CGImage, pixelWidth: Int, pixelHeight: Int) -> CGImage? {
        guard let bitmapContext = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        bitmapContext.interpolationQuality = .high
        bitmapContext.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        return bitmapContext.makeImage()
    }

    static func jpegData(from image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }

    static func pngData(from image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}

/// Draws in points measured from the top-left — the way screenshots and
/// designs are described — while AppKit underneath draws from the bottom-left.
public final class SyntheticScreenCanvas {
    public let pointSize: CGSize
    public let scale: CGFloat

    private let bitmap: NSBitmapImageRep
    private let graphicsContext: NSGraphicsContext
    private var elementRects: [String: CGRect] = [:]

    public init?(pointSize: CGSize, scale: CGFloat) {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pointSize.width * scale),
            pixelsHigh: Int(pointSize.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        // Declaring the size in points makes every drawing call below scale to the pixel density.
        bitmap.size = NSSize(width: pointSize.width, height: pointSize.height)
        guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }

        self.pointSize = pointSize
        self.scale = scale
        self.bitmap = bitmap
        self.graphicsContext = graphicsContext
    }

    public func fill(_ rect: CGRect, color: NSColor, cornerRadius: CGFloat = 0) {
        drawInContext {
            color.setFill()
            bezierPath(for: rect, cornerRadius: cornerRadius).fill()
        }
    }

    public func fillOval(_ rect: CGRect, color: NSColor) {
        drawInContext {
            color.setFill()
            NSBezierPath(ovalIn: appKitRect(for: rect)).fill()
        }
    }

    public func stroke(_ rect: CGRect, color: NSColor, cornerRadius: CGFloat = 0, lineWidth: CGFloat = 1) {
        drawInContext {
            color.setStroke()
            // Inset by half the line so the stroke stays inside the rectangle.
            let strokePath = bezierPath(for: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2), cornerRadius: cornerRadius)
            strokePath.lineWidth = lineWidth
            strokePath.stroke()
        }
    }

    public func line(from startPoint: CGPoint, to endPoint: CGPoint, color: NSColor, lineWidth: CGFloat = 1) {
        drawInContext {
            color.setStroke()
            let linePath = NSBezierPath()
            linePath.move(to: NSPoint(x: startPoint.x, y: pointSize.height - startPoint.y))
            linePath.line(to: NSPoint(x: endPoint.x, y: pointSize.height - endPoint.y))
            linePath.lineWidth = lineWidth
            linePath.stroke()
        }
    }

    /// Draws text with its top-left corner at `topLeft` and returns the area it covers.
    @discardableResult
    public func text(_ string: String, at topLeft: CGPoint, fontSize: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .black) -> CGRect {
        let textAttributes = Self.textAttributes(fontSize: fontSize, weight: weight, color: color)
        let textRect = CGRect(origin: topLeft, size: (string as NSString).size(withAttributes: textAttributes))
        drawInContext {
            (string as NSString).draw(at: appKitRect(for: textRect).origin, withAttributes: textAttributes)
        }
        return textRect
    }

    public func textWidth(_ string: String, fontSize: CGFloat, weight: NSFont.Weight = .regular) -> CGFloat {
        (string as NSString).size(withAttributes: Self.textAttributes(fontSize: fontSize, weight: weight, color: .black)).width
    }

    /// Draws an SF Symbol fitted inside `rect` without stretching it.
    public func symbol(_ systemName: String, in rect: CGRect, color: NSColor) {
        guard let symbolImage = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: rect.height, weight: .regular)) else {
            return
        }

        let symbolAspectRatio = symbolImage.size.width / max(symbolImage.size.height, 1)
        let fittedRect: CGRect
        if symbolAspectRatio > rect.width / max(rect.height, 1) {
            let fittedHeight = rect.width / symbolAspectRatio
            fittedRect = CGRect(x: rect.minX, y: rect.midY - fittedHeight / 2, width: rect.width, height: fittedHeight)
        } else {
            let fittedWidth = rect.height * symbolAspectRatio
            fittedRect = CGRect(x: rect.midX - fittedWidth / 2, y: rect.minY, width: fittedWidth, height: rect.height)
        }

        // Symbols come in black; paint the colour over only the symbol's own pixels.
        let tintedSymbolImage = NSImage(size: symbolImage.size, flipped: false) { drawingRect in
            symbolImage.draw(in: drawingRect)
            color.set()
            drawingRect.fill(using: .sourceAtop)
            return true
        }
        drawInContext {
            tintedSymbolImage.draw(in: appKitRect(for: fittedRect))
        }
    }

    /// Records where an element Tiko might be asked about sits.
    public func markElement(_ elementKey: String, rect: CGRect) {
        elementRects[elementKey] = rect
    }

    public func finish(name: String) -> SyntheticScreen? {
        guard let fullResolutionImage = bitmap.cgImage else { return nil }
        return SyntheticScreen(
            name: name,
            pointSize: pointSize,
            scale: scale,
            fullResolutionImage: fullResolutionImage,
            elementRects: elementRects
        )
    }

    private func drawInContext(_ drawing: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        drawing()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func appKitRect(for rect: CGRect) -> NSRect {
        NSRect(x: rect.minX, y: pointSize.height - rect.maxY, width: rect.width, height: rect.height)
    }

    private func bezierPath(for rect: CGRect, cornerRadius: CGFloat) -> NSBezierPath {
        cornerRadius > 0
            ? NSBezierPath(roundedRect: appKitRect(for: rect), xRadius: cornerRadius, yRadius: cornerRadius)
            : NSBezierPath(rect: appKitRect(for: rect))
    }

    private static func textAttributes(fontSize: CGFloat, weight: NSFont.Weight, color: NSColor) -> [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: fontSize, weight: weight), .foregroundColor: color]
    }
}
