import Foundation
import PDFKit
import UIKit
import XCTest
@testable import IM_Iron_Splits

final class RaceBookTests: XCTestCase {

    func testComparisonReportsLegDeltasWithinOneDistance() {
        let older = Self.result(id: "older",
                                date: "2023-09-10T00:00:00Z",
                                bikeDistance: 180,
                                swim: 3_900,
                                bike: 18_000,
                                run: 15_000,
                                finish: 39_000)
        let newer = Self.result(id: "newer",
                                date: "2025-09-07T00:00:00Z",
                                bikeDistance: 180,
                                swim: 3_720,
                                bike: 18_300,
                                run: 14_700,
                                finish: 38_100)
        let half = Self.result(id: "half",
                               date: "2024-06-01T00:00:00Z",
                               bikeDistance: 90,
                               swim: 1_800,
                               bike: 8_400,
                               run: 7_200,
                               finish: 18_000)

        let pair = RaceBookAnalytics.comparisonPair([newer, half, older], kind: .fullDistance)
        XCTAssertEqual(pair?.0.id, older.id)
        XCTAssertEqual(pair?.1.id, newer.id)

        let deltas = RaceBookAnalytics.deltas(earlier: older, later: newer)
        XCTAssertEqual(deltas.first { $0.discipline == .swim }?.change, -180)
        XCTAssertEqual(deltas.first { $0.discipline == .bike }?.change, 300)
        XCTAssertEqual(deltas.first { $0.discipline == .run }?.change, -300)
        XCTAssertTrue(deltas.first { $0.discipline == .swim }?.improved == true)
        XCTAssertTrue(RaceBookAnalytics.deltas(earlier: older, later: half).isEmpty,
                      "A full-distance race must never be compared to a half-distance race")
    }

    func testProgressionIsChronologicalAndIgnoresIncompleteRows() {
        let oldest = Self.result(id: "oldest",
                                 date: "2022-09-10T00:00:00Z",
                                 bikeDistance: 180,
                                 swim: 4_000,
                                 bike: 19_000,
                                 run: 16_000,
                                 finish: 40_000)
        let newest = Self.result(id: "newest",
                                 date: "2025-09-07T00:00:00Z",
                                 bikeDistance: 180,
                                 swim: 3_700,
                                 bike: 18_000,
                                 run: 14_500,
                                 finish: 37_000)
        let incomplete = Self.result(id: "dnf",
                                     date: "2024-09-08T00:00:00Z",
                                     bikeDistance: 180,
                                     swim: 3_000,
                                     bike: 10_000,
                                     run: nil,
                                     finish: nil,
                                     finisher: false,
                                     dnf: true)

        let points = RaceBookAnalytics.progression([newest, incomplete, oldest],
                                                   discipline: .finish,
                                                   kind: .fullDistance)
        XCTAssertEqual(points.map(\.result.id), ["oldest", "newest"])
        XCTAssertEqual(points.map(\.seconds), [40_000, 37_000])
    }

    func testExportContainsCareerStatsAndPrivateNotes() throws {
        let athlete = Athlete(id: "athlete", name: "Test Athlete", city: "Madison", stateOrProvince: "WI")
        let result = Self.result(id: "race",
                                 date: "2025-09-07T00:00:00Z",
                                 bikeDistance: 180,
                                 swim: 3_600,
                                 bike: 18_000,
                                 run: 14_400,
                                 finish: 36_000,
                                 divisionRank: 2)
        let note = RaceNote(resultID: result.id,
                            conditions: "Hot and windy",
                            nutrition: "Carried more sodium",
                            notes: "Hold the line on the run")
        let text = RaceBookBuilder.plainText(athlete: athlete,
                                             results: [result],
                                             notes: [result.id: note])

        XCTAssertTrue(text.contains("RACE BOOK: TEST ATHLETE"))
        XCTAssertTrue(text.contains("1 finishes, 1 podiums"))
        XCTAssertTrue(text.contains("Hot and windy"))
        XCTAssertTrue(text.contains("Bib 1009"))
        XCTAssertTrue(text.contains("Splits: Swim"))
        XCTAssertTrue(text.contains("Notes: Hold the line on the run"))

        let pdf = RaceBookBuilder.pdf(athlete: athlete, results: [result], notes: [result.id: note])
        let image = RaceBookBuilder.image(athlete: athlete, results: [result], notes: [result.id: note])
        let pdfURL = try XCTUnwrap(pdf)
        let imageURL = try XCTUnwrap(image)
        XCTAssertGreaterThan(try Data(contentsOf: pdfURL).count, 500)
        XCTAssertGreaterThan(try Data(contentsOf: imageURL).count, 500)
        if let pdf { try? FileManager.default.removeItem(at: pdf) }
        if let image { try? FileManager.default.removeItem(at: image) }
    }

