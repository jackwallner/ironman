import XCTest
@testable import IM_Iron_Splits

/// Scratch tests for the 2026-10-30 overnight audit. Not committed.
/// Each test asserts the CORRECT behaviour, so a failure confirms a finding.
final class ScratchAuditTests: XCTestCase {

    // MARK: - Fixtures

    private struct FixedResultsAPI: ResultsProviding {
        let rows: [RaceResult]
        var delay: Duration = .zero

        func searchAthletes(matching query: String, depth: SearchDepth) async throws -> AthleteSearchResponse {
            AthleteSearchResponse(athletes: [], hasUnsupportedResults: false, wasTruncated: false)
        }

        func results(forAthleteID athleteID: String) async throws -> [RaceResult] {
            try await results(forContactIDs: [athleteID])
        }

        func results(forContactIDs contactIDs: [String]) async throws -> [RaceResult] {
            if delay > .zero { try await Task.sleep(for: delay) }
            return rows
        }

        func results(forEventID eventID: String) async throws -> [RaceResult] { [] }
    }

    private static let athlete = Athlete(id: "a508fd19-3e5e-45d2-9a18-47215c7bcb40",
                                         name: "Audit Athlete",
                                         knownRaceCount: 1)

    private func full(id: String, year: Int, swim: Int) -> RaceResult {
        RaceResult(
            id: id, eventID: "event-" + id, eventName: "\(year) IRONMAN Wisconsin",
            eventDate: DateComponents(calendar: .current, year: year, month: 9, day: 7).date,
            externalEventName: nil, athleteID: "athlete", athleteName: "Audit Athlete",
            bib: 100, ageGroup: "M50-54", countryISO2: "US",
            swim: swim, t1: 300, bike: 18_000, t2: 180, run: 14_400,
            finish: swim + 300 + 18_000 + 180 + 14_400,
            swimDistanceKm: 3.86, bikeDistanceKm: 180.8, runDistanceKm: 42.2,
            swimRankOverall: 10, bikeRankOverall: 10, runRankOverall: 10,
            finishRankOverall: 10, finishRankGender: 10, finishRankGroup: 5,
            swimRankGroup: 3, bikeRankGroup: 3, runRankGroup: 3,
            isFinisher: true, didNotFinish: false, didNotStart: false, disqualified: false
        )
    }

    /// Real shapes from the live feed on 2026-10-30: a DNF row reports the
    /// distance actually covered, and no bike split when the bike was not
    /// finished.
    private func dnfRow(event: String, date: String, bikeKm: Double) -> ODataResultRow {
        ODataResultRow.decode("""
        {
          "wtc_resultid": "dnf-\(bikeKm)",
          "wtc_finisher": false,
          "wtc_dnf": true,
          "wtc_dns": false,
          "wtc_dq": false,
          "wtc_swimtime": 4300,
          "wtc_transition1time": 400,
          "wtc_biketime": 0,
          "wtc_runtime": 0,
          "wtc_finishtime": 0,
          "wtc_swimdistancecompleted": 3.8624,
          "wtc_bikedistancecompleted": \(bikeKm),
          "wtc_rundistancecompleted": 0.0,
          "wtc_ContactId": { "contactid": "a508fd19-3e5e-45d2-9a18-47215c7bcb40", "fullname": "Audit Athlete" },
          "wtc_EventId": { "wtc_name": "\(event)", "wtc_eventdate": "\(date)" }
        }
        """)
    }

    // MARK: - Locker refresh race

    @MainActor
    func testClaimingTheSameAthleteWhileARefreshRunsDoesNotStrandTheLocker() async throws {
        let api = FixedResultsAPI(rows: [full(id: "r1", year: 2024, swim: 3600)], delay: .milliseconds(700))
        let store = LockerStore(api: api, storage: LockerStorage())
        store.unclaim()
        await store.claim(Self.athlete)
        XCTAssertEqual(store.state, .loaded)
        XCTAssertEqual(store.results.count, 1)

        // A refresh is in flight (pull to refresh, Settings > Refresh results,
        // or the launch refresh after 30 minutes)...
        let refresh = Task { @MainActor in await store.refresh(force: true) }
        try await Task.sleep(for: .milliseconds(150))
        // ...and the same person is claimed again from Change athlete.
        await store.claim(Self.athlete)
        await refresh.value
        try await Task.sleep(for: .milliseconds(1_200))

        XCTAssertEqual(store.state, .loaded, "Locker left in \(store.state) with \(store.results.count) results")
        XCTAssertEqual(store.results.count, 1)
        store.unclaim()
    }

