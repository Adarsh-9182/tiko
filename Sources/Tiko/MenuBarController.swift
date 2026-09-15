import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted when the user starts talking to Tiko, so the panel gets out of the way.
    static let tikoDismissPanel = Notification.Name("tikoDismissPanel")
    /// Posted to open the Settings window.
    static let tikoOpenSettings = Notification.Name("tikoOpenSettings")
}

/// Owns the menu bar icon, the panel that drops down from it, and the Settings window.
@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panelPopover = NSPopover()
    private let companionManager: CompanionManager
    private let settingsWindowController: SettingsWindowController

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        self.settingsWindowController = SettingsWindowController(companionManager: companionManager)
        super.init()
        configureMenuBarButton()
        configurePanelPopover()
        NotificationCenter.default.addObserver(self, selector: #selector(closePanel), name: .tikoDismissPanel, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings), name: .tikoOpenSettings, object: nil)
    }

    private func configureMenuBarButton() {
        guard let menuBarButton = statusItem.button else { return }
        let menuBarIcon = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Tiko")
        // A template image is recoloured by macOS, so the icon stays readable
        // on both light and dark menu bars.
        menuBarIcon?.isTemplate = true
        menuBarButton.image = menuBarIcon
        menuBarButton.target = self
        menuBarButton.action = #selector(togglePanel(_:))
    }

    private func configurePanelPopover() {
        let panelHostingController = NSHostingController(rootView: CompanionPanelView(
            companionManager: companionManager,
            preferences: companionManager.preferences
        ))
        // Let the SwiftUI view decide the panel's size instead of hardcoding it here.
        panelHostingController.sizingOptions = .preferredContentSize
        panelPopover.contentViewController = panelHostingController
        // `.transient` closes the panel on any click outside it, like a real menu.
        panelPopover.behavior = .transient
        panelPopover.animates = true
    }

    @objc private func togglePanel(_ sender: Any?) {
        guard let menuBarButton = statusItem.button else { return }

        if panelPopover.isShown {
            panelPopover.performClose(sender)
        } else {
            // Check right away so the panel never opens showing stale permissions.
            companionManager.refreshPermissions()
            // An accessory app is never frontmost on its own. Activating it lets
            // the panel's controls take keyboard input (the API key field).
            NSApp.activate()
            panelPopover.show(relativeTo: menuBarButton.bounds, of: menuBarButton, preferredEdge: .minY)
        }
    }

    @objc private func closePanel() {
        guard panelPopover.isShown else { return }
        panelPopover.performClose(nil)
    }

    @objc private func openSettings() {
        closePanel()
        settingsWindowController.showSettingsWindow()
    }
}
