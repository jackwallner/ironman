import AVFoundation
import XCTest
@testable import IM_Iron_Splits

final class ResultsAPITests: XCTestCase {

    func testPattieAudioSessionUsesAudibleMixedPlayback() async {
        let activated = await PattieVoice.activateSession()

        XCTAssertTrue(activated)
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)
        XCTAssertTrue(AVAudioSession.sharedInstance().categoryOptions.contains(.mixWithOthers))
    }

    // MARK: - Name filter

    func testNameFilterSplitsOnWhitespaceSoEitherOrderMatches() {
        let filter = ResultsAPI.nameFilter(for: "Pattie Wallner")
        XCTAssertTrue(filter.contains("startswith(wtc_ContactId/firstname,'Pattie')"))
        XCTAssertTrue(filter.contains("startswith(wtc_ContactId/lastname,'Wallner')"))
        XCTAssertTrue(filter.contains(" and "))
    }

    /// The default has to stay `startswith`: `contains` is a full scan upstream
    /// and measures ~30s against ~1.5s for the same two-word name, which is the
    /// whole difference between onboarding working and onboarding looking dead.
    func testNameFilterDefaultsToThePrefixOperator() {
        XCTAssertFalse(ResultsAPI.nameFilter(for: "Pattie Wallner").contains("contains("))
    }

    func testNameFilterSubstringDepthFallsBackToContains() {
        let filter = ResultsAPI.nameFilter(for: "Wallner", depth: .substring)
        XCTAssertTrue(filter.contains("contains(wtc_ContactId/lastname,'Wallner')"))
        XCTAssertFalse(filter.contains("startswith("))
    }

    func testNameFilterEscapesApostrophes() {
        for depth in [SearchDepth.prefix, .substring] {
            let filter = ResultsAPI.nameFilter(for: "O'Brien", depth: depth)
            XCTAssertTrue(filter.contains("O''Brien"), "A raw apostrophe would terminate the OData string literal")
        }
    }

    func testNameFilterCapsTermsSoOneQueryCannotRunAway() {
        let filter = ResultsAPI.nameFilter(for: "a b c d e f")
        XCTAssertEqual(filter.components(separatedBy: " and ").count, 3)
    }

    // MARK: - GUID guard

    func testGUIDGuardRejectsInjectionAttempts() {
        XCTAssertFalse(ResultsAPI.isGUID("a508fd19' or '1'='1"))
        XCTAssertTrue(ResultsAPI.isGUID("a508fd19-3e5e-45d2-9a18-47215c7bcb40"))
    }

    // MARK: - URL construction

    func testRequestURLNestsTheUpstreamURLExactlyOnce() throws {
        let config = FeedConfig.bundled
        let query = "$filter=" + ResultsAPI.encodeODataValue("wtc_ContactId/contactid eq a508fd19-3e5e-45d2-9a18-47215c7bcb40")
        let url = try XCTUnwrap(config.requestURL(query: query))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let upstream = try XCTUnwrap(components.queryItems?.first { $0.name == "url" }?.value)

        XCTAssertTrue(upstream.hasPrefix("https://api.competitor.com/web/results?"))
        XCTAssertTrue(upstream.contains("$filter="))
        XCTAssertTrue(upstream.contains("wtc_ContactId/contactid"))
        XCTAssertFalse(upstream.contains("%2524"), "Double-encoded '$' means one escaping round too many")
    }

    func testPageSizeIsCarriedOnTheProxyNotTheUpstream() throws {
        let url = try XCTUnwrap(FeedConfig.bundled.requestURL(query: "$top=1", pageSize: 42))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first { $0.name == "pageSize" }?.value, "42")
    }

    func testFeedConfigRejectsUnsafeOverrides() {
        var config = FeedConfig.bundled
        XCTAssertTrue(config.isValid)

        config.proxyURL = "http://labs-v2.competitor.com/api/results-proxy"
        XCTAssertFalse(config.isValid)

        config = FeedConfig.bundled
        config.resultsURL = "https://example.com/web/results"
        XCTAssertFalse(config.isValid)

        config = FeedConfig.bundled
        config.maxPages = 0
        XCTAssertFalse(config.isValid)
    }

    func testNextLinkMustRemainOnTheUpstreamResultsHost() {
        XCTAssertNotNil(FeedConfig.bundled.requestURL(
            nextLink: "https://api.competitor.com/web/results?$skiptoken=abc"))
        XCTAssertNil(FeedConfig.bundled.requestURL(
            nextLink: "https://example.com/web/results?$skiptoken=abc"))
        XCTAssertNil(FeedConfig.bundled.requestURL(
            nextLink: "https://api.competitor.com:8443/web/results?$skiptoken=abc"))
    }

    // MARK: - Collapsing rows to athletes

    func testCollapseGroupsRowsByContactAndKeepsTheLatestRace() {
        let rows = ODataResultRow.athleteFixtures()
        let athletes = ResultsAPI.collapseToAthletes(rows)

        XCTAssertEqual(athletes.count, 2)
        let daniel = try? XCTUnwrap(athletes.first { $0.name == "Daniel Winek" })
        XCTAssertEqual(daniel?.knownRaceCount, 2)
        XCTAssertEqual(daniel?.latestRaceYear, 2025)
        XCTAssertEqual(daniel?.latestRaceName, "IRONMAN Wisconsin")
    }

    func testCollapseSortsTheMostRacedAthleteFirst() {
        let athletes = ResultsAPI.collapseToAthletes(ODataResultRow.athleteFixtures())
        XCTAssertEqual(athletes.first?.name, "Daniel Winek")
    }

    func testCollapseRemovesDuplicateRowsBeforeCountingRaces() {
        let rows = ODataResultRow.athleteFixtures()
        let athletes = ResultsAPI.collapseToAthletes(rows + [rows[1]])
        XCTAssertEqual(athletes.first?.name, "Daniel Winek")
        XCTAssertEqual(athletes.first?.knownRaceCount, 2)
    }

    func testCollapseExcludesNonTriathlonResultsFromAthleteSearch() {
        let ironman = ODataResultRow.athleteFixtures()[0]
        let running = ODataResultRow.decode("""
        {
          "wtc_resultid": "run-1",
          "wtc_rundistancecompleted": 42.2,
          "wtc_finisher": true,
          "wtc_ContactId": {
            "contactid": "a508fd19-3e5e-45d2-9a18-47215c7bcb40",
            "firstname": "Daniel",
            "lastname": "Winek",
            "fullname": "Daniel Winek",
            "address1_city": "MADISON",
            "address1_stateorprovince": "WI"
          },
          "wtc_EventId": {
            "wtc_name": "2024 Madison Marathon",
            "wtc_eventdate": "2024-10-06T00:00:00Z"
          }
        }
        """)

        let athlete = ResultsAPI.collapseToAthletes([ironman, running]).first
        XCTAssertEqual(athlete?.knownRaceCount, 1)
        XCTAssertEqual(athlete?.latestRaceYear, 2023)
    }

    func testResumeLabelsIncompleteResultsPrecisely() {
        let dnf = ODataResultRow.decode("{\"wtc_resultid\":\"dnf\",\"wtc_dnf\":true}").result
        let dns = ODataResultRow.decode("""
        {
          "wtc_resultid": "dns",
          "wtc_dns": true,
          "wtc_EventId": { "wtc_name": "2025 IRONMAN Wisconsin" }
        }
        """).result
        let dq = ODataResultRow.decode("{\"wtc_resultid\":\"dq\",\"wtc_dq\":true}").result

        XCTAssertEqual(ResumeBuilder.statusLabel(for: dnf), "DNF")
        XCTAssertEqual(ResumeBuilder.statusLabel(for: dns), "DNS")
        XCTAssertEqual(ResumeBuilder.statusLabel(for: dq), "DQ")
        let text = ResumeBuilder.plainText(athlete: Athlete(id: "test", name: "Test Athlete"),
                                           results: [dns],
                                           options: .init(kinds: Set(RaceKind.allCases), includeSplits: false, includeDNF: true))
        XCTAssertTrue(text.contains("DNS"))
        XCTAssertFalse(text.contains("00:00:00"))
    }
}

