import SwiftUI

struct PasteStackView: View {
    @Bindable var viewModel: ClipboardListViewModel
    @State private var animateProgress = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 36, height: 36)
                            Image(systemName: "square.stack.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text("Paste Stack")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                    }
                    Text("Queue items for sequential pasting")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !viewModel.pasteStackManager.stackItems.isEmpty {
                    Button(action: { viewModel.pasteStackManager.reset() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Clear")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 18)

            Divider()

            if viewModel.pasteStackManager.stackItems.isEmpty {
                // Empty state
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.purple.opacity(0.15), .blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 110, height: 110)
                        Circle()
                            .stroke(LinearGradient(colors: [.purple.opacity(0.2), .blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                            .frame(width: 110, height: 110)
                        Image(systemName: "square.stack")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    VStack(spacing: 10) {
                        Text("No items in stack")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("Right-click any clip and select\n\"Add to Paste Stack\" to queue it up.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                // Stack items
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(viewModel.pasteStackManager.stackItems.enumerated()), id: \.element.id) { index, item in
                            stackItemRow(item: item, index: index)
                        }
                    }
                    .padding(20)
                }
            }

            // Bottom bar with progress and paste button
            if !viewModel.pasteStackManager.stackItems.isEmpty {
                VStack(spacing: 14) {
                    Divider()

                    VStack(spacing: 10) {
                        HStack {
                            Text("Progress")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(viewModel.pasteStackManager.currentIndex)/\(viewModel.pasteStackManager.stackItems.count)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * viewModel.pasteStackManager.progress, height: 8)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.pasteStackManager.progress)
                            }
                        }
                        .frame(height: 8)

                        Button(action: {
                            if let item = viewModel.pasteStackManager.pasteNext() {
                                viewModel.copyToClipboard(item)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.on.clipboard.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Paste Next")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.pasteStackManager.currentIndex >= viewModel.pasteStackManager.stackItems.count)
                        .opacity(viewModel.pasteStackManager.currentIndex >= viewModel.pasteStackManager.stackItems.count ? 0.6 : 1)
                    }
                    .padding(20)
                }
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }

    private func stackItemRow(item: ClipboardItem, index: Int) -> some View {
        let isCurrent = index == viewModel.pasteStackManager.currentIndex
        let isCompleted = index < viewModel.pasteStackManager.currentIndex

        return HStack(spacing: 14) {
            // Status circle
            ZStack {
                Circle()
                    .fill(isCurrent ? LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom) :
                            isCompleted ? LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [Color.secondary.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 30, height: 30)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(isCurrent ? .white : .primary)
                }
            }

            // Item icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.type.gradient.0.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: item.type.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(item.type.gradient.0)
            }

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(item.previewText)
                    .font(.system(size: 13, weight: isCurrent ? .semibold : .regular, design: .rounded))
                    .lineLimit(1)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                Text(item.type.displayName)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Current badge
            if isCurrent {
                Text("NEXT")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }

            // Remove button
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.pasteStackManager.removeFromStack(at: IndexSet(integer: index))
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isCurrent ? Color.purple.opacity(0.08) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isCurrent ? Color.purple.opacity(0.2) : Color.secondary.opacity(0.1), lineWidth: 1)
                )
        )
        .opacity(isCompleted ? 0.6 : 1)
        .offset(x: isCurrent ? 4 : 0)
    }
}
