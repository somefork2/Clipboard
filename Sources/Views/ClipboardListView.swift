import SwiftUI

struct ClipboardListView: View {
    @Bindable var viewModel: ClipboardListViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            filterBar
            itemList
        }
    }

    private var headerBar: some View {
        HStack(spacing: 14) {
            // Search
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("Search clipboard...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .rounded))
                if !viewModel.searchText.isEmpty {
                    Button(action: { withAnimation { viewModel.searchText = "" }; viewModel.applyFilters() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.searchText.isEmpty ? Color.secondary.opacity(0.1) : Color(hex: "3b82f6").opacity(0.4), lineWidth: 1)
                    )
            )

            // Item count
            HStack(spacing: 5) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("\(viewModel.filteredItems.count) items")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
                    )
            )

            // Pro badge
            if SubscriptionManager.shared.isPro {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var filterBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: viewModel.selectedFilter == nil,
                        count: viewModel.items.count,
                        color: Color(hex: "3b82f6")
                    ) {
                        withAnimation { viewModel.selectedFilter = nil }
                        viewModel.applyFilters()
                    }
                    ForEach(ContentType.allCases.filter { $0 != .unknown }, id: \.self) { type in
                        FilterChip(
                            title: type.displayName,
                            icon: type.systemImage,
                            isSelected: viewModel.selectedFilter == type,
                            count: viewModel.items.filter { $0.type == type }.count,
                            color: type.gradient.0
                        ) {
                            withAnimation { viewModel.selectedFilter = viewModel.selectedFilter == type ? nil : type }
                            viewModel.applyFilters()
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 12)

            Divider()
                .background(Color.secondary.opacity(0.1))
        }
    }

    private var itemList: some View {
        Group {
            if viewModel.filteredItems.isEmpty {
                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.08))
                            .frame(width: 120, height: 120)
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                            .frame(width: 120, height: 120)
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(.secondary)
                    }
                    VStack(spacing: 12) {
                        Text("Clipboard is empty")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                        Text("Copy something to get started.\nYour clipboard history will appear here.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.id) { index, item in
                            ClipboardItemRow(
                                item: item,
                                index: viewModel.selectedSidebarItem == .pasteStack ? index : nil,
                                onSelect: {},
                                onCopy: { viewModel.copyToClipboard(item) },
                                onFavorite: { viewModel.toggleFavorite(item) },
                                onDelete: { viewModel.deleteItem(item) },
                                onAddToStack: SubscriptionManager.shared.requestAccess(for: .pasteStack) ? { viewModel.pasteStackManager.addToStack(item) } : nil
                            )
                            .transition(.asymmetric(insertion: .slide.combined(with: .opacity), removal: .opacity))
                        }
                    }
                    .padding(24)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.filteredItems.count)
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    var count: Int? = nil
    var color: Color = Color(hex: "3b82f6")
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ?
                        LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                        LinearGradient(colors: [Color(nsColor: .controlBackgroundColor)], startPoint: .leading, endPoint: .trailing)
                    )
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .foregroundColor(isSelected ? .white : .primary)
            .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
