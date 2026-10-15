import Foundation

struct TimeOfDay: Codable, Hashable, Comparable {
    var hour: Int
    var minute: Int

    var isValid: Bool { (0...23).contains(hour) && (0...59).contains(minute) }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}

/// When a compound is taken. Named DoseSchedule, not Protocol: `Protocol` is
/// an Objective-C runtime class on Apple platforms.
///
/// Days are counted with the calendar from the start day, never by adding
/// 86 400 s, so daylight-saving changes don't shift doses by an hour.
struct DoseSchedule: Codable, Hashable {
    enum Pattern: Codable, Hashable {
        /// 1 = daily, 2 = every other day, 7 = weekly from the start day.
        case everyNDays(Int)
        /// Calendar weekday numbers (1 = Sunday … 7 = Saturday).
        case weekdays(Set<Int>)
        /// `onDays` days on, then `offDays` days off, repeating.
        case cycle(onDays: Int, offDays: Int)
    }

    var pattern: Pattern
    /// Any instant within the first day.
    var start: Date
    /// Any instant within the last day (inclusive); nil = open-ended.
    var end: Date?
    var times: [TimeOfDay]

    /// Days are scanned at most this far ahead: ten years.
    static let horizonDays = 3660

    var isValid: Bool {
        guard !times.isEmpty, times.allSatisfy(\.isValid) else { return false }
        switch pattern {
        case .everyNDays(let n): return n >= 1
        case .weekdays(let days): return !days.isEmpty && days.allSatisfy { (1...7).contains($0) }
        case .cycle(let on, let off): return on >= 1 && off >= 0
        }
    }

    func isDoseDay(_ day: Date, calendar: Calendar) -> Bool {
        guard isValid else { return false }
        let firstDay = calendar.startOfDay(for: start)
        let thisDay = calendar.startOfDay(for: day)
        guard thisDay >= firstDay else { return false }
        if let end, thisDay > calendar.startOfDay(for: end) { return false }
        let index = calendar.dateComponents([.day], from: firstDay, to: thisDay).day!

        switch pattern {
        case .everyNDays(let n): return index % n == 0
        case .weekdays(let days): return days.contains(calendar.component(.weekday, from: thisDay))
        case .cycle(let on, let off): return index % (on + off) < on
        }
    }

    /// Dose instants of one day, in time order.
    private func doses(on day: Date, calendar: Calendar) -> [Date] {
        guard isDoseDay(day, calendar: calendar) else { return [] }
        return times.sorted().compactMap {
            // A time skipped by a spring-forward jump moves to the next valid one.
            calendar.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: day,
                          matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
        }
    }

    /// Every dose in `from...through`.
    func occurrences(from: Date, through: Date, calendar: Calendar) -> [Date] {
        guard isValid, from <= through else { return [] }
        var result: [Date] = []
        var day = calendar.startOfDay(for: max(from, start))
        let lastDay = calendar.startOfDay(for: through)
        while day <= lastDay {
            result += doses(on: day, calendar: calendar).filter { $0 >= from && $0 <= through }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }

    /// The next `count` doses strictly after `date`; fewer if the schedule
    /// ends or the horizon is reached.
    func nextOccurrences(after date: Date, count: Int, calendar: Calendar) -> [Date] {
        guard isValid, count > 0 else { return [] }
        var result: [Date] = []
        var day = calendar.startOfDay(for: max(date, start))
        for _ in 0..<DoseSchedule.horizonDays {
            if let end, day > calendar.startOfDay(for: end) { break }
            for dose in doses(on: day, calendar: calendar) where dose > date {
                result.append(dose)
                if result.count == count { return result }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }

    func next(after date: Date, calendar: Calendar) -> Date? {
        nextOccurrences(after: date, count: 1, calendar: calendar).first
    }
}

/// "Vial runs out on …" and the reorder reminder.
enum VialForecast {
    /// Full doses the remaining amount still covers.
    static func dosesLeft(remaining: Mass, dose: Mass) -> Int {
        guard dose.isPositive, remaining.isPositive else { return 0 }
        return (remaining.mcg / dose.mcg).rounded(0, .down).intValue
    }

    /// The first scheduled dose the vial can no longer cover — the moment a
    /// new vial is needed. nil when the schedule never gets there.
    static func runOutDate(remaining: Mass, dose: Mass, schedule: DoseSchedule,
                           after date: Date, calendar: Calendar) -> Date? {
        guard dose.isPositive else { return nil }
        let needed = dosesLeft(remaining: remaining, dose: dose) + 1
        let upcoming = schedule.nextOccurrences(after: date, count: needed, calendar: calendar)
        return upcoming.count == needed ? upcoming.last : nil
    }

    /// `leadDays` before the run-out, never in the past of `now`.
    static func reorderDate(runOut: Date, leadDays: Int, now: Date, calendar: Calendar) -> Date {
        let target = calendar.date(byAdding: .day, value: -max(0, leadDays), to: runOut)!
        return max(target, now)
    }
}
