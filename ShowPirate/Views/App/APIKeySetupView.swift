import SwiftUI

struct APIKeySetupView: View {
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 24)
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.gold)
                Text("Add your TMDB key")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Theme.cream)
                Text("Search, posters refresh, and catalog updates need a free TMDB API Key (v3). The key stays on this Mac and is not synced.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.parchment.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    SecureField("TMDB API Key (v3)", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isValidating)
                        .onSubmit { Task { await save() } }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.gold)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isValidating ? "Checking key…" : "Continue")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)

                    Link("Get a free key at themoviedb.org", destination: URL(string: "https://www.themoviedb.org/settings/api")!)
                        .font(.caption)
                }
            }
            .frame(maxWidth: 480)

            Spacer(minLength: 24)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pirateScreen()
    }

    private func save() async {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isValidating = true
        errorMessage = nil
        defer { isValidating = false }
        do {
            try await TMDBService.shared.validateAPIKey(trimmed)
            APIConfig.setAPIKey(trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
