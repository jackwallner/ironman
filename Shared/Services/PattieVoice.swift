import AVFoundation
import Foundation
import os

/// Plays Pattie's bundled voice clips, and tells the UI when she is talking.
///
/// One player for the whole app. Pattie Mode's popup and the Ask Pattie answers
/// both go through it, so starting one line always stops the last one instead
/// of leaving two takes of her talking over each other.
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
    private let logger = Logger(subsystem: "com.jackwallner.ironman", category: "PattieVoice")

    private override init() { super.init() }

    var isSpeaking: Bool { nowPlaying != nil }

    func isPlaying(_ name: String?) -> Bool {
        guard let name else { return false }
        return nowPlaying == name
    }

    /// Configure the audio session, once, off the main thread.
    ///
    /// `setCategory` and `setActive` both talk to the media daemon and both can
    /// block for hundreds of milliseconds. Calling them on the main thread is
    /// what "AVAudioSession Hang Risk" in the console is warning about, and
    /// Pattie's first line can land within a second of launch, so on the main
    /// thread it lands inside the first frame the app ever draws.
    ///
    /// `.ambient` with `.mixWithOthers` so she never stops the podcast somebody
    /// is training to.
    nonisolated static func prepareSession() {
        sessionQueue.async {
            guard !sessionConfigured else { return }
            sessionConfigured = true
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                sessionConfigured = false
            }
        }
    }

    private nonisolated static let sessionQueue = DispatchQueue(label: "com.jackwallner.ironman.pattie.audio")
    /// Only ever touched on `sessionQueue`.
    private nonisolated(unsafe) static var sessionConfigured = false

    /// Play a bundled clip. A nil name is a silent line and is not an error.
    @discardableResult
    func play(_ name: String?) -> Bool {
        guard let name, let url = Bundle.main.url(forResource: name, withExtension: "m4a") else {
            if let name { logger.debug("missing clip \(name, privacy: .public)") }
            return false
        }
        stop()
        Self.prepareSession()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            self.player = player
            nowPlaying = name
            player.play()
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
        player?.stop()
        player = nil
        nowPlaying = nil
    }
}

extension PattieVoice: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.nowPlaying = nil
            self.player = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.nowPlaying = nil
            self.player = nil
        }
    }
}

/// The names of every clip in the bundle, grouped by what it is.
///
/// The three families come from the shape every episode is cut to: she opens on
/// the situation, hands over the solution, and signs off "now that's a great
/// idea". `signoffs` is the one that matters for Pattie Mode: nineteen separate
/// takes of the same line, so she can react to something without ever landing
/// on the same recording twice in a session.
enum PattieVoiceLibrary {
    /// Short reactions, roughly a second and a half each.
    static let signoffs: [String] = [
        "pattie-signoff-01", "pattie-signoff-02", "pattie-signoff-03", "pattie-signoff-04",
        "pattie-signoff-05", "pattie-signoff-07", "pattie-signoff-08", "pattie-signoff-09",
        "pattie-signoff-10", "pattie-signoff-11", "pattie-signoff-12", "pattie-signoff-13",
        "pattie-signoff-15", "pattie-signoff-16", "pattie-signoff-17", "pattie-signoff-18",
        "pattie-signoff-19", "pattie-signoff-20",
    ]

    /// The short phrases cut from the highlight reel, kept from the first pass.
    static let phrases: [String] = [
        "pattie-away-you-go", "pattie-bike", "pattie-good", "pattie-great-idea",
        "pattie-here-s-the-situation", "pattie-here-s-the-solution", "pattie-nice",
        "pattie-now-that-s-a-great-idea", "pattie-solution", "pattie-that-s-a-great-idea",
    ]

    /// A different sign-off every time, cycling the whole deck before repeating.
    ///
    /// Nothing is more obviously canned than the same 1.4 seconds of audio on
    /// every single interaction, and there are eighteen of these, so there is no
    /// reason to ever reuse one inside a session.
    static func nextSignoff(excluding used: Set<String>) -> String {
        let fresh = signoffs.filter { !used.contains($0) }
        return (fresh.isEmpty ? signoffs : fresh).randomElement() ?? signoffs[0]
    }
}
