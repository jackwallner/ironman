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
        capture(app, named: "locker")

        app.buttons["Rankings"].tap()
        XCTAssertTrue(app.staticTexts["FINISH RANKINGS"].waitForExistence(timeout: 10))
        capture(app, named: "rankings")

        let firstRace = app.staticTexts["Riverbend Triathlon"].firstMatch
        XCTAssertTrue(firstRace.waitForExistence(timeout: 15))
        firstRace.tap()
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 20))
        capture(app, named: "race-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["Race Book"].tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["PERSONAL BESTS"].waitForExistence(timeout: 15))
        capture(app, named: "race-book")

        app.tabBars.buttons["Explore"].tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Find a racer"].waitForExistence(timeout: 10))
        capture(app, named: "explore")

        app.tabBars.buttons["Tips"].tap()
        XCTAssertTrue(app.navigationBars["Tips"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Want Pattie along for the ride?"].waitForExistence(timeout: 10))
        capture(app, named: "pattie")

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        capture(app, named: "settings")
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
