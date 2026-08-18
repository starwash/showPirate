import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store: LibraryStore?
    @State private var selectedItem: SidebarItem? = Self.initialSidebarItem()

    private static func initialSidebarItem() -> SidebarItem? {
        guard let raw = ProcessInfo.processInfo.environment["SHOWPIRATE_INITIAL_TAB"],
              let item = SidebarItem(rawValue: raw) else {
            return .dashboard
        }
        return item
    }
    @State private var path = NavigationPath()

    var body: some View {
        Group {
            if let store {
                splitView
                    .environment(store)
            }
        }
        .task {
            if store == nil {
                store = LibraryStore(context: modelContext)
            }
            if let store {
                Task {
                    await store.warmWatchCaches()
                }
                try? await Task.sleep(for: .seconds(1.5))
                await CatalogAutoRefresh.runIfNeeded(using: store)
            }
        }
    }

    private var splitView: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                Section("Navigate") {
                    ForEach(SidebarItem.allCases.filter { $0 != .settings }) { item in
                        Label(item.title, systemImage: item.systemImage)
                            .tag(item)
                    }
                }
                Section {
                    Label(SidebarItem.settings.title, systemImage: SidebarItem.settings.systemImage)
                        .tag(SidebarItem.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
            .navigationTitle("showPirate")
        } detail: {
            NavigationStack(path: $path) {
                detailView
                    .navigationDestination(for: Int.self) { tmdbID in
                        ShowDetailView(tmdbID: tmdbID)
                    }
            }
        }
        .onChange(of: selectedItem) { _, _ in
            path = NavigationPath()
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Theme.gold)
    }

    private var detailView: some View {
        let selection = selectedItem ?? .dashboard
        return Group {
            switch selection {
            case .dashboard:
                DashboardView()
            case .library:
                LibraryView()
            case .search:
                SearchView()
            case .calendar:
                CalendarView()
            case .statistics:
                StatisticsView()
            case .settings:
                SettingsView()
            }
        }
        .navigationTitle(selection.title)
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.makeContainer())
}
