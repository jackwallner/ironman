import XCTest
@testable import IM_Iron_Splits

final class UnfoldedSplitTests: XCTestCase {
    func testCompactWidthNeverSplits() {
        XCTAssertNil(UnfoldedSplit.make(width: 867, isRegularWidth: false, fold: 455.5...495.5))
    }

    func testTooNarrowForTwoPanesStaysOneColumn() {
        // The unfolded Duo held in portrait.
        XCTAssertNil(UnfoldedSplit.make(width: 669, isRegularWidth: true, fold: nil))
    }

    func testPanesMeetTheFoldEdges() {
        let split = UnfoldedSplit.make(width: 867, isRegularWidth: true, fold: 455.5...495.5)
        XCTAssertEqual(split, UnfoldedSplit(primaryWidth: 455.5, secondaryX: 495.5, secondaryWidth: 371.5))
    }

    func testNoFoldSplitsEvenly() {
        let split = UnfoldedSplit.make(width: 900, isRegularWidth: true, fold: nil)
        XCTAssertEqual(split, UnfoldedSplit(primaryWidth: 450, secondaryX: 450, secondaryWidth: 450))
    }

    func testFoldLeavingANarrowPaneFallsBackToEven() {
        let split = UnfoldedSplit.make(width: 900, isRegularWidth: true, fold: 100...140)
        XCTAssertEqual(split, UnfoldedSplit(primaryWidth: 450, secondaryX: 450, secondaryWidth: 450))
    }

    func testOddWidthKeepsEveryPoint() {
        let split = UnfoldedSplit.make(width: 951, isRegularWidth: true, fold: nil)
        XCTAssertEqual(split?.primaryWidth, 475)
        XCTAssertEqual(split?.secondaryWidth, 476)
    }

    func testPaneDefaultsToTheLatestFinish() {
        let latest = RacePane.defaultRace(in: DebugScreenshotFixtures.results)
        XCTAssertEqual(latest?.id, "demo-full-2025")
    }

    @MainActor
    func testPaneKeepsAPickedRace() {
        let pane = RacePane()
        pane.selectedID = "demo-half-2022"
        XCTAssertEqual(pane.race(in: DebugScreenshotFixtures.results)?.id, "demo-half-2022")
        pane.selectedID = "gone"
        XCTAssertEqual(pane.race(in: DebugScreenshotFixtures.results)?.id, "demo-full-2025")
    }

    func testDuoScreenOpensEverySurfaceOnASeededRace() {
        let seeded = Set(DebugScreenshotFixtures.results.map(\.id))
        for screen in DuoScreen.allCases {
            XCTAssertEqual(DuoScreen(arguments: ["app", "-DuoScreen", screen.rawValue]), screen)
            if let race = screen.race { XCTAssertTrue(seeded.contains(race), race) }
        }
        XCTAssertNil(DuoScreen(arguments: ["app", "-DuoScreen"]))
        XCTAssertNil(DuoScreen(arguments: ["app", "-DuoScreen", "paywall"]))
        XCTAssertEqual(DuoScreen.races.lockerRankings, false)
        XCTAssertEqual(DuoScreen.rankings.lockerRankings, true)
    }
}
