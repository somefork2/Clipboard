import SwiftUI

/// Creating and editing a pinboard: name, symbol and colour in one sheet.
///
/// Pinboards used to be create-and-delete only, which made them hard to tell
/// apart once there were more than two.
struct PinboardEditor: View {
    /// `nil` creates a new board.
    let board: Pinboard?
    let onDismiss: () -> Void

    @Environment(ClipboardStore.self) private var store

    @State private var name: String = ""
    @State private var icon: String = "pin"
    @State private var color: String = "blue"

    static let icons = [
        "pin", "star", "flag", "tag", "bookmark", "folder",
        "tray", "archivebox", "doc.text", "link", "terminal", "envelope",
        "creditcard", "person", "building.2", "hammer", "paintbrush", "lightbulb"
    ]

    private let columns = [GridItem(.adaptive(minimum: 38), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(board == nil ? "New Pinboard" : "Edit Pinboard")
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(commit)

            VStack(alignment: .leading, spacing: 6) {
                Text("Colour")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(ThemeManager.accentOptions, id: \.self) { option in
                        Button {
                            color = option
                        } label: {
                            Circle()
                                .fill(Color.named(option))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(.primary, lineWidth: color == option ? 2 : 0)
                                        .padding(-3)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Symbol")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Self.icons, id: \.self) { symbol in
                        Button {
                            icon = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.body)
                                .frame(width: 32, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(icon == symbol ? Color.named(color).opacity(0.22) : Theme.secondaryBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(icon == symbol ? Color.named(color) : .clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                Button(board == nil ? "Create" : "Save", action: commit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 340)
        .onAppear {
            if let board {
                name = board.name
                icon = board.icon
                color = board.color
            }
        }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let board {
            store.rename(board, to: trimmed)
            store.update(board, icon: icon, color: color)
        } else {
            store.createPinboard(name: trimmed, icon: icon, color: color)
        }
        onDismiss()
    }
}
