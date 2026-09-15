import Foundation

/// The language the user speaks to Tiko in.
public enum SpeechLanguage: String, CaseIterable, Identifiable, Sendable {
    /// Copes with Hinglish far better than US English, so it's the default.
    case indianEnglish = "en-IN"
    case usEnglish = "en-US"
    case hindi = "hi-IN"

    public var id: String { rawValue }

    public var localeIdentifier: String { rawValue }

    public var displayName: String {
        switch self {
        case .indianEnglish: return "Hinglish / Indian English"
        case .usEnglish: return "English (US)"
        case .hindi: return "Hindi"
        }
    }
}
