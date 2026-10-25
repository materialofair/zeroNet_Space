import XCTest
import UIKit

/// Requires a task-created, disposable simulator. Uses normal authentication and import UI.
final class DuoAdaptiveUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"]?.hasPrefix("SealedPocket-Demo-") == true)
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "UNRELEASED-" + name; shot.lifetime = .keepAlways; add(shot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-hierarchy"; tree.lifetime = .keepAlways; add(tree)
        print("DUO_EVIDENCE \(name) \(app.frame)")
        if name == "photos-grid" || name == "photos-imported" { sleep(3) }
    }
    @MainActor private func login() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let field = app.secureTextFields["Enter password"]
        XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + "Pocket7391")
        if app.secureTextFields["Re-enter password"].exists {
            app.secureTextFields["Re-enter password"].tap()
            app.secureTextFields["Re-enter password"].typeText("Pocket7391\n")
        } else { app.buttons["Unlock"].tap() }
        XCTAssertTrue(app.buttons["Photos"].firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        return app
    }
    @MainActor private func category(_ name: String, _ index: Int, _ app: XCUIApplication) {
        let side = app.buttons["vault.category.\(index)"]
        if side.exists && side.isHittable { side.tap() }
        else { app.buttons[name].firstMatch.tap() }
    }
    @MainActor func testPreparePhotoImport() {
        let app = login(); category("Photos", 0, app); capture(app, "photos-empty")
        if app.buttons["Start Importing"].exists { app.buttons["Start Importing"].tap() }
        else { app.buttons["plus.circle.fill"].firstMatch.tap() }
        let photos = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "From Photos")).firstMatch
        XCTAssertTrue(photos.waitForExistence(timeout: 5), app.debugDescription); photos.tap()
        let fixtures = app.images.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "PXGGridLayout-Info", "10月21日"))
        XCTAssertTrue(fixtures.firstMatch.waitForExistence(timeout: 8), app.debugDescription)
        print(app.debugDescription)
        XCTAssertGreaterThanOrEqual(fixtures.count, 6)
        capture(app, "system-photo-picker")
        for image in fixtures.allElementsBoundByIndex.prefix(6) {
            image.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let done = app.navigationBars.buttons["Done"].firstMatch
        let add = app.navigationBars.buttons["Add"].firstMatch
        if done.exists && done.isHittable { XCTAssertTrue(done.isEnabled); done.tap() }
        else { XCTAssertTrue(add.isEnabled && add.isHittable); add.tap() }
        XCTAssertTrue(app.alerts.buttons["OK"].waitForExistence(timeout: 20), app.debugDescription)
        app.alerts.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 10)); capture(app, "photos-imported")
    }
    @MainActor func testBrowseDraftAndRotation() {
        let app = login(); category("Photos", 0, app); capture(app, "photos-grid")
        category("Files", 2, app); capture(app, "files")
        category("Media", 1, app); app.segmentedControls.buttons["Audio"].tap()
        XCTAssertTrue(app.buttons["audio.record"].waitForExistence(timeout: 3)); capture(app, "audio")
        category("Notes", 3, app)
        if app.staticTexts["Fictional Duo Draft"].exists { app.staticTexts["Fictional Duo Draft"].firstMatch.tap() }
        else if app.buttons["New Note"].exists { app.buttons["New Note"].firstMatch.tap() }
        else { app.buttons["plus"].firstMatch.tap() }
        let title = app.textFields.firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap()
        if (title.value as? String ?? "") == "Note title" || (title.value as? String ?? "").isEmpty {
            title.typeText("Fictional Duo Draft")
        }
        let expectedTitle = title.value as? String
        app.textViews.firstMatch.tap(); app.textViews.firstMatch.typeText(" Only synthetic demo content. Keep this unsaved while folding.")
        capture(app, "note-keyboard-before-rotation")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(title.value as? String, expectedTitle)
        XCTAssertTrue((app.textViews.firstMatch.value as? String ?? "").contains("synthetic demo content"))
        XCTAssertTrue(app.buttons["Save"].isHittable)
        XCTAssertGreaterThanOrEqual(app.textViews.firstMatch.frame.height, 44, "Editor must remain usable above the keyboard")
        capture(app, "note-keyboard-after-rotation")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(title.value as? String, expectedTitle); app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[expectedTitle ?? "Fictional Duo Draft"].firstMatch.waitForExistence(timeout: 5)); capture(app, "notes-saved-once")
    }
    /// Operate the official Device Hub fold control during this assertion window.
    @MainActor func testInteractiveFoldKeepsDraft() {
        let app = login(); category("Notes", 3, app)
        if app.staticTexts["Fictional Duo Draft"].exists { app.staticTexts["Fictional Duo Draft"].tap() }
        else { app.buttons["New Note"].firstMatch.tap() }
        let title = app.textFields.firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap()
        let old = title.value as? String ?? ""
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + "Fold Preserved Draft")
        let content = app.textViews.firstMatch
        content.tap()
        let draftContent = "Synthetic unsaved Duo note. Keep title, body and keyboard through folding."
        let previous = content.value as? String ?? ""
        content.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + draftContent)
        capture(app, "fold-draft-start")
        for i in 0..<90 {
            XCTAssertEqual(title.value as? String, "Fold Preserved Draft")
            XCTAssertEqual(content.value as? String, draftContent)
            let save = app.buttons["Save"]
            let reachable = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in save.isHittable }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [reachable], timeout: 5), .completed)
            if i % 5 == 0 { capture(app, "fold-draft-\(i)") }
            sleep(1)
        }
        capture(app, "fold-draft-end")
    }
    @MainActor func testPhotoPreviewExportAndLock() {
        let app = login(); category("Photos", 0, app)
        let photo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vault.photo.")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 5)); photo.tap()
        XCTAssertTrue(app.buttons["trash"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["square.and.arrow.up"].isHittable)
        capture(app, "detail-visible")
        app.buttons["square.and.arrow.up"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10), app.debugDescription)
        print("SHARE_EVIDENCE_READY")
        sleep(15)
        capture(app, "normal-share-presented")
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.activate()
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["Enter password"].isHittable)
        XCTAssertFalse(app.buttons["trash"].exists)
        XCTAssertFalse(app.buttons["Save to Files"].exists)
        XCTAssertFalse(app.buttons["Copy"].exists)
        capture(app, "share-background-return-locked")
        app.secureTextFields["Enter password"].tap()
        app.secureTextFields["Enter password"].typeText("Wrong7391")
        app.buttons["Unlock"].tap()
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["trash"].exists)
        capture(app, "failed-auth-remains-locked")
    }

    @MainActor func testInteractiveFoldKeepsSearchAndSelection() {
        let app = login(); category("Photos", 0, app)
        XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 5))
        app.buttons["Select"].tap()
        app.buttons["Select All"].tap()
        capture(app, "selection-fold-start")
        for i in 0..<60 {
            XCTAssertTrue(app.buttons["Deselect All"].exists)
            if i % 5 == 0 { capture(app, "selection-fold-\(i)") }
            sleep(1)
        }
        app.buttons["Cancel"].tap()
        // Search is kept by the same screen instance across width changes.
        if !app.searchFields.firstMatch.isHittable { app.swipeDown() }
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3)); search.tap(); search.typeText("Duo search preserved")
        capture(app, "search-fold-start")
        for i in 0..<45 {
            XCTAssertEqual(search.value as? String, "Duo search preserved")
            if i % 5 == 0 { capture(app, "search-fold-\(i)") }
            sleep(1)
        }
    }

    @MainActor func testHoldPhotosForEvidence() {
        let app = login(); category("Photos", 0, app)
        XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 5))
        print("PHOTO_EVIDENCE_READY")
        sleep(25)
        capture(app, "photos-evidence")
    }

    @MainActor func testFictionalFileImportAndPreview() {
        let app = login(); category("Files", 2, app)
        let row = app.staticTexts["Demo-Checklist"]
        if !row.exists {
            app.buttons["plus.circle.fill"].firstMatch.tap()
            app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "From Files")).firstMatch.tap()
            sleep(1)
            print("FILE_PICKER " + app.debugDescription)
            let browse = app.buttons["Browse"].firstMatch
            if browse.exists && browse.isHittable { browse.tap() }
            let local = app.staticTexts["On My iPhone"].firstMatch
            if local.waitForExistence(timeout: 3) { local.tap() }
            print("LOCAL_FILES " + app.debugDescription)
            let file = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Demo-Checklist")).firstMatch
            XCTAssertTrue(file.waitForExistence(timeout: 5), app.debugDescription); file.tap()
            let open = app.buttons["Open"].firstMatch
            if open.exists && open.isHittable { open.tap() }
            XCTAssertTrue(app.alerts.buttons["OK"].waitForExistence(timeout: 15), app.debugDescription)
            app.alerts.buttons["OK"].tap()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "FICTIONAL TEST FILE")).firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        capture(app, "fictional-file-preview")
        XCUIDevice.shared.press(.home); sleep(1); app.activate()
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "FICTIONAL TEST FILE")).firstMatch.exists)
        capture(app, "file-background-return-locked")
    }

    @MainActor func testPrimaryVoiceOverLabels() throws {
        continueAfterFailure = true
        let app = login()
        for (name, index) in [("Photos",0),("Files",2),("Notes",3),("Settings",4)] {
            category(name,index,app)
            XCTAssertTrue(app.navigationBars[name].exists)
            if #available(iOS 17.0, *) {
                try app.performAccessibilityAudit(for: .sufficientElementDescription)
            } else { throw XCTSkip("Accessibility audit requires iOS 17") }
        }
        capture(app,"voiceover-label-audit")
    }

    @MainActor func testInteractiveSearchFold() {
        let app = login(); category("Photos",0,app)
        if !app.searchFields.firstMatch.isHittable { app.swipeDown() }
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3)); search.tap(); search.typeText("Duo search preserved")
        print("SEARCH_FOLD_READY")
        var widths: Set<Int> = []
        for i in 0..<60 {
            XCTAssertEqual(search.value as? String, "Duo search preserved")
            widths.insert(Int(app.frame.width))
            if i % 5 == 0 { capture(app, "search-actual-fold-\(i)") }
            sleep(1)
        }
        XCTAssertTrue(widths.contains { $0 < 640 }, "Must actually fold, not just wait")
        XCTAssertTrue(widths.contains { $0 >= 640 }, "Must actually unfold, not just wait")
    }

    @MainActor func testHoldShareForManualCopy() {
        let app = login(); category("Photos",0,app)
        let photo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vault.photo.")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout:5)); photo.tap()
        XCTAssertTrue(app.buttons["square.and.arrow.up"].waitForExistence(timeout:5))
        app.buttons["square.and.arrow.up"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout:10))
        print("MANUAL_COPY_READY")
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !app.otherElements["ActivityListView"].exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 90), .completed,
                       "Operator must complete the actual system Copy action")
        XCTAssertTrue(app.buttons["trash"].exists)
        capture(app,"normal-copy-completed")
    }

    @MainActor private func importFictionalFile(_ name: String, app: XCUIApplication) {
        category("Files", 2, app)
        if app.staticTexts[name].firstMatch.exists { return }
        app.buttons["plus.circle.fill"].firstMatch.tap()
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "From Files")).firstMatch.tap()
        let browse = app.buttons["Browse"].firstMatch
        if browse.waitForExistence(timeout: 3) && browse.isHittable { browse.tap() }
        let local = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["On My iPhone", "On My iPad"])).firstMatch
        if local.waitForExistence(timeout: 3) { local.tap() }
        let file = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 8), app.debugDescription); file.tap()
        let open = app.buttons["Open"].firstMatch
        if open.exists && open.isHittable { open.tap() }
        XCTAssertTrue(app.alerts.buttons["OK"].waitForExistence(timeout: 20), app.debugDescription)
        app.alerts.buttons["OK"].tap()
    }

    @MainActor private func assertLockedWithoutPresentation(_ app: XCUIApplication, name: String) {
        XCUIDevice.shared.press(.home); sleep(1); app.activate()
        capture(app, name + "-before-login-assertion")
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 8), app.debugDescription)
        sleep(3) // Old preview/export callbacks must not resurrect a sheet after returning.
        XCTAssertFalse(app.otherElements["ActivityListView"].exists)
        XCTAssertFalse(app.buttons["ellipsis"].exists)
        XCTAssertFalse(app.buttons["ellipsis.circle"].exists)
        XCTAssertFalse(app.buttons["More"].exists)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "FICTIONAL PDF")).firstMatch.exists)
        capture(app, name)
    }

    @MainActor func testPDFPreviewShareAndLock() {
        let app = login()
        importFictionalFile("Fictional-Privacy", app: app)
        let pdf = app.staticTexts["Fictional-Privacy"].firstMatch
        XCTAssertTrue(pdf.waitForExistence(timeout: 5)); pdf.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "FICTIONAL PDF")).firstMatch.waitForExistence(timeout: 8), app.debugDescription)
        capture(app, "pdf-preview-loaded")
        let shares = app.buttons.matching(identifier: "vault.preview.share")
        XCTAssertTrue(shares.firstMatch.waitForExistence(timeout: 5))
        guard let share = shares.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("Current PDF share button must be reachable: " + app.debugDescription); return
        }
        share.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 15), app.debugDescription)
        capture(app, "pdf-share-presented")
        assertLockedWithoutPresentation(app, name: "pdf-share-return-locked")
    }

    @MainActor func testVideoPlaybackShareAndLock() {
        let app = login()
        category("Media", 1, app)
        if app.segmentedControls.buttons["Videos"].exists { app.segmentedControls.buttons["Videos"].tap() }
        if !app.buttons.matching(NSPredicate(format: "value CONTAINS %@", "Fictional-Motion")).firstMatch.exists {
            importFictionalFile("Fictional-Motion", app: app)
            category("Media", 1, app)
            app.segmentedControls.buttons["Videos"].tap()
        }
        let video = app.buttons.matching(NSPredicate(format: "value CONTAINS %@", "Fictional-Motion")).firstMatch
        XCTAssertTrue(video.waitForExistence(timeout: 8), app.debugDescription); video.tap()
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.staticTexts["00:03"].exists, "The actual decrypted video duration must load")
        capture(app, "video-playback-loaded")
        app.buttons["More"].tap()
        app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Share")).firstMatch.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 15), app.debugDescription)
        capture(app, "video-share-presented")
        assertLockedWithoutPresentation(app, name: "video-share-return-locked")
    }

    @MainActor func testPDFLoadingRevokedByLock() {
        let app = login(); category("Files", 2, app)
        let pdf = app.staticTexts["Fictional-Privacy"].firstMatch
        XCTAssertTrue(pdf.waitForExistence(timeout: 5)); pdf.tap()
        assertLockedWithoutPresentation(app, name: "pdf-open-immediate-lock")
        app.secureTextFields["Enter password"].tap()
        app.secureTextFields["Enter password"].typeText("Wrong7391")
        app.buttons["Unlock"].tap()
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "FICTIONAL PDF")).firstMatch.exists)
    }

    @MainActor func testStoreScreenshotSources() {
        let app = login()
        for (name, index) in [("Photos",0),("Files",2),("Notes",3),("Media",1)] {
            category(name, index, app)
            XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
            sleep(2) // Capture after the native category transition finishes rendering.
            capture(app, "store-source-" + name.lowercased())
            print("STORE_SOURCE_" + name.uppercased())
            sleep(8)
        }
    }

    @MainActor func testPrepareStoreFictionalContent() {
        var app = login(); category("Photos", 0, app)
        if !app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vault.photo.")).firstMatch.exists {
            testPreparePhotoImport()
            app = XCUIApplication()
        }
        importFictionalFile("Fictional-Privacy", app: app)
        category("Notes", 3, app)
        if !app.staticTexts["Weekend checklist"].exists {
            if app.buttons["New Note"].exists { app.buttons["New Note"].tap() }
            else { app.buttons["plus"].firstMatch.tap() }
            XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
            app.textFields.firstMatch.tap(); app.textFields.firstMatch.typeText("Weekend checklist")
            app.textViews.firstMatch.tap(); app.textViews.firstMatch.typeText("Pack a notebook. Bring a camera. Take a walk.\nFictional sample for the app preview.")
            app.buttons["Save"].tap()
            XCTAssertTrue(app.staticTexts["Weekend checklist"].waitForExistence(timeout: 5))
        }
    }

    @MainActor func testStoreScreenshotSourcesChinese() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let password = app.secureTextFields.firstMatch
        XCTAssertTrue(password.waitForExistence(timeout: 10)); password.tap()
        password.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + "Pocket7391")
        app.buttons["解锁"].tap()
        XCTAssertTrue(app.buttons["相片"].firstMatch.waitForExistence(timeout: 10))
        for (name, index, marker) in [("相片",0,"PHOTOS"),("文件",2,"FILES"),("笔记",3,"NOTES"),("影音",1,"MEDIA")] {
            category(name, index, app)
            sleep(2)
            capture(app, "store-zh-source-" + marker.lowercased())
            print("STORE_ZH_SOURCE_" + marker)
            sleep(8)
        }
    }

    private func fictionalTealPixels(_ shot: XCUIScreenshot, region: CGRect? = nil,
                                     coordinateSize: CGSize? = nil) -> Int {
        var image = UIImage(data: shot.pngRepresentation)!.cgImage!
        if let region, let size = coordinateSize {
            let rect = CGRect(x: region.minX * CGFloat(image.width) / size.width,
                              y: region.minY * CGFloat(image.height) / size.height,
                              width: region.width * CGFloat(image.width) / size.width,
                              height: region.height * CGFloat(image.height) / size.height)
            image = image.cropping(to: rect)!
        }
        let width = image.width, height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let bytesCount = rgba.count
        return rgba.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            let pixels = bytes.bindMemory(to: UInt8.self)
            return stride(from: 0, to: bytesCount, by: 4).reduce(0) { count, i in
                let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
                return count + (r < 110 && g > 170 && b > 140 && g >= b - 15 && b - r > 60 ? 1 : 0)
            }
        }
    }

    @MainActor private func verifySwitcherFromNestedShare(_ app: XCUIApplication, name: String) {
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 15))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.995))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 1)
        sleep(2)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let card = springboard.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "card:com.zeronetspace.unlimited-imports:")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), springboard.debugDescription)
        capture(springboard, name + "-switcher")
        let count = fictionalTealPixels(springboard.screenshot(), region: card.frame,
                                       coordinateSize: springboard.frame.size)
        print("SENSITIVE_SWITCHER_PIXELS \(name) \(count)")
        XCTAssertLessThan(count, 1500, "The vault card must hide the fictional document/video and share thumbnail")
        // The simulated Home key from the switcher did not leave this app's foreground
        // state on this runtime. Activate a harmless system app to prove real backgrounding.
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.activate()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 10))
        capture(settings, name + "-system-foreground")
        let background = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.state != .runningForeground
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [background], timeout: 10), .completed,
                       "Must observe the vault leave the foreground before checking background auto-lock")
        print("BACKGROUND_PRECONDITION \(name) state=\(app.state.rawValue)")
        app.activate()
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 8), app.debugDescription)
        sleep(3)
        XCTAssertFalse(app.otherElements["ActivityListView"].exists)
        XCTAssertFalse(app.buttons["vault.preview.share"].exists)
        XCTAssertFalse(app.buttons["More"].exists)
        capture(app, name + "-switcher-return-locked")
    }

    @MainActor func testPDFNestedShareSwitcherProtection() {
        let app = login(); category("Files", 2, app)
        app.staticTexts["Fictional-Privacy"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "FICTIONAL PDF")).firstMatch.waitForExistence(timeout: 8))
        let pixels = fictionalTealPixels(app.screenshot())
        print("SENSITIVE_VISIBLE_PIXELS pdf \(pixels)"); XCTAssertGreaterThan(pixels, 10000)
        let share = app.buttons.matching(identifier: "vault.preview.share").allElementsBoundByIndex.first(where: { $0.isHittable })!
        share.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        verifySwitcherFromNestedShare(app, name: "pdf")
    }

    @MainActor func testVideoNestedShareSwitcherProtection() {
        let app = login(); category("Media", 1, app)
        app.segmentedControls.buttons["Videos"].tap()
        app.buttons.matching(NSPredicate(format: "value CONTAINS %@", "Fictional-Motion")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["00:03"].waitForExistence(timeout: 15))
        let pixels = fictionalTealPixels(app.screenshot())
        print("SENSITIVE_VISIBLE_PIXELS video \(pixels)"); XCTAssertGreaterThan(pixels, 10000)
        app.buttons["More"].tap(); app.buttons["Share Video"].tap()
        verifySwitcherFromNestedShare(app, name: "video")
    }

}
