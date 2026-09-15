import AppKit

// Draws Tiko's app icon — the orange cursor buddy on a dark rounded tile — as
// the set of PNG sizes macOS expects, ready for `iconutil`.
//
//   swift scripts/make-icon.swift build/Tiko.iconset
//   iconutil -c icns build/Tiko.iconset -o Resources/Tiko.icns

let iconsetFolderPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Tiko.iconset"

let iconFiles: [(pixelSize: Int, fileName: String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")
]

let tikoOrange = NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.16, alpha: 1)

func renderIconPNG(pixelSize: Int) -> Data? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        return nil
    }

    let canvasSize = CGFloat(pixelSize)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext

    // Apple's icon grid leaves a margin around the tile so icons line up in the Dock.
    let tileInset = canvasSize * 0.1
    let tileRect = NSRect(x: tileInset, y: tileInset, width: canvasSize - 2 * tileInset, height: canvasSize - 2 * tileInset)
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: tileRect.width * 0.225, yRadius: tileRect.width * 0.225)
    NSGradient(
        starting: NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.22, alpha: 1),
        ending: NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.09, alpha: 1)
    )?.draw(in: tilePath, angle: -90)

    // The buddy: an equilateral triangle around its centroid, tip up, tilted like
    // a pointer. The app tilts it -35° in SwiftUI's downward y; in AppKit's
    // upward y the same visual tilt is +35°.
    let triangleSide = tileRect.width * 0.42
    let triangleHeight = triangleSide * sqrt(3) / 2
    let triangleCentre = NSPoint(x: tileRect.midX, y: tileRect.midY)
    let pointerTiltRadians = 35.0 * Double.pi / 180
    let untiltedVertices = [
        NSPoint(x: 0, y: triangleHeight * 2 / 3),
        NSPoint(x: -triangleSide / 2, y: -triangleHeight / 3),
        NSPoint(x: triangleSide / 2, y: -triangleHeight / 3)
    ]
    let tiltedVertices = untiltedVertices.map { vertex in
        NSPoint(
            x: triangleCentre.x + vertex.x * cos(pointerTiltRadians) - vertex.y * sin(pointerTiltRadians),
            y: triangleCentre.y + vertex.x * sin(pointerTiltRadians) + vertex.y * cos(pointerTiltRadians)
        )
    }

    let trianglePath = NSBezierPath()
    trianglePath.move(to: tiltedVertices[0])
    trianglePath.line(to: tiltedVertices[1])
    trianglePath.line(to: tiltedVertices[2])
    trianglePath.close()

    let glow = NSShadow()
    glow.shadowColor = tikoOrange.withAlphaComponent(0.85)
    glow.shadowBlurRadius = canvasSize * 0.07
    glow.shadowOffset = .zero
    glow.set()
    tikoOrange.setFill()
    trianglePath.fill()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

do {
    try FileManager.default.createDirectory(atPath: iconsetFolderPath, withIntermediateDirectories: true)
    for iconFile in iconFiles {
        guard let iconPNG = renderIconPNG(pixelSize: iconFile.pixelSize) else {
            print("Couldn't draw the \(iconFile.pixelSize)px icon")
            exit(1)
        }
        try iconPNG.write(to: URL(fileURLWithPath: iconsetFolderPath).appendingPathComponent(iconFile.fileName))
    }
    print("Wrote \(iconFiles.count) icon sizes to \(iconsetFolderPath)")
} catch {
    print("Couldn't write the icons: \(error.localizedDescription)")
    exit(1)
}
