import AppKit
import SwiftUI

/// Owns the menu bar icon and the panel that drops down from it.
@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panelPopover = NSPopover()

    override init() {
        super.init()
        configureMenuBarButton()
        configurePanelPopover()
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
        let panelHostingController = NSHostingController(rootView: CompanionPanelView())
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
            // An accessory app is never frontmost on its own. Activating it lets
            // the panel's controls take keyboard input (the API key field, later).
            NSApp.activate()
            panelPopover.show(relativeTo: menuBarButton.bounds, of: menuBarButton, preferredEdge: .minY)
        }
    }
}
