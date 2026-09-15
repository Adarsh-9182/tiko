import AVFoundation
import Foundation
import Speech

enum SpeechTranscriberError: LocalizedError {
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "speech recognition abhi available nahi hai"
        }
    }
}

/// Hands audio from the microphone's real-time thread to a recognition request.
/// Apple's own sample code appends buffers straight from the audio tap, so no
/// extra locking is added here.
final class SpeechAudioSink: @unchecked Sendable {
    private let recognitionRequest: SFSpeechAudioBufferRecognitionRequest

    init(recognitionRequest: SFSpeechAudioBufferRecognitionRequest) {
        self.recognitionRequest = recognitionRequest
    }

    func append(_ audioBuffer: AVAudioPCMBuffer) {
        recognitionRequest.append(audioBuffer)
    }
}

/// Turns push-to-talk audio into text with Apple's speech recognizer — on this
/// Mac whenever the language's on-device model is available.
@MainActor
final class SpeechTranscriber: ObservableObject {
    /// What has been recognised so far in the current session, updated as the user talks.
    @Published private(set) var liveTranscript = ""

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    /// Changes with every session, so late callbacks from an abandoned session are ignored.
    private var currentSessionID = UUID()
    private var hasReceivedFinalResult = false

    /// The longest Tiko waits for the final text after the user lets go.
    private static let finalResultWaitLimit: Duration = .seconds(2)

    /// Starts a new recognition session and returns the sink the microphone should feed.
    func startSession(localeIdentifier: String) throws -> SpeechAudioSink {
        cancelSession()

        guard let speechRecognizer = Self.makeSpeechRecognizer(preferredLocaleIdentifier: localeIdentifier),
              speechRecognizer.isAvailable else {
            throw SpeechTranscriberError.recognizerUnavailable
        }

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        recognitionRequest.addsPunctuation = true
        // On-device keeps the user's voice on their Mac and has no usage limits.
        if speechRecognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        let sessionID = UUID()
        currentSessionID = sessionID
        liveTranscript = ""
        hasReceivedFinalResult = false
        self.recognitionRequest = recognitionRequest

        let resultHandler = Self.makeResultHandler { [weak self] transcriptText, isFinalResult, didFail in
            Task { @MainActor [weak self] in
                self?.handleRecognitionUpdate(
                    sessionID: sessionID,
                    transcriptText: transcriptText,
                    isFinalResult: isFinalResult,
                    didFail: didFail
                )
            }
        }
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest, resultHandler: resultHandler)

        return SpeechAudioSink(recognitionRequest: recognitionRequest)
    }

    /// Tells the recognizer the user has stopped talking, then returns the final
    /// text. Returns an empty string if nothing was heard or a newer session took over.
    func finishSession() async -> String {
        let sessionID = currentSessionID
        recognitionRequest?.endAudio()

        // The final result usually lands a fraction of a second after endAudio().
        // The wait is capped so a stuck recognizer can't leave the buddy spinning.
        let waitDeadline = ContinuousClock.now + Self.finalResultWaitLimit
        while sessionID == currentSessionID && !hasReceivedFinalResult && ContinuousClock.now < waitDeadline {
            try? await Task.sleep(for: .milliseconds(50))
        }

        guard sessionID == currentSessionID else { return "" }
        let finalTranscript = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        tearDownRecognition()
        return finalTranscript
    }

    func cancelSession() {
        currentSessionID = UUID()
        tearDownRecognition()
        liveTranscript = ""
    }

    private func tearDownRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    private func handleRecognitionUpdate(sessionID: UUID, transcriptText: String?, isFinalResult: Bool, didFail: Bool) {
        guard sessionID == currentSessionID else { return }
        if let transcriptText {
            liveTranscript = transcriptText
        }
        // An error also ends the session (for example "no speech detected"),
        // so stop waiting either way.
        if isFinalResult || didFail {
            hasReceivedFinalResult = true
        }
    }

    /// Indian English copes with Hinglish far better than US English; fall back
    /// to US English on Macs without it.
    private static func makeSpeechRecognizer(preferredLocaleIdentifier: String) -> SFSpeechRecognizer? {
        for localeIdentifier in [preferredLocaleIdentifier, "en-US"] {
            if let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) {
                return speechRecognizer
            }
        }
        return nil
    }

    /// Built outside the main actor and reduced to plain values, so the
    /// recognizer's result objects never cross threads.
    nonisolated private static func makeResultHandler(
        onUpdate: @escaping @Sendable (_ transcriptText: String?, _ isFinalResult: Bool, _ didFail: Bool) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        return { recognitionResult, recognitionError in
            onUpdate(
                recognitionResult?.bestTranscription.formattedString,
                recognitionResult?.isFinal ?? false,
                recognitionError != nil
            )
        }
    }
}
