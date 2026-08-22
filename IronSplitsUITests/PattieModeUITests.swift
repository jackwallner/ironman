import XCTest

/// Pattie Mode, and the Ask Pattie tree it shares a tab with.
///
/// Pattie Mode is off in every other UI test on purpose. `-PattieMode` is the
/// opt-in, and this is the one test group that exercises the companion.
@MainActor
final class PattieModeUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launch(pattieMode: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest", "-ResetLocker"]
        if pattieMode {
            app.launchArguments += ["-PattieMode"]
            app.launchEnvironment["IRONSPLITS_PATTIE_MODE"] = "1"
        }
        app.launch()
        return app
    }

    /// She turns up, with her face and her voice, and the bubble goes away when tapped.
    func testPattieAppearsAndDismisses() throws {
        let app = launch(pattieMode: true)

        // The search screen fires `.searching`, which is the first moment that
        // can land before an athlete has been claimed.
        let card = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Pattie says:")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "Pattie Mode should show a speech bubble")

        card.tap()
        XCTAssertTrue(waitForDisappearance(card, timeout: 10), "Tapping the card should dismiss it")
    }

    /// The speech bubble clears the tab bar and stays anchored to the left.
    func testCompanionClearsTheTabBar() throws {
        let app = launch(pattieMode: true)

        XCTAssertTrue(claimPattie(in: app), "The companion needs a claimed athlete")
        dismissBubbleIfPresent(in: app)

        app.tabBars.buttons["Settings"].tap()
        dismissBubbleIfPresent(in: app)

        let show = app.buttons["Show me one now"]
        if !show.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(show.waitForExistence(timeout: 15))
        show.tap()

        let card = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Pattie says:")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The speech bubble should show")
        XCTAssertFalse(app.staticTexts["LIVE"].exists)
        XCTAssertFalse(app.staticTexts["READY"].exists)
        XCTAssertFalse(app.staticTexts["ROTATING PHRASES"].exists)
        XCTAssertFalse(app.staticTexts["REAL PATTIE AUDIO"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "pattie-companion"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertLessThan(card.frame.maxY, tabBar.frame.minY,
                          "Pattie's bubble must stay above the tab bar")
        XCTAssertLessThan(card.frame.minX, tabBar.frame.midX,
                          "Pattie's bubble should remain on the left side")
    }

    /// The same launch without the flag stays quiet, which is what the rest of
    /// the suite depends on.
    func testPattieStaysQuietWhenNotAskedFor() throws {
        let app = launch(pattieMode: false)

        XCTAssertTrue(app.textFields["Your name as you registered"].waitForExistence(timeout: 20))
        let card = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Pattie says:")
        ).firstMatch
        // Long enough for the welcome and searching moments to have fired.
        XCTAssertFalse(card.waitForExistence(timeout: 8), "Pattie Mode should be off without -PattieMode")
        let companion = app.buttons["Pattie. Tap for a tip."]
        XCTAssertFalse(companion.waitForExistence(timeout: 2), "The companion should be hidden by default")
    }

    /// The one switch removes both the face and the voice.
    func testTurningPattieModeOffRemovesCompanion() throws {
        let app = launch(pattieMode: true)

        XCTAssertTrue(claimPattie(in: app), "The companion needs a claimed athlete")
        dismissBubbleIfPresent(in: app)
        app.tabBars.buttons["Settings"].tap()
        dismissBubbleIfPresent(in: app)

        let toggle = app.switches["Pattie Mode"]
        if !toggle.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()

        let card = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Pattie says:")
        ).firstMatch
        XCTAssertFalse(card.waitForExistence(timeout: 3), "Turning Pattie Mode off should remove the bubble")
        let companion = app.buttons["Pattie. Tap for a tip."]
        XCTAssertFalse(companion.waitForExistence(timeout: 2), "Turning Pattie Mode off should hide the companion")
    }

    /// Ask Pattie is three taps and every path lands on an answer with audio.
    func testAskPattieReachesAnAnswerInThreeTaps() throws {
        let app = launch(pattieMode: false)

        XCTAssertTrue(claimPattie(in: app), "The Pattie tab needs a claimed athlete")
        app.tabBars.buttons["Pattie"].tap()

        XCTAssertTrue(app.staticTexts["WHAT ARE YOU TRAINING FOR?"].waitForExistence(timeout: 15),
                      "The Pattie tab should open on the goal question")

        app.staticTexts["A 70.3"].tap()
        XCTAssertTrue(app.staticTexts["WHAT DO YOU NEED HELP WITH?"].waitForExistence(timeout: 10))

        app.staticTexts["Transitions"].tap()

        // An answer carries her setup, her fix, and a button that plays the
        // clip the fix was transcribed from.
        XCTAssertTrue(app.staticTexts["HERE'S THE SITUATION"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["HERE'S THE SOLUTION"].exists)
        XCTAssertTrue(app.buttons["Hear it from Pattie"].firstMatch.exists,
                      "Every answer should offer her own audio")

        // Back out, to prove this is real navigation rather than a stack of
        // sheets: the system back button has to return to the topic list.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["WHAT DO YOU NEED HELP WITH?"].waitForExistence(timeout: 10))
    }

    /// The library half of the tab still lists the episodes.
    func testEpisodeLibraryLists() throws {
        let app = launch(pattieMode: false)

        XCTAssertTrue(claimPattie(in: app), "The Pattie tab needs a claimed athlete")
        app.tabBars.buttons["Pattie"].tap()
        XCTAssertTrue(app.buttons["All episodes"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Pattie's pointers"].waitForExistence(timeout: 10),
                      "Pattie's profile moment should be featured in her tab")
        app.buttons["All episodes"].tap()

        XCTAssertTrue(app.staticTexts["Mud In Shoes"].waitForExistence(timeout: 20),
                      "The catalog should load and list episodes")
        // Nothing is behind a lock any more.
        XCTAssertFalse(app.images["lock.fill"].exists)
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                             object: element)
        return XCTWaiter.wait(for: [gone], timeout: timeout) == .completed
    }

    private func dismissBubbleIfPresent(in app: XCUIApplication) {
        let card = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Pattie says:")
        ).firstMatch
        if card.waitForExistence(timeout: 5), card.exists, card.isHittable {
            card.tap()
            _ = waitForDisappearance(card, timeout: 10)
        }
    }

    @discardableResult
    private func claimPattie(in app: XCUIApplication) -> Bool {
        let field = app.textFields["Your name as you registered"]
        guard field.waitForExistence(timeout: 20) else { return false }
        field.tap()
        field.typeText("Pattie Wallner")

        let match = app.staticTexts["Pattie Wallner"].firstMatch
        if !match.waitForExistence(timeout: 30) {
            field.typeText(" ")
            field.typeText(XCUIKeyboardKey.delete.rawValue)
            guard match.waitForExistence(timeout: 30) else { return false }
        }
        match.tap()
        return app.navigationBars["Locker"].waitForExistence(timeout: 30)
    }
}
