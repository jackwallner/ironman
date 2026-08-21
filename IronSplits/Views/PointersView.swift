import SwiftUI
import AVKit

/// The Tri Pointers coaching library.
struct PointersView: View {
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var pattie: PattieMode

    @State private var catalog: PointerCatalog = .empty
    @State private var isLoading = true
    @State private var filter: Discipline?
    @State private var paywallTrigger: PaywallTrigger?
    @State private var playing: Pointer?

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                TriPalette.canvas.ignoresSafeArea()
                content
            }
            .navigationTitle(catalog.title)
            .pattieMoment(.pointers, pattie)
            // Inline: a large title renders as an empty band here, and the
            // screen's own header is already doing that job.
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .sheet(item: $paywallTrigger) { PaywallView(trigger: $0) }
            .sheet(item: $playing) { pointer in
                if let url = pointer.playableURL {
                    PointerPlayer(url: url, title: pointer.title)
                }
            }
            .task {
                catalog = await PointerLibrary.shared.catalog()
                isLoading = catalog.pointers.isEmpty
                catalog = await PointerLibrary.shared.refresh()
                isLoading = false
            }
            .refreshable {
                catalog = await PointerLibrary.shared.refresh(force: true)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && catalog.pointers.isEmpty {
            ProgressView().tint(TriPalette.deep)
        } else if catalog.pointers.isEmpty {
            TriPlaceholder(systemImage: "play.rectangle",
                           title: catalog.title,
                           message: catalog.emptyMessage ?? PointerCatalog.empty.emptyMessage)
        } else {
            list
        }
    }

    private var list: some View {
        List {
            if let subtitle = catalog.subtitle {
                Section {
                    Text(subtitle)
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkSecondary)
                        .listRowBackground(Color.clear)
                }
            }

            if disciplines.count > 1 {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip(title: "All", isSelected: filter == nil) { filter = nil }
                            ForEach(disciplines) { leg in
                                chip(title: leg.title, isSelected: filter == leg) { filter = leg }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: TriGeo.padPage, bottom: 8, trailing: TriGeo.padPage))
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(filtered) { pointer in
                    Button {
                        open(pointer)
                    } label: {
                        PointerRow(pointer: pointer, isLocked: isLocked(pointer))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(TriPalette.surface)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(TriType.smallBold)
                .foregroundStyle(isSelected ? .white : TriPalette.inkSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? TriPalette.deep : TriPalette.surface, in: Capsule())
                .overlay(Capsule().stroke(TriPalette.hairline, lineWidth: isSelected ? 0 : TriGeo.hairline))
        }
        .buttonStyle(.plain)
    }

    private var disciplines: [Discipline] {
        var seen: [Discipline] = []
        for pointer in catalog.pointers {
            if let discipline = pointer.discipline, !seen.contains(discipline) {
                seen.append(discipline)
            }
        }
        return seen
    }

    private var filtered: [Pointer] {
        guard let filter else { return catalog.pointers }
        return catalog.pointers.filter { $0.discipline == filter }
    }

    private func isLocked(_ pointer: Pointer) -> Bool {
        !pointer.isFree && !store.isPro
    }

    private func open(_ pointer: Pointer) {
        guard !isLocked(pointer) else {
            paywallTrigger = .pointers
            return
        }
        guard let url = pointer.playableURL else { return }
        if pointer.opensExternally {
            openURL(url)
        } else {
            playing = pointer
        }
    }
}

private struct PointerRow: View {
    let pointer: Pointer
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(TriPalette.deep.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: isLocked ? "lock.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isLocked ? TriPalette.inkTertiary : TriPalette.deep)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let episode = pointer.episode {
                        Text("EP " + String(episode))
                            .font(TriType.micro)
                            .foregroundStyle(TriPalette.inkTertiary)
                    }
                    if pointer.isFree {
                        TriBadge(text: "Free", color: TriPalette.positive)
                    }
                }
                Text(pointer.title)
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.ink)
                    .lineLimit(2)
                if let summary = pointer.summary {
                    Text(summary)
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if let duration = pointer.durationText {
                Text(duration)
                    .font(TriType.statSmall)
                    .foregroundStyle(TriPalette.inkTertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct PointerPlayer: View {
    let url: URL
    let title: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .triNavBar()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }.foregroundStyle(.white)
                    }
                }
        }
    }
}
