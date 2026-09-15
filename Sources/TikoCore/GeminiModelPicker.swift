import Foundation

/// Chooses which of a key's Gemini models Tiko should use, best first.
public enum GeminiModelPicker {
    /// Words in model names that mark variants which can't answer a screenshot
    /// question in text: image generation, speech, live audio, embeddings, experiments.
    private static let unsuitableModelNameWords = ["image", "tts", "audio", "live", "embedding", "exp"]

    /// Fast "flash-lite" models come first, then "flash". On the free tier the
    /// lighter models rate-limit least and answer fastest, and a spoken reply
    /// needs speed more than depth. Moving "-latest" aliases come before pinned
    /// versions, and previews come last because their limits are lower.
    public static func preferredModelNames(from availableModelNames: [String], limit: Int = 3) -> [String] {
        let usableModelNames = availableModelNames.filter { modelName in
            modelName.hasPrefix("gemini")
                && modelName.contains("flash")
                && !unsuitableModelNameWords.contains { unsuitableWord in modelName.contains(unsuitableWord) }
        }

        let rankedModelNames = usableModelNames.sorted { firstModelName, secondModelName in
            let firstRank = preferenceRank(of: firstModelName)
            let secondRank = preferenceRank(of: secondModelName)
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

        return Array(rankedModelNames.prefix(limit))
    }

    /// Lower is better.
    private static func preferenceRank(of modelName: String) -> Int {
        let isLiteModel = modelName.contains("flash-lite")
        let isLatestAlias = modelName.hasSuffix("-latest")

        var rank: Int
        switch (isLiteModel, isLatestAlias) {
        case (true, true): rank = 0
        case (false, true): rank = 1
        case (true, false): rank = 2
        case (false, false): rank = 3
        }
        if modelName.contains("preview") {
            rank += 10
        }
        return rank
    }

    /// "gemini-3.7-flash" → 3.7. Aliases without a number count as 0.
    private static func versionNumber(of modelName: String) -> Double {
        let nameParts = modelName.split(separator: "-")
        guard nameParts.count > 1, let version = Double(nameParts[1]) else { return 0 }
        return version
    }
}
