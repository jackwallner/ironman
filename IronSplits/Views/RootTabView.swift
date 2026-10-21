import SwiftUI
import StoreKit

struct RootTabView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var reviewCoordinator: ReviewPromptCoordinator
    @EnvironmentObject private var pattie: PattieMode

    @State private var showingFeedback = false
    @State private var selectedTab: Tab = .locker
    @State private var racePane = RacePane()
    @State private var paneGeometry = PaneGeometry(width: 0, fold: nil)
    @Environment(\.requestReview) private var requestReview
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private enum Tab: CaseIterable, Hashable {
        case locker, explore, pattie, resume, settings
    }

    /// Unfolded, the selected race gets its own pane beside the tabs.
    private var split: UnfoldedSplit? {
        UnfoldedSplit.make(
            width: paneGeometry.width,
            isRegularWidth: horizontalSizeClass == .regular,
            fold: paneGeometry.fold
        )
    }

    /// Each unfolded pane is phone-width, so its screen lays out as on a phone.
    private var paneSizeClass: UserInterfaceSizeClass? {
        split == nil ? horizontalSizeClass : .compact
    }

    var body: some View {
        // One tree for both poses: folding only changes frames, so the tabs keep
        // their navigation and scroll position.
        ZStack(alignment: .topLeading) {
            Group {
                if locker.hasClaimedAthlete {
                    tabs
                } else {
                    AthleteSearchView(isOnboarding: true)
                }
            }
            .environment(\.horizontalSizeClass, paneSizeClass)
            .environment(split == nil ? nil : racePane)
            .frame(maxWidth: split?.primaryWidth ?? .infinity, maxHeight: .infinity)

            if let split {
                RaceDetailPane(pane: racePane)
                    .environment(\.horizontalSizeClass, .compact)
                    .frame(width: split.secondaryWidth)
                    .frame(maxHeight: .infinity)
                    .padding(.leading, split.secondaryX)
            }
        }
        .onGeometryChange(for: PaneGeometry.self) { proxy in
            PaneGeometry(width: proxy.size.width, fold: proxy.verticalFold())
        } action: { paneGeometry = $0 }
        .background(TriPalette.canvas.ignoresSafeArea())
        .pattieHost(pattie)
        .onChange(of: locker.hasClaimedAthlete) { _, claimed in
            if claimed {
                settings.hasCompletedOnboarding = true
                pattie.fire(.claimed)
            }
        }
        .task {
            // A long career is worth remarking on, but only once she is past
            // the claim, so the two don't stack on the same screen.
            if locker.results.count >= 10 { pattie.fire(.veteran) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ironSplitsPositiveMomentForReview)) { _ in
            presentReviewPromptIfEligible()
        }
        .onReceive(reviewCoordinator.$feedbackRequested.filter { $0 }) { _ in
            showingFeedback = true
            reviewCoordinator.clear()
        }
        .sheet(isPresented: $showingFeedback) {
            ReviewPromptSheet { outcome in
                handle(outcome)
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            LockerView()
                .tabItem { Label("Locker", systemImage: "tray.full.fill") }
                .tag(Tab.locker)
            ExploreView()
                .tabItem { Label("Explore", systemImage: "person.2.fill") }
                .tag(Tab.explore)
            PointersView()
                .tabItem { Label("Tips", systemImage: "play.rectangle.fill") }
                .tag(Tab.pattie)
            ResumeView()
                .tabItem { Label("Race Book", systemImage: "book.closed.fill") }
                .tag(Tab.resume)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(TriPalette.sunrise)
        .background(TriPalette.canvas.ignoresSafeArea())
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: selectedTab) { _, _ in
            Haptics.selection()
            pattie.react(.tab)
        }
        .task { await locker.refresh() }
        #if DEBUG
        .task { await runCaptureTour() }
        #endif
    }

    #if DEBUG
    /// `-CaptureTour`: walks the Locker races and rankings, Race Book, Explore
    /// and Tips on a timer, so one unattended gh-sim launch (which can only
    /// screenshot on its own clock) captures every store screen. Dwell is `-CaptureTourStep <s>`, the first
    /// screen holds for `-CaptureTourFirst <s>` folded and that plus
    /// `-CaptureTourUnfoldedDelay <s>` unfolded, where the runner waits for the
    /// inner display to draw before its first shot.
    private func runCaptureTour() async {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-CaptureTour") else { return }
        func value(_ key: String, _ fallback: Double) -> Double {
            guard let i = args.firstIndex(of: key), i + 1 < args.count else { return fallback }
            return Double(args[i + 1]) ?? fallback
        }
        let step = value("-CaptureTourStep", 13.5)
        var first = value("-CaptureTourFirst", 19.5)
        if horizontalSizeClass == .regular { first += value("-CaptureTourUnfoldedDelay", 7.5) }
        // Tab, the race in the unfolded detail pane, and for the Locker
        // stops whether it shows rankings. The first stop is the launch state.
        let stops: [(tab: Tab, race: String?, rankings: Bool?)] = [
            (.locker, nil, nil),
            (.locker, "demo-half-2025", false),
            (.locker, "demo-full-2025", true),
            (.resume, "demo-full-2025", nil),
            (.explore, "demo-full-2025", nil),
            (.pattie, "demo-full-2025", nil),
        ]
        for (index, stop) in stops.enumerated() {
            if Task.isCancelled { return }
            if index > 0 {
                if let rankings = stop.rankings {
                    NotificationCenter.default.post(name: .captureTourLocker, object: rankings)
                }
                racePane.selectedID = stop.race
                selectedTab = stop.tab
            }
            try? await Task.sleep(for: .seconds(index == 0 ? first : step))
        }
    }
    #endif

    private func presentReviewPromptIfEligible() {
        guard ReviewPromptTracker.shouldShowAfterPositiveMoment(
            hasCompletedOnboarding: settings.hasCompletedOnboarding
        ) else { return }
        // Apple's own prompt, asked of everyone who qualifies. It is
        // rate-limited and often shows nothing, hence the short cooldown.
        ReviewPromptTracker.markSoftDeferred()
        requestReview()
    }

    private func handle(_ outcome: ReviewPromptDismissOutcome) {
        switch outcome {
        case .notNow:
            ReviewPromptTracker.markShown()
        case .feedbackDraftOpened:
            ReviewPromptTracker.markFeedbackDraftOpened()
        }
        showingFeedback = false
    }
}


