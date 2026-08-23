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

    func testExistingPetImageMappingsRemainStable() {
        XCTAssertEqual(PattiePetState.idle.imageName, "pattie-pet-idle")
        XCTAssertEqual(PattiePetState.coach.imageName, "pattie-pet-coach")
        XCTAssertEqual(PattiePetState.celebrate.imageName, "pattie-pet-celebrate")
        XCTAssertEqual(PattiePetState.encourage.imageName, "pattie-pet-encourage")
        XCTAssertEqual(PattiePetState.shoes.imageName, "pattie-pet-shoes")
        XCTAssertEqual(PattiePetState.swim.imageName, "pattie-pet-swim")
        XCTAssertEqual(PattiePetState.bike.imageName, "pattie-pet-bike")
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

    func testSolutionTipRotationUsesDifferentTips() throws {
        var used = Set<String>()
        let first = try XCTUnwrap(PattieVoiceLibrary.nextModeTip(excludingIDs: used))
        used.insert(first.id)
        let second = try XCTUnwrap(PattieVoiceLibrary.nextModeTip(excludingIDs: used))

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertNotEqual(first.text, second.text)
    }

    func testSolutionTipRotationUsesEveryTipBeforeStartingAnotherCycle() throws {
        let tips = PattieVoiceLibrary.modeTips
        var played = Set<String>()

        for _ in tips {
            let tip = try XCTUnwrap(PattieVoiceLibrary.nextModeTip(excludingIDs: played))
            XCTAssertFalse(played.contains(tip.id))
            played.insert(tip.id)
        }

        let next = try XCTUnwrap(PattieVoiceLibrary.nextModeTip(excludingIDs: played))
        XCTAssertTrue(tips.contains(where: { $0.id == next.id }))
    }

    func testPointerPlaybackBlocksPattieUntilTheVideoEnds() {
        let mode = PattieMode()
        mode.isEnabled = true
        defer {
            mode.dismiss()
            mode.isEnabled = false
            UserDefaults.standard.removeObject(forKey: "pattie.mode.playedTipIDs")
            UserDefaults.standard.removeObject(forKey: "pattie.mode.lastTipID")
        }

        mode.beginPointerPlayback()
        mode.fire(.searching)
        XCTAssertNil(mode.current)

        mode.endPointerPlayback()
        mode.fire(.searching)
        XCTAssertNotNil(mode.current)
    }

    func testActiveMotionCycleCoversTriathlonAndCompanionStates() {
        XCTAssertEqual(PattiePetState.activeMotionStates, [
            .warmup, .swim, .transition, .bike, .run, .finish,
            .dance, .hydrate, .stretch, .recovery
        ])
        XCTAssertEqual(Set(PattiePetState.activeMotionStates).count,
                       PattiePetState.activeMotionStates.count)
    }

    func testMotionSelectionWrapsDeterministically() {
        let states = PattiePetState.activeMotionStates

        XCTAssertEqual(PattiePetState.motionState(at: 0), states[0])
        XCTAssertEqual(PattiePetState.motionState(at: states.count), states[0])
        XCTAssertEqual(PattiePetState.motionState(at: -1), states[states.count - 1])
        XCTAssertEqual(PattiePetState.nextMotionState(after: .run), .finish)
        XCTAssertEqual(PattiePetState.nextMotionState(after: .recovery), .warmup)
        XCTAssertEqual(PattiePetState.nextMotionState(after: .idle), .warmup)
    }

    func testMotionSequenceAndRotationHelpersAreBounded() {
        let sequence = PattiePetState.motionStates(startingAt: .bike, count: 100)

        XCTAssertEqual(sequence.count, PattiePetState.activeMotionStates.count)
        XCTAssertEqual(sequence.first, .bike)
        XCTAssertEqual(PattiePetState.motionStates(count: 0), [])
        XCTAssertEqual(PattiePetState.rotation(for: .dance), 6)
        XCTAssertTrue(PattiePetState.run.isActiveMotion)
        XCTAssertFalse(PattiePetState.idle.isActiveMotion)
    }

    func testMotionProfilesStayWithinBoundedAnimationLimits() {
        for state in PattiePetState.activeMotionStates {
            let profile = state.motionProfile

            XCTAssertGreaterThan(profile.duration, 0)
            XCTAssertLessThanOrEqual(profile.duration, 1.1)
            XCTAssertLessThanOrEqual(abs(profile.rotationDegrees), 6)
            XCTAssertLessThanOrEqual(abs(profile.horizontalShift), 1)
            XCTAssertLessThanOrEqual(profile.verticalLift, 1)
        }
    }

    func testNewStatesUseBundledPetImagesAndActiveAccessories() {
        XCTAssertEqual(PattiePetState.run.imageName, "pattie-pet-encourage")
        XCTAssertEqual(PattiePetState.transition.imageName, "pattie-pet-shoes")
        XCTAssertEqual(PattiePetState.finish.imageName, "pattie-pet-celebrate")
        XCTAssertEqual(PattiePetState.dance.imageName, "pattie-pet-celebrate")
        XCTAssertEqual(PattiePetState.run.accessorySymbol, "figure.run")
        XCTAssertEqual(PattiePetState.transition.accessorySymbol,
                       "arrow.triangle.2.circlepath")
        XCTAssertEqual(PattiePetState.finish.accessorySymbol, "flag.checkered")
        XCTAssertEqual(PattiePetState.dance.accessorySymbol, "music.note")
    }
}
