import XCTest

/// Persona audit: an experienced user repeating the core tasks.
///
/// Runs on the seeded public demo fixtures (`-SeedScreenshotData`), so it is
/// offline and deterministic. It records what it measures as a text attachment
/// ("observations") next to the screenshots instead of failing, because the point
/// is evidence for a report, not a pass/fail gate.
@MainActor
final class ExperiencedUserAuditUITests: XCTestCase {

    private var observations: [String] = []

    override func setUp() { continueAfterFailure = true }

    override func tearDown() {
        let attachment = XCTAttachment(string: observations.joined(separator: "\n"))
        attachment.name = "observations"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launch(pro: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITest", "-ResetLocker", "-SeedScreenshotData", "-AuditLight"]
        if pro { app.launchEnvironment["FORCE_PRO"] = "1" }
        app.launch()
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 30))
        return app
    }

    // MARK: - Locker: rankings, search, repeat filters

    func testLockerRankingsAndSearch() throws {
        let app = launch(pro: false)
        settle()
        shoot(app, "L01-locker-open")

        // Rows visible without scrolling on a cold open.
        let rowLabels = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Triathlon")).allElementsBoundByIndex
        note("Locker cold open: \(rowLabels.count) race rows exist, \(rowLabels.filter { $0.isHittable }.count) hittable without scrolling")

        // Search with no match.
        let search = app.textFields["Search races"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("zzzz")
        settle()
        shoot(app, "L02-race-search-no-match")
        note("Race search 'zzzz': 'no match' text present = \(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "No races")).count > 0 || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "match")).count > 0)")
        if app.buttons["Clear race search"].exists { app.buttons["Clear race search"].tap() }

        // Search on a name present: keyboard covers list?
        search.tap()
        search.typeText("Cascade")
        settle()
        shoot(app, "L03-race-search-cascade-keyboard")
        let cascadeRows = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Cascade")).count
        note("Race search 'Cascade': \(cascadeRows) rows; keyboard shown = \(app.keyboards.count > 0)")
        if app.buttons["Clear race search"].exists { app.buttons["Clear race search"].tap() }
        if app.keyboards.count > 0 { app.swipeDown() }

        // Rankings: reach Bike for Half.
        app.buttons["Rankings"].tap()
        settle()
        shoot(app, "L04-rankings-default")
        let bike = app.buttons["Bike"]
        note("Rankings tab opens on discipline: Finish selected = \(app.buttons["Finish"].isSelected); taps to reach Half Bike: Rankings(1) + Bike(1) + Half chip(1)")
        if bike.exists { bike.tap() }
        let half = app.buttons["70.3"].exists ? app.buttons["70.3"] : app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Half")).firstMatch
        if half.exists { half.tap() }
        settle()
        shoot(app, "L05-rankings-bike-half")

        // Tap a ranking row, come back, check mode preserved.
        let rankedRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "personal best")).firstMatch
        if rankedRow.exists {
            rankedRow.tap()
            XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 10))
            settle()
            app.navigationBars.buttons.element(boundBy: 0).tap()
            settle()
            shoot(app, "L06-rankings-after-detail-return")
            note("After opening a ranking row and returning: Rankings selected = \(app.buttons["Rankings"].isSelected), Bike selected = \(app.buttons["Bike"].isSelected)")
        } else {
            note("No ranking row found with 'personal best' label")
        }

        // Swipe through lengthy list: where is the race search / chips after scroll?
        app.swipeUp()
        settle()
        shoot(app, "L07-rankings-scrolled")
        note("After scrolling Rankings: Rankings/Races chips hittable = \(app.buttons["Races"].isHittable); search field hittable = \(search.isHittable)")
    }

    // MARK: - Race detail: field scope on repeat opens

    func testRaceDetailFieldScopeAndNotes() throws {
        let app = launch(pro: false)
        let race = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@", "Riverbend", "2025")).firstMatch
        XCTAssertTrue(race.waitForExistence(timeout: 10))
        race.tap()
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 15))
        settle()
        shoot(app, "D01-race-detail-top")
        app.swipeUp()
        settle()
        shoot(app, "D02-race-detail-field-overall")
        note("Field scope on first open: Overall selected = \(app.buttons["Overall"].isSelected)")

        let division = app.buttons["Division"]
        if division.waitForExistence(timeout: 5) {
            division.tap()
            settle()
            shoot(app, "D03-race-detail-field-division")
            note("After tapping Division: Division selected = \(division.isSelected)")
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        settle()

        // Open another race then reopen this one.
        race.tap()
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 15))
        app.swipeUp()
        settle()
        shoot(app, "D04-race-detail-reopen")
        note("Reopen same race: Division still selected = \(app.buttons["Division"].isSelected), Overall selected = \(app.buttons["Overall"].isSelected)")

        // Note editor: add note, keyboard and Save reachability.
        let addNote = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Add notes for this race")).firstMatch
        for _ in 0..<6 where !addNote.isHittable { app.swipeUp() }
        if addNote.exists {
            addNote.tap()
            let conditions = app.textFields["Heat, wind, water and course conditions"]
            if conditions.waitForExistence(timeout: 5) {
                conditions.tap()
                conditions.typeText("Hot, 29C, wetsuit legal")
            }
            settle()
            shoot(app, "D05-note-editor-keyboard")
            note("Note editor with keyboard: Save hittable = \(app.navigationBars.buttons["Save"].isHittable), Cancel hittable = \(app.navigationBars.buttons["Cancel"].isHittable)")
            let notesField = app.textFields["How it went"]
            note("Notes ('How it went') field hittable above keyboard = \(notesField.isHittable)")
            app.navigationBars.buttons["Save"].tap()
            settle()
            shoot(app, "D06-note-saved")
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        settle()
        // Does the Locker row reflect the note?
        shoot(app, "D07-locker-after-note")
    }

    // MARK: - Race Book: free value position, compare state

    func testRaceBookFreeLayoutAndPaywall() throws {
        let app = launch(pro: false)
        app.tabBars.buttons["Race Book"].tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 10))
        settle()
        shoot(app, "R01-race-book-first-screen")
        let screenHeight = app.windows.firstMatch.frame.height
        let pb = app.staticTexts["PERSONAL BESTS"]
        let progression = app.staticTexts["PROGRESSION"]
        note("Race Book free: screen height \(Int(screenHeight)); PERSONAL BESTS header y=\(pb.exists ? Int(pb.frame.minY) : -1) (on screen = \(pb.exists && pb.isHittable)); PROGRESSION y=\(progression.exists ? Int(progression.frame.minY) : -1)")
        let intro = app.staticTexts["RACE BOOK"]
        note("Intro card marketing label visible on first screen = \(intro.exists)")
        app.swipeUp()
        settle()
        shoot(app, "R02-race-book-scrolled-1")
        app.swipeUp()
        settle()
        shoot(app, "R03-race-book-scrolled-2")

        let unlock = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Unlock race comparison")).firstMatch
        for _ in 0..<6 where !unlock.isHittable { app.swipeUp() }
        if unlock.exists {
            unlock.tap()
            _ = app.buttons["Close"].waitForExistence(timeout: 15)
            settle()
            shoot(app, "R04-compare-paywall")
            note("Compare paywall: Close hittable = \(app.buttons["Close"].isHittable); Restore visible = \(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Restore")).count > 0)")
            app.buttons["Close"].tap()
        }
    }

    func testRaceBookCompareStateAcrossVisits() throws {
        let app = launch(pro: true)
        app.tabBars.buttons["Race Book"].tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 10))
        let compare = app.buttons["Compare two races"]
        for _ in 0..<10 where !(compare.exists && compare.isHittable) { app.swipeUp() }
        compare.tap()
        XCTAssertTrue(app.navigationBars["Compare races"].waitForExistence(timeout: 10))
        settle()
        shoot(app, "C01-compare-default")

        // Open the Earlier race menu.
        let menus = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", ", "))
        note("Compare default: menu buttons found = \(menus.count)")
        let earlier = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Triathlon")).element(boundBy: 0)
        if earlier.exists {
            note("Earlier selector label = \(earlier.label)")
            earlier.tap()
            settle()
            shoot(app, "C02-compare-earlier-menu")
            // Choose the third option listed if any.
            let options = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Triathlon"))
            note("Earlier menu lists \(options.count) button labels containing 'Triathlon' (includes selectors)")
            let target = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "2022, Riverbend")).firstMatch
            if target.exists { target.tap() } else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap() }
            settle()
            shoot(app, "C03-compare-after-pick")
        }
        // Back out and return.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        settle()
        for _ in 0..<10 where !(compare.exists && compare.isHittable) { app.swipeUp() }
        compare.tap()
        XCTAssertTrue(app.navigationBars["Compare races"].waitForExistence(timeout: 10))
        settle()
        shoot(app, "C04-compare-reopened")
        let again = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Triathlon")).element(boundBy: 0)
        note("Compare reopened: Earlier selector label = \(again.exists ? again.label : "none") (was reset to default if it no longer shows the 2022 pick)")
    }

    // MARK: - Explore repeat visit

    func testExploreRepeatVisit() throws {
        let app = launch(pro: false)
        app.tabBars.buttons["Explore"].tap()
        let recent = app.staticTexts["Riley Example"].firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 10))
        settle()
        shoot(app, "E01-explore-home")
        note("Explore home: recents row exists = \(recent.exists); remove/pin control exists = \(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Remove")).count > 0)")
        recent.tap()
        XCTAssertTrue(app.staticTexts["RACE HISTORY"].waitForExistence(timeout: 15))
        settle()
        shoot(app, "E02-explore-athlete")
        note("Explore athlete: Rankings chip exists = \(app.buttons["Rankings"].exists); All-distances chip exists = \(app.buttons["All"].exists); search races field exists = \(app.textFields["Search races"].exists)")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Triathlon")).firstMatch
        if row.exists {
            row.tap()
            XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 10))
            app.swipeUp()
            settle()
            shoot(app, "E03-explore-race-detail")
            note("Explore race detail: PB badge visible against explored athlete's own history = \(app.staticTexts["PB"].exists); 'Compare to my result' control exists = \(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Compare")).count > 0)")
        }
    }

    // MARK: - Settings and change-athlete sheet

    func testSettingsAndChangeAthlete() throws {
        let app = launch(pro: false)
        app.buttons["Change athlete"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Cancel"].waitForExistence(timeout: 10))
        settle()
        shoot(app, "S01-change-athlete-sheet")
        note("Change athlete sheet: keyboard auto-shown = \(app.keyboards.count > 0); saved/other athlete list exists = \(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Recent")).count > 0)")
        app.navigationBars.buttons["Cancel"].tap()
        settle()

        app.buttons["More locker actions"].tap()
        settle()
        shoot(app, "S02-locker-menu")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).tap()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        settle()
        shoot(app, "S03-settings-top")
        app.swipeUp()
        settle()
        shoot(app, "S04-settings-mid")
        app.swipeUp()
        settle()
        shoot(app, "S05-settings-bottom")
    }

    // MARK: - Helpers

    private func note(_ line: String) {
        observations.append(line)
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
