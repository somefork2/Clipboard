import AppKit
import SwiftData
import SwiftUI

struct ClipboardListView: View {
    let items: [ClipboardItem]
    let searchText: String
    @Binding var typeFilter: ContentType?

    @Environment(ClipboardStore.self) private var store
    @State private var selection: PersistentIdentifier?
    @State private var previewItem: ClipboardItem?

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            content
        }
        .sheet(item: $previewItem) { item in
            ClipPreviewSheet(item: item) { previewItem = nil }
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                FilterChip(title: "All", isSelected: typeFilter == nil) { typeFilter = nil }
                ForEach(availableTypes, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        systemImage: type.systemImage,
                        isSelected: typeFilter == type
                    ) {
                        typeFilter = typeFilter == type ? nil : type
                    }
                }
            }
            .padding(.horizontal, Theme.Metric.gutter)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.never)
    }

    /// Only offer filters for types that actually occur in the history.
    private var availableTypes: [ContentType] {
        let present = Set(store.items.map(\.type))
        return ContentType.allCases.filter { present.contains($0) }
    }

    // MARK: - List

    @ViewBuilder
    private var content: some View {
        if items.isEmpty {
            EmptyStateView(
                icon: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass",
                title: searchText.isEmpty ? "No clips here yet" : "No matches",
                message: searchText.isEmpty
                    ? "Copy anything and it appears here. Press ⌥⌘V anywhere to paste it back."
                    : "Nothing matches “\(searchText)”."
            )
        } else {
            List(items, selection: $selection) { item in
                ClipboardItemRow(
                    item: item,
                    onPaste: { paste(item, plainText: false) },
                    onPreview: { previewItem = item }
                )
                .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                .contextMenu {
                    ClipContextMenu(
                        item: item,
                        onPaste: { paste(item, plainText: false) },
                        onPastePlain: { paste(item, plainText: true) },
                        onPreview: { previewItem = item }
                    )
                }
            }
            .listStyle(.inset)
            .alternatingRowBackgrounds()
            .contextMenu {
                Button("Clear History…") {
                    NotificationCenter.default.post(name: .clipStackRequestClearHistory, object: nil)
                }
            }
            .onDeleteCommand { deleteSelection() }
        }
    }

    private func paste(_ item: ClipboardItem, plainText: Bool) {
        guard let content = item.pasteContent else { return }
        store.recordUse(item)
        StatisticsTracker.shared.recordPaste()
        PasteService.write(content, plainText: plainText)
    }

    private func deleteSelection() {
        guard let selection,
              let item = items.first(where: { $0.persistentModelID == selection }) else { return }
        store.delete(item)
    }
}

struct FilterChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.small)
                }
                Text(title)
            }
            .font(.callout)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                isSelected ? AnyShapeStyle(Theme.accent.opacity(0.18)) : AnyShapeStyle(Theme.secondaryBackground),
                in: Capsule()
            )
            .overlay(Capsule().stroke(isSelected ? Theme.accent.opacity(0.5) : Theme.separator, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
