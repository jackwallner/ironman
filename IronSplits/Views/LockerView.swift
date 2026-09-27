import SwiftUI

/// Every race the athlete has done, newest first.
struct LockerView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var notes: RaceNotesStore
    @EnvironmentObject private var pattie: PattieMode
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingAthleteSearch = false
    @State private var showingAddRegistration = false
    @State private var kindFilter: RaceKind?
    @State private var showingRankings = false
    @State private var rankingDiscipline: Discipline = .finish
    @State private var raceSearch = ""

    var body: some View {
        NavigationStack {
            ZStack {
                TriPalette.canvas.ignoresSafeArea()
                body(for: locker.state)
            }
            .navigationTitle("Locker")
            .pattieMoment(.welcome, pattie)
            // Inline, because the header card immediately below is already the
            // athlete's name in the same navy. A large title left an empty
            // navy band the height of a title above a card that repeated it.
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        pattie.react(.selection)
                        showingAthleteSearch = true
                    } label: {
                        Text("Change")
                            .font(TriType.smallBold)
                            .foregroundStyle(changeActionForeground)
                            .padding(.horizontal, TriSpace.x3)
                            .frame(minWidth: TriGeo.tapTarget, minHeight: TriGeo.tapTarget)
                    }
                    .buttonStyle(.triPressSilent)
                    .accessibilityLabel("Change athlete")

                    Menu {
                        Button {
                            showingAddRegistration = true
                        } label: {
                            Label("Add another registration", systemImage: "person.crop.circle.badge.plus")
                        }
                        Button {
                            pattie.react(.refresh)
                            Task { await locker.refresh(force: true) }
                        } label: {
                            Label("Refresh results", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(TriPalette.inkOnDark)
                            .frame(width: TriGeo.tapTarget, height: TriGeo.tapTarget)
                            .triToolbarCircleBackground()
                    }
                    .accessibilityLabel("More locker actions")
                }
            }
            .onAppear { syncKindFilter() }
            .onChange(of: locker.athlete?.id) { _, _ in syncKindFilter() }
            .onChange(of: locker.availableKinds) { _, kinds in
                if let kindFilter, !kinds.contains(kindFilter) {
                    self.kindFilter = showingRankings ? kinds.first : nil
                }
            }
            .sheet(isPresented: $showingAthleteSearch) {
                AthleteSearchView()
            }
            .sheet(isPresented: $showingAddRegistration) {
                AthleteSearchView(addingToCurrentAthlete: true)
            }
            .refreshable {
                await locker.refresh(force: true)
                pattie.fire(.refreshed)
            }
        }
    }

    @ViewBuilder
    private func body(for state: LockerStore.LoadState) -> some View {
        switch state {
        case .loading where locker.results.isEmpty:
            VStack(spacing: TriSpace.x3) {
                ProgressView().tint(TriPalette.deep)
                Text("Pulling your results…")
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
            }
        case .failed(let message) where locker.results.isEmpty:
            TriPlaceholder(systemImage: "wifi.exclamationmark",
                           title: "Couldn't load your races",
                           message: message,
                           actionTitle: "Try again") {
                pattie.react(.refresh)
                Task { await locker.refresh(force: true) }
            }
        default:
            if locker.results.isEmpty {
                TriPlaceholder(systemImage: "flag.checkered",
                               title: "No results yet",
                               message: "We couldn't find any published results under this athlete. If you registered under a different name, pick the right one.",
                               actionTitle: "Change athlete") {
                    pattie.react(.selection)
                    showingAthleteSearch = true
                }
            } else {
                list
            }
        }
    }

    private var list: some View {
        List {
            Section {
                raceSearchField
                    .listRowInsets(EdgeInsets(top: TriSpace.x2, leading: TriGeo.padPage,
                                              bottom: TriSpace.x2, trailing: TriGeo.padPage))
                    .listRowBackground(TriPalette.canvas)
                    .listRowSeparator(.hidden)

                LockerHeader(athlete: locker.athlete,
                             results: locker.results,
                             lastRefreshed: locker.lastRefreshed)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(TriPalette.canvas)
                    .listRowSeparator(.hidden)
            }

            if let warning = locker.refreshWarning {
                Section {
                    Label(warning, systemImage: "info.circle")
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: TriGeo.tapTarget, alignment: .leading)
                        .listRowBackground(TriPalette.surface)
                }
            }

            if locker.availableKinds.count > 1 {
                Section {
                    kindPicker
                        .listRowInsets(EdgeInsets(top: 0, leading: TriGeo.padPage, bottom: TriSpace.x2, trailing: TriGeo.padPage))
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                HStack(spacing: TriSpace.x2) {
                    TriChip(title: "Races", isSelected: !showingRankings) {
                        showingRankings = false
                    }
                    TriChip(title: "Rankings", isSelected: showingRankings) {
                        if kindFilter == nil {
                            kindFilter = settings.preferredKind.flatMap { locker.availableKinds.contains($0) ? $0 : nil }
                                ?? locker.availableKinds.first
                        }
                        showingRankings = true
                    }
                }
                .listRowInsets(EdgeInsets(top: TriSpace.x1, leading: TriGeo.padPage,
                                          bottom: TriSpace.x1, trailing: TriGeo.padPage))
                .listRowBackground(Color.clear)
            }

            if showingRankings {
                Section {
                    rankingPicker
                        .listRowInsets(EdgeInsets(top: 0, leading: TriGeo.padPage,
                                                  bottom: TriSpace.x2, trailing: TriGeo.padPage))
                        .listRowBackground(Color.clear)
                    if standings.isEmpty {
                        Text("Finish a race at this distance to see your split rankings.")
                            .font(TriType.small)
                            .foregroundStyle(TriPalette.inkTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minHeight: TriGeo.tapTarget, alignment: .leading)
                            .listRowBackground(TriPalette.surface)
                    } else {
                        ForEach(standings) { standing in
                            NavigationLink {
                                RaceDetailView(result: standing.result)
                            } label: {
                                SplitStandingRow(standing: standing)
                            }
                            .listRowBackground(TriPalette.surface)
                        }
                    }
                } header: {
                    TriSectionHeader(title: "\(rankingDiscipline.title) rankings",
                                     trailing: rankingKind?.longTitle)
                }
            } else {
                ForEach(resultGroups, id: \.year) { group in
                    Section(group.year > 0 ? String(group.year) : "Undated") {
                        ForEach(group.results) { result in
                            NavigationLink {
                                RaceDetailView(result: result)
                            } label: {
                                RaceRow(result: result,
                                        personalBestLegs: personalBestMap[result.id, default: []],
                                        hasNote: notes.hasNote(for: result.id))
                            }
                            .listRowBackground(TriPalette.surface)
                        }
                    }
                }
                Section {
                    Button {
                        showingAddRegistration = true
                    } label: {
                        LockerAddRegistrationCard()
                    }
                    .buttonStyle(.triPress)
                    .listRowBackground(TriPalette.surface)
                }
                Section {
                    SplitLegend()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var raceSearchField: some View {
        HStack(spacing: TriSpace.x2) {
            Image(systemName: "magnifyingglass")
                .font(TriType.body)
                .foregroundStyle(TriPalette.inkSecondary)

            TextField("Search races", text: $raceSearch,
                      prompt: Text("Search races").foregroundColor(TriPalette.inkSecondary))
                .font(TriType.field)
                .foregroundStyle(TriPalette.ink)
                .tint(TriPalette.sunrise)
                .lineLimit(1)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !raceSearch.isEmpty {
                Button {
                    raceSearch = ""
                    Haptics.tap()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TriPalette.inkTertiary)
                        .frame(minWidth: TriGeo.tapTarget, minHeight: TriGeo.tapTarget)
                }
                .buttonStyle(.triPressSilent)
                .accessibilityLabel("Clear race search")
            }
        }
        .padding(.horizontal, TriSpace.x3)
        .frame(maxWidth: .infinity, minHeight: TriGeo.tapTarget, alignment: .leading)
        .background(TriPalette.surfaceAlt, in: Capsule())
    }

    private var changeActionForeground: Color {
        // iOS 26 groups toolbar actions on a light glass capsule in light mode.
        if #available(iOS 26.0, *), colorScheme == .light { return TriPalette.deep }
        return TriPalette.inkOnDark
    }

    private var kindPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TriSpace.x2) {
                if !showingRankings {
                    TriChip(title: "All", isSelected: kindFilter == nil) {
                        kindFilter = nil
                        settings.preferredKind = nil
                        pattie.react(.filter)
                    }
                }
                ForEach(locker.availableKinds, id: \.self) { kind in
                    TriChip(title: kind.longTitle, isSelected: kindFilter == kind) {
                        kindFilter = kind
                        settings.preferredKind = kind
                        pattie.react(.filter)
                    }
                }
            }
            .padding(.vertical, TriSpace.x1)
        }
    }

    private var rankingPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TriSpace.x2) {
                ForEach(Discipline.rankable) { discipline in
                    TriChip(title: discipline.shortTitle,
                            isSelected: rankingDiscipline == discipline) {
                        rankingDiscipline = discipline
                        pattie.react(.filter)
                    }
                }
            }
            .padding(.vertical, TriSpace.x1)
        }
    }

    private var rankingKind: RaceKind? {
        kindFilter ?? settings.preferredKind.flatMap { locker.availableKinds.contains($0) ? $0 : nil }
            ?? locker.availableKinds.first
    }

    private var standings: [SplitStanding] {
        RaceAnalytics.standings(locker.results, discipline: rankingDiscipline, kind: rankingKind)
            .filter {
                raceSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || $0.result.raceName.localizedCaseInsensitiveContains(raceSearch)
            }
    }

    private var visibleResults: [RaceResult] {
        locker.results
            .filter { kindFilter == nil || $0.kind == kindFilter }
            .filter {
                raceSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || $0.raceName.localizedCaseInsensitiveContains(raceSearch)
            }
    }

    private var resultGroups: [(year: Int, results: [RaceResult])] {
        let groups = Dictionary(grouping: visibleResults, by: \.year)
        return groups.keys.sorted(by: >).map { year in
            (year: year, results: groups[year] ?? [])
        }
    }

    private var personalBestMap: [String: Set<Discipline>] {
        var result: [String: Set<Discipline>] = [:]
        for kind in locker.availableKinds {
            for discipline in Discipline.rankable {
                let ranked = RaceAnalytics.standings(locker.results, discipline: discipline, kind: kind)
                guard ranked.count > 1, let best = ranked.first?.seconds else { continue }
                for standing in ranked where standing.seconds == best {
                    result[standing.result.id, default: []].insert(discipline)
                }
            }
        }
        return result
    }

    private func syncKindFilter() {
        if let preferred = settings.preferredKind, locker.availableKinds.contains(preferred) {
            kindFilter = preferred
        } else {
            kindFilter = nil
        }
    }

}

