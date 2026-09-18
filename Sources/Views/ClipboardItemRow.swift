import AppKit
import SwiftUI

/// One row of clipboard history.
///
/// Fixed height, monochrome symbols, no gradients: the list should read like
/// Mail or Xcode's navigator, dense and scannable, not like a card feed.
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onPaste: () -> Void
    let onPreview: () -> Void

    @Environment(ClipboardStore.self) private var store
    @State private var isHovered = false
    @State private var showCopiedTick = false

    var body: some View {
        HStack(spacing: 10) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(item.previewText)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(item.isSensitive ? .secondary : .primary)

                HStack(spacing: 5) {
                    Text(item.type.displayName)
                    if let app = item.sourceApp {
                        Text("·")
                        Text(app)
                    }
                    Text("·")
                    Text(item.createdAt.relativeFormatted)
                    if !item.tags.isEmpty {
                        Text("·")
                        Text(item.tags.prefix(2).joined(separator: ", "))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 6)

            if showCopiedTick {
                Image(systemName: "checkmark")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if isHovered {
                actions
            } else if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: Theme.Metric.rowHeight)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
        .onTapGesture(count: 2) { onPaste() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.type.displayName). \(item.previewText)")
        .accessibilityHint("Double-tap to paste")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = item.thumbnailImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: Theme.Metric.iconSize, height: Theme.Metric.iconSize)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.corner))
        } else {
            TypeBadge(type: item.type)
        }
    }

    private var actions: some View {
        HStack(spacing: 2) {
            rowButton("eye", help: "Quick Look", action: onPreview)
            rowButton(item.isFavorite ? "star.fill" : "star", help: "Favourite") {
                store.toggleFavorite(item)
            }
            rowButton("doc.on.doc", help: "Copy") {
                guard let content = item.pasteContent else { return }
                PasteService.write(content)
                store.recordUse(item)
                withAnimation { showCopiedTick = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation { showCopiedTick = false }
                }
            }
            rowButton("trash", help: "Delete") { store.delete(item) }
        }
    }

    private func rowButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.callout)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
