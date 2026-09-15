import AppKit
import Combine
import TikoCore

enum BuddyVoiceState {
    case idle
    /// Push-to-talk is held and the microphone is recording.
    case listening
    /// The user let go; waiting for the speech recognizer's final text.
    case transcribing
    /// Waiting for Gemini's answer.
    case thinking
}

enum GeminiKeyStatus: Equatable {
    case missing
    case checking
    case ready(modelNames: [String])
    case failed(message: String)
}

/// A note the buddy shows next to the cursor.
struct BuddyMessage: Equatable {
    let text: String
    /// Replies can be long, so they get more room than short notes.
    let isReply: Bool
}

/// Tiko's central state: permissions, the cursor buddy, push-to-talk, speech
/// recognition and Gemini. Later phases add pointing and speaking the reply.
@MainActor
final class CompanionManager: ObservableObject {
    @Published private(set) var permissions = PermissionSnapshot()
    /// Published separately because asking for Screen Recording doesn't change
    /// the snapshot until a restart, yet the panel should offer that restart.
    @Published private(set) var hasRequestedScreenRecording = PermissionsCenter.hasRequestedBefore(.screenRecording)

    @Published private(set) var voiceState: BuddyVoiceState = .idle
    @Published private(set) var buddyMessage: BuddyMessage?
    /// The last thing the user said, as recognised text.
    @Published private(set) var lastTranscript: String?
    @Published private(set) var lastReply: GeminiReply?
    @Published private(set) var geminiKeyStatus: GeminiKeyStatus

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

    private var settings: TikoSettings
    /// Recent questions and answers, so follow-ups like "aur uske baad?" make sense.
    private var conversationHistory: [ConversationExchange] = []

    private let overlayWindowManager = OverlayWindowManager()
    private let pushToTalkShortcutMonitor = PushToTalkShortcutMonitor()
    private var permissionPollingTask: Task<Void, Never>?
    private var buddyMessageDismissTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var replyTask: Task<Void, Never>?

    private static let buddyVisibleDefaultsKey = "isBuddyVisible"
    private static let hasShownWelcomeBubbleDefaultsKey = "hasShownWelcomeBubble"
    private static let speechLocaleIdentifier = "en-IN"
    private static let maximumRememberedExchanges = 10

    init() {
        let savedSettings = TikoSettings.load()
        settings = savedSettings
        geminiKeyStatus = !savedSettings.geminiAPIKey.isEmpty && !savedSettings.geminiModelNames.isEmpty
            ? .ready(modelNames: savedSettings.geminiModelNames)
            : .missing
    }

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

    // MARK: - Gemini key

    /// Checks the key by listing the models it can use, and saves it only if that works.
    func saveGeminiAPIKey(_ enteredAPIKey: String) {
        let trimmedAPIKey = enteredAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else { return }
        geminiKeyStatus = .checking

        Task { [weak self] in
            do {
                let availableModelNames = try await GeminiClient(apiKey: trimmedAPIKey, modelNames: []).fetchAvailableModelNames()
                let preferredModelNames = GeminiModelPicker.preferredModelNames(from: availableModelNames)
                guard let self else { return }
                guard !preferredModelNames.isEmpty else {
                    self.geminiKeyStatus = .failed(message: GeminiClientError.noUsableModel.localizedDescription)
                    return
                }

                var updatedSettings = self.settings
                updatedSettings.geminiAPIKey = trimmedAPIKey
                updatedSettings.geminiModelNames = preferredModelNames
                try updatedSettings.save()
                self.settings = updatedSettings
                self.geminiKeyStatus = .ready(modelNames: preferredModelNames)
            } catch {
                self?.geminiKeyStatus = .failed(message: error.localizedDescription)
            }
        }
    }

    func removeGeminiAPIKey() {
        var updatedSettings = settings
        updatedSettings.geminiAPIKey = ""
        updatedSettings.geminiModelNames = []
        do {
            try updatedSettings.save()
            settings = updatedSettings
            geminiKeyStatus = .missing
        } catch {
            geminiKeyStatus = .failed(message: "key hata nahi paaye: \(error.localizedDescription)")
        }
    }

