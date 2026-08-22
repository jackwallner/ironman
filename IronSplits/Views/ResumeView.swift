import SwiftUI

/// The race resume: every start, in the shape race entries ask for.
struct ResumeView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var pattie: PattieMode

    @State private var selectedKinds: Set<RaceKind> = []
    @State private var includeSplits = true
    @State private var includeDNF = false
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
                            pattie.react(.selection)
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
                    .simultaneousGesture(TapGesture().onEnded { pattie.fire(.resumeExported) })
                    Button {
                        Haptics.tap()
                        pdfURL = ResumeBuilder.pdf(athlete: athlete, results: locker.results, options: options)
                        pattie.fire(.resumeExported)
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
        .onChange(of: includeSplits) { _, _ in
            pdfURL = nil
            pattie.react(.selection)
        }
        .onChange(of: includeDNF) { _, _ in
            pdfURL = nil
            pattie.react(.selection)
        }
    }
}

private struct ResumeRow: View {
    let result: RaceResult

    var body: some View {
        VStack(alignment: .leading, spacing: TriSpace.x1) {
            HStack {
                Text(result.raceName)
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.ink)
                Spacer()
                Text(result.isComplete ? TimeFormat.hms(result.finish) : "DNF")
                    .font(TriType.statSmall)
                    .foregroundStyle(result.isComplete ? TriPalette.ink : TriPalette.negative)
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
        .frame(minHeight: TriGeo.tapTarget - TriSpace.x2)
        .padding(.vertical, TriSpace.x1)
    }

    private var dateText: String {
        guard let date = result.eventDate else { return String(result.year) }
        return RaceDate.medium(date)
    }
}
