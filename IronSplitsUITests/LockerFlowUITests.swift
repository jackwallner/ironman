import XCTest

/// Drives the real app end to end against the live results feed.
///
/// The claim flow is the one thing in this app that cannot be unit tested
/// honestly: it is a search against somebody else's OData service, and a mock
/// would only ever prove the mock still matches what I wrote down. This test
/// types a name, waits for real athletes to come back, claims one, and checks
/// that the locker fills in.
@MainActor
final class LockerFlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(forcePro: Bool = false,
                         accessibilityTextSize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest", "-ResetLocker"]
        if accessibilityTextSize {
            app.launchArguments += ["-AuditLight",
                                    "-UIPreferredContentSizeCategoryName",
                                    "UICTContentSizeCategoryAccessibilityXXXL"]
        }
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
        XCTAssertTrue(app.buttons["Change athlete"].waitForExistence(timeout: 10),
                      "Changing the athlete should be visible from Locker")
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

        // Race Book is the single home for the resume and personal bests.
        app.tabBars.buttons["Race Book"].tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["PERSONAL BESTS"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["THINGS TO INCLUDE"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["PODI-UMS"].exists)
        attachScreenshot(app, name: "4-race-book")

        let compareButton = app.buttons["Compare two races"]
        XCTAssertTrue(compareButton.waitForExistence(timeout: 10))
        let tabBar = app.tabBars.firstMatch
        for _ in 0..<12 {
            guard compareButton.exists else { break }
            if compareButton.isHittable && compareButton.frame.maxY <= tabBar.frame.minY { break }
            app.swipeUp()
        }
        XCTAssertTrue(compareButton.isHittable)
        XCTAssertLessThanOrEqual(compareButton.frame.maxY, tabBar.frame.minY,
                                  "Comparison must clear the custom tab bar before it can be tapped")
        compareButton.tap()
        XCTAssertTrue(app.navigationBars["Compare races"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["TIME BY LEG"].waitForExistence(timeout: 10))
        app.navigationBars["Compare races"].buttons.element(boundBy: 0).tap()

        let buildExportButton = app.buttons["Build PDF and image"]
        for _ in 0..<6 where !buildExportButton.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(buildExportButton.waitForExistence(timeout: 10))
        buildExportButton.tap()
        XCTAssertTrue(app.buttons["Share PDF"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Share image"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["View PDF"].waitForExistence(timeout: 15))
        app.buttons["View PDF"].tap()
        XCTAssertTrue(app.navigationBars["Race Book PDF"].waitForExistence(timeout: 15))
        app.buttons["Done"].tap()

        // Pattie: Ask Pattie, then the episode library behind the same tab.
        app.tabBars.buttons["Tips"].tap()
        XCTAssertTrue(app.staticTexts["WHAT ARE YOU TRAINING FOR?"].waitForExistence(timeout: 10),
                      "The Pattie tab should open on the Ask Pattie tree")
        attachScreenshot(app, name: "6-ask-pattie")

        // Settings
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["System"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Light"].exists)
        XCTAssertTrue(app.buttons["Dark"].exists)
        app.buttons["Dark"].tap()
        XCTAssertTrue(app.buttons["Dark"].isSelected)
        app.buttons["Light"].tap()
        XCTAssertTrue(app.buttons["Light"].isSelected)
        app.buttons["System"].tap()
        attachScreenshot(app, name: "7-settings")
    }

    func testRaceBookActionsRemainReachableAtAccessibilitySize() throws {
        let app = launch(forcePro: true, accessibilityTextSize: true)

        XCTAssertTrue(searchAndClaim(app, name: "Daniel Winek"), "Search should return the athlete")
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 30))

        app.tabBars.buttons["Race Book"].tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 10))

        let compareButton = app.buttons["Compare two races"]
        XCTAssertTrue(compareButton.waitForExistence(timeout: 10))
        let tabBar = app.tabBars.firstMatch
        for _ in 0..<12 {
            guard compareButton.exists else { break }
            if compareButton.isHittable && compareButton.frame.maxY <= tabBar.frame.minY { break }
            app.swipeUp()
        }
        XCTAssertTrue(compareButton.isHittable, "Comparison should remain reachable at accessibility text size")
        XCTAssertLessThanOrEqual(compareButton.frame.maxY, tabBar.frame.minY,
                                 "Comparison must clear the custom tab bar at accessibility text size")
        compareButton.tap()
        XCTAssertTrue(app.navigationBars["Compare races"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["TIME BY LEG"].waitForExistence(timeout: 10))
        app.navigationBars["Compare races"].buttons.element(boundBy: 0).tap()

        let exportButton = app.buttons["Build PDF and image"]
        for _ in 0..<12 where !exportButton.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(exportButton.waitForExistence(timeout: 10))
        XCTAssertTrue(exportButton.isHittable, "Export should remain reachable at accessibility text size")
        attachScreenshot(app, name: "race-book-accessibility")
    }

    /// The core results remain complete without Race Book, while the actual
    /// comparison and export actions open the contextual lifetime paywall.
    func testFreeCoreStaysAvailableWithoutRaceBookPurchase() throws {
        // No FORCE_PRO: this is a plain launch with no entitlement.
        let app = launch()

        XCTAssertTrue(searchAndClaim(app, name: "Daniel Winek"), "Search should return the athlete")
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["FINISHES"].waitForExistence(timeout: 15))

        XCTAssertFalse(app.staticTexts["2 more races"].exists,
                       "The free locker must never hide history")
        XCTAssertFalse(app.staticTexts["Unlock Every Race"].exists,
                       "The retired full-history paywall must not return")
        attachScreenshot(app, name: "8-unlocked-locker")

        app.tabBars.buttons["Race Book"].tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["THINGS TO INCLUDE"].waitForExistence(timeout: 10),
                      "Race Book should expose its configuration without a locked placeholder")
        let exportButton = app.buttons["Unlock Race Book exports"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 10))
        exportButton.tap()
        XCTAssertTrue(app.staticTexts["Share your Race Book"].waitForExistence(timeout: 15),
                      "Export should open the Race Book paywall")
        attachScreenshot(app, name: "race-book-paywall")
        app.buttons["Close"].tap()
        attachScreenshot(app, name: "10-unlocked-resume")
    }

    func testReviewPromptScrollsAtAccessibilitySize() throws {
        let app = launch(accessibilityTextSize: true)
        XCTAssertTrue(searchAndClaim(app, name: "Daniel Winek"), "Search should return the athlete")
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 30))

        app.tabBars.buttons["Settings"].tap()
        let reviewButton = app.buttons["Rate or send feedback"]
        for _ in 0..<8 where !reviewButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 10))
        XCTAssertTrue(reviewButton.isHittable, "About actions should remain reachable after scrolling at accessibility text size")
        reviewButton.tap()

        XCTAssertTrue(app.navigationBars["Enjoying IM Tri Tracker?"].waitForExistence(timeout: 10))
        app.buttons["Not really"].tap()
        XCTAssertTrue(app.navigationBars["Help us improve"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["What would make IM Tri Tracker work better for you?"].exists)
        let sendButton = app.buttons["Send feedback"]
        if !sendButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(sendButton.isHittable, "Feedback submission should remain reachable above the keyboard")
        attachScreenshot(app, name: "accessibility-review-feedback")
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
