import CoreGraphics
import Foundation
import TikoCore

enum PushToTalkShortcutTransition {
    /// The push-to-talk shortcut just became held.
    case pressed
    /// The user let go — they finished talking.
    case released
    /// Another key was pressed while holding the shortcut, so this was an
    /// ordinary keyboard shortcut rather than the user talking to Tiko.
    case cancelled
    /// Esc on its own: the user wants Tiko to stop.
    case escapePressed
}

/// Watches the keyboard, in any app, for the push-to-talk shortcut and for Esc.
///
/// Uses a listen-only CGEvent tap: it sees keyboard events system-wide (which
/// needs the Accessibility permission) but can never block or change them, so
/// Esc still reaches the app the user is in.
final class PushToTalkShortcutMonitor {
    /// Called on the main thread, because the tap is attached to the main run loop.
    var onTransition: ((PushToTalkShortcutTransition) -> Void)?

    /// Which keys count as push-to-talk. Changing it lets go of any hold in progress.
    var shortcut: PushToTalkShortcut = .controlOption {
        didSet {
            guard shortcut != oldValue, isShortcutHeld else { return }
            isShortcutHeld = false
            onTransition?(.cancelled)
        }
    }

    private(set) var isShortcutHeld = false
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?

    private static let escapeKeyCode: Int64 = 53

    var isRunning: Bool { eventTap != nil }

    /// Returns false when macOS refuses the tap, which almost always means the
    /// Accessibility permission is missing. Safe to call repeatedly.
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let eventMask = (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
            | (CGEventMask(1) << CGEventType.keyDown.rawValue)

        // A C callback can't capture Swift context, so the monitor travels
        // through the tap's userInfo pointer instead.
        let eventTapCallback: CGEventTapCallBack = { _, eventType, event, userInfo in
            if let userInfo {
                let shortcutMonitor = Unmanaged<PushToTalkShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                shortcutMonitor.handleEvent(eventType: eventType, event: event)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        guard let eventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.eventTap = eventTap
        self.eventTapRunLoopSource = eventTapRunLoopSource
        return true
    }

    func stop() {
        isShortcutHeld = false

        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
            self.eventTapRunLoopSource = nil
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    deinit {
        stop()
    }

    private func handleEvent(eventType: CGEventType, event: CGEvent) {
        switch eventType {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS switches a tap off if it ever responds too slowly; turn it straight back on.
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

        case .flagsChanged:
            let isShortcutHeldNow = shortcut.isHeld(modifierFlagsRawValue: event.flags.rawValue)
            if isShortcutHeldNow && !isShortcutHeld {
                isShortcutHeld = true
                onTransition?(.pressed)
            } else if !isShortcutHeldNow && isShortcutHeld {
                isShortcutHeld = false
                onTransition?(.released)
            }

        case .keyDown:
            if isShortcutHeld {
                // The shortcut plus another key is an ordinary keyboard shortcut
                // (⌃⌥→ to switch Spaces, or ⌥ + a letter to type an accent), not the
                // user talking to Tiko.
                isShortcutHeld = false
                onTransition?(.cancelled)
            } else if event.getIntegerValueField(.keyboardEventKeycode) == Self.escapeKeyCode {
                onTransition?(.escapePressed)
            }

        default:
            break
        }
    }
}
