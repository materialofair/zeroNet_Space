import XCTest

final class AudioUITests: XCTestCase {
    @MainActor
    func testAudioNavigationAndImportPicker() throws {
        continueAfterFailure = false
        let app = openAudioPage()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Audio tab"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["audio.import"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["audio.record"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func openAudioPage() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
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
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.buttons["Media"].waitForExistence(timeout: 10))
        XCTAssertEqual(tabs.buttons.allElementsBoundByIndex.map(\.label), ["Photos", "Media", "Files", "Notes", "Settings"])
        tabs.buttons["Media"].tap()
        let audioSegment = app.segmentedControls.buttons["Audio"]
        if audioSegment.waitForExistence(timeout: 3) {
            audioSegment.tap()
        }
        XCTAssertTrue(app.buttons["audio.import"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["audio.record"].waitForExistence(timeout: 3))
        tabs.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        tabs.buttons["Media"].tap()
        if audioSegment.waitForExistence(timeout: 3) {
            audioSegment.tap()
        }
        XCTAssertTrue(app.buttons["audio.record"].waitForExistence(timeout: 3))

        return app
    }

    @MainActor
    func testAudioNavigationRecordingPlaybackAndDelete() throws {
        continueAfterFailure = false
        let app = openAudioPage()

        app.buttons["audio.record"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3) {
            let allow = springboard.alerts.buttons["Allow"]
            if allow.exists { allow.tap() }
            else if springboard.alerts.buttons["OK"].exists { springboard.alerts.buttons["OK"].tap() }
            else if springboard.alerts.buttons["允许"].exists { springboard.alerts.buttons["允许"].tap() }
            else if springboard.alerts.buttons["好"].exists { springboard.alerts.buttons["好"].tap() }
        }
        XCTAssertTrue(app.staticTexts["Recording"].waitForExistence(timeout: 5))
        let elapsed = app.staticTexts.matching(NSPredicate(
            format: "label MATCHES %@ AND label != %@", "[0-9]{2}:[0-9]{2}", "00:00")).firstMatch
        XCTAssertTrue(elapsed.waitForExistence(timeout: 5))
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.staticTexts["Paused"].exists)
        app.buttons["Resume Recording"].tap()
        XCTAssertTrue(app.staticTexts["Recording"].exists)
        let recording = XCTAttachment(screenshot: app.screenshot())
        recording.name = "Audio recording"
        recording.lifetime = .keepAlways
        add(recording)
        app.buttons["audio.save"].tap()
        let memo = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "New Recording ")).firstMatch
        XCTAssertTrue(memo.waitForExistence(timeout: 10))
        app.buttons["Play"].firstMatch.tap()
        XCTAssertTrue(app.sliders["Playback position"].waitForExistence(timeout: 5))
        app.sliders["Playback position"].adjust(toNormalizedSliderPosition: 0.5)
        let list = XCTAttachment(screenshot: app.screenshot())
        list.name = "Audio playback"
        list.lifetime = .keepAlways
        add(list)
        memo.press(forDuration: 1)
        app.buttons["Rename"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        let previous = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + "UI Audio Memo")
        app.alerts.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["UI Audio Memo"].waitForExistence(timeout: 3))
        app.staticTexts["UI Audio Memo"].swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        app.alerts.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["audio.record"].exists)
        XCTAssertFalse(app.staticTexts["UI Audio Memo"].exists)
        app.buttons["audio.import"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }
}
