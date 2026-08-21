import Foundation
import SwiftUI
import AVFoundation
import os

/// Pattie Mode: Pattie Wallner turning up in the app to comment on your racing.
///
/// The app exists because Pattie asked for it, and the tips it carries are hers,
/// so this is the version of the app where she is actually in the room. Every
/// portrait is a frame from one of her own Tri Pattie's Pointers clips and every
/// voice line is cut from that clip's audio — nothing here is synthesised.
///
/// It is off until switched on in Settings. Once on, the thing that keeps it fun
/// rather than exhausting is the budget: a moment can only fire when enough has
/// happened since the last one, a line never repeats until the whole deck has
/// been seen, and a given moment fires at most once per session. Interruption is
/// the whole joke, so the joke has to be rationed.
@MainActor
final class PattieMode: ObservableObject {

    /// Where in the app Pattie can appear.
    enum Moment: String, CaseIterable, Sendable {
        case welcome            // first look at the locker
        case claimed            // an athlete was just claimed
        case raceOpened         // a race detail was opened
        case personalBest       // a race detail that holds a PB
        case didNotFinish       // opened a DNF
        case worldChampionship  // opened a Kona / World Championship race
        case bests              // the Bests tab
        case resume             // the Resume tab
        case pointers           // the Pointers tab
        case paywall            // the paywall was shown
        case veteran            // a long career, ten races or more
        case refreshed          // pull to refresh
    }

    /// One thing Pattie says, with the face and the voice that go with it.
    struct Line: Identifiable, Sendable {
        let id: String
        let moment: Moment
        let portrait: String
        let text: String
        /// Bundled clip, cut from her own audio. Nil lines are silent on purpose.
        let voice: String?
    }

    // MARK: - State

    @AppStorage("pattie.mode.enabled") var isEnabled: Bool = false {
        willSet { objectWillChange.send() }
    }
    @AppStorage("pattie.mode.sound") var soundEnabled: Bool = true {
        willSet { objectWillChange.send() }
    }

    @Published private(set) var current: Line?

    private var firedThisSession: Set<Moment> = []
    private var lastFired: Date?
    private var player: AVAudioPlayer?
    private let seenKey = "pattie.mode.seenLines"
    private let logger = Logger(subsystem: "com.jackwallner.ironman", category: "PattieMode")

    /// Long enough that two taps in a row can't both summon her.
    private let quietPeriod: TimeInterval = 25

    // MARK: - Firing

