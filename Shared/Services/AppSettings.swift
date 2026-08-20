import Foundation
import SwiftUI

/// User preferences that aren't the locker itself.
@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("settings.units") private var storedUnits: String = UnitPreference.deviceDefault.rawValue
    @AppStorage("settings.hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("settings.preferredKind") private var storedPreferredKind: String = ""

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
}
