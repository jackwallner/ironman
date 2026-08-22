import XCTest

/// Walks every screen in both colour schemes and attaches a screenshot of each.
///
/// This exists because "there's a ton of mismatch in dark and light mode" is not
/// a thing you catch by reading Swift. `TriPalette` resolves inside
/// `UIColor(dynamicProvider:)` precisely so that UIKit-backed chrome (nav bars,
/// `Form` rows, sheets) follows the scheme, and the only way to know it actually
/// does is to look at the same screen twice.
///
/// It is a screenshot harness, not an assertion suite: it claims one athlete,
/// walks every screen, and leaves the attachments on the result bundle for the
/// twenty-minute audit in `DESIGN.md`. The handful of assertions it does make
/// are only there to fail loudly if a screen never rendered, so an empty
/// screenshot is not mistaken for a clean one.
///
/// Run it once per scheme, setting the simulator first:
///
///     xcrun simctl ui <udid> appearance dark
///     xcodebuild test ... -only-testing:IronSplitsUITests/DesignAuditUITests
///
/// `XCUIDevice.shared.appearance` looks like it should do this from inside the
/// test and does not: the screenshots come back in whatever scheme the
/// simulator was already in, which is worse than useless because they look like
/// a passing audit.
@MainActor
final class DesignAuditUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func testEveryScreen() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITest", "-ResetLocker"]
        switch ProcessInfo.processInfo.environment["IRON_SPLITS_AUDIT_APPEARANCE"] {
        case "dark":
            app.launchArguments += ["-AuditDark"]
        case "light":
            app.launchArguments += ["-AuditLight"]
        default:
            break
        }
        app.launch()

        // Onboarding first: the highest-leverage screen in the app and the only
        // one a new user is guaranteed to see.
        settle()
        shoot(app, "01-onboarding")

        let field = app.textFields["Your name as you registered"]
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        field.tap()
        field.typeText("Pattie Wallner")

        let match = app.staticTexts["Pattie Wallner"].firstMatch
        if !match.waitForExistence(timeout: 30) {
            field.typeText(" ")
            field.typeText(XCUIKeyboardKey.delete.rawValue)
            XCTAssertTrue(match.waitForExistence(timeout: 45), "Pattie should come back from the feed")
        }
        settle()
        shoot(app, "02-search-results")

        match.tap()
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 40))
        XCTAssertTrue(app.staticTexts["FINISHES"].waitForExistence(timeout: 20))

        settle()
        shoot(app, "03-locker")

        // Race detail, which is the densest screen and the one with the hero.
        let firstRace = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "IRONMAN")
        ).firstMatch
        XCTAssertTrue(firstRace.waitForExistence(timeout: 20),
                      "The first race must be tappable for the visual audit")
        firstRace.tap()
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 20),
                      "Race Detail must render for the visual audit")
        settle()
        shoot(app, "04-race-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        for (tab, name) in [("Bests", "05-bests"), ("Pattie", "06-ask-pattie"),
                            ("Resume", "07-resume"), ("Settings", "08-settings")] {
            app.tabBars.buttons[tab].tap()
            settle()
            shoot(app, name)
        }

        // The episode library, and one level into Ask Pattie, which are the two
        // screens the tab switch does not reach on its own.
        app.tabBars.buttons["Pattie"].tap()
        if app.buttons["All episodes"].waitForExistence(timeout: 10) {
            app.buttons["All episodes"].tap()
            _ = app.staticTexts["Mud In Shoes"].waitForExistence(timeout: 25)
            settle()
            shoot(app, "09-episode-library")
            app.buttons["Ask Pattie"].tap()
        }
        if app.staticTexts["A 70.3"].waitForExistence(timeout: 10) {
            app.staticTexts["A 70.3"].tap()
            _ = app.staticTexts["WHAT DO YOU NEED HELP WITH?"].waitForExistence(timeout: 10)
            settle()
            shoot(app, "10-ask-topics")
            if app.staticTexts["Transitions"].waitForExistence(timeout: 5) {
                app.staticTexts["Transitions"].tap()
                _ = app.staticTexts["HERE'S THE SITUATION"].waitForExistence(timeout: 10)
                settle()
                shoot(app, "11-ask-answers")
            }
        }
    }

    private func settle() {
        _ = XCTWaiter.wait(for: [expectation(description: "settle")], timeout: 1.2)
    }

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
