import Foundation

/// True when a thrown error is only this task being cancelled.
///
/// Screens load inside `.task(id:)`, which cancels the moment its id changes —
/// a tab switch, a new search keystroke. URLSession reports that as
/// `URLError.cancelled` rather than `CancellationError`, so a plain `catch`
/// can't tell an interrupted load from a failed one and would show an error for
/// a request nobody was waiting on any more.
func isTaskCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if let urlError = error as? URLError, urlError.code == .cancelled { return true }
    return false
}

enum ResultsAPIError: LocalizedError {
    case badConfiguration
    case badResponse(Int)
    case upstreamRejected(String)

    var errorDescription: String? {
        switch self {
        case .badConfiguration:
            return "Couldn't build the results request."
        case .badResponse(let code):
            return "The results service returned an error (\(code))."
        case .upstreamRejected(let message):
            return message
        }
    }
}

protocol ResultsProviding: Sendable {
    /// Athletes whose name contains `query`, collapsed from matching rows.
    func searchAthletes(matching query: String) async throws -> [Athlete]
    /// Every result belonging to one athlete, newest race first.
    func results(forAthleteID athleteID: String) async throws -> [RaceResult]
    /// The same, for an athlete the feed has split across several contact ids.
    func results(forContactIDs contactIDs: [String]) async throws -> [RaceResult]
    /// Every result in one event, used for field percentiles on a race detail.
    func results(forEventID eventID: String) async throws -> [RaceResult]
}

struct ResultsAPI: ResultsProviding {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Queries

