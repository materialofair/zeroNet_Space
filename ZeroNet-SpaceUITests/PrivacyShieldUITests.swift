import XCTest
import UIKit

/// Uses only the task-created sample vault. Native recording supplies transition evidence.
final class PrivacyShieldUITests: XCTestCase {
    override func setUpWithError() throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["SIMULATOR_DEVICE_NAME"]?.hasPrefix("SealedPocket-Demo-") == true,
                          "Run only on an explicitly prepared SealedPocket-Demo- sample simulator")
    }
    private func samplePixelCount(_ screenshot: XCUIScreenshot, region: CGRect? = nil,
                                  coordinateSize: CGSize? = nil) -> Int {
        var image = UIImage(data: screenshot.pngRepresentation)!.cgImage!
        if let region, let size = coordinateSize {
            let pixelRegion = CGRect(x: region.minX * CGFloat(image.width) / size.width,
                                     y: region.minY * CGFloat(image.height) / size.height,
                                     width: region.width * CGFloat(image.width) / size.width,
                                     height: region.height * CGFloat(image.height) / size.height)
            image = image.cropping(to: pixelRegion.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height)))!
        }
        let width = image.width, height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let countOfBytes = rgba.count
        return rgba.withUnsafeMutableBytes { bytes in
            let pixels = bytes.bindMemory(to: UInt8.self)
            let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            var count = 0
            for i in stride(from: 0, to: countOfBytes, by: 4) {
                let r = Int(pixels[i]), g = Int(pixels[i+1]), b = Int(pixels[i+2])
                if r < 110 && g > 170 && b > 140 && g - b > 15 && b - r > 50 { count += 1 }
            }
            return count
        }
    }
    @MainActor private func selectCategory(_ name: String, index: Int, in app: XCUIApplication) {
        let sidebar = app.buttons["vault.category.\(index)"]
        if sidebar.exists && sidebar.isHittable { sidebar.tap() }
        else { app.buttons[name].firstMatch.tap() }
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = name + "-hierarchy"; tree.lifetime = .keepAlways; add(tree)
        print("SHIELD_EVENT \(Date().timeIntervalSince1970) \(name) samplePixels=\(samplePixelCount(screenshot))")
    }
    @MainActor func testSwitcherMustHidePresentedSample() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]; app.launch()
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 10))
        app.secureTextFields["Enter password"].tap(); app.secureTextFields["Enter password"].typeText("Pocket7391"); app.buttons["Unlock"].tap()
        XCTAssertTrue(app.buttons["Photos"].firstMatch.waitForExistence(timeout: 10)); selectCategory("Photos", index: 0, in: app)
        let photo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vault.photo.")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 5)); photo.tap()
        XCTAssertTrue(app.buttons["trash"].waitForExistence(timeout: 5))
        capture(app, "baseline-detail-visible")
        XCTAssertGreaterThan(samplePixelCount(app.screenshot()), 10000, "Fixture must be visible before protection assertion")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.995))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 1)
        sleep(2)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let card = home.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "card:com.zeronetspace.unlimited-imports:")).firstMatch
        XCTAssertTrue(card.exists)
        capture(home, "switcher-must-be-protected")
        // Photos intentionally retains the original; an adjacent Photos card is outside this app's scope.
        let cardPixels = samplePixelCount(home.screenshot(), region: card.frame, coordinateSize: home.frame.size)
        print("SHIELD_CARD_PIXELS \(cardPixels) rect=\(card.frame)")
        XCTAssertLessThan(cardPixels, 1500, "Private sample must not remain in the SealedPocket app-switcher card")
    }
    @MainActor private func launchDemo() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]; app.launch()
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.secureTextFields["Enter password"].isHittable, "Shield must release login input")
        return app
    }
    @MainActor private func login(_ app: XCUIApplication) {
        let field = app.secureTextFields["Enter password"]
        XCTAssertTrue(field.waitForExistence(timeout: 10)); XCTAssertTrue(field.isHittable)
        field.tap(); field.typeText("Pocket7391"); app.buttons["Unlock"].tap()
        XCTAssertTrue(app.buttons["Photos"].firstMatch.waitForExistence(timeout: 10))
    }
    @MainActor private func openSample(_ app: XCUIApplication) {
        selectCategory("Photos", index: 0, in: app)
        let photo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vault.photo.")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 5)); photo.tap()
        XCTAssertTrue(app.buttons["trash"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["trash"].isHittable)
    }
    @MainActor private func settings(_ app: XCUIApplication) {
        selectCategory("Settings", index: 4, in: app)
        for _ in 0..<6 {
            if app.buttons["Log Out"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["Log Out"].isHittable)
    }
    @MainActor private func setTimeout(_ app: XCUIApplication, _ title: String) {
        settings(app)
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Auto-Lock When Leaving")).firstMatch.tap()
        XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 3)); app.buttons[title].tap()
        capture(app, "setting-" + title)
        selectCategory("Photos", index: 0, in: app)
    }
    @MainActor private func homeAndReturnLocked(_ app: XCUIApplication, _ label: String, delay: UInt32 = 500_000) {
        print("FIX_EVENT \(Date().timeIntervalSince1970) \(label)-home-begin")
        XCUIDevice.shared.press(.home); usleep(delay)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard"); capture(home, label + "-home")
        print("FIX_EVENT \(Date().timeIntervalSince1970) \(label)-return-begin")
        home.icons["SealedPocket"].tap()
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["Enter password"].isHittable)
        XCTAssertLessThan(samplePixelCount(app.screenshot()), 1500)
        capture(app, label + "-return-locked")
    }
    @MainActor func testManualDetailRapidAndCancelledLogout() {
        continueAfterFailure = false
        let app = launchDemo(); login(app); settings(app)
        app.buttons["Log Out"].tap(); XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 3)); app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        XCTAssertTrue(app.buttons["Photos"].firstMatch.isHittable, "Cancelling logout preserves the session")
        capture(app, "cancelled-logout-still-authenticated")
        app.buttons["Log Out"].tap(); app.sheets.buttons["Log Out"].tap()
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 5)); capture(app, "manual-before-home")
        homeAndReturnLocked(app, "manual")
        login(app); openSample(app); capture(app, "detail-before-home")
        homeAndReturnLocked(app, "detail")
        for index in 0..<3 {
            login(app); openSample(app); capture(app, "rapid-\(index)-before-home")
            homeAndReturnLocked(app, "rapid-\(index)", delay: 50_000)
        }
        // Wrong vault password remains locked, correct password still works afterwards.
        app.secureTextFields["Enter password"].tap(); app.secureTextFields["Enter password"].typeText("Wrong7391"); app.buttons["Unlock"].tap()
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 5)); capture(app, "wrong-password-still-locked")
        login(app); openSample(app); capture(app, "correct-password-after-failed-attempt")
    }
    @MainActor func testDelayedSettingsAndInterruptedLockRecover() {
        continueAfterFailure = false
        let app = launchDemo(); login(app)
        for title in ["After 1 Minute", "After 5 Minutes", "Never"] {
            setTimeout(app, title); openSample(app); capture(app, "delayed-detail-" + title)
            XCUIDevice.shared.press(.home); usleep(500_000)
            XCUIApplication(bundleIdentifier: "com.apple.springboard").icons["SealedPocket"].tap()
            XCTAssertTrue(app.buttons["trash"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["trash"].isHittable)
            capture(app, "delayed-return-" + title)
            app.buttons["xmark"].tap()
        }
        setTimeout(app, "Immediately"); openSample(app)
        // Temporary inactive interruption (Notification Center) must cover, then resume.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.001)).press(forDuration: 0.05,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        sleep(1); capture(XCUIApplication(bundleIdentifier: "com.apple.springboard"), "system-interruption")
        XCUIApplication(bundleIdentifier: "com.apple.springboard").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)).press(forDuration: 0.05,
            thenDragTo: XCUIApplication(bundleIdentifier: "com.apple.springboard").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        XCTAssertTrue(app.buttons["trash"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["trash"].isHittable)
        capture(app, "interruption-resumed-detail")
        // Lock, then interrupt the login screen; returning must not leave an input-blocking shield.
        homeAndReturnLocked(app, "interrupted-lock")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.001)).press(forDuration: 0.05,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        sleep(1); XCUIApplication(bundleIdentifier: "com.apple.springboard").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)).press(forDuration: 0.05,
            thenDragTo: XCUIApplication(bundleIdentifier: "com.apple.springboard").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 5)); XCTAssertTrue(app.secureTextFields["Enter password"].isHittable)
        login(app); openSample(app); capture(app, "login-usable-after-lock-interruption")
    }

}
