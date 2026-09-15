import AppKit
import SwiftUI

/// The panel that drops down from the menu bar icon.
struct CompanionPanelView: View {
    @ObservedObject var companionManager: CompanionManager

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            if companionManager.permissions.areAllGranted {
                allPermissionsGrantedRow
            } else {
                permissionsSection
            }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 320)
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

            Button("Quit Tiko") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
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
