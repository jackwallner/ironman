import AVKit
import SwiftUI

/// The Pattie tab: her guided answers, and the full episode library.
///
/// Two ways into the same twenty clips. Ask Pattie routes you to the right one
/// in three taps; the library is for browsing when you already know what you're
/// after. They share the catalog and the player.
struct PointersView: View {
    @EnvironmentObject private var pattie: PattieMode

    enum Mode: String, CaseIterable, Identifiable {
        case ask = "Ask Pattie"
        case library = "All episodes"
        var id: String { rawValue }
    }

    @AppStorage("pointers.mode") private var mode: Mode = .ask
    @StateObject private var ask = AskPattieModel()
    @State private var path: [AskPattieStep] = []

    var body: some View {
        // One `NavigationStack` for the whole tab, with the mode switch in its
        // principal slot. Giving each half its own stack meant the toolbar the
        // segmented control lives in was torn down by the same tap that
        // switched it, which loses the interaction it was in the middle of.
        NavigationStack(path: $path) {
            ZStack {
                TriPalette.canvas.ignoresSafeArea()
                switch mode {
                case .ask:
                    AskPattieGoalList(model: ask, path: $path)
                case .library:
                    PointerLibraryView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
            }
            .navigationDestination(for: AskPattieStep.self) { step in
                switch step {
                case .topics(let goalID):
                    AskPattieTopicList(model: ask, path: $path, goalID: goalID)
                case .answers(let goalID, let topicID):
                    AskPattieAnswerList(model: ask, goalID: goalID, topicID: topicID)
                }
            }
            .refreshable {
                await ask.refresh()
                await PointerLibrary.shared.refresh(force: true)
            }
        }
        .pattieMoment(.askOpened, pattie)
        .onChange(of: mode) { _, _ in
            Haptics.selection()
            // A path built inside Ask Pattie means nothing to the library, and
            // leaving it pushed would strand the back button on a screen the
            // other mode cannot draw.
            path.removeAll()
        }
        .task { await ask.load() }
    }
}

/// Every episode, newest first, with a thumbnail and an offline badge.
struct PointerLibraryView: View {
    @EnvironmentObject private var pattie: PattieMode

    @State private var catalog: PointerCatalog = .empty
    @State private var isLoading = true
    @State private var filter: Discipline?
    @State private var playing: Pointer?

    @Environment(\.openURL) private var openURL

    var body: some View {
        content
            .pattieMoment(.pointers, pattie)
            .sheet(item: $playing) { PointerPlayerSheet(pointer: $0) }
            .task {
                catalog = await PointerLibrary.shared.catalog()
                isLoading = catalog.pointers.isEmpty
                catalog = await PointerLibrary.shared.refresh()
                isLoading = false
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
        ScrollView {
            LazyVStack(spacing: TriSpace.x3) {
                if let subtitle = catalog.subtitle {
                    Text(subtitle)
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if disciplines.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: TriSpace.x2) {
                            TriChip(title: "All", isSelected: filter == nil) { filter = nil }
                            ForEach(disciplines) { leg in
                                TriChip(title: leg.title, isSelected: filter == leg) { filter = leg }
                            }
                        }
                        .padding(.vertical, TriSpace.x1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(filtered) { pointer in
                    Button {
                        open(pointer)
                    } label: {
                        PointerRow(pointer: pointer)
                    }
                    .buttonStyle(.triPress)
                }
            }
            .padding(TriGeo.padPage)
            .padding(.bottom, TriSpace.x8)
        }
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

    private func open(_ pointer: Pointer) {
        pattie.fire(.pointerPlayed)
        if pointer.opensExternally, let url = pointer.playableURL {
            openURL(url)
        } else {
            playing = pointer
        }
    }
}

// MARK: - Row

private struct PointerRow: View {
    let pointer: Pointer

    @State private var isDownloaded = false

    var body: some View {
        HStack(spacing: TriSpace.x3) {
            thumbnail

            VStack(alignment: .leading, spacing: TriSpace.x1) {
                HStack(spacing: TriSpace.x1) {
                    if let episode = pointer.episode {
                        Text("EP " + String(episode))
                            .font(TriType.micro)
                            .foregroundStyle(TriPalette.inkTertiary)
                    }
                    if isDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(TriPalette.positive)
                            .accessibilityLabel("Saved for offline")
                    }
                }
                Text(pointer.title)
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if let summary = pointer.summary {
                    Text(summary)
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: TriSpace.x2)

            if let duration = pointer.durationText {
                Text(duration)
                    .font(TriType.statSmall)
                    .foregroundStyle(TriPalette.inkTertiary)
            }
        }
        .frame(minHeight: TriGeo.tapTarget + TriSpace.x4)
        .triCard(padding: TriSpace.x3)
        .contentShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
        .task {
            isDownloaded = await PointerMediaCache.shared.cachedFile(for: pointer) != nil
        }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: TriGeo.radiusInner, style: .continuous)
                .fill(TriPalette.deep.opacity(0.10))

            if let thumb = pointer.thumbnailURL.flatMap(URL.init(string:)) {
                AsyncImage(url: thumb) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.clear
                }
                .clipShape(RoundedRectangle(cornerRadius: TriGeo.radiusInner, style: .continuous))
            }

            Image(systemName: "play.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 3)
        }
        .frame(width: 76, height: 52)
        .accessibilityHidden(true)
    }
}

// MARK: - Player

/// Plays an episode from a local copy.
///
/// The remote file cannot be streamed: see `PointerMediaCache` for why the
/// hosting denies `AVURLAsset` both the MIME type and the path extension it
/// needs. The sheet downloads first, shows real progress while it does, and
/// then plays a file that works offline from then on.
struct PointerPlayerSheet: View {
    let pointer: Pointer

    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var progress: Double = 0
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                content
            }
            .navigationTitle(pointer.title)
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                        .triTapTarget()
                }
            }
        }
        .task { await load() }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    @ViewBuilder
    private var content: some View {
        if let player {
            VideoPlayer(player: player)
                .ignoresSafeArea(edges: .bottom)
        } else if let errorMessage {
            TriPlaceholder(systemImage: "wifi.exclamationmark",
                           title: "Couldn't load the episode",
                           message: errorMessage,
                           actionTitle: "Try again") {
                Task { await load(force: true) }
            }
        } else {
            VStack(spacing: TriSpace.x3) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(TriPalette.sunrise)
                    .frame(maxWidth: 220)
                Text(progress > 0 ? "Downloading \(Int(progress * 100))%" : "Starting the episode…")
                    .font(TriType.small)
                    .foregroundStyle(.white.opacity(0.75))
                    .monospacedDigit()
                Text("Saved after the first play, so it works offline next time.")
                    .font(TriType.micro)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .padding(TriGeo.padPage)
        }
    }

    private func load(force: Bool = false) async {
        if force {
            errorMessage = nil
            progress = 0
        }
        do {
            let url = try await PointerMediaCache.shared.file(for: pointer) { fraction in
                Task { @MainActor in progress = fraction }
            }
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        } catch {
            guard !isTaskCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}
