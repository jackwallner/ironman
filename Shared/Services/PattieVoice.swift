import AVFoundation
import Foundation
import os

/// Plays Pattie's bundled voice clips, and tells the UI when she is talking.
///
/// One player for the whole app. Pattie's companion and the Ask Pattie answers
/// both go through it, so intentional playback never leaves two takes talking
/// over each other.
///
/// Every clip is cut from her own episodes. `PattieVoiceLibrary` holds the
/// names; nothing here synthesises anything.
@MainActor
final class PattieVoice: NSObject, ObservableObject {
    static let shared = PattieVoice()

    /// The clip currently playing, so a view can draw a speaking state and a
    /// play button can turn into a stop button.
    @Published private(set) var nowPlaying: String?

    private var player: AVAudioPlayer?
    private var fadeTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.jackwallner.ironman", category: "PattieVoice")

    private override init() { super.init() }

    var isSpeaking: Bool { nowPlaying != nil }

    func isPlaying(_ name: String?) -> Bool {
        guard let name else { return false }
        return nowPlaying == name
    }

    /// Prepare the audio session off the main thread.
    ///
    /// `setCategory` and `setActive` both talk to the media daemon and both can
    /// block for hundreds of milliseconds. Calling them on the main thread is
    /// what "AVAudioSession Hang Risk" in the console is warning about, and
    /// Pattie's first line can land within a second of launch, so on the main
    /// thread it lands inside the first frame the app ever draws.
    ///
    /// Playback uses `.mixWithOthers` so she never stops the podcast somebody
    /// is training to. Unlike `.ambient`, `.playback` remains audible when the
    /// hardware Silent switch is on, which also lets episode video share this
    /// session.
    nonisolated static func prepareSession() {
        sessionQueue.async {
            _ = configureSession()
        }
    }

    /// Activate the session and wait for the media daemon before starting a
    /// player. This closes the race where `AVAudioPlayer.play()` or
    /// `AVPlayer.play()` ran before the session finished activating.
    nonisolated static func activateSession() async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                continuation.resume(returning: configureSession())
            }
        }
    }

    private nonisolated static let sessionQueue = DispatchQueue(label: "com.jackwallner.ironman.pattie.audio")
    private nonisolated static let sessionLogger = Logger(
        subsystem: "com.jackwallner.ironman",
        category: "PattieAudioSession"
    )

    private nonisolated static func configureSession() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
            return true
        } catch {
            sessionLogger.debug("audio session setup failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Play a bundled clip. A nil name is a silent line and is not an error.
    @discardableResult
    func play(_ name: String?) -> Bool {
        guard let name, let url = Bundle.main.url(forResource: name, withExtension: "m4a") else {
            if let name { logger.debug("missing clip \(name, privacy: .public)") }
            return false
        }
        stop()
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.volume = 1
            newPlayer.prepareToPlay()
            self.player = newPlayer
            nowPlaying = name

            Task { @MainActor [weak self] in
                guard let self else { return }
                guard await Self.activateSession() else {
                    guard self.player === newPlayer else { return }
                    self.stop()
                    return
                }
                guard self.player === newPlayer, self.nowPlaying == name else { return }
                newPlayer.play()
            }
            return true
        } catch {
            logger.debug("play failed: \(error.localizedDescription, privacy: .public)")
            nowPlaying = nil
            return false
        }
    }

    /// Play if she isn't already talking, so a screen appearing behind an
    /// already-running line doesn't cut her off mid-sentence.
    @discardableResult
    func playIfQuiet(_ name: String?) -> Bool {
        guard !isSpeaking else { return false }
        return play(name)
    }

    /// Toggle: tapping the clip that is playing stops it.
    func toggle(_ name: String?) {
        guard let name else { return }
        if nowPlaying == name { stop() } else { play(name) }
    }

    func stop() {
        fadeTask?.cancel()
        fadeTask = nil
        guard let oldPlayer = player else {
            nowPlaying = nil
            return
        }
        oldPlayer.setVolume(0, fadeDuration: 0.04)
        player = nil
        nowPlaying = nil
        fadeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            oldPlayer.stop()
        }
    }
}

extension PattieVoice: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedPath = player.url?.path
        Task { @MainActor in
            guard self.player?.url?.path == finishedPath else { return }
            self.nowPlaying = nil
            self.player = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let failedPath = player.url?.path
        Task { @MainActor in
            guard self.player?.url?.path == failedPath else { return }
            self.nowPlaying = nil
            self.player = nil
        }
    }
}

/// The complete real tips available to Pattie Mode.
///
/// The catalog is the same answer tree used by Ask Pattie. Each entry pairs the
/// exact solution text with the complete solution clip cut from that pointer,
/// so the companion never shows one tip while speaking a different phrase.
enum PattieVoiceLibrary {
    struct ModeTip: Identifiable, Equatable, Sendable {
        let id: String
        let topic: String
        let text: String
        let voice: String
    }

    /// Every bundled answer with a complete solution recording. There are
    /// nineteen distinct solution clips across the answer tree, with repeated
    /// clips retaining their different, useful text.
    static let modeTips: [ModeTip] = loadModeTips()

    /// Rotate through distinct real solution recordings before reusing one.
    static func nextModeTip(excluding usedVoices: Set<String>) -> ModeTip? {
        let fresh = modeTips.filter { !usedVoices.contains($0.voice) }
        return (fresh.isEmpty ? modeTips : fresh).first
    }

    private static func loadModeTips() -> [ModeTip] {
        let bundles = [Bundle.main, Bundle(for: PattieVoice.self)]

        for bundle in bundles {
            guard let url = bundle.url(forResource: "ask-pattie", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let guide = try? JSONDecoder().decode(AskPattieGuide.self, from: data) else {
                continue
            }

            let tips = guide.answers.compactMap { answer -> ModeTip? in
                guard let voice = answer.solutionVoice, !answer.solution.isEmpty else { return nil }
                return ModeTip(id: answer.id,
                               topic: answer.topic,
                               text: answer.solution,
                               voice: voice)
            }
            if !tips.isEmpty { return tips }
        }

        return []
    }
}
