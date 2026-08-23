import SwiftUI
import StoreKit

struct RootTabView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var reviewCoordinator: ReviewPromptCoordinator
    @EnvironmentObject private var pattie: PattieMode
    @Environment(\.colorScheme) private var colorScheme

    @State private var reviewSheet: ReviewPromptSheet.Step?
    @State private var pendingRequestReview = false
    @State private var selectedTab: Tab = .locker
    @Environment(\.requestReview) private var requestReview

    private enum Tab: CaseIterable, Hashable {
        case locker, explore, pattie, resume, settings

        var title: String {
            switch self {
            case .locker: return "Locker"
            case .explore: return "Explore"
            case .pattie: return "Pattie"
            case .resume: return "Race Book"
            case .settings: return "Settings"
            }
        }

        var symbol: String {
            switch self {
            case .locker: return "tray.full.fill"
            case .explore: return "person.2.fill"
            case .pattie: return "play.rectangle.fill"
            case .resume: return "book.closed.fill"
            case .settings: return "gearshape.fill"
            }
        }
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
        TabView(selection: $selectedTab) {
            LockerView()
                .tabItem { Label("Locker", systemImage: "tray.full.fill") }
                .tag(Tab.locker)
            ExploreView()
                .tabItem { Label("Explore", systemImage: "person.2.fill") }
                .tag(Tab.explore)
            PointersView()
                .tabItem { Label("Pattie", systemImage: "play.rectangle.fill") }
                .tag(Tab.pattie)
            ResumeView()
                .tabItem { Label("Race Book", systemImage: "book.closed.fill") }
                .tag(Tab.resume)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(TriPalette.sunrise)
        .toolbar(.hidden, for: .tabBar)
        .background(TriPalette.canvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
        }
        .onChange(of: selectedTab) { _, _ in
            Haptics.selection()
            pattie.react(.tab)
        }
        .task { await locker.refresh() }
    }

    private var tabBar: some View {
        HStack(spacing: TriSpace.x1) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: TriSpace.x1) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 22, weight: .semibold))
                        Text(tab.title)
                            .font(TriType.small)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .dynamicTypeSize(.xSmall ... .large)
                    }
                    .foregroundStyle(tab == selectedTab ? TriPalette.sunrise : TriPalette.ink)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background {
                        if tab == selectedTab {
                            Capsule()
                                .fill(TriPalette.surfaceSunk)
                        }
                    }
                }
                .buttonStyle(.triPressSilent)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(tab == selectedTab ? [.isSelected] : [])
            }
        }
        .padding(TriSpace.x1)
        .background(TriPalette.surface, in: Capsule())
        .overlay {
            Capsule()
                .stroke(TriPalette.hairline, lineWidth: TriGeo.hairline)
        }
        .shadow(color: TriShadow.card(colorScheme).0,
                radius: TriShadow.card(colorScheme).1,
                y: TriShadow.card(colorScheme).2)
        .padding(.horizontal, TriSpace.x4)
        .padding(.top, TriSpace.x2)
        .padding(.bottom, TriSpace.x2)
        .background(TriPalette.canvas)
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
