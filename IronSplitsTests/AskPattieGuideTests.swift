import XCTest
@testable import IM_Iron_Splits

final class AskPattieGuideTests: XCTestCase {
    func testReachableGuideIsValid() {
        XCTAssertTrue(sampleGuide.isValid)
    }

    func testGuideRejectsDeadTopicPath() {
        var broken = sampleGuide
        broken.goals[0].topics = ["missing-topic"]
        XCTAssertFalse(broken.isValid)
    }

    func testGuideRejectsAnswerForUnknownGoal() {
        var broken = sampleGuide
        broken.answers[0].goals = ["missing-goal"]
        XCTAssertFalse(broken.isValid)
    }

    private var sampleGuide: AskPattieGuide {
        AskPattieGuide(
            version: 1,
            title: "Ask Pattie",
            subtitle: "A test guide",
            goalQuestion: "What are you training for?",
            goals: [
                .init(id: "first-tri", title: "My first triathlon", subtitle: "Start here.",
                      symbol: "figure.mixed.cardio", topics: ["transitions"])
            ],
            topics: [
                .init(id: "transitions", title: "Transitions", symbol: "arrow.triangle.2.circlepath",
                      question: "What do you need help with?")
            ],
            answers: [
                .init(id: "transitions-1", topic: "transitions", goals: ["first-tri"],
                      headline: "Keep moving", situation: "The transition feels busy.",
                      solution: "Set up one simple sequence first.", pointerID: nil,
                      situationVoice: nil, solutionVoice: nil, signoffVoice: nil)
            ]
        )
    }
}
