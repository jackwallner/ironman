import SwiftUI

/// Find yourself in the results feed and claim the record.
///
/// This is the whole onboarding. There is no account to create and nothing to
/// type in but a name, because every result the app shows already exists: the
/// only thing it needs from the athlete is which of the several thousand people
/// named "Wallner" they are.
///
/// The search runs in two phases. The fast one, `startswith` upstream, answers
/// in about a second and a half and is what fires on every keystroke. The slow
/// one, `contains`, is a full scan of somebody else's table and takes around
/// thirty seconds, so it only runs when the fast pass found nothing and the
/// screen says out loud that it is looking harder. See `SearchDepth`.
struct AthleteSearchView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var pattie: PattieMode
    @Environment(\.dismiss) private var dismiss

    /// Shown as a first-run screen, a replacement sheet, or an official
    /// contact search that adds another registration to the current profile.
    var isOnboarding: Bool = false
    var addingToCurrentAthlete: Bool = false

    @State private var query = ""
    @State private var matches: [Athlete] = []
    @State private var phase: Phase = .idle
    @State private var errorMessage: String?
    @State private var claiming: Athlete?
    @FocusState private var fieldFocused: Bool

    private enum Phase: Equatable {
        case idle
        /// The `startswith` pass.
        case quick
        /// The `contains` scan, after the quick pass came back empty.
        case deep
        case done
    }

    private let api = ResultsAPI()

    var body: some View {
        NavigationStack {
            ZStack {
                TriPalette.canvas.ignoresSafeArea()
                content
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.white)
                            .triTapTarget()
                    }
                }
            }
        }
        .pattieMoment(.searching, pattie)
        .task {
            // Not awaited before the first search can run: the hotfix channel
            // is a nice-to-have and the cached config already works.
            await FeedConfigLoader.shared.refreshIfStale()
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            searchField
            if isSearching && matches.isEmpty {
                Spacer()
                searchingState
                Spacer()
            } else {
                results
            }
        }
    }

    private var isSearching: Bool { phase == .quick || phase == .deep }

    @ViewBuilder
    private var results: some View {
        if let errorMessage {
            Spacer()
            TriPlaceholder(systemImage: "wifi.exclamationmark",
                           title: "Couldn't search",
                           message: errorMessage,
                           actionTitle: "Try again") { runSearch() }
            Spacer()
        } else if matches.isEmpty && phase == .done {
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
                .buttonStyle(.triPress)
                .listRowBackground(TriPalette.surface)
                .listRowInsets(EdgeInsets(top: TriSpace.x2, leading: TriGeo.padPage,
                                          bottom: TriSpace.x2, trailing: TriGeo.padPage))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var searchingState: some View {
        VStack(spacing: TriSpace.x3) {
            ProgressView().tint(TriPalette.deep)
            // The deep pass is the slow one, and saying so is the difference
            // between "it's working" and "it's broken".
            Text(phase == .deep
                 ? "No exact match. Searching the whole index, which takes a moment…"
                 : "Searching…")
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, TriSpace.x8)
        }
    }

    /// A native-height field set in the native size. It was 15pt in a 12pt box
    /// before, which is smaller than every other text field on the phone and
    /// reads as a web form in a wrapper.
    private var searchField: some View {
        HStack(spacing: TriSpace.x2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(fieldFocused ? TriPalette.sunrise : TriPalette.inkTertiary)

            TextField("Your name as you registered", text: $query)
                .font(TriType.field)
                .foregroundStyle(TriPalette.ink)
                .tint(TriPalette.sunrise)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .textContentType(.name)
                .submitLabel(.search)
                .focused($fieldFocused)
                .onSubmit { runSearch() }

            if !query.isEmpty {
                Button {
                    Haptics.tap()
                    pattie.react(.selection)
                    query = ""
                    matches = []
                    phase = .idle
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(TriPalette.inkTertiary)
                        .triTapTarget(TriGeo.tapTarget - TriSpace.x2)
                }
                .buttonStyle(.triPressSilent)
            }
        }
        .padding(.horizontal, TriSpace.x3)
        .frame(height: TriGeo.tapTarget + TriSpace.x2)
        .background(TriPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                .stroke(fieldFocused ? TriPalette.sunrise : TriPalette.hairline,
                        lineWidth: fieldFocused ? 1.5 : TriGeo.hairline)
        )
        .animation(.easeInOut(duration: 0.18), value: fieldFocused)
        .padding(TriGeo.padPage)
        // Debounced rather than per-keystroke: each search is a real request to
        // somebody else's service, and "Pattie" would otherwise fire six.
        .task(id: query) {
            guard query.trimmingCharacters(in: .whitespaces).count >= 3 else { return }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            runSearch()
        }
    }

    private var introBlurb: some View {
        VStack(spacing: TriSpace.x4) {
            Image(systemName: "figure.open.water.swim")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(TriPalette.inkSecondary)
            Text("Type your name")
                .font(TriType.cardTitle)
                .foregroundStyle(TriPalette.inkSecondary)
            Text(introText)
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, TriSpace.x8)
    }

    private func runSearch() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else { return }
        errorMessage = nil
        pattie.react(.search)
        phase = .quick
        Task {
            do {
                var found = try await api.searchAthletes(matching: term, depth: .prefix)
                if found.isEmpty {
                    guard !Task.isCancelled, query.trimmingCharacters(in: .whitespacesAndNewlines) == term else { return }
                    phase = .deep
                    found = try await api.searchAthletes(matching: term, depth: .substring)
                }
                guard !Task.isCancelled else { return }
                matches = found
                phase = .done
                if !found.isEmpty { Haptics.success() }
            } catch {
                guard !isTaskCancellation(error) else { return }
                errorMessage = error.localizedDescription
                phase = .done
            }
        }
    }

    private func claim(_ athlete: Athlete) {
        Haptics.tap(.medium)
        claiming = athlete
        Task {
            if addingToCurrentAthlete {
                await locker.addContact(from: athlete)
            } else {
                await locker.claim(athlete)
            }
            claiming = nil
            Haptics.success()
            if !isOnboarding { dismiss() }
        }
    }

    private var title: String {
        if isOnboarding { return "Find your races" }
        if addingToCurrentAthlete { return "Find another registration" }
        return "Change athlete"
    }

    private var introText: String {
        if addingToCurrentAthlete {
            return "Search the official results feed for another name you raced under. Choose the right person and those published races will be added to this profile."
        }
        return "Every race you have finished is already published under the name you registered with. Find yourself once and your locker fills in: bibs, splits, division places and all."
    }
}

private struct AthleteRow: View {
    let athlete: Athlete
    let isClaiming: Bool

    var body: some View {
        HStack(spacing: TriSpace.x3) {
            VStack(alignment: .leading, spacing: TriSpace.x1) {
                Text(athlete.name)
                    .font(TriType.cardTitle)
                    .foregroundStyle(TriPalette.ink)
                    .multilineTextAlignment(.leading)
                if !athlete.subtitle.isEmpty {
                    Text(athlete.subtitle)
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: TriSpace.x2)
            if isClaiming {
                ProgressView().tint(TriPalette.deep)
            } else {
                // "At least", because the search reads a capped number of rows:
                // claiming the athlete is what pulls their complete history.
                Text(String(athlete.knownRaceCount) + "+ races")
                    .font(TriType.statSmall)
                    .foregroundStyle(TriPalette.inkTertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TriPalette.inkTertiary)
            }
        }
        .frame(minHeight: TriGeo.tapTarget + TriSpace.x2)
        .contentShape(Rectangle())
    }
}
