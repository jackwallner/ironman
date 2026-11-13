import XCTest

/// iPad pass: every main screen, the paywall and onboarding, in portrait and
/// landscape, as named attachments. Skips on iPhone.
@MainActor
final class IPadLayoutUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait }

    func testPortrait() throws { try walk(.portrait, "portrait") }
    func testLandscape() throws { try walk(.landscapeLeft, "landscape") }

    private func walk(_ orientation: UIDeviceOrientation, _ tag: String) throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        let onboarding = XCUIApplication()
        onboarding.launchArguments = ["-UITest", "-ResetLocker", "-AuditLight"]
        onboarding.launch()
        rotate(to: orientation)
        XCTAssertTrue(onboarding.textFields["Your name as you registered"].waitForExistence(timeout: 20))
        shoot(onboarding, "\(tag)-onboarding")
        onboarding.terminate()

        let app = XCUIApplication()
        app.launchArguments = ["-UITest", "-ResetLocker", "-SeedScreenshotData", "-AuditLight"]
        app.launch()
        rotate(to: orientation)
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["FINISHES"].waitForExistence(timeout: 15))
        shoot(app, "\(tag)-locker")

        app.buttons["Rankings"].tap()
        XCTAssertTrue(app.staticTexts["FINISH RANKINGS"].waitForExistence(timeout: 10))
        shoot(app, "\(tag)-rankings")
        app.buttons["Run"].firstMatch.tap()
        shoot(app, "\(tag)-rankings-run")
        app.buttons["Races"].tap()

        // A second race, so the App Store frames are not the same screen twice.
        app.buttons["Half distance"].tap()
        let half = app.staticTexts["Lakeside Half Triathlon"].firstMatch
        XCTAssertTrue(half.waitForExistence(timeout: 10))
        half.tap()
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 20))
        _ = app.staticTexts["AGAINST THE FIELD"].waitForExistence(timeout: 15)
        shoot(app, "\(tag)-race-half")
        if !app.navigationBars["Locker"].exists, app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // Picks a race: pushes on a narrow Locker, fills the pane on a wide one.
        app.buttons["Full distance"].tap()
        let race = app.staticTexts["Coastline Triathlon"].firstMatch
        XCTAssertTrue(race.waitForExistence(timeout: 10))
        race.tap()
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 20))
        _ = app.staticTexts["AGAINST THE FIELD"].waitForExistence(timeout: 15)
        shoot(app, "\(tag)-race")
        if app.navigationBars.buttons.element(boundBy: 0).exists,
           !app.navigationBars["Locker"].exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        tab(app, "Race Book").tap()
        XCTAssertTrue(app.staticTexts["PERSONAL BESTS"].waitForExistence(timeout: 15))
        shoot(app, "\(tag)-racebook")
        let unlock = app.buttons["Unlock to export"]
        for _ in 0..<8 where !unlock.isHittable { app.swipeUp() }
        if unlock.waitForExistence(timeout: 5) {
            unlock.tap()
            XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 15))
            sleep(1)
            shoot(app, "\(tag)-paywall")
            app.buttons["Close"].tap()
        }

        tab(app, "Explore").tap()
        XCTAssertTrue(app.staticTexts["RECENTLY EXPLORED"].waitForExistence(timeout: 15))
        shoot(app, "\(tag)-explore")
        app.staticTexts["Riley Brooks"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["RACE HISTORY"].waitForExistence(timeout: 15))
        shoot(app, "\(tag)-explore-athlete")

        tab(app, "Tips").tap()
        XCTAssertTrue(app.navigationBars["Tips"].waitForExistence(timeout: 15))
        shoot(app, "\(tag)-tips")

        tab(app, "Settings").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        shoot(app, "\(tag)-settings")
    }

    /// The iPad tab bar floats at the top and is not always a `tabBars` member.
    private func tab(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        let bar = app.tabBars.buttons[title]
        return bar.exists ? bar : app.buttons[title].firstMatch
    }

    private func rotate(to orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        sleep(3)
    }

    private func shoot(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
