import SwiftUI

/// Find yourself in the results feed and claim the record.
///
/// This is the whole onboarding. There is no account to create and nothing to
/// type in but a name, because every result the app shows already exists — the
/// only thing it needs from the athlete is which of the several thousand people
/// named "Wallner" they are.
struct AthleteSearchView: View {
    @EnvironmentObject private var locker: LockerStore
    @Environment(\.dismiss) private var dismiss

    /// Shown as a first-run screen (no cancel) or as a "change athlete" sheet.
    var isOnboarding: Bool = false

    @State private var query = ""
    @State private var matches: [Athlete] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var hasSearched = false
    @State private var claiming: Athlete?

    private let api = ResultsAPI()

    var body: some View {
        NavigationStack {
            ZStack {
                TriPalette.canvas.ignoresSafeArea()
                content
            }
            .navigationTitle(isOnboarding ? "Find your races" : "Change athlete")
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .task { await FeedConfigLoader.shared.refreshIfStale() }
    }

    private var content: some View {
        VStack(spacing: 0) {
            searchField

            if isSearching && matches.isEmpty {
                Spacer()
                ProgressView().tint(TriPalette.deep)
                Spacer()
            } else if let errorMessage {
                Spacer()
                TriPlaceholder(systemImage: "wifi.exclamationmark",
                               title: "Couldn't search",
                               message: errorMessage,
                               actionTitle: "Try again") { runSearch() }
                Spacer()
            } else if matches.isEmpty && hasSearched {
                Spacer()
                TriPlaceholder(systemImage: "magnifyingglass",
                               title: "No athletes found",
                               message: "Try the name exactly as it appeared on your race entry. Results are listed under the name you registered with, which is often a full legal first name.")
                Spacer()
            } else if matches.isEmpty {
                Spacer()
                introBlurb
                Spacer()
            } else {
                List(matches) { athlete in
                    Button {
                        claim(athlete)
                    } label: {
                        AthleteRow(athlete: athlete, isClaiming: claiming?.id == athlete.id)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(TriPalette.surface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TriPalette.inkTertiary)
            TextField("Your name as you registered", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { runSearch() }
                .font(TriType.body)
            if !query.isEmpty {
                Button {
                    query = ""
                    matches = []
                    hasSearched = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TriPalette.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(TriPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
        .padding(TriGeo.padPage)
        // Debounced rather than per-keystroke: each search is a real request to
        // somebody else's service, and "Pattie" would otherwise fire six.
        .task(id: query) {
            guard query.trimmingCharacters(in: .whitespaces).count >= 3 else { return }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            runSearch()
        }
    }

    private var introBlurb: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.open.water.swim")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(TriPalette.deep)
            Text("Type your name")
                .font(TriType.cardTitle)
                .foregroundStyle(TriPalette.inkSecondary)
            Text("Every race you have finished is already published under the name you registered with. Find yourself once and your locker fills in — bibs, splits, division places and all.")
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
    }

    private func runSearch() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else { return }
        isSearching = true
        errorMessage = nil
        Task {
            defer { isSearching = false }
            do {
                let found = try await api.searchAthletes(matching: term)
                matches = found
                hasSearched = true
            } catch {
                guard !isTaskCancellation(error) else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func claim(_ athlete: Athlete) {
        claiming = athlete
        Task {
            await locker.claim(athlete)
            claiming = nil
            if !isOnboarding { dismiss() }
        }
    }
}

private struct AthleteRow: View {
    let athlete: Athlete
    let isClaiming: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(athlete.name)
                    .font(TriType.cardTitle)
                    .foregroundStyle(TriPalette.ink)
                if !athlete.subtitle.isEmpty {
                    Text(athlete.subtitle)
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if isClaiming {
                ProgressView().tint(TriPalette.deep)
            } else {
                // "At least", because the search reads a capped number of rows:
                // claiming the athlete is what pulls their complete history.
                Text(String(athlete.knownRaceCount) + "+")
                    .font(TriType.statSmall)
                    .foregroundStyle(TriPalette.inkTertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TriPalette.inkTertiary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
