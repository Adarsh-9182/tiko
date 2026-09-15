import Foundation

/// A version like "0.2.0", or a release tag like "v0.2.0", compared number by
/// number so 0.10.0 is newer than 0.9.1.
public struct AppVersion: Comparable, Sendable, CustomStringConvertible {
    public let numbers: [Int]

    /// nil for anything that isn't a dotted version, like "dev".
    public init?(_ text: String) {
        var versionText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if versionText.lowercased().hasPrefix("v") {
            versionText.removeFirst()
        }
        // "0.2.0-beta" compares as 0.2.0; GitHub's latest release is never a pre-release anyway.
        let coreVersionText = versionText.split(separator: "-", maxSplits: 1).first.map(String.init) ?? ""
        let parsedNumbers = coreVersionText.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parsedNumbers.isEmpty, parsedNumbers.allSatisfy({ $0 != nil }) else { return nil }
        numbers = parsedNumbers.compactMap { $0 }
    }

    public var description: String {
        numbers.map(String.init).joined(separator: ".")
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        for position in 0..<max(lhs.numbers.count, rhs.numbers.count) {
            let lhsNumber = lhs.number(at: position)
            let rhsNumber = rhs.number(at: position)
            if lhsNumber != rhsNumber {
                return lhsNumber < rhsNumber
            }
        }
        return false
    }

    /// A missing last part counts as zero, so 0.2 equals 0.2.0.
    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    private func number(at position: Int) -> Int {
        numbers.indices.contains(position) ? numbers[position] : 0
    }
}

/// A newer release the user can download.
public struct AvailableUpdate: Equatable, Sendable {
    public let version: AppVersion
    /// The release's page on GitHub, where the zip and its checksum are.
    public let pageURL: URL
}

public enum AppUpdateCheck {
    /// GitHub's public "latest release" endpoint. Drafts and pre-releases never appear here.
    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/Adarsh-9182/tiko/releases/latest")!

    private struct LatestRelease: Decodable {
        let tagName: String
        let pageAddress: String
        let isDraft: Bool?
        let isPrerelease: Bool?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case pageAddress = "html_url"
            case isDraft = "draft"
            case isPrerelease = "prerelease"
        }
    }

    /// Reads GitHub's answer. nil when the release isn't newer than the running
    /// version, isn't a finished release, or its page isn't on github.com.
    public static func availableUpdate(currentVersion: String, latestReleaseData: Data) -> AvailableUpdate? {
        guard let latestRelease = try? JSONDecoder().decode(LatestRelease.self, from: latestReleaseData),
              latestRelease.isDraft != true,
              latestRelease.isPrerelease != true,
              let releaseVersion = AppVersion(latestRelease.tagName),
              let runningVersion = AppVersion(currentVersion),
              releaseVersion > runningVersion,
              let pageURL = URL(string: latestRelease.pageAddress),
              pageURL.scheme == "https",
              pageURL.host == "github.com"
        else {
            return nil
        }
        return AvailableUpdate(version: releaseVersion, pageURL: pageURL)
    }
}