    @MainActor
    func testRemoveAndReclaimWhileARefreshRunsSavesTheLocker() async throws {
        let api = FixedResultsAPI(rows: [full(id: "r1", year: 2024, swim: 3600)], delay: .milliseconds(700))
        let store = LockerStore(api: api, storage: LockerStorage())
        store.unclaim()
        await store.claim(Self.athlete)
        XCTAssertEqual(store.state, .loaded)

        let refresh = Task { @MainActor in await store.refresh(force: true) }
        try await Task.sleep(for: .milliseconds(150))
        store.unclaim()                     // Settings > Remove my athlete
        await store.claim(Self.athlete)     // onboarding finds the same person
        await refresh.value
        try await Task.sleep(for: .milliseconds(1_200))

        XCTAssertEqual(store.state, .loaded, "Locker left in \(store.state) with \(store.results.count) results")
        XCTAssertNotNil(LockerStorage().load(), "Nothing was saved, so a relaunch returns to onboarding")
        store.unclaim()
    }

    // MARK: - DNF race kind

    func testAFullDistanceDNFOnTheBikeIsStillAFull() {
        // 2025 IRONMAN Texas: 34 of its 298 DNF rows stopped between 60 and 140 km.
        let row = dnfRow(event: "2025 IRONMAN Texas", date: "2025-04-26T00:00:00Z", bikeKm: 99.6511)
        XCTAssertEqual(row.result.kind, .fullDistance)
    }

    func testAnEarlyBikeDNFStaysInTheAthletesHistory() {
        // 2026 IRONMAN 70.3 Northern California: 18 of its 100 DNF rows stopped
        // before 60 km; 2025 IRONMAN Texas: 29 of 298.
        let half = dnfRow(event: "2026 IRONMAN 70.3 Northern California", date: "2026-08-16T00:00:00Z", bikeKm: 44.5466)
        XCTAssertEqual(half.result.kind, .halfDistance)
        let full = dnfRow(event: "2025 IRONMAN Texas", date: "2025-04-26T00:00:00Z", bikeKm: 46.0009)
        XCTAssertEqual(full.result.kind, .fullDistance)
    }

    @MainActor
    func testAnEarlyBikeDNFAppearsInTheLocker() async throws {
        let dnf = dnfRow(event: "2025 IRONMAN Texas", date: "2025-04-26T00:00:00Z", bikeKm: 46.0009).result
        let finish = full(id: "f1", year: 2024, swim: 3600)
        let store = LockerStore(api: FixedResultsAPI(rows: [dnf, finish]), storage: LockerStorage())
        store.unclaim()
        await store.claim(Self.athlete)
        XCTAssertEqual(store.results.count, 2, "Locker shows \(store.results.map(\.eventName))")
        XCTAssertEqual(RaceAnalytics.summary(store.results).starts, 2)
        store.unclaim()
    }

    // MARK: - Personal best ties

    func testATiedBestLegIsAPersonalBestForEveryRaceThatSetIt() {
        let a = full(id: "tie-a", year: 2023, swim: 3600)
        let b = full(id: "tie-b", year: 2024, swim: 3600)
        let c = full(id: "tie-c", year: 2025, swim: 3700)
        let results = [a, b, c]
        let atBest = RaceAnalytics.standings(results, discipline: .swim, kind: .fullDistance)
            .filter { $0.gapToBest == 0 }
        XCTAssertEqual(atBest.count, 2, "Rankings label both rows Personal best and Locker badges both")
        XCTAssertEqual(RaceAnalytics.isPersonalBest(a, discipline: .swim, within: results),
                       RaceAnalytics.isPersonalBest(b, discipline: .swim, within: results),
                       "The race detail badges only one of two tied races")
    }

    // MARK: - Same-name strangers

