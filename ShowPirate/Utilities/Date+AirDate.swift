import Foundation

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}

extension Calendar {
    func monthDates(for date: Date) -> [Date?] {
        guard let monthInterval = dateInterval(of: .month, for: date) else {
            return []
        }

        var leadingBlanks = weekday(of: monthInterval.start) - firstWeekday
        if leadingBlanks < 0 { leadingBlanks += 7 }

        var dates: [Date?] = Array(repeating: nil, count: leadingBlanks)
        var cursor = monthInterval.start
        while cursor < monthInterval.end {
            dates.append(cursor)
            guard let next = self.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let remainder = dates.count % 7
        if remainder != 0 {
            dates.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }

        return dates
    }

    func weekday(of date: Date) -> Int {
        component(.weekday, from: date)
    }

    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? date.startOfDay
    }
}
