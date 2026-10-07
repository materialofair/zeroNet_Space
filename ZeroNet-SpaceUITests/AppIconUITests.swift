import XCTest

final class AppIconUITests: XCTestCase {
    @MainActor
    func testIconGalleryAndVIPGate() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-DemoModeEnabled", "NO", "-hasUnlockedUnlimited", "NO",
            "-autoLockTimeout", "-1"
        ]
        app.launch()
        let password = "AudioUITest-7391"
        if app.secureTextFields["Re-enter password"].waitForExistence(timeout: 5) {
            app.secureTextFields["Enter password"].tap()
            app.secureTextFields["Enter password"].typeText(password)
            app.secureTextFields["Re-enter password"].tap()
            app.secureTextFields["Re-enter password"].typeText(password + "\n")
        } else if app.secureTextFields["Enter password"].exists {
            app.secureTextFields["Enter password"].tap()
            app.secureTextFields["Enter password"].typeText(password)
            app.buttons["Unlock"].tap()
        }
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        app.buttons["settings.appIcon"].tap()
        for name in ["primary", "paper", "calculator", "pebble", "ruler"] {
            XCTAssertTrue(app.buttons["appicon.\(name)"].waitForExistence(timeout: 5))
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "App icon gallery"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["appicon.paper"].tap()
        XCTAssertTrue(app.alerts["App icons · VIP"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.buttons["Unlock VIP"].exists)
        app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(app.buttons["appicon.primary"].value as? String, "In use")
        app.buttons["appicon.primary"].tap()
        XCTAssertFalse(app.alerts["App icons · VIP"].exists)
    }
}
