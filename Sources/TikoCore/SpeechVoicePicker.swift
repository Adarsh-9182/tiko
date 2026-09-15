import AVFoundation

/// Chooses which of the Mac's built-in voices reads Tiko's replies.
public enum SpeechVoicePicker {
    /// Indian English reads Hinglish written in Roman letters far more naturally
    /// than US English does, so it's tried first. Within a language the
    /// highest-quality installed voice wins — enhanced and premium voices are
    /// free downloads in System Settings. Novelty and personal voices are never used.
    public static func bestVoice(preferredLanguages: [String] = ["en-IN", "en-US"]) -> AVSpeechSynthesisVoice? {
        let usableVoices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            !voice.voiceTraits.contains(.isNoveltyVoice) && !voice.voiceTraits.contains(.isPersonalVoice)
        }

        for language in preferredLanguages {
            let voicesForLanguage = usableVoices
                .filter { voice in voice.language == language }
                // Sorted by quality, then name, so the same Mac always gets the same voice.
                .sorted { firstVoice, secondVoice in
                    if firstVoice.quality != secondVoice.quality {
                        return firstVoice.quality.rawValue > secondVoice.quality.rawValue
                    }
                    return firstVoice.name < secondVoice.name
                }
            if let bestVoice = voicesForLanguage.first {
                return bestVoice
            }
        }

        return AVSpeechSynthesisVoice(language: nil)
    }
}
