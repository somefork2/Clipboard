import AppKit
import SwiftUI

/// First-run setup.
///
/// Four screens, each making one point and showing it. The Services step
/// matters most: macOS ships third-party menu items switched off, so without
/// being told, people never find the right-click entries and conclude they are
/// broken.
struct SetupWizard: View {
    let onFinish: () -> Void

    @Environment(AppSettings.self) private var settings
    @State private var step = 0
    @State private var goingForward = true
    @State private var theme = ThemeManager.shared

    private let stepCount = 4

    var body: some View {
        @Bindable var bindableSettings = settings

        VStack(spacing: 0) {
            header
            Divider()

            ZStack {
                switch step {
                case 0: welcome
                case 1: essentials
                case 2: personalise(
                    soundsEnabled: $bindableSettings.soundsEnabled,
                    launchAtLogin: $bindableSettings.launchAtLogin
                )
                default: services
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            // Each step slides in from the direction of travel, so moving back
            // feels like going back rather than like a different screen.
            .transition(.asymmetric(
                insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
            ))
            .id(step)

            Divider()
            footer
        }
        .frame(width: 660, height: 600)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: 12) {
            appIcon
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text("Step \(step + 1) of \(stepCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            progressDots
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    /// The real app icon, so the guide looks like it belongs to the app.
    private var appIcon: some View {
        Image(nsImage: NSApp.applicationIconImage ?? NSImage())
            .resizable()
            .interpolation(.high)
            .frame(width: 40, height: 40)
    }

    private var progressDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<stepCount, id: \.self) { index in
                Capsule()
                    .fill(index == step ? Theme.accent : Color.secondary.opacity(0.28))
                    .frame(width: index == step ? 18 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
    }

    private var title: String {
        switch step {
        case 0: return String(localized: "Welcome to CopyWell")
        case 1: return String(localized: "Two things worth remembering")
        case 2: return String(localized: "Make it yours")
        default: return String(localized: "One switch in System Settings")
        }
    }

    private var footer: some View {
        HStack {
            Button("Skip setup") { finish() }
                .buttonStyle(.link)
            Spacer()
            if step > 0 {
                Button("Back") { move(to: step - 1) }
            }
            Button(step == stepCount - 1 ? "Start using CopyWell" : "Continue") {
                step == stepCount - 1 ? finish() : move(to: step + 1)
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func move(to newStep: Int) {
        goingForward = newStep > step
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            step = newStep
        }
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
        onFinish()
    }

    // MARK: - Steps

    private var welcome: some View {
        StepLayout(
            headline: String(localized: "CopyWell keeps what you copy, so you can get it back later."),
            illustration: { AnimatedIn { WizardIllustration.Privacy() } }
        ) {
            bullet("lock", String(localized: "Everything stays on this Mac."),
                   String(localized: "Nothing is uploaded unless you turn on iCloud sync yourself."))
            bullet("hand.raised", String(localized: "No permissions are requested."),
                   String(localized: "CopyWell never presses keys for you, so it needs no Accessibility access."))
            bullet("eye.slash", String(localized: "Password managers are respected."),
                   String(localized: "Copies marked secret by 1Password, Bitwarden or Keychain are never recorded."))
        }
    }

    private var essentials: some View {
        StepLayout(
            headline: String(localized: "Press ⌥⌘V anywhere, pick a clip, press ⌘V."),
            illustration: { AnimatedIn { WizardIllustration.Shortcut() } }
        ) {
            bullet("command", String(localized: "The palette opens at your cursor."),
                   String(localized: "Move with ↑↓ or jump with ⌘1–9. ⌘Y looks at a clip before you take it."))
            bullet("menubar.arrow.up.rectangle", String(localized: "The menu bar icon shows recent clips."),
                   String(localized: "Click one to put it back on the clipboard without opening the app."))
            bullet("square.stack", String(localized: "Pinboards and the paste stack are there when you need them."),
                   String(localized: "Keep clips you reuse, or queue several and paste them in order."))
        }
    }

    private func personalise(
        soundsEnabled: Binding<Bool>,
        launchAtLogin: Binding<Bool>
    ) -> some View {
        StepLayout(
            headline: String(localized: "Pick a look, and decide whether CopyWell makes a sound."),
            illustration: { AnimatedIn { WizardIllustration.Personalise() } }
        ) {
            LabeledContent("Theme") {
                Picker("", selection: Binding(
                    get: { theme.currentTheme },
                    set: { theme.currentTheme = $0 }
                )) {
                    ForEach(AppTheme.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }

            Toggle("Play a sound when something is copied", isOn: soundsEnabled)
            Text("Off by default. A utility that beeps every time you copy gets uninstalled.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Start CopyWell at login", isOn: launchAtLogin)
            Text("CopyWell only records while it is running. More themes, accent colours and text size are in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var services: some View {
        StepLayout(
            headline: String(localized: "CopyWell adds items to the right-click menu of every app."),
            illustration: { AnimatedIn { WizardIllustration.Services() } }
        ) {
            Text("macOS ships third-party menu items switched off. Turn them on once and they stay on.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Open Keyboard Shortcuts…") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts") {
                    NSWorkspace.shared.open(url)
                }
            }

            Text("Keyboard ▸ Keyboard Shortcuts ▸ Services. The groups there start collapsed: open Text, Images and Files and Folders with the arrow on the left, and tick the CopyWell entries inside. In Finder, CopyWell also appears as its own menu — enable it in General ▸ Login Items & Extensions ▸ Finder Extensions.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bullet(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Illustration on top, one sentence, then the detail — the same shape on every
/// step so moving between them does not feel like moving between apps.
private struct StepLayout<Illustration: View, Content: View>: View {
    let headline: String
    @ViewBuilder let illustration: () -> Illustration
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            illustration()
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.secondaryBackground.opacity(0.55))
                )

            Text(headline)
                .font(.title3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }

            Spacer(minLength: 0)
        }
    }
}

/// Fades and lifts its content once, when the step appears.
private struct AnimatedIn<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var shown = false

    var body: some View {
        content()
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45).delay(0.08)) { shown = true }
            }
    }
}
