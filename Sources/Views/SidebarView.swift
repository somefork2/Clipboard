import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarSection

    @Environment(ClipboardStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscriptions

    @State private var isCreatingPinboard = false
    @State private var newPinboardName = ""

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
                    Label(board.name, systemImage: board.icon)
                        .badge(board.items.count)
                        .tag(SidebarSection.pinboard(board.id))
                        .contextMenu {
                            Button("Delete Pinboard", role: .destructive) {
                                store.deletePinboard(board)
                            }
                        }
                }
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
        .safeAreaInset(edge: .bottom) { statusFooter }
        .alert("New Pinboard", isPresented: $isCreatingPinboard) {
            TextField("Name", text: $newPinboardName)
            Button("Create") {
                let name = newPinboardName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                store.createPinboard(name: name)
                newPinboardName = ""
            }
            Button("Cancel", role: .cancel) { newPinboardName = "" }
        }
    }

    private func startCreatingPinboard() {
        let limit = subscriptions.pinboardLimit
        if limit >= 0 && store.pinboards.count >= limit {
            subscriptions.requestAccess(for: .unlimitedPinboards)
            return
        }
        isCreatingPinboard = true
    }

    /// Free-tier users should always know where they stand, without a modal.
    @ViewBuilder
    private var statusFooter: some View {
        if !subscriptions.isPro {
            let limit = SubscriptionTier.free.maxItems
            VStack(alignment: .leading, spacing: 5) {
                Divider()
                HStack {
                    Text("Free plan")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text("\(min(store.items.count, limit))/\(limit)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: Double(min(store.items.count, limit)), total: Double(limit))
                    .progressViewStyle(.linear)
                Text("Older clips are removed once you reach the limit.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("See ClipStack Pro") { subscriptions.showingPaywall = true }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }
}
