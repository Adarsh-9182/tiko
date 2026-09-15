import AppKit
import ScreenCaptureKit
import TikoCore

struct CapturedScreen {
    let image: GeminiImage
    let isCursorScreen: Bool
    /// Lets the same display be captured again, for example to double-check a point.
    let displayID: CGDirectDisplayID
    /// AppKit global coordinates — the same space as the mouse and the overlay windows.
    let displayFrame: CGRect
}

/// Everything Tiko can see at the moment the user asks a question.
struct ScreenContext {
    /// The cursor's screen is always first.
    let screens: [CapturedScreen]
    let cursorCloseUp: GeminiImage?

    var geminiImages: [GeminiImage] {
        screens.map(\.image) + (cursorCloseUp.map { [$0] } ?? [])
    }
}

enum ScreenCaptureError: LocalizedError {
    case nothingCaptured

    var errorDescription: String? {
        "screen capture nahi hua"
    }
}

@MainActor
enum ScreenCaptureService {
    /// Longest side of each full-screen screenshot, in pixels. Big enough to
    /// read interface text, small enough to keep free-tier requests quick.
    private static let screenshotLongestSide: CGFloat = 1280
    /// How many points around the cursor the close-up covers.
    private static let cursorCloseUpSizeInPoints: CGFloat = 360

    static func captureScreenContext() async throws -> ScreenContext {
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let mouseLocation = NSEvent.mouseLocation
        let windowsToExclude = tikoWindows(in: shareableContent)

        let displaysWithFrames = shareableContent.displays.map { display in
            (display: display, frame: appKitFrame(for: display))
        }
        // The cursor's screen goes first so it is always "screen 1".
        let orderedDisplays = displaysWithFrames.sorted { firstDisplay, secondDisplay in
            firstDisplay.frame.contains(mouseLocation) && !secondDisplay.frame.contains(mouseLocation)
        }

        var capturedScreens: [CapturedScreen] = []
        var cursorCloseUp: GeminiImage?

        for (displayIndex, displayWithFrame) in orderedDisplays.enumerated() {
            let isCursorScreen = displayWithFrame.frame.contains(mouseLocation)
            let contentFilter = SCContentFilter(display: displayWithFrame.display, excludingWindows: windowsToExclude)

            let screenshotConfiguration = SCStreamConfiguration()
            let displayAspectRatio = displayWithFrame.frame.width / max(displayWithFrame.frame.height, 1)
            if displayAspectRatio >= 1 {
                screenshotConfiguration.width = Int(screenshotLongestSide)
                screenshotConfiguration.height = Int(screenshotLongestSide / displayAspectRatio)
            } else {
                screenshotConfiguration.height = Int(screenshotLongestSide)
                screenshotConfiguration.width = Int(screenshotLongestSide * displayAspectRatio)
            }

            let screenshot = try await SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: screenshotConfiguration)
            guard let screenshotJPEG = jpegData(from: screenshot) else { continue }

            capturedScreens.append(CapturedScreen(
                image: GeminiImage(
                    jpegData: screenshotJPEG,
                    label: CompanionPrompt.screenLabel(
                        screenNumber: displayIndex + 1,
                        screenCount: orderedDisplays.count,
                        isCursorScreen: isCursorScreen
                    )
                ),
                isCursorScreen: isCursorScreen,
                displayID: displayWithFrame.display.displayID,
                displayFrame: displayWithFrame.frame
            ))

            if isCursorScreen {
                // ScreenCaptureKit measures from the display's top-left corner,
                // while the mouse is in AppKit's bottom-left space.
                let mouseLocationInDisplay = CGPoint(
                    x: mouseLocation.x - displayWithFrame.frame.minX,
                    y: displayWithFrame.frame.maxY - mouseLocation.y
                )
                let closeUpRect = CloseUpRegion.captureRect(
                    centeredOn: mouseLocationInDisplay,
                    displaySize: displayWithFrame.frame.size,
                    regionSize: cursorCloseUpSizeInPoints
                )
                // A missing close-up shouldn't cost the user their answer.
                if let closeUpJPEG = try? await captureRegionJPEG(contentFilter: contentFilter, rectInDisplay: closeUpRect) {
                    cursorCloseUp = GeminiImage(jpegData: closeUpJPEG, label: CompanionPrompt.cursorCloseUpLabel)
                }
            }
        }

        guard !capturedScreens.isEmpty else { throw ScreenCaptureError.nothingCaptured }
        return ScreenContext(screens: capturedScreens, cursorCloseUp: cursorCloseUp)
    }

    /// A fresh, full-detail capture of part of one display.
    ///
    /// - Parameter rectInDisplay: Points from the display's top-left corner.
    static func captureRegion(displayID: CGDirectDisplayID, rectInDisplay: CGRect) async throws -> Data {
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = shareableContent.displays.first(where: { display in display.displayID == displayID }) else {
            throw ScreenCaptureError.nothingCaptured
        }
        let contentFilter = SCContentFilter(display: display, excludingWindows: tikoWindows(in: shareableContent))
        return try await captureRegionJPEG(contentFilter: contentFilter, rectInDisplay: rectInDisplay)
    }

    private static func captureRegionJPEG(contentFilter: SCContentFilter, rectInDisplay: CGRect) async throws -> Data {
        let regionConfiguration = SCStreamConfiguration()
        regionConfiguration.sourceRect = rectInDisplay
        // Two pixels per point keeps small interface text sharp.
        regionConfiguration.width = Int(rectInDisplay.width * 2)
        regionConfiguration.height = Int(rectInDisplay.height * 2)

        let regionImage = try await SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: regionConfiguration)
        guard let regionJPEG = jpegData(from: regionImage) else { throw ScreenCaptureError.nothingCaptured }
        return regionJPEG
    }

    /// Tiko's own buddy and panel are left out, so the model sees only the user's content.
    private static func tikoWindows(in shareableContent: SCShareableContent) -> [SCWindow] {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        return shareableContent.windows.filter { window in
            window.owningApplication?.bundleIdentifier == ownBundleIdentifier
        }
    }

    /// SCDisplay frames use a top-left origin; NSScreen frames use AppKit's
    /// bottom-left origin, like the mouse and the overlay. Match them by display ID.
    private static func appKitFrame(for display: SCDisplay) -> CGRect {
        let matchingScreen = NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
        }
        return matchingScreen?.frame ?? display.frame
    }

    private static func jpegData(from image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }
}
