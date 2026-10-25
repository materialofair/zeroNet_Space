import XCTest
import SwiftData
import UIKit
@testable import ZeroNet_Space

@MainActor final class DiaryTests: XCTestCase {
    private var storage: DiaryStorage!
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("DiaryTests-" + UUID().uuidString)
        storage = DiaryStorage(directory: root)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }
    private func sample() -> DiaryDocument {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 100)).image { ctx in
            UIColor.systemTeal.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 100))
        }
        return .init(id: UUID(), title: "Fictional private diary", runs: [
            .init(text: "Before 🌿\n", bold: true),
            .init(photo: .init(jpeg: image.jpegData(compressionQuality: 0.8)!, width: 50, height: 100)),
            .init(text: "\nBetween photos\n"),
            .init(photo: .init(jpeg: image.jpegData(compressionQuality: 0.8)!, width: 50, height: 100)),
            .init(text: "\nAfter\n")], updatedAt: Date())
    }
    private func container() throws -> ModelContainer {
        try ModelContainer(for: SecretNote.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    func testEncryptedDocumentRoundTripAndAuthentication() throws {
        let document = sample(), password = "Fictional-7391"
        let cipher = try storage.encrypt(document, password: password)
        XCTAssertEqual(try storage.decrypt(cipher, password: password), document)
        for secret in [document.title, "Between photos", "Before"] {
            XCTAssertNil(cipher.range(of: Data(secret.utf8)))
        }
        XCTAssertThrowsError(try storage.decrypt(cipher, password: "Wrong-7391"))
        var tampered = cipher; tampered[tampered.count - 1] ^= 1
        XCTAssertThrowsError(try storage.decrypt(tampered, password: password))
    }
    func testRecoverySurvivesFailedCommitAndRestart() throws {
        let document = sample(), password = "Fictional-7391", container = try container()
        let cipher = try storage.encrypt(document, password: password)
        XCTAssertThrowsError(try storage.commit(document, encrypted: cipher, container: container, save: { _ in throw CocoaError(.fileWriteOutOfSpace) }))
        let restarted = DiaryStorage(directory: root)
        XCTAssertEqual(try restarted.recoveries(password: password), [document])
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<SecretNote>()).isEmpty)
        XCTAssertEqual(try Data(contentsOf: restarted.recoveryURL(document.recoveryID)), cipher)
        try restarted.commit(document, encrypted: cipher, container: container)
        XCTAssertTrue(try restarted.recoveries(password: password).isEmpty)
        let saved = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertEqual(saved.title, ""); XCTAssertEqual(saved.content, "")
        XCTAssertEqual(try restarted.decrypt(try XCTUnwrap(saved.encryptedDiary), password: password), document)
    }
    func testFailureBeforeRecoveryLeavesOriginalUntouched() throws {
        let container = try container(), legacy = SecretNote(title: "Fictional original", content: "Exact\n original\n")
        container.mainContext.insert(legacy); try container.mainContext.save()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let invalidDirectory = root.appendingPathComponent("not-a-directory")
        try Data([1]).write(to: invalidDirectory)
        let broken = DiaryStorage(directory: invalidDirectory)
        var document = sample(); document.id = legacy.id
        let cipher = try storage.encrypt(document, password: "Fictional-7391")
        XCTAssertThrowsError(try broken.commit(document, encrypted: cipher, container: container))
        XCTAssertEqual(legacy.content, "Exact\n original\n"); XCTAssertNil(legacy.encryptedDiary)
    }
    func testExplicitSaveConvertsOnlySelectedLegacyEntry() throws {
        let container = try container()
        let one = SecretNote(title: "One", content: "Exact whitespace\n\n尾行\n"), two = SecretNote(title: "Two", content: "Do not touch")
        for note in [one, two] { container.mainContext.insert(note) }; try container.mainContext.save()
        let document = DiaryDocument.legacy(id: one.id, title: one.title, content: one.content, date: one.modifiedAt)
        XCTAssertEqual(document.plainText, one.content)
        try storage.commit(document, encrypted: storage.encrypt(document, password: "Fictional-7391"), container: container, expectedModifiedAt: one.modifiedAt)
        let context = ModelContext(container)
        let all = try context.fetch(FetchDescriptor<SecretNote>())
        let saved = try XCTUnwrap(all.first { $0.id == one.id }), untouched = try XCTUnwrap(all.first { $0.id == two.id })
        XCTAssertEqual(saved.title, ""); XCTAssertEqual(saved.content, ""); XCTAssertNotNil(saved.encryptedDiary)
        XCTAssertEqual(untouched.content, "Do not touch"); XCTAssertNil(untouched.encryptedDiary)
    }
    func testRepeatedSavePreservesIdentityAndPin() throws {
        let container = try container(), document = sample()
        let cipher = try storage.encrypt(document, password: "Fictional-7391")
        try storage.commit(document, encrypted: cipher, container: container)
        let context = ModelContext(container), note = try XCTUnwrap(context.fetch(FetchDescriptor<SecretNote>()).first)
        note.isFavorite = true; try context.save()
        for _ in 0..<3 { try storage.commit(document, encrypted: cipher, container: container, expectedModifiedAt: document.updatedAt) }
        let fetched = try ModelContext(container).fetch(FetchDescriptor<SecretNote>())
        XCTAssertEqual(fetched.count, 1); XCTAssertTrue(fetched[0].isFavorite)
    }
    func testNativeRoundTripUnicodeParagraphsAndPhotos() {
        let document = sample(), controller = DiaryTextController()
        let view = UITextView(); controller.view = view
        view.attributedText = controller.attributed(document)
        XCTAssertEqual(controller.runs(), document.runs)
        XCTAssertEqual(controller.runs().compactMap(\.photo).count, 2)
    }
    func testCursorInsertionBetweenPhotosAndExplicitMoveUndo() {
        let controller = DiaryTextController(), view = UITextView()
        controller.view = view
        view.attributedText = controller.attributed(sample())
        let old = controller.runs()
        let ns = view.textStorage.string as NSString
        let between = ns.range(of: "Between photos")
        controller.replace(NSRange(location: between.location, length: 0), with: NSAttributedString(string: "Inserted "))
        XCTAssertTrue(controller.runs().map(\.text).joined().contains("Inserted Between photos"))
        var first = NSRange()
        view.textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: view.textStorage.length)) { value, range, stop in
            if value is DiaryAttachment { first = range; stop.pointee = true }
        }
        let originalOrder = controller.runs().compactMap { $0.photo?.id }
        controller.move(photoID: originalOrder[0], to: view.textStorage.length)
        XCTAssertEqual(controller.runs().compactMap { $0.photo?.id }, originalOrder.reversed())
        // Custom mutations register native undo actions; a temporary run-loop group is closed explicitly.
        XCTAssertTrue(view.undoManager?.canUndo == true)
        view.undoManager?.undo()
        XCTAssertEqual(controller.runs(), old)
    }
    func testMoveResolvesPhotoIdentityAfterInterveningEditUndoAndRemoval() throws {
        let controller = DiaryTextController(), view = UITextView(); controller.view = view
        let document = sample(); view.attributedText = controller.attributed(document)
        let ids = document.runs.compactMap { $0.photo?.id }
        controller.replace(NSRange(location: 0, length: 0), with: NSAttributedString(string: "New paragraph before photo\n"))
        view.undoManager?.endUndoGrouping(); view.undoManager?.beginUndoGrouping()
        controller.move(photoID: ids[0], to: view.textStorage.length)
        XCTAssertEqual(controller.runs().compactMap { $0.photo?.id }, ids.reversed())
        XCTAssertTrue(view.text.hasPrefix("New paragraph before photo\nBefore"))
        view.undoManager?.undo()
        controller.move(photoID: ids[0], to: view.textStorage.length)
        XCTAssertEqual(controller.runs().compactMap { $0.photo?.id }, ids.reversed())
        var photoRange: NSRange?
        view.textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: view.textStorage.length)) { value, range, _ in
            if (value as? DiaryAttachment)?.photo.id == ids[0] { photoRange = range }
        }
        controller.replace(try XCTUnwrap(photoRange), with: NSAttributedString(string: ""))
        let remaining = controller.runs()
        controller.move(photoID: ids[0], to: 0)
        XCTAssertEqual(controller.runs(), remaining)
    }
    func testRemovalDoesNotChangeAnotherDocumentOrSource() {
        let document = sample(), controller = DiaryTextController(), view = UITextView()
        controller.view = view; view.attributedText = controller.attributed(document)
        let originalPhotoBytes = document.runs.compactMap(\.photo).first!.jpeg
        var range = NSRange()
        view.textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: view.textStorage.length)) { value, item, stop in
            if value is DiaryAttachment { range = item; stop.pointee = true }
        }
        controller.replace(range, with: NSAttributedString(string: ""))
        XCTAssertEqual(controller.runs().compactMap(\.photo).count, 1)
        XCTAssertEqual(document.photoCount, 2); XCTAssertEqual(document.runs.compactMap(\.photo).first!.jpeg, originalPhotoBytes)
    }
    func testLongImagePreviewIsBoundedAndFullDataSurvives() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 4000)).image { _ in UIColor.blue.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 200, height: 4000)) }
        let photo = DiaryDocument.Photo(jpeg: image.jpegData(compressionQuality: 0.8)!, width: 200, height: 4000)
        let attachment = DiaryAttachment(photo: photo)
        let bounds = attachment.attachmentBounds(for: nil, proposedLineFragment: CGRect(x: 0, y: 0, width: 375, height: 1), glyphPosition: .zero, characterIndex: 0)
        XCTAssertLessThanOrEqual(bounds.height, 800)
        XCTAssertEqual(attachment.photo.height, 4000); XCTAssertEqual(attachment.photo.jpeg, photo.jpeg)
    }
    func testLongTextRoundTrip() throws {
        let document = DiaryDocument.legacy(id: UUID(), title: "Fictional long entry", content: String(repeating: "Paragraph 🌿 中文\n", count: 8000), date: Date())
        let cipher = try storage.encrypt(document, password: "Fictional-7391")
        XCTAssertEqual(try storage.decrypt(cipher, password: "Fictional-7391"), document)
    }
    func testRevocationDropsTextUndoAndLateMutation() {
        let controller = DiaryTextController(), view = UITextView(); controller.view = view
        view.attributedText = controller.attributed(sample())
        controller.clear()
        controller.insert(sample().runs.compactMap(\.photo), at: NSRange(location: 0, length: 0))
        XCTAssertEqual(view.text, ""); XCTAssertFalse(view.undoManager?.canUndo == true)
    }
    func testPhotoNormalizationPreservesTallImageAndBoundsBytes() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 4000), format: format).image { _ in
            UIColor.systemMint.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 200, height: 4000))
        }
        let url = root.appendingPathComponent("fictional-long.png")
        try image.pngData()!.write(to: url)
        let photo = try DiaryPhotoImport.normalize(url: url)
        XCTAssertEqual(photo.width, image.cgImage?.width); XCTAssertEqual(photo.height, image.cgImage?.height)
        XCTAssertLessThan(photo.jpeg.count, 2_000_000)
    }
    func testDiskFailureLeavesEncryptedRecoveryReadableWithoutCanonicalWrite() throws {
        let document = sample()
        let cipher = try storage.encrypt(document, password: "Fictional-7391")
        let container = try container()
        XCTAssertThrowsError(try storage.commit(document, encrypted: cipher, container: container,
            save: { _ in throw CocoaError(.fileWriteNoPermission) }))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.recoveryURL(document.recoveryID).path))
        XCTAssertTrue(try ModelContext(container).fetch(FetchDescriptor<SecretNote>()).isEmpty)
    }
    func testLockedControllerCannotMoveRemoveOrUndoPhotos() {
        let controller = DiaryTextController(), view = UITextView(); controller.view = view
        view.attributedText = controller.attributed(sample())
        controller.replace(NSRange(location: 0, length: 0), with: NSAttributedString(string: "Fictional"))
        controller.clear()
        controller.move(photoID: UUID(), to: 3)
        controller.replace(NSRange(location: 0, length: 0), with: NSAttributedString(string: "Late"))
        controller.toggleBold()
        XCTAssertEqual(view.text, "")
    }
    func testOriginalOnDiskSchemaMigratesWithoutRewritingPlaintext() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("original.store")
        let id = UUID()
        try autoreleasepool {
            let schema = Schema([DiaryOriginalSchema.SecretNote.self])
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = ModelContext(container)
            let note = DiaryOriginalSchema.SecretNote(id: id)
            context.insert(note); try context.save()
        }
        let schema = Schema([ZeroNet_Space.SecretNote.self])
        let migrated = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let context = ModelContext(migrated)
        let note = try XCTUnwrap(context.fetch(FetchDescriptor<ZeroNet_Space.SecretNote>()).first)
        XCTAssertEqual(note.id, id); XCTAssertEqual(note.title, "Fictional legacy title")
        XCTAssertEqual(note.content, "Exact legacy\n中文 🌿\n"); XCTAssertNil(note.encryptedDiary)
        XCTAssertTrue(note.isFavorite); XCTAssertEqual(note.tags, ["fictional"])
    }
    func testWrittenEnvelopeAlwaysFitsTheReaderLimit() throws {
        let document = DiaryDocument.legacy(id: UUID(), title: "Fictional boundary", content: "Text", date: Date())
        let bytes = try JSONEncoder().encode(document)
        let exact = DiaryStorage(directory: root, maximumPlaintextBytes: bytes.count)
        let encrypted = try exact.encrypt(document, password: "Fictional-7391")
        XCTAssertEqual(encrypted.count, bytes.count + 44)
        XCTAssertEqual(try exact.decrypt(encrypted, password: "Fictional-7391"), document)
        let tooSmall = DiaryStorage(directory: root, maximumPlaintextBytes: bytes.count - 1)
        XCTAssertThrowsError(try tooSmall.encrypt(document, password: "Fictional-7391"))
    }
    func testAllDiaryStringsPresentInTenCompiledLocales() throws {
        let languages = ["en", "zh-Hans", "zh-Hant", "ja", "pl", "de", "fr", "es", "pt-BR", "id"]
        let keys = ["saving", "saved", "saveFailed", "saveFailed.message", "photoLimit", "importFailed", "back", "edit", "legacy", "moveHint", "moveHere", "photoActions", "viewPhoto", "writeAbove", "writeBelow", "movePhoto", "removePhoto", "retry", "optionalTitle", "addPhotos", "bold", "undo", "recovered", "recoveryHint", "openFailed", "recoveryFailed", "deleteFailed", "conflict", "saveCopy", "selectionTooLarge"]
        for language in languages {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in keys { XCTAssertNotEqual(bundle.localizedString(forKey: "diary." + key, value: "__MISSING__", table: nil), "__MISSING__", "\(language): \(key)") }
        }
    }
}

private enum DiaryOriginalSchema {
    @Model final class SecretNote {
        var id: UUID
        var title: String
        var content: String
        var createdAt: Date
        var modifiedAt: Date
        var isFavorite: Bool
        var tags: [String]
        init(id: UUID) {
            self.id = id; title = "Fictional legacy title"; content = "Exact legacy\n中文 🌿\n"
            let now = Date(); createdAt = now; modifiedAt = now; isFavorite = true; tags = ["fictional"]
        }
    }
}
