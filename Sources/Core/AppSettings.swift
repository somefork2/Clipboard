import AppKit
import Foundation
import Observation
import ServiceManagement

/// Single source of truth for user preferences.
///
/// Previously every toggle was an isolated `@AppStorage` in `SettingsView` that
/// nothing ever read. Each property here is wired to the behaviour it promises.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var launchAtLogin: Bool { didSet { applyLaunchAtLogin() } }
    var showInDock: Bool { didSet { persist(); applyActivationPolicy() } }
    var showInMenuBar: Bool { didSet { persist() } }
    var skipPasswords: Bool { didSet { persist() } }
    var skipConcealedPasteboard: Bool { didSet { persist() } }
    var hideFromScreenCapture: Bool { didSet { persist(); NotificationCenter.default.post(name: .copyWellWindowPrivacyChanged, object: nil) } }
    var retention: RetentionPolicy { didSet { retention.save(); ClipboardStore.shared.enforceLimits() } }
    var textSize: TextSizePreference { didSet { persist() } }
    var iCloudSync: Bool { didSet { persist() } }
    /// Off after installation on purpose.
    var soundsEnabled: Bool { didSet { persist() } }
    var captureSound: FeedbackSound { didSet { persist() } }
    var pasteSound: FeedbackSound { didSet { persist() } }
    var hasCompletedOnboarding: Bool { didSet { persist() } }

    private init() {
        defaults.register(defaults: [
            "showInDock": true,
            "showInMenuBar": true,
            "skipPasswords": true,
            "skipConcealedPasteboard": true,
            "hideFromScreenCapture": true,
            "icloudSync": false,
        ])

        launchAtLogin = SMAppService.mainApp.status == .enabled
        showInDock = defaults.bool(forKey: "showInDock")
        showInMenuBar = defaults.bool(forKey: "showInMenuBar")
        skipPasswords = defaults.bool(forKey: "skipPasswords")
        skipConcealedPasteboard = defaults.bool(forKey: "skipConcealedPasteboard")
        hideFromScreenCapture = defaults.bool(forKey: "hideFromScreenCapture")
        retention = RetentionPolicy.load()
        textSize = defaults.string(forKey: "textSize")
            .flatMap(TextSizePreference.init(rawValue:)) ?? .standard
        iCloudSync = defaults.bool(forKey: "icloudSync")
        soundsEnabled = defaults.bool(forKey: "soundsEnabled")
        captureSound = defaults.string(forKey: "sound_captured")
            .flatMap(FeedbackSound.init(rawValue:)) ?? .tink
        pasteSound = defaults.string(forKey: "sound_pasted")
            .flatMap(FeedbackSound.init(rawValue:)) ?? .pop
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
    }

    private func persist() {
        defaults.set(showInDock, forKey: "showInDock")
        defaults.set(showInMenuBar, forKey: "showInMenuBar")
        defaults.set(skipPasswords, forKey: "skipPasswords")
        defaults.set(skipConcealedPasteboard, forKey: "skipConcealedPasteboard")
        defaults.set(hideFromScreenCapture, forKey: "hideFromScreenCapture")
        defaults.set(textSize.rawValue, forKey: "textSize")
        defaults.set(iCloudSync, forKey: "icloudSync")
        defaults.set(soundsEnabled, forKey: "soundsEnabled")
        defaults.set(captureSound.rawValue, forKey: SoundEvent.captured.settingKey)
        defaults.set(pasteSound.rawValue, forKey: SoundEvent.pasted.settingKey)
        defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
    }

    func applyActivationPolicy() {
        // Keep at least one way to reach the app: if the Dock icon is hidden the
        // menu bar item has to stay.
        if !showInDock && !showInMenuBar {
            showInMenuBar = true
        }
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Registration fails when the app runs outside /Applications; reflect reality.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

extension Notification.Name {
    static let copyWellWindowPrivacyChanged = Notification.Name("copyWellWindowPrivacyChanged")
    static let copyWellHistoryChanged = Notification.Name("copyWellHistoryChanged")
}
