import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case library
    case search
    case calendar
    case statistics
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .library: "Library"
        case .search: "Search"
        case .calendar: "Calendar"
        case .statistics: "Statistics"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .library: "rectangle.stack"
        case .search: "magnifyingglass"
        case .calendar: "calendar"
        case .statistics: "chart.bar"
        case .settings: "gearshape"
        }
    }
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case watching
    case completed
    case upcoming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .watching: "Watching"
        case .completed: "Completed"
        case .upcoming: "Upcoming"
        }
    }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case name
    case progress
    case dateAdded
    case nextAirDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "Name"
        case .progress: "Progress"
        case .dateAdded: "Recently added"
        case .nextAirDate: "Upcoming air date"
        }
    }
}

enum LibraryLayout: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grid: "Grid"
        case .list: "List"
        }
    }

    var systemImage: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }
}
