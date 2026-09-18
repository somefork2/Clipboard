import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarSection

    @Environment(ClipboardStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscriptions

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
                Button("See CopyWell Pro") { subscriptions.showingPaywall = true }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }
}
