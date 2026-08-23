import Foundation

/// The visual states for Pattie's small companion.
///
/// Each state uses the same clean portrait family, with a small accessory
/// motion in the companion view. The mapping is deliberately based on stable
/// content ids rather than hosted copy that can change without an app update.
enum PattiePetState: String, CaseIterable, Sendable {
    case idle
    case coach
    case celebrate
    case encourage
    case shoes
    case swim
    case bike
    case run
    case transition
    case finish
    case dance
    case warmup
    case hydrate
    case stretch
    case recovery

    /// Small, view-agnostic motion values for the corner companion.
    /// Offsets are normalized units that a view can scale to its spacing tokens.
    struct MotionProfile: Equatable, Sendable {
        let rotationDegrees: Double
        let horizontalShift: Double
        let verticalLift: Double
        let duration: TimeInterval
    }

    /// A finite cycle keeps Pattie moving without introducing random or
    /// unbounded state into the UI.
    static let activeMotionStates: [Self] = [
        .warmup, .swim, .transition, .bike, .run, .finish,
        .dance, .hydrate, .stretch, .recovery
    ]

    var imageName: String {
        "pattie-pet-" + bundledAssetState.rawValue
    }

    var accessibilityName: String {
        switch self {
        case .idle: return "ready"
        case .coach: return "thinking"
        case .celebrate: return "celebrating"
        case .encourage: return "encouraging"
        case .shoes: return "talking about shoes"
        case .swim: return "talking about swimming"
        case .bike: return "talking about the bike"
        case .run: return "running"
        case .transition: return "in transition"
        case .finish: return "finishing"
        case .dance: return "dancing"
        case .warmup: return "warming up"
        case .hydrate: return "hydrating"
        case .stretch: return "stretching"
        case .recovery: return "recovering"
        }
    }

    var accessorySymbol: String? {
        switch self {
        case .idle: return nil
        case .coach: return "magnifyingglass"
        case .celebrate: return "sparkles"
        case .encourage: return "heart.fill"
        case .shoes: return "shoeprints.fill"
        case .swim: return "water.waves"
        case .bike: return "bicycle"
        case .run: return "figure.run"
        case .transition: return "arrow.triangle.2.circlepath"
        case .finish: return "flag.checkered"
        case .dance: return "music.note"
        case .warmup: return "figure.walk"
        case .hydrate: return "drop.fill"
        case .stretch: return "figure.stand"
        case .recovery: return "heart.fill"
        }
    }

    var accessoryLabel: String? {
        switch self {
        case .idle: return nil
        case .coach: return "A useful idea"
        case .celebrate: return "Celebration"
        case .encourage: return "Encouragement"
        case .shoes: return "Shoes"
        case .swim: return "Swim gear"
        case .bike: return "Bike gear"
        case .run: return "Run"
        case .transition: return "Transition"
        case .finish: return "Finish line"
        case .dance: return "Dance"
        case .warmup: return "Warm-up"
        case .hydrate: return "Hydration"
        case .stretch: return "Stretch"
        case .recovery: return "Recovery"
        }
    }

