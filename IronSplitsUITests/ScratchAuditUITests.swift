import XCTest

/// Scratch UI tests for the 2026-10-30 overnight audit. Not committed.
/// Each test asserts the CORRECT behaviour, so a failure confirms a finding.
@MainActor
final class ScratchAuditUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
    }

    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITest", "-ResetLocker", "-SeedScreenshotData", "-AuditLight"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 30))
        return app
    }

    private func element(_ app: XCUIApplication, labelBeginsWith prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
            .firstMatch
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testOpeningRaceBookLeavesTheLockerOnAll() {
        let app = launchSeeded()
        let all = app.buttons["All"]
        XCTAssertTrue(all.waitForExistence(timeout: 15))
        XCTAssertTrue(all.isSelected, "All should be selected on a fresh launch")
        let half = element(app, labelBeginsWith: "Lakeside Half Triathlon")
        XCTAssertTrue(half.waitForExistence(timeout: 10), "2025 half should be listed under All")
        capture(app, "1-locker-before-race-book")

        app.tabBars.buttons["Race Book"].tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 15))
        capture(app, "2-race-book")

        app.tabBars.buttons["Locker"].tap()
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 15))
        sleep(2)
        capture(app, "3-locker-after-race-book")
        XCTAssertTrue(app.buttons["All"].isSelected,
                      "Opening Race Book switched the Locker filter away from All")
        XCTAssertTrue(element(app, labelBeginsWith: "Lakeside Half Triathlon").exists,
                      "The 2025 half left the Locker after Race Book was opened")

        // A push and pop re-runs the Locker's onAppear as well.
        let race = app.staticTexts["Riverbend Triathlon"].firstMatch
        if race.waitForExistence(timeout: 10) {
            race.tap()
            _ = app.staticTexts["SPLITS"].waitForExistence(timeout: 15)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 15))
            sleep(2)
            capture(app, "3b-locker-after-race-detail")
            XCTAssertTrue(app.buttons["All"].isSelected,
                          "After a race detail the Locker filter is no longer All")
        }
    }

    func testSavingTheShareImageToPhotosKeepsTheAppRunning() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITest", "-ResetLocker", "-SeedScreenshotData", "-AuditLight"]
        app.launchEnvironment["FORCE_PRO"] = "1"
        app.launch()
        XCTAssertTrue(app.navigationBars["Locker"].waitForExistence(timeout: 30))
        app.tabBars.buttons["Race Book"].tap()
        XCTAssertTrue(app.navigationBars["Race Book"].waitForExistence(timeout: 15))

        let build = app.buttons["Build PDF and image"]
        XCTAssertTrue(build.waitForExistence(timeout: 15))
        for _ in 0..<10 where !build.isHittable { app.swipeUp() }
        build.tap()
        let shareImage = app.buttons["Share image"]
        XCTAssertTrue(shareImage.waitForExistence(timeout: 30), "Export never produced the image")
        for _ in 0..<6 where !shareImage.isHittable { app.swipeUp() }
        shareImage.tap()

        let save = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Save Image"))
            .firstMatch
        if !save.waitForExistence(timeout: 10) {
            // iOS 26+ puts the full action list behind "View More".
            capture(app, "7a-share-sheet-row")
            let more = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", "View More"))
                .firstMatch
            if more.waitForExistence(timeout: 5) { more.tap() } else { app.swipeUp() }
        }
        XCTAssertTrue(save.waitForExistence(timeout: 20), "Share sheet offered no Save Image")
        capture(app, "7-share-sheet")
        save.tap()
        sleep(5)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.firstMatch.exists {
            capture(app, "8-photos-permission-alert")
        }
        XCTAssertEqual(app.state, .runningForeground, "The app terminated after Save Image")
    }

    func testAskPattieOffersTheFullClipOnAFreshInstall() {
        let app = launchSeeded()
        app.tabBars.buttons["Tips"].tap()

        let goal = element(app, labelBeginsWith: "My first triathlon")
        XCTAssertTrue(goal.waitForExistence(timeout: 20), "Ask Pattie goals never rendered")
        goal.tap()
        let topic = element(app, labelBeginsWith: "Race morning")
        XCTAssertTrue(topic.waitForExistence(timeout: 15))
        topic.tap()
        let hear = app.buttons["Hear it from Pattie"].firstMatch
        XCTAssertTrue(hear.waitForExistence(timeout: 15), "Answers never rendered")
        sleep(3)
        capture(app, "4-answers-fresh-install")
        XCTAssertTrue(app.buttons["Full clip"].firstMatch.exists,
                      "Fresh install: answers offer no Full clip although every answer names an episode")

        // Open the episode library once, then walk back to the same answers.
        app.buttons["All episodes"].tap()
        let episode = element(app, labelBeginsWith: "EP ")
        _ = episode.waitForExistence(timeout: 30)
        sleep(2)
        capture(app, "5-library")
        app.buttons["Ask Pattie"].tap()
        let goalAgain = element(app, labelBeginsWith: "My first triathlon")
        XCTAssertTrue(goalAgain.waitForExistence(timeout: 15))
        goalAgain.tap()
        let topicAgain = element(app, labelBeginsWith: "Race morning")
        XCTAssertTrue(topicAgain.waitForExistence(timeout: 15))
        topicAgain.tap()
        XCTAssertTrue(app.buttons["Hear it from Pattie"].firstMatch.waitForExistence(timeout: 15))
        sleep(3)
        capture(app, "6-answers-after-library")
        XCTAssertTrue(app.buttons["Full clip"].firstMatch.exists,
                      "Full clip should appear once the library has loaded")
    }
}