/// Career summary above the race list.
private struct LockerHeader: View {
    let athlete: Athlete?
    let results: [RaceResult]
    let lastRefreshed: Date?

    var body: some View {
        let summary = RaceAnalytics.summary(results)
        VStack(alignment: .leading, spacing: TriSpace.x3) {
            if let athlete {
                VStack(alignment: .leading, spacing: TriSpace.x1) {
                    Text(athlete.name)
                        .font(TriType.athleteName)
                        .foregroundStyle(TriPalette.inkOnDark)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    if let location = athlete.location {
                        Text(location)
                            .font(TriType.small)
                            .foregroundStyle(TriPalette.inkOnDark.opacity(0.7))
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TriSpace.x6) {
                    StatTile(value: "\(summary.finishes)", caption: "Finishes", tint: TriPalette.inkOnDark)
                    if summary.fullDistance > 0 {
                        StatTile(value: "\(summary.fullDistance)", caption: "Full", tint: TriPalette.inkOnDark)
                    }
                    if summary.halfDistance > 0 {
                        StatTile(value: "\(summary.halfDistance)", caption: "Half", tint: TriPalette.inkOnDark)
                    }
                    if summary.podiums > 0 {
                        StatTile(value: "\(summary.podiums)", caption: "Podiums", tint: TriPalette.sunrise)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, TriSpace.x1)
            }

            if let years = summary.years {
                Text("Racing since " + String(years.lowerBound))
                    .font(TriType.micro)
                    .kerning(0.5)
                    .foregroundStyle(TriPalette.inkOnDark.opacity(0.6))
            }
            if let lastRefreshed {
                Text("Updated \(lastRefreshed.formatted(.relative(presentation: .named)))")
                    .font(TriType.micro)
                    .foregroundStyle(TriPalette.inkOnDark.opacity(0.6))
            }
        }
        .padding(TriGeo.padCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TriPalette.deep)
    }
}

private struct LockerAddRegistrationCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: TriSpace.x3) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(TriType.pageTitle)
                .foregroundStyle(TriPalette.sunrise)
                .frame(width: TriSpace.x8, height: TriSpace.x8)
                .background(TriPalette.sunrise.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: TriSpace.x1) {
                Text("Missing a race?")
                    .font(TriType.cardTitle)
                    .foregroundStyle(TriPalette.ink)
                Text("Add another registration name to your career.")
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
        }
        .padding(.vertical, TriSpace.x2)
        .frame(minHeight: TriGeo.tapTarget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Missing a race? Add another registration name to your career")
    }
}

