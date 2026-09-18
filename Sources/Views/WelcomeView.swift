import AppKit
import SwiftUI

/// Shown once, on first launch.
///
/// The Services entries are the app's way into other apps' right-click menus,
/// and macOS ships them switched off. Without saying so, people never find them
/// and conclude the feature does not work.
struct WelcomeView: View {
    let onDismiss: () -> Void

    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "clipboard")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.accent)
                Text("ClipStack is recording")
                    .font(.title2.weight(.semibold))
                Text("Everything you copy is kept on this Mac. Nothing is sent anywhere.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 14) {
                step(
                    icon: "command",
                    title: "Press ⌥⌘V anywhere",
                    detail: "The palette opens at your cursor. Pick a clip, then press ⌘V to paste it."
                )
                step(
                    icon: "menubar.arrow.up.rectangle",
                    title: "Or use the menu bar",
                    detail: "The clipboard icon shows your recent clips without opening the app."
                )
                step(
                    icon: "contextualmenu.and.cursorarrow",
                    title: "Turn on the right-click items",
                    detail: "ClipStack adds entries to the Services menu of every app. macOS ships them switched off."
                )
            }

            Button("Open Keyboard Shortcuts…") {
                // Takes the user straight to the list where Services are enabled.
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .padding(.leading, 30)
            .padding(.top, 4)

            Spacer(minLength: 16)

            HStack {
                Text("Everything here is optional and ClipStack asks for no permissions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Start") {
                    settings.hasCompletedOnboarding = true
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 460, height: 400)
    }

    private func step(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
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