/// The trailing pane on the unfolded Duo: the race picked in the Locker, or the
/// latest finish until one is picked.
private struct RaceDetailPane: View {
    let pane: RacePane
    @EnvironmentObject private var locker: LockerStore

    var body: some View {
        NavigationStack {
            Group {
                if let race = pane.race(in: locker.results) {
                    // Shown without being opened until the athlete picks a row,
                    // so the default race neither counts toward the review
                    // prompt nor wakes Pattie.
                    RaceDetailView(result: race,
                                   opensQuietly: pane.selectedID != race.id,
                                   isPaneRoot: true)
                        .id(race.id)
                } else {
                    TriPlaceholder(systemImage: "flag.checkered",
                                   title: "Your races open here",
                                   message: "Pick a race in your Locker to see its splits, ranks and field beside the list.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(TriPalette.canvas)
                }
            }
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(TriPalette.divider)
                .frame(width: TriGeo.hairline)
                .ignoresSafeArea()
        }
    }
}

/// Which race the unfolded Duo's detail pane shows. Present in the environment
/// only while split, which is how the Locker knows to select rather than push.
@MainActor @Observable
final class RacePane {
    var selectedID: String?

    func select(_ result: RaceResult) {
        selectedID = result.id
        Haptics.selection()
    }

    func race(in results: [RaceResult]) -> RaceResult? {
        results.first { $0.id == selectedID } ?? Self.defaultRace(in: results)
    }

    nonisolated static func defaultRace(in results: [RaceResult]) -> RaceResult? {
        let finishes = results.filter(\.isComplete)
        return (finishes.isEmpty ? results : finishes)
            .max { ($0.eventDate ?? .distantPast) < ($1.eventDate ?? .distantPast) }
    }
}

#if DEBUG
extension Notification.Name {
    /// The capture tour scrolling the Locker to its races (`false`) or
    /// rankings (`true`).
    static let captureTourLocker = Notification.Name("ironsplits.captureTourLocker")
}
#endif
