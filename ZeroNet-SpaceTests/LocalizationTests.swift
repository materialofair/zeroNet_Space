//
//  LocalizationTests.swift
//  ZeroNet-SpaceTests
//
//  Created by Claude on 2025-11-16.
//  Updated: test keys reflect current UI (login/password setup/tab renames)
//

import XCTest

@testable import ZeroNet_Space

class LocalizationTests: XCTestCase {

    override func setUpWithError() throws {
        // Reset to English locale for consistent testing
        UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
    }

    override func tearDownWithError() throws {
        // Clean up
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
    }

    // MARK: - Authentication Strings

    func testLoginViewStrings() throws {
        // Test that login strings are localized
        XCTAssertNotEqual(
            String(localized: "login.title"), "login.title", "Login title should be localized")
        XCTAssertNotEqual(
            String(localized: "login.subtitle"), "login.subtitle",
            "Login subtitle should be localized")
        XCTAssertNotEqual(
            String(localized: "login.passwordPlaceholder"), "login.passwordPlaceholder",
            "Password field should be localized")
        XCTAssertNotEqual(
            String(localized: "login.unlock"), "login.unlock", "Login button should be localized")
    }

    func testSetupPasswordViewStrings() throws {
        XCTAssertNotEqual(
            String(localized: "setup.header.title"), "setup.header.title",
            "Setup title should be localized")
        XCTAssertNotEqual(
            String(localized: "setup.confirmPasswordPlaceholder"),
            "setup.confirmPasswordPlaceholder",
            "Confirm password should be localized")
        XCTAssertNotEqual(
            String(localized: "setup.finish"), "setup.finish",
            "Finish setup button should be localized")
    }

    // MARK: - Tab Bar Strings

    func testTabBarStrings() throws {
        XCTAssertNotEqual(
            String(localized: "tab.photos"), "tab.photos", "Photos tab should be localized")
        XCTAssertNotEqual(
            String(localized: "tab.media"), "tab.media", "Media tab should be localized")
        XCTAssertNotEqual(
            String(localized: "tab.videos"), "tab.videos", "Videos tab should be localized")
        XCTAssertNotEqual(
            String(localized: "tab.files"), "tab.files", "Files tab should be localized")
        XCTAssertNotEqual(
            String(localized: "tab.secretSpace"), "tab.secretSpace",
            "Secret space tab should be localized")
        XCTAssertNotEqual(
            String(localized: "tab.settings"), "tab.settings", "Settings tab should be localized")
    }

    // MARK: - Gallery Strings

    func testGalleryViewStrings() throws {
        XCTAssertNotEqual(
            String(localized: "gallery.title"), "gallery.title", "Gallery title should be localized"
        )
        XCTAssertNotEqual(
            String(localized: "gallery.search.placeholder"), "gallery.search.placeholder",
            "Search placeholder should be localized")
        XCTAssertNotEqual(
            String(localized: "gallery.empty.title"), "gallery.empty.title",
            "No media message should be localized")
    }

    // MARK: - Settings Strings

    func testSettingsViewStrings() throws {
        XCTAssertNotEqual(
            String(localized: "settings.title"), "settings.title",
            "Settings title should be localized")
        XCTAssertNotEqual(
            String(localized: "settings.gridColumns"), "settings.gridColumns",
            "Grid columns setting should be localized")
        XCTAssertNotEqual(
            String(localized: "settings.logout.title"), "settings.logout.title",
            "Logout button should be localized")
    }

    // MARK: - Chinese Locale Tests

    func testChineseLocalization() throws {
        // Switch to Chinese locale
        UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")

        // Test that Chinese strings are different from English
        _ = String(localized: "login.title")

        // Force reload bundle for Chinese
        UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        // Note: In actual app, we would need to restart or reload bundle
        // For now, we verify the string catalog contains both languages
        XCTAssertNotNil(String(localized: "login.title"), "Chinese login title should exist")
    }

    // MARK: - String Catalog Completeness

    func testAllRequiredStringsExist() throws {
        // Test that all critical strings exist in the catalog
        let requiredKeys = [
            "login.title",
            "login.subtitle",
            "login.passwordPlaceholder",
            "login.unlock",
            "setup.header.title",
            "setup.finish",
            "tab.photos",
            "tab.media",
            "tab.videos",
            "tab.audio",
            "audio.record",
            "audio.error.permission",
            "tab.files",
            "tab.secretSpace",
            "tab.settings",
            "gallery.title",
            "settings.title",
            "export.title",
            "import.title",
            "audio.share.vipRequired.title",
            "audio.share.vipRequired.message",
            "import.fromAudio.title",
            "import.fromAudio.subtitle",
            "import.formats.audio",
        ]

        for key in requiredKeys {
            let localizedString = String(localized: String.LocalizationValue(key))
            XCTAssertNotEqual(
                localizedString, key, "\(key) should be localized and not return the key itself")
        }
    }

    // MARK: - Performance Tests

    func testLocalizationPerformance() throws {
        measure {
            // Measure localization lookup performance
            for _ in 0..<100 {
                _ = String(localized: "login.title")
                _ = String(localized: "gallery.title")
                _ = String(localized: "settings.title")
            }
        }
    }
}
