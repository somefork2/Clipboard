import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

/// Performs the actual paste into whatever app the user was using.
///
/// Synthesising ⌘V requires the Accessibility permission. We never ask silently:
/// `ensurePermission` shows a plain explanation and, only then, the system prompt.
@MainActor
enum PasteService {
    /// The app that was frontmost before our palette appeared.
    private(set) static var previousApp: NSRunningApplication?

    /// Keeps `previousApp` current at all times.
    ///
    /// Only the palette used to record it, so a paste from the menu bar aimed at
    /// whatever happened to be remembered last — or at nothing. Watching
    /// activations means the target is always the last app the user was in.
    static func beginTrackingFrontmostApp() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != NSRunningApplication.current.processIdentifier else { return }
            MainActor.assumeIsolated { previousApp = app }
        }
        rememberFrontmostApp()
    }

    static func rememberFrontmostApp() {
        let ours = NSRunningApplication.current.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ours {
            previousApp = front
        }
    }

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Returns true when we may synthesise keystrokes. Shows an explanatory
    /// alert before the system prompt so the request never appears out of nowhere.
    @discardableResult
    static func ensurePermission(promptIfNeeded: Bool = true) -> Bool {
        if AXIsProcessTrusted() { return true }
        guard promptIfNeeded else { return false }

        let alert = NSAlert()
        alert.messageText = "ClipStack needs Accessibility access"
        alert.informativeText = """
        To paste into other apps, ClipStack asks macOS to press ⌘V for you. \
        macOS only allows that with Accessibility access.

        ClipStack never reads the contents of other apps — the permission is \
        used solely to send the paste keystroke.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")

        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        // The constant is a global `var` and so not concurrency-safe to read;
        // its value is a documented, stable string.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        return false
    }

    /// Puts `content` on the pasteboard and pastes it into the previously active app.
    static func paste(_ content: PasteContent, plainText: Bool = false) {
        write(content, plainText: plainText)

        guard AppSettings.shared.pasteDirectly else { return }
        guard ensurePermission() else { return }

        let target = previousApp
        target?.activate()

        // Give the target app a moment to become key before the keystroke lands.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            sendCommandV()
        }
    }

    /// Writes to the pasteboard without pasting.
    static func write(_ content: PasteContent, plainText: Bool = false) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .richText(let string, let rtf):
            if plainText || rtf == nil {
                pasteboard.setString(string, forType: .string)
            } else if let rtf {
                pasteboard.setData(rtf, forType: .rtf)
                pasteboard.setString(string, forType: .string)
            }
        case .image(let data):
            if let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        }
    }

    /// Copies the current selection of the frontmost app without disturbing the
    /// user's clipboard: we snapshot the pasteboard, press ⌘C, read, then restore.
    static func captureSelection(completion: @escaping (String?) -> Void) {
        guard ensurePermission() else { completion(nil); return }

        let pasteboard = NSPasteboard.general
        let savedString = pasteboard.string(forType: .string)
        let savedChangeCount = pasteboard.changeCount

        sendCommandC()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let captured = pasteboard.changeCount != savedChangeCount
                ? pasteboard.string(forType: .string)
                : nil

            // Restore whatever the user actually had copied.
            if captured != nil, let savedString {
                pasteboard.clearContents()
                pasteboard.setString(savedString, forType: .string)
            }
            completion(captured)
        }
    }

    // MARK: - Keystroke synthesis

    private static func sendCommandV() { sendKey(CGKeyCode(kVK_ANSI_V)) }
    private static func sendCommandC() { sendKey(CGKeyCode(kVK_ANSI_C)) }

    private static func sendKey(_ keyCode: CGKeyCode) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}

enum PasteContent {
    case text(String)
    case richText(String, Data?)
    case image(Data)
}
