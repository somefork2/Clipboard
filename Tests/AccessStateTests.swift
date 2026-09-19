import AppKit
import Foundation
import Testing
@testable import CopyWell

/// What the app actually allows in each of its three states.
///
/// These exist because the gates used to ask `isPro`, which is true only for a
/// paid subscription. During the 30-day trial — the state every new user and
/// every App Review reviewer is in — that reads false, and four paid features
/// were switched off for people who were entitled to all of them.
@Suite("Access in each state", .serialized)
@MainActor
struct AccessStateTests {

    /// Runs `body` with the app in a given state and puts everything back.
    private func inState(pro: Bool, locked: Bool, trialActive: Bool, _ body: () throws -> Void) rethrows {
        let manager = SubscriptionManager.shared
        let trial = TrialManager.shared
        let previousPro = manager.simulatedPro
        let previousLock = manager.forcedLock
        // The start date lives in the keychain, so it has to be restored rather
        // than left wherever the test moved it.
        let previousStart = trial.startDate

        manager.simulatedPro = pro
        manager.forcedLock = locked
        trial.simulateStart(daysAgo: trialActive ? 1 : 40)
        defer {
            manager.simulatedPro = previousPro
            manager.forcedLock = previousLock
            trial.simulateStart(daysAgo: Int((Date().timeIntervalSince(previousStart) / 86_400).rounded()))
        }
        try body()
    }

    private func scratchPasteboard(_ name: String) -> NSPasteboard {
        let board = NSPasteboard(name: NSPasteboard.Name("CopyWellTests.\(name)"))
        board.clearContents()
        return board
    }

    // MARK: - The trial

    @Test("The trial unlocks everything, even though nothing has been bought")
    func trialUnlocksEverything() {
        inState(pro: false, locked: false, trialActive: true) {
            let manager = SubscriptionManager.shared

            // The trap: this is false, and every gate that asked it was wrong.
            #expect(manager.isPro == false)

            #expect(manager.isInFreeTrial)
            #expect(manager.hasFullAccess)
            #expect(manager.isLocked == false)

            for feature in PremiumFeature.allCases {
                #expect(manager.checkAccess(for: feature), "\(feature.rawValue) was refused during the trial")
            }
        }
    }

    @Test("The status line names the trial rather than a free plan")
    func trialStatusReadsAsTrial() {
        inState(pro: false, locked: false, trialActive: true) {
            let text = SubscriptionManager.shared.statusDescription
            #expect(text.contains("\(TrialManager.shared.daysRemaining)"))
            #expect(text != String(localized: "Free"))
        }
    }

    // MARK: - Locked

    @Test("A locked app refuses every feature")
    func lockedRefusesEverything() {
        inState(pro: false, locked: true, trialActive: false) {
            let manager = SubscriptionManager.shared
            #expect(manager.hasFullAccess == false)
            #expect(manager.isLocked)
            for feature in PremiumFeature.allCases {
                #expect(manager.checkAccess(for: feature) == false, "\(feature.rawValue) survived the lock")
            }
        }
    }

    @Test("A locked app never calls itself free")
    func lockedStatusIsNotFree() {
        inState(pro: false, locked: true, trialActive: false) {
            let text = SubscriptionManager.shared.statusDescription
            // Compared against the catalogue rather than an English phrase: the
            // app runs in whatever language the machine is set to.
            #expect(text == String(localized: "Locked — subscription needed"))
            #expect(text != String(localized: "Free"))
        }
    }

    // MARK: - Services, which are reachable from every other app

    @Test("Every paste Service is refused while locked")
    func pasteServicesRefuseWhileLocked() {
        inState(pro: false, locked: true, trialActive: false) {
            let provider = ServiceProvider()

            for (name, call) in [
                ("quickPaste", { (b: NSPasteboard, e: AutoreleasingUnsafeMutablePointer<NSString>) in
                    provider.quickPasteFromCopyWell(b, userData: "", error: e) }),
                ("pastePlain", { (b: NSPasteboard, e: AutoreleasingUnsafeMutablePointer<NSString>) in
                    provider.pastePlainFromCopyWell(b, userData: "", error: e) })
            ] {
                let board = scratchPasteboard(name)
                var error: NSString = ""
                call(board, &error)
                #expect(board.string(forType: .string) == nil, "\(name) handed a clip back while locked")
                #expect(error.length > 0, "\(name) refused silently")
            }
        }
    }

    @Test("Text recognition is refused while locked")
    func recognitionRefusedWhileLocked() {
        inState(pro: false, locked: true, trialActive: false) {
            let board = scratchPasteboard("ocr")
            let image = NSImage(size: NSSize(width: 40, height: 20))
            board.clearContents()
            board.writeObjects([image])

            var error: NSString = ""
            ServiceProvider().recognizeTextFromCopyWell(board, userData: "", error: &error)
            #expect(error.length > 0, "OCR ran while the app was locked")
        }
    }

    @Test("A locked app takes nothing in")
    func ingestRefusedWhileLocked() {
        inState(pro: false, locked: true, trialActive: false) {
            let before = ClipboardStore.shared.items.count
            let board = scratchPasteboard("ingest")
            board.clearContents()
            board.setString("something copied while locked", forType: .string)

            var error: NSString = ""
            ServiceProvider().saveSelectionToCopyWell(board, userData: "", error: &error)
            #expect(ClipboardStore.shared.items.count == before, "a clip was recorded while locked")
        }
    }
}
