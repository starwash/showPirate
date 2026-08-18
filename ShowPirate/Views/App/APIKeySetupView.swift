import SwiftUI

struct APIKeySetupView: View {
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            setupBackground
            GeometryReader { geo in
                let wide = geo.size.width >= 980
                Group {
                    if wide {
                        HStack(alignment: .center, spacing: 72) {
                            hero(alignment: .leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            formCard
                        }
                    } else {
                        VStack(spacing: 40) {
                            hero(alignment: .center)
                            formCard
                        }
                    }
                }
                .frame(maxWidth: 1080)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, wide ? 72 : 40)
                .padding(.vertical, 40)
            }
        }
        .onAppear { fieldFocused = true }
    }

    private var setupBackground: some View {
        ZStack {
            Theme.ink
            RadialGradient(
                colors: [
                    Theme.cyan.opacity(0.28),
                    Theme.cyan.opacity(0.08),
                    .clear
                ],
                center: UnitPoint(x: 0.28, y: 0.22),
                startRadius: 20,
                endRadius: 560
            )
            RadialGradient(
                colors: [
                    Theme.gold.opacity(0.10),
                    .clear
                ],
                center: UnitPoint(x: 0.85, y: 0.9),
                startRadius: 10,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }

    private func hero(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 22) {
            Image("BrandLogo")
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(width: 188, height: 188)
                .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
                .shadow(color: Theme.cyan.opacity(0.35), radius: 28, y: 8)
                .shadow(color: .black.opacity(0.28), radius: 32, y: 18)

            VStack(alignment: alignment, spacing: 10) {
                Text("showPirate")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.cream)
                    .tracking(0.4)

                Text("Navigate your favorite shows.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.cyan)

                Rectangle()
                    .fill(Theme.gold.opacity(0.85))
                    .frame(width: 56, height: 3)
                    .clipShape(Capsule())
                    .padding(.top, 4)

                Text("Search, posters, and catalog updates need a free TMDB API Key (v3). It stays on this Mac and is never written to the sync folder.")
                    .font(.body)
                    .foregroundStyle(Theme.parchment.opacity(0.72))
                    .multilineTextAlignment(alignment == .leading ? .leading : .center)
                    .frame(maxWidth: 420, alignment: alignment == .leading ? .leading : .center)
                    .padding(.top, 6)
            }
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Welcome aboard")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.cream)
            Text("Paste your API Key (v3) to open the library.")
                .font(.subheadline)
                .foregroundStyle(Theme.parchment.opacity(0.7))

            VStack(alignment: .leading, spacing: 8) {
                Text("TMDB API Key (v3)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.parchment.opacity(0.65))
                SecureField("Paste key", text: $apiKey)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.navyDeep.opacity(0.72))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                errorMessage == nil ? Theme.cyan.opacity(0.35) : Theme.gold.opacity(0.8),
                                lineWidth: 1
                            )
                    )
                    .focused($fieldFocused)
                    .disabled(isValidating)
                    .onSubmit { Task { await save() } }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.gold)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await save() }
            } label: {
                HStack(spacing: 8) {
                    if isValidating {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isValidating ? "Checking key…" : "Continue")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)

            Link(destination: URL(string: "https://www.themoviedb.org/settings/api")!) {
                Label("Get a free key at themoviedb.org", systemImage: "arrow.up.right")
                    .font(.caption)
            }
        }
        .padding(28)
        .frame(maxWidth: 440)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.huntGray.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 28, y: 16)
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

#Preview {
    APIKeySetupView()
        .frame(width: 1240, height: 800)
        .pirateAppearance(.dark)
}
