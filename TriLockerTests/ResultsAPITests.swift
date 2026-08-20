import XCTest
@testable import Tri_Locker

final class ResultsAPITests: XCTestCase {

    // MARK: - Name filter

    func testNameFilterSplitsOnWhitespaceSoEitherOrderMatches() {
        let filter = ResultsAPI.nameFilter(for: "Pattie Wallner")
        XCTAssertTrue(filter.contains("contains(wtc_ContactId/firstname,'Pattie')"))
        XCTAssertTrue(filter.contains("contains(wtc_ContactId/lastname,'Wallner')"))
        XCTAssertTrue(filter.contains(" and "))
    }

    func testNameFilterEscapesApostrophes() {
        let filter = ResultsAPI.nameFilter(for: "O'Brien")
        XCTAssertTrue(filter.contains("O''Brien"), "A raw apostrophe would terminate the OData string literal")
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
}
