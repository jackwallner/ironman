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
        app.launchArguments = ["-UITest", "-ResetLocker", "-AuditLight"]
        app.launchEnvironment["FORCE_PRO"] = "1"
        app.launch()

        let field = app.textFields["Your name as you registered"]
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        field.tap()
        field.typeText("Daniel Winek")

        let match = app.staticTexts["Daniel Winek"]
        if !match.waitForExistence(timeout: 35) {
            field.typeText(" ")
            field.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        XCTAssertTrue(match.waitForExistence(timeout: 35))
        match.tap()

        let locker = app.navigationBars["Locker"]
        XCTAssertTrue(locker.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["FINISHES"].waitForExistence(timeout: 15))
        capture(app, named: "locker")

        let firstRace = app.staticTexts["IRONMAN Wisconsin"]
        XCTAssertTrue(firstRace.waitForExistence(timeout: 15))
        firstRace.tap()
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 20))
        capture(app, named: "race-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["Bests"].tap()
        XCTAssertTrue(app.navigationBars["Bests"].waitForExistence(timeout: 15))
        capture(app, named: "bests")

        app.tabBars.buttons["Resume"].tap()
        XCTAssertTrue(app.navigationBars["Resume"].waitForExistence(timeout: 15))
        let openRaceBook = app.buttons["Open Race Book"]
        XCTAssertTrue(openRaceBook.waitForExistence(timeout: 15))
        openRaceBook.tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["PERSONAL BESTS"].waitForExistence(timeout: 15))
        capture(app, named: "race-book")

        let compare = app.buttons["Compare two races"]
        scrollToHittable(compare, in: app)
        XCTAssertTrue(compare.isHittable)
        compare.tap()
        XCTAssertTrue(app.navigationBars["Compare races"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["TIME BY LEG"].waitForExistence(timeout: 15))
        capture(app, named: "race-book-compare")
        app.navigationBars["Compare races"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 15))

        let export = app.buttons["Build PDF and image"]
        scrollToHittable(export, in: app)
        XCTAssertTrue(export.isHittable)
        capture(app, named: "race-book-export")

        app.navigationBars["Race Book"].buttons["Done"].tap()

        app.tabBars.buttons["Pattie"].tap()
        XCTAssertTrue(app.staticTexts["WHAT ARE YOU TRAINING FOR?"].waitForExistence(timeout: 15))
        capture(app, named: "pattie")

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        capture(app, named: "settings")
    }

    private func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !element.isHittable {
            app.swipeUp()
        }
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(name).png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
