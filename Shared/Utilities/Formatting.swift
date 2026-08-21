import Foundation

enum TimeFormat {
    /// "9:38:11" for a race, "58:18" for a swim, "3:03" for a transition.
    ///
    /// Leading zeros are dropped on purpose. A transition rendered as "0:03:03"
    /// (which is how the feed formats it) reads as three hours at a glance in a
    /// column of race times, and transitions are the one split people scan for
    /// exactly this reason.
    static func hms(_ seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "--" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    /// Signed gap between two times, e.g. "−4:12" or "+1:07".
    static func delta(_ seconds: Int) -> String {
        let sign = seconds < 0 ? "−" : "+"
        return sign + hms(abs(seconds))
    }

    static func mmss(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "--" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

enum UnitPreference: String, CaseIterable, Codable, Sendable {
    case metric
    case imperial

    var title: String {
        switch self {
        case .metric: return "Metric (km)"
        case .imperial: return "Imperial (mi)"
        }
    }

    static var deviceDefault: UnitPreference {
        Locale.current.measurementSystem == .metric ? .metric : .imperial
    }
}

enum PaceFormat {
    static let metersPerMile = 1609.344

    /// Pace or speed for one leg, in the idiom each sport actually uses:
    /// time per 100 m in the water, distance per hour on the bike, time per
    /// mile or kilometre on the run.
    static func text(for discipline: Discipline,
                     seconds: Int?,
                     distanceKm: Double?,
                     units: UnitPreference) -> String? {
        guard let seconds, seconds > 0, let distanceKm, distanceKm > 0.01 else { return nil }
        switch discipline {
        case .swim:
            let hundreds = distanceKm * 10
            return TimeFormat.mmss(Double(seconds) / hundreds) + " /100m"
        case .bike:
            let hours = Double(seconds) / 3600
            let distance = units == .metric ? distanceKm : distanceKm * 1000 / metersPerMile
            let speed = distance / hours
            return String(format: "%.1f %@", speed, units == .metric ? "km/h" : "mph")
        case .run:
            let distance = units == .metric ? distanceKm : distanceKm * 1000 / metersPerMile
            return TimeFormat.mmss(Double(seconds) / distance) + (units == .metric ? " /km" : " /mi")
        case .finish, .t1, .t2, .transitions:
            return nil
        }
    }

    static func distanceText(_ km: Double?, units: UnitPreference) -> String? {
        guard let km, km > 0.01 else { return nil }
        if units == .metric { return String(format: "%.2f km", km) }
        return String(format: "%.2f mi", km * 1000 / metersPerMile)
    }
}

enum Ordinal {
    /// "48th". Built per call rather than cached: `NumberFormatter` is not
    /// `Sendable`, and this renders a few dozen times per screen, not per row.
    static func text(_ value: Int?) -> String? {
        guard let value, value > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: value))
    }
}

/// Race dates, rendered in UTC.
///
/// The feed publishes event dates as bare UTC midnight ("2025-09-07T00:00:00Z")
/// means the seventh, not an instant. Formatting that with the device time zone
/// shows an athlete west of Greenwich the day before their own race, which is
/// the kind of wrong that makes someone distrust every other number on the
/// screen.
enum RaceDate {
    static func medium(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt))
    }

    static func long(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .complete, time: .omitted, timeZone: .gmt))
    }
}
