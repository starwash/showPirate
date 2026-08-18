import SwiftUI

struct SearchView: View {
    @Environment(LibraryStore.self) private var store
    @AppStorage(APIConfig.settingsKey) private var apiKey = ""
    @State private var viewModel = SearchViewModel()

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            content
        }
        .pirateScreen()
        .task {
            await viewModel.loadDiscover()
        }
        .onChange(of: apiKey) { _, _ in
            Task { await viewModel.loadDiscover(force: true) }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.gold)
            TextField("Search TV shows on TMDB", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .disabled(!APIConfig.hasAPIKey)
                .onChange(of: viewModel.query) {
                    viewModel.queryChanged()
                }
            if viewModel.isSearching {
                ProgressView()
                    .controlSize(.small)
            }
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                    viewModel.results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.parchment.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage, !viewModel.isQueryEmpty, viewModel.results.isEmpty {
            EmptyStateView(
                title: "Search unavailable",
                systemImage: "key.slash",
                message: error
            )
        } else if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            discoverContent
        } else if viewModel.results.isEmpty && !viewModel.isSearching {
            EmptyStateView(
                title: "No matches",
                systemImage: "tv.slash",
                message: "Try a different title."
            )
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 18)],
                    spacing: 22
                ) {
                    ForEach(viewModel.results) { result in
                        SearchResultCard(
                            result: result,
                            inLibrary: store.libraryShowIDs.contains(result.id),
                            isAdding: viewModel.addingIDs.contains(result.id),
                            onAdd: { markWatched in
                                Task { await viewModel.addToLibrary(id: result.id, store: store, markWatched: markWatched) }
                            }
                        )
                    }
                }
                .padding(24)
            }
        }
    }

    @ViewBuilder
    private var discoverContent: some View {
        if !APIConfig.hasAPIKey {
            EmptyStateView(
                title: "TMDB API key required",
                systemImage: "key",
                message: "Add your free TMDB API key in Settings to search shows and browse trending titles."
            )
        } else if viewModel.isLoadingDiscover && viewModel.trending.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    discoverRow(title: "Trending this week", shows: viewModel.trending)
                    discoverRow(title: "Popular", shows: viewModel.popular)
                    discoverRow(title: "On the air", shows: viewModel.onAir)
                }
                .padding(24)
            }
        }
    }

    private func discoverRow(title: String, shows: [TMDBSearchShow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            if shows.isEmpty {
                Text("Nothing to show yet.")
                    .foregroundStyle(Theme.parchment.opacity(0.7))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(shows) { result in
                            SearchResultCard(
                                result: result,
                                inLibrary: store.libraryShowIDs.contains(result.id),
                                isAdding: viewModel.addingIDs.contains(result.id),
                                onAdd: { markWatched in
                                    Task { await viewModel.addToLibrary(id: result.id, store: store, markWatched: markWatched) }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct SearchResultCard: View {
    let result: TMDBSearchShow
    let inLibrary: Bool
    let isAdding: Bool
    let onAdd: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterView(path: result.posterPath, width: 160)

            Text(result.name)
                .font(.headline)
                .foregroundStyle(Theme.cream)
                .lineLimit(1)
            Text(result.yearLabel.isEmpty ? "TV Series" : result.yearLabel)
                .font(.caption)
                .foregroundStyle(Theme.parchment.opacity(0.7))

            if inLibrary {
                NavigationLink(value: result.id) {
                    Label("In Library", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Theme.watchedGreen)
            } else if isAdding {
                ProgressView()
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            } else {
                Menu {
                    Button("Add to Library", systemImage: "plus") {
                        onAdd(false)
                    }
                    Button("Watched Everything", systemImage: "checkmark.circle.fill") {
                        onAdd(true)
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .menuStyle(.borderedButton)
                .controlSize(.large)
                .tint(Theme.huntRed)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 160, alignment: .leading)
    }
}
