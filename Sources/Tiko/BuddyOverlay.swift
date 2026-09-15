import AppKit
import SwiftUI

/// A transparent, click-through window covering one whole screen. The buddy
/// is drawn inside it, so it can appear anywhere without blocking any app.
final class BuddyOverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Every click passes straight through to the app underneath.
        ignoresMouseEvents = true
        // Above menus and popups, so the buddy is never hidden behind them.
        level = .screenSaver
        // Stay put on every Space and over full-screen apps, and stay out of ⌘-` window cycling.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        setFrame(screen.frame, display: false)
    }

    // Never take focus away from the app the user is working in.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Creates one overlay window per connected screen, so the buddy can follow
/// the cursor from one monitor to the next.
@MainActor
final class OverlayWindowManager {
    private var overlayWindows: [BuddyOverlayWindow] = []
    private let cursorTracker = CursorTracker()
    private var screenChangeObserver: NSObjectProtocol?

    var isShowingOverlay: Bool { !overlayWindows.isEmpty }

    init() {
        // Plugging in a monitor or changing resolution changes the screen
        // frames, so rebuild the windows to match.
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isShowingOverlay else { return }
                self.showOverlay(showsWelcomeBubble: false)
            }
        }
    }

    func showOverlay(showsWelcomeBubble: Bool) {
        removeOverlayWindows()
        cursorTracker.start()

        for screen in NSScreen.screens {
            let overlayWindow = BuddyOverlayWindow(screen: screen)
            let overlayView = BuddyOverlayView(
                screenFrame: screen.frame,
                cursorTracker: cursorTracker,
                showsWelcomeBubble: showsWelcomeBubble
            )
            overlayWindow.contentView = NSHostingView(rootView: overlayView)
            overlayWindow.orderFrontRegardless()
            overlayWindows.append(overlayWindow)
        }
    }

    func hideOverlay() {
        removeOverlayWindows()
        // With no buddy on screen there's no reason to watch the mouse.
        cursorTracker.stop()
    }

    private func removeOverlayWindows() {
        for overlayWindow in overlayWindows {
            overlayWindow.orderOut(nil)
            overlayWindow.contentView = nil
        }
        overlayWindows.removeAll()
    }
}

/// The buddy as drawn on one screen. Every screen has its own copy, and only
/// the copy on the screen that holds the cursor is visible.
struct BuddyOverlayView: View {
    let screenFrame: CGRect
    @ObservedObject var cursorTracker: CursorTracker
    let showsWelcomeBubble: Bool

    @State private var buddyOpacity = 0.0
    @State private var welcomeBubbleText = ""
    @State private var welcomeBubbleOpacity = 0.0

    private static let welcomeMessage = "hey! main tiko hoon"

    /// The buddy sits just below and to the right of the real pointer, so it
    /// never covers what the user is about to click.
    private static let offsetFromMousePointer = CGSize(width: 28, height: 24)

    private var isCursorOnThisScreen: Bool {
        screenFrame.contains(cursorTracker.mouseLocation)
    }

    /// The buddy's centre in this window's SwiftUI coordinates.
    private var buddyPosition: CGPoint {
        // AppKit measures up from the bottom of the main screen; SwiftUI measures
        // down from the top of this window. Flip Y within this screen's frame.
        CGPoint(
            x: cursorTracker.mouseLocation.x - screenFrame.minX + Self.offsetFromMousePointer.width,
            y: screenFrame.maxY - cursorTracker.mouseLocation.y + Self.offsetFromMousePointer.height
        )
    }

    var body: some View {
        ZStack {
            BuddyTriangleShape()
                .fill(tikoAccentColor)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(-35))
                .shadow(color: tikoAccentColor, radius: 8)
                .position(buddyPosition)
                .opacity(isCursorOnThisScreen ? buddyOpacity : 0)

            if isCursorOnThisScreen && !welcomeBubbleText.isEmpty {
                // A 1×1 anchor at the buddy lets the bubble size itself to its
                // text and hang off the buddy's side, instead of being centred on it.
                Color.clear
                    .frame(width: 1, height: 1)
                    .overlay(alignment: .topLeading) {
                        BuddySpeechBubble(text: welcomeBubbleText)
                            .offset(x: 10, y: 8)
                    }
                    .position(buddyPosition)
                    .opacity(welcomeBubbleOpacity)
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        // A quick, slightly bouncy spring makes the buddy trail the cursor
        // like something alive instead of being glued to it.
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: buddyPosition)
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) {
                buddyOpacity = 1
            }
            if showsWelcomeBubble && isCursorOnThisScreen {
                playWelcomeBubble()
            }
        }
    }

    /// Types the welcome message out one character at a time, holds it, then fades it away.
    private func playWelcomeBubble() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeIn(duration: 0.3)) {
                welcomeBubbleOpacity = 1
            }
            for character in Self.welcomeMessage {
                welcomeBubbleText.append(character)
                try? await Task.sleep(for: .milliseconds(35))
            }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.5)) {
                welcomeBubbleOpacity = 0
            }
            try? await Task.sleep(for: .milliseconds(500))
            welcomeBubbleText = ""
        }
    }
}

/// The small orange speech bubble the buddy talks through.
struct BuddySpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tikoAccentColor)
                    .shadow(color: tikoAccentColor.opacity(0.5), radius: 6)
            )
            // Take the text's natural size even though the anchor proposes 1×1.
            .fixedSize()
    }
}
