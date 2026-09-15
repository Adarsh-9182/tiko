import AVFoundation
import Foundation
import TikoCore

enum SpeakingSpeed: String, CaseIterable, Identifiable {
    case relaxed
    case normal
    case quick

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .relaxed: return "Relaxed"
        case .normal: return "Normal"
        case .quick: return "Quick"
        }
    }

    var speechRate: Float {
        switch self {
        case .relaxed: return AVSpeechUtteranceDefaultSpeechRate * 0.85
        case .normal: return AVSpeechUtteranceDefaultSpeechRate
        case .quick: return min(AVSpeechUtteranceDefaultSpeechRate * 1.15, AVSpeechUtteranceMaximumSpeechRate)
        }
    }
}

/// The choices made in the Settings window, saved in UserDefaults. Changes
/// apply straight away; nothing needs a restart.
@MainActor
final class TikoPreferences: ObservableObject {
    @Published var pushToTalkShortcut: PushToTalkShortcut {
        didSet { UserDefaults.standard.set(pushToTalkShortcut.rawValue, forKey: Keys.pushToTalkShortcut) }
    }

    @Published var speechLanguage: SpeechLanguage {
        didSet { UserDefaults.standard.set(speechLanguage.rawValue, forKey: Keys.speechLanguage) }
    }

    /// nil lets Tiko pick the best installed voice.
    @Published var voiceIdentifier: String? {
        didSet {
            if let voiceIdentifier {
                UserDefaults.standard.set(voiceIdentifier, forKey: Keys.voiceIdentifier)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.voiceIdentifier)
            }
        }
    }

    @Published var speakingSpeed: SpeakingSpeed {
        didSet { UserDefaults.standard.set(speakingSpeed.rawValue, forKey: Keys.speakingSpeed) }
    }

    private enum Keys {
        static let pushToTalkShortcut = "pushToTalkShortcut"
        static let speechLanguage = "speechLanguage"
        static let voiceIdentifier = "voiceIdentifier"
        static let speakingSpeed = "speakingSpeed"
    }

    init() {
        let userDefaults = UserDefaults.standard
        pushToTalkShortcut = userDefaults.string(forKey: Keys.pushToTalkShortcut).flatMap(PushToTalkShortcut.init(rawValue:)) ?? .controlOption
        speechLanguage = userDefaults.string(forKey: Keys.speechLanguage).flatMap(SpeechLanguage.init(rawValue:)) ?? .indianEnglish
        voiceIdentifier = userDefaults.string(forKey: Keys.voiceIdentifier)
        speakingSpeed = userDefaults.string(forKey: Keys.speakingSpeed).flatMap(SpeakingSpeed.init(rawValue:)) ?? .normal
    }
}
