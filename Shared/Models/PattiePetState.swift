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

    var imageName: String {
        "pattie-pet-" + rawValue
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
        }
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
}