extension ResultsAPITests {
    /// Regression guard for the bug that made every search come back empty:
    /// an explicit `$expand` replaces the server default, so any relation the
    /// decoder reads must be named in it.
    func testExpandClauseNamesEveryRelationTheDecoderReads() {
        let clause = ResultsAPI.expandClause
        for relation in ["wtc_EventId", "wtc_ContactId", "wtc_CountryRepresentingId", "wtc_AgeGroupId"] {
            XCTAssertTrue(clause.contains(relation), "\(relation) missing from $expand")
        }
        XCTAssertTrue(clause.contains("contactid"), "Claiming an athlete keys on the contact id")
        XCTAssertTrue(clause.contains("wtc_eventdate"), "Sorting and the year label need the event date")
    }

    // MARK: - Split contact records

    private static let contactA = "f1d44741-1048-ed11-bba1-000d3a314d17"
    private static let contactB = "f98c1655-3981-f111-ab0e-70a8a5ae8eaa"

    /// Pattie Wallner's 22 races sit under a contact spelled
    /// "Lincoln, CALIFORNIA" and her most recent race under a second contact
    /// spelled "Lincoln, CA". Grouping on the contact id showed her twice in
    /// search and gave her a locker missing whichever half she didn't tap.
    func testOnePersonSplitOverTwoContactsCollapsesToOneAthlete() {
        let rows = [
            ODataResultRow.contactRow(id: "1", first: "Pattie", last: "Wallner",
                                      contact: Self.contactA, city: "Lincoln",
                                      state: "CALIFORNIA", gender: "Female",
                                      event: "2025 IRONMAN Texas", date: "2025-04-26T00:00:00Z"),
            ODataResultRow.contactRow(id: "2", first: "Pattie", last: "Wallner",
                                      contact: Self.contactB, city: "Lincoln",
                                      state: "CA", gender: "Female",
                                      event: "2026 IRONMAN 70.3 Northern California",
                                      date: "2026-08-16T00:00:00Z"),
        ]
        let athletes = ResultsAPI.collapseToAthletes(rows)
        XCTAssertEqual(athletes.count, 1, "Both contacts are the same person")
        XCTAssertEqual(athletes[0].knownRaceCount, 2)
        XCTAssertEqual(Set(athletes[0].contactIDs), [Self.contactA, Self.contactB],
                       "Both ids must be carried so the locker fetches the whole career")
        XCTAssertEqual(athletes[0].latestRaceYear, 2026)
        XCTAssertEqual(athletes[0].stateOrProvince, "CA",
                       "The newest registration wins the display fields")
    }

