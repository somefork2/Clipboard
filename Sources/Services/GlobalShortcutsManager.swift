import AppKit
import Carbon.HIToolbox
import Foundation

class GlobalShortcutsManager: ObservableObject {
    static let shared = GlobalShortcutsManager()

    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID = EventHotKeyID()

    @Published var isPaused = false

    // Shortcuts
    var quickPasteShortcut: String = "⌥⌘V"
    var togglePauseShortcut: String = "⌃⌥P"

    var onQuickPaste: (() -> Void)?
    var onTogglePause: (() -> Void)?

    func registerShortcuts() {
        // Quick Paste: ⌥⌘V
        registerHotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey | cmdKey), id: 1)

        // Toggle Pause: ⌃⌥P
        registerHotKey(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(controlKey | optionKey), id: 2)
    }

    func unregisterAll() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
    }

    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: UInt32) {
        hotKeyID.signature = OSType(0x4353504B) // "CSPK"
        hotKeyID.id = id

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

            DispatchQueue.main.async {
                switch hotKeyID.id {
                case 1: GlobalShortcutsManager.shared.onQuickPaste?()
                case 2: GlobalShortcutsManager.shared.onTogglePause?()
                default: break
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
