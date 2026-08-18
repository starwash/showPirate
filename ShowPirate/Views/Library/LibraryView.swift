import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.sidebarTabIsActive) private var sidebarTabIsActive
    @Environment(LibraryStore.self) private var store
    @Query(filter: #Predicate<Show> { $0.inLibrary }, sort: \Show.name)
    private var shows: [Show]
    @State private var viewModel = LibraryViewModel()
    @AppStorage("library.layout") private var layout: LibraryLayout = .list
    @AppStorage("library.sort") private var sort: LibrarySort = .name
    @State private var showPendingDelete: Show?
    @State private var isRefreshing = false
    @State private var refreshMessage: String?

    var body: some View {
        let items = viewModel.filtered(shows, sort: sort)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                Picker("Filter", selection: $viewModel.filter) {
                    ForEach(LibraryFilter.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)

                Spacer(minLength: 8)

                Picker("Sort", selection: $sort) {
                    ForEach(LibrarySort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
                .help("Sort library")
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.ink)

            ScrollView {
                if items.isEmpty {
                    EmptyStateView(
                        title: "Empty catalog",
                        systemImage: "rectangle.stack.badge.plus",
                        message: "Search TMDB and add series to start tracking."
                    )
                    .frame(minHeight: 360)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                } else if layout == .grid {
                    grid(items)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                } else {
                    list(items)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
        }
        .modifier(LibraryNavigationChrome(
            isActive: sidebarTabIsActive,
            searchText: $viewModel.searchText,
            layout: $layout,
            isRefreshing: isRefreshing,
            showsEmpty: shows.isEmpty,
            refresh: { Task { await refreshCatalog() } }
        ))
        .pirateScreen()
        .alert(
            "Remove \(showPendingDelete?.name ?? "this show")?",
            isPresented: Binding(
                get: { showPendingDelete != nil },
                set: { if !$0 { showPendingDelete = nil } }
            )
        ) {
            Button("Remove", role: .destructive) {
                if let show = showPendingDelete {
                    try? store.removeFromLibrary(show)
                }
                showPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                showPendingDelete = nil
            }
        } message: {
            Text("This deletes the show and its watch progress from your catalog.")
        }
        .alert("Catalog refresh", isPresented: Binding(
            get: { refreshMessage != nil },
            set: { if !$0 { refreshMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                refreshMessage = nil
            }
        } message: {
            Text(refreshMessage ?? "")
        }
    }

    private func refreshCatalog() async {
        isRefreshing = true
        let result = await store.refreshLibrary()
        isRefreshing = false
        if result.failed == 0 {
            refreshMessage = result.refreshed == 1
                ? "Updated 1 show from TMDB."
                : "Updated \(result.refreshed) shows from TMDB."
        } else {
            refreshMessage = "Updated \(result.refreshed) shows. \(result.failed) failed."
        }
    }

    private func grid(_ items: [Show]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 18)],
            spacing: 22
        ) {
            ForEach(items) { show in
                NavigationLink(value: show.tmdbID) {
                    ShowCard(show: show)
                }
                .buttonStyle(.plain)
                .showLibraryContextMenu(show: show, store: store, pendingDelete: $showPendingDelete)
            }
        }
    }

    private func list(_ items: [Show]) -> some View {
        LazyVStack(spacing: 12) {
            ForEach(items) { show in
                NavigationLink(value: show.tmdbID) {
                    ShowListRow(show: show)
                }
                .buttonStyle(.plain)
                .showLibraryContextMenu(show: show, store: store, pendingDelete: $showPendingDelete)
            }
        }
    }
}

private struct LibraryNavigationChrome: ViewModifier {
    let isActive: Bool
    @Binding var searchText: String
    @Binding var layout: LibraryLayout
    let isRefreshing: Bool
    let showsEmpty: Bool
    let refresh: () -> Void

    func body(content: Content) -> some View {
        if isActive {
            content
                .searchable(text: $searchText, prompt: "Filter library")
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button(action: refresh) {
                            if isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Refresh All", systemImage: "arrow.clockwise")
                            }
                        }
                        .disabled(isRefreshing || showsEmpty)
                        .help("Update library metadata and new episodes from TMDB")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Picker("Layout", selection: $layout) {
                            ForEach(LibraryLayout.allCases) { layout in
                                Image(systemName: layout.systemImage)
                                    .tag(layout)
                                    .help(layout.title)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
        } else {
            content
        }
    }
}

private extension View {
    func showLibraryContextMenu(
        show: Show,
        store: LibraryStore,
        pendingDelete: Binding<Show?>
    ) -> some View {
        contextMenu {
            if show.hasUnwatchedAired {
                Button("Watched Everything", systemImage: "checkmark.circle") {
                    try? store.setShow(show, watched: true)
                }
            } else {
                Button("Unwatch All", systemImage: "arrow.uturn.backward.circle") {
                    try? store.setShow(show, watched: false)
                }
            }
            Divider()
            Button("Remove from Library", role: .destructive) {
                pendingDelete.wrappedValue = show
            }
        }
    }
}
