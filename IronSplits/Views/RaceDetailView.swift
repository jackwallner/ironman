import SwiftUI

/// One race, in full: splits, ranks, where each leg landed in the field, and
/// the athlete's own notes.
struct RaceDetailView: View {
    let result: RaceResult

    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var notes: RaceNotesStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var pattie: PattieMode

    @State private var field: [RaceResult] = []
    @State private var fieldState: FieldState = .idle
    @State private var paywallTrigger: PaywallTrigger?
    @State private var editingNote = false

    private enum FieldState: Equatable {
        case idle, loading, loaded, failed
    }

    private let api = ResultsAPI()

    var body: some View {
        ScrollView {
            VStack(spacing: TriGeo.padSection) {
                hero
                splitsCard
                fieldCard
                notesCard
            }
            .padding(.bottom, 32)
        }
        .background(TriPalette.canvas)
        .navigationTitle(String(result.year))
        .navigationBarTitleDisplayMode(.inline)
        .triNavBar()
        .sheet(item: $paywallTrigger) { PaywallView(trigger: $0) }
        .sheet(isPresented: $editingNote) {
            RaceNoteEditor(note: notes.note(for: result.id), raceName: result.raceName) { updated in
                notes.save(updated)
            }
        }
        .task {
            ReviewPromptTracker.recordPositiveMoment()
            pattie.fire(pattieMoment)
            guard store.isPro, result.isComplete else { return }
            await loadField()
        }
    }

    /// The most interesting thing about this race, in Pattie's eyes.
    private var pattieMoment: PattieMode.Moment {
        if !result.isComplete { return .didNotFinish }
        if result.raceName.localizedCaseInsensitiveContains("World Championship") {
            return .worldChampionship
        }
        let isPB = Discipline.rankable.contains {
            RaceAnalytics.isPersonalBest(result, discipline: $0, within: locker.results)
        }
        return isPB ? .personalBest : .raceOpened
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            Text(result.raceName)
                .font(TriType.pageTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(dateText)
                .font(TriType.small)
                .foregroundStyle(.white.opacity(0.7))

            Text(result.isComplete ? TimeFormat.hms(result.finish) : statusText)
                .font(TriType.statHero)
                .foregroundStyle(result.isComplete ? .white : TriPalette.sunrise)

            HStack(spacing: 8) {
                TriBadge(text: result.kind.longTitle, color: .white.opacity(0.85))
                if let group = result.ageGroup {
                    TriBadge(text: group, color: .white.opacity(0.85))
                }
                if let bib = result.bib {
                    TriBadge(text: "Bib \(bib)", color: .white.opacity(0.85))
                }
            }

            if result.isComplete {
                HStack(spacing: 0) {
                    StatTile(value: Ordinal.text(result.finishRankGroup) ?? "—", caption: "Division", tint: .white)
                    StatTile(value: Ordinal.text(result.finishRankGender) ?? "—", caption: "Gender", tint: .white)
                    StatTile(value: Ordinal.text(result.finishRankOverall) ?? "—", caption: "Overall", tint: .white)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, TriGeo.padCard)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(TriPalette.deep)
    }

    private var statusText: String {
        if result.disqualified { return "DQ" }
        if result.didNotStart { return "DNS" }
        return "DNF"
    }

    private var dateText: String {
        guard let date = result.eventDate else { return String(result.year) }
        return RaceDate.long(date)
    }

    // MARK: - Splits

    private var splitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TriSectionHeader(title: "Splits")

            if result.isComplete {
                SplitBar(result: result, height: 12)
            }

            VStack(spacing: 0) {
                ForEach([Discipline.swim, .t1, .bike, .t2, .run]) { leg in
                    SplitRow(
                        discipline: leg,
                        seconds: result.seconds(for: leg),
                        pace: PaceFormat.text(for: leg,
                                              seconds: result.seconds(for: leg),
                                              distanceKm: result.distanceKm(for: leg),
                                              units: settings.units),
                        overallRank: result.overallRank(for: leg),
                        divisionRank: result.divisionRank(for: leg),
                        isPersonalBest: store.isPro && RaceAnalytics.isPersonalBest(result, discipline: leg, within: locker.results)
                    )
                    if leg != .run { Divider().background(TriPalette.divider) }
                }
            }
        }
        .triCard()
        .padding(.horizontal, TriGeo.padPage)
    }

    // MARK: - Field

