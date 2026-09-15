import Foundation

/// Tiko's saved Gemini settings. The key lives in the keychain; the small JSON
/// file in Application Support holds only the model choices.
public struct TikoSettings: Codable, Equatable, Sendable {
    /// Kept in memory while Tiko runs, but never written to the settings file.
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
    // older version of Tiko still loads — including one that still has the key.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        geminiAPIKey = try container.decodeIfPresent(String.self, forKey: .geminiAPIKey) ?? ""
        geminiModelNames = try container.decodeIfPresent([String].self, forKey: .geminiModelNames) ?? []
        availableModelNames = try container.decodeIfPresent([String].self, forKey: .availableModelNames) ?? []
        chosenModelName = try container.decodeIfPresent(String.self, forKey: .chosenModelName)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(geminiModelNames, forKey: .geminiModelNames)
        try container.encode(availableModelNames, forKey: .availableModelNames)
        try container.encodeIfPresent(chosenModelName, forKey: .chosenModelName)
    }

    /// The models to try for a question, best first.
    public var modelNamesToTry: [String] {
        GeminiModelPicker.modelsToTry(chosenModelName: chosenModelName, automaticModelNames: geminiModelNames)
    }

    /// For the command-line tools, which can't read Tiko's keychain item
    /// without macOS asking: the `GEMINI_API_KEY` environment variable, or a
    /// key still in a settings file from Tiko 0.1.
    public var resolvedGeminiAPIKey: String {
        let environmentAPIKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return environmentAPIKey.isEmpty ? geminiAPIKey : environmentAPIKey
    }

    public static var defaultFileURL: URL {
        PrivateFile.tikoFolderURL.appendingPathComponent("settings.json")
    }

    /// Reads only the file. The app uses `loadMovingKeyToKeychain` instead.
    public static func load(from fileURL: URL = TikoSettings.defaultFileURL) -> TikoSettings {
        guard let settingsData = try? Data(contentsOf: fileURL),
              let loadedSettings = try? JSONDecoder().decode(TikoSettings.self, from: settingsData) else {
            return TikoSettings()
        }
        return loadedSettings
    }

    /// Writes the model choices. The key is never part of the file.
    public func save(to fileURL: URL = TikoSettings.defaultFileURL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try PrivateFile.write(try encoder.encode(self), to: fileURL)
    }

    // MARK: - Keychain

    public enum KeyMigration: Equatable, Sendable {
        /// The file had no key, so the key (if any) came from the keychain.
        case notNeeded
        /// A key from Tiko 0.1's settings file is now in the keychain, and gone from the file.
        case movedToKeychain
        /// The keychain refused; the key stays in the file for now, and is tried again next launch.
        case failed(message: String)
    }

    /// Loads the settings with the key from the keychain. A key left in the
    /// file by Tiko 0.1 is moved into the keychain, and only removed from the
    /// file once the keychain hands the same key back.
    public static func loadMovingKeyToKeychain(
        from fileURL: URL = TikoSettings.defaultFileURL,
        keyStore: KeychainPasswordStore = .geminiAPIKey
    ) -> (settings: TikoSettings, keyMigration: KeyMigration) {
        var loadedSettings = load(from: fileURL)
        let keyLeftInFile = loadedSettings.geminiAPIKey

        guard !keyLeftInFile.isEmpty else {
            loadedSettings.geminiAPIKey = keyStore.load() ?? ""
            return (loadedSettings, .notNeeded)
        }

        do {
            try keyStore.save(keyLeftInFile)
            guard keyStore.load() == keyLeftInFile else {
                return (loadedSettings, .failed(message: "the keychain didn't return the saved key"))
            }
            try loadedSettings.save(to: fileURL)
            return (loadedSettings, .movedToKeychain)
        } catch {
            return (loadedSettings, .failed(message: error.localizedDescription))
        }
    }

    /// Saves the key to the keychain (or removes it there when empty), then
    /// the model choices to the file. The keychain goes first, so a refusal
    /// never leaves Tiko with the key in neither place.
    public func saveIncludingKey(
        to fileURL: URL = TikoSettings.defaultFileURL,
        keyStore: KeychainPasswordStore = .geminiAPIKey
    ) throws {
        if geminiAPIKey.isEmpty {
            try keyStore.delete()
        } else {
            try keyStore.save(geminiAPIKey)
        }
        try save(to: fileURL)
    }
}
