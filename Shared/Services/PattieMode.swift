import Foundation
import SwiftUI
import os

/// Pattie Mode: Pattie Wallner turning up in the app to comment on your racing.
///
/// The app exists because Pattie asked for it, and the tips it carries are hers,
/// so this is the version where she is actually in the room. The working portraits
/// are from her own Tri Pattie's Pointers clips, with her public profile portrait
/// reserved for the large hero popup. Every voice line is cut from her own audio.
/// Nothing here is synthesised.
///
/// It is on by default and switched off in Settings. On by default because the
/// app is named after her pointers and a personality feature nobody finds is
/// the same as one that does not exist; switchable because it interrupts, and
/// an interruption you cannot turn off is a different product.
///
/// What keeps it fun rather than exhausting is the budget: a moment needs a
/// quiet gap behind it, a line
/// never repeats until the deck has been through, and each moment has its own
/// cooldown so the same remark can come back later in a long session without
/// coming back immediately.
///
/// She talks a lot more than she used to. There are now eighteen separate takes
/// of her sign-off cut from eighteen different episodes, so a line with nothing
/// specific to say still gets a voice, and it is a different recording every
/// time.
@MainActor
final class PattieMode: ObservableObject {

    /// How much of the screen a line is allowed to take.
    enum Impact: Sendable {
        /// A card above the tab bar. The default.
        case banner
        /// She takes the screen: big portrait, dimmed background. Reserved for
        /// the handful of moments that have actually earned an interruption.
        case big
    }

    /// Where in the app Pattie can appear.
    enum Moment: String, CaseIterable, Sendable {
        case welcome            // first look at the locker
        case claimed            // an athlete was just claimed
        case searching          // the search screen, before anything is typed
        case raceOpened         // a race detail was opened
        case personalBest       // a race detail that holds a PB
        case didNotFinish       // opened a DNF
        case worldChampionship  // opened a Kona / World Championship race
        case bests              // the Bests tab
        case bestsFiltered      // changed the leg on the leaderboard
        case resume             // the Resume tab
        case resumeExported     // shared or built the resume
        case pointers           // the Pointers library
        case pointerPlayed      // started an episode
        case askOpened          // opened Ask Pattie
        case askAnswered        // reached an answer in Ask Pattie
        case noteSaved          // wrote a race note
        case veteran            // a long career, ten races or more
        case refreshed          // pull to refresh
        case settings           // the Settings tab

        /// How long before this moment is allowed to come round again.
        ///
        /// The one-shot moments are the ones whose joke does not survive a
        /// second telling in the same sitting; the rest are reactions to
        /// something the athlete just did, and going silent on those is what
        /// made the feature feel like it had switched itself off.
        var cooldown: TimeInterval {
            switch self {
            case .welcome, .claimed, .veteran:
                return .infinity
            case .personalBest, .worldChampionship, .askAnswered, .pointerPlayed:
                return 90
            default:
                return 240
            }
        }
    }

    /// One thing Pattie says, with the face and the voice that go with it.
    struct Line: Identifiable, Sendable {
        let id: String
        let moment: Moment
        let portrait: String
        let text: String
        /// Bundled clip cut from her own audio. When nil, the line still speaks:
        /// `fire` hands it one of the eighteen sign-offs instead.
        var voice: String?
        var impact: Impact = .banner
    }

    // MARK: - State

    @AppStorage("pattie.mode.enabled") var isEnabled: Bool = true {
        willSet { objectWillChange.send() }
    }
    @AppStorage("pattie.mode.sound") var soundEnabled: Bool = true {
        willSet { objectWillChange.send() }
    }

    @Published private(set) var current: Line?

    private var firedAt: [Moment: Date] = [:]
    private var usedSignoffs: Set<String> = []
    private var lastFired: Date?
    private let voice = PattieVoice.shared
    private let seenKey = "pattie.mode.seenLines"
    private let logger = Logger(subsystem: "com.jackwallner.ironman", category: "PattieMode")

    /// Long enough that two taps in a row can't both summon her, short enough
    /// that moving through three screens gets more than one line out of her.
    private let quietPeriod: TimeInterval = 10

    init() {
        #if DEBUG
        // StateObject storage can initialize before IronSplitsApp.init() resets
        // the UI-test fixture. Keep the in-memory value in step with the
        // launch arguments as well as UserDefaults.
        if ProcessInfo.processInfo.arguments.contains("-ResetLocker") {
            isEnabled = Self.isPattieModeOptedIn
        }
        #endif
    }

    // MARK: - Firing

