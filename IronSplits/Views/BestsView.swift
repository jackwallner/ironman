import SwiftUI

/// The split leaderboards: your races ranked by each leg.
///
/// This is the thing the app exists for. The official results site can tell you
/// what you did in one race; nothing tells you which of your fourteen 70.3s
/// held your fastest bike, or how far off it you are now.
struct BestsView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var settings: AppSettings

    @State private var discipline: Discipline = .finish
    @State private var kind: RaceKind?
    @State private var paywallTrigger: PaywallTrigger?

    var body: some View {
        NavigationStack {
            ZStack {
                TriPalette.canvas.ignoresSafeArea()
                content
            }
            .navigationTitle("Bests")
            // Inline: a large title renders as an empty band here, and the
            // screen's own header is already doing that job.
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .sheet(item: $paywallTrigger) { PaywallView(trigger: $0) }
            .onAppear { syncKind() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if locker.results.isEmpty {
            TriPlaceholder(systemImage: "list.number",
                           title: "No races yet",
                           message: "Your split leaderboards appear once your locker has results in it.")
        } else if !store.isPro {
            lockedState
        } else if standings.isEmpty {
            TriPlaceholder(systemImage: "list.number",
                           title: "Nothing to rank yet",
                           message: "You need at least one finish at this distance for a \(discipline.title.lowercased()) leaderboard.")
        } else {
            board
        }
    }

    private var lockedState: some View {
        ScrollView {
            VStack(spacing: 16) {
                pickers
                    .disabled(true)
                    .opacity(0.5)
                TriPlaceholder(systemImage: "lock.fill",
                               title: "Split leaderboards",
                               message: "Rank every race you have finished by swim, bike, run or transitions. See the personal best on each leg and how far off it today's race was.",
                               actionTitle: "Unlock Iron Splits+") {
                    paywallTrigger = .splitLeaderboards
                }
            }
            .padding(.vertical, TriGeo.padPage)
        }
    }

    private var board: some View {
        List {
            Section {
                pickers
                    .listRowInsets(EdgeInsets(top: 8, leading: TriGeo.padPage, bottom: 8, trailing: TriGeo.padPage))
                    .listRowBackground(Color.clear)
            }

            if let best = standings.first {
                Section {
                    BestCard(standing: best, units: settings.units)
                        .listRowInsets(EdgeInsets(top: 0, leading: TriGeo.padPage, bottom: 8, trailing: TriGeo.padPage))
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
    }

    private var pickers: some View {
        VStack(spacing: 10) {
            Picker("Leg", selection: $discipline) {
                ForEach(Discipline.rankable) { leg in
                    Text(leg.shortTitle).tag(leg)
                }
            }
            .pickerStyle(.segmented)

            if locker.availableKinds.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(locker.availableKinds, id: \.self) { available in
                            Button {
                                kind = available
                                settings.preferredKind = available
                            } label: {
                                Text(available.longTitle)
                                    .font(TriType.smallBold)
                                    .foregroundStyle(kind == available ? .white : TriPalette.inkSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(kind == available ? TriPalette.deep : TriPalette.surface, in: Capsule())
                                    .overlay(Capsule().stroke(TriPalette.hairline, lineWidth: kind == available ? 0 : TriGeo.hairline))
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
        VStack(alignment: .leading, spacing: 8) {
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
        HStack(spacing: 12) {
            Text(String(standing.rank))
                .font(TriType.statSmall)
                .foregroundStyle(standing.isPersonalBest ? TriPalette.sunrise : TriPalette.inkTertiary)
                .frame(width: 22, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(standing.result.raceName)
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.ink)
                    .lineLimit(2)
                HStack(spacing: 6) {
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

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
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
        .padding(.vertical, 4)
    }
}
