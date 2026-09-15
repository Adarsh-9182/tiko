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

/// Somewhere on screen the buddy should fly to.
struct PointingTarget: Equatable {
    let id = UUID()
    /// The element's centre, in AppKit global coordinates.
    let location: CGPoint
    /// The display the element is on, so only that screen's overlay flies there.
    let displayFrame: CGRect
    let elementLabel: String
    /// Whether the close-up double-check confirmed the spot.
    let wasZoomChecked: Bool
}

/// Tiko's central state: permissions, the cursor buddy, push-to-talk, speech
/// recognition, Gemini, pointing, speaking replies, guided tours and history.
@MainActor
final class CompanionManager: ObservableObject {
    @Published private(set) var permissions = PermissionSnapshot()
    /// Published separately because asking for Screen Recording doesn't change
    /// the snapshot until a restart, yet the panel should offer that restart.
    @Published private(set) var hasRequestedScreenRecording = PermissionsCenter.hasRequestedBefore(.screenRecording)

    @Published private(set) var voiceState: BuddyVoiceState = .idle
    @Published private(set) var buddyMessage: BuddyMessage?
    /// Where the buddy is pointing right now; nil sends it back to the cursor.
    @Published private(set) var pointingTarget: PointingTarget?
    /// The multi-step task the user is being walked through, if any.
    @Published private(set) var activeTour: GuidedTour?
    /// The last thing the user said, as recognised text.
    @Published private(set) var lastTranscript: String?
    @Published private(set) var lastReply: GeminiReply?
    /// Where the buddy pointed for the last reply, kept for the panel.
    @Published private(set) var lastPointingTarget: PointingTarget?
    @Published private(set) var geminiKeyStatus: GeminiKeyStatus
    /// Every question and answer, saved on this Mac for the History tab.
    @Published private(set) var conversationLog = ConversationLog.load()