    private static let isPattieModeOptedIn =
        ProcessInfo.processInfo.arguments.contains("-PattieMode")
        || ProcessInfo.processInfo.environment["IRONSPLITS_PATTIE_MODE"] == "1"

    /// Offer a moment. It lands if Pattie Mode is on, this moment's cooldown has
    /// expired, and the quiet period behind it has elapsed.
    func fire(_ moment: Moment) {
        guard isEnabled, current == nil else { return }
        if let last = firedAt[moment], Date.now.timeIntervalSince(last) < moment.cooldown { return }
        if let lastFired, Date.now.timeIntervalSince(lastFired) < quietPeriod { return }
        guard let line = pick(for: moment) else { return }
        present(line)
    }

    /// Preview one immediately, ignoring the budget. Used by the Settings row so
    /// switching the toggle on shows what you just signed up for.
    func demo() {
        guard var line = Self.deck.first(where: { $0.moment == .welcome }) else { return }
        line.impact = .big
        present(line, respectingBudget: false)
    }

    private func present(_ line: Line, respectingBudget: Bool = true) {
        var line = line
        // Every line speaks. One with nothing specific to say gets a sign-off,
        // and a different one each time: eighteen takes cut from eighteen
        // episodes is enough that a session never hears the same recording.
        if line.voice == nil {
            let pick = PattieVoiceLibrary.nextSignoff(excluding: usedSignoffs)
            usedSignoffs.insert(pick)
            if usedSignoffs.count >= PattieVoiceLibrary.signoffs.count { usedSignoffs = [pick] }
            line.voice = pick
        }
        if respectingBudget {
            firedAt[line.moment] = .now
            lastFired = .now
        }
        markSeen(line.id)
        withAnimation(.spring(response: 0.46, dampingFraction: 0.74)) {
            current = line
        }
        Haptics.tap(.soft)
        if soundEnabled { voice.play(line.voice) }
    }

    func replayVoice() {
        guard let current, soundEnabled else { return }
        voice.toggle(current.voice)
    }

    func dismiss() {
        voice.stop()
        withAnimation(.easeInOut(duration: 0.24)) { current = nil }
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
}

// MARK: - The deck

extension PattieMode {

