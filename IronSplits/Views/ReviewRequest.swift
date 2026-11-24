import StoreKit
import SwiftUI
import UIKit

extension View {
    /// Calls Apple's rating prompt a few seconds after a good moment, with no
    /// question in front of it. Bump `moment` when the moment happens.
    ///
    /// `isClear` is checked again when the wait is over, together with any
    /// sheet, alert or cover on screen, so the prompt never lands on top of
    /// something the athlete opened in the meantime; the view leaving the
    /// screen cancels it too. A skipped moment just lets the next one ask.
    func requestsReview(after moment: Int, isClear: @escaping () -> Bool = { true }) -> some View {
        modifier(ReviewRequestModifier(moment: moment, isClear: isClear))
    }
}

private struct ReviewRequestModifier: ViewModifier {
    let moment: Int
    let isClear: () -> Bool

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.requestReview) private var requestReview
    @State private var onScreen = false

    func body(content: Content) -> some View {
        content
            .onAppear { onScreen = true }
            .onDisappear { onScreen = false }
            .onChange(of: moment) { _, _ in schedule() }
    }

    private func schedule() {
        // Never inside onboarding, and never in the first session.
        guard settings.hasCompletedOnboarding, ReviewPromptTracker.shouldRequestReview() else { return }
        Task { @MainActor in
            // Let the result land first.
            try? await Task.sleep(for: .seconds(ReviewPromptTracker.delaySeconds))
            guard onScreen, isClear(), !ReviewRequestScreen.isPresentingOverApp,
                  ReviewPromptTracker.shouldRequestReview() else { return }
            ReviewPromptTracker.markShown()
            requestReview()
        }
    }
}

@MainActor
enum ReviewRequestScreen {
    /// True while any window has a sheet, alert, full-screen cover or the
    /// paywall presented over it.
    static var isPresentingOverApp: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .contains { $0.rootViewController?.presentedViewController != nil }
    }
}
