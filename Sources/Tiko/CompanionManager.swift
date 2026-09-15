import AppKit
import Combine

enum BuddyVoiceState {
    case idle
    /// Push-to-talk is held and the microphone is recording.
    case listening
    /// The user let go; waiting for the speech recognizer's final text.
    case transcribing
}

/// Tiko's central state: permissions, the cursor buddy, push-to-talk and
/// speech recognition. Later phases add the AI reply and pointing.
@MainActor
final class CompanionManager: ObservableObject {
    @Published private(set) var permissions = PermissionSnapshot()
    /// Published separately because asking for Screen Recording doesn't change
    /// the snapshot until a restart, yet the panel should offer that restart.
    @Published private(set) var hasRequestedScreenRecording = PermissionsCenter.hasRequestedBefore(.screenRecording)

    @Published private(set) var voiceState: BuddyVoiceState = .idle
    /// A short note the buddy shows next to the cursor, like a missing permission.
    @Published private(set) var buddyMessage: String?
    /// The last thing the user said, as recognised text.
    @Published private(set) var lastTranscript: String?

    /// Whether the buddy follows the cursor. Saved so the choice survives restarts.
    @Published var isBuddyVisible = UserDefaults.standard.object(forKey: CompanionManager.buddyVisibleDefaultsKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isBuddyVisible, forKey: Self.buddyVisibleDefaultsKey)
            applyBuddyVisibility()
        }
    }

    /// Shared with the overlay so the waveform can follow the microphone level.
    let microphoneCapture = MicrophoneCapture()
    /// Shared with the overlay so it can show the words as they're recognised.
    let speechTranscriber = SpeechTranscriber()

    private let overlayWindowManager = OverlayWindowManager()
    private let pushToTalkShortcutMonitor = PushToTalkShortcutMonitor()
    private var permissionPollingTask: Task<Void, Never>?
    private var buddyMessageDismissTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?

    private static let buddyVisibleDefaultsKey = "isBuddyVisible"
    private static let hasShownWelcomeBubbleDefaultsKey = "hasShownWelcomeBubble"
    private static let speechLocaleIdentifier = "en-IN"

    func start() {
        pushToTalkShortcutMonitor.onTransition = { [weak self] shortcutTransition in
            // The event tap is attached to the main run loop, so this is already the main thread.
            MainActor.assumeIsolated {
                self?.handlePushToTalkTransition(shortcutTransition)
            }
        }

        // macOS doesn't tell an app when the user flips a switch in System
        // Settings, so poll. It's cheap, and the panel updates within a moment.
        permissionPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshPermissions()
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
        applyBuddyVisibility()
    }

    func refreshPermissions() {
        let latestSnapshot = PermissionsCenter.currentSnapshot()
        // Only publish real changes so the panel doesn't redraw every poll.
        if latestSnapshot != permissions {
            permissions = latestSnapshot
        }

        // The shortcut tap can only exist while Accessibility is granted, so
        // start it the moment the user allows it, and drop it if they revoke it.
        if latestSnapshot.isAccessibilityGranted {
            if !pushToTalkShortcutMonitor.isRunning {
                pushToTalkShortcutMonitor.start()
            }
        } else if pushToTalkShortcutMonitor.isRunning {
            pushToTalkShortcutMonitor.stop()
        }
    }

    func requestPermission(_ permissionKind: PermissionKind) {
        PermissionsCenter.request(permissionKind)
        hasRequestedScreenRecording = PermissionsCenter.hasRequestedBefore(.screenRecording)
        refreshPermissions()
    }

    /// Starts a fresh copy of Tiko and quits this one. Needed after granting
    /// Screen Recording, which macOS only applies to a newly launched app.
    func relaunch() {
        let openConfiguration = NSWorkspace.OpenConfiguration()
        openConfiguration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: openConfiguration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Push-to-talk

    private func handlePushToTalkTransition(_ shortcutTransition: PushToTalkShortcutTransition) {
        switch shortcutTransition {
        case .pressed:
            startListening()
        case .released:
            finishListening()
        case .cancelled:
            cancelListening()
        }
    }

    private func startListening() {
        guard voiceState != .listening else { return }
        // A new question replaces one that is still being transcribed.
        transcriptionTask?.cancel()
        transcriptionTask = nil
        // Get the panel out of the way so it doesn't cover what the user is asking about.
        NotificationCenter.default.post(name: .tikoDismissPanel, object: nil)

        guard permissions.isMicrophoneGranted && permissions.isSpeechRecognitionGranted else {
            voiceState = .idle
            showBuddyMessage("mic aur speech recognition ki permission chahiye, menu bar mein Tiko kholo")
            return
        }

        do {
            let speechAudioSink = try speechTranscriber.startSession(localeIdentifier: Self.speechLocaleIdentifier)
            try microphoneCapture.start(onAudioBuffer: { audioBuffer in
                speechAudioSink.append(audioBuffer)
            })
            clearBuddyMessage()
            voiceState = .listening
            applyBuddyVisibility()
        } catch {
            speechTranscriber.cancelSession()
            voiceState = .idle
            showBuddyMessage(error.localizedDescription)
        }
    }

    private func finishListening() {
        guard voiceState == .listening else { return }
        microphoneCapture.stop()
        voiceState = .transcribing

        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            let finalTranscript = await self.speechTranscriber.finishSession()
            // The user may have pressed the shortcut again while we waited.
            guard !Task.isCancelled, self.voiceState == .transcribing else { return }
            self.voiceState = .idle

            guard !finalTranscript.isEmpty else {
                self.showBuddyMessage("kuch sunai nahi diya, phir se bolo", for: .seconds(2.5))
                return
            }
            self.lastTranscript = finalTranscript
            // Phase 6 sends this to Gemini. Until then, show what was heard so it can be checked.
            self.showBuddyMessage("suna: \(finalTranscript)", for: .seconds(5))
        }
    }

    private func cancelListening() {
        guard voiceState == .listening else { return }
        microphoneCapture.stop()
        speechTranscriber.cancelSession()
        voiceState = .idle
        applyBuddyVisibility()
    }

    // MARK: - Buddy

    private func showBuddyMessage(_ message: String, for displayDuration: Duration = .seconds(4)) {
        buddyMessage = message
        applyBuddyVisibility()

        buddyMessageDismissTask?.cancel()
        buddyMessageDismissTask = Task { [weak self] in
            try? await Task.sleep(for: displayDuration)
            guard !Task.isCancelled else { return }
            self?.clearBuddyMessage()
        }
    }

    private func clearBuddyMessage() {
        buddyMessageDismissTask?.cancel()
        buddyMessageDismissTask = nil
        guard buddyMessage != nil else { return }
        buddyMessage = nil
        applyBuddyVisibility()
    }

    private func applyBuddyVisibility() {
        // Even with the buddy switched off, it appears while the user is talking
        // to Tiko or Tiko has something to tell them.
        let shouldShowOverlay = isBuddyVisible || voiceState != .idle || buddyMessage != nil
        guard shouldShowOverlay else {
            overlayWindowManager.hideOverlay()
            return
        }
        guard !overlayWindowManager.isShowingOverlay else { return }

        // The buddy introduces itself only the very first time it appears.
        let hasShownWelcomeBubble = UserDefaults.standard.bool(forKey: Self.hasShownWelcomeBubbleDefaultsKey)
        UserDefaults.standard.set(true, forKey: Self.hasShownWelcomeBubbleDefaultsKey)
        overlayWindowManager.showOverlay(companionManager: self, showsWelcomeBubble: !hasShownWelcomeBubble)
    }
}
