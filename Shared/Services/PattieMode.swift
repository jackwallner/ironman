import Foundation
import SwiftUI

/// Pattie Mode: Pattie Wallner turning up in the app to comment on your racing.
///
/// The app exists because Pattie asked for it, and the tips it carries are hers,
/// so this is the version where she is actually in the room. The companion keeps
/// a small Pattie pet in the corner and shows one useful tip at a time.
/// Every voice line is cut from her own audio. Nothing here is synthesised.
///
/// It is off on a first install and switched on in Settings. The people who want
/// a talkative coach can invite her in, and everybody else gets the results app
/// without an unexpected personality on top of it.
///
/// What keeps it fun rather than exhausting is the budget: a moment needs a
/// quiet gap behind it, a line never repeats until the deck has been through,
/// and each moment has its own cooldown so the same remark can come back later
/// in a long session without coming back immediately.
///
/// Each automatic line is paired with a complete solution recording from the
/// Ask Pattie answer tree. The event deck decides when a tip appears, while the
/// tip catalog decides what useful thing she says.
@MainActor
final class PattieMode: ObservableObject {

    /// Deck priority retained for semantic moments. Every line is presented
    /// through the same lightweight, nonmodal companion.
    enum Impact: Sendable {
        /// A normal companion reaction.
        case banner
        /// A moment with extra emotional weight, still without blocking content.
        case big
    }

