import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    var index: Int? = nil
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void
    var onAddToStack: (() -> Void)? = nil

    @State private var isHovered = false
    @State private var showCopyAnim = false

    var body: some View {
        HStack(spacing: 14) {
            // Number badge (for paste stack)
            if let index {
                Text("\(index+1)").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Circle())
            }

            // Icon with category color
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [categoryColor.opacity(0.25), categoryColor.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(categoryColor.opacity(0.15), lineWidth: 1)
                    )

                if item.type == .image, let thumbData = item.imageThumbnail, let nsImage = NSImage(data: thumbData) {
                    Image(nsImage: nsImage).resizable().scaledToFill().frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: item.type.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [categoryColor, categoryColor.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.displayTitle).font(.system(size: 13.5, weight: .semibold)).lineLimit(1).foregroundColor(.primary)

                    // AI confidence badge
                    if item.aiConfidence > 0.7 {
                        Image(systemName: "sparkle.id")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom))
                    }

                    // OCR badge
                    if item.extractedText != nil {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                    }
                }

                HStack(spacing: 6) {
                    if let app = item.sourceApp {
                        Label(app, systemImage: "app.fill")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Circle().fill(Color.secondary.opacity(0.4)).frame(width: 3, height: 3)
                    Text(item.createdAt.relativeFormatted).font(.system(size: 11)).foregroundColor(.secondary)

                    // Language badge
                    if let lang = item.detectedLanguage {
                        Circle().fill(Color.secondary.opacity(0.4)).frame(width: 3, height: 3)
                        Text(lang.uppercased()).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.1)).clipShape(Capsule())
                    }
                }

                // Tags
                if !item.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.tags.prefix(4), id: \.self) { tag in
                            Text(tag).font(.system(size: 9, weight: .medium)).foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(tagColor(for: tag)).clipShape(Capsule())
                        }
                    }
                }

                // Entities
                if !item.entities.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(item.entities.prefix(3)) { entity in
                            HStack(spacing: 3) {
                                Image(systemName: entity.type.icon).font(.system(size: 8))
                                Text(entity.value).font(.system(size: 9)).lineLimit(1)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                // Sentiment indicator
                if item.sentiment != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: item.sentiment > 0 ? "face.smiling.fill" : "face.dashed")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(item.sentiment > 0 ? .green : .red)
                        Text(item.sentiment > 0 ? "Positive" : "Negative").font(.system(size: 9, design: .rounded)).foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 6) {
                if item.isFavorite {
                    Image(systemName: "star.fill").font(.system(size: 11))
                        .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                }
                actionBtn(icon: "doc.on.doc", color: .blue) { onCopy(); showCopied() }
                if let onAddToStack { actionBtn(icon: "plus.rectangle.on.rectangle", color: .purple) { onAddToStack() } }
                actionBtn(icon: "star", color: item.isFavorite ? .yellow : .gray) { onFavorite() }
                actionBtn(icon: "trash", color: .red) { onDelete() }
            }.opacity(isHovered ? 1 : 0.4).animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial).opacity(isHovered ? 1 : 0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(isHovered ? 0.12 : 0.04), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.2)) { isHovered = hovering } }
        .onTapGesture { onSelect() }
        .contextMenu {
            Button(action: { onCopy(); showCopied() }) { Label("Copy", systemImage: "doc.on.doc.fill") }
            Button(action: onFavorite) { Label(item.isFavorite ? "Unfavorite" : "Favorite", systemImage: item.isFavorite ? "star.slash.fill" : "star.fill") }
            if let onAddToStack { Button(action: onAddToStack) { Label("Add to Paste Stack", systemImage: "plus.rectangle.fill") } }
            Divider()
            if !item.entities.isEmpty {
                Menu("Copy Entity") {
                    ForEach(item.entities) { entity in
                        Button(entity.value) { NSPasteboard.general.setString(entity.value, forType: .string) }
                    }
                }
            }
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash.fill") }
        }
        .overlay(alignment: .topTrailing) {
            if showCopyAnim {
                Text("Copied!").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5).background(Color.green).clipShape(Capsule())
                    .transition(.scale.combined(with: .opacity)).offset(y: -10)
            }
        }
    }

    private func actionBtn(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color.opacity(0.12))
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(0.15), lineWidth: 0.5)
                    }
                )
        }.buttonStyle(.plain)
    }

    private var categoryColor: Color {
        switch item.category {
        case "code": return .green
        case "links": return .purple
        case "contacts": return .pink
        case "addresses": return .orange
        case "notes": return .cyan
        default: return .blue
        }
    }

    private func tagColor(for tag: String) -> Color {
        switch tag {
        case "todo": return .orange
        case "meeting": return .blue
        case "deadline": return .red
        case "sensitive": return .red
        case "bug": return .red
        case "idea": return .yellow
        case "link": return .purple
        case "email": return .pink
        case "phone": return .cyan
        case "company": return .indigo
        default: return .gray
        }
    }

    private func showCopied() {
        withAnimation(.spring(response: 0.3)) { showCopyAnim = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { showCopyAnim = false } }
    }
}

struct FilterChip: View {
    let title: String; var icon: String? = nil; let isSelected: Bool; var count: Int? = nil; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ?
                        LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing) :
                        LinearGradient(colors: [Color(nsColor: .controlBackgroundColor)], startPoint: .leading, endPoint: .trailing)
                    )
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.15), lineWidth: 0.5)
                    )
            )
            .foregroundColor(isSelected ? .white : .primary)
            .shadow(color: isSelected ? .indigo.opacity(0.3) : .clear, radius: 4, y: 2)
        }.buttonStyle(.plain)
    }
}
