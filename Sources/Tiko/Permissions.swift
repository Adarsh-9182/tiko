import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import Speech

/// The four macOS privacy permissions Tiko needs.
enum PermissionKind: CaseIterable, Identifiable {
    case accessibility
    case screenRecording
    case microphone
    case speechRecognition

    var id: Self { self }

    var title: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .screenRecording: return "Screen Recording"
        case .microphone: return "Microphone"
        case .speechRecognition: return "Speech Recognition"
        }
    }

    /// Why Tiko needs it, in the words the panel shows the user.
    var reason: String {
        switch self {
        case .accessibility: return "Hear the ⌃ Control + ⌥ Option shortcut in any app"
        case .screenRecording: return "See your screen when you ask something"
        case .microphone: return "Hear your question"
        case .speechRecognition: return "Turn your voice into text, on this Mac"
        }
    }

    /// The Privacy & Security pane in System Settings for this permission.
    var systemSettingsURL: URL {
        let privacyPaneAnchor: String
        switch self {
        case .accessibility: privacyPaneAnchor = "Privacy_Accessibility"
        case .screenRecording: privacyPaneAnchor = "Privacy_ScreenCapture"
        case .microphone: privacyPaneAnchor = "Privacy_Microphone"
        case .speechRecognition: privacyPaneAnchor = "Privacy_SpeechRecognition"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(privacyPaneAnchor)")!
    }
}

/// Which permissions are granted at one moment in time.
struct PermissionSnapshot: Equatable {
    var isAccessibilityGranted = false
    var isScreenRecordingGranted = false
    var isMicrophoneGranted = false
    var isSpeechRecognitionGranted = false

    func isGranted(_ permissionKind: PermissionKind) -> Bool {
        switch permissionKind {
        case .accessibility: return isAccessibilityGranted
        case .screenRecording: return isScreenRecordingGranted
        case .microphone: return isMicrophoneGranted
        case .speechRecognition: return isSpeechRecognitionGranted
        }
    }

    var areAllGranted: Bool {
        PermissionKind.allCases.allSatisfy { permissionKind in isGranted(permissionKind) }
    }
}

@MainActor
enum PermissionsCenter {
    static func currentSnapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            isAccessibilityGranted: AXIsProcessTrusted(),
            // Screen Recording reads as granted only after Tiko restarts — macOS
            // applies that permission at launch.
            isScreenRecordingGranted: CGPreflightScreenCaptureAccess(),
            isMicrophoneGranted: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
            isSpeechRecognitionGranted: SFSpeechRecognizer.authorizationStatus() == .authorized
        )
    }

    /// Asks for a permission. macOS shows its own prompt only once per app;
    /// after that the only way to change the answer is System Settings, so
    /// later requests open the right pane there instead.
    static func request(_ permissionKind: PermissionKind) {
        switch permissionKind {
        case .accessibility:
            guard !hasRequestedBefore(permissionKind) else {
                NSWorkspace.shared.open(permissionKind.systemSettingsURL)
                return
            }
            markRequested(permissionKind)
            // Shows the "Tiko would like to control this computer" dialog, which
            // has its own button into System Settings.
            let promptOptions = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(promptOptions)

        case .screenRecording:
            guard !hasRequestedBefore(permissionKind) else {
                NSWorkspace.shared.open(permissionKind.systemSettingsURL)
                return
            }
            markRequested(permissionKind)
            _ = CGRequestScreenCaptureAccess()

        case .microphone:
            // The microphone and speech APIs report whether the user was ever
            // asked, so they don't need our own "requested before" flag.
            guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else {
                NSWorkspace.shared.open(permissionKind.systemSettingsURL)
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { _ in }

        case .speechRecognition:
            guard SFSpeechRecognizer.authorizationStatus() == .notDetermined else {
                NSWorkspace.shared.open(permissionKind.systemSettingsURL)
                return
            }
            SFSpeechRecognizer.requestAuthorization { _ in }
        }
    }

    static func hasRequestedBefore(_ permissionKind: PermissionKind) -> Bool {
        UserDefaults.standard.bool(forKey: requestedBeforeDefaultsKey(for: permissionKind))
    }

    private static func markRequested(_ permissionKind: PermissionKind) {
        UserDefaults.standard.set(true, forKey: requestedBeforeDefaultsKey(for: permissionKind))
    }

    private static func requestedBeforeDefaultsKey(for permissionKind: PermissionKind) -> String {
        "hasRequestedPermission.\(permissionKind)"
    }
}
