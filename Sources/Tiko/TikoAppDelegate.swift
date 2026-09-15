import AppKit

@MainActor
final class TikoAppDelegate: NSObject, NSApplicationDelegate {
    /// Held for the life of the app — if it were released, the menu bar icon
    /// would disappear with it.
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
    }
}