    /// Live feed, 2026-10-30: a common two-word male name returned one search
    /// row built from two contacts in the same city whose age groups in the
    /// same season were M45-49 and M30-34. Names here are fictional.
    func testSameNameSameCityStrangersStayTwoAthletes() {
        func row(_ id: String, contact: String, ageGroup: String, event: String, date: String) -> ODataResultRow {
            ODataResultRow.decode("""
            {
              "wtc_resultid": "\(id)",
              "wtc_finisher": true,
              "wtc_finishtime": 21338,
              "wtc_biketime": 10000,
              "wtc_bikedistancecompleted": 90.1,
              "_wtc_agegroupid_value_formatted": "\(ageGroup)",
              "wtc_ContactId": { "contactid": "\(contact)", "firstname": "Sam", "lastname": "Rivera",
                                 "fullname": "Sam Rivera", "address1_city": "Henderson",
                                 "address1_stateorprovince": "US-NV", "address1_country": "usa",
                                 "gendercode_formatted": "Male" },
              "wtc_EventId": { "wtc_name": "\(event)", "wtc_eventdate": "\(date)" }
            }
            """)
        }
        let rows = [
            row("a1", contact: "f1d44741-1048-ed11-bba1-000d3a314d17", ageGroup: "M45-49",
                event: "2018 IRONMAN 70.3 Santa Cruz", date: "2018-09-09T00:00:00Z"),
            row("b1", contact: "f98c1655-3981-f111-ab0e-70a8a5ae8eaa", ageGroup: "M30-34",
                event: "2018 IRONMAN 70.3 Arizona", date: "2018-12-09T00:00:00Z"),
        ]
        let athletes = ResultsAPI.collapseToAthletes(rows)
        XCTAssertEqual(athletes.count, 2, "Merged into \(athletes.map(\.contactIDs))")
    }

    // MARK: - Year in a US time zone

    /// The feed dates every event at UTC midnight. West of UTC that instant is
    /// still the previous day, so a 1 January race must not file under the
    /// previous year while its date label (rendered in UTC) says January 1.
    func testAJanuaryFirstRaceKeepsItsYearInPacificTime() {
        let saved = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "America/Los_Angeles")!
        defer { NSTimeZone.default = saved }
        let row = ODataResultRow.decode("""
        {
          "wtc_resultid": "jan1",
          "wtc_finisher": true,
          "wtc_finishtime": 21338,
          "wtc_biketime": 10000,
          "wtc_bikedistancecompleted": 90.1,
          "wtc_EventId": { "wtc_name": "2026 IRONMAN 70.3 New Year", "wtc_eventdate": "2026-01-01T00:00:00Z" }
        }
        """)
        XCTAssertEqual(RaceDate.medium(row.result.eventDate!), "Jan 1, 2026")
        XCTAssertEqual(row.result.year, 2026, "Listed under \(row.result.year) while labelled Jan 1, 2026")
    }

    // MARK: - Notes persistence

    @MainActor
    func testOneUnreadableNoteDoesNotEraseTheOthersOnTheNextSave() throws {
        let url = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                              appropriateFor: nil, create: true)
            .appendingPathComponent("race-notes.json")
        let backup = try? Data(contentsOf: url)
        defer {
            if let backup { try? backup.write(to: url) } else { try? FileManager.default.removeItem(at: url) }
        }
        // The second note has one field fewer than today's RaceNote, which is
        // exactly what every saved note looks like the day a field is added.
        let saved = """
        {"kona-2024": {"resultID": "kona-2024", "conditions": "38C on the run", "nutrition": "",
                       "gear": "", "notes": "Cramped at mile 18", "updatedAt": 750000000},
         "texas-2023": {"resultID": "texas-2023", "conditions": "", "nutrition": "Gel every 30 min",
                        "gear": "", "notes": ""}}
        """
        try Data(saved.utf8).write(to: url)

        let store = RaceNotesStore()
        XCTAssertEqual(store.notes.count, 2, "Loaded \(store.notes.count) of 2 saved notes")
        store.save(RaceNote(resultID: "wisconsin-2025", notes: "New PB"))

        let reloaded = RaceNotesStore()
        XCTAssertNotNil(reloaded.notes["kona-2024"], "Saving one note erased the notes that failed to load")
    }
}
