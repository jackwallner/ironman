import XCTest

/// Temporary demo-drive: claims Pattie Wallner and screenshots every surface.
@MainActor
final class PattieWallnerSmokeUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func testPattieWallnerLocker() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest", "-ResetLocker"]
        app.launchEnvironment["FORCE_PRO"] = "1"
        app.launchEnvironment["IRONSPLITS_FORCE_PRO"] = "1"
        app.launch()

        let field = app.textFields["Your name as you registered"]
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        field.tap()
        field.typeText("Pattie Wallner")
        shoot(app, "01-typed")

        let match = app.staticTexts["Pattie Wallner"].firstMatch
        if !match.waitForExistence(timeout: 30) {
            field.typeText(" ")
            field.typeText(XCUIKeyboardKey.delete.rawValue)
            XCTAssertTrue(match.waitForExistence(timeout: 30), "Pattie should come back from the feed")
        }
        shoot(app, "02-search-results")
        // The merge has to leave exactly one Pattie: two rows means the feed's
        // split contact records leaked back into search.
        XCTAssertEqual(app.staticTexts.matching(identifier: "Pattie Wallner").count, 1,
                       "Pattie's two contact records should collapse to one athlete")
        match.tap()

        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["FINISHES"].waitForExistence(timeout: 15))
        shoot(app, "03-locker-top")

        app.swipeUp(); shoot(app, "04-locker-scrolled")
        app.swipeUp(); shoot(app, "05-locker-scrolled2")

        for (tab, name) in [("Bests", "06-bests"), ("Pattie", "07-ask-pattie"),
                            ("Resume", "08-resume"), ("Settings", "09-settings")] {
            app.tabBars.buttons[tab].tap()
            _ = app.navigationBars[tab].waitForExistence(timeout: 15)
            sleepBriefly()
            shoot(app, name)
        }
        app.swipeUp(); shoot(app, "10-settings-scrolled")
    }

    private func sleepBriefly() {
        _ = XCTWaiter.wait(for: [expectation(description: "settle")], timeout: 2.5)
    }

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
