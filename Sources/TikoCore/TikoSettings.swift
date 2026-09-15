import Foundation

/// Tiko's saved Gemini settings. Stored as a small JSON file in Application
/// Support that only the current user can read, because it holds an API key.
public struct TikoSettings: Codable, Equatable, Sendable {
    public var geminiAPIKey: String
    /// Picked automatically from the models the key can reach, fastest first.
    /// Refreshed whenever the key is saved.
    public var geminiModelNames: [String]
    /// Every model the key can ask questions of, for the model picker in Settings.
    public var availableModelNames: [String]
    /// A model the user picked in Settings; nil means automatic.
    public var chosenModelName: String?

    public init(
        geminiAPIKey: String = "",
        geminiModelNames: [String] = [],
        availableModelNames: [String] = [],
        chosenModelName: String? = nil
    ) {
        self.geminiAPIKey = geminiAPIKey
        self.geminiModelNames = geminiModelNames
        self.availableModelNames = availableModelNames
        self.chosenModelName = chosenModelName
    }

    private enum CodingKeys: String, CodingKey {
        case geminiAPIKey
        case geminiModelNames
        case availableModelNames
        case chosenModelName
    }

    // Missing fields fall back to defaults, so a settings file written by an
    // older version of Tiko still loads.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        geminiAPIKey = try container.decodeIfPresent(String.self, forKey: .geminiAPIKey) ?? ""
        geminiModelNames = try container.decodeIfPresent([String].self, forKey: .geminiModelNames) ?? []
        availableModelNames = try container.decodeIfPresent([String].self, forKey: .availableModelNames) ?? []
        chosenModelName = try container.decodeIfPresent(String.self, forKey: .chosenModelName)
    }

    /// The models to try for a question, best first.
    public var modelNamesToTry: [String] {
        GeminiModelPicker.modelsToTry(chosenModelName: chosenModelName, automaticModelNames: geminiModelNames)
    }

    /// The `GEMINI_API_KEY` environment variable wins over the saved key, so
    /// `TikoCheck --live` can try a key without saving it.
    public var resolvedGeminiAPIKey: String {
        let environmentAPIKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return environmentAPIKey.isEmpty ? geminiAPIKey : environmentAPIKey
    }

    public static var defaultFileURL: URL {
        PrivateFile.tikoFolderURL.appendingPathComponent("settings.json")
    }

    public static func load(from fileURL: URL = TikoSettings.defaultFileURL) -> TikoSettings {
        guard let settingsData = try? Data(contentsOf: fileURL),
              let loadedSettings = try? JSONDecoder().decode(TikoSettings.self, from: settingsData) else {
            return TikoSettings()
        }
        return loadedSettings
    }

    public func save(to fileURL: URL = TikoSettings.defaultFileURL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try PrivateFile.write(try encoder.encode(self), to: fileURL)
    }
}
