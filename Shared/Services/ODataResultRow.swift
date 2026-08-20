import Foundation

struct ODataErrorEnvelope: Decodable {
    let error: String?
}

struct ODataPage: Decodable {
    let value: [ODataResultRow]
    let nextLink: String?

    private enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

/// One raw row from the upstream results table.
///
/// Numeric columns are not consistently typed: the same rank arrives as `3` on
/// one row and `"4"` on the next, and `wtc_bibnumber_formatted` is a
/// thousands-separated string ("1,009"). Every number therefore goes through
/// `LooseInt` / `LooseDouble` rather than a plain `Int`, because a single
/// strict decode would throw away a whole page over one string-typed rank.
struct ODataResultRow: Decodable, Sendable {
    struct Contact: Decodable, Sendable {
        let contactid: String?
        let firstname: String?
        let lastname: String?
        let fullname: String?
        let address1_city: String?
        let address1_stateorprovince: String?
        let address1_country: String?
        let gendercode_formatted: String?
    }

    struct Event: Decodable, Sendable {
        let wtc_eventid: String?
        let wtc_name: String?
        let wtc_eventdate: String?
        let wtc_externaleventname: String?
    }

    struct Country: Decodable, Sendable {
        let wtc_iso2: String?
        let wtc_name: String?
    }

    let wtc_resultid: String?
    let _wtc_eventid_value: String?
    let _wtc_agegroupid_value_formatted: String?

    let wtc_ContactId: Contact?
    let wtc_EventId: Event?
    let wtc_CountryRepresentingId: Country?

    let wtc_bibnumber: LooseInt?
    let wtc_swimtime: LooseInt?
    let wtc_transition1time: LooseInt?
    let wtc_biketime: LooseInt?
    let wtc_transition2time: LooseInt?
    let wtc_runtime: LooseInt?
    let wtc_finishtime: LooseInt?

    let wtc_swimdistancecompleted: LooseDouble?
    let wtc_bikedistancecompleted: LooseDouble?
    let wtc_rundistancecompleted: LooseDouble?

    let wtc_swimrankoverall: LooseInt?
    let wtc_bikerankoverall: LooseInt?
    let wtc_runrankoverall: LooseInt?
    let wtc_finishrankoverall: LooseInt?
    let wtc_finishrankgender: LooseInt?
    let wtc_finishrankgroup: LooseInt?
    let wtc_swimrankgroup: LooseInt?
    let wtc_bikerankgroup: LooseInt?
    let wtc_runrankgroup: LooseInt?

    let wtc_finisher: Bool?
    let wtc_dnf: Bool?
    let wtc_dns: Bool?
    let wtc_dq: Bool?

    var contact: Contact? { wtc_ContactId }

    var result: RaceResult {
        let name = wtc_ContactId?.fullname
            ?? [wtc_ContactId?.firstname, wtc_ContactId?.lastname].compactMap { $0 }.joined(separator: " ")
        return RaceResult(
            id: wtc_resultid ?? UUID().uuidString,
            eventID: _wtc_eventid_value ?? wtc_EventId?.wtc_eventid ?? "",
            eventName: wtc_EventId?.wtc_name ?? "Unknown race",
            eventDate: Self.parseDate(wtc_EventId?.wtc_eventdate),
            externalEventName: wtc_EventId?.wtc_externaleventname,
            athleteID: wtc_ContactId?.contactid,
            athleteName: name.isEmpty ? "Unknown athlete" : name,
            bib: wtc_bibnumber?.value,
            ageGroup: _wtc_agegroupid_value_formatted,
            countryISO2: wtc_CountryRepresentingId?.wtc_iso2,
            swim: Self.positive(wtc_swimtime),
            t1: Self.positive(wtc_transition1time),
            bike: Self.positive(wtc_biketime),
            t2: Self.positive(wtc_transition2time),
            run: Self.positive(wtc_runtime),
            finish: Self.positive(wtc_finishtime),
            swimDistanceKm: wtc_swimdistancecompleted?.value,
            bikeDistanceKm: wtc_bikedistancecompleted?.value,
            runDistanceKm: wtc_rundistancecompleted?.value,
            swimRankOverall: Self.positive(wtc_swimrankoverall),
            bikeRankOverall: Self.positive(wtc_bikerankoverall),
            runRankOverall: Self.positive(wtc_runrankoverall),
            finishRankOverall: Self.positive(wtc_finishrankoverall),
            finishRankGender: Self.positive(wtc_finishrankgender),
            finishRankGroup: Self.positive(wtc_finishrankgroup),
            swimRankGroup: Self.positive(wtc_swimrankgroup),
            bikeRankGroup: Self.positive(wtc_bikerankgroup),
            runRankGroup: Self.positive(wtc_runrankgroup),
            isFinisher: wtc_finisher ?? false,
            didNotFinish: wtc_dnf ?? false,
            didNotStart: wtc_dns ?? false,
            disqualified: wtc_dq ?? false
        )
    }

    /// Zero is the feed's "no data" for both times and ranks — a DNF carries a
    /// 0 run split, not a missing one — so it has to become nil here or every
    /// leaderboard sorts the people who didn't run to the top.
    private static func positive(_ loose: LooseInt?) -> Int? {
        guard let value = loose?.value, value > 0 else { return nil }
        return value
    }

    /// Parse "2025-09-07T00:00:00Z" by hand.
    ///
    /// A shared `ISO8601DateFormatter` is not `Sendable`, and building one per
    /// row costs more than the parse: a single athlete-history fetch decodes a
    /// few thousand of these, and a field fetch several thousand more. The feed
    /// only ever emits UTC midnight in this one layout, so reading the digits
    /// directly is both correct and the cheap option.
    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, raw.count >= 10 else { return nil }
        let digits = Array(raw.utf8)
        func number(_ range: Range<Int>) -> Int? {
            var value = 0
            for index in range {
                let byte = digits[index]
                guard byte >= 48, byte <= 57 else { return nil }
                value = value * 10 + Int(byte - 48)
            }
            return value
        }
        guard let year = number(0..<4), let month = number(5..<7), let day = number(8..<10) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        if digits.count >= 19, digits[10] == UInt8(ascii: "T") {
            components.hour = number(11..<13)
            components.minute = number(14..<16)
            components.second = number(17..<19)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar.date(from: components)
    }
}

/// An integer that may arrive as a number, or as a string with separators.
struct LooseInt: Decodable, Sendable {
    let value: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = Int(double)
        } else if let string = try? container.decode(String.self) {
            value = Int(string.replacingOccurrences(of: ",", with: ""))
        } else {
            value = nil
        }
    }
}

struct LooseDouble: Decodable, Sendable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = Double(string.replacingOccurrences(of: ",", with: ""))
        } else {
            value = nil
        }
    }
}
