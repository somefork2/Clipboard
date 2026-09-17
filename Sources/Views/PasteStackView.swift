import SwiftUI

struct PasteStackView: View {
    @Bindable var viewModel: ClipboardListViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) { Image(systemName: "rectangle.stack.fill").font(.system(size: 20)).foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)); Text("Paste Stack").font(.system(size: 22, weight: .bold)) }
                    Text("Queue items for sequential pasting").font(.system(size: 13)).foregroundColor(.secondary)
                }
                Spacer()
                if !viewModel.pasteStackManager.stackItems.isEmpty {
                    Button(action: { viewModel.pasteStackManager.reset() }) { Label("Clear", systemImage: "trash").font(.system(size: 12, weight: .medium)).foregroundColor(.red).padding(.horizontal, 12).padding(.vertical, 6).background(Color.red.opacity(0.1)).clipShape(Capsule()) }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 24).padding(.vertical, 18)

            if viewModel.pasteStackManager.stackItems.isEmpty {
                VStack(spacing: 20) {
                    ZStack { Circle().fill(LinearGradient(colors: [.purple.opacity(0.2), .blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 100, height: 100)
                        Image(systemName: "rectangle.stack").font(.system(size: 40)).foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    VStack(spacing: 8) {
                        Text("No items in stack").font(.system(size: 18, weight: .semibold))
                        Text("Right-click any clip and select\n\"Add to Paste Stack\" to queue it up.").font(.system(size: 13)).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(viewModel.pasteStackManager.stackItems.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 12) {
                                ZStack { Circle().fill(index == viewModel.pasteStackManager.currentIndex ? Color.purple : (index < viewModel.pasteStackManager.currentIndex ? Color.green : Color.secondary.opacity(0.2))).frame(width: 28, height: 28)
                                    if index < viewModel.pasteStackManager.currentIndex { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white) }
                                    else { Text("\(index+1)").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(index == viewModel.pasteStackManager.currentIndex ? .white : .primary) }
                                }
                                Image(systemName: item.type.systemImage).font(.system(size: 14)).foregroundColor(index < viewModel.pasteStackManager.currentIndex ? .secondary : .primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.previewText).font(.system(size: 13, weight: index == viewModel.pasteStackManager.currentIndex ? .semibold : .regular)).lineLimit(1).foregroundColor(index < viewModel.pasteStackManager.currentIndex ? .secondary : .primary)
                                    Text(item.type.displayName).font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                Spacer()
                                if index == viewModel.pasteStackManager.currentIndex { Text("NEXT").font(.system(size: 9, weight: .bold)).foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 3).background(Color.purple).clipShape(Capsule()) }
                                Button(action: { viewModel.pasteStackManager.removeFromStack(at: IndexSet(integer: index)) }) { Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundColor(.secondary) }.buttonStyle(.plain)
                            }.padding(.horizontal, 16).padding(.vertical, 12).background(RoundedRectangle(cornerRadius: 12).fill(index == viewModel.pasteStackManager.currentIndex ? Color.purple.opacity(0.1) : .clear)).opacity(index < viewModel.pasteStackManager.currentIndex ? 0.6 : 1)
                        }
                    }.padding(20)
                }
            }

            if !viewModel.pasteStackManager.stackItems.isEmpty {
                VStack(spacing: 12) {
                    HStack { Text("Progress").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary); Spacer(); Text("\(viewModel.pasteStackManager.currentIndex)/\(viewModel.pasteStackManager.stackItems.count)").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.secondary) }
                    GeometryReader { geo in ZStack(alignment: .leading) { RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)).frame(height: 8); RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * viewModel.pasteStackManager.progress, height: 8).animation(.spring(response: 0.3), value: viewModel.pasteStackManager.progress) } }.frame(height: 8)
                    Button(action: { if let item = viewModel.pasteStackManager.pasteNext() { viewModel.copyToClipboard(item) } }) { HStack(spacing: 8) { Image(systemName: "arrow.up.doc"); Text("Paste Next").font(.system(size: 14, weight: .semibold)) }.foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12).background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)).clipShape(RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain).disabled(viewModel.pasteStackManager.currentIndex >= viewModel.pasteStackManager.stackItems.count)
                }.padding(20).background(Rectangle().fill(.ultraThinMaterial).overlay(alignment: .top) { Divider() })
            }
        }
    }
}
