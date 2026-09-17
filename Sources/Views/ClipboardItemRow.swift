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
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        LinearGradient(colors: [Color(hex: "1a1a2e"), Color(hex: "0f172a")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())
            }

            // Content type icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(categoryColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(categoryColor.opacity(0.15), lineWidth: 1)
                    )

                if item.type == .image, let thumbData = item.imageThumbnail, let nsImage = NSImage(data: thumbData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: item.type.systemImage)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(categoryColor)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(item.displayTitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    if item.aiConfidence > 0.7 {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(hex: "8b5cf6"))
                    }

                    if item.extractedText != nil {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(hex: "f59e0b"))
                    }
                }

                HStack(spacing: 6) {
                    if let app = item.sourceApp {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 4, height: 4)
                            Text(app)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.secondary)
                    }

                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    Text(item.createdAt.relativeFormatted)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)

                    if let lang = item.detectedLanguage {
                        Circle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 3, height: 3)
                        Text(lang.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }

                // Tags
                if !item.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.tags.prefix(4), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(tagColor(for: tag))
                                .clipShape(Capsule())
                        }
                    }
                }

                // Entities
                if !item.entities.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(item.entities.prefix(3)) { entity in
                            HStack(spacing: 4) {
                                Image(systemName: entity.type.icon)
                                    .font(.system(size: 8, weight: .semibold))
                                Text(entity.value)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

                // Sentiment
                if item.sentiment != 0 {
                    HStack(spacing: 5) {
                        Image(systemName: item.sentiment > 0 ? "face.smiling.fill" : "face.dashed")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(item.sentiment > 0 ? Color(hex: "10b981") : Color(hex: "ef4444"))
                        Text(item.sentiment > 0 ? "Positive" : "Negative")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 6) {
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "f59e0b"))
                }
                actionBtn(icon: "doc.on.doc.fill", color: Color(hex: "3b82f6")) {
                    onCopy()
                    showCopied()
                }
                if let onAddToStack {
                    actionBtn(icon: "plus.rectangle.fill", color: Color(hex: "8b5cf6")) {
                        onAddToStack()
                    }
                }
                actionBtn(
                    icon: item.isFavorite ? "star.slash.fill" : "star.fill",
                    color: item.isFavorite ? Color(hex: "f59e0b") : Color.secondary.opacity(0.5)
                ) {
                    onFavorite()
                }
                actionBtn(icon: "trash.fill", color: Color(hex: "ef4444")) {
                    onDelete()
                }
            }
            .opacity(isHovered ? 1 : 0.3)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isHovered ? Color.secondary.opacity(0.1) : Color.clear, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(isHovered ? 0.06 : 0), radius: isHovered ? 8 : 0, y: isHovered ? 4 : 0)
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
                Text("Copied!")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "10b981"))
                    .clipShape(Capsule())
                    .transition(.scale.combined(with: .opacity))
                    .offset(y: -12)
            }
        }
    }

    private func actionBtn(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var categoryColor: Color {
        switch item.category {
        case "code": return Color(hex: "10b981")
        case "links": return Color(hex: "8b5cf6")
        case "contacts": return Color(hex: "ec4899")
        case "addresses": return Color(hex: "f59e0b")
        case "notes": return Color(hex: "06b6d4")
        default: return Color(hex: "3b82f6")
        }
    }

    private func tagColor(for tag: String) -> Color {
        switch tag {
        case "todo": return Color(hex: "f59e0b")
        case "meeting": return Color(hex: "3b82f6")
        case "deadline": return Color(hex: "ef4444")
        case "sensitive": return Color(hex: "ef4444")
        case "bug": return Color(hex: "ef4444")
        case "idea": return Color(hex: "f59e0b")
        case "link": return Color(hex: "8b5cf6")
        case "email": return Color(hex: "ec4899")
        case "phone": return Color(hex: "06b6d4")
        case "company": return Color(hex: "6366f1")
        default: return Color.secondary
        }
    }

    private func showCopied() {
        withAnimation(.spring(response: 0.3)) { showCopyAnim = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { showCopyAnim = false }
        }
    }
}