    /// Where in the app Pattie can appear.
    enum Moment: String, CaseIterable, Sendable {
        case action             // a small reaction to a user interaction
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
        case resumeExported     // built or shared the Race Book
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
            case .action:
                return 2.5
            case .welcome, .claimed, .veteran:
                return .infinity
            case .personalBest, .worldChampionship, .askAnswered, .pointerPlayed:
                return 90
            default:
                return 240
            }
        }
    }

    /// The little things Pattie can notice without taking over the screen.
    enum Action: String, CaseIterable, Sendable {
        case tab
        case filter
        case selection
        case search
        case choice
        case save
        case export
        case play
        case refresh
        case tap
        case back

        var cooldown: TimeInterval { 0.9 }
    }

    /// One thing Pattie says, with the face and the voice that go with it.
    struct Line: Identifiable, Sendable {
        let id: String
        let moment: Moment
        let portrait: String
        var text: String
        /// Bundled clip cut from her own audio. `present` replaces placeholder
        /// event copy with a complete solution tip when one is available.
        var voice: String?
        var impact: Impact = .banner
        var action: Action? = nil
        var petState: PattiePetState = .idle

        /// The stable, content-backed state used when a caller has not
        /// supplied a more specific pointer or topic state.
        var defaultPetState: PattiePetState {
            switch id {
            case "claimed-1", "claimed-2", "pb-1", "pb-2", "worlds-1", "veteran-1",
                 "resume-2":
                return .celebrate
            case "dnf-1", "dnf-2", "race-4", "ask-answered-2":
                return .encourage
            case "race-2", "refresh-1":
                return .bike
            case "bests-1", "bests-2", "bests-filter-1", "bests-filter-2",
                 "search-1", "search-2", "resume-1", "pointers-1", "pointers-2",
                 "pointer-played-1", "ask-1", "ask-2":
                return .coach
            case "action-tab-1", "action-tab-2", "action-filter-1", "action-filter-2",
                 "action-selection-1", "action-selection-2", "action-search-1", "action-search-2",
                 "action-choice-1", "action-choice-2":
                return .coach
            case "action-save-1", "action-save-2", "action-export-1", "action-export-2",
                 "note-1":
                return .encourage
            case "action-play-1", "action-play-2", "action-refresh-1", "action-refresh-2",
                 "action-tap-1", "action-tap-2", "welcome-1", "welcome-2":
                return .idle
            case "race-1", "race-3", "settings-1":
                return .coach
            default:
                return .idle
            }
        }
    }

    // MARK: - State

    @Published var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            UserDefaults.standard.set(isEnabled, forKey: "pattie.mode.enabled")
            if !isEnabled { dismiss() }
        }
    }

    @Published private(set) var current: Line?

    private var firedAt: [Moment: Date] = [:]
    private var firedActions: [Action: Date] = [:]
    private var usedModeTipVoices: Set<String> = []
    private var lastFired: Date?
    private let voice = PattieVoice.shared
    private let seenKey = "pattie.mode.seenLines"
    /// Long enough that two taps in a row cannot both summon her, short enough
    /// that moving through three screens still gets more than one line out of
    /// her.
    private let quietPeriod: TimeInterval = 0.9

    init() {
        let storedIsEnabled = UserDefaults.standard.object(forKey: "pattie.mode.enabled") as? Bool ?? false
        _isEnabled = Published(initialValue: storedIsEnabled)

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

    /// Offer a meaningful screen moment. It lands if Pattie Mode is on, the
    /// moment's cooldown has expired, and the quiet period behind it has elapsed.
    func fire(_ moment: Moment, petState: PattiePetState? = nil) {
        guard isEnabled, current == nil, !voice.isSpeaking else { return }
        if let last = firedAt[moment], Date.now.timeIntervalSince(last) < moment.cooldown { return }
        if let lastFired, Date.now.timeIntervalSince(lastFired) < quietPeriod { return }
        guard let line = pick(for: moment) else { return }
        present(line, petState: petState)
    }

    /// React to a small interaction by replacing the current bubble in place.
    /// The companion never stacks cards, and a speaking clip gets to finish
    /// before another reaction can appear.
    func react(_ action: Action, petState: PattiePetState? = nil) {
        guard isEnabled, !voice.isSpeaking else { return }
        if let last = firedActions[action], Date.now.timeIntervalSince(last) < action.cooldown {
            return
        }
        if action != .back {
            if let lastFired, Date.now.timeIntervalSince(lastFired) < quietPeriod { return }
        }
        guard let line = pick(for: action) else { return }
        present(line, petState: petState)
    }

    /// Preview one immediately, ignoring the budget. Used by Settings and the
    /// idle avatar so switching Pattie on feels like an invitation, not a new
    /// modal screen.
    func demo() {
        guard let line = Self.deck.first(where: { $0.action == .tap }) else { return }
        present(line, respectingBudget: false)
    }

    private func present(_ line: Line,
                         respectingBudget: Bool = true,
                         petState: PattiePetState? = nil) {
        guard !voice.isSpeaking else { return }
        var line = line
        line.petState = petState ?? line.defaultPetState
        // The event deck controls timing. The real answer tree controls the
        // visible tip and the matching complete solution recording.
        if let tip = PattieVoiceLibrary.nextModeTip(excluding: usedModeTipVoices) {
            usedModeTipVoices.insert(tip.voice)
            line.text = tip.text
            line.voice = tip.voice
            line.petState = petState ?? .forTopicID(tip.topic)
        } else {
            line.petState = petState ?? line.defaultPetState
        }
        if respectingBudget {
            firedAt[line.moment] = .now
            if let action = line.action { firedActions[action] = .now }
            lastFired = .now
        }
        markSeen(line.id)
        withAnimation(.spring(response: 0.46, dampingFraction: 0.74)) {
            current = line
        }
        Haptics.tap(.soft)
        voice.playIfQuiet(line.voice)
    }

    func replayVoice() {
        guard let current else { return }
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
        return pick(from: candidates)
    }

    private func pick(for action: Action) -> Line? {
        let candidates = Self.deck.filter { $0.action == action }
        return pick(from: candidates)
    }

    private func pick(from candidates: [Line]) -> Line? {
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

    /// The event deck determines when she appears. `present` supplies the
    /// actual tip text and matching recording from the Ask Pattie catalog.
    ///
    /// The wording follows the shape of her own clips: she opens on the
    /// situation, hands you the solution, and signs off "now that's a great
    /// idea", because that is the format every one of the episodes is cut to.
    ///
    /// The text and voice values below are fallback copy for a missing catalog.
    static let deck: [Line] = [
        // Small companion reactions
        Line(id: "action-tab-1", moment: .action, portrait: "pattie-profile",
             text: "Here's the situation: a race story is easier to use when the swim, bike, run, and finish stay together. Keep it all in one place.",
             action: .tab),
        Line(id: "action-tab-2", moment: .action, portrait: "pattie-profile",
             text: "Here's the solution: look at the whole pattern, not one shiny number. The useful clue is usually in the split beside it.",
             action: .tab),
        Line(id: "action-filter-1", moment: .action, portrait: "pattie-profile",
             text: "A half and a full are different races. Compare like with like before you call something your best.",
             action: .filter),
        Line(id: "action-filter-2", moment: .action, portrait: "pattie-profile",
             text: "Different leg, different story. The transition number is often the free time hiding in plain sight.",
             action: .filter),
        Line(id: "action-selection-1", moment: .action, portrait: "pattie-profile",
             text: "Pick the piece you can practise. Small changes are the ones that make it to race day.",
             action: .selection),
        Line(id: "action-selection-2", moment: .action, portrait: "pattie-profile",
             text: "Good choice. If it matters on race day, give it one rehearsal before you need it.",
             action: .selection),
        Line(id: "action-search-1", moment: .action, portrait: "pattie-profile",
             text: "Here's the situation: the timing feed knows the name on your registration. Start there, then we can find the rest.",
             action: .search),
        Line(id: "action-search-2", moment: .action, portrait: "pattie-profile",
             text: "Surname first works too. The important thing is matching the entry, not guessing at a nickname.",
             action: .search),
        Line(id: "action-choice-1", moment: .action, portrait: "pattie-profile",
             text: "Here's the solution: choose the race first, then the problem you want to solve. No typing, no invented advice.",
             action: .choice),
        Line(id: "action-choice-2", moment: .action, portrait: "pattie-profile",
             text: "That is the useful choice. Take one pointer and try it on a training day before race day.",
             action: .choice),
        Line(id: "action-save-1", moment: .action, portrait: "pattie-profile",
             text: "Write down the weather and what went wrong while it is fresh. In two years, that detail will be worth more than the time.",
             action: .save),
        Line(id: "action-save-2", moment: .action, portrait: "pattie-profile",
             text: "That is smart racecraft. The small detail you save today becomes your best advice later.",
             action: .save),
        Line(id: "action-export-1", moment: .action, portrait: "pattie-profile",
             text: "Away you go. Put the race history in front of the next person who needs to see it.",
             action: .export),
        Line(id: "action-export-2", moment: .action, portrait: "pattie-profile",
             text: "Here's the solution: one clean resume, with the splits that prove the story.",
             action: .export),
        Line(id: "action-play-1", moment: .action, portrait: "pattie-profile",
             text: "Here's the situation, then here's the solution. Listen for the small thing you can try before the next start.",
             action: .play),
        Line(id: "action-play-2", moment: .action, portrait: "pattie-profile",
             text: "Press play when you have a quiet minute. These pointers are built from the things that went wrong first.",
             action: .play),
        Line(id: "action-refresh-1", moment: .action, portrait: "pattie-profile",
             text: "Fresh results, straight from the timers. If the latest race is not here, it has not been posted yet.",
             action: .refresh),
        Line(id: "action-refresh-2", moment: .action, portrait: "pattie-profile",
             text: "A refresh checks the official feed again. It cannot make an unpublished result appear early.",
             action: .refresh),
        Line(id: "action-tap-1", moment: .action, portrait: "pattie-profile",
             text: "One small move at a time. The next useful clue is usually one tap away.",
             action: .tap),
        Line(id: "action-tap-2", moment: .action, portrait: "pattie-profile",
             text: "Good. Keep going. We are looking for the detail that makes the next race easier.",
             action: .tap),
        Line(id: "action-back-1", moment: .action, portrait: "pattie-profile",
             text: "Good, take the pointer with you. You do not need to stay on a screen after you have got the useful bit.",
             action: .back),
        Line(id: "action-back-2", moment: .action, portrait: "pattie-profile",
             text: "Away you go. The best tip is the one you can try before the next start.",
             action: .back),

        // Welcome
        Line(id: "welcome-1", moment: .welcome, portrait: "pattie-profile",
             text: "Here's the situation: your races are scattered across a dozen result pages. Here's the solution. They're all in here now.",
             voice: "pattie-here-s-the-situation", impact: .big),
        Line(id: "welcome-2", moment: .welcome, portrait: "pattie-profile",
             text: "Every bib, every split, every year. No more digging through old emails the night before a race.",
             voice: "pattie-here-s-the-solution", impact: .big),

        // Search
        Line(id: "search-1", moment: .searching, portrait: "pattie-profile",
             text: "Type your name the way you registered. Full legal first name, usually, whether you like it or not."),
        Line(id: "search-2", moment: .searching, portrait: "pattie-profile",
             text: "Surname first works too. I've spelled mine both ways on an entry form and so has everyone else."),

        // Claim
        Line(id: "claimed-1", moment: .claimed, portrait: "pattie-profile",
             text: "There you are. That's your whole career, straight off the timing feed.",
             voice: "pattie-now-that-s-a-great-idea", impact: .big),
        Line(id: "claimed-2", moment: .claimed, portrait: "pattie-profile",
             text: "Found you. Now you never have to remember a bib number again.",
             voice: "pattie-nice", impact: .big),

        // Race detail
        Line(id: "race-1", moment: .raceOpened, portrait: "pattie-profile",
             text: "Look at your transitions. That's free time sitting right there, and it costs nothing to practise."),
        Line(id: "race-2", moment: .raceOpened, portrait: "pattie-profile",
             text: "The bike is where the day is won or thrown away. Everything after it is just holding on.",
             voice: "pattie-bike"),
        Line(id: "race-3", moment: .raceOpened, portrait: "pattie-profile",
             text: "Splits don't lie. They just don't tell you how hot it was that day."),
        Line(id: "race-4", moment: .raceOpened, portrait: "pattie-profile",
             text: "Somewhere in this one there's a mile you'd rather not talk about. There is in all of mine too."),

        // Personal best
        Line(id: "pb-1", moment: .personalBest, portrait: "pattie-profile",
             text: "That's a personal best. Go on, look at it for a minute. You earned that one.",
             voice: "pattie-that-s-a-great-idea", impact: .big),
        Line(id: "pb-2", moment: .personalBest, portrait: "pattie-profile",
             text: "Best you've ever gone at that distance. Now that's a great idea.",
             voice: "pattie-now-that-s-a-great-idea", impact: .big),

        // DNF
        Line(id: "dnf-1", moment: .didNotFinish, portrait: "pattie-profile",
             text: "A DNF is a day, not a verdict. I've had mine. The next one still counts the same."),
        Line(id: "dnf-2", moment: .didNotFinish, portrait: "pattie-profile",
             text: "Everybody who races long enough collects one of these. It stays on the record and so do you."),

        // World Championship
        Line(id: "worlds-1", moment: .worldChampionship, portrait: "pattie-profile",
             text: "A World Championship start line. Not many people get one of those on their record.",
             voice: "pattie-good", impact: .big),

        // Bests
        Line(id: "bests-1", moment: .bests, portrait: "pattie-profile",
             text: "Best swim, best bike, best run, all scoped to the right distance. A half and a full were never the same race."),
        Line(id: "bests-2", moment: .bests, portrait: "pattie-profile",
             text: "Sorted by your fastest leg. This is the list you quote at dinner.",
             voice: "pattie-nice"),
        Line(id: "bests-filter-1", moment: .bestsFiltered, portrait: "pattie-profile",
             text: "Different leg, different story. The transitions one is the list nobody wants to look at."),
        Line(id: "bests-filter-2", moment: .bestsFiltered, portrait: "pattie-profile",
             text: "Watch the gap column. That number is the whole training plan in one line."),

        // Resume
        Line(id: "resume-1", moment: .resume, portrait: "pattie-profile",
             text: "Here's the situation: a race wants your history for validation. Here's the solution. Export it and send it.",
             voice: "pattie-here-s-the-solution"),
        Line(id: "resume-2", moment: .resumeExported, portrait: "pattie-profile",
             text: "That's the sheet they ask for, in one tap. Away you go.",
             voice: "pattie-away-you-go"),

        // Pointers
        Line(id: "pointers-1", moment: .pointers, portrait: "pattie-profile",
             text: "These are my pointers. Little things that cost nothing and save your whole day.",
             voice: "pattie-away-you-go"),
        Line(id: "pointers-2", moment: .pointers, portrait: "pattie-profile",
             text: "Every one of these is something that went wrong for me first. That's how the list got written."),
        Line(id: "pointer-played-1", moment: .pointerPlayed, portrait: "pattie-profile",
             text: "Here's the situation, and then here's the solution. That's the whole format."),

        // Ask Pattie
        Line(id: "ask-1", moment: .askOpened, portrait: "pattie-profile",
             text: "Tell me what you're training for and what's bothering you. I've probably already made a clip about it.",
             voice: "pattie-here-s-the-situation", impact: .big),
        Line(id: "ask-2", moment: .askOpened, portrait: "pattie-profile",
             text: "Pick the race, pick the problem. No typing, and no waiting on me to answer."),
        Line(id: "ask-answered-1", moment: .askAnswered, portrait: "pattie-profile",
             text: "That's the one. Tap play and you'll get it in my own words.",
             voice: "pattie-here-s-the-solution"),
        Line(id: "ask-answered-2", moment: .askAnswered, portrait: "pattie-profile",
             text: "Try it on a training day first. Race day is a bad time to learn a new trick."),

        // Notes
        Line(id: "note-1", moment: .noteSaved, portrait: "pattie-profile",
             text: "Write down the conditions while you still remember them. In two years that note is worth more than the time."),

        // Long career
        Line(id: "veteran-1", moment: .veteran, portrait: "pattie-profile",
             text: "That is a lot of start lines. Most people talk about doing one of these. You kept going back.",
             voice: "pattie-good", impact: .big),

        // Refresh
        Line(id: "refresh-1", moment: .refreshed, portrait: "pattie-profile",
             text: "Pulled it again, straight from the timers. If your latest race isn't here, they haven't posted it yet."),

        // Settings
        Line(id: "settings-1", moment: .settings, portrait: "pattie-profile",
             text: "If I'm getting on your nerves there's a switch on this very screen. No hard feelings."),
    ]
}
