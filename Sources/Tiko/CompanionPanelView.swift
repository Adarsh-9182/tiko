import AppKit
import SwiftUI

/// The panel that drops down from the menu bar icon.
struct CompanionPanelView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            Divider()

            HStack {
                Text("v\(appVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                Spacer()

                Button("Quit Tiko") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
