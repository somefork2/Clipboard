import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarSection

    @Environment(ClipboardStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(\.openSettings) private var openSettings

    @State private var editingBoard: Pinboard?
    @State private var isCreatingBoard = false

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                Label("History", systemImage: "clock")
                    .badge(store.items.count)
                    .tag(SidebarSection.history)

                Label("Favourites", systemImage: "star")
                    .badge(store.items.count(where: \.isFavorite))
                    .tag(SidebarSection.favorites)

                Label("Paste Stack", systemImage: "square.stack")
                    .badge(PasteStackManager.shared.stackItems.count)
                    .tag(SidebarSection.pasteStack)
            }

            Section {
                ForEach(store.pinboards) { board in
                    Label {
                        Text(board.name)
                    } icon: {
                        Image(systemName: board.icon)
                            .foregroundStyle(Color.named(board.color))
                    }
                    .badge(board.items.count)
                    .tag(SidebarSection.pinboard(board.id))
                    .contextMenu {
                        Button("Edit…") { editingBoard = board }
                        Button("Delete Pinboard", role: .destructive) {
                            store.deletePinboard(board)
                        }
                    }
                }
                .onMove { store.movePinboards(from: $0, to: $1) }
            } header: {
                HStack {
                    Text("Pinboards")
                    Spacer()
                    Button {
                        startCreatingPinboard()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .help("New pinboard")
                }
            }

            Section("Insights") {
                Label("Statistics", systemImage: "chart.bar")
                    .tag(SidebarSection.statistics)
            }
        }
        .listStyle(.sidebar)
        .themedScrollBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) { settingsRow }
        .safeAreaInset(edge: .bottom) { statusFooter }
        .sheet(isPresented: $isCreatingBoard) {
            PinboardEditor(board: nil) { isCreatingBoard = false }
        }
        .sheet(item: $editingBoard) { board in
            PinboardEditor(board: board) { editingBoard = nil }
        }
    }

    private func startCreatingPinboard() {
        let limit = subscriptions.pinboardLimit
        if limit >= 0 && store.pinboards.count >= limit {
            subscriptions.requestAccess(for: .unlimitedPinboards)
            return
        }
        isCreatingBoard = true
    }

    /// Settings sits at the foot of the sidebar, where a utility's preferences
    /// are easiest to find — not everyone reaches for ⌘, or the app menu.
    private var settingsRow: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Settings (⌘,)")

                Button {
                    AppCoordinator.shared.showSetupGuide()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Setup guide")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    /// Where the user stands, stated plainly and without a modal.
    ///
    /// During the trial it counts down; afterwards it says what the free plan
    /// actually keeps. Nothing is shown to a subscriber.
    @ViewBuilder
    private var statusFooter: some View {
        if !subscriptions.isPro {
            VStack(alignment: .leading, spacing: 5) {
                Divider()

                if subscriptions.isInFreeTrial {
                    let trial = TrialManager.shared
                    HStack {
                        Text("Trial")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text("\(trial.daysRemaining) \(trial.daysRemaining == 1 ? "day" : "days") left")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(
                        value: max(0, TrialManager.duration - trial.endDate.timeIntervalSinceNow),
                        total: TrialManager.duration
                    )
                    .progressViewStyle(.linear)
                    Text("Everything is unlocked. Afterwards CopyWell keeps the last 48 hours.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Free plan")
                        .font(.caption.weight(.medium))
                    Text("The last 48 hours are kept. Favourites and pinboards are never removed.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("See CopyWell Pro") { subscriptions.showingPaywall = true }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }
}
