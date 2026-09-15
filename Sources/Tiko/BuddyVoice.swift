import AVFoundation
import TikoCore

/// Reads Tiko's replies aloud with the Mac's built-in voices: free, offline,
/// and stoppable in an instant.
@MainActor
final class BuddyVoice: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false

    let voice: AVSpeechSynthesisVoice? = SpeechVoicePicker.bestVoice()

    private let speechSynthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    private var speechFinishedContinuation: CheckedContinuation<Void, Never>?

    /// Basic-quality voices sound robotic; the panel suggests a free download when that's all there is.
    var isUsingHighQualityVoice: Bool {
        guard let voice else { return false }
        return voice.quality != .default
    }

    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    /// Speaks the text and returns once it has finished or been stopped.
    func speak(_ text: String) async {
        stop()
        let spokenText = SpokenText.prepare(text)
        guard !spokenText.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: spokenText)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        currentUtterance = utterance
        isSpeaking = true

        await withCheckedContinuation { continuation in
            speechFinishedContinuation = continuation
            speechSynthesizer.speak(utterance)
        }
    }

    func stop() {
        guard currentUtterance != nil else { return }
        speechSynthesizer.stopSpeaking(at: .immediate)
        // Finish right away instead of waiting for the delegate, so stopping feels instant.
        finishCurrentUtterance()
    }

    fileprivate func utteranceEnded(_ endedUtteranceIdentifier: ObjectIdentifier) {
        // After stop() and a new speak(), the old utterance's callback can still
        // arrive; it must not end the new one.
        guard let currentUtterance, ObjectIdentifier(currentUtterance) == endedUtteranceIdentifier else { return }
        finishCurrentUtterance()
    }

    private func finishCurrentUtterance() {
        currentUtterance = nil
        isSpeaking = false
        speechFinishedContinuation?.resume()
        speechFinishedContinuation = nil
    }
}

extension BuddyVoice: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let endedUtteranceIdentifier = ObjectIdentifier(utterance)
        Task { @MainActor in
            self.utteranceEnded(endedUtteranceIdentifier)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let endedUtteranceIdentifier = ObjectIdentifier(utterance)
        Task { @MainActor in
            self.utteranceEnded(endedUtteranceIdentifier)
        }
    }
}
