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

    func testPattieModeUsesRealSolutionTips() {
        let tips = PattieVoiceLibrary.modeTips

        XCTAssertGreaterThanOrEqual(tips.count, 19)
        XCTAssertGreaterThanOrEqual(Set(tips.map(\.voice)).count, 19)
        XCTAssertTrue(tips.allSatisfy { $0.voice.hasPrefix("pattie-solution-") })
        XCTAssertTrue(tips.allSatisfy { !$0.text.isEmpty })
    }

    func testSolutionTipRotationUsesDifferentRealRecordings() throws {
        var used = Set<String>()
        let first = try XCTUnwrap(PattieVoiceLibrary.nextModeTip(excluding: used))
        used.insert(first.voice)
        let second = try XCTUnwrap(PattieVoiceLibrary.nextModeTip(excluding: used))

        XCTAssertNotEqual(first.voice, second.voice)
        XCTAssertNotEqual(first.text, second.text)
    }
}
