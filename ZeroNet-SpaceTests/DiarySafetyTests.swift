import XCTest
import SwiftData
import UIKit
import UniformTypeIdentifiers
import ImageIO
@testable import ZeroNet_Space

@MainActor private final class FictionalDiarySession: DiarySessionProviding {
    var isAuthenticated = true
    var isDiaryOwner = true
    var sessionPassword: String? = "Fictional-test-only-7391"
    var presentationGeneration = UUID()
    func canPresentSensitiveResult(_ generation: UUID) -> Bool {
        isAuthenticated && isDiaryOwner && generation == presentationGeneration
    }
}

@MainActor final class DiarySafetyTests: XCTestCase {
    private var root: URL!
    private var storage: DiaryStorage!
    private var container: ModelContainer!
    private var session: FictionalDiarySession!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("DiarySafety-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        storage = DiaryStorage(directory: root.appendingPathComponent("Recovery"))
        container = try ModelContainer(for: SecretNote.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        session = FictionalDiarySession()
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }
    private func document() -> DiaryDocument {
        .legacy(id: UUID(), title: "Fictional safety entry", content: "Before\nAfter\n", date: Date())
    }
    private func editor(_ document: DiaryDocument, expected: Date? = nil,
                        save: ((ModelContext) throws -> Void)? = nil) -> (DiaryEditorModel, UITextView) {
        let model = DiaryEditorModel(document: document, editing: true, storage: storage,
            expectedModifiedAt: expected, saveContext: save)
        model.configure(container: container, authentication: session)
        let view = UITextView(); model.text.view = view
        view.attributedText = model.text.attributed(document)
        model.text.changed = { [weak model] in model?.changed() }
        return (model, view)
    }
    private func imageURL(_ name: String, color: UIColor = .systemTeal) throws -> URL {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 120), format: format).image { _ in
            color.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 80, height: 120))
        }
        let url = root.appendingPathComponent(name + ".png"); try image.pngData()!.write(to: url); return url
    }
    private func provider(_ url: URL, delay: TimeInterval = 0) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerFileRepresentation(forTypeIdentifier: UTType.image.identifier, fileOptions: [], visibility: .all) { completion in
            if delay > 0 { DispatchQueue.global().asyncAfter(deadline: .now() + delay) { completion(url, false, nil) } }
            else { completion(url, false, nil) }
            return Progress(totalUnitCount: 1)
        }
        return provider
    }
    private func finishImport(_ model: DiaryEditorModel) async {
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !model.importing }, object: nil)
        await fulfillment(of: [finished], timeout: 5)
    }
    func testClearingExistingTitleOnlyEntryPersistsEmptyDocument() throws {
        var original = document(); original.runs = []
        try storage.commit(original, encrypted: storage.encrypt(original, password: session.sessionPassword!), container: container)
        let (model, view) = editor(original, expected: original.updatedAt)
        model.document.title = ""; model.changed(); XCTAssertTrue(model.flush())
        let note = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertTrue(try storage.decrypt(try XCTUnwrap(note.encryptedDiary), password: session.sessionPassword!).isEmpty)
        withExtendedLifetime(view) {}
    }
    func testClearingAllExistingContentAutosaves() async throws {
        let original = document()
        try storage.commit(original, encrypted: storage.encrypt(original, password: session.sessionPassword!), container: container)
        let (model, view) = editor(original, expected: original.updatedAt)
        model.document.title = ""; view.attributedText = NSAttributedString(string: ""); model.changed()
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let note = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertTrue(try storage.decrypt(try XCTUnwrap(note.encryptedDiary), password: session.sessionPassword!).isEmpty)
    }
    func testUntouchedNewBlankEntryDoesNotCreateNote() throws {
        let blank = DiaryDocument.legacy(id: UUID(), title: "", content: "", date: Date())
        let (model, view) = editor(blank); model.changed(); XCTAssertTrue(model.flush())
        XCTAssertTrue(try ModelContext(container).fetch(FetchDescriptor<SecretNote>()).isEmpty)
        withExtendedLifetime(view) {}
    }
    func testLegacyAutosaveAndLockKeepOriginalUntilExplicitCommit() async throws {
        let context = ModelContext(container), note = SecretNote(title: "Fictional original", content: "Original text")
        context.insert(note); try context.save()
        let original = DiaryDocument.legacy(id: note.id, title: note.title, content: note.content, date: note.modifiedAt)
        let model = DiaryEditorModel(document: original, editing: true, legacy: true, storage: storage, expectedModifiedAt: note.modifiedAt)
        model.configure(container: container, authentication: session)
        model.document.title = "Fictional changed"; model.changed()
        try await Task.sleep(nanoseconds: 1_500_000_000)
        var stored = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertEqual(stored.title, "Fictional original"); XCTAssertEqual(stored.content, "Original text"); XCTAssertNil(stored.encryptedDiary)
        XCTAssertEqual(try storage.recoveries(password: session.sessionPassword!).first?.title, "Fictional changed")
        XCTAssertTrue(model.flush(atLockBoundary: true))
        stored = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertNil(stored.encryptedDiary)
        XCTAssertTrue(model.flush())
        stored = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertNotNil(stored.encryptedDiary); XCTAssertEqual(stored.content, "")
        XCTAssertTrue(try storage.recoveries(password: session.sessionPassword!).isEmpty)
    }
    func testEmptyFailedSaveRecoveryCommitsAfterRestart() throws {
        let original = document()
        try storage.commit(original, encrypted: storage.encrypt(original, password: session.sessionPassword!), container: container)
        let (failed, view) = editor(original, expected: original.updatedAt, save: { _ in throw CocoaError(.fileWriteOutOfSpace) })
        failed.document.title = ""; view.attributedText = NSAttributedString(string: ""); failed.changed()
        XCTAssertFalse(failed.flush())
        let recovered = try XCTUnwrap(storage.recoveries(password: session.sessionPassword!).first)
        XCTAssertTrue(recovered.isEmpty)
        let restarted = DiaryEditorModel(document: recovered, editing: true, storage: storage,
            expectedModifiedAt: recovered.baseModifiedAt, sourceRecoveryID: recovered.recoveryID)
        restarted.configure(container: container, authentication: session)
        XCTAssertTrue(restarted.flush())
        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertTrue(try storage.decrypt(try XCTUnwrap(saved.encryptedDiary), password: session.sessionPassword!).isEmpty)
        XCTAssertTrue(try storage.recoveries(password: session.sessionPassword!).isEmpty)
    }
    func testLegacyRecoveryRetainsExplicitMigrationAcrossRestartAndLock() throws {
        let context = ModelContext(container), note = SecretNote(title: "Fictional legacy", content: "Keep original until Done")
        context.insert(note); try context.save()
        var recovered = DiaryDocument.legacy(id: note.id, title: "Recovered edit", content: "New text", date: note.modifiedAt)
        recovered.baseModifiedAt = note.modifiedAt
        try storage.writeRecovery(storage.encrypt(recovered, password: session.sessionPassword!), id: recovered.recoveryID)
        let restarted = DiaryEditorModel(document: recovered, editing: true, storage: storage,
            expectedModifiedAt: recovered.baseModifiedAt, sourceRecoveryID: recovered.recoveryID)
        restarted.configure(container: container, authentication: session)
        XCTAssertTrue(restarted.isLegacy)
        XCTAssertTrue(restarted.flush(explicitCommit: false)); XCTAssertTrue(restarted.flush(atLockBoundary: true))
        var saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertEqual(saved.content, "Keep original until Done"); XCTAssertNil(saved.encryptedDiary)
        XCTAssertTrue(restarted.flush())
        saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertNotNil(saved.encryptedDiary); XCTAssertEqual(saved.content, "")
        XCTAssertTrue(try storage.recoveries(password: session.sessionPassword!).isEmpty)
    }
    func testClearingRecoveredNewEntryCommitsEmptyAndRemovesSourceDraft() throws {
        let original = document()
        let (failed, firstView) = editor(original, save: { _ in throw CocoaError(.fileWriteOutOfSpace) })
        XCTAssertFalse(failed.flush())
        let recovered = try XCTUnwrap(storage.recoveries(password: session.sessionPassword!).first)
        XCTAssertNil(recovered.baseModifiedAt)
        let restarted = DiaryEditorModel(document: recovered, editing: true, storage: storage,
            sourceRecoveryID: recovered.recoveryID)
        restarted.configure(container: container, authentication: session)
        let view = UITextView(); restarted.text.view = view
        view.attributedText = NSAttributedString(string: ""); restarted.document.title = ""; restarted.changed()
        XCTAssertTrue(restarted.flush())
        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertTrue(try storage.decrypt(try XCTUnwrap(saved.encryptedDiary), password: session.sessionPassword!).isEmpty)
        XCTAssertTrue(try storage.recoveries(password: session.sessionPassword!).isEmpty)
        withExtendedLifetime(firstView) {}
    }
    func testEmptyConflictedEntryCanExplicitlySaveAsCopy() throws {
        let original = document()
        try storage.commit(original, encrypted: storage.encrypt(original, password: session.sessionPassword!), container: container)
        let (first, firstView) = editor(original, expected: original.updatedAt)
        let (second, secondView) = editor(original, expected: original.updatedAt)
        first.document.title = "Other window saved"; first.changed(); XCTAssertTrue(first.flush())
        second.document.title = ""; secondView.attributedText = NSAttributedString(string: ""); second.changed()
        XCTAssertFalse(second.flush()); XCTAssertTrue(second.conflicted)
        XCTAssertTrue(second.saveAsCopy())
        let notes = try ModelContext(container).fetch(FetchDescriptor<SecretNote>())
        XCTAssertEqual(notes.count, 2)
        let documents = try notes.map { try storage.decrypt(try XCTUnwrap($0.encryptedDiary), password: session.sessionPassword!) }
        XCTAssertEqual(documents.filter(\.isEmpty).count, 1)
        XCTAssertTrue(documents.contains { $0.title == "Other window saved" })
        XCTAssertTrue(try storage.recoveries(password: session.sessionPassword!).isEmpty)
        withExtendedLifetime([firstView, secondView]) {}
    }
    func testCorruptRecoveryDoesNotHideOtherDrafts() throws {
        let good = document(), cipher = try storage.encrypt(good, password: session.sessionPassword!)
        try storage.writeRecovery(cipher, id: good.recoveryID)
        let brokenID = UUID(); try storage.writeRecovery(Data("broken synthetic data".utf8), id: brokenID)
        let scan = try storage.scanRecoveries(password: session.sessionPassword!)
        XCTAssertEqual(scan.documents, [good]); XCTAssertEqual(scan.unreadableCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.recoveryURL(brokenID).path))
    }
    func testConcurrentWindowsCannotOverwriteAndHaveIndependentRecoveries() throws {
        let original = document(), cipher = try storage.encrypt(original, password: session.sessionPassword!)
        try storage.commit(original, encrypted: cipher, container: container)
        let (first, firstView) = editor(original, expected: original.updatedAt)
        let (second, secondView) = editor(original, expected: original.updatedAt)
        first.document.title = "Fictional first window"; first.changed(); XCTAssertTrue(first.flush())
        second.document.title = "Fictional second window"; second.changed(); XCTAssertFalse(second.flush())
        XCTAssertTrue(second.conflicted)
        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertEqual(try storage.decrypt(try XCTUnwrap(saved.encryptedDiary), password: session.sessionPassword!).title, "Fictional first window")
        XCTAssertEqual(try storage.recoveries(password: session.sessionPassword!).first?.title, "Fictional second window")
        XCTAssertTrue(second.saveAsCopy())
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<SecretNote>()).count, 2)
        XCTAssertTrue(try storage.recoveries(password: session.sessionPassword!).isEmpty)
        withExtendedLifetime([firstView, secondView]) {}
    }
    func testDeletedEntryCannotBeSilentlyResurrectedByOldWindow() throws {
        let original = document(), cipher = try storage.encrypt(original, password: session.sessionPassword!)
        try storage.commit(original, encrypted: cipher, container: container)
        let (model, view) = editor(original, expected: original.updatedAt)
        let context = ModelContext(container), note = try XCTUnwrap(context.fetch(FetchDescriptor<SecretNote>()).first)
        context.delete(note); try context.save()
        model.changed(); XCTAssertFalse(model.flush()); XCTAssertTrue(model.conflicted)
        XCTAssertTrue(try ModelContext(container).fetch(FetchDescriptor<SecretNote>()).isEmpty)
        XCTAssertEqual(try storage.recoveries(password: session.sessionPassword!).count, 1)
        withExtendedLifetime(view) {}
    }
    func testSaveFailureRetainsTextAndRestartRecovery() throws {
        let original = document()
        let (model, view) = editor(original, save: { _ in throw CocoaError(.fileWriteOutOfSpace) })
        model.document.title = "Fictional failed save"; model.changed()
        XCTAssertFalse(model.flush()); XCTAssertNotNil(model.error)
        XCTAssertTrue(view.text.contains("Before")); XCTAssertEqual(model.document.title, "Fictional failed save")
        let restarted = DiaryStorage(directory: storage.recoveryDirectory)
        let recovered = try XCTUnwrap(restarted.recoveries(password: session.sessionPassword!).first)
        XCTAssertEqual(recovered.title, "Fictional failed save"); XCTAssertEqual(recovered.plainText, "Before\nAfter\n")
        XCTAssertNil(try ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
    }
    func testManualLockFlushesBeforeKeyRevocationAndRejectsLateEdits() throws {
        let (model, view) = editor(document())
        model.document.title = "Fictional last instant"; model.changed()
        session.presentationGeneration = UUID()
        model.revoke()
        session.isAuthenticated = false; session.sessionPassword = nil
        XCTAssertEqual(view.text, ""); XCTAssertTrue(model.revoked)
        let note = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertNotNil(note.encryptedDiary)
        model.text.replace(NSRange(location: 0, length: 0), with: NSAttributedString(string: "Late result"))
        XCTAssertEqual(view.text, "")
    }
    func testGuestCannotPersistOrRetainOwnerDraft() throws {
        let (model, view) = editor(document())
        model.changed(); session.isDiaryOwner = false; model.revoke()
        XCTAssertTrue(model.revoked); XCTAssertEqual(view.text, ""); XCTAssertEqual(model.document.title, "")
        XCTAssertTrue(try ModelContext(container).fetch(FetchDescriptor<SecretNote>()).isEmpty)
        XCTAssertTrue(try storage.recoveries(password: session.sessionPassword!).isEmpty)
    }
    func testFailedBatchInsertsNothingAndRetryPreservesSelectedOrder() async throws {
        let firstURL = try imageURL("first"), secondURL = root.appendingPathComponent("retry.png")
        try Data("intentionally invalid image".utf8).write(to: secondURL)
        let first = provider(firstURL), second = provider(secondURL)
        let (model, view) = editor(document())
        model.beginImport(providers: [first, second], at: NSRange(location: 7, length: 0))
        await finishImport(model)
        XCTAssertEqual(model.text.runs().compactMap(\.photo).count, 0); XCTAssertTrue(model.canRetryImport)
        let valid = try imageURL("second", color: .systemOrange)
        try FileManager.default.removeItem(at: secondURL); try FileManager.default.copyItem(at: valid, to: secondURL)
        model.retryImport(); await finishImport(model)
        let photos = model.text.runs().compactMap(\.photo)
        XCTAssertEqual(photos.count, 2)
        XCTAssertEqual(photos.first?.jpeg, try DiaryPhotoImport.normalize(url: firstURL).jpeg)
        XCTAssertEqual(photos.last?.jpeg, try DiaryPhotoImport.normalize(url: secondURL).jpeg)
        XCTAssertTrue(view.text.hasPrefix("Before\n"))
    }
    func testCancelledAndRevokedProviderCannotInsertLater() async throws {
        let url = try imageURL("late")
        let (model, view) = editor(document())
        model.beginImport(providers: [provider(url, delay: 0.4)], at: NSRange(location: 0, length: 0))
        model.cancelImport()
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(model.text.runs().compactMap(\.photo).count, 0)
        model.beginImport(providers: [provider(url, delay: 0.4)], at: NSRange(location: 0, length: 0))
        model.revoke(); try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(view.text, ""); XCTAssertEqual(model.text.runs().compactMap(\.photo).count, 0)
    }
    func testNormalizedJPEGDoesNotCarrySourceLocationMetadata() throws {
        let input = try imageURL("metadata-base"), photo = try DiaryPhotoImport.normalize(url: input)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(photo.jpeg as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let located = root.appendingPathComponent("synthetic-location.jpg")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(located as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 1.234, kCGImagePropertyGPSLatitudeRef: "N", kCGImagePropertyGPSLongitude: 2.345, kCGImagePropertyGPSLongitudeRef: "E"]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let normalized = try DiaryPhotoImport.normalize(url: located)
        let output = try XCTUnwrap(CGImageSourceCreateWithData(normalized.jpeg as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(output, 0, nil) as? [CFString: Any])
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
    }
    func testRichFormattingSurvivesEncryptedFailedSaveRestartAndGuestIsolation() throws {
        var original = document()
        original.runs = [.init(text: "小标题\n", paragraph: .heading),
            .init(text: "中文😀 stacked\n", bold: true, italic: true, underline: true),
            .init(text: "一\n二\n", paragraph: .numbered), .init(text: "引用", paragraph: .quote)]
        let (failed, view) = editor(original, save: { _ in throw CocoaError(.fileWriteOutOfSpace) })
        XCTAssertFalse(failed.flush()); XCTAssertNotNil(failed.error)
        let recovery = try XCTUnwrap(storage.recoveries(password: session.sessionPassword!).first)
        XCTAssertEqual(recovery.runs, original.runs)
        let cipher = try Data(contentsOf: storage.recoveryURL(recovery.recoveryID))
        XCTAssertNil(cipher.range(of: Data("stacked".utf8)))
        session.isDiaryOwner = false
        let guest = DiaryEditorModel(document: recovery, editing: true, storage: storage, sourceRecoveryID: recovery.recoveryID)
        guest.configure(container: container, authentication: session)
        XCTAssertFalse(guest.flush()); XCTAssertFalse(guest.authorized)
        XCTAssertTrue(try ModelContext(container).fetch(FetchDescriptor<SecretNote>()).isEmpty)
        session.isDiaryOwner = true
        let restarted = DiaryEditorModel(document: recovery, editing: true, storage: storage, sourceRecoveryID: recovery.recoveryID)
        restarted.configure(container: container, authentication: session)
        XCTAssertTrue(restarted.flush())
        let stored = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<SecretNote>()).first)
        XCTAssertEqual(try storage.decrypt(try XCTUnwrap(stored.encryptedDiary), password: session.sessionPassword!).runs, original.runs)
        XCTAssertTrue(try storage.recoveries(password: session.sessionPassword!).isEmpty)
        withExtendedLifetime(view) {}
    }

}
