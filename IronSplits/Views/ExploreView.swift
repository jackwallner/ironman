import SwiftUI

/// A read-only way to browse another athlete's official history.
///
/// The Locker is the user's own record. Explore deliberately uses the same
/// search feed without calling LockerStore.claim, so looking at a friend,
/// teammate, or favorite racer cannot replace the athlete on the home tab.
struct ExploreView: View {
    @EnvironmentObject private var pattie: PattieMode
    @State private var showingSearch = false
    @State private var selectedAthlete: Athlete?
    @State private var recentAthletes: [Athlete] = []

    var body: some View {
        NavigationStack {
            ZStack {
                TriPalette.canvas.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: TriSpace.x6) {
                        hero
                        searchAction
                        if !recentAthletes.isEmpty {
                            recentSection
                        }
                    }
                    .padding(.horizontal, TriGeo.padPage)
                    .padding(.top, TriSpace.x4)
                    .padding(.bottom, TriGeo.tabBarClearance)
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .sheet(isPresented: $showingSearch) {
                AthleteSearchView(onSelect: select)
            }
            .navigationDestination(item: $selectedAthlete) { athlete in
                ExploreAthleteView(athlete: athlete)
            }
        }
        .pattieMoment(.searching, pattie)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: TriSpace.x3) {
            HStack(alignment: .top, spacing: TriSpace.x3) {
                Image(systemName: "person.2.fill")
                    .font(TriType.pageTitle)
                    .foregroundStyle(TriPalette.sunrise)
                    .frame(width: TriSpace.x10, height: TriSpace.x10)
                    .background(TriPalette.sunrise.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: TriSpace.x1) {
                    Text("EXPLORE RACERS")
                        .font(TriType.sectionTitle)
                        .foregroundStyle(TriPalette.sunrise)
                        .tracking(1.2)
                    Text("See the story behind the splits")
                        .font(TriType.pageTitle)
                        .foregroundStyle(TriPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Search the official results index for another athlete and browse a focused full and half-distance race history. Your Locker stays exactly as it is.")
                .font(TriType.body)
                .foregroundStyle(TriPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .triCard(padding: TriSpace.x4)
    }

    private var searchAction: some View {
        Button {
            pattie.react(.selection)
            showingSearch = true
        } label: {
            HStack(spacing: TriSpace.x3) {
                Image(systemName: "magnifyingglass")
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.inkOnDark)
                    .frame(width: TriSpace.x8)
                VStack(alignment: .leading, spacing: TriSpace.x1) {
                    Text("Find a racer")
                        .font(TriType.bodyBold)
                        .foregroundStyle(TriPalette.inkOnDark)
                    Text("Open their career without changing Locker")
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkOnDark.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
                Spacer(minLength: TriSpace.x2)
                Image(systemName: "chevron.right")
                    .font(TriType.smallBold)
                    .foregroundStyle(TriPalette.inkOnDark.opacity(0.8))
            }
            .frame(maxWidth: .infinity, minHeight: TriGeo.tapTarget, alignment: .leading)
            .padding(.horizontal, TriSpace.x4)
            .padding(.vertical, TriSpace.x3)
            .background(TriPalette.deep, in: RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
        }
        .buttonStyle(.triPress)
        .accessibilityLabel("Find a racer")
        .accessibilityHint("Search official results without changing Locker")
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: TriSpace.x3) {
            TriSectionHeader(title: "Recently explored")
            ForEach(recentAthletes) { athlete in
                Button {
                    pattie.react(.selection)
                    selectedAthlete = athlete
                } label: {
                    ExploreAthleteRow(athlete: athlete)
                }
                .buttonStyle(.triPress)
            }
        }
    }

    private func select(_ athlete: Athlete) {
        recentAthletes.removeAll { $0.id == athlete.id }
        recentAthletes.insert(athlete, at: 0)
        recentAthletes = Array(recentAthletes.prefix(3))
        selectedAthlete = athlete
        pattie.react(.selection)
    }
}

private struct ExploreAthleteRow: View {
    let athlete: Athlete

    var body: some View {
        HStack(spacing: TriSpace.x3) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(TriPalette.deep)
                .frame(width: TriSpace.x10, height: TriSpace.x10)
            VStack(alignment: .leading, spacing: TriSpace.x1) {
                Text(athlete.name)
                    .font(TriType.cardTitle)
                    .foregroundStyle(TriPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let location = athlete.location {
                    Text(location)
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: TriSpace.x2)
            Image(systemName: "chevron.right")
                .font(TriType.smallBold)
                .foregroundStyle(TriPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: TriGeo.tapTarget, alignment: .leading)
        .padding(TriSpace.x3)
        .background(TriPalette.surface, in: RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                .stroke(TriPalette.hairline, lineWidth: TriGeo.hairline)
        }
    }
}

private struct ExploreAthleteView: View {
    let athlete: Athlete

    @State private var results: [RaceResult] = []
    @State private var state: LoadState = .idle
    @State private var selectedKind: RaceKind?

    private let api = ResultsAPI()

    private enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
        ZStack {
            TriPalette.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: TriSpace.x6) {
                    profileHeader
                    if case .failed(let message) = state {
                        TriPlaceholder(systemImage: "wifi.exclamationmark",
                                       title: "Couldn't load this history",
                                       message: message,
                                       actionTitle: "Try again") {
                            load()
                        }
                    } else if results.isEmpty && state == .loading {
                        loadingView
                    } else if results.isEmpty {
                        TriPlaceholder(systemImage: "flag.checkered",
                                       title: "No supported results",
                                       message: "This racer has no published full or half-distance results in the feed.")
                    } else {
                        distanceFilter
                        history
                    }
                }
                .padding(.horizontal, TriGeo.padPage)
                .padding(.top, TriSpace.x4)
                .padding(.bottom, TriSpace.x8)
            }
        }
        .navigationTitle(athlete.name)
        .navigationBarTitleDisplayMode(.inline)
        .triNavBar()
        .task { load() }
        .onChange(of: results) { _, _ in syncKind() }
    }

    private var profileHeader: some View {
        let summary = RaceAnalytics.summary(results)
        return VStack(alignment: .leading, spacing: TriSpace.x3) {
            Text(athlete.name)
                .font(TriType.athleteName)
                .foregroundStyle(TriPalette.inkOnDark)
                .fixedSize(horizontal: false, vertical: true)
            if let location = athlete.location {
                Text(location)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkOnDark.opacity(0.7))
            }
            HStack(spacing: TriSpace.x6) {
                StatTile(value: "\(summary.finishes)", caption: "Finishes", tint: TriPalette.inkOnDark)
                StatTile(value: "\(summary.fullDistance)", caption: "Full", tint: TriPalette.inkOnDark)
                StatTile(value: "\(summary.halfDistance)", caption: "Half", tint: TriPalette.inkOnDark)
                if summary.podiums > 0 {
                    StatTile(value: "\(summary.podiums)", caption: "Podiums", tint: TriPalette.sunrise)
                }
            }
            if let years = summary.years {
                Text("Racing since \(years.lowerBound)")
                    .font(TriType.micro)
                    .foregroundStyle(TriPalette.inkOnDark.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TriGeo.padCard)
        .background(TriPalette.deep, in: RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
    }

    private var distanceFilter: some View {
        VStack(alignment: .leading, spacing: TriSpace.x2) {
            TriSectionHeader(title: "Distance")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TriSpace.x2) {
                    ForEach(availableKinds, id: \.self) { kind in
                        TriChip(title: kind.longTitle,
                                isSelected: activeKind == kind) {
                            selectedKind = kind
                        }
                    }
                }
                .padding(.vertical, TriSpace.x1)
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: TriSpace.x3) {
            TriSectionHeader(title: "Race history", trailing: activeKind?.longTitle)
            ForEach(visibleResults) { result in
                RaceRow(result: result)
                    .padding(TriSpace.x3)
                    .background(TriPalette.surface, in: RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                            .stroke(TriPalette.hairline, lineWidth: TriGeo.hairline)
                    }
            }
            SplitLegend()
                .padding(.top, TriSpace.x1)
        }
    }

    private var loadingView: some View {
        VStack(spacing: TriSpace.x3) {
            ProgressView().tint(TriPalette.deep)
            Text("Loading this career…")
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: TriSpace.x10 + TriSpace.x10)
    }

    private var availableKinds: [RaceKind] {
        RaceAnalytics.availableKinds(results)
    }

    private var activeKind: RaceKind? {
        selectedKind ?? availableKinds.first
    }

    private var visibleResults: [RaceResult] {
        guard let activeKind else { return results }
        return results.filter { $0.kind == activeKind }
    }

    private func syncKind() {
        guard let selectedKind, availableKinds.contains(selectedKind) else {
            self.selectedKind = availableKinds.first
            return
        }
    }

    private func load() {
        guard state != .loading else { return }
        state = .loading
        Task {
            do {
                results = try await api.results(forContactIDs: athlete.contactIDs)
                state = .loaded
            } catch {
                guard !isTaskCancellation(error) else { return }
                state = .failed(error.localizedDescription)
            }
        }
    }
}
