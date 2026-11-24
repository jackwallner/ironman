// State machine audit repro suite, 2026-11-24.
//
// Kept out of the test target on purpose. To run it, copy this file into
// `IronSplitsTests/` and run
// `gh-sim test --scheme IronSplits --only IronSplitsTests/StateMachineAuditRepro`.
// Each claim test asserts its preconditions first; each claim has a control
// that passes on the starting commit.

import Foundation
import XCTest
@preconcurrency import RevenueCat
@testable import IM_Iron_Splits

/// A results feed the test drives by hand: every call waits until the test
/// answers it, so in-flight refreshes can overlap the way they do on a slow feed.
actor ScriptedFeed: ResultsProviding {
    private var waiting: [CheckedContinuation<[RaceResult], Error>] = []
    private(set) var calls: [[String]] = []

    func searchAthletes(matching query: String, depth: SearchDepth) async throws -> AthleteSearchResponse {
        throw URLError(.notConnectedToInternet)
    }

    func results(forAthleteID athleteID: String) async throws -> [RaceResult] {
        try await results(forContactIDs: [athleteID])
    }

    func results(forContactIDs contactIDs: [String]) async throws -> [RaceResult] {
        calls.append(contactIDs)
        return try await withCheckedThrowingContinuation { waiting.append($0) }
    }

    func results(forEventID eventID: String) async throws -> [RaceResult] { [] }

    var pendingCount: Int { waiting.count }

    func answerOldest(with results: [RaceResult]) {
        guard !waiting.isEmpty else { return }
        waiting.removeFirst().resume(returning: results)
    }

    func failOldest() {
        guard !waiting.isEmpty else { return }
        waiting.removeFirst().resume(throwing: URLError(.timedOut))
    }
}

@MainActor
final class StateMachineAuditRepro: XCTestCase {
    private var savedLocker: LockerSnapshot?

    override func setUp() async throws {
        savedLocker = LockerStorage().load()
        LockerStorage().clear()
    }

    override func tearDown() async throws {
        if let savedLocker { LockerStorage().save(savedLocker) } else { LockerStorage().clear() }
    }

    // MARK: Fixtures

    static func race(_ id: String, date: String = "2025-09-07T00:00:00Z") -> RaceResult {
        ODataResultRow.decode("""
        {
          "wtc_resultid": "\(id)",
          "wtc_swimtime": 3700,
          "wtc_biketime": 17800,
          "wtc_runtime": 14700,
          "wtc_finishtime": 37000,
          "wtc_bikedistancecompleted": 180,
          "wtc_rundistancecompleted": 42.2,
          "wtc_finisher": true,
          "wtc_EventId": { "wtc_name": "IRONMAN Wisconsin \(id)", "wtc_eventdate": "\(date)" },
          "wtc_ContactId": { "contactid": "athlete", "fullname": "Test Athlete" }
        }
        """).result
    }

