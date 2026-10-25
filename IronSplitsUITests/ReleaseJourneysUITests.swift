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

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let rankings = app.buttons["Rankings"]
        XCTAssertTrue(rankings.waitForExistence(timeout: 15))
        rankings.tap()
        XCTAssertTrue(app.staticTexts["FINISH RANKINGS"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "rankings")
    }

    func test03RaceBookPaywallShownAndClosed() {
        let app = launchSeeded()
        app.tabBars.buttons["Race Book"].tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "race-book")

        let unlock = app.buttons["Unlock to export"]
        for _ in 0..<10 where !(unlock.exists && unlock.isHittable) {
            app.swipeUp()
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
        app.tabBars.buttons["Explore"].tap()
        XCTAssertTrue(app.staticTexts["RECENTLY EXPLORED"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "explore")

        app.tabBars.buttons["Tips"].tap()
        XCTAssertTrue(app.navigationBars["Tips"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "tips")

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "settings")

        QA.interrupt(app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "settings-after-interruption")

        QA.relaunch(app)
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 20))
        QA.checkpoint(app, "locker-after-relaunch")
    }

    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, arguments: Self.seeded)
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 25), "seeded Locker never rendered")
        XCTAssertTrue(app.staticTexts["FINISHES"].waitForExistence(timeout: 15))
        return app
    }
}
