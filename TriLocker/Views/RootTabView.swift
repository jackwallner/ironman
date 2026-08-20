import SwiftUI
import StoreKit

struct RootTabView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var reviewCoordinator: ReviewPromptCoordinator

    @State private var reviewSheet: ReviewPromptSheet.Step?
    @State private var pendingRequestReview = false
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        Group {
            if locker.hasClaimedAthlete {
                tabs
            } else {
                AthleteSearchView(isOnboarding: true)
            }
        }
        .onChange(of: locker.hasClaimedAthlete) { _, claimed in
            if claimed { settings.hasCompletedOnboarding = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .triLockerPositiveMomentForReview)) { _ in
            presentReviewPromptIfEligible()
        }
        .onReceive(reviewCoordinator.$pendingPresentation.compactMap { $0 }) { presentation in
            reviewSheet = presentation == .feedbackOnly ? .feedback : .enjoyment
            reviewCoordinator.clear()
        }
        .sheet(item: $reviewSheet) { step in
            ReviewPromptSheet(initialStep: step) { outcome in
                handle(outcome)
            }
        } 
    }

    private var tabs: some View {
        TabView {
            LockerView()
                .tabItem { Label("Locker", systemImage: "tray.full.fill") }
            BestsView()
                .tabItem { Label("Bests", systemImage: "list.number") }
            PointersView()
                .tabItem { Label("Pointers", systemImage: "play.rectangle.fill") }
            ResumeView()
                .tabItem { Label("Resume", systemImage: "doc.text.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(TriPalette.sunrise)
        .task { await locker.refresh() }
    }

    private func presentReviewPromptIfEligible() {
        guard ReviewPromptTracker.shouldShowAfterPositiveMoment(
            hasCompletedOnboarding: settings.hasCompletedOnboarding
        ) else { return }
        reviewSheet = .enjoyment
    }

    private func handle(_ outcome: ReviewPromptDismissOutcome) {
        switch outcome {
        case .notNow:
            ReviewPromptTracker.markShown()
        case .feedbackSubmitted:
            ReviewPromptTracker.markFeedbackSubmitted()
        case .openedWriteReview:
            ReviewPromptTracker.markOpenedWriteReview()
        case .enjoyedMaybeLater:
            // Apple's native prompt is rate-limited and often shows nothing, so
            // this uses the short cooldown rather than the full one.
            ReviewPromptTracker.markSoftDeferred()
            pendingRequestReview = true
        }
        reviewSheet = nil
        if pendingRequestReview {
            pendingRequestReview = false
            requestReview()
        }
    }
}

extension ReviewPromptSheet.Step: Identifiable {
    public var id: Int {
        switch self {
        case .enjoyment: return 0
        case .reviewPitch: return 1
        case .feedback: return 2
        }
    }
}
