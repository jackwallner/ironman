import SwiftUI

/// A free, useful preview of the story in an athlete's history.
///
/// The preview keeps personal bests and progression visible to everyone. The
/// lifetime Race Book unlock is requested only when comparison or export is
/// actually chosen.
struct RaceBookView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var notes: RaceNotesStore
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var pattie: PattieMode
    @Environment(\.dismiss) private var dismiss

    var showsDoneButton = false

    @State private var selectedKind: RaceKind?
    @State private var selectedDiscipline: Discipline = .finish
    @State private var exportOptions = RaceBookOptions()
    @State private var didInitializeExportOptions = false
    @State private var paywallTrigger: PaywallTrigger?
    @State private var isBuildingExports = false
    @State private var exportGeneration = 0
    @State private var exports: RaceBookExports?
    @State private var exportError: String?
    @State private var pdfPreview: RaceBookPDFItem?

    var body: some View {
        ZStack {
            TriPalette.canvas.ignoresSafeArea()
            content
        }
        .navigationTitle("Race Book")
        .navigationBarTitleDisplayMode(.inline)
        .triNavBar()
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(TriType.bodyBold)
                            .foregroundStyle(TriPalette.inkOnDark)
                            .padding(.horizontal, TriSpace.x3)
                            .frame(minWidth: TriSpace.x10 + TriSpace.x8,
                                   minHeight: TriGeo.tapTarget)
                    }
                    .buttonStyle(.triPressSilent)
                }
            }
        }
        .onAppear {
            syncKind()
            syncExportOptions()
        }
        .onChange(of: locker.availableKinds) { _, _ in
            syncKind()
            syncExportOptions()
        }
        .sheet(item: $paywallTrigger) { trigger in
            PaywallView(trigger: trigger)
        }
        .sheet(item: $pdfPreview) { item in
            RaceBookPDFPreview(url: item.url)
        }
    }

    @ViewBuilder
    private var content: some View {
        if locker.results.isEmpty {
            TriPlaceholder(systemImage: "book.closed",
                           title: "Your Race Book is waiting",
                           message: "Claim an athlete to preview personal bests, progression, comparison and export tools.")
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: TriSpace.x6) {
                    introCard
                    exportCard
                    includeCard
                    careerCard
                    kindFilter
                    personalBestsCard
                    progressionCard
                    Text("Official times are shown as published by the event timer. Race notes stay on this phone and are included only when you choose to export.")
                        .font(TriType.micro)
                        .foregroundStyle(TriPalette.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, TriSpace.x1)
                    compareCard
                }
                .padding(.horizontal, TriGeo.padPage)
                .padding(.top, TriSpace.x4)
                .padding(.bottom, TriGeo.tabBarClearance)
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: TriSpace.x2) {
            HStack(alignment: .top, spacing: TriSpace.x3) {
                Image(systemName: "book.closed.fill")
                    .font(TriType.pageTitle)
                    .foregroundStyle(TriPalette.sunrise)
                    .frame(width: TriSpace.x8, height: TriSpace.x8)
                    .background(TriPalette.sunrise.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: TriSpace.x1) {
                    Text("RACE BOOK")
                        .font(TriType.micro)
                        .kerning(1.2)
                        .foregroundStyle(TriPalette.sunrise)
                    Text("Make your history tell a story")
                        .font(TriType.pageTitle)
                        .foregroundStyle(TriPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("See the best of your career, where your time is moving, and what each race contributed. Compare and export with one lifetime unlock.")
                .font(TriType.body)
                .foregroundStyle(TriPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(raceBookUnlocked ? "Race Book unlocked" : "Preview included. No subscription.")
                .font(TriType.smallBold)
                .foregroundStyle(raceBookUnlocked ? TriPalette.positive : TriPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .triCard()
    }

    private var careerCard: some View {
        let summary = RaceAnalytics.summary(locker.results)
        return VStack(alignment: .leading, spacing: TriSpace.x3) {
            TriSectionHeader(title: "Career at a glance")
            ViewThatFits(in: .horizontal) {
                HStack {
                    StatTile(value: String(summary.finishes), caption: "Finishes")
                    Spacer(minLength: 0)
                    StatTile(value: String(summary.podiums), caption: "Podiums", tint: TriPalette.sunrise)
                    Spacer(minLength: 0)
                    StatTile(value: String(summary.starts), caption: "Starts")
                }
                VStack(spacing: TriSpace.x3) {
                    HStack {
                        StatTile(value: String(summary.finishes), caption: "Finishes")
                        Spacer(minLength: 0)
                        StatTile(value: String(summary.podiums), caption: "Podiums", tint: TriPalette.sunrise)
                    }
                    HStack {
                        StatTile(value: String(summary.starts), caption: "Starts")
                    }
                }
            }
            if let years = summary.years {
                Text(yearsText(years))
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .triCard(padding: TriSpace.x3)
    }

    private var includeCard: some View {
        VStack(alignment: .leading, spacing: TriSpace.x3) {
            TriSectionHeader(title: "Things to include")
            Text("Shape the book around the parts of your career you will want on race morning and after the finish.")
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: TriSpace.x1) {
                optionToggle("Career overview", detail: "Starts, finishes, podiums and years",
                             isOn: $exportOptions.includeCareerSummary)
                optionToggle("Podium highlights", detail: "Your top-three race moments",
                             isOn: $exportOptions.includePodiumHighlights)
                optionToggle("Personal bests", detail: "Fastest finish and leg at each distance",
                             isOn: $exportOptions.includePersonalBests)
                optionToggle("Progression", detail: "First and latest finish by distance",
                             isOn: $exportOptions.includeProgression)
                optionToggle("Race history", detail: "A complete timeline of selected races",
                             isOn: $exportOptions.includeRaceHistory)
                optionToggle("Official splits", detail: "Swim, T1, bike, T2 and run",
                             isOn: $exportOptions.includeSplits)
                optionToggle("Placements", detail: "Bib, age group and overall rank",
                             isOn: $exportOptions.includePlacements)
                optionToggle("Race-day notes", detail: "Conditions, nutrition, gear and notes",
                             isOn: $exportOptions.includeRaceNotes)
                optionToggle("Incomplete results", detail: "Include DNF, DNS and DQ entries",
                             isOn: $exportOptions.includeIncomplete)
            }

            if locker.availableKinds.count > 1 {
                TriSectionHeader(title: "Distances")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TriSpace.x2) {
                        ForEach(locker.availableKinds, id: \.self) { kind in
                            TriChip(title: kind.longTitle,
                                    isSelected: exportOptions.kinds.contains(kind)) {
                                toggleExportKind(kind)
                            }
                        }
                    }
                    .padding(.vertical, TriSpace.x1)
                }
            }
        }
        .triCard(padding: TriSpace.x3)
    }

    private func optionToggle(_ title: String,
                              detail: String,
                              isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: TriSpace.x1) {
                Text(title)
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                Text(detail)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(TriPalette.sunrise)
        .frame(minHeight: TriGeo.tapTarget, alignment: .leading)
    }

    @ViewBuilder
    private var kindFilter: some View {
        if locker.availableKinds.count > 1 {
            VStack(alignment: .leading, spacing: TriSpace.x2) {
                TriSectionHeader(title: "Compare by distance")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TriSpace.x2) {
                        ForEach(locker.availableKinds, id: \.self) { kind in
                            TriChip(title: kind.longTitle,
                                    isSelected: activeKind == kind) {
                                selectedKind = kind
                                selectedDiscipline = .finish
                                exports = nil
                                exportError = nil
                                pattie.react(.filter)
                            }
                        }
                    }
                    .padding(.vertical, TriSpace.x1)
                }
            }
        }
    }

    private var personalBestsCard: some View {
        VStack(alignment: .leading, spacing: TriSpace.x3) {
            TriSectionHeader(title: "Personal bests", trailing: activeKind?.longTitle)
            if personalBests.isEmpty {
                Text("No complete splits are available for this distance yet.")
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(personalBests) { best in
                    RaceBookBestRow(best: best)
                }
            }
        }
        .triCard(padding: TriSpace.x3)
    }

    private var progressionCard: some View {
        VStack(alignment: .leading, spacing: TriSpace.x3) {
            TriSectionHeader(title: "Progression", trailing: activeKind?.longTitle)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TriSpace.x2) {
                    ForEach(Discipline.rankable) { discipline in
                        TriChip(title: discipline.shortTitle,
                                isSelected: selectedDiscipline == discipline) {
                            selectedDiscipline = discipline
                            pattie.react(.filter)
                        }
                    }
                }
                .padding(.vertical, TriSpace.x1)
            }

            if let first = progression.first, let latest = progression.last,
               first.result.id != latest.result.id {
                let change = latest.seconds - first.seconds
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: TriSpace.x3) {
                        progressionPoint(title: "First", point: first)
                        progressionArrow(change: change)
                        progressionPoint(title: "Latest", point: latest)
                    }
                    VStack(alignment: .leading, spacing: TriSpace.x3) {
                        progressionPoint(title: "First", point: first)
                        progressionArrow(change: change)
                        progressionPoint(title: "Latest", point: latest)
                    }
                }
                Text(changeText(change))
                    .font(TriType.smallBold)
                    .foregroundStyle(changeColor(change))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("Add another complete race at this distance to see progression over time.")
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .triCard(padding: TriSpace.x3)
    }

    private var compareCard: some View {
        VStack(alignment: .leading, spacing: TriSpace.x3) {
            TriSectionHeader(title: "Compare races")
            Text(comparableRaces.count >= 2
                 ? "Put two \(distanceLabel) finishes side by side and see every leg's gain or loss."
                 : "You need two complete races at the same distance before comparison is available.")
                .font(TriType.body)
                .foregroundStyle(TriPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if comparableRaces.count >= 2 {
                if raceBookUnlocked {
                    NavigationLink {
                        RaceCompareView(kind: activeKind)
                    } label: {
                        RaceBookActionLabel(title: "Compare two races",
                                            subtitle: "Time gained or lost by leg",
                                            systemImage: "arrow.left.arrow.right")
                    }
                    .buttonStyle(.triPress)
                } else {
                    Button {
                        paywallTrigger = .raceBookCompare
                    } label: {
                        RaceBookActionLabel(title: "Unlock race comparison",
                                            subtitle: "One lifetime purchase, no subscription",
                                            systemImage: "lock.fill")
                    }
                    .buttonStyle(.triPress)
                }
            }
        }
        .triCard(padding: TriSpace.x3)
    }

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: TriSpace.x3) {
            TriSectionHeader(title: "Build your Race Book")
            Text("Build a polished PDF and a tall shareable image from the choices below. Everything is generated on this phone.")
                .font(TriType.body)
                .foregroundStyle(TriPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TriPrimaryButton(title: raceBookUnlocked
                             ? (exportError == nil ? "Build PDF and image" : "Try export again")
                             : "Unlock to export",
                             systemImage: raceBookUnlocked ? "square.and.arrow.up" : "lock.fill",
                             isBusy: isBuildingExports) {
                if raceBookUnlocked {
                    buildExports()
                } else {
                    paywallTrigger = .raceBookExport
                }
            }

            if isBuildingExports {
                HStack(spacing: TriSpace.x2) {
                    ProgressView()
                        .tint(TriPalette.deep)
                    Text("Building both files on this phone...")
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkSecondary)
                }
                .frame(minHeight: TriGeo.tapTarget, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Building your Race Book exports")
            }

            if let exportError {
                Label(exportError, systemImage: "exclamationmark.triangle.fill")
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.negative)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(exportError)
            }

            if let pdf = exports?.pdf {
                Button {
                    pdfPreview = RaceBookPDFItem(url: pdf)
                } label: {
                    RaceBookActionLabel(title: "View PDF",
                                        subtitle: "Read it here before sharing",
                                        systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.triPress)

                ShareLink(item: pdf) {
                    Label("Share PDF", systemImage: "doc.richtext")
                }
                .font(TriType.bodyBold)
                .foregroundStyle(TriPalette.sunrise)
                .frame(minHeight: TriGeo.tapTarget)
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.triPressSilent)
            }
            if let image = exports?.image {
                ShareLink(item: image) {
                    Label("Share image", systemImage: "photo")
                }
                .font(TriType.bodyBold)
                .foregroundStyle(TriPalette.sunrise)
                .frame(minHeight: TriGeo.tapTarget)
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.triPressSilent)
            }

            Text(raceBookUnlocked ? "Unlimited exports are included with Race Book." : "Your results remain free. Compare and export are the only Race Book actions.")
                .font(TriType.micro)
                .foregroundStyle(TriPalette.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .triCard(padding: TriSpace.x3)
    }

    private var activeKind: RaceKind? {
        selectedKind ?? locker.availableKinds.first
    }

    private var raceBookUnlocked: Bool {
        ProGate.raceBookUnlocked(isPro: store.isPro)
    }

    private var comparableRaces: [RaceResult] {
        RaceBookAnalytics.comparableRaces(locker.results, kind: activeKind)
    }

    private var distanceLabel: String {
        activeKind?.longTitle.lowercased() ?? "like-for-like"
    }

    private var personalBests: [PersonalBest] {
        guard let activeKind else { return [] }
        return RaceBookAnalytics.bests(locker.results, kind: activeKind)
    }

    private var progression: [RaceBookProgressionPoint] {
        guard let activeKind else { return [] }
        return RaceBookAnalytics.progression(locker.results,
                                             discipline: selectedDiscipline,
                                             kind: activeKind)
    }

    private func progressionPoint(title: String, point: RaceBookProgressionPoint) -> some View {
        VStack(alignment: .leading, spacing: TriSpace.x1) {
            Text(title.uppercased())
                .font(TriType.micro)
                .foregroundStyle(TriPalette.inkTertiary)
            Text(TimeFormat.hms(point.seconds))
                .font(TriType.statLarge)
                .foregroundStyle(TriPalette.ink)
            Text(point.result.raceName)
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(dateText(point.result))
                .font(TriType.micro)
                .foregroundStyle(TriPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progressionArrow(change: Int) -> some View {
        Image(systemName: change == 0 ? "arrow.right" : (change < 0 ? "arrow.down.right" : "arrow.up.right"))
            .font(TriType.cardTitle)
            .foregroundStyle(changeColor(change))
            .frame(minWidth: TriGeo.tapTarget, minHeight: TriGeo.tapTarget)
            .accessibilityHidden(true)
    }

    private func buildExports() {
        guard !isBuildingExports, let athlete = locker.athlete else { return }
        Haptics.tap(.medium)
        isBuildingExports = true
        exports = nil
        exportGeneration &+= 1
        let generation = exportGeneration
        let results = locker.results
        let notes = notes.notes
        let options = exportOptions

        Task { @MainActor in
            let built = await Task.detached(priority: .userInitiated) {
                RaceBookExports(pdf: RaceBookBuilder.pdf(athlete: athlete,
                                                         results: results,
                                                         notes: notes,
                                                         options: options),
                                 image: RaceBookBuilder.image(athlete: athlete,
                                                              results: results,
                                                              notes: notes,
                                                              options: options))
            }.value
            guard !Task.isCancelled, generation == exportGeneration else { return }
            exports = built
            exportError = built.pdf == nil && built.image == nil
                ? "The export could not be created. Check available storage and try again."
                : nil
            isBuildingExports = false
            pattie.fire(.resumeExported)
            if built.pdf != nil || built.image != nil {
                Haptics.success()
            }
        }
    }

    private func syncKind() {
        let available = locker.availableKinds
        guard !available.isEmpty else {
            selectedKind = nil
            return
        }
        if let selectedKind, available.contains(selectedKind) { return }
        selectedKind = available.first
    }

    private func syncExportOptions() {
        let available = Set(locker.availableKinds)
        guard !available.isEmpty else { return }
        guard !didInitializeExportOptions else {
            exportOptions.kinds.formIntersection(available)
            if exportOptions.kinds.isEmpty {
                exportOptions.kinds = available
            }
            return
        }
        exportOptions.kinds = available
        didInitializeExportOptions = true
    }

    private func toggleExportKind(_ kind: RaceKind) {
        if exportOptions.kinds.contains(kind) {
            guard exportOptions.kinds.count > 1 else { return }
            exportOptions.kinds.remove(kind)
        } else {
            exportOptions.kinds.insert(kind)
        }
        pattie.react(.selection)
        exports = nil
        exportError = nil
    }

    private func yearsText(_ years: ClosedRange<Int>?) -> String {
        guard let years else { return "No dated races" }
        return years.lowerBound == years.upperBound
            ? String(years.lowerBound)
            : "\(years.lowerBound) to \(years.upperBound)"
    }

    private func dateText(_ result: RaceResult) -> String {
        result.eventDate.map(RaceDate.medium) ?? (result.year > 0 ? String(result.year) : "Undated")
    }

    private func changeText(_ change: Int) -> String {
        if change == 0 { return "No change between first and latest" }
        return change < 0
            ? "\(TimeFormat.hms(abs(change))) faster than the first"
            : "\(TimeFormat.hms(change)) slower than the first"
    }

    private func changeColor(_ change: Int) -> Color {
        if change < 0 { return TriPalette.positive }
        if change > 0 { return TriPalette.negative }
        return TriPalette.inkSecondary
    }
}

private struct RaceBookPDFItem: Identifiable {
    let url: URL

    var id: URL { url }
}

private struct RaceBookExports: Sendable {
    let pdf: URL?
    let image: URL?
}

private struct RaceBookBestRow: View {
    let best: PersonalBest

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideRow
            stackedRow
        }
        .frame(minHeight: TriGeo.tapTarget)
        .padding(.vertical, TriSpace.x1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Personal best, \(best.discipline.title), \(TimeFormat.hms(best.seconds)), \(best.result.raceName)")
    }

    private var wideRow: some View {
        HStack(alignment: .top, spacing: TriSpace.x3) {
            icon
            VStack(alignment: .leading, spacing: TriSpace.x1) {
                Text(best.discipline.title)
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.ink)
                Text(best.result.raceName)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minWidth: TriSpace.x10 + TriSpace.x8, alignment: .leading)
            .layoutPriority(1)
            Spacer(minLength: TriSpace.x2)
            time
        }
    }

    private var stackedRow: some View {
        HStack(alignment: .top, spacing: TriSpace.x3) {
            icon
            VStack(alignment: .leading, spacing: TriSpace.x1) {
                Text(best.discipline.title)
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.ink)
                Text(best.result.raceName)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                time
            }
            .layoutPriority(1)
        }
    }

    private var icon: some View {
        Image(systemName: best.discipline.symbol)
            .font(TriType.cardTitle)
            .foregroundStyle(TriPalette.color(for: best.discipline))
            .frame(width: TriSpace.x8, height: TriGeo.tapTarget)
    }

    private var time: some View {
        Text(TimeFormat.hms(best.seconds))
            .font(TriType.statMed)
            .foregroundStyle(TriPalette.ink)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct RaceBookActionLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: TriSpace.x3) {
            Image(systemName: systemImage)
                .font(TriType.cardTitle)
                .foregroundStyle(TriPalette.sunrise)
                .frame(width: TriSpace.x8)
            VStack(alignment: .leading, spacing: TriSpace.x1) {
                Text(title)
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: TriSpace.x2)
            Image(systemName: "chevron.right")
                .font(TriType.smallBold)
                .foregroundStyle(TriPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: TriGeo.tapTarget)
        .padding(.vertical, TriSpace.x1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

/// Like-for-like comparison. Both selectors draw from one RaceKind, and every
/// delta is derived from the normalized official seconds.
struct RaceCompareView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var pattie: PattieMode

    @State private var selectedKind: RaceKind?
    @State private var baselineID: String?
    @State private var comparisonID: String?

    init(kind: RaceKind? = nil) {
        _selectedKind = State(initialValue: kind)
    }

    var body: some View {
        ZStack {
            TriPalette.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: TriSpace.x6) {
                    Text("Choose two finishes at the same distance. Negative changes mean the comparison race was faster on that leg.")
                        .font(TriType.body)
                        .foregroundStyle(TriPalette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if availableKinds.count > 1 {
                        kindPicker
                    }
                    selector(title: "Baseline race", selectedID: $baselineID)
                    selector(title: "Comparison race", selectedID: $comparisonID)
                    comparisonCard
                }
                .padding(.horizontal, TriGeo.padPage)
                .padding(.top, TriSpace.x4)
                .padding(.bottom, TriSpace.x8)
            }
        }
        .navigationTitle("Compare races")
        .navigationBarTitleDisplayMode(.inline)
        .triNavBar()
        .onAppear { syncKindAndRaces() }
        .onChange(of: selectedKind) { _, _ in syncRaces() }
        .onChange(of: locker.results) { _, _ in syncKindAndRaces() }
    }

    private var availableKinds: [RaceKind] { locker.availableKinds }

    private var activeKind: RaceKind? {
        selectedKind ?? availableKinds.first
    }

    private var races: [RaceResult] {
        RaceBookAnalytics.comparableRaces(locker.results, kind: activeKind)
    }

    private var baseline: RaceResult? {
        races.first { $0.id == baselineID }
    }

    private var comparison: RaceResult? {
        races.first { $0.id == comparisonID }
    }

    private var deltas: [RaceBookLegDelta] {
        guard let baseline, let comparison else { return [] }
        return RaceBookAnalytics.deltas(earlier: baseline, later: comparison)
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: TriSpace.x2) {
            TriSectionHeader(title: "Distance")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TriSpace.x2) {
                    ForEach(availableKinds, id: \.self) { kind in
                        TriChip(title: kind.longTitle, isSelected: activeKind == kind) {
                            selectedKind = kind
                            pattie.react(.filter)
                        }
                    }
                }
                .padding(.vertical, TriSpace.x1)
            }
        }
    }

    private func selector(title: String, selectedID: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: TriSpace.x2) {
            TriSectionHeader(title: title, trailing: activeKind?.longTitle)
            Menu {
                ForEach(races) { race in
                    Button {
                        selectedID.wrappedValue = race.id
                        pattie.react(.selection)
                    } label: {
                        Text(raceLabel(race))
                    }
                }
            } label: {
                HStack(spacing: TriSpace.x2) {
                    Text(selectedID.wrappedValue.flatMap { id in races.first { $0.id == id }.map(raceLabel) }
                         ?? "Choose a finish")
                        .font(TriType.body)
                        .foregroundStyle(TriPalette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: TriSpace.x2)
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(TriPalette.inkTertiary)
                }
                .frame(maxWidth: .infinity, minHeight: TriGeo.tapTarget, alignment: .leading)
            }
            .buttonStyle(.triPressSilent)
        }
        .triCard(padding: TriSpace.x3)
    }

    @ViewBuilder
    private var comparisonCard: some View {
        if let baseline, let comparison {
            VStack(alignment: .leading, spacing: TriSpace.x3) {
                TriSectionHeader(title: "Time by leg")
                Text("\(baseline.raceName) to \(comparison.raceName)")
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(deltas) { delta in
                    RaceBookDeltaRow(delta: delta)
                }
                if deltas.isEmpty {
                    Text("These results do not have comparable positive split times yet.")
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .triCard(padding: TriSpace.x3)
        } else {
            TriPlaceholder(systemImage: "arrow.left.arrow.right",
                           title: "Choose two finishes",
                           message: "The leg-by-leg comparison will appear here.")
                .triCard(padding: TriSpace.x3)
        }
    }

    private func syncKindAndRaces() {
        if let selectedKind, availableKinds.contains(selectedKind) {
            syncRaces()
        } else {
            selectedKind = availableKinds.first
            syncRaces()
        }
    }

    private func syncRaces() {
        let ids = Set(races.map(\.id))
        if let baselineID, ids.contains(baselineID) == false {
            self.baselineID = nil
        }
        if let comparisonID, ids.contains(comparisonID) == false {
            self.comparisonID = nil
        }
        guard races.count >= 2 else { return }
        if baselineID == nil { baselineID = races[1].id }
        if comparisonID == nil || comparisonID == baselineID { comparisonID = races[0].id }
        if baselineID == comparisonID {
            comparisonID = races.first { $0.id != baselineID }?.id
        }
    }

    private func raceLabel(_ result: RaceResult) -> String {
        let date = result.eventDate.map(RaceDate.medium) ?? (result.year > 0 ? String(result.year) : "Undated")
        return "\(date), \(result.raceName)"
    }
}

private struct RaceBookDeltaRow: View {
    let delta: RaceBookLegDelta

    var body: some View {
        HStack(spacing: TriSpace.x3) {
            Image(systemName: delta.discipline.symbol)
                .font(TriType.bodyBold)
                .foregroundStyle(TriPalette.color(for: delta.discipline))
                .frame(width: TriSpace.x8)
            VStack(alignment: .leading, spacing: TriSpace.x1) {
                Text(delta.discipline.title)
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.ink)
                Text("\(TimeFormat.hms(delta.earlierSeconds))  to  \(TimeFormat.hms(delta.laterSeconds))")
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .monospacedDigit()
            }
            Spacer(minLength: TriSpace.x2)
            VStack(alignment: .trailing, spacing: TriSpace.x1) {
                Text(TimeFormat.delta(delta.change))
                    .font(TriType.statSmall)
                    .foregroundStyle(deltaColor)
                Text(delta.change == 0 ? "No change" : (delta.improved ? "Faster" : "Slower"))
                    .font(TriType.micro)
                    .foregroundStyle(TriPalette.inkTertiary)
            }
        }
        .frame(minHeight: TriGeo.tapTarget)
        .padding(.vertical, TriSpace.x1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(delta.discipline.title), \(TimeFormat.delta(delta.change)), \(delta.change < 0 ? "faster" : delta.change > 0 ? "slower" : "no change")")
    }

    private var deltaColor: Color {
        if delta.change < 0 { return TriPalette.positive }
        if delta.change > 0 { return TriPalette.negative }
        return TriPalette.inkSecondary
    }
}
