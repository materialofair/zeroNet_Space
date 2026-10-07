import XCTest
@testable import ZeroNet_Space

/// Checks compiled app resources, rather than relying on source catalog key counts.
final class LocalizationCoverageTests: XCTestCase {
    private let languages = ["zh-Hant", "ja", "pl", "de", "fr", "es", "pt-BR", "id"]
    private let keys = ["setup.header.title", "login.unlock", "tab.photos", "tab.media", "tab.audio", "tab.files", "tab.secretSpace", "tab.settings", "action.cancel", "action.confirm", "filePreview.error.decrypt", "iap.restorePurchases", "iap.error.noPurchaseToRestore", "audio.share.vipRequired.message", "media.error.deleteFailed"]

    func testCompiledLanguagesAndCriticalFlows() throws {
        for language in languages {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"), "Missing bundled locale: \(language)")
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in keys {
                let text = bundle.localizedString(forKey: key, value: "__MISSING__", table: "Localizable")
                XCTAssertNotEqual(text, "__MISSING__", "\(language): \(key)")
                XCTAssertNotEqual(text, key, "\(language): leaked key \(key)")
                XCTAssertFalse(text.isEmpty, "\(language): empty \(key)")
            }
            let permissionsPath = try XCTUnwrap(bundle.path(forResource: "InfoPlist", ofType: "strings"))
            let data = try Data(contentsOf: URL(fileURLWithPath: permissionsPath))
            let permissions = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
            XCTAssertEqual(permissions["CFBundleDisplayName"], "ZeroNet Space")
            for key in ["NSMicrophoneUsageDescription", "NSPhotoLibraryUsageDescription"] {
                XCTAssertFalse(try XCTUnwrap(permissions[key]).isEmpty)
            }
        }
    }

    func testPolishPluralRendering() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "pl", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        let format = bundle.localizedString(forKey: "folders.itemCount", value: nil, table: "Localizable")
        let expected = [1: "1 element", 2: "2 elementy", 5: "5 elementów", 12: "12 elementów", 22: "22 elementy"]
        for (count, text) in expected {
            XCTAssertEqual(String(format: format, locale: Locale(identifier: "pl_PL"), count), text)
        }
    }

    func testOtherAddedLanguagePluralRendering() throws {
        let samples: [(String, String, String)] = [
            ("de", "1 Element", "2 Elemente"),
            ("fr", "1 élément", "2 éléments"),
            ("es", "1 elemento", "2 elementos"),
            ("pt-BR", "1 item", "2 itens"),
            ("id", "1 item", "2 item")
        ]
        for (language, one, other) in samples {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            let format = bundle.localizedString(forKey: "folders.itemCount", value: nil, table: "Localizable")
            XCTAssertEqual(String(format: format, locale: Locale(identifier: language), 1), one)
            XCTAssertEqual(String(format: format, locale: Locale(identifier: language), 2), other)
        }
    }
}