    /// Whether the buddy follows the cursor. Saved so the choice survives restarts.
    @Published var isBuddyVisible = UserDefaults.standard.object(forKey: CompanionManager.buddyVisibleDefaultsKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isBuddyVisible, forKey: Self.buddyVisibleDefaultsKey)
            applyBuddyVisibility()
        }
    }

    /// Whether replies are read aloud. Saved, so a quiet office stays quiet.
    @Published var isSpeakingRepliesEnabled = UserDefaults.standard.object(forKey: CompanionManager.speakRepliesDefaultsKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isSpeakingRepliesEnabled, forKey: Self.speakRepliesDefaultsKey)
            if !isSpeakingRepliesEnabled {
                buddyVoice.stop()
            }
        }
    }

    /// The choices made in the Settings window.
    let preferences = TikoPreferences()
    /// Shared with the overlay so the waveform can follow the microphone level.
    let microphoneCapture = MicrophoneCapture()
    /// Shared with the overlay so it can show the words as they're recognised.
    let speechTranscriber = SpeechTranscriber()
    /// Shared with Settings so it can show which voice is speaking.
    let buddyVoice = BuddyVoice()

    /// Everything Tiko needs before it can answer: all four permissions and a working key.
    var isSetUpComplete: Bool {
        guard permissions.areAllGranted, case .ready = geminiKeyStatus else { return false }
        return true
    }

    private var settings: TikoSettings
    /// Recent questions and answers, so follow-ups like "aur uske baad?" make sense.
    private var conversationHistory: [ConversationExchange] = []

    private let overlayWindowManager = OverlayWindowManager()
    private let pushToTalkShortcutMonitor = PushToTalkShortcutMonitor()
    private var preferenceSubscriptions: Set<AnyCancellable> = []
    private var permissionPollingTask: Task<Void, Never>?
    private var buddyMessageDismissTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var replyTask: Task<Void, Never>?
    private var listeningStartTime = ContinuousClock.now

    private static let buddyVisibleDefaultsKey = "isBuddyVisible"
    private static let speakRepliesDefaultsKey = "isSpeakingRepliesEnabled"
    private static let hasShownWelcomeBubbleDefaultsKey = "hasShownWelcomeBubble"
    private static let maximumRememberedExchanges = 10
    /// The close-up used to double-check a point, in points.
    private static let pointRefinementRegionSize: CGFloat = 400
    /// The double-check is a bonus; past this, point at the first guess instead of making the user wait.
    private static let pointRefinementTimeLimit: Duration = .seconds(5)
    /// A press shorter than this is a tap, not someone talking.
    private static let quickTapLimit: Duration = .milliseconds(450)
    /// How long a tour step waits for the user before the tour quietly ends.
    private static let tourStepPatience: Duration = .seconds(60)
    /// What a "next step" request is remembered as in the conversation history.
    private static let nextStepHistoryText = "(next step)"
    private static let voicePreviewText = "namaste! main tiko hoon, aapke cursor ke paas rehta hoon."

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

        // Settings take effect the moment they change, with no restart.
        preferences.$pushToTalkShortcut
            .sink { [weak self] pushToTalkShortcut in
                self?.pushToTalkShortcutMonitor.shortcut = pushToTalkShortcut
            }
            .store(in: &preferenceSubscriptions)
        preferences.$voiceIdentifier
            .sink { [weak self] voiceIdentifier in
                self?.buddyVoice.useVoice(identifier: voiceIdentifier)
            }
            .store(in: &preferenceSubscriptions)
        preferences.$speakingSpeed
            .sink { [weak self] speakingSpeed in
                self?.buddyVoice.speechRate = speakingSpeed.speechRate
            }
            .store(in: &preferenceSubscriptions)

        // Checked right away, so the app can tell at launch whether setup is still needed.
        refreshPermissions()
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        TikoLog.write("launched v\(appVersion) · \(Self.describe(permissions)) · key \(keyStatusDescription)")

        // macOS doesn't tell an app when the user flips a switch in System
        // Settings, so poll. It's cheap, and the panel updates within a moment.
        permissionPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                self?.refreshPermissions()
            }
        }
        applyBuddyVisibility()
    }

    func refreshPermissions() {
        let latestSnapshot = PermissionsCenter.currentSnapshot()
        // Only publish real changes so the panel doesn't redraw every poll.
        if latestSnapshot != permissions {
            permissions = latestSnapshot
            TikoLog.write("permissions changed · \(Self.describe(latestSnapshot))")
        }

        // The shortcut tap can only exist while Accessibility is granted, so
        // start it the moment the user allows it, and drop it if they revoke it.
        if latestSnapshot.isAccessibilityGranted {
            if !pushToTalkShortcutMonitor.isRunning {
                let didStartTap = pushToTalkShortcutMonitor.start()
                TikoLog.write(didStartTap ? "shortcut tap started" : "shortcut tap refused by macOS")
            }
        } else if pushToTalkShortcutMonitor.isRunning {
            pushToTalkShortcutMonitor.stop()
            TikoLog.write("shortcut tap stopped: accessibility revoked")
        }
    }

    func requestPermission(_ permissionKind: PermissionKind) {
        TikoLog.write("requesting \(permissionKind.title)")
        PermissionsCenter.request(permissionKind)
        hasRequestedScreenRecording = PermissionsCenter.hasRequestedBefore(.screenRecording)
        refreshPermissions()
    }

    /// Starts a fresh copy of Tiko and quits this one. Needed after granting
    /// Screen Recording, which macOS only applies to a newly launched app.
    func relaunch() {
        TikoLog.write("relaunching")
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
                    TikoLog.write("key check: no usable model among \(availableModelNames.count)")
                    self.geminiKeyStatus = .failed(message: GeminiClientError.noUsableModel.localizedDescription)
                    return
                }

                var updatedSettings = self.settings
                updatedSettings.geminiAPIKey = trimmedAPIKey
                updatedSettings.geminiModelNames = preferredModelNames
                try updatedSettings.save()
                self.settings = updatedSettings
                self.geminiKeyStatus = .ready(modelNames: preferredModelNames)
                TikoLog.write("key saved · models \(preferredModelNames.joined(separator: ", "))")
            } catch {
                TikoLog.write("key check failed: \(error.localizedDescription)")
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
            TikoLog.write("key removed")
        } catch {
            geminiKeyStatus = .failed(message: "key hata nahi paaye: \(error.localizedDescription)")
        }
    }

    func copyLastReply() {
        guard let lastReply else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastReply.text, forType: .string)
    }

    /// Ends the guided tour from the panel, along with the step still on screen.
    func endTour() {
        guard activeTour != nil else { return }
        TikoLog.write("tour ended from the panel")
        activeTour = nil
        replyTask?.cancel()
        replyTask = nil
        buddyVoice.stop()
        if voiceState == .thinking {
            voiceState = .idle
        }
        clearBuddyMessage()
    }

    // MARK: - Settings actions

    /// Reads a short sample aloud with the chosen voice and speed.
    func previewVoice() {
        Task {
            await buddyVoice.speak(Self.voicePreviewText)
        }
    }

    func clearHistory() {
        conversationLog.removeAll()
        try? conversationLog.save()
        TikoLog.write("history cleared")
    }

    /// Sends one typed question through the whole answer path — screenshot,
    /// Gemini, pointing, the bubble and speech — without the microphone. Used by
    /// `-TikoAskOnLaunch` to check a build end to end.
    func ask(_ question: String) {
        TikoLog.write("asking without the microphone")
        transcriptionTask?.cancel()
        replyTask?.cancel()
        buddyVoice.stop()
        pointingTarget = nil
        activeTour = nil
        clearBuddyMessage()
        lastTranscript = question

        let screenContextTask: Task<ScreenContext?, Never>? = permissions.isScreenRecordingGranted
            ? Task { await Self.captureScreenContextLogged() }
            : nil
        answer(question: question, screenContextTask: screenContextTask, continuingTour: nil)
    }

    // MARK: - Keyboard

    private func handlePushToTalkTransition(_ shortcutTransition: PushToTalkShortcutTransition) {
        switch shortcutTransition {
        case .pressed:
            TikoLog.write("shortcut pressed")
            startListening()
        case .released:
            TikoLog.write("shortcut released")
            finishListening()
        case .cancelled:
            TikoLog.write("shortcut cancelled by another key")
            cancelListening()
        case .escapePressed:
            stopEverything()
        }
    }

    /// Esc: stop speaking, thinking, pointing and any tour at once. Unlike
    /// Clicky, Tiko never has to be sat through once it starts talking.
    private func stopEverything() {
        let isTikoBusy = buddyVoice.isSpeaking
            || voiceState == .transcribing
            || voiceState == .thinking
            || buddyMessage != nil
            || pointingTarget != nil
            || activeTour != nil
        guard isTikoBusy, voiceState != .listening else { return }
        TikoLog.write("stopped with esc")

        transcriptionTask?.cancel()
        transcriptionTask = nil
        replyTask?.cancel()
        replyTask = nil
        speechTranscriber.cancelSession()
        buddyVoice.stop()
        activeTour = nil
        voiceState = .idle
        clearBuddyMessage()
    }

    // MARK: - Push-to-talk

    private func startListening() {
        guard voiceState != .listening else { return }
        // A new press replaces anything still in progress for the previous question.
        // A tour in progress survives: this press may be the user asking for its next step.
        transcriptionTask?.cancel()
        transcriptionTask = nil
        replyTask?.cancel()
        replyTask = nil
        buddyVoice.stop()
        pointingTarget = nil
        // Get the panel out of the way so it doesn't cover what the user is asking about.
        NotificationCenter.default.post(name: .tikoDismissPanel, object: nil)

        guard permissions.isMicrophoneGranted && permissions.isSpeechRecognitionGranted else {
            TikoLog.write("can't listen: microphone=\(permissions.isMicrophoneGranted) speech=\(permissions.isSpeechRecognitionGranted)")
            voiceState = .idle
            showBuddyMessage("mic aur speech recognition ki permission chahiye, menu bar mein Tiko kholo")
            return
        }

        do {
            let speechAudioSink = try speechTranscriber.startSession(localeIdentifier: preferences.speechLanguage.localeIdentifier)
            try microphoneCapture.start(onAudioBuffer: { audioBuffer in
                speechAudioSink.append(audioBuffer)
            })
            clearBuddyMessage()
            listeningStartTime = ContinuousClock.now
            voiceState = .listening
            applyBuddyVisibility()
        } catch {
            TikoLog.write("couldn't start listening: \(error.localizedDescription)")
            speechTranscriber.cancelSession()
            voiceState = .idle
            showBuddyMessage(error.localizedDescription)
        }
    }

    private func finishListening() {
        guard voiceState == .listening else { return }
        microphoneCapture.stop()
        let heldDuration = ContinuousClock.now - listeningStartTime
        let wasQuickTap = heldDuration < Self.quickTapLimit
        voiceState = .transcribing

        // Capture the screen the moment the user lets go — that's what they were
        // asking about — while speech recognition finishes in parallel.
        let screenContextTask: Task<ScreenContext?, Never>? = permissions.isScreenRecordingGranted
            ? Task { await Self.captureScreenContextLogged() }
            : nil

        // During a tour, a quick tap means "next step", so there's nothing to transcribe.
        if let activeTour, wasQuickTap {
            TikoLog.write("quick tap during a tour: next step")
            speechTranscriber.cancelSession()
            continueTour(activeTour, screenContextTask: screenContextTask)
            return
        }

        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            let finalTranscript = await self.speechTranscriber.finishSession()
            // The user may have pressed the shortcut again, or Esc, while we waited.
            guard !Task.isCancelled, self.voiceState == .transcribing else { return }

            let wordCount = finalTranscript.split(whereSeparator: \.isWhitespace).count
            TikoLog.write("held \(Self.milliseconds(in: heldDuration)) ms · heard \(wordCount) words")

            if let activeTour = self.activeTour,
               finalTranscript.isEmpty || TourCommand.isNextStepRequest(finalTranscript) {
                self.continueTour(activeTour, screenContextTask: screenContextTask)
                return
            }

            guard !finalTranscript.isEmpty else {
                self.voiceState = .idle
                self.showBuddyMessage("kuch sunai nahi diya, phir se bolo", for: .seconds(2.5))
                return
            }
            self.lastTranscript = finalTranscript
            // Any real new question ends a tour that was in progress.
            self.activeTour = nil
            self.answer(question: finalTranscript, screenContextTask: screenContextTask, continuingTour: nil)
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

    private func continueTour(_ tour: GuidedTour, screenContextTask: Task<ScreenContext?, Never>?) {
        answer(
            question: CompanionPrompt.nextTourStepRequest(for: tour),
            screenContextTask: screenContextTask,
            continuingTour: tour
        )
    }

    /// - Parameters:
    ///   - question: What Gemini is asked — the user's words, or a next-step request during a tour.
    ///   - continuingTour: The tour this answer is the next step of, if any.
    private func answer(question: String, screenContextTask: Task<ScreenContext?, Never>?, continuingTour: GuidedTour?) {
        replyTask?.cancel()
        voiceState = .thinking

        replyTask = Task { [weak self] in
            guard let self else { return }
            do {
                let screenContext = await screenContextTask?.value
                TikoLog.write("asking gemini · screens \(screenContext?.screens.count ?? 0) · close-up \(screenContext?.cursorCloseUp != nil) · history \(self.conversationHistory.count)\(continuingTour.map { " · tour step \($0.nextStepNumber)" } ?? "")")
                let requestStartTime = ContinuousClock.now
                let reply = try await self.fetchReply(to: question, screenContext: screenContext)
                guard !Task.isCancelled else { return }

                let (textWithoutTourTag, hasMoreSteps) = TourTag.strip(reply.text)
                let parsedReply = PointTag.parse(textWithoutTourTag)
                TikoLog.write("reply from \(reply.modelName) in \(Self.milliseconds(since: requestStartTime)) ms · point \(parsedReply.normalizedPoint != nil ? (parsedReply.elementLabel ?? "unlabelled") : "none") · more steps \(hasMoreSteps)")

                // A reply with more steps starts or continues a tour; one without ends it.
                let isTourStep = hasMoreSteps || continuingTour != nil
                let replyText = isTourStep
                    ? parsedReply.displayText
                    : TourTag.removingLeadingStepNumber(parsedReply.displayText)
                let displayText = replyText.isEmpty ? "yahan dekho" : replyText
                let tourGoal = continuingTour?.goal ?? question

                self.rememberExchange(ConversationExchange(
                    userText: continuingTour == nil ? question : Self.nextStepHistoryText,
                    tikoReply: displayText
                ))
                self.recordInHistory(question: continuingTour == nil ? question : "\(tourGoal) · next step", reply: displayText)
                self.lastReply = GeminiReply(text: displayText, modelName: reply.modelName)
                self.lastPointingTarget = nil
                self.voiceState = .idle

                let stepNumber = continuingTour?.nextStepNumber ?? 1
                self.activeTour = hasMoreSteps
                    ? GuidedTour(goal: tourGoal, shownSteps: (continuingTour?.shownSteps ?? []) + [displayText])
                    : nil

                // The step hint is shown under the reply but never spoken.
                let tourHint = hasMoreSteps
                    ? "step \(stepNumber) · agle step ke liye \(self.preferences.pushToTalkShortcut.symbols) tap karo"
                    : "step \(stepNumber) · bas, ho gaya"
                let bubbleText = isTourStep ? "\(displayText)\n\(tourHint)" : displayText

                // Show the words and start speaking right away; the buddy flies over
                // once the point is double-checked. The bubble stays until both are done.
                let replyMessage = BuddyMessage(text: bubbleText, isReply: true)
                self.showBuddyMessage(replyMessage, for: nil)
                let replyShownTime = ContinuousClock.now
                let speakingTask: Task<Void, Never>? = self.isSpeakingRepliesEnabled
                    ? Task { await self.buddyVoice.speak(displayText) }
                    : nil

                if let screenContext,
                   let resolvedTarget = await self.resolvePointingTarget(for: parsedReply, question: tourGoal, screenContext: screenContext) {
                    // The user may have asked something new, or pressed Esc, meanwhile.
                    guard !Task.isCancelled, self.buddyMessage == replyMessage else { return }
                    self.pointingTarget = resolvedTarget
                    self.lastPointingTarget = resolvedTarget
                }

                await speakingTask?.value
                guard !Task.isCancelled, self.buddyMessage == replyMessage else { return }

                if hasMoreSteps {
                    // Wait on this step while the user does it; give up quietly after a while.
                    self.scheduleBuddyMessageDismissal(after: Self.tourStepPatience, endingTour: true)
                } else {
                    // Keep the reply up for at least its reading time, and linger a moment
                    // after the last word — longer when the buddy has only just landed.
                    let remainingReadingTime = Self.readingDuration(for: displayText) - (ContinuousClock.now - replyShownTime)
                    let lingerTime: Duration = self.pointingTarget != nil ? .seconds(3) : .seconds(1.5)
                    self.scheduleBuddyMessageDismissal(after: max(remainingReadingTime, lingerTime))
                }
            } catch {
                // A cancelled request means the user asked something new or pressed Esc; stay quiet.
                guard !Task.isCancelled, !Self.isCancellation(error) else { return }
                TikoLog.write("answer failed: \(error.localizedDescription)")
                self.voiceState = .idle
                self.showBuddyMessage(error.localizedDescription)
            }
        }
    }

    private func fetchReply(to question: String, screenContext: ScreenContext?) async throws -> GeminiReply {
        guard case .ready(let modelNames) = geminiKeyStatus, !settings.geminiAPIKey.isEmpty else {
            throw GeminiClientError.missingAPIKey
        }

        let geminiClient = GeminiClient(apiKey: settings.geminiAPIKey, modelNames: modelNames)
        return try await geminiClient.generateReply(
            systemInstruction: CompanionPrompt.systemInstruction(canSeeScreen: screenContext != nil),
            history: conversationHistory,
            images: screenContext?.geminiImages ?? [],
            userText: question
        )
    }

    /// Captures the screen and records how that went, since a failed capture
    /// otherwise just looks like Tiko ignoring the screen.
    private static func captureScreenContextLogged() async -> ScreenContext? {
        let captureStartTime = ContinuousClock.now
        do {
            let screenContext = try await ScreenCaptureService.captureScreenContext()
            TikoLog.write("captured \(screenContext.screens.count) screen(s) in \(milliseconds(since: captureStartTime)) ms")
            return screenContext
        } catch {
            TikoLog.write("screen capture failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Pointing

    /// Turns the reply's point tag into a spot on a real screen, double-checked on a close-up.
    private func resolvePointingTarget(for parsedReply: PointTagParseResult, question: String, screenContext: ScreenContext) async -> PointingTarget? {
        guard let normalizedPoint = parsedReply.normalizedPoint, let cursorScreen = screenContext.screens.first else {
            return nil
        }

        // No screen number, or one that doesn't exist, means the cursor's screen.
        let requestedScreenIndex = (parsedReply.screenNumber ?? 1) - 1
        let targetScreen = screenContext.screens.indices.contains(requestedScreenIndex)
            ? screenContext.screens[requestedScreenIndex]
            : cursorScreen

        let wholeDisplay = CGRect(origin: .zero, size: targetScreen.displayFrame.size)
        let firstGuessInDisplay = ScreenCoordinates.point(fromNormalized: normalizedPoint, in: wholeDisplay)
        let elementLabel = parsedReply.elementLabel ?? "yahan"

        let zoomCheckStartTime = ContinuousClock.now
        let zoomCheckedPointInDisplay = await zoomCheckPoint(
            firstGuessInDisplay,
            on: targetScreen,
            elementLabel: elementLabel,
            question: question
        )
        if let zoomCheckedPointInDisplay {
            let distanceMoved = Int(hypot(zoomCheckedPointInDisplay.x - firstGuessInDisplay.x, zoomCheckedPointInDisplay.y - firstGuessInDisplay.y))
            TikoLog.write("zoom check moved the point \(distanceMoved) pt in \(Self.milliseconds(since: zoomCheckStartTime)) ms")
        } else {
            TikoLog.write("zoom check kept the first guess after \(Self.milliseconds(since: zoomCheckStartTime)) ms")
        }
        let finalPointInDisplay = zoomCheckedPointInDisplay ?? firstGuessInDisplay

        return PointingTarget(
            location: ScreenCoordinates.appKitGlobalPoint(fromDisplayPoint: finalPointInDisplay, displayFrame: targetScreen.displayFrame),
            displayFrame: targetScreen.displayFrame,
            elementLabel: elementLabel,
            wasZoomChecked: zoomCheckedPointInDisplay != nil
        )
    }

    /// The full screenshot Gemini saw was scaled down, so its first guess can be
    /// a little off. Capture a sharp close-up around the guess and ask again.
    /// Returns nil if the check doesn't finish in time or can't find the element.
    private func zoomCheckPoint(_ firstGuessInDisplay: CGPoint, on targetScreen: CapturedScreen, elementLabel: String, question: String) async -> CGPoint? {
        guard case .ready(let modelNames) = geminiKeyStatus else { return nil }

        let regionRect = CloseUpRegion.captureRect(
            centeredOn: firstGuessInDisplay,
            displaySize: targetScreen.displayFrame.size,
            regionSize: Self.pointRefinementRegionSize
        )
        let geminiClient = GeminiClient(apiKey: settings.geminiAPIKey, modelNames: modelNames)
        let displayID = targetScreen.displayID

        return await Self.firstResult(within: Self.pointRefinementTimeLimit) {
            guard let regionJPEG = try? await ScreenCaptureService.captureRegion(displayID: displayID, rectInDisplay: regionRect) else {
                return nil
            }
            return await PointRefiner.refinePoint(
                elementLabel: elementLabel,
                userQuestion: question,
                regionRect: regionRect,
                regionJPEG: regionJPEG,
                geminiClient: geminiClient
            )
        }
    }

    /// Runs `operation`, but gives up with nil once `timeLimit` passes.
    private static func firstResult<Value: Sendable>(
        within timeLimit: Duration,
        operation: @escaping @Sendable () async -> Value?
    ) async -> Value? {
        await withTaskGroup(of: Value?.self) { taskGroup in
            taskGroup.addTask {
                await operation()
            }
            taskGroup.addTask {
                try? await Task.sleep(for: timeLimit)
                return nil
            }
            let firstFinishedResult = await taskGroup.next() ?? nil
            taskGroup.cancelAll()
            return firstFinishedResult
        }
    }

    // MARK: - Helpers

    private func rememberExchange(_ exchange: ConversationExchange) {
        conversationHistory.append(exchange)
        // Only recent context helps; an ever-growing history just slows every request.
        if conversationHistory.count > Self.maximumRememberedExchanges {
            conversationHistory.removeFirst(conversationHistory.count - Self.maximumRememberedExchanges)
        }
    }

    private func recordInHistory(question: String, reply: String) {
        conversationLog.append(ConversationLogEntry(question: question, reply: reply))
        // History is a convenience; failing to save it shouldn't interrupt the answer.
        try? conversationLog.save()
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

    private static func milliseconds(in duration: Duration) -> Int {
        Int(duration.components.seconds * 1000) + Int(duration.components.attoseconds / 1_000_000_000_000_000)
    }

    private static func milliseconds(since startTime: ContinuousClock.Instant) -> Int {
        milliseconds(in: ContinuousClock.now - startTime)
    }

    private static func describe(_ permissionSnapshot: PermissionSnapshot) -> String {
        PermissionKind.allCases
            .map { permissionKind in "\(permissionKind.title.lowercased()) \(permissionSnapshot.isGranted(permissionKind) ? "yes" : "no")" }
            .joined(separator: ", ")
    }

    private var keyStatusDescription: String {
        switch geminiKeyStatus {
        case .missing: return "missing"
        case .checking: return "checking"
        case .ready(let modelNames): return "ready (\(modelNames.first ?? "no model"))"
        case .failed: return "failed"
        }
    }

    // MARK: - Buddy

    private func showBuddyMessage(_ text: String, for displayDuration: Duration = .seconds(4)) {
        showBuddyMessage(BuddyMessage(text: text, isReply: false), for: displayDuration)
    }

    /// - Parameter displayDuration: nil keeps the message up until a dismissal is scheduled.
    private func showBuddyMessage(_ message: BuddyMessage, for displayDuration: Duration?) {
        buddyMessage = message
        applyBuddyVisibility()

        buddyMessageDismissTask?.cancel()
        buddyMessageDismissTask = nil
        if let displayDuration {
            scheduleBuddyMessageDismissal(after: displayDuration)
        }
    }

    /// - Parameter endingTour: Also ends the guided tour when the time runs out.
    ///   Pressing the shortcut cancels this, so asking for the next step keeps the tour going.
    private func scheduleBuddyMessageDismissal(after displayDuration: Duration, endingTour: Bool = false) {
        buddyMessageDismissTask?.cancel()
        buddyMessageDismissTask = Task { [weak self] in
            try? await Task.sleep(for: displayDuration)
            guard !Task.isCancelled else { return }
            if endingTour {
                TikoLog.write("tour ended: no next step within a minute")
                self?.activeTour = nil
            }
            self?.clearBuddyMessage()
        }
    }

    /// Hides the bubble, and sends the buddy home if it was pointing to go with it.
    private func clearBuddyMessage() {
        buddyMessageDismissTask?.cancel()
        buddyMessageDismissTask = nil
        if pointingTarget != nil {
            pointingTarget = nil
        }
        guard buddyMessage != nil else { return }
        buddyMessage = nil
        applyBuddyVisibility()
    }

    private func applyBuddyVisibility() {
        // Even with the buddy switched off, it appears while the user is talking
        // to Tiko, Tiko has something to say, or it's pointing at something.
        let shouldShowOverlay = isBuddyVisible || voiceState != .idle || buddyMessage != nil || pointingTarget != nil
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