    func testDifferentCitiesStaySeparatePeople() {
        let rows = [
            ODataResultRow.contactRow(id: "1", first: "John", last: "Smith",
                                      contact: Self.contactA, city: "Madison", state: "WI",
                                      gender: "Male", event: "2024 IRONMAN Wisconsin",
                                      date: "2024-09-08T00:00:00Z"),
            ODataResultRow.contactRow(id: "2", first: "John", last: "Smith",
                                      contact: Self.contactB, city: "Austin", state: "TX",
                                      gender: "Male", event: "2025 IRONMAN Texas",
                                      date: "2025-04-26T00:00:00Z"),
        ]
        XCTAssertEqual(ResultsAPI.collapseToAthletes(rows).count, 2)
    }

    func testSameCityDifferentStatesStaySeparatePeople() {
        let rows = [
            ODataResultRow.contactRow(id: "1", first: "John", last: "Smith",
                                      contact: Self.contactA, city: "Springfield", state: "IL",
                                      gender: "Male", event: "2024 IRONMAN Wisconsin",
                                      date: "2024-09-08T00:00:00Z"),
            ODataResultRow.contactRow(id: "2", first: "John", last: "Smith",
                                      contact: Self.contactB, city: "Springfield", state: "MO",
                                      gender: "Male", event: "2025 IRONMAN Texas",
                                      date: "2025-04-26T00:00:00Z")
        ]
        XCTAssertEqual(ResultsAPI.collapseToAthletes(rows).count, 2)
    }

    func testContactWithNoCityNeverMergesWithAnother() {
        let rows = [
            ODataResultRow.contactRow(id: "1", first: "John", last: "Smith",
                                      contact: Self.contactA, city: nil, state: nil,
                                      gender: "Male", event: "2024 IRONMAN Wisconsin",
                                      date: "2024-09-08T00:00:00Z"),
            ODataResultRow.contactRow(id: "2", first: "John", last: "Smith",
                                      contact: Self.contactB, city: nil, state: nil,
                                      gender: "Male", event: "2025 IRONMAN Texas",
                                      date: "2025-04-26T00:00:00Z"),
        ]
        XCTAssertEqual(ResultsAPI.collapseToAthletes(rows).count, 2,
                       "A missing city must not collapse strangers together")
    }

    func testDifferentGendersStaySeparatePeople() {
        let rows = [
            ODataResultRow.contactRow(id: "1", first: "Alex", last: "Kim",
                                      contact: Self.contactA, city: "Lincoln", state: "CA",
                                      gender: "Female", event: "2024 IRONMAN Texas",
                                      date: "2024-04-27T00:00:00Z"),
            ODataResultRow.contactRow(id: "2", first: "Alex", last: "Kim",
                                      contact: Self.contactB, city: "Lincoln", state: "CA",
                                      gender: "Male", event: "2025 IRONMAN Texas",
                                      date: "2025-04-26T00:00:00Z"),
        ]
        XCTAssertEqual(ResultsAPI.collapseToAthletes(rows).count, 2)
    }

    /// The same person typed at two registrations differs in case, accents and
    /// stray whitespace. None of those may split them into two athletes.
    func testCaseAccentsAndSpacingDoNotSplitAPerson() {
        XCTAssertEqual(ResultsAPI.normalizeForMatching("O'Brien-Smith"),
                       ResultsAPI.normalizeForMatching("o'brien-smith"))
        XCTAssertEqual(ResultsAPI.normalizeForMatching("MÜNCHEN"),
                       ResultsAPI.normalizeForMatching("münchen"))
        XCTAssertEqual(ResultsAPI.normalizeForMatching("  Lincoln  "),
                       ResultsAPI.normalizeForMatching("lincoln"))
        XCTAssertNotEqual(ResultsAPI.normalizeForMatching("Lincoln"),
                          ResultsAPI.normalizeForMatching("Lincolnshire"))
    }

    /// A locker cached before the merge shipped has no `contactIDs` key, and
    /// must not be thrown away and force a re-claim.
    func testAthleteDecodedFromAPreMergeCacheKeepsItsOwnID() throws {
        let json = Data("""
        {"id":"\(Self.contactA)","name":"Pattie Wallner","knownRaceCount":22}
        """.utf8)
        let athlete = try JSONDecoder().decode(Athlete.self, from: json)
        XCTAssertEqual(athlete.contactIDs, [Self.contactA])
    }
}
