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

    func testProxyErrorEnvelopeIsRecognised() throws {
        let json = #"{"error":"Invalid results URL"}"#.data(using: .utf8)!
        let envelope = try JSONDecoder().decode(ODataErrorEnvelope.self, from: json)
        XCTAssertEqual(envelope.error, "Invalid results URL")
    }
}
