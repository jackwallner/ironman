import AVFoundation
import XCTest
@testable import IM_Iron_Splits

/// A hosted-content fetch cancelled by leaving its screen must not be stamped
/// as a failed attempt, or the next real try is held off for hours.
@MainActor
final class CancelledFetchTests: XCTestCase {
    private let dateKeys = ["pointers.catalog.cachedAt", "askpattie.guide.cachedAt"]

    override func setUp() {
        super.setUp()
        dateKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        dateKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    func testCancelledPointerFetchDoesNotStampAttempt() async {
        let task = Task { await PointerLibrary.shared.refresh(force: true) }
        task.cancel()
        _ = await task.value
        XCTAssertNil(UserDefaults.standard.object(forKey: "pointers.catalog.cachedAt"))
    }

    func testCancelledAskPattieFetchDoesNotStampAttempt() async {
        let task = Task { await AskPattieLibrary.shared.refresh(force: true) }
        task.cancel()
        let guide = await task.value
        XCTAssertNil(UserDefaults.standard.object(forKey: "askpattie.guide.cachedAt"))
        XCTAssertTrue(guide.isValid, "falls back to the bundled guide")
    }

    func testAudioInterruptionClearsSpeakingState() async throws {
        let voice = PattieVoice.shared
        XCTAssertTrue(voice.play("pattie-good"))
        XCTAssertTrue(voice.isSpeaking)

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertFalse(voice.isSpeaking)
    }
}
