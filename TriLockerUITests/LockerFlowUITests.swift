import XCTest

/// Drives the real app end to end against the live results feed.
///
/// The claim flow is the one thing in this app that cannot be unit tested
/// honestly: it is a search against somebody else's OData service, and a mock
/// would only ever prove the mock still matches what I wrote down. This test
/// types a name, waits for real athletes to come back, claims one, and checks
/// that the locker fills in.
final class LockerFlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(forcePro: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest", "-ResetLocker"]
        if forcePro {
            app.launchEnvironment["FORCE_PRO"] = "1"
        }
        app.launch()
        return app
    }

    func testSearchClaimAndBrowseLocker() throws {
        let app = launch(forcePro: true)

        XCTAssertTrue(searchAndClaim(app, name: "Daniel Winek"), "Search should return the athlete")
        attachScreenshot(app, name: "1-search")

        let locker = app.navigationBars["Locker"]
        XCTAssertTrue(locker.waitForExistence(timeout: 30), "Claiming should open the locker")
        XCTAssertTrue(app.staticTexts["FINISHES"].waitForExistence(timeout: 10))
        attachScreenshot(app, name: "2-locker")

        // Race detail. Tapped by name rather than by cell index: the locker's
        // first cell is the athlete header card, and the kind picker adds
        // another for anyone who has raced more than one distance.
        let firstRace = app.staticTexts["IRONMAN Wisconsin"]
        XCTAssertTrue(firstRace.waitForExistence(timeout: 10))
        firstRace.tap()
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 15), "Race detail should show splits")
        attachScreenshot(app, name: "3-race-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Split leaderboards
        app.tabBars.buttons["Bests"].tap()
        XCTAssertTrue(app.navigationBars["Bests"].waitForExistence(timeout: 10))
        attachScreenshot(app, name: "4-bests")

        // Resume
        app.tabBars.buttons["Resume"].tap()
        XCTAssertTrue(app.navigationBars["Resume"].waitForExistence(timeout: 10))
        attachScreenshot(app, name: "5-resume")

        // Pointers
        app.tabBars.buttons["Pointers"].tap()
        attachScreenshot(app, name: "6-pointers")

        // Settings
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        attachScreenshot(app, name: "7-settings")
    }

    func testFreeTierShowsTheUpgradeRowInsteadOfEveryRace() throws {
        let app = launch()

        XCTAssertTrue(searchAndClaim(app, name: "Daniel Winek"), "Search should return the athlete")

        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 30))
        // Five results exist for this athlete and three are free, so the
        // locked row must be there.
        let locked = app.staticTexts["2 more races"]
        XCTAssertTrue(locked.waitForExistence(timeout: 15), "Free tier should truncate to three races")
        attachScreenshot(app, name: "8-free-tier")

        locked.tap()
        let paywallTitle = app.staticTexts["Unlock Every Race"]
        let opened = paywallTitle.waitForExistence(timeout: 15)
        attachScreenshot(app, name: "9-paywall")
        XCTAssertTrue(opened, "Locked row should open the paywall")
        // Products come from TriLocker.storekit under `xcodebuild test`, so the
        // real plan cards must render — not the "Couldn't Load Plans" state
        // that a simulator without StoreKit Testing would show.
        XCTAssertTrue(app.staticTexts["Yearly"].waitForExistence(timeout: 10), "Paywall should show real plans")
        attachScreenshot(app, name: "10-paywall-plans")
    }


    /// Type a name and wait for the athlete to come back, retrying once.
    ///
    /// This is a live request to a service that is not ours, back-to-back with
    /// the other test's. One slow response is not a regression in the app, and
    /// a suite that cries wolf about the network stops being read.
    @discardableResult
    private func searchAndClaim(_ app: XCUIApplication, name: String) -> Bool {
        let field = app.textFields["Your name as you registered"]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "Onboarding search should be the first screen")
        field.tap()
        field.typeText(name)

        let match = app.staticTexts[name]
        if !match.waitForExistence(timeout: 30) {
            // Nudge the debounce and give the feed one more go.
            field.typeText(" ")
            field.typeText(XCUIKeyboardKey.delete.rawValue)
            guard match.waitForExistence(timeout: 30) else { return false }
        }
        match.tap()
        return true
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
