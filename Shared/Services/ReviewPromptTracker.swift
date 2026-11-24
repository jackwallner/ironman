import Foundation

/// What the athlete did about a review. Only opening the write-review page
/// ends the passive asks: someone who sent feedback can still rate later.
enum ReviewPromptOutcome: String, Sendable {
    case openedWriteReview
    /// Written by builds before 1.2.1's star prompt change. Kept so those
    /// installs decode it; it no longer stops anything.
    case submittedFeedback
    case feedbackDraftOpened
}

/// When the app may call Apple's own rating prompt.
///
/// No question goes in front of it (an "Enjoying it?" step got 1.1.2 rejected
/// under 5.6.1). The only automatic trigger is a good moment: the athlete
/// opening one of their own finishes that is a personal best for its
/// distance. From the second cold launch on, at most once every 30 days.
/// Apple shows the prompt at most three times a year and decides each time;
/// a call it swallows costs nothing.
@MainActor
enum ReviewPromptTracker {
    private static let defaults = UserDefaults.standard

    // Same keys as the old funnel, so an upgrade keeps its launch count, its
    // last ask and a write-review that already happened.
    private enum Keys {
        static let launchCount = "reviewPrompt.appLaunchCount"
        static let firstOpen = "reviewPrompt.firstAppOpenDate"
        static let lastShown = "reviewPrompt.lastShownDate"
        static let outcome = "reviewPrompt.outcome"
    }

    /// Not in the first session: a second cold start is the only tenure gate.
    static let minimumLaunchCount = 2
    /// Days between our calls. Paces the asks, not the athlete's answers.
    static let cooldownDays = 30
    /// How long the good moment gets on screen before the prompt can land.
    static let delaySeconds: Double = 3

    /// The legs a personal best counts on. A transition best is real but is
    /// not a race anyone feels good about by itself.
    static let momentDisciplines: [Discipline] = [.finish, .swim, .bike, .run]

    static var appLaunchCount: Int {
        get { max(defaults.integer(forKey: Keys.launchCount), 0) }
        set { defaults.set(newValue, forKey: Keys.launchCount) }
    }

    static var outcome: ReviewPromptOutcome? {
        get { defaults.string(forKey: Keys.outcome).flatMap(ReviewPromptOutcome.init(rawValue:)) }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Keys.outcome)
            } else {
                defaults.removeObject(forKey: Keys.outcome)
            }
        }
    }

    static var lastShownDate: Date? {
        get { defaults.object(forKey: Keys.lastShown) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Keys.lastShown)
            } else {
                defaults.removeObject(forKey: Keys.lastShown)
            }
        }
    }

    /// Skip passive prompts during UI tests / Fastlane snapshot runs.
    static var isAutomationRun: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-UITest")
            || ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT")
            || ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] == "1"
        #else
        return false
        #endif
    }

    /// The good moment: one of the athlete's own finishes, opened, that is a
    /// personal best on the finish, swim, bike or run for its distance (with
    /// at least two races of that distance to beat). Another racer's career,
    /// a DNF, or a race that is nobody's best never asks.
    static func isPositiveMoment(result: RaceResult,
                                 isReadOnly: Bool,
                                 within results: [RaceResult]) -> Bool {
        guard !isReadOnly, result.isComplete else { return false }
        return momentDisciplines.contains {
            RaceAnalytics.isPersonalBest(result, discipline: $0, within: results)
        }
    }

    static func recordAppLaunch(now: Date = .now) {
        if defaults.object(forKey: Keys.firstOpen) == nil {
            defaults.set(now, forKey: Keys.firstOpen)
        }
        appLaunchCount += 1
    }

    /// Whether a good moment right now may call `requestReview()`.
    static func shouldRequestReview(now: Date = .now) -> Bool {
        guard !isAutomationRun else { return false }
        guard outcome != .openedWriteReview else { return false }
        guard appLaunchCount >= minimumLaunchCount else { return false }
        // A stamp from a clock that ran ahead is in the future: it is no
        // evidence of an ask, and would hold the cooldown shut for as long.
        guard let last = lastShownDate, last <= now else { return true }
        return now.timeIntervalSince(last) >= TimeInterval(cooldownDays) * 86_400
    }

    /// Recorded when the call is made: Apple may show nothing, and there is
    /// no answer to wait for.
    static func markShown(now: Date = .now) {
        lastShownDate = now
    }

    /// Settings > Write a review. The one thing that ends the asks.
    static func markOpenedWriteReview(now: Date = .now) {
        outcome = .openedWriteReview
        markShown(now: now)
    }

    /// Feedback is its own path and never ends or delays the asks. It also
    /// never overwrites a write-review that already ended them.
    static func markFeedbackDraftOpened() {
        guard outcome != .openedWriteReview else { return }
        outcome = .feedbackDraftOpened
    }
}