    /// A `CustomerInfo` decoded the way RevenueCat's backend sends it.
    static func customerInfo(ownsRaceBook: Bool) throws -> CustomerInfo {
        let entitlements = ownsRaceBook ? """
        "pro": { "expires_date": null, "product_identifier": "com.jackwallner.ironman.pro",
                 "purchase_date": "2026-11-01T00:00:00Z" }
        """ : ""
        let purchases = ownsRaceBook ? """
        "com.jackwallner.ironman.pro": [{ "id": "t1", "purchase_date": "2026-11-01T00:00:00Z",
          "original_purchase_date": "2026-11-01T00:00:00Z", "store": "app_store", "is_sandbox": true }]
        """ : ""
        let json = """
        {
          "request_date": "2026-11-24T00:00:00Z",
          "subscriber": {
            "original_app_user_id": "audit",
            "first_seen": "2026-01-01T00:00:00Z",
            "subscriptions": {},
            "non_subscriptions": { \(purchases) },
            "entitlements": { \(entitlements) }
          }
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CustomerInfo.self, from: Data(json.utf8))
    }

    private func settle(_ feed: ScriptedFeed, calls: Int) async {
        for _ in 0..<200 {
            if await feed.pendingCount >= calls { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: M1. A restore that found nothing keeps saying so after Race Book unlocks

    /// Settings shows `store.restoreError` in red under "Race Book is unlocked"
    /// (`SettingsView.swift:113-131`). Once the purchase lands the line must go.
    func testRestoreErrorClearsWhenRaceBookUnlocks() async throws {
        let store = StoreService.shared
        store.apply(customerInfo: try Self.customerInfo(ownsRaceBook: false))
        await store.restorePurchases()
        XCTAssertFalse(store.isPro, "precondition: not unlocked")
        XCTAssertNotNil(store.restoreError, "precondition: the restore left an error line")

        store.apply(customerInfo: try Self.customerInfo(ownsRaceBook: true))
        XCTAssertTrue(store.isPro, "precondition: the purchase unlocked Race Book")
        XCTAssertNil(store.restoreError, "Settings says unlocked and 'No Race Book purchase was found' at once")

        store.apply(customerInfo: try Self.customerInfo(ownsRaceBook: false))
    }

    func testControlRestoreErrorStaysWhileStillLocked() async throws {
        let store = StoreService.shared
        store.apply(customerInfo: try Self.customerInfo(ownsRaceBook: false))
        await store.restorePurchases()
        store.apply(customerInfo: try Self.customerInfo(ownsRaceBook: false))
        XCTAssertFalse(store.isPro)
        XCTAssertNotNil(store.restoreError, "a still-locked account keeps the restore result")
    }

    // MARK: M2. Adding a registration empties the Locker when the merged fetch fails

    func testFailedAddRegistrationKeepsTheCareerOnScreen() async {
        let feed = ScriptedFeed()
        let locker = LockerStore(api: feed)
        let claim = Task { await locker.claim(Athlete(id: "a", name: "Test Athlete")) }
        await settle(feed, calls: 1)
        await feed.answerOldest(with: [Self.race("r1"), Self.race("r2", date: "2024-09-08T00:00:00Z")])
        await claim.value
        XCTAssertEqual(locker.results.count, 2, "precondition: the career loaded")
        XCTAssertEqual(locker.state, .loaded)

        let add = Task { await locker.addContact(from: Athlete(id: "b", name: "Test A")) }
        await settle(feed, calls: 1)
        await feed.failOldest()
        await add.value
        XCTAssertEqual(locker.athlete?.contactIDs, ["a", "b"], "precondition: the merged fetch was the one that failed")

        XCTAssertEqual(locker.results.count, 2, "a failed fetch must not empty a Locker that had races")
        XCTAssertEqual(locker.state, .loaded)
    }

    func testControlSuccessfulAddRegistrationMergesRaces() async {
        let feed = ScriptedFeed()
        let locker = LockerStore(api: feed)
        let claim = Task { await locker.claim(Athlete(id: "a", name: "Test Athlete")) }
        await settle(feed, calls: 1)
        await feed.answerOldest(with: [Self.race("r1")])
        await claim.value

        let add = Task { await locker.addContact(from: Athlete(id: "b", name: "Test A")) }
        await settle(feed, calls: 1)
        await feed.answerOldest(with: [Self.race("r1"), Self.race("r3", date: "2023-05-21T00:00:00Z")])
        await add.value
        XCTAssertEqual(locker.results.map(\.id).sorted(), ["r1", "r3"])
        XCTAssertEqual(locker.state, .loaded)
    }

    // MARK: M3. Re-claiming the same athlete during a refresh leaves the Locker loading forever

    func testReclaimDuringRefreshStillLoadsTheCareer() async {
        let feed = ScriptedFeed()
        let locker = LockerStore(api: feed)
        let athlete = Athlete(id: "a", name: "Test Athlete")
        let first = Task { await locker.claim(athlete) }
        await settle(feed, calls: 1)
        await feed.answerOldest(with: [Self.race("r1")])
        await first.value
        XCTAssertEqual(locker.state, .loaded, "precondition: claimed and loaded")

        // A refresh is in flight (launch, pull to refresh) when the athlete
        // confirms "Replace" on the same person from Settings > Change athlete.
        let refresh = Task { await locker.refresh(force: true) }
        await settle(feed, calls: 1)
        let reclaim = Task { await locker.claim(athlete) }
        try? await Task.sleep(for: .milliseconds(100))
        await feed.answerOldest(with: [Self.race("r1")])
        await refresh.value
        await settle(feed, calls: 1)
        await feed.answerOldest(with: [Self.race("r1")])
        await reclaim.value

        XCTAssertEqual(locker.state, .loaded, "the Locker sits on a spinner with no races")
        XCTAssertEqual(locker.results.map(\.id), ["r1"])
    }

    func testControlClaimingAnotherAthleteDuringRefreshLoadsThem() async {
        let feed = ScriptedFeed()
        let locker = LockerStore(api: feed)
        let first = Task { await locker.claim(Athlete(id: "a", name: "Test Athlete")) }
        await settle(feed, calls: 1)
        await feed.answerOldest(with: [Self.race("r1")])
        await first.value

        let refresh = Task { await locker.refresh(force: true) }
        await settle(feed, calls: 1)
        let other = Task { await locker.claim(Athlete(id: "z", name: "Other Athlete")) }
        await settle(feed, calls: 2)
        await feed.answerOldest(with: [Self.race("r1")])
        await refresh.value
        await feed.answerOldest(with: [Self.race("z1")])
        await other.value
        XCTAssertEqual(locker.state, .loaded)
        XCTAssertEqual(locker.results.map(\.id), ["z1"])
    }
}
