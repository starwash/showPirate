import SwiftUI

struct SettingsView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(CatalogSync.self) private var catalogSync
    @AppStorage("appearance") private var appearance: AppearancePreference = .system
    @State private var apiKey: String = UserDefaults.standard.string(forKey: APIConfig.settingsKey) ?? ""
    @State private var confirmClear = false
    @State private var statusMessage: String?
    @State private var isRefreshing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "showPirate", subtitle: "Navigate your favorite shows.")

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Appearance")
                            .font(.headline)
                            .foregroundStyle(Theme.cream)
                        Text("Light, Dark, or Auto. Auto follows macOS and switches to Dark in the evening.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.parchment.opacity(0.7))
                        Picker("Appearance", selection: $appearance) {
                            ForEach(AppearancePreference.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TMDB API Key")
                            .font(.headline)
                            .foregroundStyle(Theme.cream)
                        Text("Search and catalog refresh use The Movie Database. Add your own free TMDB API key to get started. The app ships with an empty library.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.parchment.opacity(0.7))
                        SecureField("TMDB API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("Save Key") {
                                APIConfig.setAPIKey(apiKey)
                                statusMessage = APIConfig.hasAPIKey ? "API key saved." : "API key cleared."
                            }
                            .buttonStyle(.borderedProminent)
                            if APIConfig.hasAPIKey {
                                Label("Key saved", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.lime)
                            } else {
                                Label("Key required", systemImage: "exclamationmark.circle")
                                    .foregroundStyle(Theme.gold)
                            }
                        }
                        Link("Get a free key at themoviedb.org", destination: URL(string: "https://www.themoviedb.org/settings/api")!)
                            .font(.caption)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sync folder")
                            .font(.headline)
                            .foregroundStyle(Theme.cream)
                        Text("Choose a Dropbox, iCloud Drive, or Syncthing folder. Both Macs use the same folder. showPirate writes showPirate-library.json there. The TMDB API key stays on this computer. If both Macs edit at once, the last save wins.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.parchment.opacity(0.7))
                        Text(catalogSync.folderLabel)
                            .font(.caption)
                            .foregroundStyle(Theme.cyan)
                        Text(catalogSync.statusMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.parchment.opacity(0.7))
                        if let last = catalogSync.lastSyncedAt {
                            Text("Last sync \(Formatters.relative.localizedString(for: last, relativeTo: .now)).")
                                .font(.caption)
                                .foregroundStyle(Theme.cyan)
                        }
                        HStack {
                            Button("Choose Folder…") {
                                catalogSync.chooseFolder()
                            }
                            .buttonStyle(.borderedProminent)
                            if catalogSync.isConnected {
                                Button("Disconnect") {
                                    catalogSync.disconnect()
                                }
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Library")
                            .font(.headline)
                            .foregroundStyle(Theme.cream)
                        Text("The catalog refreshes automatically once a day when you open the app. Refresh now pulls new seasons, episodes, posters, and status from TMDB without clearing watched flags.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.parchment.opacity(0.7))
                        if let last = CatalogAutoRefresh.lastRefresh {
                            Text("Last refresh \(Formatters.relative.localizedString(for: last, relativeTo: .now)).")
                                .font(.caption)
                                .foregroundStyle(Theme.cyan)
                        }
                        HStack {
                            Button {
                                Task { await refreshCatalog() }
                            } label: {
                                if isRefreshing {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Refresh catalog")
                                }
                            }
                            .disabled(isRefreshing)
                            Button("Empty catalog…", role: .destructive) {
                                confirmClear = true
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Attribution")
                            .font(.headline)
                            .foregroundStyle(Theme.cream)
                        Text("This product uses the TMDB API but is not endorsed or certified by TMDB. Poster and still images are provided by TMDB.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.parchment.opacity(0.7))
                        Link("themoviedb.org", destination: URL(string: "https://www.themoviedb.org")!)
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .foregroundStyle(Theme.cyan)
                }
            }
            .padding(24)
        }
        .pirateScreen()
        .alert("Empty catalog?", isPresented: $confirmClear) {
            Button("Empty catalog", role: .destructive) {
                do {
                    try store.clearLibrary()
                    statusMessage = "Catalog is empty."
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every show and all watch progress.")
        }
    }

    private func refreshCatalog() async {
        isRefreshing = true
        let result = await store.refreshLibrary()
        isRefreshing = false
        if result.failed == 0 {
            statusMessage = result.refreshed == 1
                ? "Updated 1 show from TMDB."
                : "Updated \(result.refreshed) shows from TMDB."
        } else {
            statusMessage = "Updated \(result.refreshed) shows. \(result.failed) failed."
        }
    }
}
