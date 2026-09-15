import AppKit
import Speech
import SwiftUI
import TikoCore

/// Opens and reuses the Settings window.
@MainActor
final class SettingsWindowController {
    private var settingsWindow: NSWindow?
    private let companionManager: CompanionManager

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
    }

    func showSettingsWindow() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 480),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Tiko Settings"
            // Closing hides the window; the next open reuses it.
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(
                companionManager: companionManager,
                preferences: companionManager.preferences,
                buddyVoice: companionManager.buddyVoice
            ))
            window.center()
            settingsWindow = window
        }
        // A menu bar app is never frontmost on its own; bring it forward so the window gets focus.
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject var preferences: TikoPreferences
    @ObservedObject var buddyVoice: BuddyVoice

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            voiceTab
                .tabItem { Label("Voice", systemImage: "speaker.wave.2") }
            historyTab
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .padding(16)
        .frame(width: 540, height: 480)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                Picker("Push-to-talk shortcut", selection: $preferences.pushToTalkShortcut) {
                    ForEach(PushToTalkShortcut.allCases) { shortcut in
                        Text(shortcut.displayName).tag(shortcut)
                    }
                }
                Text("Hold it and ask. During a guided tour, tap it for the next step. Esc stops Tiko.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("I speak", selection: $preferences.speechLanguage) {
                    ForEach(SpeechLanguage.allCases) { speechLanguage in
                        Text(speechLanguage.displayName).tag(speechLanguage)
                    }
                }
                Text(speechRecognitionPlaceDescription(for: preferences.speechLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Show Tiko next to my cursor", isOn: $companionManager.isBuddyVisible)
            }
        }
        .formStyle(.grouped)
    }

    /// Whether this language is recognised on the Mac itself or sent to Apple.
    private func speechRecognitionPlaceDescription(for speechLanguage: SpeechLanguage) -> String {
        guard let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: speechLanguage.localeIdentifier)) else {
            return "This Mac can't recognise this language."
        }
        return speechRecognizer.supportsOnDeviceRecognition
            ? "Recognised on this Mac — your voice never leaves it."
            : "This language is recognised by Apple's servers on this Mac."
    }

    // MARK: - Voice

    private var voiceTab: some View {
        Form {
            Section {
                Toggle("Speak replies", isOn: $companionManager.isSpeakingRepliesEnabled)
            }

            Section {
                Picker("Voice", selection: $preferences.voiceIdentifier) {
                    Text("Automatic (best installed)").tag(String?.none)
                    ForEach(SpeechVoicePicker.voiceOptions()) { voiceOption in
                        Text("\(voiceOption.name) · \(voiceOption.language) · \(voiceOption.qualityName)")
                            .tag(String?.some(voiceOption.id))
                    }
                }

                Picker("Speed", selection: $preferences.speakingSpeed) {
                    ForEach(SpeakingSpeed.allCases) { speakingSpeed in
                        Text(speakingSpeed.displayName).tag(speakingSpeed)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    if let voice = buddyVoice.voice {
                        Text("Now using \(voice.name) (\(voice.language), \(SpeechVoicePicker.qualityName(of: voice)))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Test voice") {
                        companionManager.previewVoice()
                    }
                }
            }
            .disabled(!companionManager.isSpeakingRepliesEnabled)

            if !buddyVoice.isUsingHighQualityVoice {
                Section {
                    Text("Basic voices sound robotic. For free, download an enhanced English (India) voice: System Settings → Accessibility → Spoken Content → System voice → Manage Voices. Then pick it here.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - History

    @State private var isConfirmingClearHistory = false

    private var historyTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            if companionManager.conversationLog.entries.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("No conversations yet")
                            .font(.system(size: 13, weight: .medium))
                        Text("Questions you ask Tiko, and its answers, will show up here.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                List(companionManager.conversationLog.entries.reversed()) { logEntry in
                    ConversationLogRow(logEntry: logEntry)
                }
                .listStyle(.inset)
            }

            HStack {
                Text("Saved only on this Mac · \(companionManager.conversationLog.entries.count) of \(ConversationLog.maximumEntryCount)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear history") {
                    isConfirmingClearHistory = true
                }
                .disabled(companionManager.conversationLog.entries.isEmpty)
            }
        }
        .confirmationDialog("Clear all of Tiko's history?", isPresented: $isConfirmingClearHistory) {
            Button("Clear history", role: .destructive) {
                companionManager.clearHistory()
            }
        } message: {
            Text("This removes every saved question and answer from this Mac.")
        }
    }
}

private struct ConversationLogRow: View {
    let logEntry: ConversationLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(logEntry.question)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text(logEntry.date, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Text(logEntry.reply)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Button("Copy answer") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(logEntry.reply, forType: .string)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
