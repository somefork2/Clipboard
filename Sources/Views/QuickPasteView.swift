import SwiftUI

struct QuickPasteView: View {
    let items: [ClipboardItem]; let onSelect: (ClipboardItem) -> Void
    @State private var searchText = ""; @State private var selectedIndex = 0; @Environment(\.dismiss) private var dismiss
    private var filteredItems: [ClipboardItem] { searchText.isEmpty ? items : items.filter { $0.text?.localizedCaseInsensitiveContains(searchText) == true || $0.url?.localizedCaseInsensitiveContains(searchText) == true } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) { Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundColor(.secondary); TextField("Search clips...", text: $searchText).textFieldStyle(.plain).font(.system(size: 15)); if !searchText.isEmpty { Button(action: { searchText = "" }) { Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.secondary) }.buttonStyle(.plain) } }.padding(14)
            Divider()
            ScrollView { LazyVStack(spacing: 3) { ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    Text("\(index+1)").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(index == selectedIndex ? .white : .secondary).frame(width: 22, height: 22).background(Circle().fill(index == selectedIndex ? LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.secondary.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    if item.type == .image, let thumbData = item.imageThumbnail, let nsImage = NSImage(data: thumbData) { Image(nsImage: nsImage).resizable().scaledToFill().frame(width: 34, height: 34).clipShape(RoundedRectangle(cornerRadius: 6)) }
                    else { Image(systemName: item.type.systemImage).font(.system(size: 13)).foregroundColor(.blue).frame(width: 34, height: 34).background(Color.blue.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 6)) }
                    VStack(alignment: .leading, spacing: 3) { Text(item.previewText).font(.system(size: 13, weight: index == selectedIndex ? .medium : .regular)).lineLimit(1); HStack(spacing: 4) { if let app = item.sourceApp { Text(app).font(.system(size: 10)).foregroundColor(.secondary) }; Text("•").font(.system(size: 10)).foregroundColor(.secondary); Text(item.createdAt.relativeFormatted).font(.system(size: 10)).foregroundColor(.secondary) } }
                    Spacer()
                }.padding(.horizontal, 12).padding(.vertical, 9).background(RoundedRectangle(cornerRadius: 8).fill(index == selectedIndex ? LinearGradient(colors: [.blue.opacity(0.12), .purple.opacity(0.08)], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing))).clipShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture { selectedIndex = index; onSelect(item); dismiss() }
                    .onHover { if $0 { selectedIndex = index } }
            }}.padding(10) }
            Divider()
            HStack { HStack(spacing: 12) { ShortcutHint(keys: "⌘1-9", label: "Quick"); ShortcutHint(keys: "↑↓", label: "Nav"); ShortcutHint(keys: "↩", label: "Paste") }; Spacer(); Text("\(filteredItems.count) clips").font(.system(size: 11)).foregroundColor(.secondary) }.padding(12).background(Rectangle().fill(.ultraThinMaterial))
        }.frame(width: 440, height: 520).background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial).shadow(color: .black.opacity(0.2), radius: 30, y: 10))
    }
}

struct ShortcutHint: View { let keys: String; let label: String; var body: some View { HStack(spacing: 4) { Text(keys).font(.system(size: 10, weight: .semibold, design: .monospaced)).padding(.horizontal, 5).padding(.vertical, 2).background(Color(nsColor: .controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 4)); Text(label).font(.system(size: 10)).foregroundColor(.secondary) } } }
