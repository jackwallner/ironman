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

        var title: String {
            switch self {
            case .locker: "Locker"
            case .explore: "Explore"
            case .pattie: "Tips"
            case .resume: "Race Book"
            case .settings: "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .locker: "tray.full.fill"
            case .explore: "person.2.fill"
            case .pattie: "play.rectangle.fill"
            case .resume: "book.closed.fill"
            case .settings: "gearshape.fill"
            }
        }
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
            tab(.locker) { LockerView() }
            tab(.explore) { ExploreView() }
            tab(.pattie) { PointersView() }
            tab(.resume) { ResumeView() }
            tab(.settings) { SettingsView() }
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
        .task { await openDuoScreen() }
        #endif
    }

    /// One tab's screen. Unfolded, the system's floating glass bar let rows show
    /// through it and reported an inset about twice its height, so the leading
    /// pane hides it for an opaque bar of the same tabs. That bar is a safe-area
    /// inset, so every list scrolls its last row clear of it.
    private func tab<Content: View>(_ tab: Tab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .toolbar(split == nil ? .automatic : .hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if split != nil { paneTabBar }
            }
            .tabItem { Label(tab.title, systemImage: tab.systemImage) }
            .tag(tab)
    }

    /// The pane's bar, topped by a short fade so a row scrolling toward it
    /// dissolves into the canvas instead of being cut at the bar's edge. The
    /// fade is part of the inset, so the last row still scrolls clear of it.
    private var paneTabBar: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [TriPalette.canvas.opacity(0), TriPalette.canvas],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: TriSpace.x6)
                .allowsHitTesting(false)
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    paneTabButton(tab)
                }
            }
            .padding(.horizontal, TriSpace.x2)
            .padding(.vertical, TriSpace.x2)
            .background(TriPalette.surface.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(TriPalette.hairline)
                    .frame(height: TriGeo.hairline)
            }
        }
    }

    private func paneTabButton(_ tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: TriSpace.x1) {
                // A fixed icon box keeps every label on one baseline.
                Image(systemName: tab.systemImage)
                    .font(TriType.bodyBold)
                    .imageScale(.large)
                    .frame(height: TriSpace.x8)
                Text(tab.title)
                    .font(TriType.micro)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? TriPalette.sunrise : TriPalette.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: TriGeo.tapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.triPressSilent)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    #if DEBUG
    /// `-DuoScreen <surface>` opens one store surface on the seeded data, so
    /// each gh-sim `--screen` launch captures it folded and unfolded.
    private func openDuoScreen() async {
        guard let screen = DuoScreen(arguments: ProcessInfo.processInfo.arguments) else { return }
        racePane.selectedID = screen.race
        selectedTab = switch screen {
        case .locker, .races, .rankings: .locker
        case .racebook: .resume
        case .explore: .explore
        case .tips: .pattie
        }
        guard let rankings = screen.lockerRankings else { return }
        // Give the seeded Locker a moment to lay out before scrolling it.
        try? await Task.sleep(for: .seconds(1.5))
        NotificationCenter.default.post(name: .duoScreenLocker, object: rankings)
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
                        // The inner display's status column insets the trailing
                        // edge only, which pushed every card off centre. The
                        // column sits beside the nav bar, so the cards below
                        // can use the pane's full width.
                        .ignoresSafeArea(.container, edges: .trailing)
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
    /// `-DuoScreen` scrolling the Locker to its races (`false`) or rankings
    /// (`true`).
    static let duoScreenLocker = Notification.Name("ironsplits.duoScreenLocker")
}

/// The store surfaces `-DuoScreen` can open.
enum DuoScreen: String, CaseIterable {
    case locker, races, rankings, racebook, explore, tips

    init?(arguments: [String]) {
        guard let index = arguments.firstIndex(of: "-DuoScreen"),
              index + 1 < arguments.count else { return nil }
        self.init(rawValue: arguments[index + 1].lowercased())
    }

    /// The seeded race in the unfolded detail pane; nil is the latest finish.
    var race: String? {
        switch self {
        case .locker: nil
        case .races: "demo-half-2025"
        case .rankings: "demo-full-2025"
        case .racebook: "demo-full-2024"
        case .explore: "demo-half-2024"
        case .tips: "demo-full-2023"
        }
    }

    /// For the Locker surfaces, whether it scrolls to rankings or races.
    var lockerRankings: Bool? {
        switch self {
        case .races: false
        case .rankings: true
        default: nil
        }
    }
}
#endif
