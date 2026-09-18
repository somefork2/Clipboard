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
    var hideFromScreenCapture: Bool { didSet { persist(); NotificationCenter.default.post(name: .clipStackWindowPrivacyChanged, object: nil) } }
    var maxHistoryItems: Int { didSet { persist() } }
    var autoCleanupDays: Int { didSet { persist() } }
    var iCloudSync: Bool { didSet { persist() } }
    var playFeedbackSound: Bool { didSet { persist() } }
    var pasteDirectly: Bool { didSet { persist() } }
    var hasCompletedOnboarding: Bool { didSet { persist() } }

    private init() {
        defaults.register(defaults: [
            "showInDock": true,
            "showInMenuBar": true,
            "skipPasswords": true,
            "skipConcealedPasteboard": true,
            "hideFromScreenCapture": true,
            "maxHistoryItems": 1000,
            "autoCleanupDays": 0,
            "icloudSync": false,
            "playFeedbackSound": false,
            "pasteDirectly": true
        ])

        launchAtLogin = SMAppService.mainApp.status == .enabled
        showInDock = defaults.bool(forKey: "showInDock")
        showInMenuBar = defaults.bool(forKey: "showInMenuBar")
        skipPasswords = defaults.bool(forKey: "skipPasswords")
        skipConcealedPasteboard = defaults.bool(forKey: "skipConcealedPasteboard")
        hideFromScreenCapture = defaults.bool(forKey: "hideFromScreenCapture")
        maxHistoryItems = defaults.integer(forKey: "maxHistoryItems")
        autoCleanupDays = defaults.integer(forKey: "autoCleanupDays")
        iCloudSync = defaults.bool(forKey: "icloudSync")
        playFeedbackSound = defaults.bool(forKey: "playFeedbackSound")
        pasteDirectly = defaults.bool(forKey: "pasteDirectly")
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
    }

    private func persist() {
        defaults.set(showInDock, forKey: "showInDock")
        defaults.set(showInMenuBar, forKey: "showInMenuBar")
        defaults.set(skipPasswords, forKey: "skipPasswords")
        defaults.set(skipConcealedPasteboard, forKey: "skipConcealedPasteboard")
        defaults.set(hideFromScreenCapture, forKey: "hideFromScreenCapture")
        defaults.set(maxHistoryItems, forKey: "maxHistoryItems")
        defaults.set(autoCleanupDays, forKey: "autoCleanupDays")
        defaults.set(iCloudSync, forKey: "icloudSync")
        defaults.set(playFeedbackSound, forKey: "playFeedbackSound")
        defaults.set(pasteDirectly, forKey: "pasteDirectly")
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
    static let clipStackWindowPrivacyChanged = Notification.Name("clipStackWindowPrivacyChanged")
    static let clipStackHistoryChanged = Notification.Name("clipStackHistoryChanged")
}
