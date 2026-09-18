import AppKit
import SwiftUI

/// The menu bar popover: the whole point is seeing and pasting recent clips
/// without ever opening the app window.
/// Closing the menu bar popover.
///
/// `MenuBarExtra(.window)` hands out no binding or environment action to dismiss
/// itself, and it does not close when something else takes focus. Opening the
/// main window therefore left a small panel stranded on screen with no obvious
/// way to get rid of it. Its window sits at the pop-up-menu level, which nothing
/// else in this app uses, so we can close it the way the system would.
@MainActor
enum MenuBarPopover {
    static func dismiss() {
        for window in NSApp.windows where window.level == .popUpMenu && window.isVisible {
            window.orderOut(nil)
        }
    }
}

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
            if let previewItem {
                Divider()
                InlineClipPreview(item: previewItem) { self.previewItem = nil }
                    .frame(height: 210)
            }
            Divider()
            footer
        }
        .frame(width: 340)
        .elevatedSurface()
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
                            MenuBarRow(item: item) {
                                previewItem = (previewItem?.id == item.id) ? nil : item
                            }
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
                    MenuBarPopover.dismiss()
                    coordinator.openMainWindow()
                }
                .buttonStyle(.link)

                Button(coordinator.isPaused ? "Resume" : "Pause") {
                    coordinator.togglePause()
                }
                .buttonStyle(.link)

                Spacer()

                Button {
                    MenuBarPopover.dismiss()
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
        // The popover has to go before the paste: it is holding focus, and the
        // keystroke needs to land in the app the user came from.
        MenuBarPopover.dismiss()
        guard let content = item.pasteContent else { return }
        store.recordUse(item)
        StatisticsTracker.shared.recordPaste()
        PasteService.deliver(content, plainText: plainText)
    }
}

struct MenuBarRow: View {
    let item: ClipboardItem
    var onPreview: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 9) {
            if let thumbnail = item.thumbnailImage {
                Button { onPreview?() } label: {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Show this image")
            } else {
                TypeBadge(type: item.type, size: 22)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(item.previewText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 4) {
                    if item.type == .image {
                        let summary = item.imageSummary
                        if !summary.isEmpty {
                            Text(summary)
                            Text("·")
                        }
                    }
                    Text(item.createdAt.relativeFormatted)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
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
