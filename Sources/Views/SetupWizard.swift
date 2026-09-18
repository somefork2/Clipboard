import AppKit
import SwiftUI

/// First-run setup.
///
/// Four screens, each asking one thing and explaining why. The Services step
/// matters most: macOS ships third-party services switched off, so without
/// being told, people never find the right-click items and conclude they are
/// broken.
struct SetupWizard: View {
    let onFinish: () -> Void

    @Environment(AppSettings.self) private var settings
    @State private var step = 0
    @State private var theme = ThemeManager.shared

    private let stepCount = 4

    var body: some View {
        @Bindable var bindableSettings = settings

        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            Group {
                switch step {
                case 0: welcome
                case 1: essentials
                case 2: appearanceAndSound(
                    soundsEnabled: $bindableSettings.soundsEnabled,
                    launchAtLogin: $bindableSettings.launchAtLogin
                )
                default: services
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)

            Divider()
            footer
        }
        .frame(width: 520, height: 470)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "clipboard")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.headline)
            Spacer()
            HStack(spacing: 5) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Theme.accent : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var title: String {
        switch step {
        case 0: return "Welcome to CopyWell"
        case 1: return "The two things to remember"
        case 2: return "Make it yours"
        default: return "One switch in System Settings"
        }
    }

    private var footer: some View {
        HStack {
            Button("Skip setup") { finish() }
                .buttonStyle(.link)
            Spacer()
            if step > 0 {
                Button("Back") { withAnimation { step -= 1 } }
            }
            Button(step == stepCount - 1 ? "Done" : "Continue") {
                if step == stepCount - 1 {
                    finish()
                } else {
                    withAnimation { step += 1 }
                }
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
        onFinish()
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CopyWell keeps what you copy, so you can get it back later.")
                .font(.title3)
            bullet("lock", "Everything stays on this Mac.", "Nothing is uploaded unless you turn on iCloud sync yourself.")
            bullet("hand.raised", "No permissions are requested.", "CopyWell never presses keys for you, so it needs no Accessibility access.")
            bullet("eye.slash", "Password managers are respected.", "Copies marked secret by 1Password, Bitwarden or Keychain are never recorded.")
        }
    }

    private var essentials: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    KeyCap(text: "⌥⌘V")
                    Text("opens the palette wherever you are")
                        .font(.callout)
                }
                Text("Pick a clip with ↑↓ or ⌘1–9, press ⏎, then ⌘V to paste it. Press ⌘Y to look at one first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "menubar.arrow.up.rectangle")
                        .foregroundStyle(Theme.accent)
                    Text("The menu bar icon shows recent clips")
                        .font(.callout)
                }
                Text("Click any of them to put it back on the clipboard, without opening the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Everything else is optional")
                    .font(.callout)
                Text("Pinboards for clips you reuse, a paste stack for pasting several in order, and search across text, links and the text inside screenshots.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func appearanceAndSound(
        soundsEnabled: Binding<Bool>,
        launchAtLogin: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Theme")
                    .font(.callout)
                Picker("", selection: Binding(
                    get: { theme.currentTheme },
                    set: { theme.currentTheme = $0 }
                )) {
                    ForEach(AppTheme.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Text("More themes, accent colours and text size live in Settings ▸ Appearance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Play a sound when something is copied", isOn: soundsEnabled)
                Text("Off by default. A utility that beeps every time you copy gets uninstalled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Start CopyWell at login", isOn: launchAtLogin)
                Text("CopyWell only records while it is running.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var services: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CopyWell adds items to the right-click menu of every app — save the selection, pin it, or read the text out of an image.")
                .font(.callout)

            Text("macOS ships third-party menu items switched off. Turn them on once and they stay on.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Open Keyboard Shortcuts…") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts") {
                    NSWorkspace.shared.open(url)
                }
            }

            Text("Keyboard ▸ Keyboard Shortcuts ▸ Services, then tick the CopyWell entries.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("In Finder, CopyWell also appears as its own menu. Enable it in General ▸ Login Items & Extensions ▸ Finder Extensions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func bullet(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
