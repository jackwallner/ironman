import XCTest

/// Skeptical free-user walkthrough of the paid boundary: what Race Book shows
/// before paying, the paywall from each entry point, Restore, and every way out.
///
/// Screenshots and measurements only, no hard asserts on product quality, so a
/// finding never turns the lane red. No purchase is attempted (simulator builds
/// have no transaction behind the CTA).
@MainActor
final class SubscriptionAuditUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest", "-ResetLocker", "-SeedScreenshotData", "-AuditLight"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func note(_ text: String) {
        let a = XCTAttachment(string: text)
        a.name = "note"
        a.lifetime = .keepAlways
        add(a)
    }

    private func size(_ el: XCUIElement, _ label: String) {
        note("\(label): exists=\(el.exists) hittable=\(el.exists && el.isHittable) frame=\(el.exists ? "\(el.frame)" : "n/a")")
    }

    private func scrollTo(_ el: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<10 where !(el.exists && el.isHittable) { app.swipeUp() }
    }

    /// Race Book as a free user sees it, then the compare paywall, Restore, close.
    func testRaceBookFreeAndComparePaywall() throws {
        let app = launch()
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Race Book"].tap()
        sleep(2)
        shot(app, "s01-race-book-top")

        let compare = app.buttons["Unlock race comparison"]
        scrollTo(compare, app)
        shot(app, "s02-race-book-compare-card")
        size(compare, "compare button")

        let export = app.buttons["Unlock to export"]
        scrollTo(export, app)
        shot(app, "s03-race-book-export-card")
        size(export, "export button")

        scrollTo(compare, app)
        for _ in 0..<4 where !(compare.exists && compare.isHittable) { app.swipeDown() }
        compare.tap()
        sleep(3)
        shot(app, "s04-paywall-compare-top")

        let close = app.buttons["Close"]
        size(close, "paywall close")
        let restore = app.buttons["Restore Purchases"]
        size(restore, "paywall restore (before scroll)")

        app.swipeUp()
        sleep(1)
        shot(app, "s05-paywall-compare-scrolled")
        size(restore, "paywall restore (after scroll)")
        for _ in 0..<3 where !(restore.exists && restore.isHittable) { app.swipeUp() }
        size(app.buttons["Terms"], "terms link")
        size(app.buttons["Privacy"], "privacy link")
        for link in ["Terms", "Privacy"] {
            note("\(link) as link: \(app.links[link].exists) frame=\(app.links[link].exists ? "\(app.links[link].frame)" : "n/a")")
        }

        if restore.exists && restore.isHittable {
            restore.tap()
            sleep(3)
            shot(app, "s06-paywall-after-restore")
        }

        // Exit 1: close button.
        if close.exists { close.tap() }
        sleep(1)
        shot(app, "s07-after-close")

        // Exit 2: swipe down from the sheet.
        export.exists ? () : scrollTo(export, app)
        if export.exists && export.isHittable {
            export.tap()
            sleep(3)
            shot(app, "s08-paywall-export-top")
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
            start.press(forDuration: 0.1, thenDragTo: end)
            sleep(2)
            shot(app, "s09-after-swipe-down")
            note("paywall still on screen after swipe down: \(app.buttons["Restore Purchases"].exists)")
        }
    }

    /// Settings: the Race Book section, See Race Book, and Restore from there.
    func testSettingsRaceBookAndRestore() throws {
        let app = launch()
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Settings"].tap()
        sleep(2)
        let see = app.buttons["See Race Book"]
        scrollTo(see, app)
        shot(app, "r01-settings-race-book-section")
        size(see, "See Race Book")
        let restore = app.buttons["Restore purchases"]
        size(restore, "Settings restore")
        if restore.exists && restore.isHittable {
            restore.tap()
            sleep(2)
            shot(app, "r02-settings-after-restore")
            restore.tap()
            sleep(1)
            shot(app, "r03-settings-second-restore")
        }
        if see.exists && see.isHittable {
            see.tap()
            sleep(3)
            shot(app, "r04-settings-paywall")
        }
    }

    /// Exit path: remove the athlete, and what the paid screen says without one.
    func testExitPaths() throws {
        let app = launch()
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Settings"].tap()
        sleep(2)
        let remove = app.buttons["Remove athlete"]
        let removeAlt = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Remove'")).firstMatch
        let target = remove.exists ? remove : removeAlt
        scrollTo(target, app)
        shot(app, "x01-settings-remove-row")
        if target.exists && target.isHittable {
            target.tap()
            sleep(1)
            shot(app, "x02-remove-confirmation")
        }
    }
}
