import Foundation
import ServiceManagement
import TikoCore

/// Whether Tiko opens by itself when the user logs in. A buddy that has to be
/// remembered and started each morning mostly doesn't get used.
@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status
    @Published private(set) var errorMessage: String?

    /// Also on while macOS waits for the user to allow it, so the switch doesn't flick back.
    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    var needsApproval: Bool {
        status == .requiresApproval
    }

    func setEnabled(_ shouldEnable: Bool) {
        errorMessage = nil
        do {
            if shouldEnable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = "macOS didn't allow that: \(error.localizedDescription)"
        }
        refresh()
        TikoLog.write("open at login \(shouldEnable ? "on" : "off") · \(statusDescription)\(errorMessage != nil ? " · failed" : "")")
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private var statusDescription: String {
        switch status {
        case .enabled: return "enabled"
        case .requiresApproval: return "waiting for approval"
        case .notRegistered: return "not registered"
        case .notFound: return "not found"
        @unknown default: return "unknown"
        }
    }
}
