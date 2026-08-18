import SwiftUI

struct CalendarView: View {
    @Environment(\.sidebarTabIsActive) private var sidebarTabIsActive
    @Environment(LibraryStore.self) private var store
    @State private var viewModel = CalendarViewModel()

    private var weekdayHeaders: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        let days = Calendar.current.monthDates(for: viewModel.month)
        let selectedEpisodes = store.calendarItems(on: viewModel.selectedDay)

        HStack(alignment: .top, spacing: 0) {
            monthPanel(days: days)
                .frame(maxWidth: .infinity)
            Divider()
            dayPanel(selectedEpisodes)
                .frame(width: 360)
        }
        .modifier(CalendarNavigationChrome(isActive: sidebarTabIsActive, viewModel: viewModel))
        .pirateScreen()
    }

    private func monthPanel(days: [Date?]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Formatters.monthYear.string(from: viewModel.month))
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.parchment)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(weekdayHeaders, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.gold.opacity(0.8))
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let day = date.startOfDay
                        Button {
                            viewModel.selectedDay = day
                        } label: {
                            CalendarDayCell(
                                date: date,
                                isSelected: date.isSameDay(as: viewModel.selectedDay),
                                hasEpisodes: store.calendarMarkedDays.contains(day),
                                isCurrentMonth: Calendar.current.isDate(date, equalTo: viewModel.month, toGranularity: .month)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 64)
                    }
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private func dayPanel(_ selectedEpisodes: [CalendarDayItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: Formatters.mediumDate.string(from: viewModel.selectedDay),
                subtitle: viewModel.selectedDay.isToday ? "Today" : nil
            )
            if selectedEpisodes.isEmpty {
                EmptyStateView(
                    title: "No episodes",
                    systemImage: "calendar",
                    message: "Nothing airs on this day."
                )
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(selectedEpisodes) { item in
                            NavigationLink(value: item.showID) {
                                CalendarEpisodeRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
    }
}

private struct CalendarEpisodeRow: View {
    let item: CalendarDayItem

    var body: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                PosterView(path: item.posterPath, width: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.showName)
                        .font(.headline)
                        .foregroundStyle(Theme.cream)
                        .lineLimit(1)
                    Text("\(item.code) · \(item.name)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.parchment.opacity(0.75))
                        .lineLimit(1)
                    Text(Formatters.episodeAirLabel(item.airDate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.isAiringToday ? Theme.crimson : Theme.cyan)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let hasEpisodes: Bool
    let isCurrentMonth: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(Formatters.day.string(from: date))
                .font(.body.weight(date.isToday ? .semibold : .regular))
                .foregroundStyle(date.isToday ? Theme.huntRed : .primary)
            Circle()
                .fill(hasEpisodes ? (date.isToday ? Theme.huntRed : Theme.huntTeal) : .clear)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Theme.huntRed.opacity(0.22) : Theme.hairline.opacity(0.001))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(date.isToday ? Theme.huntRed : Theme.hairline.opacity(0.12), lineWidth: date.isToday ? 1.5 : 1)
        }
        .opacity(isCurrentMonth ? 1 : 0.35)
    }
}

private struct CalendarNavigationChrome: ViewModifier {
    let isActive: Bool
    let viewModel: CalendarViewModel

    func body(content: Content) -> some View {
        if isActive {
            content
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        Button("Today", action: viewModel.goToToday)
                        Button(action: viewModel.previousMonth) {
                            Image(systemName: "chevron.left")
                        }
                        Button(action: viewModel.nextMonth) {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
        } else {
            content
        }
    }
}