    func copyLastReply() {
        guard let lastReply else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastReply.text, forType: .string)
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
        // A new question replaces anything still in progress for the previous one.
        transcriptionTask?.cancel()
        transcriptionTask = nil
        replyTask?.cancel()
        replyTask = nil
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

        // Capture the screen the moment the user lets go — that's what they were
        // asking about — while speech recognition finishes in parallel.
        let screenContextTask: Task<ScreenContext?, Never>? = permissions.isScreenRecordingGranted
            ? Task { try? await ScreenCaptureService.captureScreenContext() }
            : nil

        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            let finalTranscript = await self.speechTranscriber.finishSession()
            // The user may have pressed the shortcut again while we waited.
            guard !Task.isCancelled, self.voiceState == .transcribing else { return }

            guard !finalTranscript.isEmpty else {
                self.voiceState = .idle
                self.showBuddyMessage("kuch sunai nahi diya, phir se bolo", for: .seconds(2.5))
                return
            }
            self.lastTranscript = finalTranscript
            self.answer(finalTranscript, screenContextTask: screenContextTask)
        }
    }

    private func cancelListening() {
        guard voiceState == .listening else { return }
        microphoneCapture.stop()
        speechTranscriber.cancelSession()
        voiceState = .idle
        applyBuddyVisibility()
    }

    // MARK: - Answering

    private func answer(_ transcript: String, screenContextTask: Task<ScreenContext?, Never>?) {
        replyTask?.cancel()
        voiceState = .thinking

        replyTask = Task { [weak self] in
            guard let self else { return }
            do {
                let screenContext = await screenContextTask?.value
                let reply = try await self.fetchReply(to: transcript, screenContext: screenContext)
                guard !Task.isCancelled else { return }

                self.rememberExchange(ConversationExchange(userText: transcript, tikoReply: reply.text))
                self.lastReply = reply
                self.voiceState = .idle
                self.showBuddyMessage(BuddyMessage(text: reply.text, isReply: true), for: Self.readingDuration(for: reply.text))
            } catch {
                // A cancelled request means the user asked something new; stay quiet.
                guard !Task.isCancelled, !Self.isCancellation(error) else { return }
                self.voiceState = .idle
                self.showBuddyMessage(error.localizedDescription)
            }
        }
    }

    private func fetchReply(to transcript: String, screenContext: ScreenContext?) async throws -> GeminiReply {
        guard case .ready(let modelNames) = geminiKeyStatus, !settings.geminiAPIKey.isEmpty else {
            throw GeminiClientError.missingAPIKey
        }

        let geminiClient = GeminiClient(apiKey: settings.geminiAPIKey, modelNames: modelNames)
        return try await geminiClient.generateReply(
            systemInstruction: CompanionPrompt.systemInstruction(canSeeScreen: screenContext != nil),
            history: conversationHistory,
            images: screenContext?.geminiImages ?? [],
            userText: transcript
        )
    }

    private func rememberExchange(_ exchange: ConversationExchange) {
        conversationHistory.append(exchange)
        // Only recent context helps; an ever-growing history just slows every request.
        if conversationHistory.count > Self.maximumRememberedExchanges {
            conversationHistory.removeFirst(conversationHistory.count - Self.maximumRememberedExchanges)
        }
    }

    /// Long enough to read the reply at a relaxed pace — about two and a half
    /// words a second, plus a moment to notice it appeared.
    private static func readingDuration(for text: String) -> Duration {
        let wordCount = text.split(whereSeparator: \.isWhitespace).count
        let readingSeconds = min(max(2 + Double(wordCount) / 2.5, 4), 20)
        return .seconds(readingSeconds)
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    // MARK: - Buddy

    private func showBuddyMessage(_ text: String, for displayDuration: Duration = .seconds(4)) {
        showBuddyMessage(BuddyMessage(text: text, isReply: false), for: displayDuration)
    }

    private func showBuddyMessage(_ message: BuddyMessage, for displayDuration: Duration) {
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
