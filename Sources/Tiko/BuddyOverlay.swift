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
                speechTranscriber: companionManager.speechTranscriber,
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
    @ObservedObject var speechTranscriber: SpeechTranscriber
    let showsWelcomeBubble: Bool

    @State private var buddyOpacity = 0.0
    @State private var welcomeBubbleText = ""
    @State private var welcomeBubbleOpacity = 0.0

    private static let welcomeMessage = "hey! main tiko hoon"

    /// The buddy sits just below and to the right of the real pointer, so it
    /// never covers what the user is about to click.
    private static let offsetFromMousePointer = CGSize(width: 28, height: 24)

    /// Keeps bubbles this far from the screen's edges.
    private static let screenEdgeMargin: CGFloat = 8

    private struct VisibleBubble {
        let text: String
        let isReply: Bool
        let opacity: Double
    }

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

    /// While the user talks the bubble shows what Tiko hears; otherwise a
    /// message from Tiko wins over the welcome bubble.
    private var visibleBubble: VisibleBubble? {
        if companionManager.voiceState == .listening {
            let liveTranscript = speechTranscriber.liveTranscript
            return liveTranscript.isEmpty ? nil : VisibleBubble(text: liveTranscript, isReply: false, opacity: 1)
        }
        if let buddyMessage = companionManager.buddyMessage {
            return VisibleBubble(text: buddyMessage.text, isReply: buddyMessage.isReply, opacity: 1)
        }
        if !welcomeBubbleText.isEmpty {
            return VisibleBubble(text: welcomeBubbleText, isReply: false, opacity: welcomeBubbleOpacity)
        }
        return nil
    }

    private var isWorkingOnAnswer: Bool {
        companionManager.voiceState == .transcribing || companionManager.voiceState == .thinking
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

            // The waveform and spinner are inserted only in their state, so their
            // animations aren't running in the background the rest of the time.
            if isCursorOnThisScreen && companionManager.voiceState == .listening {
                BuddyWaveformView(audioLevel: microphoneCapture.audioLevel)
                    .position(buddyPosition)
                    .transition(.opacity)
            }

            if isCursorOnThisScreen && isWorkingOnAnswer {
                BuddySpinnerView()
                    .position(buddyPosition)
                    .transition(.opacity)
            }

            if isCursorOnThisScreen, let visibleBubble {
                bubble(visibleBubble)
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

    /// Hangs the bubble off the buddy's side — flipped left or upward when the
    /// buddy is close to the screen's right or bottom edge, so it stays readable.
    private func bubble(_ visibleBubble: VisibleBubble) -> some View {
        let bubbleWidth = BuddySpeechBubble.maximumWidth(isReply: visibleBubble.isReply)
        let roughBubbleHeight: CGFloat = visibleBubble.isReply ? 170 : 70
        let opensLeftward = buddyPosition.x + 14 + bubbleWidth > screenFrame.width - Self.screenEdgeMargin
        let opensUpward = buddyPosition.y + 8 + roughBubbleHeight > screenFrame.height - Self.screenEdgeMargin

        // A 1×1 anchor at the buddy lets the bubble size itself to its text and
        // grow away from the buddy, instead of being centred on it.
        return Color.clear
            .frame(width: 1, height: 1)
            .overlay(alignment: Alignment(
                horizontal: opensLeftward ? .trailing : .leading,
                vertical: opensUpward ? .bottom : .top
            )) {
                BuddySpeechBubble(
                    text: visibleBubble.text,
                    isReply: visibleBubble.isReply,
                    hugsTrailingEdge: opensLeftward
                )
                .offset(x: opensLeftward ? -14 : 14, y: opensUpward ? -14 : 8)
            }
            .position(buddyPosition)
            .opacity(visibleBubble.opacity)
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

/// A small spinning arc shown while Tiko works on what the user said.
struct BuddySpinnerView: View {
    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0.15, to: 0.85)
            .stroke(
                AngularGradient(colors: [tikoAccentColor.opacity(0), tikoAccentColor], center: .center),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .shadow(color: tikoAccentColor.opacity(0.6), radius: 6)
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    isSpinning = true
                }
            }
    }
}

/// The small orange speech bubble the buddy talks through.
struct BuddySpeechBubble: View {
    let text: String
    /// Replies get more room and cut off at their end; live transcripts and
    /// notes stay compact and keep their newest words visible.
    let isReply: Bool
    /// True when the bubble opens to the left of the buddy.
    let hugsTrailingEdge: Bool

    static func maximumWidth(isReply: Bool) -> CGFloat {
        isReply ? 320 : 280
    }

    var body: some View {
        Text(text)
            .font(.system(size: isReply ? 12 : 11, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(isReply ? 10 : 4)
            .truncationMode(isReply ? .tail : .head)
            // Wrap to the available width, but always take the height the lines need.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, isReply ? 10 : 8)
            .padding(.vertical, isReply ? 6 : 4)
            .background(
                RoundedRectangle(cornerRadius: isReply ? 8 : 6, style: .continuous)
                    .fill(tikoAccentColor)
                    .shadow(color: tikoAccentColor.opacity(0.5), radius: 6)
            )
            // The anchor proposes 1×1; this gives the text real room to lay out in,
            // while short text still hugs its own width.
            .frame(width: Self.maximumWidth(isReply: isReply), alignment: hugsTrailingEdge ? .trailing : .leading)
    }
}
