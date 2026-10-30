import Foundation
import XCTest
@testable import IM_Iron_Splits

/// The string catalog compiles into one .lproj per language, and the plural
/// rules survive the trip. A key that fell back to English would still pass a
/// "not empty" check, so these compare against the catalog's own wording.
final class LocalizationTests: XCTestCase {
    static let languages = ["de", "es", "fr", "it", "ja", "nl", "pl", "pt-BR"]

    private func bundle(_ language: String) -> Bundle? {
        let hosts = [Bundle.main] + Bundle.allBundles
        for host in hosts {
            if let path = host.path(forResource: language, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }

    func testEveryLanguageShips() {
        for language in Self.languages {
            XCTAssertNotNil(bundle(language), "\(language).lproj is missing")
        }
    }

    func testPolishPluralsPickTheRightForm() throws {
        let pl = try XCTUnwrap(bundle("pl"))
        let locale = Locale(identifier: "pl")
        XCTAssertEqual(String(localized: "\(1) podiums", bundle: pl, locale: locale), "1 podium")
        XCTAssertEqual(String(localized: "\(3) podiums", bundle: pl, locale: locale), "3 podia")
        XCTAssertEqual(String(localized: "\(5) podiums", bundle: pl, locale: locale), "5 podiów")
    }

    func testEnglishPluralsReadNaturally() throws {
        let en = try XCTUnwrap(bundle("en") ?? Bundle.main)
        let locale = Locale(identifier: "en")
        XCTAssertEqual(String(localized: "\(1) finishes", bundle: en, locale: locale), "1 finish")
        XCTAssertEqual(String(localized: "\(4) finishes", bundle: en, locale: locale), "4 finishes")
    }

    func testCopyIsTranslated() throws {
        let de = try XCTUnwrap(bundle("de"))
        XCTAssertEqual(String(localized: "Locker", bundle: de), "Spind")
        XCTAssertEqual(String(localized: "Half distance", bundle: de), "Mitteldistanz")
        let ja = try XCTUnwrap(bundle("ja"))
        XCTAssertEqual(String(localized: "Bike", bundle: ja), "バイク")
        let ptBR = try XCTUnwrap(bundle("pt-BR"))
        XCTAssertEqual(String(localized: "Settings", bundle: ptBR), "Ajustes")
    }

    func testFormattedSentenceKeepsItsArgument() throws {
        let fr = try XCTUnwrap(bundle("fr"))
        let value = String(localized: "Bib \(String(1009))", bundle: fr, locale: Locale(identifier: "fr"))
        XCTAssertEqual(value, "Dossard 1009")
    }
}
