import Foundation

enum Formatters {
    static let year: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter
    }()

    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    static let tmdbDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    static func parseTMDBDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return tmdbDate.date(from: raw)
    }

    static func watchTime(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 {
            return "\(remainder)m"
        }
        if remainder == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainder)m"
    }

    static func episodeAirLabel(_ date: Date?) -> String {
        guard let date else { return "TBA" }
        if date.isToday { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return mediumDate.string(from: date)
    }
}
