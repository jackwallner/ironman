import SwiftUI

@main
struct TriLockerApp: App {
    @StateObject private var locker = LockerStore()
    @StateObject private var store = StoreService.shared
    @StateObject private var notes = RaceNotesStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var reviewCoordinator = ReviewPromptCoordinator.shared

    init() {
        #if DEBUG
        // UI tests share one installed app, so a test that claims an athlete
        // would otherwise decide what the next test's first screen is. Launch
        // with `-ResetLocker` to start from a clean install.
        if ProcessInfo.processInfo.arguments.contains("-ResetLocker") {
            LockerStorage().clear()
            for key in ["settings.hasCompletedOnboarding", "settings.preferredKind",
                        "feed.config.cached", "feed.config.cachedAt",
                        "pointers.catalog.cached", "pointers.catalog.cachedAt"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        #endif
        ReviewPromptTracker.recordAppLaunch()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(locker)
                .environmentObject(store)
                .environmentObject(notes)
                .environmentObject(settings)
                .environmentObject(reviewCoordinator)
                .task {
                    store.start()
                    await FeedConfigLoader.shared.refreshIfStale()
                }
        }
    }
}
