import AppKit

@MainActor
final class TikoAppDelegate: NSObject, NSApplicationDelegate {
    private let companionManager = CompanionManager()
    /// Held for the life of the app — if it were released, the menu bar icon
    /// would disappear with it.
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        companionManager.start()
        menuBarController = MenuBarController(companionManager: companionManager)

        // A menu bar app has no window to show on first launch, so a new user sees
        // only an arrow by their cursor. Until permissions and the key are in place,
        // open the panel that sets them up.
        if !companionManager.isSetUpComplete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NotificationCenter.default.post(name: .tikoShowPanel, object: nil)
            }
        }

        // Launch arguments for checking a build without clicking around:
        //   open build/Tiko.app --args -TikoOpenSettingsOnLaunch YES
        //   open build/Tiko.app --args -TikoAskOnLaunch "wifi kahan hai?" -isSpeakingRepliesEnabled NO
        if UserDefaults.standard.bool(forKey: "TikoOpenSettingsOnLaunch") {
            NotificationCenter.default.post(name: .tikoOpenSettings, object: nil)
        }
        if let launchQuestion = UserDefaults.standard.string(forKey: "TikoAskOnLaunch"), !launchQuestion.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [companionManager] in
                companionManager.ask(launchQuestion)
            }
        }
    }
}
