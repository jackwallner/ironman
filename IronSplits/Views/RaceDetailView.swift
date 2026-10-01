import SwiftUI

/// One race, in full: splits, ranks, where each leg landed in the field, and
/// the athlete's own notes.
struct RaceDetailView: View {
    let result: RaceResult
    var contextResults: [RaceResult]? = nil
    var isReadOnly = false

    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var notes: RaceNotesStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var pattie: PattieMode

    @State private var field: [RaceResult] = []
    @State private var fieldState: FieldState = .idle
    @State private var fieldScope: FieldScope = .overall
    @State private var editingNote = false

    private enum FieldState: Equatable {
        case idle, loading, loaded, failed, unavailable
    }

    private enum FieldScope: String, CaseIterable {
        case division, gender, overall

        var title: String {
            switch self {
            case .division: "Division"
            case .gender: "Gender"
            case .overall: "Overall"
            }
        }
    }

    private let api = ResultsAPI()

    var body: some View {
        ScrollView {
            VStack(spacing: TriGeo.padSection) {
                hero
                splitsCard
                fieldCard
                if !isReadOnly { notesCard }
            }
        }
        .background(TriPalette.canvas)
        .navigationTitle(result.raceName)
        .navigationBarTitleDisplayMode(.inline)
        .triNavBar(pushed: true)
        .sheet(isPresented: $editingNote) {
            RaceNoteEditor(note: notes.note(for: result.id), raceName: result.raceName) { updated in
                notes.save(updated)
                Haptics.success()
                pattie.fire(.noteSaved)
            }
        }
        .task {
            if ReviewPromptTracker.isPositiveMoment(result: result,
                                                    isReadOnly: isReadOnly,
                                                    within: careerResults) {
                ReviewPromptTracker.recordPositiveMoment(identifier: result.id)
            }
            if !isReadOnly { pattie.fire(pattieMoment) }
            guard result.isComplete else { return }
            await loadField()
        }
        .onDisappear { pattie.react(.back) }
    }

    /// The most interesting thing about this race, in Pattie's eyes.
    private var pattieMoment: PattieMode.Moment {
        if !result.isComplete { return .didNotFinish }
        if result.raceName.localizedCaseInsensitiveContains("World Championship") {
            return .worldChampionship
        }
        let isPB = Discipline.rankable.contains {
            RaceAnalytics.isPersonalBest(result, discipline: $0, within: careerResults)
        }
        return isPB ? .personalBest : .raceOpened
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: TriSpace.x3) {
            Text(result.raceName)
                .font(TriType.pageTitle)
                .foregroundStyle(TriPalette.inkOnDark)
                .multilineTextAlignment(.center)
            Text(dateText)
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkOnDark.opacity(0.7))

