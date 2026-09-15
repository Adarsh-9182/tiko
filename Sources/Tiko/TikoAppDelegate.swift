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
    }
}
