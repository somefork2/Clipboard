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
        HStack(spacing: 10) {
            // Number badge (for paste stack)
            if let index {
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color(hex: "1a1a2e"))
                    .clipShape(Circle())
            }

            // Content type icon - smaller
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(categoryColor.opacity(0.1))
                    .frame(width: 36, height: 36)

                if item.type == .image, let thumbData = item.imageThumbnail, let nsImage = NSImage(data: thumbData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: item.type.systemImage)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(categoryColor.opacity(0.8))
                }
            }

            // Content - compact, adaptive
            VStack(alignment: .leading, spacing: 3) {
                // Title row with badges
                HStack(spacing: 6) {
                    Text(item.displayTitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    if item.aiConfidence > 0.7 {
                        Image(systemName: "sparkle")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: "8b5cf6"))
                    }

                    if item.extractedText != nil {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: "f59e0b"))
                    }

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: "f59e0b"))
                    }

                    Spacer(minLength: 0)
                }

                // Metadata row
                HStack(spacing: 5) {
                    if let app = item.sourceApp {
                        Text(app)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Text("·")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text(item.createdAt.relativeFormatted)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)

                    if let lang = item.detectedLanguage {
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(lang.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Spacer(minLength: 0)

                    // Tags inline
                    if !item.tags.isEmpty {
                        ForEach(item.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(tagColor(for: tag))
                                .clipShape(Capsule())
                        }
                    }

                    // Entities inline
                    if !item.entities.isEmpty {
                        ForEach(item.entities.prefix(2)) { entity in
                            HStack(spacing: 2) {
                                Image(systemName: entity.type.icon)
                                    .font(.system(size: 7, weight: .bold))
                                Text(entity.value)
                                    .font(.system(size: 8, weight: .medium, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    // Sentiment inline
                    if item.sentiment != 0 {
                        HStack(spacing: 2) {
                            Image(systemName: item.sentiment > 0 ? "face.smiling.fill" : "face.dashed")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(item.sentiment > 0 ? Color(hex: "10b981") : Color(hex: "ef4444"))
                        }
                    }

                    // Source URL for links
                    if item.type == .url, let url = item.url {
                        Text(URL(string: url)?.host() ?? url)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "3b82f6"))
                            .lineLimit(1)
                    }

                    // OCR text preview
                    if let ocr = item.extractedText {
                        Text(ocr)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 4)

            // Actions - compact
            HStack(spacing: 4) {
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
                    color: item.isFavorite ? Color(hex: "f59e0b") : Color.secondary.opacity(0.4)
                ) {
                    onFavorite()
                }
                actionBtn(icon: "trash.fill", color: Color(hex: "ef4444")) {
                    onDelete()
                }
            }
            .opacity(isHovered ? 1 : 0.2)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isHovered ? Color.secondary.opacity(0.08) : Color.clear, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering } }
        .onTapGesture { onSelect() }
        .contextMenu {
            Button(action: { onCopy(); showCopied() }) { Label("Copy", systemImage: "doc.on.doc.fill") }
            Button(action: onFavorite) { Label(item.isFavorite ? "Unfavorite" : "Favorite", systemImage: item.isFavorite ? "star.slash.fill" : "star.fill") }
            if let onAddToStack { Button(action: onAddToStack) { Label("Add to Paste Stack", systemImage: "plus.rectangle.fill") } }
            Divider()
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash.fill") }
        }
        .overlay(alignment: .topTrailing) {
            if showCopyAnim {
                Text("Copied!")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "10b981"))
                    .clipShape(Capsule())
                    .transition(.scale.combined(with: .opacity))
                    .offset(y: -8)
            }
        }
    }

    private func actionBtn(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color.opacity(0.7))
                .frame(width: 22, height: 22)
                .background(color.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 5))
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
        case "deadline", "sensitive", "bug": return Color(hex: "ef4444")
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { showCopyAnim = false }
        }
    }
}
