import SwiftUI

/// Every race the athlete has done, newest first.
struct LockerView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var notes: RaceNotesStore
    @EnvironmentObject private var pattie: PattieMode

    @State private var showingAthleteSearch = false
    @State private var kindFilter: RaceKind?

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
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            pattie.react(.refresh)
                            Task { await locker.refresh(force: true) }
                        } label: {
                            Label("Refresh results", systemImage: "arrow.clockwise")
                        }
                        Button {
                            pattie.react(.selection)
                            showingAthleteSearch = true
                        } label: {
                            Label("Change athlete", systemImage: "person.crop.circle.badge.questionmark")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.white)
                            .triTapTarget()
                    }
                }
            }
            .sheet(isPresented: $showingAthleteSearch) {
                AthleteSearchView()
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

    private var filteredResults: [RaceResult] {
        guard let kindFilter else { return locker.results }
        return locker.results.filter { $0.kind == kindFilter }
    }

    private var list: some View {
        List {
            Section {
                LockerHeader(athlete: locker.athlete, results: locker.results)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if locker.availableKinds.count > 1 {
                Section {
                    kindPicker
                        .listRowInsets(EdgeInsets(top: 0, leading: TriGeo.padPage, bottom: TriSpace.x2, trailing: TriGeo.padPage))
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(visibleResults) { result in
                    NavigationLink {
                        RaceDetailView(result: result)
                    } label: {
                        RaceRow(result: result,
                                personalBestLegs: personalBestLegs(for: result),
                                hasNote: notes.hasNote(for: result.id))
                    }
                    .listRowBackground(TriPalette.surface)
                }

            } header: {
                TriSectionHeader(title: "Races", trailing: footerText)
            }

            Section {
                SplitLegend()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var kindPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TriSpace.x2) {
                TriChip(title: "All", isSelected: kindFilter == nil) {
                    kindFilter = nil
                    pattie.react(.filter)
                }
                ForEach(locker.availableKinds, id: \.self) { kind in
                    TriChip(title: kind.longTitle, isSelected: kindFilter == kind) {
                        kindFilter = kind
                        pattie.react(.filter)
                    }
                }
            }
            .padding(.vertical, TriSpace.x1)
        }
    }

    /// Every race that matches the filter.
    ///
    /// This still routes through `ProGate` rather than returning
    /// `filteredResults` directly. While `everythingUnlocked` is set the gate is
    /// a pass-through, and keeping the call here means turning the switch back
    /// off restores the free window without anybody having to remember that this
    /// screen had its own copy of the rule. The rule it enforces when it is on:
    /// the window applies to the athlete's whole history, not to whatever the
    /// filter happens to show, or switching to "Half" would hand out three more
    /// races each time.
    private var visibleResults: [RaceResult] {
        let allowed = Set(ProGate.visibleResults(locker.results, isPro: store.isPro).map(\.id))
        return filteredResults.filter { allowed.contains($0.id) }
    }

    private var footerText: String? {
        guard let refreshed = locker.lastRefreshed else { return nil }
        return "Updated \(refreshed.formatted(.relative(presentation: .named)))"
    }

    private func personalBestLegs(for result: RaceResult) -> Set<Discipline> {
        Set(Discipline.rankable.filter {
            RaceAnalytics.isPersonalBest(result, discipline: $0, within: locker.results)
        })
    }
}

/// Career summary above the race list.
private struct LockerHeader: View {
    let athlete: Athlete?
    let results: [RaceResult]

    var body: some View {
        let summary = RaceAnalytics.summary(results)
        VStack(alignment: .leading, spacing: TriSpace.x3) {
            if let athlete {
                VStack(alignment: .leading, spacing: TriSpace.x1) {
                    Text(athlete.name)
                        .font(TriType.athleteName)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let location = athlete.location {
                        Text(location)
                            .font(TriType.small)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            HStack(spacing: 0) {
                StatTile(value: "\(summary.finishes)", caption: "Finishes", tint: .white)
                StatTile(value: "\(summary.fullDistance)", caption: "Full", tint: .white)
                StatTile(value: "\(summary.halfDistance)", caption: "Half", tint: .white)
                if summary.podiums > 0 {
                    StatTile(value: "\(summary.podiums)", caption: "Podiums", tint: TriPalette.sunrise)
                }
            }

            if let years = summary.years {
                Text("Racing since " + String(years.lowerBound))
                    .font(TriType.micro)
                    .kerning(0.5)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(TriGeo.padCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TriPalette.deep)
    }
}
