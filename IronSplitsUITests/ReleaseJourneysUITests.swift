import XCTest

/// Release-gate journeys. The core loop is claiming an athlete and reading
/// their races and splits; it hits the live feed on purpose (see AGENTS.md).
@MainActor
final class ReleaseJourneysUITests: XCTestCase {
    private let athlete = "Daniel Winek"
    private let race = "IRONMAN Wisconsin"

    override func setUp() {
        continueAfterFailure = false
    }

    func testCoreLoopClaimAthleteReadSplitsSurvivesRelaunch() {
        let app = XCUIApplication()
        QA.launch(app, arguments: ["-UITest", "-ResetLocker"])

        let field = app.textFields["Your name as you registered"]
        XCTAssertTrue(field.waitForExistence(timeout: 20), "Onboarding search should be the first screen")
        QA.checkpoint(app, "search")
        field.tap()
        field.typeText(athlete)

        let match = app.staticTexts[athlete]
        if !match.waitForExistence(timeout: 30) {
            field.typeText(" ")
            field.typeText(XCUIKeyboardKey.delete.rawValue)
            XCTAssertTrue(match.waitForExistence(timeout: 30), "Search should return \(athlete)")
        }
        QA.checkpoint(app, "search-results")
        match.tap()

        assertLockerHasRace(app)
        QA.checkpoint(app, "locker")

        app.staticTexts[race].firstMatch.tap()
        assertSplits(app)
        QA.checkpoint(app, "race-detail")

        // Relaunch reuses the launch arguments; keeping -ResetLocker would wipe what we assert survived.
        app.launchArguments.removeAll { $0 == "-ResetLocker" }
        QA.relaunch(app)
        assertLockerHasRace(app)
        QA.checkpoint(app, "locker-after-relaunch")

        app.staticTexts[race].firstMatch.tap()
        assertSplits(app)
        QA.checkpoint(app, "race-detail-after-relaunch")
    }

    private func assertLockerHasRace(_ app: XCUIApplication, journey: String = #function) {
        XCTAssertTrue(app.staticTexts["FINISHES"].waitForExistence(timeout: 40),
                      "Claiming should fill the locker (\(journey))")
        XCTAssertTrue(app.buttons["Change athlete"].exists, "The claimed athlete should be changeable")
        XCTAssertTrue(app.staticTexts[race].firstMatch.waitForExistence(timeout: 15),
                      "The athlete's race should be listed")
    }

    private func assertSplits(_ app: XCUIApplication, journey: String = #function) {
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 20),
                      "Race detail should show splits (\(journey))")
        let leg = NSPredicate(format: "label CONTAINS[c] 'bike'")
        XCTAssertTrue(app.staticTexts.containing(leg).firstMatch.exists, "Splits should list the bike leg")
    }
}
