import SwiftUI

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = true
    @AppStorage("showInDock") private var showInDock = false
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("skipPasswords") private var skipPasswords = true
    @AppStorage("hideFromScreenCapture") private var hideFromScreenCapture = true
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 1000
    @AppStorage("icloudSync") private var icloudSync = true
    @State private var showPaywall = false
    @State private var showExportSheet = false
    let subscription = SubscriptionManager.shared

    var body: some View {
        TabView {
            generalTab
            privacyTab
            shortcutsTab
            aiTab
            syncTab
            subscriptionTab
            aboutTab
        }
        .frame(width: 560, height: 440)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showExportSheet) { ExportSheet() }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Startup") {
                SettingToggle(title: "Launch at login", icon: "power", isOn: $launchAtLogin)
                SettingToggle(title: "Show in Dock", icon: "app.badge", isOn: $showInDock)
                SettingToggle(title: "Show in Menu Bar", icon: "menubar.rectangle", isOn: $showInMenuBar)
            }
            Section("History") {
                Picker("Maximum items", selection: $maxHistoryItems) {
                    Text("100").tag(100)
                    Text("500").tag(500)
                    Text("1,000").tag(1000)
                    Text("5,000").tag(5000)
                    Text("Unlimited").tag(-1)
                }
                if !subscription.isPro {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "f59e0b"))
                        Text("Free plan limited to 100 items")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Section("Data") {
                Button(action: { showExportSheet = true }) {
                    Label("Export History", systemImage: "arrow.up.doc.fill")
                }
                Button(role: .destructive) { } label: {
                    Label("Clear All History", systemImage: "trash.fill")
                }
            }
        }
        .padding(20)
        .tabItem { Label("General", systemImage: "gearshape.fill") }
    }

    // MARK: - Privacy

    private var privacyTab: some View {
        Form {
            Section("Clipboard") {
                SettingToggle(title: "Skip passwords automatically", icon: "key.fill", isOn: $skipPasswords)
                SettingToggle(title: "Hide from screen capture", icon: "eye.slash.fill", isOn: $hideFromScreenCapture)
            }
            Section("Security") {
                SettingToggle(title: "Require authentication", icon: "lock.fill", isOn: .constant(false))
            }
        }
        .padding(20)
        .tabItem { Label("Privacy", systemImage: "lock.shield.fill") }
    }

    // MARK: - Shortcuts

    private var shortcutsTab: some View {
        Form {
            Section("Global Shortcuts") {
                ShortcutRow(action: "Open Quick Paste", shortcut: "⌥⌘V")
                ShortcutRow(action: "Toggle Pause", shortcut: "⌃⌥P")
                ShortcutRow(action: "Open Main Window", shortcut: "⌃⌥⌘C")
            }
            Section("Quick Paste (⌘1-9)") {
                SettingToggle(title: "Enable number shortcuts", icon: "command", isOn: .constant(true))
                Text("Press ⌘1 through ⌘9 to paste the last 9 copied items instantly.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Section("Pause/Resume") {
                SettingToggle(title: "Pause clipboard monitoring", icon: "pause.fill", isOn: .constant(false))
                Text("When paused, ClipStack won't save new clips.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .tabItem { Label("Shortcuts", systemImage: "command") }
    }

    // MARK: - AI

    private var aiTab: some View {
        Form {
            Section("AI Processing") {
                AIStatusRow(
                    icon: "brain.head.profile.fill",
                    color: Color(hex: "8b5cf6"),
                    title: "Smart Categorization",
                    subtitle: "Auto-categorize using NaturalLanguage"
                )
                AIStatusRow(
                    icon: "text.magnifyingglass",
                    color: Color(hex: "3b82f6"),
                    title: "Entity Extraction",
                    subtitle: "Extract emails, phones, names, addresses"
                )
                AIStatusRow(
                    icon: "eye.fill",
                    color: Color(hex: "f59e0b"),
                    title: "OCR (Text from Images)",
                    subtitle: "Recognize text in screenshots via Vision"
                )
            }
            Section("Language Support") {
                Text("English, Russian, Ukrainian, German, French, Spanish, Japanese, Chinese, Korean")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .tabItem { Label("AI", systemImage: "brain.head.profile.fill") }
    }

    // MARK: - Sync

    private var syncTab: some View {
        Form {
            Section("iCloud") {
                SettingToggle(title: "Enable iCloud Sync", icon: "icloud.fill", isOn: $icloudSync)
                HStack(spacing: 8) {
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "3b82f6"))
                    Text("Sync your clipboard history across all Apple devices")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            Section("Status") {
                HStack {
                    Text("Last sync")
                        .font(.system(size: 12, design: .rounded))
                    Spacer()
                    Text("Just now")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Items synced")
                        .font(.system(size: 12, design: .rounded))
                    Spacer()
                    Text("0")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Button("Sync Now") { }
                    .disabled(!icloudSync)
            }
        }
        .padding(20)
        .tabItem { Label("Sync", systemImage: "icloud.fill") }
    }

    // MARK: - Subscription

    private var subscriptionTab: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(subscription.isPro ?
                                    LinearGradient(colors: [Color(hex: "f59e0b"), Color(hex: "d97706")], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                    LinearGradient(colors: [Color.secondary.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 32, height: 32)
                            Image(systemName: subscription.isPro ? "crown.fill" : "person.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(subscription.isPro ? .white : .secondary)
                        }
                        Text(subscription.isPro ? "Pro Plan" : "Free Plan")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                }
                Spacer()
                if !subscription.isPro {
                    Button(action: { showPaywall = true }) {
                        Text("Upgrade")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(LinearGradient(colors: [Color(hex: "1a1a2e"), Color(hex: "0f172a")], startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))

            VStack(spacing: 0) {
                CompRowHeader()
                Divider()
                CompRow(f: "Clipboard History", free: "100 items", pro: "Unlimited")
                CompRow(f: "Pinboards", free: "1", pro: "Unlimited")
                CompRow(f: "AI Features", free: "Basic", pro: "Full")
                CompRow(f: "Paste Stack", free: "—", pro: "✓")
                CompRow(f: "Export", free: "—", pro: "✓")
                CompRow(f: "Themes", free: "—", pro: "✓")
                CompRow(f: "iCloud Sync", free: "✓", pro: "✓")
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
        }
        .padding(20)
        .tabItem { Label("Subscription", systemImage: "crown.fill") }
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }
            VStack(spacing: 6) {
                Text("ClipStack")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Version 1.0.0")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Text("Your clipboard, supercharged with AI.\nMade with NaturalLanguage + Vision + CloudKit.")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .tabItem { Label("About", systemImage: "info.circle.fill") }
    }
}

// MARK: - Components

struct SettingToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, design: .rounded))
            }
        }
        .toggleStyle(.switch)
    }
}

struct AIStatusRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "10b981"))
        }
    }
}

struct ShortcutRow: View {
    let action: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(action)
                .font(.system(size: 13, design: .rounded))
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
                )
        }
    }
}

struct CompRowHeader: View {
    var body: some View {
        HStack {
            Text("Feature")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Free")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 80)
            Text("Pro")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct CompRow: View {
    let f: String
    let free: String
    let pro: String

    var body: some View {
        HStack {
            Text(f)
                .font(.system(size: 12, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(free)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 80)
            Text(pro)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "10b981"))
                .frame(width: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .json

    var body: some View {
        VStack(spacing: 20) {
            Text("Export Clipboard History")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Picker("Format", selection: $selectedFormat) {
                Text("JSON").tag(ExportFormat.json)
                Text("CSV").tag(ExportFormat.csv)
                Text("Markdown").tag(ExportFormat.markdown)
                Text("HTML").tag(ExportFormat.html)
            }
            .pickerStyle(.segmented)
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Export") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 400)
    }
}
