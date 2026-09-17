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
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("Search clipboard...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .rounded))
                if !viewModel.searchText.isEmpty {
                    Button(action: { withAnimation { viewModel.searchText = "" }; viewModel.applyFilters() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }.buttonStyle(.plain).transition(.scale)
                }
            }.padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.indigo.opacity(viewModel.searchText.isEmpty ? 0 : 0.4), lineWidth: 1)
                        )
                )

            HStack(spacing: 5) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("\(viewModel.filteredItems.count) items")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(Capsule())

            if SubscriptionManager.shared.isPro {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(
                    LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
            }
        }.padding(.horizontal, 20).padding(.vertical, 14)
    }

    private var filterBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isSelected: viewModel.selectedFilter == nil, count: viewModel.items.count, action: { withAnimation { viewModel.selectedFilter = nil }; viewModel.applyFilters() })
                    ForEach(ContentType.allCases.filter { $0 != .unknown }, id: \.self) { type in
                        FilterChip(title: type.displayName, icon: type.systemImage, isSelected: viewModel.selectedFilter == type, count: viewModel.items.filter { $0.type == type }.count, action: { withAnimation { viewModel.selectedFilter = viewModel.selectedFilter == type ? nil : type }; viewModel.applyFilters() })
                    }
                }.padding(.horizontal, 20)
            }.padding(.vertical, 10)
            Rectangle().fill(Color.secondary.opacity(0.15)).frame(height: 1)
        }
    }

    private var itemList: some View {
        Group {
            if viewModel.filteredItems.isEmpty {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.indigo.opacity(0.15), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 110, height: 110)
                        Circle()
                            .stroke(LinearGradient(colors: [.indigo.opacity(0.2), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                            .frame(width: 110, height: 110)
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    VStack(spacing: 10) {
                        Text("Clipboard is empty")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("Copy something to get started.\nYour clipboard history will appear here.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.id) { index, item in
                            ClipboardItemRow(item: item, index: viewModel.selectedSidebarItem == .pasteStack ? index : nil, onSelect: {}, onCopy: { viewModel.copyToClipboard(item) }, onFavorite: { viewModel.toggleFavorite(item) }, onDelete: { viewModel.deleteItem(item) }, onAddToStack: SubscriptionManager.shared.requestAccess(for: .pasteStack) ? { viewModel.pasteStackManager.addToStack(item) } : nil)
                                .transition(.asymmetric(insertion: .slide.combined(with: .opacity), removal: .opacity))
                        }
                    }.padding(20).animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.filteredItems.count)
                }
            }
        }
    }
}
