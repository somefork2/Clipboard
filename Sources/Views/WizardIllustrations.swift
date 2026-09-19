import SwiftUI

/// Drawings for the setup guide.
///
/// Built from shapes rather than images: they follow the theme and the accent
/// colour, stay sharp at any size, and add nothing to the bundle. Each one
/// shows the single idea its step is making, so the screen reads before it is
/// read.
enum WizardIllustration {

    // MARK: Step 1 — the language the rest of the guide is read in

    /// The same word, written the way several of the languages on offer write
    /// it. The subject of this step is text, so text is what it draws: shapes
    /// would say nothing about a choice of language.
    struct Language: View {
        /// Fixed on purpose. The picture is about the range on offer, not about
        /// whichever language happens to be selected while it is drawn — and it
        /// should not change under the reader as they try the picker.
        private static let rows = [
            ["Copy", "Copier", "Kopieren", "Copiar"],
            ["Копировать", "コピー", "복사", "نسخ", "复制"],
        ]

        var body: some View {
            VStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.accent)

                // Two rows, so the long words and the short ones both sit
                // comfortably instead of one line scaling itself into a smear.
                VStack(spacing: 6) {
                    ForEach(Self.rows, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(row, id: \.self) { word in
                                Text(word)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    // The neutral used by the other drawings
                                    // here. `Theme.secondaryBackground` sat a
                                    // shade off the card on a light theme and
                                    // the chips disappeared into it.
                                    .background(Color.secondary.opacity(0.14), in: Capsule())
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Step 2 — what it keeps and what it never does

    struct Privacy: View {
        var body: some View {
            HStack(spacing: 26) {
                stack
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                machine
            }
            .frame(maxWidth: .infinity)
        }

        private var stack: some View {
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Theme.secondaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Theme.separator, lineWidth: 0.5)
                        )
                        .frame(width: 92, height: 58)
                        .offset(x: CGFloat(index) * 7, y: CGFloat(index) * -7)
                }
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == 0 ? Theme.accent.opacity(0.7) : Color.secondary.opacity(0.28))
                            .frame(width: index == 2 ? 30 : 56, height: 4)
                    }
                }
                .offset(x: 14, y: -14)
            }
            .frame(width: 110, height: 76)
        }

        private var machine: some View {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Theme.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Theme.separator, lineWidth: 0.5)
                    )
                    .frame(width: 112, height: 76)
                    .overlay(
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 34))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    )

                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Circle().fill(Theme.accent))
                    .offset(x: 6, y: 6)
            }
        }
    }

    // MARK: Step 3 — the two shortcuts

    struct Shortcut: View {
        var body: some View {
            HStack(spacing: 14) {
                keys
                arrow
                palette
                arrow
                pasteTarget
            }
            .frame(maxWidth: .infinity)
        }

        private var arrow: some View {
            Image(systemName: "arrow.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }

        private var keys: some View {
            HStack(spacing: 4) {
                ForEach(["⌥", "⌘", "V"], id: \.self) { key in
                    Text(key)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Theme.secondaryBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.separator, lineWidth: 0.5)
                        )
                }
            }
        }

        private var palette: some View {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                    Capsule()
                        .fill(Color.secondary.opacity(0.22))
                        .frame(width: 44, height: 3)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 6)

                Divider()

                VStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.25))
                                .frame(width: 8, height: 8)
                            Capsule()
                                .fill(index == 0 ? Theme.accent.opacity(0.75) : Color.secondary.opacity(0.22))
                                .frame(width: index == 1 ? 34 : 48, height: 3)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(index == 0 ? Theme.accent.opacity(0.14) : .clear)
                        )
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 6)
            }
            .frame(width: 96)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.separator, lineWidth: 0.5)
            )
        }

        private var pasteTarget: some View {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Theme.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Theme.separator, lineWidth: 0.5)
                    )
                    .frame(width: 74, height: 50)
                    .overlay(
                        VStack(alignment: .leading, spacing: 4) {
                            Capsule().fill(Theme.accent.opacity(0.7)).frame(width: 46, height: 3)
                            Capsule().fill(Color.secondary.opacity(0.22)).frame(width: 34, height: 3)
                        }
                    )
                HStack(spacing: 3) {
                    Text(verbatim: "⌘")
                    Text(L("V"))
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Step 4 — themes and sound

    struct Personalise: View {
        var body: some View {
            HStack(spacing: 14) {
                miniWindow(background: Color(hex: "FBF9F4"), surface: Color(hex: "F4F1EA"), line: Color(hex: "CFC7B6"), label: L("Light"))
                miniWindow(background: Color(hex: "212832"), surface: Color(hex: "191E25"), line: Color(hex: "3A4553"), label: L("Dark"))
                VStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                    Text(L("Optional"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 70)
            }
            .frame(maxWidth: .infinity)
        }

        private func miniWindow(background: Color, surface: Color, line: Color, label: String) -> some View {
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(surface)
                        .frame(width: 26)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(0..<3, id: \.self) { index in
                                    Capsule()
                                        .fill(index == 0 ? Theme.accent : line)
                                        .frame(width: index == 0 ? 15 : 12, height: 3)
                                }
                            }
                            .padding(5)
                        }
                    Rectangle()
                        .fill(background)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(0..<4, id: \.self) { index in
                                    Capsule()
                                        .fill(line)
                                        .frame(width: index == 1 ? 30 : 44, height: 3)
                                }
                            }
                            .padding(6)
                        }
                }
                .frame(width: 104, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Theme.separator, lineWidth: 0.5)
                )

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: No longer a step — the Services guidance moved into Settings

    struct Services: View {
        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                menu
                Image(systemName: "arrow.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 46)
                submenu
            }
            .frame(maxWidth: .infinity)
        }

        private var menu: some View {
            VStack(spacing: 2) {
                row(width: 52, highlighted: false)
                row(width: 64, highlighted: false)
                Divider().padding(.vertical, 2)
                row(width: 44, highlighted: false)
                HStack(spacing: 5) {
                    Text(L("Services"))
                        .font(.system(size: 9, weight: .medium))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accent.opacity(0.16))
                )
            }
            .padding(5)
            .frame(width: 104)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.elevated))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.separator, lineWidth: 0.5))
        }

        private var submenu: some View {
            VStack(alignment: .leading, spacing: 3) {
                ForEach([L("Save to CopyWell"), L("Pin to CopyWell"), L("Copy Text in Image")], id: \.self) { title in
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Theme.accent)
                        Text(title)
                            .font(.system(size: 9))
                            .lineLimit(1)
                    }
                }
            }
            .padding(7)
            .frame(width: 136, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.elevated))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.separator, lineWidth: 0.5))
        }

        private func row(width: CGFloat, highlighted: Bool) -> some View {
            HStack {
                Capsule()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(width: width, height: 3)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }
}
