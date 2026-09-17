import Foundation
import SwiftUI

@Observable
final class PasteStackManager {
    var stackItems: [ClipboardItem] = []
    var currentIndex = 0
    var showingStack = false

    var progress: Double {
        guard !stackItems.isEmpty else { return 0 }
        return Double(currentIndex) / Double(stackItems.count)
    }

    func addToStack(_ item: ClipboardItem) {
        stackItems.append(item)
    }

    func removeFromStack(at offsets: IndexSet) {
        stackItems.remove(atOffsets: offsets)
    }

    func pasteNext() -> ClipboardItem? {
        guard currentIndex < stackItems.count else { return nil }
        let item = stackItems[currentIndex]
        currentIndex += 1
        return item
    }

    func reset() {
        currentIndex = 0
        stackItems.removeAll()
    }
}
