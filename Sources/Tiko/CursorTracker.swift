import AppKit
import Combine

/// Publishes the mouse position that every buddy overlay follows.
///
/// Listens to mouse-move events instead of polling on a timer, so Tiko uses
/// no CPU while the mouse is still. Unlike key events, mouse events can be
/// monitored system-wide without any permission.
@MainActor
final class CursorTracker: ObservableObject {
    /// AppKit global coordinates: origin at the bottom-left of the main screen.
    @Published private(set) var mouseLocation = NSEvent.mouseLocation

    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    private static let mouseMovementEvents: NSEvent.EventTypeMask = [
        .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
    ]

    func start() {
        guard globalMouseMonitor == nil else { return }
        mouseLocation = NSEvent.mouseLocation

        // The global monitor only sees events sent to other apps; the local
        // one covers the moments Tiko's own panel is frontmost.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: Self.mouseMovementEvents) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.mouseLocation = NSEvent.mouseLocation
            }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: Self.mouseMovementEvents) { [weak self] event in
            MainActor.assumeIsolated {
                self?.mouseLocation = NSEvent.mouseLocation
            }
            return event
        }
    }

    func stop() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }
}
