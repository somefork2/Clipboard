import AppKit
import SwiftUI

/// The palette shown by ⌥⌘V, and the menu bar's "quick look" at the clipboard.
///
/// Entirely keyboard-driven: type to filter, ↑↓ to move, ⌘1–9 to jump, ⏎ to
/// paste, ⌥⏎ to paste without formatting, Space to preview, ⌘⌫ to delete.
struct QuickPasteView: View {
    let onSelect: (ClipboardItem, Bool) -> Void
    let onDismiss: () -> Void

    @Environment(ClipboardStore.self) private var store
    @State private var searchText = ""
    @State private var selection = 0
    @State private var previewItem: ClipboardItem?
    @FocusState private var searchFocused: Bool

    private var results: [ClipboardItem] {
        let all = store.items
        guard !searchText.isEmpty else { return Array(all.prefix(200)) }
        let query = searchText.lowercased()
        return all.filter { $0.searchCorpus.contains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            content
            Divider()
            footer
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.separator, lineWidth: 0.5)
        )
        .onAppear { searchFocused = true }
        .onChange(of: searchText) { selection = 0 }
        .sheet(item: $previewItem) { item in
            ClipPreviewSheet(item: item) { previewItem = nil }
        }
    }

    // MARK: - Sections

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clips", text: $searchText)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($searchFocused)
                .onSubmit { pasteSelected(plainText: false) }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var content: some View {
        if results.isEmpty {
            EmptyStateView(
                icon: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass",
                title: searchText.isEmpty ? "Nothing copied yet" : "No matches",
                message: searchText.isEmpty
                    ? "Copy something and it will appear here."
                    : "No clip contains “\(searchText)”."
            )
            .frame(height: 200)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                            QuickPasteRow(
                                item: item,
                                index: index,
                                isSelected: index == selection
                            )
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selection = index
                                onSelect(item, false)
                            }
                            .onHover { if $0 { selection = index } }
                        }
                    }
                    .padding(6)
                }
                .onChange(of: selection) { _, new in
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(new, anchor: .center) }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            ShortcutHint(keys: "↩", label: "Paste")
            ShortcutHint(keys: "⌥↩", label: "Plain")
            ShortcutHint(keys: "⌘1–9", label: "Jump")
            ShortcutHint(keys: "Space", label: "Preview")
            Spacer()
            Text("\(results.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .overlay(alignment: .center) { keyboardCommands }
    }

    /// Invisible buttons that carry the palette's key equivalents.
    private var keyboardCommands: some View {
        ZStack {
            Button("") { move(by: 1) }.keyboardShortcut(.downArrow, modifiers: [])
            Button("") { move(by: -1) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("") { move(by: 8) }.keyboardShortcut(.pageDown, modifiers: [])
            Button("") { move(by: -8) }.keyboardShortcut(.pageUp, modifiers: [])
            Button("") { pasteSelected(plainText: false) }.keyboardShortcut(.return, modifiers: [])
            Button("") { pasteSelected(plainText: true) }.keyboardShortcut(.return, modifiers: .option)
            Button("") { togglePreview() }.keyboardShortcut(.space, modifiers: [])
            Button("") { deleteSelected() }.keyboardShortcut(.delete, modifiers: .command)
            Button("") { searchFocused = true }.keyboardShortcut("f", modifiers: .command)
            Button("") { onDismiss() }.keyboardShortcut(.escape, modifiers: [])
            ForEach(1...9, id: \.self) { number in
                Button("") { jump(to: number - 1) }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
            }
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    // MARK: - Actions

    private func move(by delta: Int) {
        guard !results.isEmpty else { return }
        selection = min(max(selection + delta, 0), results.count - 1)
    }

    private func jump(to index: Int) {
        guard results.indices.contains(index) else { return }
        selection = index
        onSelect(results[index], false)
    }

    private func pasteSelected(plainText: Bool) {
        guard results.indices.contains(selection) else { return }
        onSelect(results[selection], plainText)
    }

    private func togglePreview() {
        // Space types a space while the user is searching; preview only when the
        // search field is empty.
        guard searchText.isEmpty, results.indices.contains(selection) else { return }
        previewItem = results[selection]
    }

    private func deleteSelected() {
        guard results.indices.contains(selection) else { return }
        store.delete(results[selection])
        selection = min(selection, max(results.count - 2, 0))
    }
}

struct QuickPasteRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            if index < 9 {
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isSelected ? .primary : .tertiary)
                    .frame(width: 14)
            } else {
                Spacer().frame(width: 14)
            }

            if let thumbnail = item.thumbnailImage {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Theme.Metric.iconSize, height: Theme.Metric.iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.corner))
            } else {
                TypeBadge(type: item.type)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.previewText)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 4) {
                    if let app = item.sourceApp {
                        Text(app)
                        Text("·")
                    }
                    Text(item.createdAt.relativeFormatted)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: Theme.Metric.rowHeight)
        .background(isSelected ? Theme.selection.opacity(0.25) : .clear,
                    in: RoundedRectangle(cornerRadius: Theme.Metric.corner))
    }
}

/// Space-bar preview, the Quick Look equivalent for a clip.
struct ClipPreviewSheet: View {
    let item: ClipboardItem
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TypeBadge(type: item.type)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(item.type.displayName) · \(item.sourceApp ?? "Unknown") · \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }

            Divider()

            ScrollView {
                if let thumbnail = item.imageData.flatMap(NSImage.init(data:)) {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                } else if item.isSensitive {
                    Text("This item is stored encrypted and is not shown in previews.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(item.displayBody)
                        .font(item.type == .code ? .body.monospaced() : .body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let ocr = item.extractedText, item.type == .image {
                    Divider().padding(.vertical, 8)
                    Text("Recognised text")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(ocr)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .frame(width: 520, height: 420)
    }
}
