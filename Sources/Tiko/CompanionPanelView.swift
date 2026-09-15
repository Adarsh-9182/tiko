import AppKit
import SwiftUI
import TikoCore

/// The panel that drops down from the menu bar icon: what Tiko needs to work,
/// and what it last said. Everything else lives in the Settings window.
struct CompanionPanelView: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject var preferences: TikoPreferences

    @State private var enteredGeminiAPIKey = ""
    @State private var isReplacingGeminiKey = false

    private static let freeGeminiKeyURL = URL(string: "https://aistudio.google.com/apikey")!

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let availableUpdate = companionManager.availableUpdate {
                updateRow(availableUpdate)
            }

            Divider()

            if companionManager.permissions.areAllGranted {
                allPermissionsGrantedRow
            } else {
                permissionsSection
            }

            Divider()

            geminiKeySection

            Divider()

            if let activeTour = companionManager.activeTour {
                tourRow(activeTour)
            }

            pushToTalkHint

            if let lastTranscript = companionManager.lastTranscript {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last heard")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(lastTranscript)
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let lastReply = companionManager.lastReply {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Tiko said")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Copy") {
                            companionManager.copyLastReply()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                    Text(lastReply.text)
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    if let lastPointingTarget = companionManager.lastPointingTarget {
                        Text("Pointed at \(lastPointingTarget.elementLabel)\(lastPointingTarget.refinement.panelSuffix)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Toggle(isOn: $companionManager.isBuddyVisible) {
                Text("Show Tiko next to my cursor")
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Toggle(isOn: $companionManager.isSpeakingRepliesEnabled) {
                Text("Speak replies")
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 340)
        .onChange(of: companionManager.geminiKeyStatus) { _, newKeyStatus in
            // Once a key checks out, clear the field so the key isn't left sitting in it.
            if case .ready = newKeyStatus {
                enteredGeminiAPIKey = ""
                isReplacingGeminiKey = false
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            BuddyTriangleShape()
                .fill(tikoAccentColor)
                .frame(width: 13, height: 13)
                .rotationEffect(.degrees(-35))
                .shadow(color: tikoAccentColor.opacity(0.6), radius: 5)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tikoAccentColor.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text("Tiko")
                    .font(.system(size: 15, weight: .semibold))
                Text("Your buddy next to the cursor")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private func updateRow(_ availableUpdate: AvailableUpdate) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(tikoAccentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Tiko \(availableUpdate.version.description) is out")
                    .font(.system(size: 12, weight: .medium))
                Text("You have \(appVersion). Download it, then replace the app.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button("Download") {
                NSWorkspace.shared.open(availableUpdate.pageURL)
            }
            .controlSize(.small)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tikoAccentColor.opacity(0.1)))
    }

    private func tourRow(_ activeTour: GuidedTour) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Guided tour · step \(activeTour.shownSteps.count) shown")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tikoAccentColor)
                Text(activeTour.goal)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Tap \(preferences.pushToTalkShortcut.symbols) or say \"next\" for the next step")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button("End tour") {
                companionManager.endTour()
            }
            .controlSize(.small)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tikoAccentColor.opacity(0.1)))
    }

    @ViewBuilder
    private var geminiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gemini API key")
                .font(.system(size: 12, weight: .semibold))

            if case .ready(let modelNames) = companionManager.geminiKeyStatus, !isReplacingGeminiKey {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                    Text("Saved · \(companionManager.chosenModelName ?? modelNames.first ?? "")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    Button("Change") {
                        isReplacingGeminiKey = true
                    }
                    .controlSize(.small)
                    Button("Remove") {
                        companionManager.removeGeminiAPIKey()
                    }
                    .controlSize(.small)
                }
            } else {
                HStack(spacing: 6) {
                    SecureField("Paste your key", text: $enteredGeminiAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onSubmit(saveEnteredGeminiAPIKey)
                    Button("Save", action: saveEnteredGeminiAPIKey)
                        .controlSize(.small)
                        .disabled(isSaveKeyButtonDisabled)
                }

                switch companionManager.geminiKeyStatus {
                case .checking:
                    Text("Checking the key…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                case .failed(let message):
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                case .missing, .ready:
                    EmptyView()
                }

                HStack(spacing: 4) {
                    Text("Free key:")
                    Link("aistudio.google.com/apikey", destination: Self.freeGeminiKeyURL)
                    Text("· stays on this Mac")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var isSaveKeyButtonDisabled: Bool {
        enteredGeminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || companionManager.geminiKeyStatus == .checking
    }

    private func saveEnteredGeminiAPIKey() {
        guard !isSaveKeyButtonDisabled else { return }
        companionManager.saveGeminiAPIKey(enteredGeminiAPIKey)
    }

    private var pushToTalkHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Hold")
                KeyCap(text: preferences.pushToTalkShortcut.displayName)
                Text("and ask")
            }
            HStack(spacing: 6) {
                Text("Press")
                KeyCap(text: "⎋ esc")
                Text("to stop Tiko")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tiko needs a few permissions")
                .font(.system(size: 12, weight: .semibold))

            ForEach(PermissionKind.allCases) { permissionKind in
                PermissionRow(
                    permissionKind: permissionKind,
                    isGranted: companionManager.permissions.isGranted(permissionKind),
                    onAllow: { companionManager.requestPermission(permissionKind) }
                )
            }

            if companionManager.hasRequestedScreenRecording && !companionManager.permissions.isScreenRecordingGranted {
                HStack(spacing: 8) {
                    Text("Allowed Screen Recording? macOS applies it after a restart.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    Button("Restart") {
                        companionManager.relaunch()
                    }
                    .controlSize(.small)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tikoAccentColor.opacity(0.1)))
            }
        }
    }

    private var allPermissionsGrantedRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.green)
            Text("All set — Tiko has every permission it needs.")
                .font(.system(size: 12))
        }
    }

    private var footer: some View {
        HStack {
            Text("v\(appVersion)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            Button("Settings…") {
                NotificationCenter.default.post(name: .tikoOpenSettings, object: nil)
            }
            .keyboardShortcut(",")

            Button("Quit Tiko") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

/// A small keyboard key, so shortcuts read like the keys on the keyboard.
private struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
            )
    }
}

private struct PermissionRow: View {
    let permissionKind: PermissionKind
    let isGranted: Bool
    let onAllow: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(isGranted ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(permissionKind.title)
                    .font(.system(size: 12, weight: .medium))
                Text(permissionKind.reason)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if !isGranted {
                Button("Allow", action: onAllow)
                    .controlSize(.small)
            }
        }
    }
}
