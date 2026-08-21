import SwiftUI

@main
struct IronSplitsApp: App {
    @StateObject private var locker = LockerStore()
    @StateObject private var store = StoreService.shared
    @StateObject private var notes = RaceNotesStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var reviewCoordinator = ReviewPromptCoordinator.shared
    @StateObject private var pattie = PattieMode()

    private var auditColorScheme: ColorScheme? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-AuditDark") { return .dark }
        if ProcessInfo.processInfo.arguments.contains("-AuditLight") { return .light }
        return nil
        #else
        return nil
        #endif
    }

    init() {
        #if DEBUG
        // UI tests share one installed app, so a test that claims an athlete
        // would otherwise decide what the next test's first screen is. Launch
        // with `-ResetLocker` to start from a clean install.
        if ProcessInfo.processInfo.arguments.contains("-ResetLocker") {
            LockerStorage().clear()
            for key in ["settings.hasCompletedOnboarding", "settings.preferredKind",
                        "feed.config.cached", "feed.config.cachedAt",
                        "pointers.catalog.cached", "pointers.catalog.cachedAt",
                        "pointers.mode",
                        "askpattie.guide.cached", "askpattie.guide.cachedAt",
                        "pattie.mode.enabled", "pattie.mode.seenLines"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            // Pattie Mode ships on, and a card that slides over the tab bar
            // eats the tap a UI test was aiming at. Tests opt in with
            // `-PattieMode` instead of fighting an overlay they did not ask
            // for; `PattieModeUITests` is the one that does.
            UserDefaults.standard.set(
                ProcessInfo.processInfo.arguments.contains("-PattieMode"),
                forKey: "pattie.mode.enabled"
            )
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
                .environmentObject(pattie)
                .preferredColorScheme(auditColorScheme)
                .task {
                    store.start()
                    // Warm the audio session off the main thread now, so
                    // Pattie's first line does not pay for it inside the first
                    // frame the app draws.
                    PattieVoice.prepareSession()
                    await FeedConfigLoader.shared.refreshIfStale()
                }
        }
    }
}
