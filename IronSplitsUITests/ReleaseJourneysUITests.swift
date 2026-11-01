import XCTest

/// The release gate's journeys (`qa-gate run`): first run to a filled Locker,
/// a race's splits, the Race Book paywall shown and closed, and a return visit
/// with an interruption. Each step ends in `QA.checkpoint`, which runs the fleet
/// oracles on whatever is on screen. Assert reachability only.
@MainActor
final class ReleaseJourneysUITests: XCTestCase {

    private static let bundle = "com.jackwallner.ironman"
    private static let seeded = ["-UITest", "-ResetLocker", "-SeedScreenshotData"]

    override func setUp() {
        continueAfterFailure = false
    }

    /// The claim search is a live request to the results feed, so a slow
    /// response ends the journey at the search screen rather than failing it.
    func test01FirstRunClaimsAnAthlete() {
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, arguments: ["-UITest", "-ResetLocker"])
        let field = app.textFields["Your name as you registered"]
        XCTAssertTrue(field.waitForExistence(timeout: 20), "claim search never rendered")
        QA.checkpoint(app, "claim-search")

        field.tap()
        field.typeText("Daniel Winek")
        let match = app.staticTexts["Daniel Winek"]
        guard match.waitForExistence(timeout: 45) else { return }
        QA.checkpoint(app, "claim-results")

        match.tap()
        guard app.navigationBars["Locker"].waitForExistence(timeout: 45) else { return }
        QA.checkpoint(app, "first-locker")
    }

    func test02LockerRaceAndRankings() {
        let app = launchSeeded()
        QA.checkpoint(app, "locker")

        let race = app.staticTexts["Riverbend Triathlon"].firstMatch
        XCTAssertTrue(race.waitForExistence(timeout: 15))
        race.tap()
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 20))
        QA.checkpoint(app, "race-detail")

        // Unfolded, the race opens in the pane beside the Locker; there is
        // nothing to go back from.
        let back = app.navigationBars.buttons["Back"].firstMatch
        if back.exists {
            back.tap()
            // The list keeps its scroll position, so at large text the header
            // card (and its FINISHES caption) can be scrolled out of the tree.
            XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 15), "back at the Locker")
        }
        // The chips sit at the top of the list, which can be scrolled past
        // them at large text sizes.
        let rankings = app.buttons["Rankings"].firstMatch
        var scrolls = 0
        while !(rankings.exists && rankings.isHittable) && scrolls < 6 {
            QA.swipe(app.windows.firstMatch, .down)
            scrolls += 1
        }
        XCTAssertTrue(rankings.waitForExistence(timeout: 15))
        rankings.tap()
        XCTAssertTrue(app.staticTexts["FINISH RANKINGS"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "rankings")
    }

    func test03RaceBookPaywallShownAndClosed() {
        let app = launchSeeded()
        tapTab("Race Book", in: app)
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "race-book")

        let unlock = app.buttons["Unlock to export"]
        for _ in 0..<10 where !(unlock.exists && unlock.isHittable) {
            QA.swipe(app.windows.firstMatch, .up)
        }
        XCTAssertTrue(unlock.waitForExistence(timeout: 10))
        unlock.tap()
        XCTAssertTrue(app.staticTexts["Share your Race Book"].waitForExistence(timeout: 20))
        QA.checkpoint(app, "race-book-paywall", paywall: true)

        app.buttons["Close"].tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "race-book-after-paywall", paywall: false)
    }

    func test04ReturnVisitWithInterruption() {
        let app = launchSeeded()
        tapTab("Explore", in: app)
        XCTAssertTrue(app.staticTexts["RECENTLY EXPLORED"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "explore")

        tapTab("Tips", in: app)
        XCTAssertTrue(app.navigationBars["Tips"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "tips")

        tapTab("Settings", in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "settings")

        QA.interrupt(app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "settings-after-interruption")

        QA.relaunch(app)
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 20))
        QA.checkpoint(app, "locker-after-relaunch")
    }

    /// Core loop: the Locker holds the 2025 Riverbend finish, its race opens
    /// with the real finish time, splits and field, and the same Locker, race
    /// and field are there after the app is killed and reopened without the seed.
    func testCoreLoopLockerRaceSurvivesRelaunch() {
        let app = launchSeeded()
        openRiverbend(in: app)
        assertRiverbendFinish(in: app)
        QA.checkpoint(app, "race-detail")

        // Reopen as a returning user: no reset, no seed, persona arguments kept.
        app.launchArguments.removeAll { $0 == "-ResetLocker" || $0 == "-SeedScreenshotData" }
        QA.relaunch(app)
        XCTAssertTrue(app.staticTexts["Riverbend Triathlon"].firstMatch.waitForExistence(timeout: 25),
                      "the claimed Locker after relaunch")
        let back = app.navigationBars.buttons["Back"].firstMatch
        if back.exists { back.tap() }
        openRiverbend(in: app)
        assertRiverbendFinish(in: app)
        QA.checkpoint(app, "race-detail-after-relaunch")
    }


    private func assertRiverbendFinish(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["10:11:12"].firstMatch.waitForExistence(timeout: 10), "the finish time")
        XCTAssertTrue(app.staticTexts["59:50"].firstMatch.exists, "the swim split")
        XCTAssertTrue(app.staticTexts["37 finishers"].waitForExistence(timeout: 20), "the field beside the finish")
        XCTAssertFalse(app.buttons["Couldn't load the field. Try again."].exists, "the field failed to load")
    }

    private func openRiverbend(in app: XCUIApplication) {
        let race = app.staticTexts["Riverbend Triathlon"].firstMatch
        XCTAssertTrue(race.waitForExistence(timeout: 15), "Riverbend in the Locker")
        race.tap()
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 20), "Riverbend's splits")
    }

    /// Folded, a system tab bar; unfolded, the leading pane's own bar, which is
    /// not a `tabBars` element. A tap can miss there, so retry with a press.
    private func tapTab(_ label: String, in app: XCUIApplication) {
        let button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15), "\(label) tab")
        button.tap()
        let selected = NSPredicate(format: "isSelected == true")
        if XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: selected, object: button)], timeout: 3) != .completed {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.05)
        }
    }

    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, arguments: Self.seeded)
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 25), "seeded Locker never rendered")
        XCTAssertTrue(app.staticTexts["FINISHES"].waitForExistence(timeout: 15))
        return app
    }
}
