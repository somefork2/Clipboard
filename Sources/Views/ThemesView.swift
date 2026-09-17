import SwiftUI

struct ThemesView: View {
    @State private var themeManager = ThemeManager.shared
    @State private var selectedAccent = "blue"

    private let accentColors: [(id: String, name: String, color: Color, secondary: Color)] = [
        ("blue", "Ocean", .blue, .cyan),
        ("indigo", "Indigo", .indigo, .purple),
        ("purple", "Violet", .purple, .pink),
        ("pink", "Rose", .pink, .red),
        ("red", "Cherry", .red, .orange),
        ("orange", "Sunset", .orange, .yellow),
        ("green", "Emerald", .green, .mint),
        ("teal", "Teal", .teal, .cyan)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "paintbrush.pointed.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text("Themes")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                        }
                        Text("Customize your ClipStack appearance")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("PRO")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(
                        LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                }

                // Live preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    HStack(spacing: 16) {
                        // Mini sidebar
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 28, height: 28)
                                Text("ClipStack")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }

                            ForEach(["History", "Favorites", "Paste Stack"], id: \.self) { item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(item == "History" ? Color.blue : Color.secondary.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                    Text(item)
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(item == "History" ? .primary : .secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(14)
                        .frame(width: 150)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                        )

                        // Mini content area
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "doc.text.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sample Content")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    Text("Preview card")
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.ultraThinMaterial)
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                        )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                        )
                )

                // Appearance modes
                VStack(alignment: .leading, spacing: 16) {
                    Text("Appearance")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            themeCard(theme)
                        }
                    }
                }

                // Accent colors
                VStack(alignment: .leading, spacing: 16) {
                    Text("Accent Color")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(accentColors, id: \.id) { accent in
                            accentButton(accent)
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private func themeCard(_ theme: AppTheme) -> some View {
        Button(action: { themeManager.setTheme(theme) }) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.currentTheme == theme ?
                            LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.secondary.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: theme.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme == theme ? .white : .primary)
                }

                VStack(spacing: 2) {
                    Text(theme.displayName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(theme == .system ? "Auto" : theme == .dark ? "Dimmed" : "Bright")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(themeManager.currentTheme == theme ? Color.indigo : Color.secondary.opacity(0.15), lineWidth: themeManager.currentTheme == theme ? 2 : 1)
                    )
            )
            .shadow(color: themeManager.currentTheme == theme ? .indigo.opacity(0.2) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func accentButton(_ accent: (id: String, name: String, color: Color, secondary: Color)) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                themeManager.setAccentColor(accent.id)
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accent.color, accent.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    if themeManager.accentColorName == accent.id {
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 40, height: 40)
                    }
                    if themeManager.accentColorName == accent.id {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .shadow(color: themeManager.accentColorName == accent.id ? accent.color.opacity(0.4) : .clear, radius: 6)

                Text(accent.name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeManager.accentColorName == accent.id ? accent.color.opacity(0.1) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(themeManager.accentColorName == accent.id ? accent.color : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