    func searchAthletes(matching query: String) async throws -> [Athlete] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else { return [] }
        let rows = try await fetch(filter: Self.nameFilter(for: term),
                                   orderBy: nil,
                                   pageLimit: 2,
                                   pageSize: 250)
        return Self.collapseToAthletes(rows)
    }

    func results(forAthleteID athleteID: String) async throws -> [RaceResult] {
        try await results(forContactIDs: [athleteID])
    }

    /// One athlete's whole career, across every contact id the feed holds for
    /// them.
    ///
    /// See `Athlete.contactIDs`: a career is regularly split over two contact
    /// records, so asking for only the one the user tapped silently drops the
    /// other half. The ids are ORed into a single `$filter` rather than fetched
    /// separately so paging and the page cap still apply to the whole career.
    func results(forContactIDs contactIDs: [String]) async throws -> [RaceResult] {
        let ids = Array(NSOrderedSet(array: contactIDs)).compactMap { $0 as? String }
        guard !ids.isEmpty, ids.allSatisfy(Self.isGUID) else { throw ResultsAPIError.badConfiguration }
        let clause = ids.map { "wtc_ContactId/contactid eq \($0)" }.joined(separator: " or ")
        let rows = try await fetch(filter: ids.count == 1 ? clause : "(\(clause))",
                                   orderBy: "wtc_EventId/wtc_eventdate desc")
        return rows.map(\.result).sortedByDateDescending()
    }

    func results(forEventID eventID: String) async throws -> [RaceResult] {
        guard Self.isGUID(eventID) else { throw ResultsAPIError.badConfiguration }
        let rows = try await fetch(filter: "_wtc_eventid_value eq \(eventID) and wtc_AgeGroupId/wtc_agegroupname ne 'ODIV'",
                                   orderBy: "wtc_finishrankoverall")
        return rows.map(\.result)
    }

    // MARK: - Transport

    /// Pages through one OData filter, following `@odata.nextLink`.
    private func fetch(filter: String,
                       orderBy: String?,
                       pageLimit: Int? = nil,
                       pageSize: Int? = nil) async throws -> [ODataResultRow] {
        let config = await FeedConfigLoader.shared.config()
        var query = "$filter=" + Self.encodeODataValue(filter)
        query += "&$expand=" + Self.encodeODataValue(Self.expandClause)
        if let orderBy {
            query += "&$orderby=" + Self.encodeODataValue(orderBy)
        }
        guard var url = config.requestURL(query: query, pageSize: pageSize) else {
            throw ResultsAPIError.badConfiguration
        }

        var rows: [ODataResultRow] = []
        let limit = min(pageLimit ?? config.maxPages, config.maxPages)
        for _ in 0..<max(limit, 1) {
            let page = try await load(url: url, config: config)
            rows.append(contentsOf: page.value)
            guard let next = page.nextLink, let nextURL = config.requestURL(nextLink: next) else { break }
            url = nextURL
            try Task.checkCancellation()
        }
        return rows
    }

    private func load(url: URL, config: FeedConfig) async throws -> ODataPage {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.referer, forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ResultsAPIError.badResponse(-1)
        }
        guard 200..<300 ~= http.statusCode else {
            throw ResultsAPIError.badResponse(http.statusCode)
        }
        // The proxy answers 200 with `{"error": "..."}` for a URL it declines
        // to sign, so a status check alone is not enough to call this a success.
        if let envelope = try? JSONDecoder().decode(ODataErrorEnvelope.self, from: data), let message = envelope.error {
            throw ResultsAPIError.upstreamRejected(message)
        }
        return try JSONDecoder().decode(ODataPage.self, from: data)
    }

    // MARK: - Helpers

    /// The related records every row needs, spelled out in full.
    ///
    /// An explicit `$expand` *replaces* the server's default expansion rather
    /// than adding to it. Asking only for `wtc_EventId` — which is all the app
    /// needs that the default doesn't already give — silently drops
    /// `wtc_ContactId` from every row, so search returned rows with no athlete
    /// attached and reported "no athletes found" against a perfectly good
    /// 200 response. Every relation the decoder reads has to be listed here.
    static let expandClause = [
        "wtc_EventId($select=wtc_name,wtc_eventdate,wtc_externaleventname)",
        "wtc_ContactId($select=contactid,firstname,lastname,fullname,address1_city,address1_stateorprovince,address1_country,gendercode)",
        "wtc_CountryRepresentingId($select=wtc_iso2,wtc_name)",
        "wtc_AgeGroupId($select=wtc_agegroupname)",
    ].joined(separator: ",")

    /// Percent-encoding for a value that sits inside an OData query string.
    ///
    /// `$filter` values legitimately contain characters that
    /// `URLComponents` would otherwise mangle or leave ambiguous once the whole
    /// upstream URL is nested inside another URL's query. Encoding here and
    /// assigning to `percentEncodedQuery` keeps exactly one round of escaping.
    static func encodeODataValue(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~()$/*")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    /// Escape a single-quoted OData string literal.
    static func escapeODataLiteral(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    /// Search on the parts of the name the athlete actually typed.
    ///
    /// A single `contains(fullname, …)` looks right and behaves badly on the
    /// half of searches that put the surname first: matching is case
    /// insensitive upstream but strictly ordered, so "wallner pattie" returns
    /// nothing at all while "pattie wallner" returns the athlete. Splitting on
    /// whitespace and ANDing the terms against first and last name makes both
    /// orderings work and lets a partial name still land.
    static func nameFilter(for term: String) -> String {
        let words = term.split(whereSeparator: { $0 == " " || $0 == "," })
            .map { escapeODataLiteral(String($0)) }
            .filter { !$0.isEmpty }
            .prefix(3)
        guard !words.isEmpty else { return "contains(wtc_ContactId/fullname,'')" }
        let clauses = words.map { word -> String in
            "(contains(wtc_ContactId/firstname,'\(word)') or contains(wtc_ContactId/lastname,'\(word)'))"
        }
        return clauses.joined(separator: " and ")
    }

    static func isGUID(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }

    /// Group result rows into the people who produced them.
    ///
    /// Grouping is on person, not on contact id: see `Athlete.contactIDs` for
    /// why one person routinely owns two. Rows merge when the name, the
    /// gender and the home city all match after normalisation, which is what
    /// reunites "Lincoln, CALIFORNIA" with "Lincoln, CA". A row whose contact
    /// carries no city keeps its own id as the key, so a missing city never
    /// collapses strangers together.
    static func collapseToAthletes(_ rows: [ODataResultRow]) -> [Athlete] {
        var byKey: [String: Athlete] = [:]
        var latestYear: [String: Int] = [:]
        var order: [String] = []
        for row in rows {
            guard let contact = row.contact, let id = contact.contactid else { continue }
            let result = row.result
            let key = identityKey(for: contact, fallback: id)
            let year = result.year
            if var athlete = byKey[key] {
                athlete.knownRaceCount += 1
                if !athlete.contactIDs.contains(id) { athlete.contactIDs.append(id) }
                if year > (latestYear[key] ?? 0) {
                    latestYear[key] = year
                    athlete.latestRaceName = result.raceName
                    athlete.latestRaceYear = year
                    athlete.latestAgeGroup = result.ageGroup
                    // The newest registration is the athlete's current truth:
                    // it is where "Lincoln, CA" beats the older "CALIFORNIA".
                    athlete.name = contact.fullname ?? result.athleteName
                    athlete.city = contact.address1_city ?? athlete.city
                    athlete.stateOrProvince = contact.address1_stateorprovince ?? athlete.stateOrProvince
                    athlete.countryISO2 = result.countryISO2 ?? athlete.countryISO2
                }
                byKey[key] = athlete
            } else {
                order.append(key)
                latestYear[key] = year
                byKey[key] = Athlete(
                    id: id,
                    contactIDs: [id],
                    name: contact.fullname ?? result.athleteName,
                    countryISO2: result.countryISO2,
                    city: contact.address1_city,
                    stateOrProvince: contact.address1_stateorprovince,
                    gender: contact.gendercode_formatted,
                    latestAgeGroup: result.ageGroup,
                    knownRaceCount: 1,
                    latestRaceName: result.raceName,
                    latestRaceYear: year
                )
            }
        }
        return order.compactMap { byKey[$0] }.sorted {
            if $0.knownRaceCount != $1.knownRaceCount { return $0.knownRaceCount > $1.knownRaceCount }
            return $0.name < $1.name
        }
    }

    /// The key two contact records have to share to be treated as one person.
    static func identityKey(for contact: ODataResultRow.Contact, fallback id: String) -> String {
        let city = normalizeForMatching(contact.address1_city)
        guard !city.isEmpty else { return "id:" + id }
        let first = normalizeForMatching(contact.firstname)
        let last = normalizeForMatching(contact.lastname)
        let name = first.isEmpty && last.isEmpty
            ? normalizeForMatching(contact.fullname)
            : first + " " + last
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return "id:" + id }
        let gender = normalizeForMatching(contact.gendercode_formatted)
        return [name, gender, city].joined(separator: "|")
    }

    /// Case, accents, punctuation and stray whitespace all vary between two
    /// registrations by the same person, and none of them mean anything.
    static func normalizeForMatching(_ value: String?) -> String {
        guard let value else { return "" }
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let cleaned = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }
}

extension Array where Element == RaceResult {
    func sortedByDateDescending() -> [RaceResult] {
        sorted { lhs, rhs in
            switch (lhs.eventDate, rhs.eventDate) {
            case let (l?, r?) where l != r: return l > r
            default: return lhs.year > rhs.year
            }
        }
    }
}
