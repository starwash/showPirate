import Foundation
import Observation

@Observable
@MainActor
final class LibraryViewModel {
    var filter: LibraryFilter = .all
    var searchText = ""

    private var cachedItems: [Show] = []
    private var cacheKey = ""

    func filtered(_ shows: [Show], sort: LibrarySort = .name) -> [Show] {
        let key = cacheKey(for: shows, sort: sort)
        if key == cacheKey {
            return cachedItems
        }

        let matches = shows.filter { show in
            let matchesSearch = searchText.isEmpty
                || show.name.localizedCaseInsensitiveContains(searchText)
            switch filter {
            case .all: return matchesSearch
            case .watching: return matchesSearch && show.isWatching
            case .completed: return matchesSearch && show.isCompleted
            case .upcoming: return matchesSearch && show.hasUpcoming
            }
        }

        let result: [Show]
        switch sort {
        case .name:
            result = matches.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .dateAdded:
            result = matches.sorted {
                if $0.dateAdded != $1.dateAdded { return $0.dateAdded > $1.dateAdded }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .progress:
            let ranked = matches.map { show in (show, show.progress, show.name) }
            result = ranked.sorted {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                return $0.2.localizedCaseInsensitiveCompare($1.2) == .orderedAscending
            }.map(\.0)
        case .nextAirDate:
            let ranked = matches.map { show in (show, nextAirSortDate(show), show.name) }
            result = ranked.sorted {
                if $0.1 != $1.1 { return $0.1 < $1.1 }
                return $0.2.localizedCaseInsensitiveCompare($1.2) == .orderedAscending
            }.map(\.0)
        }

        cacheKey = key
        cachedItems = result
        return result
    }

    private func cacheKey(for shows: [Show], sort: LibrarySort) -> String {
        let fingerprint = shows.reduce(into: 0) { partial, show in
            partial &+= show.tmdbID
            partial &+= Int(show.lastUpdated.timeIntervalSince1970)
            partial &+= show.cachedWatchedCount
        }
        return "\(filter.rawValue)-\(sort.rawValue)-\(searchText)-\(fingerprint)"
    }

    private func nextAirSortDate(_ show: Show) -> Date {
        show.cachedNextAirDate?.startOfDay ?? .distantFuture
    }
}

@Observable
@MainActor
final class DashboardViewModel {
    func snapshot(from shows: [Show]) -> DashboardSnapshot {
        DashboardProjector.snapshot(from: shows)
    }
}

@Observable
@MainActor
final class StatisticsViewModel {
    func stats(from shows: [Show]) -> WatchStats {
        StatisticsService.stats(for: shows)
    }
}
