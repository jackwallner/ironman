import XCTest
@testable import IM_Iron_Splits

@MainActor
final class PattiePetStateTests: XCTestCase {
    func testPointerTopicsUseStableVisualStates() {
        XCTAssertEqual(PattiePetState.forPointerID("ep-17"), .shoes)
        XCTAssertEqual(PattiePetState.forPointerID("ep-13"), .swim)
        XCTAssertEqual(PattiePetState.forPointerID("ep-09"), .bike)
        XCTAssertEqual(PattiePetState.forPointerID("ep-03"), .coach)
    }

    func testAskTopicsUseStableVisualStates() {
        XCTAssertEqual(PattiePetState.forTopicID("feet"), .shoes)
        XCTAssertEqual(PattiePetState.forTopicID("swim-gear"), .swim)
        XCTAssertEqual(PattiePetState.forTopicID("bike-trouble"), .bike)
        XCTAssertEqual(PattiePetState.forTopicID("run-form"), .encourage)
    }

    func testDeckMomentsHaveFlatteringStates() {
        let best = PattieMode.Line(
            id: "pb-1",
            moment: .personalBest,
            portrait: "pattie-profile",
            text: "You earned that one."
        )
        let dnf = PattieMode.Line(
            id: "dnf-1",
            moment: .didNotFinish,
            portrait: "pattie-profile",
            text: "The next one still counts."
        )

        XCTAssertEqual(best.defaultPetState, .celebrate)
        XCTAssertEqual(dnf.defaultPetState, .encourage)
    }

    func testActionVoicesRotateInsteadOfUsingTheDefaultSignoff() {
        let first = PattieVoiceLibrary.nextReaction(action: .tap, moment: .action, excluding: [])
        let second = PattieVoiceLibrary.nextReaction(action: .tap, moment: .action, excluding: [first])

        XCTAssertTrue(PattieVoiceLibrary.actionPhrases[.tap]?.contains(first) == true)
        XCTAssertTrue(PattieVoiceLibrary.actionPhrases[.tap]?.contains(second) == true)
        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(first, "pattie-now-that-s-a-great-idea")
    }

    func testPattieModeUsesCompleteShortRecordings() {
        let clips = PattieVoiceLibrary.modeCatchphrases

        XCTAssertEqual(Set(clips).count, clips.count)
        XCTAssertFalse(clips.contains { $0.hasPrefix("pattie-hook-") })
        XCTAssertFalse(clips.contains { $0.hasPrefix("pattie-solution-") })
        XCTAssertGreaterThanOrEqual(PattieVoiceLibrary.signoffs.count, 18)
    }

    func testCatchphraseDeckRotatesInOrderBeforeRepeating() {
        var used = Set<String>()
        let first = PattieVoiceLibrary.nextCatchphrase(excluding: used)
        used.insert(first)
        let second = PattieVoiceLibrary.nextCatchphrase(excluding: used)

        XCTAssertEqual(first, PattieVoiceLibrary.modeCatchphrases[0])
        XCTAssertEqual(second, PattieVoiceLibrary.modeCatchphrases[1])
    }
}
