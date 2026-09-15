import AVFoundation

/// A voice the user can choose in Settings.
public struct SpeechVoiceOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let language: String
    public let qualityName: String
}

/// Chooses which of the Mac's built-in voices reads Tiko's replies.
public enum SpeechVoicePicker {
    /// Indian English reads Hinglish written in Roman letters far more naturally
    /// than US English does, so it's tried first.
    public static let automaticVoiceLanguages = ["en-IN", "en-US"]

    /// The languages whose voices are offered in Settings.
    public static let offeredVoiceLanguages = ["en-IN", "en-US", "en-GB", "hi-IN"]

    /// Within a language the highest-quality installed voice wins — enhanced and
    /// premium voices are free downloads in System Settings. Novelty and
    /// personal voices are never used.
    public static func bestVoice(preferredLanguages: [String] = SpeechVoicePicker.automaticVoiceLanguages) -> AVSpeechSynthesisVoice? {
        for language in preferredLanguages {
            if let bestVoice = rankedVoices(for: language).first {
                return bestVoice
            }
        }
        return AVSpeechSynthesisVoice(language: nil)
    }

    /// The voice the user picked, or the best installed one when they chose
    /// "Automatic" or the picked voice has since been removed from the Mac.
    public static func voice(withIdentifier voiceIdentifier: String?) -> AVSpeechSynthesisVoice? {
        if let voiceIdentifier, let chosenVoice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            return chosenVoice
        }
        return bestVoice()
    }

    public static func voiceOptions(languages: [String] = SpeechVoicePicker.offeredVoiceLanguages) -> [SpeechVoiceOption] {
        languages.flatMap { language in rankedVoices(for: language) }.map { voice in
            SpeechVoiceOption(id: voice.identifier, name: voice.name, language: voice.language, qualityName: qualityName(of: voice))
        }
    }

    public static func qualityName(of voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: return "premium"
        case .enhanced: return "enhanced"
        default: return "basic"
        }
    }

    /// Best quality first, then by name, so the same Mac always gets the same order.
    private static func rankedVoices(for language: String) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { voice in
                voice.language == language
                    && !voice.voiceTraits.contains(.isNoveltyVoice)
                    && !voice.voiceTraits.contains(.isPersonalVoice)
            }
            .sorted { firstVoice, secondVoice in
                if firstVoice.quality != secondVoice.quality {
                    return firstVoice.quality.rawValue > secondVoice.quality.rawValue
                }
                return firstVoice.name < secondVoice.name
            }
    }
}
