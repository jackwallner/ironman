import SwiftUI
import StoreKit

struct RootTabView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var reviewCoordinator: ReviewPromptCoordinator
    @EnvironmentObject private var pattie: PattieMode

    @State private var showingFeedback = false
    @State private var selectedTab: Tab = .locker
    @Environment(\.requestReview) private var requestReview

    private enum Tab: CaseIterable, Hashable {
        case locker, explore, pattie, resume, settings
    }

    var body: some View {
        Group {
            if locker.hasClaimedAthlete {
                tabs
            } else {
                AthleteSearchView(isOnboarding: true)
            }
        }
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
    }

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

