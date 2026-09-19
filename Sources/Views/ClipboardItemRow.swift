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
                HStack(spacing: 5) {
                    Text(item.previewText)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(item.isSensitive ? .secondary : .primary)

                    // An image row leads with the text found in it, so mark that
                    // the words come from the picture rather than from a copy.
                    if item.type == .image, item.recognizedFirstLine != nil {
                        Image(systemName: "text.viewfinder")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .help(L("Text recognised in this image"))
                    }
                }

                HStack(spacing: 5) {
                    Text(item.type.displayName)
                    if item.type == .image {
                        let summary = item.imageSummary
                        if !summary.isEmpty {
                            Text("·")
                            Text(summary)
                        }
                    }
                    if let app = item.sourceApp {
                        Text("·")
                        Text(app)
                    }
                    Text("·")
                    Text(item.createdAt.relativeFormatted)
                    if item.type != .image, !item.tags.isEmpty {
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
        .accessibilityLabel(L("\(item.type.displayName). \(item.previewText)"))
        // A Mac is clicked, not tapped. VoiceOver read the iOS wording out
        // loud to people who have no touchscreen.
        .accessibilityHint(L("Double-click to paste"))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = item.thumbnailImage {
            // Clicking the picture is the obvious way to ask "what is this?",
            // so the thumbnail itself opens the preview.
            Button(action: onPreview) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Theme.Metric.iconSize, height: Theme.Metric.iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.corner))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metric.corner)
                            .stroke(Theme.separator, lineWidth: 0.5)
                    )
                    .overlay {
                        if isHovered {
                            RoundedRectangle(cornerRadius: Theme.Metric.corner)
                                .fill(.black.opacity(0.35))
                                .overlay(
                                    Image(systemName: "eye")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                )
                        }
                    }
            }
            .buttonStyle(.plain)
            .help(L("Show this image"))
            .accessibilityLabel(L("Show image"))
        } else {
            // Not only images: clicking the badge of any clip opens its preview,
            // which is the only way to read a long clip in full.
            Button(action: onPreview) {
                TypeBadge(type: item.type)
                    .overlay {
                        if isHovered {
                            RoundedRectangle(cornerRadius: Theme.Metric.corner)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay(
                                    Image(systemName: "eye")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
            }
            .buttonStyle(.plain)
            .help(L("Show this clip"))
            .accessibilityLabel(L("Show clip"))
        }
    }

    private var actions: some View {
        HStack(spacing: 2) {
            rowButton("eye", help: L("Quick Look"), action: onPreview)
            rowButton(item.isFavorite ? "star.fill" : "star", help: L("Favourite")) {
                store.toggleFavorite(item)
            }
            rowButton("doc.on.doc", help: L("Copy")) {
                guard let content = item.pasteContent else { return }
                PasteService.write(content)
                store.recordUse(item)
                withAnimation { showCopiedTick = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation { showCopiedTick = false }
                }
            }
            rowButton("trash", help: L("Delete")) { store.delete(item) }
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
