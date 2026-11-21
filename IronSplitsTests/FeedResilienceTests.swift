import XCTest
@testable import IM_Iron_Splits

/// November 2026: the server's default columns dropped the raw seconds and every
/// race read as a DNF. These pin each layer that now stops that happening again.
final class FeedResilienceTests: XCTestCase {

    override func tearDown() {
        SelectRejectingProtocol.requests = []
        super.tearDown()
    }

    func testQueryNamesTheColumnsTheDecoderReads() throws {
        let query = ResultsAPI.query(filter: "x eq 1", orderBy: nil, select: ResultsAPI.selectClause)
        XCTAssertTrue(query.contains("&$select=wtc_resultid"))
        for column in ["wtc_finishtime", "wtc_finishtimeformatted", "wtc_dnf", "wtc_finisher", "_wtc_agegroupid_value"] {
            XCTAssertTrue(ResultsAPI.selectClause.split(separator: ",").contains(Substring(column)), column)
        }
        XCTAssertFalse(ResultsAPI.query(filter: "x eq 1", orderBy: nil, select: nil).contains("&$select="))
    }

    func testRemoteSelectOverrideIsValidatedAndCanDisableSelect() {
        var config = FeedConfig.bundled
        XCTAssertEqual(config.effectiveSelect, ResultsAPI.selectClause)
        config.select = ""
        XCTAssertTrue(config.isValid)
        XCTAssertNil(config.effectiveSelect)
        config.select = "wtc_finishtime,wtc_dnf"
        XCTAssertTrue(config.isValid)
        config.select = "wtc_finishtime&$top=1"
        XCTAssertFalse(config.isValid)
    }

    func testOldConfigFileWithoutSelectStillDecodes() throws {
        let json = """
        {"proxyURL":"https://labs-v2.competitor.com/api/results-proxy","proxyURLParameter":"url",
         "pageSizeParameter":"pageSize","resultsURL":"https://api.competitor.com/web/results",
         "pageSize":500,"maxPages":12,"referer":"https://labs-v2.competitor.com/"}
        """
        let config = try JSONDecoder().decode(FeedConfig.self, from: Data(json.utf8))
        XCTAssertTrue(config.isValid)
        XCTAssertEqual(config.effectiveSelect, ResultsAPI.selectClause)
    }

    func testRejectedSelectRetriesWithoutItAndStillReadsTimes() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SelectRejectingProtocol.self]
        let api = ResultsAPI(session: URLSession(configuration: configuration))

        let results = try await api.results(forContactIDs: ["f1d44741-1048-ed11-bba1-000d3a314d17"])

        XCTAssertEqual(SelectRejectingProtocol.requests.count, 2)
        XCTAssertTrue(SelectRejectingProtocol.requests[0].contains("$select=wtc_resultid"))
        XCTAssertFalse(SelectRejectingProtocol.requests[1].contains("$select=wtc_resultid"))
        XCTAssertEqual(results.first?.finish, 27151)
        XCTAssertEqual(results.first?.isComplete, true)
    }

    func testQueryRejectionIsOnlyAClientError() {
        XCTAssertTrue(ResultsAPI.isQueryRejection(ResultsAPIError.badResponse(400)))
        XCTAssertTrue(ResultsAPI.isQueryRejection(ResultsAPIError.upstreamRejected("bad column")))
        XCTAssertFalse(ResultsAPI.isQueryRejection(ResultsAPIError.badResponse(503)))
        XCTAssertFalse(ResultsAPI.isQueryRejection(URLError(.timedOut)))
    }

    func testFinishFallsBackToTheSumOfAllFiveLegs() {
        let result = ODataResultRow.decode("""
        { "wtc_resultid": "r", "wtc_swimtimeformatted": "0:53:18", "wtc_transition1timeformatted": "0:06:19",
          "wtc_biketimeformatted": "3:31:03", "wtc_transitiontime2formatted": "0:07:34",
          "wtc_runtimeformatted": "2:54:17", "wtc_finisher": true }
        """).result
        XCTAssertEqual(result.finish, 27151)
        XCTAssertTrue(result.isComplete)

        let partial = ODataResultRow.decode("""
        { "wtc_resultid": "p", "wtc_swimtimeformatted": "0:53:18", "wtc_finisher": true }
        """).result
        XCTAssertNil(partial.finish)
    }

    func testAFlaggedFinishWithNoTimeIsNeverCalledADNF() {
        let untimed = ODataResultRow.decode("""
        { "wtc_resultid": "u", "wtc_finisher": true, "wtc_dnf": false }
        """).result
        XCTAssertFalse(untimed.isComplete)
        XCTAssertTrue(untimed.isUntimedFinish)
        XCTAssertEqual(untimed.statusText, "Finished")
        XCTAssertEqual(ResumeBuilder.statusLabel(for: untimed), "Finished")

        let dnf = ODataResultRow.decode("""
        { "wtc_resultid": "d", "wtc_finisher": false, "wtc_dnf": true, "wtc_finishtimeformatted": "4:16:32" }
        """).result
        XCTAssertFalse(dnf.isComplete)
        XCTAssertEqual(dnf.statusText, "DNF")
    }
}

/// Answers 400 to any request carrying `$select`, as the upstream does for an
/// unknown column, and a default-columns page otherwise.
final class SelectRejectingProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requests: [String] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let url = request.url?.absoluteString.removingPercentEncoding?.removingPercentEncoding ?? ""
        Self.requests.append(url)
        let rejected = url.contains("$select=wtc_resultid")
        let body = rejected
            ? #"{"error":{"code":"0x80060888","message":"Could not find a property"}}"#
            : """
            {"value":[{"wtc_resultid":"9fb8bd9e-3d48-4f42-8894-5ddc75ce3193",
              "wtc_finishtimeformatted":"7:32:31","wtc_swimtimeformatted":"0:53:18",
              "wtc_finisher":true,"wtc_dnf":false,"wtc_dns":false,"wtc_dq":false,
              "wtc_ContactId":{"contactid":"f1d44741-1048-ed11-bba1-000d3a314d17","fullname":"Pattie Wallner"},
              "wtc_EventId":{"wtc_name":"2026 IRONMAN 70.3 Northern California","wtc_eventdate":"2026-08-16T00:00:00Z"}}]}
            """
        let response = HTTPURLResponse(url: request.url!, statusCode: rejected ? 400 : 200,
                                       httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