    /// What she says, and where.
    ///
    /// The wording follows the shape of her own clips: she opens on the
    /// situation, hands you the solution, and signs off "now that's a great
    /// idea", because that is the format every one of the episodes is cut to.
    ///
    /// A `voice` of nil is not a silent line. It means "no specific clip fits,
    /// use a sign-off", which `present(_:)` fills in.
    static let deck: [Line] = [
        // Welcome
        Line(id: "welcome-1", moment: .welcome, portrait: "pattie-profile",
             text: "Here's the situation: your races are scattered across a dozen result pages. Here's the solution. They're all in here now.",
             voice: "pattie-here-s-the-situation", impact: .big),
        Line(id: "welcome-2", moment: .welcome, portrait: "pattie-profile",
             text: "Every bib, every split, every year. No more digging through old emails the night before a race.",
             voice: "pattie-here-s-the-solution", impact: .big),

        // Search
        Line(id: "search-1", moment: .searching, portrait: "pattie-ready",
             text: "Type your name the way you registered. Full legal first name, usually, whether you like it or not."),
        Line(id: "search-2", moment: .searching, portrait: "pattie-excited",
             text: "Surname first works too. I've spelled mine both ways on an entry form and so has everyone else."),

        // Claim
        Line(id: "claimed-1", moment: .claimed, portrait: "pattie-excited",
             text: "There you are. That's your whole career, straight off the timing feed.",
             voice: "pattie-now-that-s-a-great-idea", impact: .big),
        Line(id: "claimed-2", moment: .claimed, portrait: "pattie-profile",
             text: "Found you. Now you never have to remember a bib number again.",
             voice: "pattie-nice", impact: .big),

        // Race detail
        Line(id: "race-1", moment: .raceOpened, portrait: "pattie-ready",
             text: "Look at your transitions. That's free time sitting right there, and it costs nothing to practise."),
        Line(id: "race-2", moment: .raceOpened, portrait: "pattie-ride",
             text: "The bike is where the day is won or thrown away. Everything after it is just holding on.",
             voice: "pattie-bike"),
        Line(id: "race-3", moment: .raceOpened, portrait: "pattie-ready",
             text: "Splits don't lie. They just don't tell you how hot it was that day."),
        Line(id: "race-4", moment: .raceOpened, portrait: "pattie-grit",
             text: "Somewhere in this one there's a mile you'd rather not talk about. There is in all of mine too."),

        // Personal best
        Line(id: "pb-1", moment: .personalBest, portrait: "pattie-profile",
             text: "That's a personal best. Go on, look at it for a minute. You earned that one.",
             voice: "pattie-that-s-a-great-idea", impact: .big),
        Line(id: "pb-2", moment: .personalBest, portrait: "pattie-excited",
             text: "Best you've ever gone at that distance. Now that's a great idea.",
             voice: "pattie-now-that-s-a-great-idea", impact: .big),

        // DNF
        Line(id: "dnf-1", moment: .didNotFinish, portrait: "pattie-ready",
             text: "A DNF is a day, not a verdict. I've had mine. The next one still counts the same."),
        Line(id: "dnf-2", moment: .didNotFinish, portrait: "pattie-grit",
             text: "Everybody who races long enough collects one of these. It stays on the record and so do you."),

        // World Championship
        Line(id: "worlds-1", moment: .worldChampionship, portrait: "pattie-profile",
             text: "A World Championship start line. Not many people get one of those on their record.",
             voice: "pattie-good", impact: .big),

        // Bests
        Line(id: "bests-1", moment: .bests, portrait: "pattie-excited",
             text: "Best swim, best bike, best run, all scoped to the right distance. A half and a full were never the same race."),
        Line(id: "bests-2", moment: .bests, portrait: "pattie-grit",
             text: "Sorted by your fastest leg. This is the list you quote at dinner.",
             voice: "pattie-nice"),
        Line(id: "bests-filter-1", moment: .bestsFiltered, portrait: "pattie-ready",
             text: "Different leg, different story. The transitions one is the list nobody wants to look at."),
        Line(id: "bests-filter-2", moment: .bestsFiltered, portrait: "pattie-excited",
             text: "Watch the gap column. That number is the whole training plan in one line."),

        // Resume
        Line(id: "resume-1", moment: .resume, portrait: "pattie-ready",
             text: "Here's the situation: a race wants your history for validation. Here's the solution. Export it and send it.",
             voice: "pattie-here-s-the-solution"),
        Line(id: "resume-2", moment: .resumeExported, portrait: "pattie-excited",
             text: "That's the sheet they ask for, in one tap. Away you go.",
             voice: "pattie-away-you-go"),

        // Pointers
        Line(id: "pointers-1", moment: .pointers, portrait: "pattie-ready",
             text: "These are my pointers. Little things that cost nothing and save your whole day.",
             voice: "pattie-away-you-go"),
        Line(id: "pointers-2", moment: .pointers, portrait: "pattie-excited",
             text: "Every one of these is something that went wrong for me first. That's how the list got written."),
        Line(id: "pointer-played-1", moment: .pointerPlayed, portrait: "pattie-ready",
             text: "Here's the situation, and then here's the solution. That's the whole format."),

        // Ask Pattie
        Line(id: "ask-1", moment: .askOpened, portrait: "pattie-profile",
             text: "Tell me what you're training for and what's bothering you. I've probably already made a clip about it.",
             voice: "pattie-here-s-the-situation", impact: .big),
        Line(id: "ask-2", moment: .askOpened, portrait: "pattie-ready",
             text: "Pick the race, pick the problem. No typing, and no waiting on me to answer."),
        Line(id: "ask-answered-1", moment: .askAnswered, portrait: "pattie-excited",
             text: "That's the one. Tap play and you'll get it in my own words.",
             voice: "pattie-here-s-the-solution"),
        Line(id: "ask-answered-2", moment: .askAnswered, portrait: "pattie-ready",
             text: "Try it on a training day first. Race day is a bad time to learn a new trick."),

        // Notes
        Line(id: "note-1", moment: .noteSaved, portrait: "pattie-ready",
             text: "Write down the conditions while you still remember them. In two years that note is worth more than the time."),

        // Long career
        Line(id: "veteran-1", moment: .veteran, portrait: "pattie-grit",
             text: "That is a lot of start lines. Most people talk about doing one of these. You kept going back.",
             voice: "pattie-good", impact: .big),

        // Refresh
        Line(id: "refresh-1", moment: .refreshed, portrait: "pattie-ride",
             text: "Pulled it again, straight from the timers. If your latest race isn't here, they haven't posted it yet."),

        // Settings
        Line(id: "settings-1", moment: .settings, portrait: "pattie-ready",
             text: "If I'm getting on your nerves there's a switch on this very screen. No hard feelings."),
    ]
}
