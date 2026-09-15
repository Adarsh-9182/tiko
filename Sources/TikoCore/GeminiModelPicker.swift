import Foundation

/// Chooses which of a key's Gemini models Tiko uses.
public enum GeminiModelPicker {
    /// Words in model names that mark variants which can't answer a screenshot
    /// question in text: image generation, speech, live audio, embeddings, experiments.
    private static let unsuitableModelNameWords = ["image", "tts", "audio", "live", "embedding", "exp"]

    /// The automatic picks, best first. Fast "flash-lite" models come first,
    /// then "flash". On the free tier the lighter models rate-limit least and
    /// answer fastest, and a spoken reply needs speed more than depth. Moving
    /// "-latest" aliases come before pinned versions, and previews come last
    /// because their limits are lower.
    public static func preferredModelNames(from availableModelNames: [String], limit: Int = 3) -> [String] {
        let usableModelNames = availableModelNames.filter { modelName in
            isSuitable(modelName) && modelName.contains("flash")
        }
        return Array(sortedByPreference(usableModelNames, groupingByFamily: false).prefix(limit))
    }

    /// Every model worth offering in Settings: flash-lite, then flash, then pro.
    /// Pro answers better and is slower, with far lower free-tier limits — a
    /// choice worth making with a paid key, which is why it's never automatic.
    public static func choosableModelNames(from availableModelNames: [String]) -> [String] {
        let choosableModelNames = availableModelNames.filter { modelName in
            isSuitable(modelName) && (modelName.contains("flash") || modelName.contains("pro"))
        }
        return sortedByPreference(choosableModelNames, groupingByFamily: true)
    }

    /// The models to try for a question, best first: the one chosen in Settings
    /// when there is one, with the automatic picks behind it in case it's busy.
    public static func modelsToTry(chosenModelName: String?, automaticModelNames: [String]) -> [String] {
        guard let chosenModelName, !chosenModelName.isEmpty else { return automaticModelNames }
        return [chosenModelName] + automaticModelNames.filter { modelName in modelName != chosenModelName }
    }

    // MARK: - Ordering

    private static func isSuitable(_ modelName: String) -> Bool {
        modelName.hasPrefix("gemini")
            && !unsuitableModelNameWords.contains { unsuitableWord in modelName.contains(unsuitableWord) }
    }

    private static func sortedByPreference(_ modelNames: [String], groupingByFamily: Bool) -> [String] {
        modelNames.sorted { firstModelName, secondModelName in
            let firstRank = preferenceRank(of: firstModelName, groupingByFamily: groupingByFamily)
            let secondRank = preferenceRank(of: secondModelName, groupingByFamily: groupingByFamily)
            if firstRank != secondRank {
                return firstRank < secondRank
            }
            let firstVersion = versionNumber(of: firstModelName)
            let secondVersion = versionNumber(of: secondModelName)
            if firstVersion != secondVersion {
                return firstVersion > secondVersion
            }
            return firstModelName < secondModelName
        }
    }

    /// Lower is better. Moving "-latest" aliases come before pinned versions
    /// and lite before flash before pro; previews always sort last within
    /// their group.
    /// - Parameter groupingByFamily: Keep each family together (all lite, then
    ///   all flash), as the Settings list reads best. The automatic picks
    ///   instead take every "-latest" alias before any pinned version, so a
    ///   busy lite model falls back to the current flash, not an older lite.
    private static func preferenceRank(of modelName: String, groupingByFamily: Bool) -> Int {
        let familyRank: Int
        if modelName.contains("flash-lite") {
            familyRank = 0
        } else if modelName.contains("flash") {
            familyRank = 1
        } else {
            familyRank = 2
        }
        let pinnedRank = modelName.hasSuffix("-latest") ? 0 : 1
        let previewRank = modelName.contains("preview") ? 1 : 0

        if groupingByFamily {
            return familyRank * 10 + pinnedRank * 2 + previewRank * 5
        }
        return pinnedRank * 3 + familyRank + previewRank * 10
    }

    /// "gemini-3.7-flash" → 3.7. Aliases without a number count as 0.
    private static func versionNumber(of modelName: String) -> Double {
        let nameParts = modelName.split(separator: "-")
        guard nameParts.count > 1, let version = Double(nameParts[1]) else { return 0 }
        return version
    }
}
