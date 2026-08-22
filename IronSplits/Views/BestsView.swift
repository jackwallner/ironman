import SwiftUI

/// The split leaderboards: your races ranked by each leg.
///
/// This is the thing the app exists for. The official results site can tell you
/// what you did in one race; nothing tells you which of your fourteen 70.3s
/// held your fastest bike, or how far off it you are now.
struct BestsView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var pattie: PattieMode

    @State private var discipline: Discipline = .finish
    @State private var kind: RaceKind?

    var body: some View {
        NavigationStack {
            ZStack {
                TriPalette.canvas.ignoresSafeArea()
                content
            }
            .navigationTitle("Bests")
            .pattieMoment(.bests, pattie)
            // Inline: a large title renders as an empty band here, and the
            // screen's own header is already doing that job.
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .onAppear { syncKind() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if locker.results.isEmpty {
            TriPlaceholder(systemImage: "list.number",
                           title: "No races yet",
                           message: "Your split leaderboards appear once your locker has results in it.")
        } else if standings.isEmpty {
            TriPlaceholder(systemImage: "list.number",
                           title: "Nothing to rank yet",
                           message: "You need at least one finish at this distance for a \(discipline.title.lowercased()) leaderboard.")
        } else {
            board
        }
    }

    private var board: some View {
        List {
            Section {
                pickers
                    .listRowInsets(EdgeInsets(top: TriSpace.x2, leading: TriGeo.padPage, bottom: TriSpace.x2, trailing: TriGeo.padPage))
                    .listRowBackground(Color.clear)
            }

            if let best = standings.first {
                Section {
                    BestCard(standing: best, units: settings.units)
                        .listRowInsets(EdgeInsets(top: 0, leading: TriGeo.padPage, bottom: TriSpace.x2, trailing: TriGeo.padPage))
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(standings) { standing in
                    NavigationLink {
                        RaceDetailView(result: standing.result)
                    } label: {
                        StandingRow(standing: standing, units: settings.units)
                    }
                    .listRowBackground(TriPalette.surface)
                }
            } header: {
                TriSectionHeader(title: "\(discipline.title) times", trailing: "\(standings.count) races")
            } footer: {
                Text("Ranked within \(kindLabel). Distances differ enough between them that one combined list would only ever show the shortest races.")
                    .font(TriType.micro)
                    .foregroundStyle(TriPalette.inkTertiary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .triTabBarClearance()
    }

    private var pickers: some View {
        VStack(spacing: TriSpace.x3) {
            Picker("Leg", selection: $discipline) {
                ForEach(Discipline.rankable) { leg in
                    Text(leg.shortTitle).tag(leg)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: discipline) { _, _ in
                Haptics.selection()
                pattie.fire(.bestsFiltered)
            }

            if locker.availableKinds.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TriSpace.x2) {
                        ForEach(locker.availableKinds, id: \.self) { available in
                            TriChip(title: available.longTitle, isSelected: kind == available) {
                                kind = available
                                settings.preferredKind = available
                                pattie.react(.filter)
                            }
                        }
                    }
                    .padding(.vertical, TriSpace.x1)
                }
            }
        }
    }

    private var standings: [SplitStanding] {
        RaceAnalytics.standings(locker.results, discipline: discipline, kind: kind)
    }

    private var kindLabel: String {
        (kind ?? .unknown).longTitle.lowercased() + " races"
    }

    /// Pick a sensible distance the first time, and never leave the picker on
    /// one the athlete has never raced.
    private func syncKind() {
        let available = locker.availableKinds
        guard !available.isEmpty else { return }
        if let kind, available.contains(kind) { return }
        if let preferred = settings.preferredKind, available.contains(preferred) {
            kind = preferred
        } else {
            kind = available.first
        }
    }
}

/// The personal best, called out above the list.
private struct BestCard: View {
    let standing: SplitStanding
    let units: UnitPreference

    var body: some View {
        VStack(alignment: .leading, spacing: TriSpace.x2) {
            HStack {
                TriBadge(text: "Personal best", color: TriPalette.sunrise, filled: true)
                Spacer()
                Text(String(standing.result.year))
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
            }
            Text(TimeFormat.hms(standing.seconds))
                .font(TriType.statHero)
                .foregroundStyle(TriPalette.ink)
            Text(standing.result.raceName)
                .font(TriType.bodyBold)
                .foregroundStyle(TriPalette.inkSecondary)
            if let pace = PaceFormat.text(for: standing.discipline,
                                          seconds: standing.seconds,
                                          distanceKm: standing.result.distanceKm(for: standing.discipline),
                                          units: units) {
                Text(pace)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .triCard()
    }
}

private struct StandingRow: View {
    let standing: SplitStanding
    let units: UnitPreference

    var body: some View {
        HStack(spacing: TriSpace.x3) {
            Text(String(standing.rank))
                .font(TriType.statSmall)
                .foregroundStyle(standing.isPersonalBest ? TriPalette.sunrise : TriPalette.inkTertiary)
                .frame(width: 22, alignment: .trailing)

            VStack(alignment: .leading, spacing: TriSpace.x1) {
                Text(standing.result.raceName)
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.ink)
                    .lineLimit(2)
                HStack(spacing: TriSpace.x2) {
                    Text(String(standing.result.year))
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                    if let pace = PaceFormat.text(for: standing.discipline,
                                                  seconds: standing.seconds,
                                                  distanceKm: standing.result.distanceKm(for: standing.discipline),
                                                  units: units) {
                        Text(pace)
                            .font(TriType.small)
                            .foregroundStyle(TriPalette.inkTertiary)
                    }
                }
            }

            Spacer(minLength: TriSpace.x2)

            VStack(alignment: .trailing, spacing: TriSpace.x1) {
                Text(TimeFormat.hms(standing.seconds))
                    .font(TriType.statMed)
                    .foregroundStyle(TriPalette.ink)
                if standing.gapToBest > 0 {
                    Text(TimeFormat.delta(standing.gapToBest))
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                }
            }
        }
        .frame(minHeight: TriGeo.tapTarget)
        .padding(.vertical, TriSpace.x1)
    }
}