    /// Offer a moment. It only lands if Pattie Mode is on, the moment hasn't
    /// already fired this session, and the quiet period has elapsed.
    func fire(_ moment: Moment) {
        guard isEnabled, current == nil else { return }
        guard !firedThisSession.contains(moment) else { return }
        if let lastFired, Date.now.timeIntervalSince(lastFired) < quietPeriod { return }
        guard let line = pick(for: moment) else { return }

        firedThisSession.insert(moment)
        lastFired = .now
        markSeen(line.id)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            current = line
        }
        play(line.voice)
    }

    func dismiss() {
        withAnimation(.easeInOut(duration: 0.22)) { current = nil }
    }

    /// Preview one immediately, ignoring the budget. Used by the Settings row so
    /// switching the toggle on shows what you just signed up for.
    func demo() {
        guard let line = Self.deck.first(where: { $0.moment == .welcome }) else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { current = line }
        play(line.voice)
    }

    /// A line for this moment, preferring ones not yet seen so the deck cycles
    /// before it repeats.
    private func pick(for moment: Moment) -> Line? {
        let candidates = Self.deck.filter { $0.moment == moment }
        guard !candidates.isEmpty else { return nil }
        let seen = seenLines
        let fresh = candidates.filter { !seen.contains($0.id) }
        return (fresh.isEmpty ? candidates : fresh).randomElement()
    }

    private var seenLines: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
    }

    private func markSeen(_ id: String) {
        var seen = seenLines
        seen.insert(id)
        // Once she has said everything, start the deck over rather than going quiet.
        if seen.count >= Self.deck.count { seen = [id] }
        UserDefaults.standard.set(Array(seen), forKey: seenKey)
    }

    // MARK: - Voice

    private func play(_ name: String?) {
        guard soundEnabled, let name,
              let url = Bundle.main.url(forResource: name, withExtension: "m4a") else { return }
        do {
            // .ambient so she never stops the podcast someone is training to.
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            logger.debug("pattie voice failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - The deck

extension PattieMode {

    /// What she says, and where.
    ///
    /// The wording follows the shape of her own clips — she opens on the
    /// situation, hands you the solution, and signs off "now that's a great
    /// idea" — because that is the format every one of the twenty-one episodes
    /// is cut to.
    static let deck: [Line] = [
        // Welcome
        Line(id: "welcome-1", moment: .welcome, portrait: "pattie-happy",
             text: "Here's the situation: your races are scattered across a dozen result pages. Here's the solution. They're all in here now.",
             voice: "pattie-here-s-the-situation"),
        Line(id: "welcome-2", moment: .welcome, portrait: "pattie-coach",
             text: "Every bib, every split, every year. No more digging through old emails the night before a race.",
             voice: nil),

        // Claim
        Line(id: "claimed-1", moment: .claimed, portrait: "pattie-excited",
             text: "There you are. That's your whole career, straight off the timing feed.",
             voice: "pattie-now-that-s-a-great-idea"),
        Line(id: "claimed-2", moment: .claimed, portrait: "pattie-happy",
             text: "Found you. Now you never have to remember a bib number again.",
             voice: "pattie-nice"),

        // Race detail
        Line(id: "race-1", moment: .raceOpened, portrait: "pattie-coach",
             text: "Look at your transitions. That's free time sitting right there, and it costs nothing to practise.",
             voice: nil),
        Line(id: "race-2", moment: .raceOpened, portrait: "pattie-ride",
             text: "The bike is where the day is won or thrown away. Everything after it is just holding on.",
             voice: "pattie-bike"),
        Line(id: "race-3", moment: .raceOpened, portrait: "pattie-ready",
             text: "Splits don't lie. They just don't tell you how hot it was that day.",
             voice: nil),

        // Personal best
        Line(id: "pb-1", moment: .personalBest, portrait: "pattie-podium",
             text: "That's a personal best. Go on, look at it for a minute. You earned that one.",
             voice: "pattie-that-s-a-great-idea"),
        Line(id: "pb-2", moment: .personalBest, portrait: "pattie-excited",
             text: "Best you've ever gone at that distance. Now that's a great idea.",
             voice: "pattie-now-that-s-a-great-idea"),

        // DNF
        Line(id: "dnf-1", moment: .didNotFinish, portrait: "pattie-oops",
             text: "A DNF is a day, not a verdict. I've had mine. The next one still counts the same.",
             voice: nil),
        Line(id: "dnf-2", moment: .didNotFinish, portrait: "pattie-grit",
             text: "Everybody who races long enough collects one of these. It stays on the record and so do you.",
             voice: nil),

        // World Championship
        Line(id: "worlds-1", moment: .worldChampionship, portrait: "pattie-podium",
             text: "A World Championship start line. Not many people get one of those on their record.",
             voice: "pattie-good"),

        // Bests
        Line(id: "bests-1", moment: .bests, portrait: "pattie-coach",
             text: "Best swim, best bike, best run, all scoped to the right distance. A half and a full were never the same race.",
             voice: nil),
        Line(id: "bests-2", moment: .bests, portrait: "pattie-grit",
             text: "Sorted by your fastest leg. This is the list you quote at dinner.",
             voice: "pattie-nice"),

        // Resume
        Line(id: "resume-1", moment: .resume, portrait: "pattie-ready",
             text: "Here's the situation: a race wants your history for validation. Here's the solution. Export it and send it.",
             voice: "pattie-here-s-the-solution"),

        // Pointers
        Line(id: "pointers-1", moment: .pointers, portrait: "pattie-happy",
             text: "These are my pointers. Little things that cost nothing and save your whole day.",
             voice: "pattie-away-you-go"),

        // Paywall
        Line(id: "paywall-1", moment: .paywall, portrait: "pattie-coach",
             text: "The free three get you started. The rest of your career is behind this, and so are all my pointers.",
             voice: nil),

        // Long career
        Line(id: "veteran-1", moment: .veteran, portrait: "pattie-grit",
             text: "That is a lot of start lines. Most people talk about doing one of these. You kept going back.",
             voice: "pattie-good"),

        // Refresh
        Line(id: "refresh-1", moment: .refreshed, portrait: "pattie-ride",
             text: "Pulled it again, straight from the timers. If your latest race isn't here, they haven't posted it yet.",
             voice: nil),
    ]
}
