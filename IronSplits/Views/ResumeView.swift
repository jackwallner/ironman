import SwiftUI

/// The race resume: every start, in the shape race entries ask for.
struct ResumeView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var pattie: PattieMode

    @State private var selectedKinds: Set<RaceKind> = []
    @State private var includeSplits = true
    @State private var includeDNF = false
    @State private var paywallTrigger: PaywallTrigger?
    @State private var pdfURL: URL?

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
            .sheet(item: $paywallTrigger) { PaywallView(trigger: $0) }
            .onAppear {
                if selectedKinds.isEmpty {
                    selectedKinds = Set(locker.availableKinds)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if locker.results.isEmpty {
            TriPlaceholder(systemImage: "doc.text",
                           title: "Nothing to export yet",
                           message: "Your resume is built from the races in your locker.")
        } else if !store.isPro {
            TriPlaceholder(systemImage: "lock.fill",
                           title: "Race resume",
                           message: "Every race with its date, distance, bib number, official time and division place — the sheet other races ask you to produce, in one tap.",
                           actionTitle: "Unlock Iron Splits+") {
                paywallTrigger = .raceResume
            }
        } else {
            list
        }
    }

    private var rows: [RaceResult] {
        ResumeBuilder.rows(for: locker.results, options: options)
    }

    private var options: ResumeBuilder.Options {
        ResumeBuilder.Options(kinds: selectedKinds.isEmpty ? Set(RaceKind.allCases) : selectedKinds,
                              includeSplits: includeSplits,
                              includeDNF: includeDNF)
    }

    private var list: some View {
        List {
            Section {
                ForEach(locker.availableKinds, id: \.self) { kind in
                    Toggle(kind.longTitle, isOn: Binding(
                        get: { selectedKinds.contains(kind) },
                        set: { isOn in
                            if isOn { selectedKinds.insert(kind) } else { selectedKinds.remove(kind) }
                        }
                    ))
                }
                Toggle("Include splits", isOn: $includeSplits)
                Toggle("Include DNFs", isOn: $includeDNF)
            } header: {
                TriSectionHeader(title: "Include")
            }
            .listRowBackground(TriPalette.surface)

            Section {
                if let athlete = locker.athlete {
                    ShareLink(item: ResumeBuilder.plainText(athlete: athlete, results: locker.results, options: options)) {
                        Label("Share as text", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        pdfURL = ResumeBuilder.pdf(athlete: athlete, results: locker.results, options: options)
                    } label: {
                        Label("Build PDF", systemImage: "doc.richtext")
                    }
                    if let pdfURL {
                        ShareLink(item: pdfURL) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            } header: {
                TriSectionHeader(title: "Export", trailing: "\(rows.count) races")
            }
            .listRowBackground(TriPalette.surface)

            Section {
                ForEach(rows) { result in
                    ResumeRow(result: result)
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
        // Any change to what goes in invalidates the file that was built from
        // the old settings, so drop it rather than sharing a stale PDF.
        .onChange(of: options.kinds) { _, _ in pdfURL = nil }
        .onChange(of: includeSplits) { _, _ in pdfURL = nil }
        .onChange(of: includeDNF) { _, _ in pdfURL = nil }
    }
}

private struct ResumeRow: View {
    let result: RaceResult

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(result.raceName)
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.ink)
                Spacer()
                Text(result.isComplete ? TimeFormat.hms(result.finish) : "DNF")
                    .font(TriType.statSmall)
                    .foregroundStyle(result.isComplete ? TriPalette.ink : TriPalette.negative)
            }
            HStack(spacing: 8) {
                Text(dateText)
                if let bib = result.bib { Text("Bib " + String(bib)) }
                if let group = result.ageGroup {
                    Text(result.finishRankGroup.map { "\(group) #\($0)" } ?? group)
                }
            }
            .font(TriType.small)
            .foregroundStyle(TriPalette.inkTertiary)
        }
        .padding(.vertical, 2)
    }

    private var dateText: String {
        guard let date = result.eventDate else { return String(result.year) }
        return RaceDate.medium(date)
    }
}
