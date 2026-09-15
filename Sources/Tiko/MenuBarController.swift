import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted when the user starts talking to Tiko, so the panel gets out of the way.
    static let tikoDismissPanel = Notification.Name("tikoDismissPanel")
}

/// Owns the menu bar icon and the panel that drops down from it.
@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panelPopover = NSPopover()
    private let companionManager: CompanionManager

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        super.init()
        configureMenuBarButton()
        configurePanelPopover()
        NotificationCenter.default.addObserver(self, selector: #selector(closePanel), name: .tikoDismissPanel, object: nil)
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
        let panelHostingController = NSHostingController(rootView: CompanionPanelView(companionManager: companionManager))
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
            // the panel's controls take keyboard input (the API key field, later).
            NSApp.activate()
            panelPopover.show(relativeTo: menuBarButton.bounds, of: menuBarButton, preferredEdge: .minY)
        }
    }

    @objc private func closePanel() {
        guard panelPopover.isShown else { return }
        panelPopover.performClose(nil)
    }
}
