import Foundation

/// One athlete's finish in one event, normalized from the results feed.
///
/// The upstream rows are Dynamics/OData records with two representations of
/// every number: a raw value (`wtc_swimtime`, seconds) and a display string
/// (`wtc_swimtimeformatted`, "1:02:46"). We keep the raw seconds and format on
/// our own terms, because every ranking, delta, and pace in the app is
/// arithmetic on seconds and the display strings are lossy for anything under
/// an hour.
struct RaceResult: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let eventID: String
    let eventName: String
    let eventDate: Date?
    let externalEventName: String?

    let athleteID: String?
    let athleteName: String
    let bib: Int?
    let ageGroup: String?
    let countryISO2: String?

    let swim: Int?
    let t1: Int?
    let bike: Int?
    let t2: Int?
    let run: Int?
    let finish: Int?

    let swimDistanceKm: Double?
    let bikeDistanceKm: Double?
    let runDistanceKm: Double?

    let swimRankOverall: Int?
    let bikeRankOverall: Int?
    let runRankOverall: Int?
    let finishRankOverall: Int?
    let finishRankGender: Int?
    let finishRankGroup: Int?
    let swimRankGroup: Int?
    let bikeRankGroup: Int?
    let runRankGroup: Int?

    let isFinisher: Bool
    let didNotFinish: Bool
    let didNotStart: Bool
    let disqualified: Bool

    /// Calendar year, from the event date when present and the "2025 IRONMAN …"
    /// name prefix otherwise. Some older events carry no date at all.
    var year: Int {
        if let eventDate {
            return Calendar(identifier: .gregorian).component(.year, from: eventDate)
        }
        let prefix = eventName.prefix(4)
        return Int(prefix) ?? 0
    }

    /// Event name without the leading year, which every row repeats.
    var raceName: String {
        let trimmed = eventName.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 5, Int(trimmed.prefix(4)) != nil else { return trimmed }
        return String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
    }

    var kind: RaceKind {
        RaceKind(bikeDistanceKm: bikeDistanceKm, runDistanceKm: runDistanceKm, externalEventName: externalEventName, eventName: eventName)
    }

    /// A finish only counts as a comparable performance when the athlete
    /// actually completed the course. DNF rows carry partial splits that would
    /// otherwise win every "best swim" leaderboard.
    var isComplete: Bool {
        isFinisher && !didNotFinish && !didNotStart && !disqualified && (finish ?? 0) > 0
    }

    func seconds(for discipline: Discipline) -> Int? {
        switch discipline {
        case .swim: return swim
        case .t1: return t1
        case .bike: return bike
        case .t2: return t2
        case .run: return run
        case .finish: return finish
        case .transitions:
            guard let t1, let t2 else { return t1 ?? t2 }
            return t1 + t2
        }
    }

    func overallRank(for discipline: Discipline) -> Int? {
        switch discipline {
        case .swim: return swimRankOverall
        case .bike: return bikeRankOverall
        case .run: return runRankOverall
        case .finish: return finishRankOverall
        case .t1, .t2, .transitions: return nil
        }
    }

    func divisionRank(for discipline: Discipline) -> Int? {
        switch discipline {
        case .swim: return swimRankGroup
        case .bike: return bikeRankGroup
        case .run: return runRankGroup
        case .finish: return finishRankGroup
        case .t1, .t2, .transitions: return nil
        }
    }

    /// Distance actually covered on a leg, used for pace. Nil for transitions.
    func distanceKm(for discipline: Discipline) -> Double? {
        switch discipline {
        case .swim: return swimDistanceKm
        case .bike: return bikeDistanceKm
        case .run: return runDistanceKm
        case .finish, .t1, .t2, .transitions: return nil
        }
    }
}

/// The six legs plus the two derived aggregates the app ranks on.
enum Discipline: String, CaseIterable, Codable, Sendable, Identifiable {
    case swim, t1, bike, t2, run, transitions, finish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .swim: return "Swim"
        case .t1: return "T1"
        case .bike: return "Bike"
        case .t2: return "T2"
        case .run: return "Run"
        case .transitions: return "Transitions"
        case .finish: return "Finish"
        }
    }

    /// Label for the segmented picker, which gives each leg a fifth of the
    /// screen. "Transitions" truncates to "Transiti…" there; "T1+T2" is what
    /// triathletes call it anyway.
    var shortTitle: String {
        self == .transitions ? "T1+T2" : title
    }

    var symbol: String {
        switch self {
        case .swim: return "figure.open.water.swim"
        case .bike: return "figure.outdoor.cycle"
        case .run: return "figure.run"
        case .t1, .t2, .transitions: return "arrow.triangle.swap"
        case .finish: return "flag.checkered"
        }
    }

    /// The legs that get their own leaderboard. T1 and T2 are folded into
    /// `transitions` because nobody chases a T2 personal best on its own.
    static var rankable: [Discipline] { [.finish, .swim, .bike, .run, .transitions] }
}

enum RaceKind: String, Codable, Sendable, CaseIterable {
    case fullDistance
    case halfDistance
    case otherTriathlon
    case running
    case unknown

    var title: String {
        switch self {
        case .fullDistance: return "Full"
        case .halfDistance: return "Half"
        case .otherTriathlon: return "Tri"
        case .running: return "Run"
        case .unknown: return "Race"
        }
    }

    var longTitle: String {
        switch self {
        case .fullDistance: return "Full distance"
        case .halfDistance: return "Half distance"
        case .otherTriathlon: return "Triathlon"
        case .running: return "Running"
        case .unknown: return "Race"
        }
    }

    /// Distance first, name second.
    ///
    /// The feed mixes full-distance triathlon, 70.3, marathons, 5Ks, and the
    /// 2020 virtual series, and only the completed-distance fields describe all
    /// of them consistently. Event names do not: "2013 IRONMAN Wisconsin:
    /// Triathlon" and "2025 IRONMAN Wisconsin" are the same race, and
    /// "IRONMAN 70.3" appears in the name of events whose rows have no
    /// distances at all.
    init(bikeDistanceKm: Double?, runDistanceKm: Double?, externalEventName: String?, eventName: String) {
        if let bike = bikeDistanceKm, bike > 1 {
            if bike > 140 { self = .fullDistance; return }
            if bike > 60 { self = .halfDistance; return }
            self = .otherTriathlon
            return
        }
        let haystack = ((externalEventName ?? "") + " " + eventName).uppercased()
        if haystack.contains("70.3") || haystack.contains("IM703") || haystack.contains("-703-") {
            self = .halfDistance
        } else if haystack.contains("IRONMAN") || haystack.contains("TRIATHLON") || haystack.hasPrefix("IRM") {
            self = .fullDistance
        } else if let run = runDistanceKm, run > 1 {
            self = .running
        } else {
            self = .unknown
        }
    }
}
