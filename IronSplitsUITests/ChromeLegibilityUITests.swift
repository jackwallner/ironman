import XCTest

/// Measures that every control on the navy navigation bar can actually be read,
/// and that no text runs off the edge of the screen, in both colour schemes.
///
/// Why this exists: 1.1.1 shipped a Change button that was navy text on dark
/// Liquid Glass on Pattie's iPhone. `LockerFlowUITests` had asserted that the
/// button *existed* the whole time, and the design audit screenshots came from a
/// simulator whose glass rendered light, so nothing noticed. Existence is not
/// legibility. These tests read the pixels of each control and fail below the
/// WCAG 4.5:1 text contrast ratio, and they read element frames to catch a stat
/// tile or label clipped by the screen edge ("29 PODIU…").
///
/// Seeded data (`-SeedScreenshotData`) keeps the run offline and deterministic.
@MainActor
final class ChromeLegibilityUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func testBarControlsAreLegibleInLightMode() throws {
        try walkBarControls(appearance: "-AuditLight")
    }

    func testBarControlsAreLegibleInDarkMode() throws {
        try walkBarControls(appearance: "-AuditDark")
    }

    func testSheetsAndPaywallAreLegibleInLightMode() throws {
        try walkSheets(appearance: "-AuditLight")
    }

    func testSheetsAndPaywallAreLegibleInDarkMode() throws {
        try walkSheets(appearance: "-AuditDark")
    }

    /// The modal surfaces: the Race Book paywall a free user hits, the race
    /// note editor, and the episode player, each with its own bar controls.
    private func walkSheets(appearance: String) throws {
        let app = XCUIApplication()
        // No FORCE_PRO: the paywall is the point.
        app.launchArguments = ["-UITest", "-ResetLocker", "-SeedScreenshotData", appearance]
        app.launch()
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 20))

        app.tabBars.buttons["Race Book"].tap()
        let unlock = app.buttons["Unlock to export"]
        for _ in 0..<8 where !unlock.isHittable { app.swipeUp() }
        XCTAssertTrue(unlock.waitForExistence(timeout: 10))
        unlock.tap()
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 15))
        settle()
        shoot(app, "paywall")
        assertLegible(close, "Paywall Close")
        assertNoTextRunsOffScreen(app, screen: "Paywall")
        close.tap()

        app.tabBars.buttons["Locker"].tap()
        let race = app.staticTexts["Riverbend Triathlon"].firstMatch
        XCTAssertTrue(race.waitForExistence(timeout: 10))
        race.tap()
        let addNote = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Add notes for this race")
        ).firstMatch
        for _ in 0..<6 where !addNote.isHittable { app.swipeUp() }
        XCTAssertTrue(addNote.waitForExistence(timeout: 10))
        addNote.tap()
        XCTAssertTrue(app.navigationBars.buttons["Save"].waitForExistence(timeout: 10))
        settle()
        shoot(app, "note-editor")
        assertNavigationBarLegible(app, screen: "Note editor")
        app.navigationBars.buttons["Cancel"].tap()
        backButton(app).tap()

        app.tabBars.buttons["Tips"].tap()
        let library = app.buttons["All episodes"]
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        library.tap()
        let episode = app.staticTexts["Mud In Shoes"].firstMatch
        XCTAssertTrue(episode.waitForExistence(timeout: 25))
        episode.tap()
        XCTAssertTrue(app.navigationBars.buttons["Done"].waitForExistence(timeout: 15))
        settle()
        shoot(app, "episode-player")
        assertNavigationBarLegible(app, screen: "Episode player")
        app.navigationBars.buttons["Done"].tap()
        app.buttons["Ask Pattie"].tap()
    }

    private func walkBarControls(appearance: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITest", "-ResetLocker", "-SeedScreenshotData", appearance]
        app.launchEnvironment["FORCE_PRO"] = "1"
        app.launch()

        // Locker: the two trailing actions Pattie could not see.
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["FINISHES"].waitForExistence(timeout: 15))
        settle()
        assertLegible(app.buttons["Change athlete"], "Locker Change")
        assertLegible(app.buttons["More locker actions"], "Locker more menu")
        assertNoTextRunsOffScreen(app, screen: "Locker")

        // The sheet Change opens, and its Cancel.
        app.buttons["Change athlete"].tap()
        let cancel = app.navigationBars.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        settle()
        assertLegible(cancel, "Change athlete Cancel")
        cancel.tap()

        // A pushed screen and its back button.
        let race = app.staticTexts["Riverbend Triathlon"].firstMatch
        XCTAssertTrue(race.waitForExistence(timeout: 10))
        race.tap()
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 15))
        settle()
        assertLegible(backButton(app), "Race detail Back")
        assertNoTextRunsOffScreen(app, screen: "Race detail")
        backButton(app).tap()

        // Tips: the mode switch in both states, then a pushed Ask Pattie page.
        app.tabBars.buttons["Tips"].tap()
        let ask = app.buttons["Ask Pattie"]
        let library = app.buttons["All episodes"]
        XCTAssertTrue(ask.waitForExistence(timeout: 10))
        settle()
        assertLegible(ask, "Tips Ask Pattie (selected)")
        assertLegible(library, "Tips All episodes (unselected)")
        library.tap()
        settle()
        assertLegible(ask, "Tips Ask Pattie (unselected)")
        assertLegible(library, "Tips All episodes (selected)")
        ask.tap()
        let goal = app.staticTexts["A 70.3"]
        XCTAssertTrue(goal.waitForExistence(timeout: 15))
        goal.tap()
        XCTAssertTrue(app.staticTexts["WHAT DO YOU NEED HELP WITH?"].waitForExistence(timeout: 10))
        settle()
        assertLegible(backButton(app), "Ask Pattie topics Back")
        backButton(app).tap()

        // Race Book's pushed compare screen.
        app.tabBars.buttons["Race Book"].tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 10))
        let compare = app.buttons["Compare two races"]
        for _ in 0..<6 where !compare.isHittable { app.swipeUp() }
        if compare.waitForExistence(timeout: 5) {
            compare.tap()
            XCTAssertTrue(app.navigationBars["Compare races"].waitForExistence(timeout: 10))
            settle()
            assertLegible(backButton(app), "Compare races Back")
            backButton(app).tap()
        }

        // Explore's pushed athlete page.
        app.tabBars.buttons["Explore"].tap()
        let recent = app.staticTexts["Riley Example"].firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 15))
        recent.tap()
        XCTAssertTrue(app.staticTexts["RACE HISTORY"].waitForExistence(timeout: 15))
        settle()
        assertLegible(backButton(app), "Explore athlete Back")
        assertNoTextRunsOffScreen(app, screen: "Explore athlete")
    }

    // MARK: - Helpers

    private func backButton(_ app: XCUIApplication) -> XCUIElement {
        let custom = app.navigationBars.buttons["Back"].firstMatch
        return custom.exists ? custom : app.navigationBars.buttons.element(boundBy: 0)
    }

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func settle() {
        _ = XCTWaiter.wait(for: [expectation(description: "settle")], timeout: 1.0)
    }
}
