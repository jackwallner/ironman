import Foundation
@testable import IM_Iron_Splits

extension ODataResultRow {
    static func decode(_ json: String) -> ODataResultRow {
        // Force-unwrapped on purpose: a fixture that stops decoding is a broken
        // test, and a nil here would be reported as an unrelated assertion.
        try! JSONDecoder().decode(ODataResultRow.self, from: json.data(using: .utf8)!)
    }

    static func zeroSplitFixture() -> ODataResultRow {
        decode("""
        {
          "wtc_resultid": "dnf-1",
          "wtc_swimtime": 3600,
          "wtc_biketime": 9000,
          "wtc_runtime": 0,
          "wtc_finishtime": 0,
          "wtc_finisher": false,
          "wtc_dnf": true
        }
        """)
    }

    static func athleteFixtures() -> [ODataResultRow] {
        [
            row(id: "1", first: "Daniel", last: "Winek", contact: "a508fd19-3e5e-45d2-9a18-47215c7bcb40",
                event: "2023 IRONMAN Tulsa", date: "2023-05-21T00:00:00Z"),
            row(id: "2", first: "Daniel", last: "Winek", contact: "a508fd19-3e5e-45d2-9a18-47215c7bcb40",
                event: "2025 IRONMAN Wisconsin", date: "2025-09-07T00:00:00Z"),
            row(id: "3", first: "Suzanne", last: "Wineke", contact: "b608fd19-3e5e-45d2-9a18-47215c7bcb41",
                event: "2024 IRONMAN Texas", date: "2024-04-27T00:00:00Z"),
        ]
    }

    /// A row with the contact fields the identity merge actually reads.
    static func contactRow(id: String, first: String, last: String, contact: String,
                           city: String?, state: String?, gender: String,
                           event: String, date: String) -> ODataResultRow {
        let cityJSON = city.map { "\"address1_city\": \"\($0)\"," } ?? ""
        let stateJSON = state.map { "\"address1_stateorprovince\": \"\($0)\"," } ?? ""
        return decode("""
        {
          "wtc_resultid": "\(id)",
          "wtc_finisher": true,
          "wtc_ContactId": {
            "contactid": "\(contact)",
            "firstname": "\(first)",
            "lastname": "\(last)",
            "fullname": "\(first) \(last)",
            \(cityJSON)
            \(stateJSON)
            "gendercode_formatted": "\(gender)"
          },
          "wtc_EventId": { "wtc_name": "\(event)", "wtc_eventdate": "\(date)" }
        }
        """)
    }

    private static func row(id: String, first: String, last: String, contact: String,
                            event: String, date: String) -> ODataResultRow {
        decode("""
        {
          "wtc_resultid": "\(id)",
          "wtc_finisher": true,
          "wtc_ContactId": {
            "contactid": "\(contact)",
            "firstname": "\(first)",
            "lastname": "\(last)",
            "fullname": "\(first) \(last)",
            "address1_city": "MADISON",
            "address1_stateorprovince": "WI"
          },
          "wtc_EventId": { "wtc_name": "\(event)", "wtc_eventdate": "\(date)" }
        }
        """)
    }
}
