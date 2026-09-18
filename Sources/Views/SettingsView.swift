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

    /// What is actually in force: the free tier ignores the chosen policy.
    private var effectiveRetention: RetentionPolicy {
        subscriptions.isPro ? settings.retention : .count(SubscriptionTier.free.maxItems)
    }

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

            Section {
                Picker("Text size", selection: $settings.textSize) {
                    ForEach(TextSizePreference.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
            } header: {
                Text("Accessibility")
            } footer: {
                Text("Scales every label in ClipStack, and the rows grow with it. Independent of the system-wide setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Keep", selection: $settings.retention) {
                    Section("By number of clips") {
                        ForEach(RetentionPolicy.presets.filter { if case .count = $0 { return true }; return false }) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                    Section("By age") {
                        ForEach(RetentionPolicy.presets.filter { if case .days = $0 { return true }; return false }) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                    Text(RetentionPolicy.forever.displayName).tag(RetentionPolicy.forever)
                }
                .disabled(!subscriptions.isPro)

                Text(effectiveRetention.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Favourites and clips on a pinboard are never removed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
            } header: {
                Text("History")
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

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        @Bindable var theme = theme

        Form {
            Section("Theme") {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(AppTheme.allCases) { option in
                        ThemeSwatch(theme: option, isSelected: theme.currentTheme == option) {
                            theme.currentTheme = option
                        }
                    }
                }
                .padding(.vertical, 4)

                Text(theme.currentTheme.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Accent colour") {
                HStack(spacing: 8) {
                    // "Theme" means each theme keeps the accent it was designed
                    // around; picking a colour overrides that everywhere.
                    Button {
                        theme.accentColorName = nil
                    } label: {
                        Circle()
                            .fill(theme.currentTheme.palette.accent)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(.primary, lineWidth: theme.accentColorName == nil ? 2 : 0)
                                    .padding(-3)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Use the colour this theme was designed around")
                    .accessibilityLabel("Theme accent")

                    Divider().frame(height: 18)

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

/// A miniature of the app drawn in the theme's own colours, so the choice is
/// made by looking rather than by reading colour names.
struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                preview
                HStack(spacing: 4) {
                    Text(theme.displayName)
                        .font(.callout)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                            lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName) theme")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var preview: some View {
        let palette = theme.palette
        HStack(spacing: 0) {
            // Sidebar
            Rectangle()
                .fill(palette.surface)
                .frame(width: 26)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(index == 0 ? palette.accent : palette.separator)
                                .frame(width: index == 0 ? 16 : 13, height: 3)
                        }
                    }
                    .padding(5)
                }

            Rectangle()
                .fill(palette.separator)
                .frame(width: 0.5)

            // Content rows
            Rectangle()
                .fill(palette.background)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(0..<4, id: \.self) { index in
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(palette.surface)
                                    .frame(width: 8, height: 8)
                                Capsule()
                                    .fill(palette.separator)
                                    .frame(width: index == 1 ? 34 : 46, height: 3)
                            }
                        }
                    }
                    .padding(6)
                }
        }
        .frame(height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(palette.separator, lineWidth: 0.5)
        )
    }
}

// MARK: - Sync & Export

struct SyncSettings: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ClipboardStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscriptions

    @State private var sync = SyncCoordinator.shared
    @State private var accountStatus: String?
    @State private var exportFormat: ExportFormat = .json

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("iCloud") {
                Toggle("Sync history across my Macs", isOn: $settings.iCloudSync)
                    .disabled(!subscriptions.isPro)
                    .onChange(of: settings.iCloudSync) { _, enabled in
                        sync.settingsChanged()
                        if enabled { Task { await checkAccount() } }
                    }

                if let message = sync.status.message ?? accountStatus {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await sync.syncNow(userInitiated: true) }
                } label: {
                    if sync.status == .syncing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Sync Now")
                    }
                }
                .disabled(!settings.iCloudSync || sync.status == .syncing || !subscriptions.isPro)

                Text("ClipStack syncs on launch, when you switch back to it, and a few seconds after you copy something. Images and items marked sensitive stay on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        accountStatus = available
            ? "Connected to your private iCloud database."
            : "Sign in to iCloud in System Settings to use sync."
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
