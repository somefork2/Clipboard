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
    @State private var exportFormat: ExportFormat = .json
    @State private var showExportSheet = false
    let subscription = SubscriptionManager.shared

    var body: some View {
        TabView {
            // General
            Form {
                Section("Startup") {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                    Toggle("Show in Dock", isOn: $showInDock)
                    Toggle("Show in Menu Bar", isOn: $showInMenuBar)
                }
                Section("History") {
                    Picker("Maximum items", selection: $maxHistoryItems) {
                        Text("100").tag(100); Text("500").tag(500); Text("1,000").tag(1000); Text("5,000").tag(5000); Text("Unlimited").tag(-1)
                    }
                    if !subscription.isPro {
                        HStack { Image(systemName: "info.circle").foregroundColor(.orange); Text("Free plan limited to 100 items").font(.system(size: 12)).foregroundColor(.secondary) }
                    }
                }
                Section("Data") {
                    Button(action: { showExportSheet = true }) { Label("Export History", systemImage: "arrow.up.doc") }
                    Button(role: .destructive) { } label: { Label("Clear All History", systemImage: "trash") }
                }
            }.padding(20).tabItem { Label("General", systemImage: "gear") }

            // Privacy
            Form {
                Section("Clipboard") {
                    Toggle("Skip passwords automatically", isOn: $skipPasswords).toggleStyle(.switch)
                    Toggle("Hide from screen capture", isOn: $hideFromScreenCapture).toggleStyle(.switch)
                }
                Section("Security") {
                    Toggle("Require authentication", isOn: .constant(false)).toggleStyle(.switch)
                }
            }.padding(20).tabItem { Label("Privacy", systemImage: "lock.shield") }

            // Shortcuts
            Form {
                Section("Global Shortcuts") {
                    ShortcutRow(action: "Open Quick Paste", shortcut: "⌥⌘V")
                    ShortcutRow(action: "Toggle Pause", shortcut: "⌃⌥P")
                    ShortcutRow(action: "Open Main Window", shortcut: "⌃⌥⌘C")
                }
                Section("Quick Paste (⌘1-9)") {
                    Toggle("Enable number shortcuts", isOn: .constant(true)).toggleStyle(.switch)
                    Text("Press ⌘1 through ⌘9 to paste the last 9 copied items instantly.").font(.system(size: 12)).foregroundColor(.secondary)
                }
                Section("Pause/Resume") {
                    Toggle("Pause clipboard monitoring", isOn: .constant(false)).toggleStyle(.switch)
                    Text("When paused, ClipStack won't save new clips.").font(.system(size: 12)).foregroundColor(.secondary)
                }
            }.padding(20).tabItem { Label("Shortcuts", systemImage: "command") }

            // AI
            Form {
                Section("AI Processing") {
                    HStack {
                        Image(systemName: "brain.head.profile").foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text("Smart Categorization").font(.system(size: 14, weight: .medium))
                            Text("Auto-categorize clips using NaturalLanguage + Apple Intelligence").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    }
                    HStack {
                        Image(systemName: "text.magnifyingglass").foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Entity Extraction").font(.system(size: 14, weight: .medium))
                            Text("Extract emails, phones, names, addresses from text").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    }
                    HStack {
                        Image(systemName: "eye.fill").foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text("OCR (Text from Images)").font(.system(size: 14, weight: .medium))
                            Text("Recognize text in screenshots using Vision framework").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    }
                }
                Section("Language Support") {
                    Text("Supported: English, Russian, Ukrainian, German, French, Spanish, Japanese, Chinese, Korean").font(.system(size: 12)).foregroundColor(.secondary)
                }
            }.padding(20).tabItem { Label("AI", systemImage: "brain.head.profile") }

            // Sync
            Form {
                Section("iCloud") {
                    Toggle("Enable iCloud Sync", isOn: $icloudSync).toggleStyle(.switch)
                    HStack {
                        Image(systemName: "icloud.fill").foregroundColor(.blue)
                        Text("Sync your clipboard history across all your Apple devices")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    }
                }
                Section("Status") {
                    HStack { Text("Last sync:"); Spacer(); Text("Just now").foregroundColor(.secondary) }
                    HStack { Text("Items synced:"); Spacer(); Text("0").foregroundColor(.secondary) }
                    Button("Sync Now") { }.disabled(!icloudSync)
                }
            }.padding(20).tabItem { Label("Sync", systemImage: "icloud") }

            // Subscription
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Plan").font(.system(size: 12)).foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            Image(systemName: subscription.isPro ? "crown.fill" : "person.fill").font(.system(size: 20)).foregroundColor(subscription.isPro ? .yellow : .secondary)
                            Text(subscription.isPro ? "Pro Plan" : "Free Plan").font(.system(size: 20, weight: .bold))
                        }
                    }
                    Spacer()
                    if !subscription.isPro {
                        Button(action: { showPaywall = true }) { Text("Upgrade").font(.system(size: 14, weight: .semibold)).foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 10).background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)).clipShape(Capsule()) }.buttonStyle(.plain)
                    }
                }.padding(16).background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                VStack(alignment: .leading, spacing: 8) {
                    CompRow(f: "Clipboard History", free: "100 items", pro: "Unlimited")
                    CompRow(f: "Pinboards", free: "1", pro: "Unlimited")
                    CompRow(f: "AI Features", free: "✓ Basic", pro: "✓ Full")
                    CompRow(f: "Paste Stack", free: "—", pro: "✓")
                    CompRow(f: "Export", free: "—", pro: "✓")
                    CompRow(f: "Themes", free: "—", pro: "✓")
                    CompRow(f: "iCloud Sync", free: "✓", pro: "✓")
                }
            }.padding(20).tabItem { Label("Subscription", systemImage: "crown.fill") }

            // About
            VStack(spacing: 20) {
                ZStack { Circle().fill(LinearGradient(colors: [.blue.opacity(0.15), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 80, height: 80); Image(systemName: "clipboard.fill").font(.system(size: 36)).foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)) }
                VStack(spacing: 6) { Text("ClipStack").font(.system(size: 24, weight: .bold)); Text("Version 1.0.0").font(.system(size: 13)).foregroundColor(.secondary) }
                Text("Your clipboard, supercharged with AI.\nMade with NaturalLanguage + Vision + CloudKit.").font(.system(size: 13)).foregroundColor(.secondary).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(20).tabItem { Label("About", systemImage: "info.circle") }
        }.frame(width: 520, height: 400).sheet(isPresented: $showPaywall) { PaywallView() }.sheet(isPresented: $showExportSheet) { ExportSheet() }
    }
}

struct ShortcutRow: View { let action: String; let shortcut: String; var body: some View { HStack { Text(action).font(.system(size: 13)); Spacer(); Text(shortcut).font(.system(size: 13, weight: .medium, design: .monospaced)).padding(.horizontal, 10).padding(.vertical, 5).background(Color(nsColor: .controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 6)) } } }
struct CompRow: View { let f: String; let free: String; let pro: String; var body: some View { HStack { Text(f).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading); Text(free).font(.system(size: 12)).foregroundColor(.secondary).frame(width: 80); Text(pro).font(.system(size: 12, weight: .medium)).foregroundColor(.green).frame(width: 80) }.padding(.vertical, 6) } }

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss; @State private var selectedFormat: ExportFormat = .json
    var body: some View {
        VStack(spacing: 20) {
            Text("Export Clipboard History").font(.headline)
            Picker("Format", selection: $selectedFormat) { Text("JSON").tag(ExportFormat.json); Text("CSV").tag(ExportFormat.csv); Text("Markdown").tag(ExportFormat.markdown); Text("HTML").tag(ExportFormat.html) }.pickerStyle(.segmented)
            HStack { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Button("Export") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 380)
    }
}