    func testExportKeepsLongHistoryAndNotesVisible() throws {
        let athlete = Athlete(id: "athlete", name: "Test Athlete", city: "Madison", stateOrProvince: "WI")
        let results = (0..<24).map { index in
            Self.result(id: "history-\(index)",
                        date: "\(2002 + index)-09-07T00:00:00Z",
                        bikeDistance: 180,
                        swim: 3_600 - index,
                        bike: 18_000 - index,
                        run: 14_400 - index,
                        finish: 36_000 - index,
                        raceName: index == 23
                            ? "Final finish with a deliberately long event name that must wrap safely"
                            : nil)
        }
        let lastResult = try XCTUnwrap(results.last)
        let longNote = String(repeating: "A detailed race-day note that must remain in the exported artifact. ", count: 16)
        let note = RaceNote(resultID: lastResult.id,
                            conditions: "Warm, windy, and humid",
                            notes: longNote)

        let pdfURL = try XCTUnwrap(RaceBookBuilder.pdf(athlete: athlete,
                                                       results: results,
                                                       notes: [lastResult.id: note]))
        let imageURL = try XCTUnwrap(RaceBookBuilder.image(athlete: athlete,
                                                           results: results,
                                                           notes: [lastResult.id: note]))
        defer {
            try? FileManager.default.removeItem(at: pdfURL)
            try? FileManager.default.removeItem(at: imageURL)
        }

        let document = try XCTUnwrap(PDFDocument(url: pdfURL))
        XCTAssertGreaterThan(document.pageCount, 1, "A full career should paginate instead of clipping")
        let extractedText = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
        XCTAssertTrue(extractedText.contains("Final finish with a deliberately long event name"))
        XCTAssertTrue(extractedText.contains("A detailed race-day note"))

        let image = try XCTUnwrap(UIImage(contentsOfFile: imageURL.path))
        XCTAssertGreaterThanOrEqual(image.size.width, 1170,
                                    "The shareable image should keep a high-resolution canvas")
        XCTAssertGreaterThan(image.size.height, 1500,
                             "The shareable image should contain the full history, not a fixed cover")
    }

    func testProGateLeavesResultsFreeAndOnlyRaceBookUsesEntitlement() {
        let result = Self.result(id: "race",
                                 date: "2025-09-07T00:00:00Z",
                                 bikeDistance: 180,
                                 swim: 3_600,
                                 bike: 18_000,
                                 run: 14_400,
                                 finish: 36_000)
        XCTAssertFalse(ProGate.raceBookUnlocked(isPro: false))
        XCTAssertTrue(ProGate.raceBookUnlocked(isPro: true))
        XCTAssertEqual(ProGate.visibleResults([result], isPro: false), [result])
        XCTAssertEqual(ProGate.lockedCount([result], isPro: false), 0)
        XCTAssertFalse(ProGate.isLocked(result, in: [result], isPro: false))
    }

    func testAppearancePreferencesMapToSystemLightAndDark() {
        XCTAssertNil(AppearancePreference.system.colorScheme)
        XCTAssertEqual(AppearancePreference.light.colorScheme, .light)
        XCTAssertEqual(AppearancePreference.dark.colorScheme, .dark)
    }
}

private extension RaceBookTests {
    static func result(id: String,
                       date: String,
                       bikeDistance: Int,
                       swim: Int?,
                       bike: Int?,
                       run: Int?,
                       finish: Int?,
                       divisionRank: Int? = nil,
                       finisher: Bool = true,
                       dnf: Bool = false,
                       raceName: String? = nil) -> RaceResult {
        let swim = swim.map(String.init) ?? "null"
        let bike = bike.map(String.init) ?? "null"
        let run = run.map(String.init) ?? "null"
        let finish = finish.map(String.init) ?? "null"
        let rank = divisionRank.map(String.init) ?? "null"
        return ODataResultRow.decode("""
        {
          "wtc_resultid": "\(id)",
          "wtc_bibnumber": "1,009",
          "wtc_swimtime": \(swim),
          "wtc_biketime": \(bike),
          "wtc_runtime": \(run),
          "wtc_finishtime": \(finish),
          "wtc_bikedistancecompleted": \(bikeDistance),
          "wtc_rundistancecompleted": 42.2,
          "wtc_finishrankgroup": \(rank),
          "wtc_finisher": \(finisher),
          "wtc_dnf": \(dnf),
          "wtc_EventId": {
            "wtc_name": "\(raceName ?? "\(date.prefix(4)) IRONMAN Wisconsin")",
            "wtc_eventdate": "\(date)"
          },
          "wtc_ContactId": {
            "contactid": "athlete",
            "fullname": "Test Athlete"
          }
        }
        """).result
    }
}