    var motionProfile: MotionProfile {
        switch self {
        case .idle: return MotionProfile(rotationDegrees: 0, horizontalShift: 0, verticalLift: 0.5, duration: 1.8)
        case .coach: return MotionProfile(rotationDegrees: 0, horizontalShift: 0, verticalLift: 0.5, duration: 1.4)
        case .celebrate: return MotionProfile(rotationDegrees: -3, horizontalShift: 0, verticalLift: 1, duration: 0.54)
        case .encourage: return MotionProfile(rotationDegrees: 0, horizontalShift: 0.5, verticalLift: 0.75, duration: 0.72)
        case .shoes: return MotionProfile(rotationDegrees: 3, horizontalShift: 0.5, verticalLift: 0.75, duration: 0.64)
        case .swim: return MotionProfile(rotationDegrees: -2, horizontalShift: -1, verticalLift: 0.75, duration: 0.72)
        case .bike: return MotionProfile(rotationDegrees: 2, horizontalShift: 1, verticalLift: 0.5, duration: 0.68)
        case .run: return MotionProfile(rotationDegrees: -4, horizontalShift: 1, verticalLift: 1, duration: 0.46)
        case .transition: return MotionProfile(rotationDegrees: 3, horizontalShift: 0.5, verticalLift: 0.75, duration: 0.58)
        case .finish: return MotionProfile(rotationDegrees: -3, horizontalShift: 0, verticalLift: 1, duration: 0.62)
        case .dance: return MotionProfile(rotationDegrees: 6, horizontalShift: 1, verticalLift: 1, duration: 0.42)
        case .warmup: return MotionProfile(rotationDegrees: -1, horizontalShift: 0.5, verticalLift: 0.75, duration: 0.86)
        case .hydrate: return MotionProfile(rotationDegrees: 2, horizontalShift: 0.5, verticalLift: 0.5, duration: 0.78)
        case .stretch: return MotionProfile(rotationDegrees: 4, horizontalShift: -0.5, verticalLift: 0.5, duration: 0.92)
        case .recovery: return MotionProfile(rotationDegrees: -2, horizontalShift: -0.5, verticalLift: 0.5, duration: 1.1)
        }
    }

    var rotationDegrees: Double {
        motionProfile.rotationDegrees
    }

    var isActiveMotion: Bool {
        Self.activeMotionStates.contains(self)
    }

    /// Returns a repeatable state for any animation tick, including negative
    /// indexes used by previews or restored UI state.
    static func motionState(at index: Int) -> Self {
        activeMotionStates[wrappedIndex(index, count: activeMotionStates.count)]
    }

    /// Advances through the finite motion cycle without using hash-based order.
    static func nextMotionState(after state: Self) -> Self {
        guard let index = activeMotionStates.firstIndex(of: state) else {
            return motionState(at: 0)
        }
        return motionState(at: index + 1)
    }

    static func rotation(for state: Self) -> Double {
        state.rotationDegrees
    }

    /// Returns at most one pass through the active cycle, so a bad count cannot
    /// allocate an unbounded sequence.
    static func motionStates(startingAt state: Self = .warmup, count: Int) -> [Self] {
        guard count > 0 else { return [] }
        let length = min(count, activeMotionStates.count)
        let startIndex = activeMotionStates.firstIndex(of: state) ?? 0
        return (0..<length).map { motionState(at: startIndex + $0) }
    }

    static func forPointerID(_ id: String) -> Self {
        switch id {
        case "ep-01", "ep-02", "ep-16", "ep-17", "ep-19",
             "morning-flipflops", "t1-mud", "t2-lube":
            return .shoes
        case "ep-06", "ep-10", "ep-11", "ep-12", "ep-13", "ep-15", "ep-18",
             "swim-contact", "swim-bright-cap", "swim-key", "gear-wetsuit-roll",
             "gear-cap-stick":
            return .swim
        case "ep-05", "ep-07", "ep-08", "ep-09", "bike-bubs", "bike-climb",
             "bike-left-hand", "bike-trouble":
            return .bike
        case "ep-03", "ep-04", "t1-freezer-bag", "weather":
            return .coach
        default:
            return .coach
        }
    }

    static func forTopicID(_ id: String) -> Self {
        switch id {
        case "swim-start", "swim-gear": return .swim
        case "bike-handling", "bike-trouble": return .bike
        case "feet": return .shoes
        case "transitions": return .coach
        case "weather": return .coach
        case "after": return .celebrate
        case "run-form": return .encourage
        default: return .coach
        }
    }

    private var bundledAssetState: Self {
        switch self {
        case .run, .stretch, .recovery: return .encourage
        case .transition: return .shoes
        case .finish, .dance: return .celebrate
        case .warmup: return .idle
        case .hydrate: return .swim
        default: return self
        }
    }

    private static func wrappedIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let remainder = index % count
        return remainder >= 0 ? remainder : remainder + count
    }
}
