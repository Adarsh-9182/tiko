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
    private weak var companionManager: CompanionManager?

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
                guard let self, self.isShowingOverlay, let companionManager = self.companionManager else { return }
                self.showOverlay(companionManager: companionManager, showsWelcomeBubble: false)
            }
        }
    }

    func showOverlay(companionManager: CompanionManager, showsWelcomeBubble: Bool) {
        self.companionManager = companionManager
        removeOverlayWindows()
        cursorTracker.start()

        for screen in NSScreen.screens {
            let overlayWindow = BuddyOverlayWindow(screen: screen)
            let overlayView = BuddyOverlayView(
                screenFrame: screen.frame,
                cursorTracker: cursorTracker,
                companionManager: companionManager,
                microphoneCapture: companionManager.microphoneCapture,
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
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject var microphoneCapture: MicrophoneCapture
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

    /// A message from Tiko wins over the welcome bubble.
    private var visibleBubbleText: String? {
        if let buddyMessage = companionManager.buddyMessage {
            return buddyMessage
        }
        return welcomeBubbleText.isEmpty ? nil : welcomeBubbleText
    }

    private var visibleBubbleOpacity: Double {
        companionManager.buddyMessage != nil ? 1 : welcomeBubbleOpacity
    }

    var body: some View {
        ZStack {
            BuddyTriangleShape()
                .fill(tikoAccentColor)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(-35))
                .shadow(color: tikoAccentColor, radius: 8)
                .position(buddyPosition)
                .opacity(isCursorOnThisScreen && companionManager.voiceState == .idle ? buddyOpacity : 0)

            // Inserted only while listening, so its animation timeline isn't
            // ticking in the background the rest of the time.
            if isCursorOnThisScreen && companionManager.voiceState == .listening {
                BuddyWaveformView(audioLevel: microphoneCapture.audioLevel)
                    .position(buddyPosition)
                    .transition(.opacity)
            }

            if isCursorOnThisScreen, let visibleBubbleText {
                // A 1×1 anchor at the buddy lets the bubble size itself to its
                // text and hang off the buddy's side, instead of being centred on it.
                Color.clear
                    .frame(width: 1, height: 1)
                    .overlay(alignment: .topLeading) {
                        BuddySpeechBubble(text: visibleBubbleText)
                            .offset(x: 10, y: 8)
                    }
                    .position(buddyPosition)
                    .opacity(visibleBubbleOpacity)
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        // A quick, slightly bouncy spring makes the buddy trail the cursor
        // like something alive instead of being glued to it.
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: buddyPosition)
        .animation(.easeInOut(duration: 0.15), value: companionManager.voiceState)
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

/// Five small bars that bounce with the user's voice while push-to-talk is held.
struct BuddyWaveformView: View {
    let audioLevel: CGFloat

    /// Taller in the middle, so the bars read as a waveform rather than a row of blocks.
    private static let barHeightProfile: [CGFloat] = [0.4, 0.7, 1.0, 0.7, 0.4]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            HStack(spacing: 2) {
                ForEach(Self.barHeightProfile.indices, id: \.self) { barIndex in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(tikoAccentColor)
                        .frame(width: 2.5, height: barHeight(barIndex: barIndex, at: timeline.date))
                }
            }
            .shadow(color: tikoAccentColor.opacity(0.6), radius: 6)
            .animation(.linear(duration: 0.08), value: audioLevel)
        }
    }

    private func barHeight(barIndex: Int, at date: Date) -> CGFloat {
        // Speech loudness is small (roughly 0.01–0.2), so boost it and ease the
        // curve so that quiet talking still moves the bars visibly.
        let boostedAudioLevel = pow(min(max(audioLevel - 0.005, 0) * 6, 1), 0.7)
        // A gentle ripple keeps the bars alive in the pauses between words.
        let ripplePhase = date.timeIntervalSinceReferenceDate * 3.6 + Double(barIndex) * 0.35
        let idleRipple = (sin(ripplePhase) + 1) / 2 * 1.5
        return 3 + boostedAudioLevel * 12 * Self.barHeightProfile[barIndex] + idleRipple
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
