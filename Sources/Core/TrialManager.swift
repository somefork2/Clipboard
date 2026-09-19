import Foundation
import Observation
import Security

/// The free trial: everything unlocked for 30 days from first launch.
///
/// Not a StoreKit introductory offer, which would require committing to a
/// subscription before trying the app. This is a plain local period: no payment,
/// no account, nothing to cancel. When it ends the app locks and asks for a
/// subscription; nothing the user saved is deleted.
///
/// The start date lives in the keychain rather than in preferences, because a
/// keychain item survives deleting the app. In preferences a reinstall would
/// hand out a fresh 30 days forever.
@MainActor
@Observable
final class TrialManager {
    static let shared = TrialManager()

    static let duration: TimeInterval = 30 * 24 * 60 * 60

    private let service = "CopyWell"
    private let account = "com.copywell.trialStart"

    private(set) var startDate: Date

    private init() {
        if let stored = Self.readStartDate(service: "CopyWell", account: "com.copywell.trialStart") {
            startDate = stored
        } else {
            let now = Date()
            startDate = now
            Self.writeStartDate(now, service: "CopyWell", account: "com.copywell.trialStart")
        }
    }

    var endDate: Date { startDate.addingTimeInterval(Self.duration) }
    var isActive: Bool { Date() < endDate }

    /// Whole days left, rounded up, so the last partial day still reads as "1".
    var daysRemaining: Int {
        guard isActive else { return 0 }
        return max(1, Int(ceil(endDate.timeIntervalSinceNow / 86_400)))
    }

    var summary: String {
        guard isActive else {
            return String(localized: "Your 30-day trial has ended. Subscribe to carry on using CopyWell.")
        }
        let days = daysRemaining
        return days == 1
            ? String(localized: "Last day of your trial — everything is unlocked.")
            : String(localized: "\(days) days left in your trial — everything is unlocked.")
    }

    // MARK: - Keychain

    private static func readStartDate(service: String, account: String) -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let text = String(data: data, encoding: .utf8),
              let seconds = TimeInterval(text) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    @discardableResult
    private static func writeStartDate(_ date: Date, service: String, account: String) -> Bool {
        let data = Data(String(date.timeIntervalSince1970).utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    #if DEBUG
    /// Development only: move the start date so the expired state can be seen.
    func simulateStart(daysAgo: Int) {
        let moved = Date().addingTimeInterval(-Double(daysAgo) * 86_400)
        startDate = moved
        Self.writeStartDate(moved, service: service, account: account)
    }
    #endif
}
