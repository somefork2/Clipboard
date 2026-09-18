import Foundation
import Observation

/// A queue of clips pasted one after another.
@MainActor
@Observable
final class PasteStackManager {
    static let shared = PasteStackManager()

    private(set) var stackItems: [ClipboardItem] = []
    private(set) var currentIndex = 0

    private init() {}

    var isEmpty: Bool { stackItems.isEmpty }
    var remaining: Int { max(stackItems.count - currentIndex, 0) }

    var progress: Double {
        guard !stackItems.isEmpty else { return 0 }
        return Double(currentIndex) / Double(stackItems.count)
    }

    func add(_ item: ClipboardItem) {
        guard !stackItems.contains(where: { $0.id == item.id }) else { return }
        stackItems.append(item)
    }

    func remove(at offsets: IndexSet) {
        stackItems.remove(atOffsets: offsets)
        currentIndex = min(currentIndex, stackItems.count)
    }

    func move(from source: IndexSet, to destination: Int) {
        stackItems.move(fromOffsets: source, toOffset: destination)
    }

    /// Returns the next queued clip and advances the cursor.
    func pasteNext() -> ClipboardItem? {
        guard currentIndex < stackItems.count else { return nil }
        let item = stackItems[currentIndex]
        currentIndex += 1
        return item
    }

    func rewind() { currentIndex = 0 }

    func reset() {
        currentIndex = 0
        stackItems.removeAll()
    }
}
