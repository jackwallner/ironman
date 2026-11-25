import XCTest
@testable import IM_Iron_Splits

/// The star prompt: when Apple's rating prompt may be called, and the good
/// moments that call it.
@MainActor
final class ReviewPromptTests: XCTestCase {
    private let keys = ["reviewPrompt.appLaunchCount", "reviewPrompt.firstAppOpenDate",
                        "reviewPrompt.lastShownDate", "reviewPrompt.outcome"]
    private var saved: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        saved = [:]
        for key in keys {
            if let value = UserDefaults.standard.object(forKey: key) { saved[key] = value }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in keys {
            if let value = saved[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    // MARK: Gates

    func testFirstLaunchNeverAsksAndSecondLaunchMay() {
        ReviewPromptTracker.recordAppLaunch(now: now)
        XCTAssertFalse(ReviewPromptTracker.shouldRequestReview(now: now))
        ReviewPromptTracker.recordAppLaunch(now: now)
        XCTAssertTrue(ReviewPromptTracker.shouldRequestReview(now: now))
    }

    func testThirtyDayCooldownIsStampedByTheCall() {
        ReviewPromptTracker.appLaunchCount = 2
        ReviewPromptTracker.markShown(now: now)
        XCTAssertFalse(ReviewPromptTracker.shouldRequestReview(now: now.addingTimeInterval(29 * 86_400)))
        XCTAssertTrue(ReviewPromptTracker.shouldRequestReview(now: now.addingTimeInterval(30 * 86_400)))
    }

    func testAStampFromTheFutureDoesNotHoldTheCooldownShut() {
        ReviewPromptTracker.appLaunchCount = 2
        ReviewPromptTracker.markShown(now: now.addingTimeInterval(400 * 86_400))
        XCTAssertTrue(ReviewPromptTracker.shouldRequestReview(now: now))
    }

    func testOpeningTheWriteReviewPageEndsTheAsks() {
        ReviewPromptTracker.appLaunchCount = 5
        ReviewPromptTracker.markOpenedWriteReview(now: now)
        XCTAssertFalse(ReviewPromptTracker.shouldRequestReview(now: now.addingTimeInterval(400 * 86_400)))
    }

    func testSendingFeedbackNeverEndsOrDelaysTheAsks() {
        ReviewPromptTracker.appLaunchCount = 2
        ReviewPromptTracker.markFeedbackDraftOpened()
        XCTAssertTrue(ReviewPromptTracker.shouldRequestReview(now: now))
        XCTAssertNil(ReviewPromptTracker.lastShownDate)
    }

    func testFeedbackAfterAReviewKeepsTheAsksEnded() {
        ReviewPromptTracker.appLaunchCount = 2
        ReviewPromptTracker.markOpenedWriteReview(now: now)
        ReviewPromptTracker.markFeedbackDraftOpened()
        XCTAssertEqual(ReviewPromptTracker.outcome, .openedWriteReview)
        XCTAssertFalse(ReviewPromptTracker.shouldRequestReview(now: now.addingTimeInterval(400 * 86_400)))
    }

    /// Installs from the old funnel keep their counts and their write-review,
    /// and the old feedback outcomes no longer block the prompt.
    func testUpgradeKeepsStoredStateUnderTheSameKeys() {
        UserDefaults.standard.set(7, forKey: "reviewPrompt.appLaunchCount")
        UserDefaults.standard.set("submittedFeedback", forKey: "reviewPrompt.outcome")
        XCTAssertEqual(ReviewPromptTracker.appLaunchCount, 7)
        XCTAssertTrue(ReviewPromptTracker.shouldRequestReview(now: now))

        UserDefaults.standard.set("feedbackDraftOpened", forKey: "reviewPrompt.outcome")
        XCTAssertTrue(ReviewPromptTracker.shouldRequestReview(now: now))

        UserDefaults.standard.set("openedWriteReview", forKey: "reviewPrompt.outcome")
        XCTAssertFalse(ReviewPromptTracker.shouldRequestReview(now: now))

        UserDefaults.standard.removeObject(forKey: "reviewPrompt.outcome")
        UserDefaults.standard.set(now.addingTimeInterval(-10 * 86_400), forKey: "reviewPrompt.lastShownDate")
        XCTAssertFalse(ReviewPromptTracker.shouldRequestReview(now: now), "an ask ten days ago still counts")
    }

    // MARK: The good moment

    func testAPersonalBestFinishIsTheMoment() {
        let earlier = Self.race(id: "earlier", date: "2024-09-08T00:00:00Z", swim: 3_900, bike: 18_600, run: 15_600, finish: 39_000)
        let best = Self.race(id: "best", date: "2025-09-07T00:00:00Z", swim: 3_700, bike: 17_800, run: 14_700, finish: 37_000)
        XCTAssertTrue(ReviewPromptTracker.isPositiveMoment(result: best, isReadOnly: false, within: [earlier, best]))
    }

    func testADNFIsNotTheMoment() {
        let best = Self.race(id: "best", date: "2024-09-08T00:00:00Z", swim: 3_700, bike: 17_800, run: 14_700, finish: 37_000)
        let dnf = Self.race(id: "dnf", date: "2026-06-01T00:00:00Z", swim: 3_600, bike: 17_000, run: nil, finish: nil,
                            finisher: false, dnf: true)
        XCTAssertFalse(dnf.isComplete, "precondition: the DNF is not a completed race")
        XCTAssertFalse(ReviewPromptTracker.isPositiveMoment(result: dnf, isReadOnly: false, within: [best, dnf]))
    }

    /// The frequent moment: any completed race of their own, PB or not.
    func testOpeningAnyOwnFinishIsTheMoment() {
        let best = Self.race(id: "best", date: "2024-09-08T00:00:00Z", swim: 3_700, bike: 17_800, run: 14_700, finish: 37_000)
        let slower = Self.race(id: "slower", date: "2025-09-07T00:00:00Z", swim: 3_900, bike: 18_600, run: 15_600, finish: 39_000)
        let all = [best, slower]
        XCTAssertFalse(ReviewPromptTracker.isPersonalBestOpened(result: slower, isReadOnly: false, within: all),
                       "precondition: the slower race is nobody's best")
        XCTAssertTrue(ReviewPromptTracker.isPositiveMoment(result: slower, isReadOnly: false, within: all))
    }

    func testAnOnlyFinishIsTheMomentButNotAPersonalBest() {
        let only = Self.race(id: "only", date: "2025-09-07T00:00:00Z", swim: 3_700, bike: 17_800, run: 14_700, finish: 37_000)
        XCTAssertTrue(ReviewPromptTracker.isOwnFinishOpened(result: only, isReadOnly: false))
        XCTAssertFalse(ReviewPromptTracker.isPersonalBestOpened(result: only, isReadOnly: false, within: [only]))
        XCTAssertTrue(ReviewPromptTracker.isPositiveMoment(result: only, isReadOnly: false, within: [only]))
    }

    func testAnotherRacersBestIsNotTheMoment() {
        let earlier = Self.race(id: "earlier", date: "2024-09-08T00:00:00Z", swim: 3_900, bike: 18_600, run: 15_600, finish: 39_000)
        let best = Self.race(id: "best", date: "2025-09-07T00:00:00Z", swim: 3_700, bike: 17_800, run: 14_700, finish: 37_000)
        XCTAssertFalse(ReviewPromptTracker.isPositiveMoment(result: best, isReadOnly: true, within: [earlier, best]))
    }

    func testATransitionBestAloneIsNotTheMoment() {
        let faster = Self.race(id: "faster", date: "2024-09-08T00:00:00Z", swim: 3_700, bike: 17_800, run: 14_700,
                               finish: 37_000, t1: 400, t2: 300)
        let slowerWithQuickTransitions = Self.race(id: "quickT", date: "2025-09-07T00:00:00Z", swim: 3_900, bike: 18_600,
                                                   run: 15_600, finish: 38_500, t1: 200, t2: 150)
        let all = [faster, slowerWithQuickTransitions]
        XCTAssertTrue(RaceAnalytics.isPersonalBest(slowerWithQuickTransitions, discipline: .transitions, within: all),
                      "precondition: it is the transition best")
        XCTAssertFalse(ReviewPromptTracker.isPersonalBestOpened(result: slowerWithQuickTransitions, isReadOnly: false, within: all))
    }

    // MARK: Fixtures

    static func race(id: String, date: String, swim: Int?, bike: Int?, run: Int?, finish: Int?,
                     t1: Int? = nil, t2: Int? = nil, finisher: Bool = true, dnf: Bool = false) -> RaceResult {
        func json(_ value: Int?) -> String { value.map(String.init) ?? "null" }
        return ODataResultRow.decode("""
        {
          "wtc_resultid": "\(id)",
          "wtc_swimtime": \(json(swim)),
          "wtc_transition1time": \(json(t1)),
          "wtc_biketime": \(json(bike)),
          "wtc_transition2time": \(json(t2)),
          "wtc_runtime": \(json(run)),
          "wtc_finishtime": \(json(finish)),
          "wtc_bikedistancecompleted": 180,
          "wtc_rundistancecompleted": 42.2,
          "wtc_finisher": \(finisher),
          "wtc_dnf": \(dnf),
          "wtc_EventId": { "wtc_name": "\(date.prefix(4)) IRONMAN Wisconsin", "wtc_eventdate": "\(date)" },
          "wtc_ContactId": { "contactid": "athlete", "fullname": "Test Athlete" }
        }
        """).result
    }
}
