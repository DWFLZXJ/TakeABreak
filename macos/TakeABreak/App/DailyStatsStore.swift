import Foundation

struct DailyStats: Equatable, Sendable, Codable {
    /// yyyy-MM-dd in local calendar
    var dayKey: String
    /// Completed focus sessions (work → break).
    var completedRounds: Int
    /// Accumulated focused work time in milliseconds.
    var focusMilliseconds: Int
    /// Times the user skipped a break.
    var skipCount: Int

    static func empty(for dayKey: String) -> DailyStats {
        DailyStats(dayKey: dayKey, completedRounds: 0, focusMilliseconds: 0, skipCount: 0)
    }

    var focusMinutes: Int {
        Int((Double(focusMilliseconds) / 60_000.0).rounded())
    }

    var focusDisplay: String {
        let totalSec = max(0, focusMilliseconds / 1000)
        let h = totalSec / 3600
        let m = (totalSec % 3600) / 60
        if h > 0 {
            return "\(h) 小时 \(m) 分"
        }
        return "\(m) 分钟"
    }
}

enum DailyStatsStore {
    private static let key = "takeabreak.stats.v1"

    static func todayKey(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: now)
    }

    static func loadToday() -> DailyStats {
        let keyToday = todayKey()
        guard let data = UserDefaults.standard.data(forKey: key),
              let stats = try? JSONDecoder().decode(DailyStats.self, from: data) else {
            return .empty(for: keyToday)
        }
        if stats.dayKey != keyToday {
            return .empty(for: keyToday)
        }
        return stats
    }

    static func save(_ stats: DailyStats) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func update(_ mutate: (inout DailyStats) -> Void) -> DailyStats {
        var stats = loadToday()
        mutate(&stats)
        save(stats)
        return stats
    }
}
