import XCTest

/// Canonical App Store screenshot capture for the editable App Store version.
///
/// This stays as a separate test so the shared shotflow adapter can run the
/// real claim flow and export named XCTest attachments without adding capture
/// state or preview-only UI to the app target.
@MainActor
final class ASCReleaseCaptureUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testCaptureRaceBookScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITest", "-ResetLocker", "-SeedScreenshotData", "-AuditLight"]
        app.launch()

        let locker = app.navigationBars["Locker"]
        XCTAssertTrue(locker.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["FINISHES"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.textFields["Search races"].exists)
        capture(app, named: "locker")

        app.buttons["Rankings"].tap()
        XCTAssertTrue(app.staticTexts["FINISH RANKINGS"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["2025 · Full"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["2,025 · Full"].exists)
        capture(app, named: "rankings")

        let firstRace = app.staticTexts["Riverbend Triathlon"].firstMatch
        XCTAssertTrue(firstRace.waitForExistence(timeout: 15))
        firstRace.tap()
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 20))
        let fieldHeading = app.staticTexts["AGAINST THE FIELD"]
        XCTAssertTrue(fieldHeading.waitForExistence(timeout: 15))
        let firstFieldPlacement = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS '8 of 11 finishers'"))
            .firstMatch
        XCTAssertTrue(firstFieldPlacement.waitForExistence(timeout: 10))
        if !fieldHeading.isHittable {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        if !firstFieldPlacement.isHittable {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.73))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTAssertTrue(app.staticTexts["SPLITS"].isHittable)
        XCTAssertTrue(fieldHeading.isHittable)
        XCTAssertTrue(firstFieldPlacement.isHittable)
        capture(app, named: "race-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["Race Book"].tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["PERSONAL BESTS"].waitForExistence(timeout: 15))
        capture(app, named: "race-book")

        app.tabBars.buttons["Explore"].tap()
        XCTAssertTrue(app.staticTexts["RECENTLY EXPLORED"].waitForExistence(timeout: 15))
        let recentAthlete = app.staticTexts["Riley Example"].firstMatch
        XCTAssertTrue(recentAthlete.waitForExistence(timeout: 10))
        recentAthlete.tap()
        XCTAssertTrue(app.staticTexts["RACE HISTORY"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Canyon Ridge Triathlon"].firstMatch.exists)
        capture(app, named: "explore")

        app.tabBars.buttons["Locker"].tap()
        XCTAssertTrue(app.staticTexts["Alex Runner"].waitForExistence(timeout: 10))

        app.tabBars.buttons["Tips"].tap()
        XCTAssertTrue(app.navigationBars["Tips"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Want Pattie along for the ride?"].waitForExistence(timeout: 10))
        capture(app, named: "pattie")

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        capture(app, named: "settings")
    }

    func testLockerRaceSearchFiltersAndClears() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITest", "-ResetLocker", "-SeedScreenshotData", "-AuditLight"]
        app.launch()

        let raceSearch = app.textFields["Search races"]
        XCTAssertTrue(raceSearch.waitForExistence(timeout: 20))
        raceSearch.tap()
        raceSearch.typeText("Coastline")

        XCTAssertTrue(app.staticTexts["Coastline Triathlon"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Riverbend Triathlon"].exists)

        app.buttons["Clear race search"].tap()
        XCTAssertTrue(app.staticTexts["Riverbend Triathlon"].firstMatch.waitForExistence(timeout: 10))
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