private struct SplitStandingRow: View {
    let standing: SplitStanding

    var body: some View {
        HStack(spacing: TriSpace.x3) {
            Text(String(standing.rank))
                .font(TriType.statMed)
                .foregroundStyle(standing.isPersonalBest ? TriPalette.sunrise : TriPalette.inkSecondary)
                .frame(minWidth: TriSpace.x8, alignment: .leading)

            VStack(alignment: .leading, spacing: TriSpace.x1) {
                Text(standing.result.raceName)
                    .font(TriType.cardTitle)
                    .foregroundStyle(TriPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(standing.result.year) + " · " + standing.result.kind.title)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
            }
            .layoutPriority(1)

            Spacer(minLength: TriSpace.x2)

            VStack(alignment: .trailing, spacing: TriSpace.x1) {
                Text(TimeFormat.hms(standing.seconds))
                    .font(TriType.statMed)
                    .foregroundStyle(TriPalette.ink)
                Text(standing.gapToBest == 0 ? "Personal best" : "+\(TimeFormat.hms(standing.gapToBest))")
                    .font(TriType.small)
                    .foregroundStyle(standing.gapToBest == 0 ? TriPalette.sunrise : TriPalette.inkTertiary)
            }
        }
        .frame(minHeight: TriGeo.tapTarget)
        .padding(.vertical, TriSpace.x2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(standing.rank), \(standing.result.raceName), \(standing.result.year), \(standing.discipline.title) \(TimeFormat.hms(standing.seconds)), \(standing.gapToBest == 0 ? "personal best" : "\(TimeFormat.hms(standing.gapToBest)) behind best")")
    }
}
