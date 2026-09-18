import AppKit
import SwiftUI

/// The menu bar popover: the whole point is seeing and pasting recent clips
/// without ever opening the app window.
struct MenuBarContentView: View {
    @Environment(ClipboardStore.self) private var store
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    @State private var searchText = ""
    @State private var previewItem: ClipboardItem?

    private var results: [ClipboardItem] {
        guard !searchText.isEmpty else { return store.recent(limit: 12) }
        let query = searchText.lowercased()
        return Array(store.items.filter { $0.searchCorpus.contains(query) }.prefix(30))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 340)
        .sheet(item: $previewItem) { item in
            ClipPreviewSheet(item: item) { previewItem = nil }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.callout)
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var list: some View {
        if results.isEmpty {
            EmptyStateView(
                icon: "doc.on.clipboard",
                title: searchText.isEmpty ? "Nothing yet" : "No matches",
                message: searchText.isEmpty ? "Copy something to get started." : "Try another search."
            )
            .frame(height: 140)
        } else {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(results) { item in
                        Button {
                            paste(item)
                        } label: {
                            MenuBarRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            ClipContextMenu(
                                item: item,
                                onPaste: { paste(item) },
                                onPastePlain: { paste(item, plainText: true) },
                                onPreview: { previewItem = item }
                            )
                        }
                    }
                }
                .padding(6)
            }
            // A ScrollView has no intrinsic height: inside a popover that sizes
            // itself to its content it collapses to nothing, so the list has to
            // state how tall it wants to be.
            .frame(height: listHeight)
        }
    }

    /// Tall enough for the rows we have, capped so the popover never runs off
    /// the screen.
    private var listHeight: CGFloat {
        let rows = CGFloat(results.count)
        let content = rows * (Theme.Metric.compactRowHeight + 1) + 12
        return min(max(content, Theme.Metric.compactRowHeight + 12), 420)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if coordinator.isPaused {
                Label("Recording paused", systemImage: "pause.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }
            HStack(spacing: 10) {
                Button("Open ClipStack") {
                    coordinator.openMainWindow()
                }
                .buttonStyle(.link)

                Button(coordinator.isPaused ? "Resume" : "Pause") {
                    coordinator.togglePause()
                }
                .buttonStyle(.link)

                Spacer()

                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .help("Quit ClipStack")
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func paste(_ item: ClipboardItem, plainText: Bool = false) {
        guard let content = item.pasteContent else { return }
        store.recordUse(item)
        StatisticsTracker.shared.recordPaste()
        PasteService.paste(content, plainText: plainText)
    }
}

struct MenuBarRow: View {
    let item: ClipboardItem
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 9) {
            if let thumbnail = item.thumbnailImage {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                TypeBadge(type: item.type, size: 22)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(item.previewText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.createdAt.relativeFormatted)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: Theme.Metric.compactRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovered ? Theme.selection.opacity(0.25) : .clear,
                    in: RoundedRectangle(cornerRadius: Theme.Metric.corner))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
