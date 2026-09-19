import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, then press a combination to rebind a global shortcut.
///
/// Global hotkeys that cannot be changed are a support problem: sooner or later
/// they collide with another app and the feature simply stops working with no
/// way out. Every binding here is editable and clearable.
struct ShortcutRecorder: View {
    let action: ShortcutAction

    @State private var isRecording = false
    @State private var errorMessage: String?
    @State private var monitor: Any?

    private var manager: GlobalShortcutsManager { .shared }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Text(isRecording ? String(localized: "Press keys…") : manager.shortcut(for: action).displayString)
                    .font(.callout.monospaced())
                    .frame(minWidth: 88)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isRecording ? Theme.accent.opacity(0.15) : Theme.secondaryBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isRecording ? Theme.accent : Theme.separator, lineWidth: isRecording ? 1.5 : 0.5)
                    )
            }
            .buttonStyle(.plain)

            if !manager.shortcut(for: action).isEmpty {
                Button {
                    manager.rebind(action, to: .none)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Remove this shortcut")
            }

            if manager.conflicts.contains(action) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("Another app is already using this combination.")
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .offset(y: 16)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        errorMessage = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        let modifiers = ClipShortcut.carbonModifiers(from: event.modifierFlags)
        let candidate = ClipShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)

        guard candidate.isValidGlobalBinding else {
            errorMessage = String(localized: "Use at least one of ⌘, ⌥ or ⌃.")
            return
        }

        if manager.rebind(action, to: candidate) {
            errorMessage = nil
            stopRecording()
            AppCoordinator.shared.updateConflictMessage()
        } else {
            errorMessage = String(localized: "That combination is already taken.")
        }
    }
}
