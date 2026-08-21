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

        // Pattie: Ask Pattie, then the episode library behind the same tab.
        app.tabBars.buttons["Pattie"].tap()
        XCTAssertTrue(app.staticTexts["WHAT ARE YOU TRAINING FOR?"].waitForExistence(timeout: 10),
                      "The Pattie tab should open on the Ask Pattie tree")
        attachScreenshot(app, name: "6-ask-pattie")

        // Settings
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        attachScreenshot(app, name: "7-settings")
    }

    /// Nothing in the app is gated: `ProGate.everythingUnlocked` is set.
    ///
    /// This test used to assert the opposite, that a free athlete saw three
    /// races and a "2 more races" row that opened the paywall. It is inverted
    /// rather than deleted, because the thing worth pinning is the same either
    /// way: whatever `ProGate` says, the locker has to agree with it. If the
    /// flag ever goes back, this is the test that has to be flipped again, and
    /// it will fail loudly rather than silently pass.
    func testEverythingIsUnlockedWithNoPurchase() throws {
        // No FORCE_PRO: this is a plain launch with no entitlement at all.
        let app = launch()

        XCTAssertTrue(searchAndClaim(app, name: "Daniel Winek"), "Search should return the athlete")
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["FINISHES"].waitForExistence(timeout: 15))

        XCTAssertFalse(app.staticTexts["2 more races"].exists,
                       "No locked row should exist while everything is unlocked")
        XCTAssertFalse(app.staticTexts["Unlock Every Race"].exists, "No paywall should be reachable")
        attachScreenshot(app, name: "8-unlocked-locker")

        // The three surfaces that used to be behind the paywall.
        app.tabBars.buttons["Bests"].tap()
        XCTAssertTrue(app.navigationBars["Bests"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Split leaderboards"].exists,
                       "Bests should show the board, not the locked placeholder")
        attachScreenshot(app, name: "9-unlocked-bests")

        app.tabBars.buttons["Resume"].tap()
        XCTAssertTrue(app.navigationBars["Resume"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["INCLUDE"].waitForExistence(timeout: 10),
                      "Resume should show its options, not the locked placeholder")
        attachScreenshot(app, name: "10-unlocked-resume")
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
