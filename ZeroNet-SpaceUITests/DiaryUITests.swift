import XCTest
import UIKit
import StoreKitTest

final class DiaryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"]?.hasPrefix("SealedPocket-Demo-") == true,
                          "Only use the existing synthetic SealedPocket demo simulators")
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot()); screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = name + "-tree"; tree.lifetime = .keepAlways; add(tree)
    }
    @MainActor private func backgroundAndReactivate(_ app: XCUIApplication) {
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"]?.contains("Duo") == true {
            // Hardware Home targets the primary display; swipe the active window's home indicator instead.
            let window = app.windows.firstMatch, frame = window.frame
            let start = window.coordinate(withNormalizedOffset: CGVector(dx:0.5,dy:1)).withOffset(CGVector(dx:0,dy:-3))
            let end = window.coordinate(withNormalizedOffset: CGVector(dx:0.5,dy:0.35))
            print("DIARY_ACTIVE_WINDOW_HOME frame=\(frame)")
            start.press(forDuration:0.05,thenDragTo:end,withVelocity:.fast,thenHoldForDuration:0)
        } else { XCUIDevice.shared.press(.home) }
        let background = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            app.state == .runningBackground || app.state == .runningBackgroundSuspended
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[background],timeout:8),.completed,"The active diary window must actually background before testing automatic lock")
        app.activate()
    }
    @MainActor private func login(_ app: XCUIApplication, password: String = "Pocket7391") {
        let field = app.secureTextFields["Enter password"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap(); field.typeText(password)
        if app.secureTextFields["Re-enter password"].exists {
            app.secureTextFields["Re-enter password"].tap(); app.secureTextFields["Re-enter password"].typeText("Pocket7391")
            app.buttons["Finish Setup"].tap()
        } else { app.buttons["Unlock"].tap() }
        XCTAssertTrue(app.buttons["Photos"].firstMatch.waitForExistence(timeout: 10), app.debugDescription)
    }
    @MainActor private func launch(largeType: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-hasUnlockedUnlimited", "NO"];
        if largeType { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch(); login(app); notes(app)
        return app
    }
    @MainActor private func back(_ app: XCUIApplication) {
        let button = app.buttons["BackButton"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), app.debugDescription); button.tap()
    }
    @MainActor private func notes(_ app: XCUIApplication) {
        let sidebar = app.buttons["vault.category.3"]
        if sidebar.exists && sidebar.isHittable { sidebar.tap() } else { app.buttons["Notes"].firstMatch.tap() }
        XCTAssertTrue(app.buttons["diary.new"].waitForExistence(timeout: 5))
    }
    @discardableResult @MainActor private func newEntry(_ app: XCUIApplication, title: String) -> String {
        app.buttons["diary.new"].tap()
        let field = app.descendants(matching: .any)["diary.title"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription); field.tap(); field.typeText(title)
        let actual = field.value as? String ?? title
        let body = app.textViews["diary.body"]
        body.swipeUp()
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.9)).tap()
        return actual
    }
    @MainActor private func tapFirstPhoto(_ body: XCUIElement) {
        body.swipeDown(); body.swipeDown()
        let photo = body.staticTexts.allElementsBoundByIndex.first { $0.label.isEmpty && $0.frame.height > 40 }
        if let photo {
            photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        } else {
            // Editable UITextView exposes the document as one accessibility node.
            // Return to its opening paragraph and tap the actual first image region.
            body.swipeDown(); body.swipeDown()
            let title = body.descendants(matching: .any)["diary.title"].firstMatch
            let y = min(body.frame.height - 30, max(30, title.frame.maxY - body.frame.minY + 100))
            body.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: body.frame.width / 2, dy: y)).tap()
        }
    }
    @MainActor func testTextSaveReopenCancelPickerRotationAndLock() {
        let app = launch()
        var name = "Fictional diary " + String(Int(Date().timeIntervalSince1970))
        name = newEntry(app, title: name)
        let body = app.textViews["diary.body"]
        body.typeText("A quiet walk beside an imaginary lake.\n\nThe afternoon felt unhurried.\n")
        XCTAssertTrue(app.staticTexts["Saved on this device"].waitForExistence(timeout: 8))
        capture(app, "diary-phone-editing")
        app.buttons["diary.addPhotos"].tap()
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 5)); app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5)); XCTAssertTrue((body.value as? String ?? "").contains("imaginary lake"))
        body.typeText("Text after cancelling photos.")
        XCTAssertTrue((body.value as? String ?? "").hasSuffix("Text after cancelling photos."))
        app.buttons["diary.editDone"].tap()
        XCTAssertEqual(app.keyboards.count, 0)
        capture(app, "diary-reading-no-keyboard")
        back(app)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), app.debugDescription); app.staticTexts[name].tap()
        XCTAssertTrue(app.buttons["diary.editDone"].waitForExistence(timeout: 5)); XCTAssertEqual(app.buttons["diary.editDone"].label, "Edit")
        XCTAssertEqual(app.keyboards.count, 0)
        XCTAssertTrue((body.value as? String ?? "").contains("imaginary lake"))
        app.buttons["diary.editDone"].tap(); body.tap(); body.typeText(" Draft before rotation.")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        XCTAssertTrue((body.value as? String ?? "").contains("Draft before rotation"))
        XCTAssertTrue(app.buttons["diary.editDone"].isHittable)
        capture(app, "diary-rotated-keyboard")
        XCUIDevice.shared.orientation = .portrait
        body.typeText(" Latest before background.")
        backgroundAndReactivate(app)
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertFalse(body.exists); capture(app, "diary-return-locked")
        login(app); notes(app); app.staticTexts[name].tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5)); XCTAssertTrue((body.value as? String ?? "").contains("Latest before background"))
        capture(app, "diary-reopened-after-lock")
    }
    @MainActor func testImportPhotosInOrderAndReadBack() {
        let app = launch()
        var name = "Fictional photo diary " + String(Int(Date().timeIntervalSince1970))
        name = newEntry(app, title: name)
        app.textViews["diary.body"].typeText("A small collection of fictional places.\n")
        app.buttons["diary.addPhotos"].tap()
        let fixtures = app.images.matching(NSPredicate(format: "identifier == %@", "PXGGridLayout-Info"))
        XCTAssertTrue(fixtures.firstMatch.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertGreaterThanOrEqual(fixtures.count, 2)
        fixtures.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        fixtures.element(boundBy: 0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        capture(app, "diary-ordered-photo-selection")
        let add = app.navigationBars.buttons["Add"].firstMatch, done = app.navigationBars.buttons["Done"].firstMatch
        if add.exists { add.tap() } else { done.tap() }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.buttons["diary.editDone"].isEnabled }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed)
        XCTAssertTrue(app.staticTexts["Saved on this device"].waitForExistence(timeout: 15), app.debugDescription)
        app.buttons["diary.editDone"].tap()
        XCTAssertEqual(app.keyboards.count, 0)
        capture(app, "diary-photos-reading")
        back(app); XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5)); app.staticTexts[name].tap()
        XCTAssertTrue(app.textViews["diary.body"].waitForExistence(timeout: 5)); capture(app, "diary-photos-reopened")
    }
    @MainActor func testLargeTypeKeyboardAndReading() {
        let app = launch(largeType: true)
        newEntry(app, title: "Fictional large type diary")
        let body = app.textViews["diary.body"]
        body.typeText("Larger letters for a quiet fictional afternoon.\nSecond paragraph.")
        XCTAssertGreaterThanOrEqual(body.frame.height, 44)
        XCTAssertTrue(app.buttons["diary.editDone"].isHittable)
        capture(app, "diary-large-type-keyboard")
        app.buttons["diary.editDone"].tap(); XCTAssertEqual(app.keyboards.count, 0)
        capture(app, "diary-large-type-reading")
    }
    @MainActor func testPhotoActionsFullViewAndWriteBetween() {
        let app = launch()
        newEntry(app, title: "Fictional photo actions " + String(Int(Date().timeIntervalSince1970)))
        app.textViews["diary.body"].typeText("An opening paragraph for these fictional photos.\n")
        importTwoPhotos(app)
        app.buttons["diary.editDone"].tap()
        let body = app.textViews["diary.body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        tapFirstPhoto(body)
        XCTAssertTrue(app.buttons["diary.photoDone"].waitForExistence(timeout: 5), app.debugDescription)
        capture(app, "diary-full-photo")
        app.buttons["diary.photoDone"].tap()
        app.buttons["diary.editDone"].tap()
        tapFirstPhoto(body)
        XCTAssertTrue(app.buttons["Write below"].waitForExistence(timeout: 5), app.debugDescription)
        capture(app, "diary-image-actions")
        app.buttons["Write below"].tap(); body.typeText("Fictional text between these photos.\n")
        XCTAssertTrue((body.value as? String ?? "").contains("Fictional text between these photos"))
        app.buttons["diary.editDone"].tap()
        capture(app, "diary-text-between-photos")
    }
    @MainActor func testDuoFoldKeepsMixedEntry() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"]?.contains("Duo") == true)
        XCUIDevice.shared.orientation = .portrait
        let app = launch()
        newEntry(app, title: "Fictional rich folding diary\nA second title line")
        let body = app.textViews["diary.body"]
        app.buttons["diary.format"].tap()
        paragraph("heading", in: app); body.typeText("A folding afternoon 🌿\n")
        app.buttons["diary.format.bold"].tap(); app.buttons["diary.format.italic"].tap()
        body.typeText("中英 mixed styles.")
        app.buttons["diary.format.bold"].tap(); app.buttons["diary.format.italic"].tap()
        body.typeText("\n"); paragraph("bullet", in: app); body.typeText("A fictional list\n\n")
        app.buttons["diary.format"].tap(); importTwoPhotos(app)
        body.typeText(" Folding keeps this fictional draft.")
        let expected = body.value as? String
        print("DIARY_FOLD_READY")
        var widths = Set<Int>()
        var compact = false, expanded = false
        for i in 0..<60 {
            if i == 20 { XCUIDevice.shared.orientation = .landscapeLeft }
            if i == 40 { XCUIDevice.shared.orientation = .portrait }
            widths.insert(Int(app.frame.width))
            compact = compact || (app.frame.width < 640 && app.frame.height < 900)
            expanded = expanded || app.frame.width >= 640
            XCTAssertEqual(body.value as? String, expected)
            XCTAssertGreaterThanOrEqual(body.frame.height, 44)
            let done = app.buttons["diary.editDone"]
            let reachable = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in done.isHittable }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [reachable], timeout: 5), .completed)
            if i % 10 == 0 { capture(app, "diary-fold-\(i)"); print("DIARY_FOLD_FRAME \(app.frame)") }
            sleep(1)
        }
        XCTAssertGreaterThan(widths.count, 1, "Operate Device Hub Open/Closed during this test")
        XCTAssertTrue(compact && expanded, "Observe the real compact outer display and expanded inner display, not rotation alone")
        app.buttons["diary.editDone"].tap()
        XCTAssertEqual((body.value as? String ?? "").filter { $0 == "\u{fffc}" }.count, 2)
        capture(app, "rich-duo-fold-reading")
    }

    @MainActor func testRestartRecoveryAndGuestIsolation() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch(); login(app, password: "830196")
        let sidebar = app.buttons["vault.category.3"]
        if sidebar.exists && sidebar.isHittable { sidebar.tap() } else { app.buttons["Notes"].firstMatch.tap() }
        XCTAssertFalse(app.buttons["diary.new"].exists)
        XCTAssertFalse(app.staticTexts["Fictional restart recovery"].exists)
        XCTAssertFalse(app.textViews["diary.body"].exists)
        capture(app, "diary-guest-no-owner-drafts")
        app.terminate(); app.launch(); login(app); notes(app)
        XCTAssertTrue(app.staticTexts["Fictional restart recovery"].firstMatch.waitForExistence(timeout: 8), app.debugDescription)
        app.terminate(); app.launch(); login(app); notes(app)
        app.staticTexts["Fictional restart recovery"].firstMatch.tap()
        let body = app.textViews["diary.body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        XCTAssertTrue((body.value as? String ?? "").contains("Owner-only fictional recovery"))
        XCTAssertTrue((body.value as? String ?? "").contains("after the photo also survived restart"))
        capture(app, "diary-recovery-after-process-restart")
        app.buttons["diary.editDone"].tap(); back(app)
        XCTAssertTrue(app.staticTexts["Fictional restart recovery"].firstMatch.waitForExistence(timeout: 5))
        app.terminate(); app.launch(); login(app); notes(app)
        app.staticTexts["Fictional restart recovery"].firstMatch.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["diary.editDone"].label, "Edit")
        XCTAssertEqual(app.keyboards.count, 0)
        capture(app, "diary-recovered-and-committed-reopened")
    }

    @MainActor func testRemoveUndoAndExplicitMove() {
        let app = launch()
        newEntry(app, title: "Fictional photo actions " + String(Int(Date().timeIntervalSince1970)))
        app.textViews["diary.body"].typeText("An opening paragraph for these fictional photos.\n")
        importTwoPhotos(app)
        app.buttons["diary.editDone"].tap()
        let body = app.textViews["diary.body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        let before = body.value as? String ?? ""
        XCTAssertEqual(before.filter { $0 == "\u{fffc}" }.count, 2)
        app.buttons["diary.editDone"].tap()
        tapFirstPhoto(body)
        XCTAssertTrue(app.buttons["Remove from entry"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Remove from entry"].tap()
        XCTAssertEqual((body.value as? String ?? "").filter { $0 == "\u{fffc}" }.count, 1)
        app.buttons["diary.undo"].tap()
        XCTAssertEqual((body.value as? String ?? "").filter { $0 == "\u{fffc}" }.count, 2)
        capture(app, "diary-photo-removal-undone")
        tapFirstPhoto(body)
        XCTAssertTrue(app.buttons["Move photo…"].waitForExistence(timeout: 5)); app.buttons["Move photo…"].tap()
        let destination = before.distance(from: before.startIndex, to: before.firstIndex(of: "\u{fffc}")!)
        // Choose a caret in the opening paragraph, then commit the explicit move.
        body.swipeDown(); body.swipeDown()
        let title = app.descendants(matching: .any)["diary.title"].firstMatch
        let targetY = min(body.frame.height - 30, max(25, title.frame.maxY - body.frame.minY + 35))
        body.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: targetY)).tap()
        XCTAssertTrue(app.buttons["diary.moveHere"].isHittable); app.buttons["diary.moveHere"].tap()
        let moved = body.value as? String ?? ""
        XCTAssertEqual(moved.filter { $0 == "\u{fffc}" }.count, 2)
        XCTAssertNotEqual(moved, before)
        XCTAssertGreaterThan(destination, 0)
        app.buttons["diary.editDone"].tap(); capture(app, "diary-explicit-photo-move")
        app.buttons["diary.editDone"].tap(); app.buttons["diary.undo"].tap()
        XCTAssertEqual((body.value as? String ?? "").filter { $0 == "\u{fffc}" }.count, 2)
        app.buttons["diary.editDone"].tap()
    }

    @MainActor func testWritingFlowRecording() {
        let app = launch()
        newEntry(app, title: "An imaginary lakeside afternoon\n湖边的虚构午后")
        let body = app.textViews["diary.body"]
        print("DIARY_RECORD_READY")
        sleep(3) // Allows the external simulator recorder to attach after authentication.
        app.buttons["diary.format"].tap()
        paragraph("heading", in: app); body.typeText("A quiet walk 🌿\n")
        app.buttons["diary.format.bold"].tap(); app.buttons["diary.format.italic"].tap()
        body.typeText("An imaginary lake. 虚构的湖。")
        app.buttons["diary.format.bold"].tap(); app.buttons["diary.format.italic"].tap()
        body.typeText("\n"); paragraph("bullet", in: app); body.typeText("Slow steps\nSoft light\n\n")
        app.buttons["diary.format"].tap()
        app.buttons["diary.addPhotos"].tap()
        let fixtures = app.images.matching(NSPredicate(format: "identifier == %@", "PXGGridLayout-Info"))
        XCTAssertTrue(fixtures.firstMatch.waitForExistence(timeout: 25), app.debugDescription)
        fixtures.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        fixtures.element(boundBy: 0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let add = app.navigationBars.buttons["Add"].firstMatch, done = app.navigationBars.buttons["Done"].firstMatch
        if add.exists { add.tap() } else { done.tap() }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.buttons["diary.editDone"].isEnabled }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed)
        app.buttons["diary.editDone"].tap()
        body.swipeDown(); body.swipeDown()
        let visiblePhoto = body.staticTexts.allElementsBoundByIndex.first { $0.label.isEmpty && $0.frame.height > 40 }
        guard let visiblePhoto else { XCTFail("Expected the actual first photo accessibility frame"); return }
        let photoPoint = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: visiblePhoto.frame.midX, dy: visiblePhoto.frame.minY + 24))
        app.buttons["diary.editDone"].tap(); photoPoint.tap()
        XCTAssertTrue(app.buttons["Write below"].waitForExistence(timeout: 5)); app.buttons["Write below"].tap()
        body.typeText("The afternoon felt unhurried.\n")
        app.buttons["diary.editDone"].tap()
        XCTAssertEqual(app.keyboards.count, 0)
        body.swipeDown(); body.swipeDown()
        capture(app, "diary-writing-flow-reading")
        print("DIARY_RECORD_DONE"); sleep(8)
    }

    @MainActor private func importTwoPhotos(_ app: XCUIApplication) {
        app.buttons["diary.addPhotos"].tap()
        let fixtures = app.images.matching(NSPredicate(format: "identifier == %@", "PXGGridLayout-Info"))
        XCTAssertTrue(fixtures.firstMatch.waitForExistence(timeout: 25), app.debugDescription)
        fixtures.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        fixtures.element(boundBy: 0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let add = app.navigationBars.buttons["Add"].firstMatch
        if add.exists { add.tap() } else { app.navigationBars.buttons["Done"].firstMatch.tap() }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.buttons["diary.editDone"].isEnabled }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed)
    }
    @MainActor private func paragraph(_ kind: String, in app: XCUIApplication) {
        let button = app.buttons["diary.paragraph." + kind]
        if !button.isHittable {
            app.scrollViews.containing(.button, identifier: "diary.paragraph.body").firstMatch.swipeLeft()
        }
        XCTAssertTrue(button.isHittable, app.debugDescription); button.tap()
    }
    @MainActor func testRichFormattingListsEdgeBackAndFreePDF() {
        richFormattingListsAndFreePDF(useEdge: true)
    }
    @MainActor func testRichFormattingListsSystemBackAndFreePDF() {
        richFormattingListsAndFreePDF(useEdge: false)
    }
    @MainActor private func richFormattingListsAndFreePDF(useEdge: Bool) {
        let app = launch()
        let name = "Fictional rich diary " + String(Int(Date().timeIntervalSince1970))
        newEntry(app, title: name + "\nA second title line")
        let body = app.textViews["diary.body"]
        app.buttons["diary.format"].tap()
        paragraph("heading", in: app); body.typeText("Spring walk 🌿\n")
        capture(app, "rich-after-heading-return")
        XCTAssertTrue(app.buttons["diary.paragraph.body"].isSelected)
        XCTAssertEqual(app.buttons["diary.format.bold"].value as? String, "Off")
        app.buttons["diary.format.bold"].tap(); app.buttons["diary.format.italic"].tap()
        XCTAssertEqual(app.buttons["diary.format.bold"].value as? String, "On")
        XCTAssertEqual(app.buttons["diary.format.italic"].value as? String, "On")
        body.typeText("Combined styles 中文😀")
        capture(app, "rich-aa-selected-typing")
        app.buttons["diary.format.bold"].tap(); app.buttons["diary.format.italic"].tap()
        body.typeText("\n")
        paragraph("bullet", in: app); body.typeText("Apple\nCloud\n\n")
        XCTAssertTrue(app.buttons["diary.paragraph.body"].isSelected)
        paragraph("numbered", in: app); body.typeText("First step\nSecond step\n\n")
        paragraph("quote", in: app); body.typeText("A fictional quotation.\n\n")
        app.buttons["diary.format"].tap()
        importTwoPhotos(app)
        body.typeText("Undo this sentence.")
        app.buttons["diary.undo"].tap(); app.buttons["diary.redo"].tap()
        XCTAssertTrue((body.value as? String ?? "").contains("Undo this sentence."))
        app.buttons["diary.hideKeyboard"].tap()
        body.swipeDown(); body.swipeDown()
        capture(app, "rich-title-and-reading-hierarchy")
        let before = body.value as? String
        if useEdge {
            let origin = body.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: -body.frame.minX, dy: -body.frame.minY))
            let gestureY = body.frame.minY + min(150, body.frame.height * 0.5)
            // The text container has horizontal padding; UIKit's edge belongs to its navigation pane.
            let navigationFrame = app.navigationBars.firstMatch.frame
            let start = origin.withOffset(CGVector(dx: navigationFrame.minX + 18, dy: gestureY))
            let short = origin.withOffset(CGVector(dx: navigationFrame.minX + navigationFrame.width * 0.12, dy: gestureY))
            start.press(forDuration: 0.1, thenDragTo: short, withVelocity: .slow, thenHoldForDuration: 0.5)
            XCTAssertTrue(body.waitForExistence(timeout: 5)); XCTAssertEqual(body.value as? String, before)
            capture(app, "rich-edge-cancelled")
            let end = origin.withOffset(CGVector(dx: body.frame.maxX - 20, dy: gestureY))
            start.press(forDuration: 0.05, thenDragTo: end)
        } else {
            back(app)
        }
        XCTAssertTrue(app.buttons["diary.new"].waitForExistence(timeout: 5), app.debugDescription)
        let entry = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        for _ in 0..<10 {
            if entry.exists && entry.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5)); XCTAssertEqual(body.value as? String, before)
        XCTAssertEqual(app.buttons["diary.editDone"].label, "Edit")
        app.buttons["diary.exportPDF"].tap()
        XCTAssertTrue(app.buttons["diary.pdf.restore"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.buttons["diary.pdf.progress"].exists)
        capture(app, "rich-free-pdf-membership-gate")
        app.buttons["diary.pdf.vipDone"].tap()
        app.terminate(); app.launch(); login(app); notes(app)
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5)); XCTAssertEqual(body.value as? String, before)
        app.buttons["diary.editDone"].tap(); body.tap(); body.typeText(" Survives lock.")
        backgroundAndReactivate(app)
        XCTAssertTrue(app.secureTextFields["Enter password"].waitForExistence(timeout: 8))
        XCTAssertFalse(body.exists)
        login(app); notes(app)
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5)); XCTAssertTrue((body.value as? String ?? "").contains("Survives lock"))
        capture(app, "rich-reopened-after-restart-lock")
    }
    @MainActor func testNativeEdgeBackInNavigationPane() {
        let app = launch()
        newEntry(app, title: "Fictional native edge verification")
        let body = app.textViews["diary.body"]
        body.typeText("A fictional draft survives a cancelled native transition.")
        app.buttons["diary.hideKeyboard"].tap()
        let before = body.value as? String
        let frame = app.navigationBars.firstMatch.frame
        let origin = body.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: -body.frame.minX, dy: -body.frame.minY))
        let y = body.frame.minY + 180
        // Horizontal movement in the content area must remain available to text selection.
        origin.withOffset(CGVector(dx: frame.midX, dy: y)).press(forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: frame.maxX - 20, dy: y)))
        XCTAssertTrue(body.exists); XCTAssertEqual(body.value as? String, before)
        let start = origin.withOffset(CGVector(dx: frame.minX + 18, dy: y))
        start.press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: frame.minX + frame.width * 0.12, dy: y)), withVelocity: .slow, thenHoldForDuration: 0.5)
        XCTAssertTrue(body.exists); XCTAssertEqual(body.value as? String, before)
        capture(app, "native-edge-pane-cancelled")
        start.press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: frame.maxX - 20, dy: y)))
        XCTAssertTrue(app.buttons["diary.new"].waitForExistence(timeout: 5), app.debugDescription)
        app.staticTexts["Fictional native edge verification"].firstMatch.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5)); XCTAssertEqual(body.value as? String, before)
        app.buttons["diary.editDone"].tap()
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.9)).tap(); body.typeText(" Button save.")
        back(app)
        XCTAssertTrue(app.buttons["diary.new"].waitForExistence(timeout: 5))
        app.staticTexts["Fictional native edge verification"].firstMatch.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5)); XCTAssertTrue((body.value as? String ?? "").contains("Button save."))
    }
    @MainActor func testStandardSettingsNavigationEdgeControl() {
        let app = launch()
        app.buttons["vault.category.4"].tap()
        app.buttons["settings.appIcon"].tap()
        XCTAssertTrue(app.buttons["appicon.primary"].waitForExistence(timeout: 5))
        capture(app, "native-settings-control-before-edge")
        let frame = app.navigationBars.firstMatch.frame
        let control = app.buttons["appicon.primary"]
        let origin = control.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: -control.frame.minX, dy: -control.frame.minY))
        let y = frame.maxY + 180
        origin.withOffset(CGVector(dx: frame.minX + 18, dy: y)).press(forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: frame.maxX - 20, dy: y)))
        capture(app, "native-settings-control-after-edge")
        XCTAssertTrue(app.buttons["settings.appIcon"].waitForExistence(timeout: 5), app.debugDescription)
    }
    @MainActor func testDuoExpandedButtonAndCategoryPersistence() {
        let app = launch()
        let name = "Fictional Duo navigation " + String(Int(Date().timeIntervalSince1970))
        newEntry(app, title: name)
        let body = app.textViews["diary.body"]
        body.typeText("Saved before system Back. 中文🌿")
        importTwoPhotos(app)
        body.typeText(" Category draft.")
        app.buttons["diary.hideKeyboard"].tap()
        let before = body.value as? String
        back(app)
        XCTAssertTrue(app.buttons["diary.new"].waitForExistence(timeout: 5))
        let entry = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        entry.tap(); XCTAssertTrue(body.waitForExistence(timeout: 5)); XCTAssertEqual(body.value as? String, before)
        app.buttons["diary.editDone"].tap()
        body.coordinate(withNormalizedOffset: CGVector(dx:0.8,dy:0.9)).tap(); body.typeText(" Retained across categories.")
        app.buttons["diary.hideKeyboard"].tap()
        let draft = body.value as? String
        app.buttons["vault.category.4"].tap(); XCTAssertTrue(app.buttons["settings.appIcon"].waitForExistence(timeout:5))
        app.buttons["vault.category.3"].tap(); XCTAssertTrue(body.waitForExistence(timeout:5)); XCTAssertEqual(body.value as? String,draft)
        XCTAssertTrue(app.buttons["diary.undo"].isEnabled)
        app.buttons["diary.undo"].tap(); app.buttons["diary.redo"].tap(); XCTAssertEqual(body.value as? String,draft)
        app.terminate(); app.launch(); login(app); notes(app); entry.tap()
        XCTAssertTrue(body.waitForExistence(timeout:5)); XCTAssertEqual(body.value as? String,draft)
        XCTAssertEqual((body.value as? String ?? "").filter { $0 == "\u{fffc}" }.count,2)
        capture(app,"duo-expanded-system-back-category-and-restart")
    }
    @MainActor func testSelectedWordKeepsStackedFormattingAndMixedState() {
        let app = launch()
        newEntry(app, title: "Fictional selected text")
        let body = app.textViews["diary.body"]
        body.typeText("Alpha beta gamma")
        body.swipeDown(); body.swipeDown()
        let title = app.textFields["diary.title"]
        let point = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: body.frame.minX + 35, dy: title.frame.maxY + 28))
        point.doubleTap()
        XCTAssertTrue(app.menuItems["Copy"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["diary.format"].tap()
        app.buttons["diary.format.bold"].tap(); app.buttons["diary.format.italic"].tap()
        XCTAssertEqual(app.buttons["diary.format.bold"].value as? String, "On")
        XCTAssertEqual(app.buttons["diary.format.italic"].value as? String, "On")
        XCTAssertEqual(body.value as? String, "Alpha beta gamma")
        capture(app, "rich-selected-word-stacked-styles")
        let trailing = body.otherElements["com.apple.text.grabber.trailing"].firstMatch
        XCTAssertTrue(trailing.waitForExistence(timeout: 5), app.debugDescription)
        let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: body.frame.minX + 260, dy: title.frame.maxY + 28))
        trailing.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.0)).press(forDuration: 0.1, thenDragTo: end)
        XCTAssertEqual(app.buttons["diary.format.bold"].value as? String, "Mixed")
        XCTAssertEqual(app.buttons["diary.format.italic"].value as? String, "Mixed")
        capture(app, "rich-mixed-native-selection")
        app.buttons["diary.format.underline"].tap()
        app.buttons["diary.undo"].tap(); app.buttons["diary.redo"].tap()
        XCTAssertEqual(body.value as? String, "Alpha beta gamma")
        app.buttons["diary.editDone"].tap()
    }
    @MainActor func testSystemBackLongPressBehavior() {
        let app = launch()
        newEntry(app, title: "Fictional system back long press")
        app.textViews["diary.body"].typeText("Fictional text saved before inspecting the native Back control.")
        app.buttons["diary.hideKeyboard"].tap()
        let back = app.navigationBars.buttons["BackButton"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5)); back.press(forDuration: 1.2)
        capture(app, "native-system-back-long-press")
        print("DIARY_BACK_LONG_PRESS_TREE " + app.debugDescription)
        XCTAssertTrue(app.buttons["diary.new"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["diary.body"].exists)
    }
    @MainActor func testRealInstalledPinyinCompositionAndReopen() {
        let app = XCUIApplication()
        // Use the synthetic device's real Chinese system language and installed keyboards.
        // Forcing AppleLanguages=(en) intentionally limits the test keyboard menu to English.
        app.launch()
        let password = app.secureTextFields.firstMatch
        XCTAssertTrue(password.waitForExistence(timeout: 10)); password.tap(); password.typeText("Pocket7391")
        let unlock = app.buttons["解锁"].exists ? app.buttons["解锁"] : app.buttons["Unlock"]
        unlock.tap()
        XCTAssertTrue(app.buttons["vault.category.3"].waitForExistence(timeout: 8)); app.buttons["vault.category.3"].tap()
        let name = "Fictional Pinyin " + String(Int(Date().timeIntervalSince1970))
        newEntry(app, title: name)
        let body = app.textViews["diary.body"]
        app.buttons["diary.format"].tap(); app.buttons["diary.format.bold"].tap()
        let globe = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label IN %@", "emoji", ["Next keyboard", "Emoji", "下一键盘", "下一个键盘", "表情符号"])).firstMatch
        XCTAssertTrue(globe.waitForExistence(timeout: 5), app.debugDescription); globe.press(forDuration: 1.2)
        capture(app, "pinyin-real-language-menu")
        let pinyin = app.cells.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS[c] %@", "拼音", "Pinyin")).firstMatch
        XCTAssertTrue(pinyin.waitForExistence(timeout: 5), app.debugDescription); pinyin.tap()
        for letter in "zhongwen" {
            let key = app.keyboards.keys.matching(NSPredicate(format: "label ==[c] %@", String(letter))).firstMatch
            XCTAssertTrue(key.exists, app.debugDescription); key.tap()
        }
        let marked = body.value as? String
        capture(app, "pinyin-real-marked-composition")
        app.buttons["diary.format.italic"].tap()
        XCTAssertEqual(body.value as? String, marked)
        let candidate = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "中文")).firstMatch
        XCTAssertTrue(candidate.waitForExistence(timeout: 5), app.debugDescription); candidate.tap()
        XCTAssertTrue((body.value as? String ?? "").contains("中文"))
        XCTAssertTrue(app.buttons["diary.format.bold"].isSelected)
        XCTAssertFalse(app.buttons["diary.format.italic"].isSelected)
        capture(app, "pinyin-real-committed-bold")
        app.buttons["diary.editDone"].tap(); back(app)
        app.staticTexts[name].firstMatch.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5)); XCTAssertTrue((body.value as? String ?? "").contains("中文"))
        XCTAssertEqual(app.keyboards.count, 0)
        capture(app, "pinyin-real-saved-reopened")
    }
    @MainActor func testRichMaximumTypeFormattingAndTitleScroll() {
        let app = launch(largeType: true)
        newEntry(app, title: "Two lines of a fictional title\nA quiet afternoon")
        let body = app.textViews["diary.body"]
        body.typeText("Large text remains editable.\nSecond paragraph.")
        app.buttons["diary.format"].tap()
        XCTAssertTrue(app.buttons["diary.format.bold"].isHittable)
        XCTAssertLessThanOrEqual(app.buttons["diary.addPhotos"].frame.maxX, app.buttons["diary.format"].frame.minX)
        app.buttons["diary.format.bold"].tap(); body.typeText(" Bold typing.")
        capture(app, "rich-maximum-type-aa")
        app.buttons["diary.format"].tap(); app.buttons["diary.hideKeyboard"].tap()
        body.swipeDown(); body.swipeDown()
        capture(app, "rich-maximum-type-title")
        XCTAssertTrue(app.buttons["diary.editDone"].isHittable)
        XCTAssertTrue((body.value as? String ?? "").contains("Large text remains editable."))
        app.buttons["diary.editDone"].tap(); XCTAssertEqual(app.keyboards.count, 0)
    }

    @MainActor func testRichStoreKitMemberPDFShareAndRevocation() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Local StoreKit async test requires iOS17") }
        let config = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "DiaryProducts", withExtension: "storekit"))
        let store = try SKTestSession(contentsOf: config)
        store.disableDialogs = true
        XCTAssertTrue(store.disableDialogs, "Abort before purchase: local StoreKit configuration did not persist")
        guard store.disableDialogs else { return }
        store.clearTransactions()
        defer { store.clearTransactions() }
        let app = launch()
        newEntry(app, title: "Fictional member PDF\nA local StoreKit test")
        let body = app.textViews["diary.body"]
        body.typeText("中文与 English 😀. A fictional PDF for local testing.\n")
        app.buttons["diary.addPhotos"].tap()
        let fixtures = app.images.matching(NSPredicate(format: "identifier == %@", "PXGGridLayout-Info"))
        XCTAssertTrue(fixtures.firstMatch.waitForExistence(timeout: 25), app.debugDescription)
        fixtures.element(boundBy: 0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        fixtures.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let add = app.navigationBars.buttons["Add"].firstMatch
        if add.exists { add.tap() } else { app.navigationBars.buttons["Done"].firstMatch.tap() }
        let imported = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.buttons["diary.editDone"].isEnabled }, object: nil)
        await fulfillment(of: [imported], timeout: 20)
        app.buttons["diary.editDone"].tap(); app.buttons["diary.exportPDF"].tap()
        XCTAssertTrue(app.buttons["diary.pdf.restore"].waitForExistence(timeout: 10))
        // SKTestSession uses only the bundled local StoreKit configuration; no Apple charge.
        XCTAssertTrue(app.buttons["diary.pdf.purchase"].isEnabled)
        app.buttons["diary.pdf.purchase"].tap()
        let member = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !app.buttons["diary.pdf.vipDone"].exists && app.buttons["diary.editDone"].exists && !app.secureTextFields["Enter password"].exists }, object: nil)
        await fulfillment(of: [member], timeout: 15)
        let transaction = try XCTUnwrap(store.allTransactions().first)
        app.buttons["diary.exportPDF"].tap()
        XCTAssertTrue(app.cells["Copy"].waitForExistence(timeout: 15) || app.buttons["Copy"].exists, app.debugDescription)
        capture(app, "rich-local-storekit-member-pdf-share")
        let close = app.buttons["header.closeButton"].firstMatch
        if close.exists { close.tap() } else { app.swipeDown() }
        try store.refundTransaction(identifier: transaction.identifier)
        // Observe the existing entitlement revocation path before trying another export.
        try await Task.sleep(nanoseconds: 1_000_000_000)
        app.buttons["diary.exportPDF"].tap()
        XCTAssertTrue(app.buttons["diary.pdf.restore"].waitForExistence(timeout: 12), app.debugDescription)
        capture(app, "rich-local-storekit-refunded-free-gate")
        app.buttons["diary.pdf.vipDone"].tap()
    }



}
