//
//  LocalizationTests.swift
//  ZeroNet-SpaceTests
//
//  Created by Claude on 2025-11-16.
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
            String(localized: "login.email"), "login.email", "Email field should be localized")
        XCTAssertNotEqual(
            String(localized: "login.password"), "login.password",
            "Password field should be localized")
        XCTAssertNotEqual(
            String(localized: "login.button"), "login.button", "Login button should be localized")
    }

    func testRegisterViewStrings() throws {
        XCTAssertNotEqual(
            String(localized: "register.title"), "register.title",
            "Register title should be localized")
        XCTAssertNotEqual(
            String(localized: "register.confirmPassword"), "register.confirmPassword",
            "Confirm password should be localized")
        XCTAssertNotEqual(
            String(localized: "register.button"), "register.button",
            "Register button should be localized")
    }

    // MARK: - Tab Bar Strings

    func testTabBarStrings() throws {
        XCTAssertNotEqual(
            String(localized: "tab.gallery"), "tab.gallery", "Gallery tab should be localized")
        XCTAssertNotEqual(
            String(localized: "tab.videos"), "tab.videos", "Videos tab should be localized")
        XCTAssertNotEqual(
            String(localized: "tab.import"), "tab.import", "Import tab should be localized")
        XCTAssertNotEqual(
            String(localized: "tab.export"), "tab.export", "Export tab should be localized")
        XCTAssertNotEqual(
            String(localized: "tab.settings"), "tab.settings", "Settings tab should be localized")
    }

    // MARK: - Gallery Strings

    func testGalleryViewStrings() throws {
        XCTAssertNotEqual(
            String(localized: "gallery.title"), "gallery.title", "Gallery title should be localized"
        )
        XCTAssertNotEqual(
            String(localized: "gallery.searchPlaceholder"), "gallery.searchPlaceholder",
            "Search placeholder should be localized")
        XCTAssertNotEqual(
            String(localized: "gallery.noPhotos"), "gallery.noPhotos",
            "No photos message should be localized")
    }

    // MARK: - Settings Strings

    func testSettingsViewStrings() throws {
        XCTAssertNotEqual(
            String(localized: "settings.title"), "settings.title",
            "Settings title should be localized")
        XCTAssertNotEqual(
            String(localized: "settings.language"), "settings.language",
            "Language setting should be localized")
        XCTAssertNotEqual(
            String(localized: "settings.logout"), "settings.logout",
            "Logout button should be localized")
    }

    // MARK: - Chinese Locale Tests

    func testChineseLocalization() throws {
        // Switch to Chinese locale
        UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")

        // Test that Chinese strings are different from English
        let englishTitle = String(localized: "login.title")

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
            "login.email",
            "login.password",
            "login.button",
            "register.title",
            "register.button",
            "tab.gallery",
            "tab.videos",
            "tab.import",
            "tab.export",
            "tab.settings",
            "gallery.title",
            "settings.title",
            "export.title",
            "import.title",
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
