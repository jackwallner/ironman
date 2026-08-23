import Foundation
import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// User preferences that aren't the locker itself.
@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("settings.units") private var storedUnits: String = UnitPreference.deviceDefault.rawValue
    @AppStorage("settings.hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("settings.preferredKind") private var storedPreferredKind: String = ""
    @AppStorage("settings.appearance") private var storedAppearance: String = AppearancePreference.system.rawValue

    var units: UnitPreference {
        get { UnitPreference(rawValue: storedUnits) ?? .deviceDefault }
        set {
            objectWillChange.send()
            storedUnits = newValue.rawValue
        }
    }

    /// Last race kind the athlete looked at, so the leaderboard opens where
    /// they left it instead of resetting to whatever is most common.
    var preferredKind: RaceKind? {
        get { RaceKind(rawValue: storedPreferredKind) }
        set {
            objectWillChange.send()
            storedPreferredKind = newValue?.rawValue ?? ""
        }
    }

    var appearance: AppearancePreference {
        get { AppearancePreference(rawValue: storedAppearance) ?? .system }
        set {
            objectWillChange.send()
            storedAppearance = newValue.rawValue
        }
    }

    var preferredColorScheme: ColorScheme? { appearance.colorScheme }
}
