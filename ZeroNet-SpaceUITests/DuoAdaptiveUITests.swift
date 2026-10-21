import XCTest

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

}
