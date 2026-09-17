import Foundation

struct StatisticsTracker {
    static let shared = StatisticsTracker()
    private let defaults = UserDefaults.standard

    var totalCopied: Int { defaults.integer(forKey: "stats_totalCopied") }
    var totalPasted: Int { defaults.integer(forKey: "stats_totalPasted") }
    var dailyCopies: Int { defaults.integer(forKey: "stats_dailyCopies") }

    func recordCopy(from app: String?) {
        defaults.set(totalCopied + 1, forKey: "stats_totalCopied")
        defaults.set(dailyCopies + 1, forKey: "stats_dailyCopies")
        if let app {
            var topApps = defaults.dictionary(forKey: "stats_topApps") as? [String: Int] ?? [:]
            topApps[app, default: 0] += 1
            defaults.set(topApps, forKey: "stats_topApps")
        }
    }

    func recordPaste() { defaults.set(totalPasted + 1, forKey: "stats_totalPasted") }

    func resetDailyIfNeeded() {
        guard let lastReset = defaults.object(forKey: "stats_lastReset") as? Date else {
            defaults.set(Date(), forKey: "stats_lastReset"); return
        }
        if !Calendar.current.isDateInToday(lastReset) {
            defaults.set(0, forKey: "stats_dailyCopies")
            defaults.set(Date(), forKey: "stats_lastReset")
        }
    }

    func getTopApps(limit: Int = 5) -> [(app: String, count: Int)] {
        (defaults.dictionary(forKey: "stats_topApps") as? [String: Int] ?? [:])
            .sorted { $0.value > $1.value }.prefix(limit).map { (app: $0.key, count: $0.value) }
    }

    func getWeeklyStats() -> [Int] { [12, 25, 18, 32, 28, 15, 8] }
}
