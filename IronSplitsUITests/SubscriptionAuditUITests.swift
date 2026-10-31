import XCTest

/// Skeptical free user: what is paid, what does paying add, can I get back
/// out, and can I get my purchase back on a new phone?
///
/// It records, it does not judge. Each test attaches named screenshots and one
/// "observations" text (what was on screen, control sizes, timings) so a report
/// can quote evidence. The only assertions are "the screen I need to continue
/// exists", so a slow screen ends a walk early without failing the audit.
/// Frame rate is not measured here.
///
/// All tests use the seeded demo athlete (`-SeedScreenshotData`), so nothing
/// depends on the live results feed. RevenueCat is never configured on a
/// simulator and no test taps a buy button, so nothing is purchased. S5 uses
/// the Debug-only `FORCE_PRO` hook to look at what the unlock opens.
@MainActor
final class SubscriptionAuditUITests: XCTestCase {

    private var lines: [String] = []

    override func setUp() {
        continueAfterFailure = true
        lines = []
    }

    // MARK: - S1: where does "paid" show up for a free user?

    func testS1_FreeBoundaryMap() {
        defer { flush("S1-free-boundary-map") }
        let app = launch(pro: false)
        guard lockerReady(app) else { return }
        shot("s01-locker-top")
        inventory(app, "s01 locker top")
        probePaid(app, "locker top")

        for _ in 0..<5 { app.swipeUp() }
        usleep(500_000)
        shot("s02-locker-bottom")
        probePaid(app, "locker bottom")
        for _ in 0..<5 { app.swipeDown() }

        // The free comparison a skeptic can already do: rank every race by leg.
        let rankings = app.buttons["Rankings"]
        if rankings.waitForExistence(timeout: 10) {
            rankings.tap()
            usleep(900_000)
            shot("s03-rankings-finish")
            inventory(app, "s03 rankings finish")
            let bike = app.buttons["Bike"]
            if bike.exists {
                bike.tap()
                usleep(700_000)
                shot("s04-rankings-bike")
                inventory(app, "s04 rankings bike")
            }
            probePaid(app, "rankings")
        } else {
            note("Rankings chip not found")
        }

        // A race: any paid hint on the screen a free user spends most time on?
        let races = app.buttons["Races"]
        if races.exists { races.tap(); usleep(500_000) }
        let race = app.staticTexts["Riverbend Triathlon"].firstMatch
        if race.waitForExistence(timeout: 10) {
            race.tap()
            if app.staticTexts["SPLITS"].waitForExistence(timeout: 20) {
                usleep(1_200_000)
                shot("s05-race-detail-top")
                probePaid(app, "race detail top")
                for _ in 0..<4 { app.swipeUp() }
                usleep(600_000)
                shot("s06-race-detail-bottom")
                probePaid(app, "race detail bottom")
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
            usleep(500_000)
        }

        // Race Book tab: the free preview, top to bottom.
        app.tabBars.buttons["Race Book"].tap()
        guard app.navigationBars["Race Book"].waitForExistence(timeout: 15) else {
            XCTFail("Race Book never rendered")
            return
        }
        usleep(900_000)
        shot("s07-race-book-top")
        inventory(app, "s07 race book top")
        probePaid(app, "race book top")
        app.swipeUp()
        usleep(600_000)
        shot("s08-race-book-mid")
        inventory(app, "s08 race book mid")
        probePaid(app, "race book mid")
        for _ in 0..<4 { app.swipeUp() }
        usleep(600_000)
        shot("s09-race-book-bottom")
        inventory(app, "s09 race book bottom")
        probePaid(app, "race book bottom")
    }

    // MARK: - S2: every way into the paywall, and every way out

    func testS2_PaywallEntriesAndExits() {
        defer { flush("S2-paywall-entries-exits") }
        let app = launch(pro: false)
        guard lockerReady(app) else { return }
        app.tabBars.buttons["Race Book"].tap()
        guard app.navigationBars["Race Book"].waitForExistence(timeout: 15) else {
            XCTFail("Race Book never rendered")
            return
        }

        // Entry 1: Compare.
        let compare = app.buttons["Unlock race comparison"]
        scrollTo(app, compare)
        let compareYBefore = compare.frame.minY
        note("Unlock race comparison: exists \(compare.exists), hittable \(compare.isHittable), frame \(compare.frame)")
        usleep(400_000)
        shot("p01-compare-card-before-tap")
        guard compare.exists, compare.isHittable else { return }
        let tapped = Date()
        compare.tap()
        let title = app.staticTexts["Compare your races"]
        let shown = title.waitForExistence(timeout: 20)
        note("compare paywall title \(shown ? "shown " + secs(tapped) + " after the tap" : "NOT shown in 20 s")")
        usleep(1_500_000)
        shot("p02-paywall-from-compare")
        inventory(app, "p02 paywall from compare")
        paywallFacts(app, "compare paywall")

        // Exit A: drag the sheet down instead of using the close button.
        dragSheetDown(app)
        usleep(1_300_000)
        let gone = !app.staticTexts["Compare your races"].exists
        note("swipe-down dismissed the paywall: \(gone)")
        shot("p03-after-swipe-down")
        if gone {
            let compareAfter = app.buttons["Unlock race comparison"]
            note("Race Book position kept after swipe dismiss: compare card y before \(Int(compareYBefore)), after \(compareAfter.exists ? String(Int(compareAfter.frame.minY)) : "not on screen")")
        } else if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
            usleep(900_000)
        }

        // Entry 2: Export, then exit with the close button.
        let export = app.buttons["Unlock to export"]
        scrollTo(app, export)
        note("Unlock to export: exists \(export.exists), hittable \(export.isHittable), frame \(export.frame)")
        shot("p04-export-card-before-tap")
        guard export.exists, export.isHittable else { return }
        let exportTapped = Date()
        export.tap()
        let exportTitle = app.staticTexts["Share your Race Book"]
        let exportShown = exportTitle.waitForExistence(timeout: 20)
        note("export paywall title \(exportShown ? "shown " + secs(exportTapped) + " after the tap" : "NOT shown in 20 s")")
        usleep(1_500_000)
        shot("p05-paywall-from-export")
        inventory(app, "p05 paywall from export")
        paywallFacts(app, "export paywall")

        // Restore from the paywall, as a free user with nothing to restore.
        // First a tap 11 pt above the label: outside the 118x15 text, inside a
        // 44 pt tap target. Only then a tap on the label itself.
        let restore = app.buttons["Restore Purchases"]
        let simMessage = app.staticTexts["Purchases are unavailable in simulator builds."]
        if restore.exists {
            let before = restore.frame
            note("restore before: frame \(before), message on screen \(simMessage.exists)")
            let probe = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: before.midX, dy: before.minY - 11))
            probe.tap()
            usleep(900_000)
            shot("p06-restore-edge-probe")
            let edgeWorks = simMessage.exists
            note("restore: tap 11 pt above the label (outside the text, inside a 44 pt box) gave feedback: \(edgeWorks)")
            if !edgeWorks {
                let restoreTapped = Date()
                restore.tap()
                usleep(400_000)
                shot("p07-paywall-restore-400ms")
                usleep(1_800_000)
                shot("p08-paywall-restore-2s")
                inventory(app, "p08 paywall restore 2 s")
                note("restore: label tapped, feedback checked \(secs(restoreTapped)) later: message \(simMessage.exists)")
            }
            let afterButton = app.buttons["Restore Purchases"]
            if afterButton.exists, simMessage.exists {
                note("restore layout: button y \(Int(before.minY)) before, \(Int(afterButton.frame.minY)) after the message appeared; message frame \(simMessage.frame); button hittable \(afterButton.isHittable)")
            }
        } else {
            note("Restore Purchases not found on the export paywall")
        }

        let close = app.buttons["Close"]
        note("Close: exists \(close.exists), frame \(close.frame)")
        if close.exists {
            close.tap()
            usleep(1_000_000)
            shot("p09-after-close-button")
            let exportAfter = app.buttons["Unlock to export"]
            note("after Close: Race Book bar visible \(app.navigationBars["Race Book"].exists); export card present \(exportAfter.exists)")
        }

        // Entry 3: Settings, "See Race Book".
        app.tabBars.buttons["Settings"].tap()
        guard app.navigationBars["Settings"].waitForExistence(timeout: 15) else { return }
        let see = app.buttons["See Race Book"]
        scrollTo(app, see)
        shot("p10-settings-see-race-book")
        note("See Race Book: exists \(see.exists), hittable \(see.isHittable), frame \(see.frame)")
        guard see.exists, see.isHittable else { return }
        see.tap()
        usleep(1_800_000)
        shot("p11-paywall-from-settings")
        inventory(app, "p11 paywall from settings")
        note("after tapping 'See Race Book': sheet titled 'Share your Race Book' \(app.staticTexts["Share your Race Book"].exists); title 'Unlock Race Book' \(app.staticTexts["Unlock Race Book"].exists)")
        if app.buttons["Close"].exists { app.buttons["Close"].tap() }
    }

    // MARK: - S3: restore from Settings, and a return visit

    func testS3_SettingsRestoreAndReturnVisit() {
        defer { flush("S3-settings-restore") }
        let app = launch(pro: false)
        guard lockerReady(app) else { return }
        app.tabBars.buttons["Settings"].tap()
        guard app.navigationBars["Settings"].waitForExistence(timeout: 15) else {
            XCTFail("Settings never rendered")
            return
        }
        let restore = app.buttons["Restore purchases"]
        scrollTo(app, restore)
        usleep(500_000)
        shot("r01-settings-race-book-section")
        inventory(app, "r01 settings race book section")
        note("Restore purchases: exists \(restore.exists), hittable \(restore.isHittable), frame \(restore.frame)")
        guard restore.exists, restore.isHittable else { return }

        let tapped = Date()
        restore.tap()
        usleep(300_000)
        shot("r02-restore-300ms")
        usleep(1_500_000)
        shot("r03-restore-2s")
        inventory(app, "r03 restore 2 s")
        let message = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@",
                                                           "No Race Book purchase", "unavailable")).firstMatch
        note("feedback text \(message.exists ? "'" + message.label + "' at " + String(Int(message.frame.minY)) : "NONE") \(secs(tapped)) after the tap")
        note("restore button still enabled: \(restore.isEnabled)")

        // Leave and come back: does the old result linger?
        app.tabBars.buttons["Locker"].tap()
        usleep(600_000)
        app.tabBars.buttons["Settings"].tap()
        usleep(900_000)
        let lingering = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@",
                                                             "No Race Book purchase", "unavailable")).firstMatch
        note("after switching tabs and back, old restore result still shown: \(lingering.exists)")
        scrollTo(app, app.buttons["Restore purchases"])
        shot("r04-settings-after-tab-switch")

        // Return visit: relaunch and see whether anything about the paywall
        // is pushed at launch or on the first screen.
        app.terminate()
        app.launch()
        let back = app.navigationBars["Locker"].waitForExistence(timeout: 30)
        usleep(1_500_000)
        shot("r05-relaunch-locker")
        note("relaunch: Locker \(back ? "shown" : "NOT shown"); sheet or paywall title on screen: \(app.staticTexts["Unlock Race Book"].exists || app.staticTexts["Share your Race Book"].exists || app.staticTexts["Compare your races"].exists)")
        probePaid(app, "locker after relaunch")
    }

    // MARK: - S4: exit, then try to get back to Restore

    func testS4_RemoveAthleteThenLookForRestore() {
        defer { flush("S4-remove-then-restore") }
        let app = launch(pro: false)
        guard lockerReady(app) else { return }

        // Put one note on a race so "your notes are kept" can be checked.
        let race = app.staticTexts["Riverbend Triathlon"].firstMatch
        if race.waitForExistence(timeout: 10) {
            race.tap()
            if app.staticTexts["SPLITS"].waitForExistence(timeout: 20) {
                let add = app.buttons["Add notes for this race"]
                scrollTo(app, add, attempts: 10)
                if add.exists && add.isHittable {
                    add.tap()
                    // A vertical-axis TextField is a text view to XCUITest.
                    let textView = app.textViews["How it went"]
                    let field = textView.waitForExistence(timeout: 10) ? textView : app.textFields["How it went"]
                    if field.exists {
                        field.tap()
                        field.typeText("Audit note")
                        usleep(500_000)
                        shot("x01-note-editor")
                        let save = app.buttons["Save"]
                        if save.exists { save.tap() }
                        usleep(900_000)
                        note("note saved: 'Audit note' on screen \(app.staticTexts["Audit note"].exists)")
                    } else {
                        note("note editor field not found")
                    }
                } else {
                    note("Add notes for this race not reachable")
                }
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
            usleep(500_000)
        }

        app.tabBars.buttons["Settings"].tap()
        guard app.navigationBars["Settings"].waitForExistence(timeout: 15) else {
            XCTFail("Settings never rendered")
            return
        }
        usleep(500_000)
        let exportNotes = app.buttons["Export my race notes"]
        scrollTo(app, exportNotes, attempts: 6)
        note("before Remove: 'Export my race notes' exists \(exportNotes.exists)")
        shot("x02-settings-before-remove")

        let remove = app.buttons["Remove my athlete"]
        scrollTo(app, remove, attempts: 6)
        guard remove.exists else {
            shot("x03-remove-row-missing")
            XCTFail("Remove my athlete row not found")
            return
        }
        remove.tap()
        usleep(900_000)
        shot("x03-remove-confirmation")
        inventory(app, "x03 remove confirmation")
        note("confirmation: Remove button \(app.buttons["Remove"].exists), Cancel button \(app.buttons["Cancel"].exists)")
        guard app.buttons["Remove"].waitForExistence(timeout: 5) else { return }
        app.buttons["Remove"].tap()

        let field = app.textFields["Your name as you registered"]
        let back = field.waitForExistence(timeout: 20)
        usleep(1_000_000)
        shot("x04-after-remove")
        inventory(app, "x04 after remove")
        note("after Remove: onboarding field \(back ? "shown" : "NOT shown"); tab bar present \(app.tabBars.count > 0); Settings tab \(app.tabBars.buttons["Settings"].exists)")
        let restoreHits = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS[c] %@",
                                                                               "Restore", "Purchase", "Race Book")).count
        note("elements mentioning Restore, Purchase or Race Book on the post-Remove screen: \(restoreHits)")
        probePaid(app, "after remove")

        // Claim the same athlete again (the fixture), and see whether the note
        // and the export row come back.
        app.terminate()
        app.launch()
        if lockerReady(app) {
            app.tabBars.buttons["Settings"].tap()
            if app.navigationBars["Settings"].waitForExistence(timeout: 15) {
                let again = app.buttons["Export my race notes"]
                scrollTo(app, again, attempts: 6)
                note("after re-claiming the same athlete: 'Export my race notes' exists \(again.exists)")
                shot("x05-settings-after-reclaim")
            }
        }
    }

    // MARK: - S5: what the unlock actually opens (Debug FORCE_PRO, no purchase)

    func testS5_WhatTheUnlockOpens() {
        defer { flush("S5-what-the-unlock-opens") }
        let app = launch(pro: true)
        guard lockerReady(app) else { return }
        app.tabBars.buttons["Race Book"].tap()
        guard app.navigationBars["Race Book"].waitForExistence(timeout: 15) else {
            XCTFail("Race Book never rendered")
            return
        }
        usleep(900_000)
        shot("q01-race-book-unlocked-top")
        inventory(app, "q01 race book unlocked top")

        let compare = app.buttons["Compare two races"]
        scrollTo(app, compare)
        shot("q02-compare-card-unlocked")
        if compare.exists, compare.isHittable {
            compare.tap()
            if app.navigationBars["Compare races"].waitForExistence(timeout: 15) {
                usleep(1_000_000)
                shot("q03-compare-view")
                inventory(app, "q03 compare view")
                app.swipeUp()
                usleep(600_000)
                shot("q04-compare-view-scrolled")
                inventory(app, "q04 compare view scrolled")
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
            usleep(700_000)
        }

        let build = app.buttons["Build PDF and image"]
        scrollTo(app, build)
        if build.exists, build.isHittable {
            let started = Date()
            build.tap()
            usleep(400_000)
            shot("q05-export-building")
            let viewPDF = app.buttons["View PDF"]
            let built = viewPDF.waitForExistence(timeout: 120)
            note("export build \(built ? "finished " + secs(started) + " after the tap" : "did NOT finish in 120 s")")
            usleep(600_000)
            shot("q06-export-built")
            inventory(app, "q06 export built")
            if built {
                scrollTo(app, viewPDF)
                viewPDF.tap()
                if app.navigationBars["Race Book PDF"].waitForExistence(timeout: 20) {
                    usleep(1_500_000)
                    shot("q07-pdf-page-1")
                    app.swipeUp()
                    usleep(900_000)
                    shot("q08-pdf-page-2")
                    app.buttons["Done"].firstMatch.tap()
                    usleep(600_000)
                } else {
                    note("PDF preview did not open")
                }
            }
        } else {
            note("Build PDF and image not reachable")
        }

        // The unlocked Settings section, and what a failed restore looks like
        // under it. The text here is the simulator's own message; the point is
        // where an error lands once the section says "unlocked".
        app.tabBars.buttons["Settings"].tap()
        guard app.navigationBars["Settings"].waitForExistence(timeout: 15) else { return }
        let settingsRestore = app.buttons["Restore purchases"]
        scrollTo(app, settingsRestore)
        usleep(500_000)
        shot("q09-settings-unlocked")
        inventory(app, "q09 settings unlocked")
        note("Settings unlocked: 'Race Book is unlocked' \(app.staticTexts["Race Book is unlocked"].exists), See Race Book button \(app.buttons["See Race Book"].exists)")
        if settingsRestore.exists, settingsRestore.isHittable {
            settingsRestore.tap()
            usleep(900_000)
            shot("q10-settings-unlocked-after-restore")
            let stale = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "unavailable")).firstMatch
            note("after Restore while unlocked: error text '\(stale.exists ? stale.label : "none")' sits under 'Race Book is unlocked'")
        }
    }

    // MARK: - S6: can a buyer see the price and the buy button without scrolling?

    /// Meant for a small phone (`gh-sim test --device "iPhone SE (3rd generation)"`).
    /// On any device it records where each purchase-relevant control sits
    /// against the screen height.
    func testS6_PaywallFitsTheScreen() {
        defer { flush("S6-paywall-fit") }
        let app = launch(pro: false)
        guard lockerReady(app) else { return }
        app.tabBars.buttons["Race Book"].tap()
        guard app.navigationBars["Race Book"].waitForExistence(timeout: 15) else {
            XCTFail("Race Book never rendered")
            return
        }
        usleep(900_000)
        shot("f01-race-book-first-screen")
        let compare = app.buttons["Unlock race comparison"]
        scrollTo(app, compare)
        guard compare.exists, compare.isHittable else {
            note("Unlock race comparison not reachable")
            return
        }
        compare.tap()
        guard app.staticTexts["Compare your races"].waitForExistence(timeout: 20) else {
            note("paywall never appeared")
            return
        }
        usleep(1_500_000)
        let screen = app.windows.firstMatch.frame
        note("screen \(Int(screen.width))x\(Int(screen.height))")
        shot("f02-paywall-first-screen")
        let buy = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Unlock Race Book")).firstMatch
        let controls: [(String, XCUIElement)] = [
            ("price row", app.staticTexts["One-time lifetime purchase"]),
            ("buy button", buy),
            ("Restore Purchases", app.buttons["Restore Purchases"]),
            ("Close", app.buttons["Close"]),
        ]
        for (name, element) in controls {
            let frame = element.frame
            note("first screen, \(name): exists \(element.exists), y \(Int(frame.minY)) to \(Int(frame.maxY)), fully on screen \(element.exists && screen.contains(frame)), hittable \(element.isHittable)")
        }
        inventory(app, "f02 paywall first screen")
        app.swipeUp()
        usleep(800_000)
        shot("f03-paywall-scrolled")
        for (name, element) in controls {
            let frame = element.frame
            note("after one swipe up, \(name): y \(Int(frame.minY)) to \(Int(frame.maxY)), fully on screen \(element.exists && screen.contains(frame))")
        }
        app.buttons["Close"].firstMatch.tap()
        usleep(900_000)
        shot("f04-after-close")
    }

    // MARK: - S7: what a buyer can shape before building (Debug FORCE_PRO, no purchase)

    /// A free user never sees the export options, so this records what they
    /// would be buying: the include list and whether a single race can be chosen.
    func testS7_ExportOptionsBehindTheLock() {
        defer { flush("S7-export-options") }
        let app = launch(pro: true)
        guard lockerReady(app) else { return }
        app.tabBars.buttons["Race Book"].tap()
        guard app.navigationBars["Race Book"].waitForExistence(timeout: 15) else {
            XCTFail("Race Book never rendered")
            return
        }
        let customize = app.buttons["Customize export"]
        scrollTo(app, customize)
        shot("o01-customize-collapsed")
        guard customize.exists, customize.isHittable else {
            note("Customize export not reachable")
            return
        }
        customize.tap()
        usleep(900_000)
        shot("o02-customize-expanded")
        inventory(app, "o02 customize expanded")
        app.swipeUp()
        usleep(600_000)
        shot("o03-customize-expanded-lower")
        inventory(app, "o03 customize expanded lower")
        let raceChoice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "this race")).count
        note("elements offering a single-race export: \(raceChoice)")
    }

    // MARK: - Helpers

    private func launch(pro: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest", "-ResetLocker", "-SeedScreenshotData", "-AuditLight"]
        if pro { app.launchEnvironment["FORCE_PRO"] = "1" }
        app.launch()
        return app
    }

    private func lockerReady(_ app: XCUIApplication) -> Bool {
        guard app.navigationBars["Locker"].waitForExistence(timeout: 30),
              app.staticTexts["FINISHES"].waitForExistence(timeout: 15) else {
            shot("seeded-locker-missing")
            XCTFail("seeded Locker never rendered")
            return false
        }
        return true
    }

    /// Scrolls until the element is on screen and clear of the tab bar.
    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement, attempts: Int = 14) {
        let bar = app.tabBars.firstMatch
        for _ in 0..<attempts {
            let clear = !bar.exists || element.frame.maxY <= bar.frame.minY - 4
            if element.exists && element.isHittable && clear { return }
            app.swipeUp()
        }
    }

    private func dragSheetDown(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.14))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// What a buyer can see on the paywall before scrolling.
    private func paywallFacts(_ app: XCUIApplication, _ tag: String) {
        let price = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "$")).allElementsBoundByIndex
            .filter { $0.exists }
            .map { "'\($0.label)'@\(Int($0.frame.minY))" }
        note("[\(tag)] price text on screen: \(price.isEmpty ? "none" : price.joined(separator: "; "))")
        for name in ["Restore Purchases", "Terms", "Privacy", "Close"] {
            let element = app.descendants(matching: .any).matching(identifier: name).firstMatch
            note("[\(tag)] \(name): exists \(element.exists), hittable \(element.isHittable), frame \(element.exists ? element.frame.debugDescription : "n/a")")
        }
        let buy = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Unlock Race Book")).firstMatch
        note("[\(tag)] buy button: \(buy.exists ? "'" + buy.label + "' enabled \(buy.isEnabled) frame \(buy.frame)" : "not found")")
    }

    /// Notes every label on screen that talks about paying, from one snapshot.
    private func probePaid(_ app: XCUIApplication, _ tag: String) {
        guard let root = try? app.snapshot() else {
            note("[\(tag)] paid-signal probe unavailable (snapshot failed)")
            return
        }
        let pattern = "unlock|lock|premium|upgrade|subscri|purchase|restore|race book|lifetime|\\$[0-9]"
        let bounds = root.frame
        var hits: [String] = []
        var pending: [XCUIElementSnapshot] = [root]
        while let node = pending.popLast() {
            pending.append(contentsOf: node.children)
            guard node.elementType == .staticText || node.elementType == .button || node.elementType == .link else { continue }
            let frame = node.frame
            let label = node.label.replacingOccurrences(of: "\n", with: " ")
            guard !label.isEmpty, !frame.isEmpty, frame.intersects(bounds),
                  label.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil,
                  node.elementType != .button || !["Locker", "Explore", "Tips", "Race Book", "Settings"].contains(label) else { continue }
            hits.append("\(node.elementType == .button ? "button" : "text") '\(label)'@\(Int(frame.minY))")
        }
        note("[\(tag)] paid signals on screen: \(hits.isEmpty ? "none" : hits.sorted().joined(separator: "; "))")
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func note(_ text: String) {
        lines.append(text)
    }

    private func flush(_ name: String) {
        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "observations-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func secs(_ since: Date) -> String {
        String(format: "%.1f s", Date().timeIntervalSince(since))
    }

    /// What is on screen right now, from one snapshot of the tree: type, label,
    /// position and size. Buttons under 44 pt either way are flagged SMALL.
    private func inventory(_ app: XCUIApplication, _ tag: String) {
        guard let root = try? app.snapshot() else {
            note("[\(tag)] inventory unavailable (snapshot failed)")
            return
        }
        let bounds = root.frame
        note("[\(tag)] screen \(Int(bounds.width))x\(Int(bounds.height)); on-screen elements (type | label | x,y size):")
        var pending: [XCUIElementSnapshot] = [root]
        var emitted = 0
        while let node = pending.popLast() {
            pending.append(contentsOf: node.children.reversed())
            let frame = node.frame
            guard !frame.isEmpty, frame.intersects(bounds), emitted < 110 else { continue }
            let kind: String
            switch node.elementType {
            case .staticText: kind = "text"
            case .button: kind = "button"
            case .textField: kind = "field"
            case .textView: kind = "textview"
            case .switch: kind = "switch"
            case .link: kind = "link"
            default: continue
            }
            let label = node.label.replacingOccurrences(of: "\n", with: " ")
            guard !label.isEmpty || kind == "field" else { continue }
            let small = (kind == "button" || kind == "link") && (frame.height < 43.5 || frame.width < 43.5) ? " SMALL" : ""
            note("  \(kind) | \(label) | \(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))\(small)")
            emitted += 1
        }
    }
}