    @ViewBuilder
    private var fieldCard: some View {
        if result.isComplete {
            VStack(alignment: .leading, spacing: 12) {
                TriSectionHeader(title: "Against the field",
                                 trailing: fieldState == .loaded ? "\(field.filter(\.isComplete).count) finishers" : nil)

                if !store.isPro {
                    LockedRow(title: "See where each leg landed",
                              subtitle: "Your swim, bike and run as a percentile of everyone who finished this race.") {
                        paywallTrigger = .fieldPercentiles
                    }
                } else {
                    switch fieldState {
                    case .idle, .loading:
                        HStack(spacing: 8) {
                            ProgressView().tint(TriPalette.deep)
                            Text("Loading the field…")
                                .font(TriType.small)
                                .foregroundStyle(TriPalette.inkTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    case .failed:
                        Button("Couldn't load the field. Try again.") {
                            Task { await loadField() }
                        }
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.sunrise)
                    case .loaded:
                        VStack(spacing: 12) {
                            ForEach(Discipline.rankable) { leg in
                                if let placement = RaceAnalytics.placement(of: result, discipline: leg, inField: field) {
                                    PlacementRow(placement: placement)
                                }
                            }
                        }
                    }
                }
            }
            .triCard()
            .padding(.horizontal, TriGeo.padPage)
        }
    }

    private func loadField() async {
        guard fieldState != .loaded, !result.eventID.isEmpty else { return }
        fieldState = .loading
        do {
            field = try await api.results(forEventID: result.eventID)
            fieldState = .loaded
        } catch {
            guard !isTaskCancellation(error) else { return }
            fieldState = .failed
        }
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TriSectionHeader(title: "Race notes")

            if !store.isPro {
                LockedRow(title: "Add your own notes",
                          subtitle: "Conditions, nutrition and gear, kept with the result.") {
                    paywallTrigger = .raceNotes
                }
            } else {
                let note = notes.note(for: result.id)
                if note.isEmpty {
                    Button {
                        editingNote = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add notes for this race")
                        }
                        .font(TriType.bodyBold)
                        .foregroundStyle(TriPalette.sunrise)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        noteField("Conditions", note.conditions)
                        noteField("Nutrition", note.nutrition)
                        noteField("Gear", note.gear)
                        noteField("Notes", note.notes)
                        Button("Edit") { editingNote = true }
                            .font(TriType.smallBold)
                            .foregroundStyle(TriPalette.sunrise)
                    }
                }
            }
        }
        .triCard()
        .padding(.horizontal, TriGeo.padPage)
    }

    @ViewBuilder
    private func noteField(_ label: String, _ value: String) -> some View {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(TriType.micro)
                    .kerning(0.4)
                    .foregroundStyle(TriPalette.inkTertiary)
                Text(trimmed)
                    .font(TriType.body)
                    .foregroundStyle(TriPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SplitRow: View {
    let discipline: Discipline
    let seconds: Int?
    let pace: String?
    let overallRank: Int?
    let divisionRank: Int?
    let isPersonalBest: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: discipline.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TriPalette.color(for: discipline))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(discipline.title)
                        .font(TriType.bodyBold)
                        .foregroundStyle(TriPalette.ink)
                    if isPersonalBest {
                        TriBadge(text: "PB", color: TriPalette.sunrise, filled: true)
                    }
                }
                if let pace {
                    Text(pace)
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(TimeFormat.hms(seconds))
                    .font(TriType.statMed)
                    .foregroundStyle(TriPalette.ink)
                if let divisionRank {
                    Text("\(Ordinal.text(divisionRank) ?? "") in division")
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                } else if let overallRank {
                    Text("\(Ordinal.text(overallRank) ?? "") overall")
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

private struct PlacementRow: View {
    let placement: FieldPlacement

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(placement.discipline.title)
                    .font(TriType.smallBold)
                    .foregroundStyle(TriPalette.ink)
                Spacer()
                Text("\(placement.rank) of \(placement.fieldSize)")
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                Text(String(placement.percentile))
                    .font(TriType.statSmall)
                    .foregroundStyle(TriPalette.textColor(forPercentile: placement.percentile))
                    .frame(width: 28, alignment: .trailing)
            }
            PercentileBar(percentile: placement.percentile)
        }
    }
}

/// Sheet for editing one race's notes.
struct RaceNoteEditor: View {
    @State var note: RaceNote
    let raceName: String
    let onSave: (RaceNote) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Conditions") {
                    TextField("Water 68°F, 15mph crosswind on the out leg", text: $note.conditions, axis: .vertical)
                }
                Section("Nutrition") {
                    TextField("What you took, and when", text: $note.nutrition, axis: .vertical)
                }
                Section("Gear") {
                    TextField("Wetsuit, wheels, shoes", text: $note.gear, axis: .vertical)
                }
                Section("Notes") {
                    TextField("How it went", text: $note.notes, axis: .vertical)
                        .lineLimit(4...10)
                }
            }
            .navigationTitle(raceName)
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(note)
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
