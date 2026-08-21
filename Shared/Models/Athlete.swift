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
    /// Every contact id the feed holds for this person, primary first.
    ///
    /// Timing registration mints a fresh contact record whenever the details
    /// the athlete typed don't match an existing one, so a career routinely
    /// arrives split across two ids: Pattie Wallner's 22 races sit under one
    /// contact spelled "Lincoln, CALIFORNIA / US" and her most recent race
    /// under another spelled "Lincoln, CA / USA". Grouping on the id alone
    /// showed her twice in search and gave her a locker missing whichever
    /// half she didn't tap. `collapseToAthletes` merges them; the locker then
    /// has to ask the feed for all of them, so the whole set is carried here.
    var contactIDs: [String]
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

    /// Lockers cached before the merge existed encode no `contactIDs`, so an
    /// upgrade must not throw them away and force a re-claim.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        contactIDs = try c.decodeIfPresent([String].self, forKey: .contactIDs) ?? [id]
        name = try c.decode(String.self, forKey: .name)
        countryISO2 = try c.decodeIfPresent(String.self, forKey: .countryISO2)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        stateOrProvince = try c.decodeIfPresent(String.self, forKey: .stateOrProvince)
        gender = try c.decodeIfPresent(String.self, forKey: .gender)
        latestAgeGroup = try c.decodeIfPresent(String.self, forKey: .latestAgeGroup)
        knownRaceCount = try c.decode(Int.self, forKey: .knownRaceCount)
        latestRaceName = try c.decodeIfPresent(String.self, forKey: .latestRaceName)
        latestRaceYear = try c.decodeIfPresent(Int.self, forKey: .latestRaceYear)
    }

    init(id: String,
         contactIDs: [String]? = nil,
         name: String,
         countryISO2: String? = nil,
         city: String? = nil,
         stateOrProvince: String? = nil,
         gender: String? = nil,
         latestAgeGroup: String? = nil,
         knownRaceCount: Int = 0,
         latestRaceName: String? = nil,
         latestRaceYear: Int? = nil) {
        self.id = id
        self.contactIDs = contactIDs ?? [id]
        self.name = name
        self.countryISO2 = countryISO2
        self.city = city
        self.stateOrProvince = stateOrProvince
        self.gender = gender
        self.latestAgeGroup = latestAgeGroup
        self.knownRaceCount = knownRaceCount
        self.latestRaceName = latestRaceName
        self.latestRaceYear = latestRaceYear
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
