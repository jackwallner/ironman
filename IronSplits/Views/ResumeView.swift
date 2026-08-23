import SwiftUI

/// The race resume: every start, in the shape race entries ask for.
struct ResumeView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var pattie: PattieMode

    @State private var selectedKinds: Set<RaceKind> = []
    @State private var didInitializeKinds = false
    @State private var includeSplits = true
    @State private var includeIncomplete = false
    @State private var paywallTrigger: PaywallTrigger?
    @State private var raceBookPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                TriPalette.canvas.ignoresSafeArea()
                content
            }
            .navigationTitle("Resume")
            .pattieMoment(.resume, pattie)
            // Inline: a large title renders as an empty band here, and the
            // screen's own header is already doing that job.
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .onAppear {
                syncKinds()
            }
            .onChange(of: locker.athlete?.id) { _, _ in
                selectedKinds = []
                didInitializeKinds = false
                syncKinds()
            }
            .onChange(of: locker.availableKinds) { _, _ in syncKinds() }
            .sheet(isPresented: $raceBookPresented) {
                RaceBookView()
            }
            .sheet(item: $paywallTrigger) { trigger in
                PaywallView(trigger: trigger)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if locker.results.isEmpty {
            TriPlaceholder(systemImage: "doc.text",
                           title: "No races yet",
                           message: "Your free history preview appears once your locker has results.")
        } else {
            list
        }
    }

    private var rows: [RaceResult] {
        ResumeBuilder.rows(for: locker.results, options: options)
    }

    private var options: ResumeBuilder.Options {
        ResumeBuilder.Options(kinds: selectedKinds,
                              includeSplits: includeSplits,
                              includeDNF: includeIncomplete)
    }

    private var list: some View {
        List {
            Section {
                if rows.isEmpty {
                    Text("Select at least one distance to open Race Book.")
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if raceBookUnlocked {
                    Button {
                        Haptics.tap()
                        raceBookPresented = true
                    } label: {
                        Label("Open Race Book", systemImage: "book.closed.fill")
                    }
                    .buttonStyle(.triPress)
                } else {
                    Button {
                        paywallTrigger = .raceBookExport
                    } label: {
                        Label("Unlock Race Book exports", systemImage: "lock.fill")
                    }
                    .buttonStyle(.triPress)
                }
                Text("Your complete history and preview stay free. Race Book adds like-for-like comparison and unlimited PDF or image exports for one lifetime purchase.")
                    .font(TriType.micro)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                TriSectionHeader(title: "Race Book", trailing: "\(rows.count) races")
            }
            .listRowBackground(TriPalette.surface)

            Section {
                ForEach(locker.availableKinds, id: \.self) { kind in
                    Toggle(kind.longTitle, isOn: Binding(
                        get: { selectedKinds.contains(kind) },
                        set: { isOn in
                            if isOn { selectedKinds.insert(kind) } else { selectedKinds.remove(kind) }
                            pattie.react(.selection)
                        }
                    ))
                }
                Toggle("Include splits", isOn: $includeSplits)
                Toggle("Include incomplete results", isOn: $includeIncomplete)
            } header: {
                TriSectionHeader(title: "Include")
            }
            .listRowBackground(TriPalette.surface)

            Section {
                if rows.isEmpty {
                    Text("No races match these options. Select a distance or include incomplete results.")
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: TriGeo.tapTarget)
                } else {
                    ForEach(rows) { result in
                        ResumeRow(result: result)
                    }
                }
            } header: {
                TriSectionHeader(title: "Preview")
            } footer: {
                Text("Times are as published by the event timer.")
                    .font(TriType.micro)
                    .foregroundStyle(TriPalette.inkTertiary)
            }
            .listRowBackground(TriPalette.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .safeAreaPadding(.bottom, TriSpace.x4)
        .onChange(of: includeSplits) { _, _ in
            pattie.react(.selection)
        }
        .onChange(of: includeIncomplete) { _, _ in
            pattie.react(.selection)
        }
    }

    private func syncKinds() {
        let available = Set(locker.availableKinds)
        guard !didInitializeKinds else {
            selectedKinds.formIntersection(available)
            return
        }
        selectedKinds = available
        didInitializeKinds = true
    }

    private var raceBookUnlocked: Bool {
        ProGate.raceBookUnlocked(isPro: store.isPro)
    }

}

private struct ResumeRow: View {
    let result: RaceResult

    var body: some View {
        VStack(alignment: .leading, spacing: TriSpace.x1) {
            HStack(alignment: .top, spacing: TriSpace.x2) {
                Text(result.raceName)
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                Spacer()
                Text(result.isComplete ? TimeFormat.hms(result.finish) : (ResumeBuilder.statusLabel(for: result) ?? ""))
                    .font(TriType.statSmall)
                    .foregroundStyle(result.isComplete ? TriPalette.ink : TriPalette.negative)
                    .fixedSize(horizontal: true, vertical: false)
            }
            HStack(spacing: TriSpace.x2) {
                Text(dateText)
                if let bib = result.bib { Text("Bib " + String(bib)) }
                if let group = result.ageGroup {
                    Text(result.finishRankGroup.map { "\(group) #\($0)" } ?? group)
                }
            }
            .font(TriType.small)
            .foregroundStyle(TriPalette.inkTertiary)
        }
        .frame(minHeight: TriGeo.tapTarget)
        .padding(.vertical, TriSpace.x1)
    }

    private var dateText: String {
        guard let date = result.eventDate else { return String(result.year) }
        return RaceDate.medium(date)
    }
}
