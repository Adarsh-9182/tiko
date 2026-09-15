import AppKit
import ScreenCaptureKit
import TikoCore

struct CapturedScreen {
    let image: GeminiImage
    let isCursorScreen: Bool
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
    /// The close-up covers this many points around the cursor, captured at
    /// 2 pixels per point so small text stays sharp.
    private static let cursorCloseUpSizeInPoints: CGFloat = 360

    static func captureScreenContext() async throws -> ScreenContext {
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let mouseLocation = NSEvent.mouseLocation

        // Leave Tiko's own buddy and panel out, so the model sees only the user's content.
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let tikoWindows = shareableContent.windows.filter { window in
            window.owningApplication?.bundleIdentifier == ownBundleIdentifier
        }

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
            let contentFilter = SCContentFilter(display: displayWithFrame.display, excludingWindows: tikoWindows)

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
                displayFrame: displayWithFrame.frame
            ))

            if isCursorScreen {
                // A missing close-up shouldn't cost the user their answer.
                cursorCloseUp = try? await captureCursorCloseUp(
                    contentFilter: contentFilter,
                    displayFrame: displayWithFrame.frame,
                    mouseLocation: mouseLocation
                )
            }
        }

        guard !capturedScreens.isEmpty else { throw ScreenCaptureError.nothingCaptured }
        return ScreenContext(screens: capturedScreens, cursorCloseUp: cursorCloseUp)
    }

    private static func captureCursorCloseUp(contentFilter: SCContentFilter, displayFrame: CGRect, mouseLocation: CGPoint) async throws -> GeminiImage? {
        // ScreenCaptureKit measures the source rectangle from the display's
        // top-left corner, while the mouse is in AppKit's bottom-left space.
        let mouseLocationInDisplay = CGPoint(
            x: mouseLocation.x - displayFrame.minX,
            y: displayFrame.maxY - mouseLocation.y
        )
        let closeUpRect = CursorCloseUp.captureRect(
            mouseLocationInDisplay: mouseLocationInDisplay,
            displaySize: displayFrame.size,
            closeUpSize: cursorCloseUpSizeInPoints
        )

        let closeUpConfiguration = SCStreamConfiguration()
        closeUpConfiguration.sourceRect = closeUpRect
        closeUpConfiguration.width = Int(closeUpRect.width * 2)
        closeUpConfiguration.height = Int(closeUpRect.height * 2)

        let closeUpImage = try await SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: closeUpConfiguration)
        guard let closeUpJPEG = jpegData(from: closeUpImage) else { return nil }
        return GeminiImage(jpegData: closeUpJPEG, label: CompanionPrompt.cursorCloseUpLabel)
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
