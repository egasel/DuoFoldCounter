import Foundation

/// One hinge event, as reported by the Shortcuts "When iPhone is Opened / Closed" trigger.
enum FoldEvent: String, Codable, CaseIterable, Sendable {
    case open
    case close
}

struct DayCount: Codable, Equatable, Sendable {
    var opens = 0
    var closes = 0
}

struct DaySummary: Identifiable, Equatable {
    let date: Date
    let count: DayCount
    var id: Date { date }
}

struct FoldStats: Codable, Equatable, Sendable {
    /// Counts per local calendar day, keyed "yyyy-MM-dd".
    var days: [String: DayCount] = [:]
    var firstEvent: Date?
    var lastEvent: Date?

    var total: DayCount {
        days.values.reduce(into: DayCount()) { sum, day in
            sum.opens += day.opens
            sum.closes += day.closes
        }
    }

    func count(on date: Date, calendar: Calendar = .current) -> DayCount {
        days[Self.dayKey(for: date, calendar: calendar)] ?? DayCount()
    }

    /// The `count` days ending on `date`, newest first, including days with no folds.
    func recentDays(_ count: Int, endingOn date: Date, calendar: Calendar = .current) -> [DaySummary] {
        let start = calendar.startOfDay(for: date)
        return (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
            return DaySummary(date: day, count: self.count(on: day, calendar: calendar))
        }
    }

    mutating func record(_ event: FoldEvent, at date: Date, calendar: Calendar = .current) {
        let key = Self.dayKey(for: date, calendar: calendar)
        var day = days[key] ?? DayCount()
        switch event {
        case .open: day.opens += 1
        case .close: day.closes += 1
        }
        days[key] = day
        if firstEvent == nil { firstEvent = date }
        lastEvent = date
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// Persists the counts in the App Group so the app, its intents and the widget all see the same numbers.
final class FoldStore: @unchecked Sendable {
    static let didChange = Notification.Name("FoldStoreDidChange")

    static let shared: FoldStore = {
        let groupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? ""
        let defaults = groupID.isEmpty ? nil : UserDefaults(suiteName: groupID)
        return FoldStore(defaults: defaults ?? .standard)
    }()

    private let defaults: UserDefaults
    private let key = "foldStats.v1"
    private let lock = NSLock()

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func load() -> FoldStats {
        guard let data = defaults.data(forKey: key),
              let stats = try? JSONDecoder().decode(FoldStats.self, from: data)
        else { return FoldStats() }
        return stats
    }

    @discardableResult
    func record(_ event: FoldEvent, at date: Date = Date(), calendar: Calendar = .current) -> FoldStats {
        mutate { $0.record(event, at: date, calendar: calendar) }
    }

    func reset() {
        mutate { $0 = FoldStats() }
    }

    @discardableResult
    private func mutate(_ change: (inout FoldStats) -> Void) -> FoldStats {
        lock.lock()
        var stats = load()
        change(&stats)
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: key)
        }
        lock.unlock()
        NotificationCenter.default.post(name: Self.didChange, object: self)
        return stats
    }
}
