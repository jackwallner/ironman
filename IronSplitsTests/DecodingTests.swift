import XCTest
@testable import IM_Iron_Splits

/// Decoding is pinned against the real upstream payload shape, because every
/// number in it has at least two representations and a strict decode of the
/// wrong one silently drops a whole page of results.
final class DecodingTests: XCTestCase {

    func testDecodesAPageWithMixedNumberTypes() throws {
        let json = """
        {
          "@odata.nextLink": "https://api.competitor.com/web/wtc_results?$skiptoken=x",
          "value": [
            {
              "wtc_resultid": "5a5c7596-33c2-4a30-b4fb-354c2f340c11",
              "_wtc_eventid_value": "3bd630ca-4c2a-4775-87bd-b0d2c2764c53",
              "_wtc_agegroupid_value_formatted": "M25-29",
              "wtc_bibnumber": 1009,
              "wtc_bibnumber_formatted": "1,009",
              "wtc_swimtime": 3498,
              "wtc_transition1time": 391,
              "wtc_biketime": 17018,
              "wtc_transition2time": 183,
              "wtc_runtime": 10397,
              "wtc_finishtime": 31487,
              "wtc_swimdistancecompleted": 3.8624,
              "wtc_bikedistancecompleted": 180.81,
              "wtc_rundistancecompleted": 42.3579,
              "wtc_bikerankgender": "4",
              "wtc_bikerankgroup": 3,
              "wtc_finishrankoverall": 2,
              "wtc_finisher": true,
              "wtc_dnf": false,
              "wtc_dns": false,
              "wtc_dq": false,
              "wtc_ContactId": {
                "contactid": "a508fd19-3e5e-45d2-9a18-47215c7bcb40",
                "firstname": "Daniel",
                "lastname": "Winek",
                "fullname": "Daniel Winek",
                "address1_city": "MADISON",
                "address1_stateorprovince": "WI"
              },
              "wtc_CountryRepresentingId": { "wtc_iso2": "US", "wtc_name": "United States" },
              "wtc_EventId": {
                "wtc_eventid": "3bd630ca-4c2a-4775-87bd-b0d2c2764c53",
                "wtc_name": "2025 IRONMAN Wisconsin",
                "wtc_eventdate": "2025-09-07T00:00:00Z",
                "wtc_externaleventname": "IRM-WISCONSIN-2025"
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let page = try JSONDecoder().decode(ODataPage.self, from: json)
        XCTAssertEqual(page.value.count, 1)
        XCTAssertNotNil(page.nextLink)

        let result = page.value[0].result
        XCTAssertEqual(result.athleteName, "Daniel Winek")
        XCTAssertEqual(result.bib, 1009)
        XCTAssertEqual(result.swim, 3498)
        XCTAssertEqual(result.finish, 31487)
        XCTAssertEqual(result.ageGroup, "M25-29")
        XCTAssertEqual(result.kind, .fullDistance)
        XCTAssertEqual(result.raceName, "IRONMAN Wisconsin")
        XCTAssertEqual(result.year, 2025)
        XCTAssertTrue(result.isComplete)
    }

    func testStringTypedNumbersDecode() throws {
        let json = """
        { "value": [ { "wtc_resultid": "x", "wtc_bibnumber": "1,009", "wtc_swimtime": "3498" } ] }
        """.data(using: .utf8)!
        let page = try JSONDecoder().decode(ODataPage.self, from: json)
        XCTAssertEqual(page.value[0].result.bib, 1009)
        XCTAssertEqual(page.value[0].result.swim, 3498)
    }

    func testBooleanColumnsAcceptStringsAndNumbers() throws {
        let json = """
        { "value": [
          { "wtc_resultid": "a", "wtc_finisher": "true", "wtc_dnf": 1 },
          { "wtc_resultid": "b", "wtc_finisher": "false", "wtc_dns": 0, "wtc_dq": "yes" }
        ] }
        """.data(using: .utf8)!

        let rows = try JSONDecoder().decode(ODataPage.self, from: json).value
        XCTAssertTrue(rows[0].result.isFinisher)
        XCTAssertTrue(rows[0].result.didNotFinish)
        XCTAssertFalse(rows[1].result.isFinisher)
        XCTAssertTrue(rows[1].result.disqualified)
    }

    func testMissingResultIDIsStableAcrossDecodes() {
        let json = """
        {
          "_wtc_eventid_value": "3bd630ca-4c2a-4775-87bd-b0d2c2764c53",
          "wtc_ContactId": { "contactid": "a508fd19-3e5e-45d2-9a18-47215c7bcb40", "fullname": "Daniel Winek" },
          "wtc_EventId": { "wtc_eventdate": "2025-09-07T00:00:00Z" },
          "wtc_finishtime": 31487
        }
        """

        let first = ODataResultRow.decode(json).result.id
        let second = ODataResultRow.decode(json).result.id
        XCTAssertEqual(first, second)
        XCTAssertNotNil(UUID(uuidString: first))
    }

    func testProxyErrorEnvelopeIsRecognised() throws {
        let json = #"{"error":"Invalid results URL"}"#.data(using: .utf8)!
        let envelope = try JSONDecoder().decode(ODataErrorEnvelope.self, from: json)
        XCTAssertEqual(envelope.error, "Invalid results URL")
    }

    /// November 2026: the default projection stopped sending raw seconds and
    /// sends only display strings. Every race read as a DNF until this decoded.
    func testFormattedTimesOnlyStillDecodeAsAFinish() throws {
        let json = """
        { "value": [ {
          "wtc_resultid": "9fb8bd9e-3d48-4f42-8894-5ddc75ce3193",
          "wtc_swimtimeformatted": "0:53:18",
          "wtc_transition1timeformatted": "0:06:19",
          "wtc_biketimeformatted": "3:31:03",
          "wtc_transitiontime2formatted": "0:07:34",
          "wtc_runtimeformatted": "2:54:17",
          "wtc_finishtimeformatted": "7:32:31",
          "wtc_finishrankgroup": 2,
          "wtc_finisher": true, "wtc_dnf": false, "wtc_dns": false, "wtc_dq": false,
          "wtc_ContactId": { "contactid": "c", "fullname": "Pattie Wallner" },
          "wtc_EventId": { "wtc_name": "2026 IRONMAN 70.3 Northern California", "wtc_eventdate": "2026-08-16T00:00:00Z" }
        } ] }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(ODataPage.self, from: json).value[0].result
        XCTAssertEqual(result.swim, 3198)
        XCTAssertEqual(result.t1, 379)
        XCTAssertEqual(result.bike, 12663)
        XCTAssertEqual(result.t2, 454)
        XCTAssertEqual(result.run, 10457)
        XCTAssertEqual(result.finish, 27151)
        XCTAssertTrue(result.isComplete)
    }

    func testClockSecondsRejectsJunkAndZero() {
        XCTAssertEqual(ODataResultRow.clockSeconds("52:10"), 3130)
        XCTAssertNil(ODataResultRow.clockSeconds("0:00:00"))
        XCTAssertNil(ODataResultRow.clockSeconds("--:--"))
        XCTAssertNil(ODataResultRow.clockSeconds(""))
        XCTAssertNil(ODataResultRow.clockSeconds(nil))
    }
}
