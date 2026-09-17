import SwiftUI

struct ThemesView: View {
    @State private var themeManager = ThemeManager.shared

    private let accentColors: [(id: String, name: String, color: Color)] = [
        ("blue", "Ocean", .blue),
        ("purple", "Violet", .purple),
        ("pink", "Rose", .pink),
        ("red", "Cherry", .red),
        ("orange", "Sunset", .orange),
        ("yellow", "Gold", .yellow),
        ("green", "Emerald", .green),
        ("mint", "Mint", .mint)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "paintpalette.fill").font(.system(size: 20))
                                .foregroundStyle(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text("Themes").font(.system(size: 28, weight: .bold))
                        }
                        Text("Customize your ClipStack appearance").font(.system(size: 14)).foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) { Image(systemName: "crown.fill").font(.system(size: 12)); Text("PRO").font(.system(size: 11, weight: .bold)) }
                        .foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 6)
                        .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)).clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Appearance").font(.system(size: 16, weight: .semibold))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            themeCard(theme)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Accent Color").font(.system(size: 16, weight: .semibold))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(accentColors, id: \.id) { accent in
                            accentButton(accent)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Card Style").font(.system(size: 16, weight: .semibold))
                    HStack(spacing: 12) {
                        cardStyleBtn(title: "Glass", icon: "drop.fill", isSelected: true)
                        cardStyleBtn(title: "Solid", icon: "square.fill", isSelected: false)
                        cardStyleBtn(title: "Outlined", icon: "square.dashed", isSelected: false)
                    }
                }
            }.padding(24)
        }
    }

    private func themeCard(_ theme: AppTheme) -> some View {
        Button(action: { themeManager.setTheme(theme) }) {
            VStack(spacing: 10) {
                Image(systemName: theme.icon).font(.system(size: 24))
                    .foregroundColor(themeManager.currentTheme == theme ? .white : .primary)
                Text(theme.displayName).font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme == theme ? .white : .primary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14).fill(
                themeManager.currentTheme == theme ?
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [Color(nsColor: .controlBackgroundColor)], startPoint: .topLeading, endPoint: .bottomTrailing)
            ))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(themeManager.currentTheme == theme ? Color.clear : Color.secondary.opacity(0.15), lineWidth: 1))
            .shadow(color: themeManager.currentTheme == theme ? .blue.opacity(0.3) : .clear, radius: 8, y: 4)
        }.buttonStyle(.plain)
    }

    private func accentButton(_ accent: (id: String, name: String, color: Color)) -> some View {
        Button(action: { themeManager.setAccentColor(accent.id) }) {
            VStack(spacing: 6) {
                Circle().fill(accent.color).frame(width: 36, height: 36)
                    .overlay(Circle().stroke(.white, lineWidth: 2).opacity(themeManager.accentColorName == accent.id ? 1 : 0))
                    .shadow(color: themeManager.accentColorName == accent.id ? accent.color.opacity(0.4) : .clear, radius: 6)
                Text(accent.name).font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(themeManager.accentColorName == accent.id ? accent.color.opacity(0.1) : Color(nsColor: .controlBackgroundColor).opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(themeManager.accentColorName == accent.id ? accent.color : Color.clear, lineWidth: 2))
        }.buttonStyle(.plain)
    }

    private func cardStyleBtn(title: String, icon: String, isSelected: Bool) -> some View {
        Button(action: {}) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(isSelected ? .white : .primary)
                Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ?
                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                LinearGradient(colors: [Color(nsColor: .controlBackgroundColor)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        }.buttonStyle(.plain)
    }
}
