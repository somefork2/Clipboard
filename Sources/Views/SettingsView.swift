import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            PrivacySettings()
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
            ShortcutSettings()
                .tabItem { Label("Shortcuts", systemImage: "command") }
            AppearanceSettings()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            SyncSettings()
                .tabItem { Label("Sync & Export", systemImage: "icloud") }
            SubscriptionSettings()
                .tabItem { Label("Subscription", systemImage: "creditcard") }
        }
        .frame(width: 560)
    }
}

// MARK: - General

struct GeneralSettings: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SubscriptionManager.self) private var subscriptions

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle("Launch ClipStack at login", isOn: $settings.launchAtLogin)
                Toggle("Show icon in the Dock", isOn: $settings.showInDock)
                Toggle("Show icon in the menu bar", isOn: $settings.showInMenuBar)
            } footer: {
                Text("With the Dock icon hidden, the menu bar item stays available so ClipStack is always reachable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Pasting") {
                Toggle("Paste directly into the active app", isOn: $settings.pasteDirectly)
                if settings.pasteDirectly {
                    AccessibilityStatusRow()
                }
            }

            Section("History") {
                Picker("Keep at most", selection: $settings.maxHistoryItems) {
                    Text("100 clips").tag(100)
                    Text("500 clips").tag(500)
                    Text("1,000 clips").tag(1000)
                    Text("5,000 clips").tag(5000)
                    Text("No limit").tag(0)
                }
                .disabled(!subscriptions.isPro)

                Picker("Delete clips older than", selection: $settings.autoCleanupDays) {
                    Text("Never").tag(0)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                .disabled(!subscriptions.isPro)

                if !subscriptions.isPro {
                    LabeledContent("Free plan") {
                        HStack {
                            Text("100 most recent clips")
                                .foregroundStyle(.secondary)
                            Button("Upgrade") { subscriptions.showingPaywall = true }
                                .buttonStyle(.link)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Shows exactly where the Accessibility permission stands, instead of failing
/// silently the first time a paste does nothing.
struct AccessibilityStatusRow: View {
    @State private var trusted = PasteService.hasAccessibilityPermission

    var body: some View {
        LabeledContent("Accessibility access") {
            HStack(spacing: 6) {
                Image(systemName: trusted ? "checkmark.circle" : "exclamationmark.triangle")
                    .foregroundStyle(trusted ? .green : .orange)
                Text(trusted ? "Granted" : "Not granted")
                    .foregroundStyle(.secondary)
                if !trusted {
                    Button("Grant…") {
                        PasteService.ensurePermission()
                    }
                    .buttonStyle(.link)
                }
            }
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            trusted = PasteService.hasAccessibilityPermission
        }
    }
}

// MARK: - Privacy

struct PrivacySettings: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ClipboardStore.self) private var store
    @State private var showingClearConfirmation = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle("Ignore items marked secret by other apps", isOn: $settings.skipConcealedPasteboard)
                Toggle("Never record anything that looks like a password", isOn: $settings.skipPasswords)
                Toggle("Hide ClipStack windows from screen recordings", isOn: $settings.hideFromScreenCapture)
            } footer: {
                Text("""
                Password managers mark their copies with the standard \
                org.nspasteboard.ConcealedType flag; ClipStack skips those and never \
                records copies made in known password managers. Items you mark as \
                sensitive yourself are encrypted with a key kept in your login keychain.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Stored data") {
                LabeledContent("Clips on this Mac", value: "\(store.items.count)")
                LabeledContent("Encrypted clips", value: "\(store.items.count(where: \.isSensitive))")
                Button("Clear History…", role: .destructive) {
                    showingClearConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Clear clipboard history?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Except Favourites", role: .destructive) {
                store.clearHistory(keepingFavorites: true)
            }
            Button("Delete Everything", role: .destructive) {
                store.clearHistory(keepingFavorites: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clips and their stored images are removed permanently.")
        }
    }
}

// MARK: - Shortcuts

struct ShortcutSettings: View {
    @Environment(SubscriptionManager.self) private var subscriptions
    private var manager: GlobalShortcutsManager { .shared }

    var body: some View {
        Form {
            Section {
                ForEach(ShortcutAction.allCases) { action in
                    LabeledContent {
                        ShortcutRecorder(action: action)
                            .disabled(!subscriptions.isPro && !isFreeAction(action))
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(action.title)
                            Text(action.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if !subscriptions.isPro {
                        Text("Rebinding every shortcut is part of ClipStack Pro. The palette and pause shortcuts stay editable on the free plan.")
                    }
                    Text("Inside the palette: ↑↓ to move, ⌘1–9 to jump, ⏎ to paste, ⌥⏎ to paste as plain text, ⌘Y to preview, ⌘⌫ to delete, ⎋ to close.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset All Shortcuts") { manager.resetToDefaults() }
            }
        }
        .formStyle(.grouped)
    }

    private func isFreeAction(_ action: ShortcutAction) -> Bool {
        action == .quickPaste || action == .togglePause
    }
}

// MARK: - Appearance

struct AppearanceSettings: View {
    @State private var theme = ThemeManager.shared

    var body: some View {
        @Bindable var theme = theme

        Form {
            Section("Appearance") {
                Picker("Theme", selection: $theme.currentTheme) {
                    ForEach(AppTheme.allCases) { option in
                        Label(option.displayName, systemImage: option.icon).tag(option)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("Accent colour") {
                HStack(spacing: 8) {
                    ForEach(ThemeManager.accentOptions, id: \.self) { name in
                        Button {
                            theme.accentColorName = name
                        } label: {
                            Circle()
                                .fill(Color.named(name))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(.primary, lineWidth: theme.accentColorName == name ? 2 : 0)
                                        .padding(-3)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(name)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Sync & Export

struct SyncSettings: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ClipboardStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscriptions

    @State private var syncStatus: String?
    @State private var isSyncing = false
    @State private var exportFormat: ExportFormat = .json

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("iCloud") {
                Toggle("Sync history across my Macs", isOn: $settings.iCloudSync)
                    .disabled(!subscriptions.isPro)
                    .onChange(of: settings.iCloudSync) { _, enabled in
                        if enabled { Task { await checkAccount() } }
                    }

                if let syncStatus {
                    Text(syncStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await syncNow() }
                } label: {
                    if isSyncing { ProgressView().controlSize(.small) } else { Text("Sync Now") }
                }
                .disabled(!settings.iCloudSync || isSyncing || !subscriptions.isPro)
            }

            Section("Export") {
                Picker("Format", selection: $exportFormat) {
                    Text("JSON").tag(ExportFormat.json)
                    Text("CSV").tag(ExportFormat.csv)
                    Text("Markdown").tag(ExportFormat.markdown)
                    Text("HTML").tag(ExportFormat.html)
                }
                Button("Export History…") { export() }
                    .disabled(store.items.isEmpty)
                Text("Sensitive clips are never included in exports.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func checkAccount() async {
        let available = await CloudKitSyncManager.shared.checkAccountStatus()
        syncStatus = available
            ? "Connected to your private iCloud database."
            : "Sign in to iCloud in System Settings to use sync."
    }

    private func syncNow() async {
        isSyncing = true
        defer { isSyncing = false }
        let result = await CloudKitSyncManager.shared.sync(localItems: store.items.map(CloudClip.init))
        switch result {
        case .success(let incoming):
            for clip in incoming { store.insert(clip) }
            syncStatus = "Synced. \(incoming.count) new clip\(incoming.count == 1 ? "" : "s") from iCloud."
        case .failure(let message):
            syncStatus = message
        }
    }

    /// Writes through an NSSavePanel, which is also how a sandboxed app gets
    /// permission to write where the user chose.
    private func export() {
        guard subscriptions.requestAccess(for: .exportImport) else { return }
        guard let data = ExportManager.export(items: store.items, format: exportFormat) else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "ClipStack Export.\(exportFormat.fileExtension)"
        panel.allowedContentTypes = [exportFormat.contentType]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
    }
}

// MARK: - Subscription

struct SubscriptionSettings: View {
    @Environment(SubscriptionManager.self) private var manager

    var body: some View {
        Form {
            Section("Plan") {
                LabeledContent("Status", value: statusText)
                if let expiry = manager.expirationDate {
                    LabeledContent(
                        manager.isInTrial ? "Trial ends" : "Renews",
                        value: expiry.formatted(date: .abbreviated, time: .shortened)
                    )
                }
                if !manager.isPro {
                    Button("See ClipStack Pro") { manager.showingPaywall = true }
                }
                Button("Restore Purchases") {
                    Task { await manager.restorePurchases() }
                }
                Button("Manage Subscription") { manager.showManageSubscriptions() }
                if let error = manager.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Legal") {
                Link("Privacy Policy", destination: LegalLinks.privacyPolicy)
                Link("Terms of Use", destination: LegalLinks.termsOfUse)
                Link("Support", destination: LegalLinks.support)
            }
        }
        .formStyle(.grouped)
        .task { await manager.refreshEntitlement() }
    }

    private var statusText: String {
        if manager.isInTrial { return "Pro — free trial" }
        return manager.isPro ? "Pro" : "Free"
    }
}
