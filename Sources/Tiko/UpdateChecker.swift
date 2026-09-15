import Foundation
import TikoCore

/// Asks GitHub once a day whether a newer Tiko has been released. The request
/// carries nothing about the user, and nothing is downloaded or installed —
/// the panel just offers the release page.
@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var availableUpdate: AvailableUpdate?

    @Published var isCheckingAutomatically = UserDefaults.standard.object(forKey: UpdateChecker.checkingDefaultsKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isCheckingAutomatically, forKey: Self.checkingDefaultsKey)
            if isCheckingAutomatically {
                start()
            } else {
                stop()
                availableUpdate = nil
            }
        }
    }

    private var checkingTask: Task<Void, Never>?

    private static let checkingDefaultsKey = "isCheckingForUpdates"
    private static let checkInterval: Duration = .seconds(24 * 60 * 60)

    /// The version in the app's Info.plist; "dev" outside an app bundle, which never gets offered updates.
    static var runningVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    func start() {
        guard isCheckingAutomatically, checkingTask == nil else { return }
        checkingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkNow()
                try? await Task.sleep(for: Self.checkInterval)
            }
        }
    }

    func stop() {
        checkingTask?.cancel()
        checkingTask = nil
    }

    private func checkNow() async {
        var request = URLRequest(url: AppUpdateCheck.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            // 404 means nothing has been published yet; there's simply no update.
            guard statusCode == 200 else {
                TikoLog.write("update check: status \(statusCode)")
                return
            }
            availableUpdate = AppUpdateCheck.availableUpdate(currentVersion: Self.runningVersion, latestReleaseData: responseData)
            TikoLog.write("update check: \(availableUpdate.map { "\($0.version) available" } ?? "up to date")")
        } catch {
            TikoLog.write("update check failed: \(error.localizedDescription)")
        }
    }
}
