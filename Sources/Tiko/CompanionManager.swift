import AppKit
import Combine

/// Tiko's central state. For now it tracks permissions; later phases add the
/// voice pipeline, the cursor buddy and pointing.
@MainActor
final class CompanionManager: ObservableObject {
    @Published private(set) var permissions = PermissionSnapshot()
    /// Published separately because asking for Screen Recording doesn't change
    /// the snapshot until a restart, yet the panel should offer that restart.
    @Published private(set) var hasRequestedScreenRecording = PermissionsCenter.hasRequestedBefore(.screenRecording)

    private var permissionPollingTask: Task<Void, Never>?

    func start() {
        // macOS doesn't tell an app when the user flips a switch in System
        // Settings, so poll. It's cheap, and the panel updates within a moment.
        permissionPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshPermissions()
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    func refreshPermissions() {
        let latestSnapshot = PermissionsCenter.currentSnapshot()
        // Only publish real changes so the panel doesn't redraw every poll.
        if latestSnapshot != permissions {
            permissions = latestSnapshot
        }
    }

    func requestPermission(_ permissionKind: PermissionKind) {
        PermissionsCenter.request(permissionKind)
        hasRequestedScreenRecording = PermissionsCenter.hasRequestedBefore(.screenRecording)
        refreshPermissions()
    }

    /// Starts a fresh copy of Tiko and quits this one. Needed after granting
    /// Screen Recording, which macOS only applies to a newly launched app.
    func relaunch() {
        let openConfiguration = NSWorkspace.OpenConfiguration()
        openConfiguration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: openConfiguration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
