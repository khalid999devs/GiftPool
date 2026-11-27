import Foundation

// Dates are saved as noon UTC of the picked day so every time zone shows the same date.
enum DateHelpers {
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    static func occasionTimestamp(for localDate: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.dateComponents([.year, .month, .day], from: localDate)
        let noon = DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)
        return utcCalendar.date(from: noon) ?? localDate
    }

    static func localDate(fromOccasion stored: Date, calendar: Calendar = .current) -> Date {
        let day = utcCalendar.dateComponents([.year, .month, .day], from: stored)
        return calendar.date(from: day) ?? stored
    }

    static func occasionText(_ stored: Date, style: Date.FormatStyle = .dateTime.weekday(.abbreviated).day().month(.abbreviated)) -> String {
        localDate(fromOccasion: stored).formatted(style)
    }

    static func daysUntil(_ stored: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: localDate(fromOccasion: stored, calendar: calendar))
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }

    static func countdownText(_ stored: Date, now: Date = .now) -> String {
        let days = daysUntil(stored, now: now)
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case 2...: return "In \(days) days"
        default: return "\(abs(days)) days ago"
        }
    }

    static func isBeforeToday(_ localDate: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: localDate) < calendar.startOfDay(for: now)
    }
}