            Text(result.isComplete ? TimeFormat.hms(result.finish) : statusText)
                .font(TriType.statHero)
                .foregroundStyle(result.isComplete ? TriPalette.inkOnDark : TriPalette.sunrise)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TriSpace.x2) {
                    TriBadge(text: result.kind.longTitle, color: TriPalette.inkOnDark.opacity(0.85))
                    if let group = result.ageGroup {
                        TriBadge(text: group, color: TriPalette.inkOnDark.opacity(0.85))
                    }
                    if let bib = result.bib {
                        TriBadge(text: "Bib \(bib)", color: TriPalette.inkOnDark.opacity(0.85))
                    }
                }
            }

            if result.isComplete {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) {
                        StatTile(value: Ordinal.text(result.finishRankGroup) ?? "--", caption: "Division", tint: TriPalette.inkOnDark)
                        StatTile(value: Ordinal.text(result.finishRankGender) ?? "--", caption: "Gender", tint: TriPalette.inkOnDark)
                        StatTile(value: Ordinal.text(result.finishRankOverall) ?? "--", caption: "Overall", tint: TriPalette.inkOnDark)
                    }
                    VStack(spacing: TriSpace.x2) {
                        HStack(spacing: TriSpace.x2) {
                            StatTile(value: Ordinal.text(result.finishRankGroup) ?? "--", caption: "Division", tint: TriPalette.inkOnDark)
                            StatTile(value: Ordinal.text(result.finishRankGender) ?? "--", caption: "Gender", tint: TriPalette.inkOnDark)
                        }
                        StatTile(value: Ordinal.text(result.finishRankOverall) ?? "--", caption: "Overall", tint: TriPalette.inkOnDark)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, TriSpace.x1)
            }
        }
        .padding(.horizontal, TriGeo.padCard)
        .padding(.vertical, TriSpace.x5)
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
        VStack(alignment: .leading, spacing: TriSpace.x3) {
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
                        isPersonalBest: Discipline.rankable.contains(leg)
                            && RaceAnalytics.isPersonalBest(result, discipline: leg, within: careerResults)
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
            VStack(alignment: .leading, spacing: TriSpace.x3) {
                TriSectionHeader(title: "Against the field",
                                 trailing: fieldState == .loaded ? "\(scopedField.filter(\.isComplete).count) finishers" : nil)

                switch fieldState {
                case .idle, .loading:
                    HStack(spacing: TriSpace.x2) {
                        ProgressView().tint(TriPalette.inkSecondary)
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
                    .frame(minHeight: TriGeo.tapTarget, alignment: .leading)
                case .unavailable:
                    Text("Field results aren't available for this race. Your published splits are still shown above.")
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .loaded:
                    VStack(alignment: .leading, spacing: TriSpace.x3) {
                        if availableFieldScopes.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: TriSpace.x2) {
                                    ForEach(availableFieldScopes, id: \.self) { scope in
                                        TriChip(title: scope.title, isSelected: fieldScope == scope) {
                                            fieldScope = scope
                                        }
                                    }
                                }
                            }
                        }
                        if fieldPlacements.isEmpty {
                            Text(emptyFieldMessage)
                                .font(TriType.small)
                                .foregroundStyle(TriPalette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(minHeight: TriGeo.tapTarget, alignment: .leading)
                        } else {
                            VStack(spacing: TriSpace.x3) {
                                ForEach(fieldPlacements, id: \.discipline) { placement in
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
        guard fieldState != .loaded, fieldState != .unavailable else { return }
        guard !result.eventID.isEmpty else {
            fieldState = .unavailable
            return
        }
        if let cached = RaceFieldCache.results(for: result.eventID) {
            field = cached
            fieldState = .loaded
            return
        }
        fieldState = .loading
        do {
            let loaded = try await api.results(forEventID: result.eventID)
            guard !Task.isCancelled else { return }
            field = loaded
            RaceFieldCache.store(loaded, for: result.eventID)
            fieldState = .loaded
        } catch {
            guard !isTaskCancellation(error), !Task.isCancelled else { return }
            fieldState = .failed
        }
    }

    private var availableFieldScopes: [FieldScope] {
        guard let ageGroup = result.ageGroup else { return [.overall] }
        let prefix = ageGroup.uppercased().first
        if prefix == "M" || prefix == "F" { return [.division, .gender, .overall] }
        return [.division, .overall]
    }

    private var scopedField: [RaceResult] {
        switch fieldScope {
        case .division:
            guard let ageGroup = result.ageGroup else { return field }
            return field.filter { $0.ageGroup?.caseInsensitiveCompare(ageGroup) == .orderedSame }
        case .gender:
            guard let prefix = result.ageGroup?.uppercased().first, prefix == "M" || prefix == "F" else { return field }
            return field.filter { $0.ageGroup?.uppercased().hasPrefix(String(prefix)) == true }
        case .overall:
            return field
        }
    }

    private var fieldPlacements: [FieldPlacement] {
        Discipline.rankable.compactMap { RaceAnalytics.placement(of: result, discipline: $0, inField: scopedField) }
    }

    private var emptyFieldMessage: String {
        fieldScope == .overall
            ? "There isn't enough comparable field data for these splits."
            : "No comparable finishers were found in this \(fieldScope.title.lowercased()). Try Overall."
    }

    private var careerResults: [RaceResult] { contextResults ?? locker.results }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: TriSpace.x3) {
            TriSectionHeader(title: "Race notes")

            let note = notes.note(for: result.id)
            if note.isEmpty {
                Button {
                    editingNote = true
                } label: {
                    HStack(spacing: TriSpace.x2) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add notes for this race")
                    }
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.sunrise)
                    .frame(minHeight: TriGeo.tapTarget, alignment: .leading)
                }
                .buttonStyle(.triPress)
            } else {
                VStack(alignment: .leading, spacing: TriSpace.x3) {
                    noteField("Conditions", note.conditions)
                    noteField("Nutrition", note.nutrition)
                    noteField("Gear", note.gear)
                    noteField("Notes", note.notes)
                    Button("Edit") { editingNote = true }
                        .font(TriType.smallBold)
                        .foregroundStyle(TriPalette.sunrise)
                        .frame(minHeight: TriGeo.tapTarget, alignment: .leading)
                        .buttonStyle(.triPress)
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
            VStack(alignment: .leading, spacing: TriSpace.x1) {
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
        HStack(spacing: TriSpace.x3) {
            Image(systemName: discipline.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TriPalette.color(for: discipline))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: TriSpace.x1) {
                HStack(spacing: TriSpace.x2) {
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
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: TriSpace.x2)

            VStack(alignment: .trailing, spacing: TriSpace.x1) {
                Text(TimeFormat.hms(seconds))
                    .font(TriType.statMed)
                    .foregroundStyle(TriPalette.ink)
                    .fixedSize(horizontal: true, vertical: false)
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
        .padding(.vertical, TriSpace.x3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [discipline.title, TimeFormat.spoken(seconds)]
        if let divisionRank { parts.append("\(Ordinal.text(divisionRank) ?? String(divisionRank)) in division") }
        else if let overallRank { parts.append("\(Ordinal.text(overallRank) ?? String(overallRank)) overall") }
        if isPersonalBest { parts.append("Personal best") }
        return parts.joined(separator: ", ")
    }
}

private struct PlacementRow: View {
    let placement: FieldPlacement

    var body: some View {
        VStack(alignment: .leading, spacing: TriSpace.x1) {
            HStack {
                Text(placement.discipline.title)
                    .font(TriType.smallBold)
                    .foregroundStyle(TriPalette.ink)
                Spacer()
                Text("\(placement.rank) of \(placement.fieldSize)")
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .fixedSize(horizontal: true, vertical: false)
                Text("\(placement.percentile)%")
                    .font(TriType.statSmall)
                    .foregroundStyle(TriPalette.textColor(forPercentile: placement.percentile))
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: TriSpace.x8, alignment: .trailing)
            }
            PercentileBar(percentile: placement.percentile)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(placement.discipline.title), \(placement.percentile) percent, \(placement.rank) of \(placement.fieldSize) finishers")
    }
}

/// Sheet for editing one race's notes.
struct RaceNoteEditor: View {
    @State var note: RaceNote
    let raceName: String
    let onSave: (RaceNote) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingDiscardConfirmation = false
    @State private var showingDeleteConfirmation = false
    private let initialNote: RaceNote

    private var isDirty: Bool { note != initialNote }

    init(note: RaceNote, raceName: String, onSave: @escaping (RaceNote) -> Void) {
        self.initialNote = note
        self.raceName = raceName
        self.onSave = onSave
        _note = State(initialValue: note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Conditions") {
                    TextField("Heat, wind, water and course conditions", text: $note.conditions, axis: .vertical)
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
                if !initialNote.isEmpty {
                    Section {
                        Button("Delete this race note", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(raceName)
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .interactiveDismissDisabled(isDirty)
            .toolbar {
                TriBarItem(placement: .cancellationAction) {
                    Button { requestDismiss() } label: { TriBarLabel(title: "Cancel") }
                        .buttonStyle(.triPressSilent)
                }
                TriBarItem(placement: .confirmationAction) {
                    Button {
                        onSave(note)
                        dismiss()
                    } label: {
                        TriBarLabel(title: "Save", emphasized: true)
                    }
                    .buttonStyle(.triPressSilent)
                }
            }
            .confirmationDialog("Discard unsaved note changes?",
                                isPresented: $showingDiscardConfirmation,
                                titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .confirmationDialog("Delete this race note?",
                                isPresented: $showingDeleteConfirmation,
                                titleVisibility: .visible) {
                Button("Delete note", role: .destructive) {
                    onSave(RaceNote(resultID: initialNote.resultID))
                    dismiss()
                }
                Button("Keep note", role: .cancel) {}
            }
        }
    }

    private func requestDismiss() {
        guard isDirty else {
            dismiss()
            return
        }
        showingDiscardConfirmation = true
    }
}

@MainActor
enum RaceFieldCache {
    private static var entries: [String: [RaceResult]] = [:]
    private static var order: [String] = []

    static func results(for eventID: String) -> [RaceResult]? {
        entries[eventID]
    }

    static func store(_ results: [RaceResult], for eventID: String) {
        entries[eventID] = results
        order.removeAll { $0 == eventID }
        order.append(eventID)
        while order.count > 4 {
            entries.removeValue(forKey: order.removeFirst())
        }
    }
}
