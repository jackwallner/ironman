import Foundation

/// A person in the results feed, collapsed from the rows they appear in.
///
/// The feed has no athlete endpoint — there is only a flat table of results —
/// so an athlete is something we reconstruct by grouping rows on the contact
/// id. That id is the durable handle: names repeat (there are a dozen
/// Wallners), and once the user picks themselves out of a search we never have
/// to match on a string again.
struct Athlete: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var countryISO2: String?
    var city: String?
    var stateOrProvince: String?
    var gender: String?
    /// Most recent age-group label seen, e.g. "M50-54".
    var latestAgeGroup: String?
    /// How many rows the search saw. Indicative, not authoritative: search
    /// pages are capped, so this is "at least this many".
    var knownRaceCount: Int
    var latestRaceName: String?
    var latestRaceYear: Int?

    /// "Madison, WI".
    ///
    /// Registration stores whatever the athlete typed, which is usually
    /// "MADISON". Title-casing the joined string turns the state code into
    /// "Wi", so the city and the region are cased separately.
    var location: String? {
        let city = (self.city?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0.capitalizedIfShouting }
        let region = (stateOrProvince?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0.uppercased() }
        let parts = [city, region].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    var subtitle: String {
        var bits: [String] = []
        if let location { bits.append(location) }
        if let latestAgeGroup { bits.append(latestAgeGroup) }
        if let latestRaceYear, latestRaceYear > 0, let latestRaceName {
            bits.append(String(latestRaceYear) + " " + latestRaceName)
        }
        return bits.joined(separator: " · ")
    }
}

extension String {
    /// The feed stores cities as the athlete typed them at registration, which
    /// is often "MADISON". Title-case those without touching names that are
    /// already mixed case.
    var capitalizedIfShouting: String {
        guard self == uppercased(), count > 2 else { return self }
        return capitalized
    }
}
