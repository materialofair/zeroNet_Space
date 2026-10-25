import XCTest
import UIKit
@testable import ZeroNet_Space

final class AdaptivePrivacyRegressionTests: XCTestCase {
    func testWidthDecisionsLeaveUsableContent() {
        for width: CGFloat in [320, 375, 402, 639] {
            XCTAssertFalse(AdaptiveVaultLayout.showsSidebar(width: width, accessibility: false))
        }
        for width: CGFloat in [640, 669, 900, 1024, 1366] {
            XCTAssertTrue(AdaptiveVaultLayout.showsSidebar(width: width, accessibility: false))
            XCTAssertGreaterThanOrEqual(width - 200, 440)
        }
        XCTAssertFalse(AdaptiveVaultLayout.showsSidebar(width: 900, accessibility: true))
        XCTAssertTrue(AdaptiveVaultLayout.showsSidebar(width: 1366, accessibility: true))
        XCTAssertEqual(AdaptiveVaultLayout.photoColumns(width: 375, accessibility: false), 3)
        XCTAssertGreaterThan(AdaptiveVaultLayout.photoColumns(width: 1000, accessibility: false), 3)
        XCTAssertLessThan(AdaptiveVaultLayout.photoColumns(width: 1000, accessibility: true),
                          AdaptiveVaultLayout.photoColumns(width: 1000, accessibility: false))
    }

    func testCacheRejectsCompletionFromBeforeLock() {
        let cache = SensitiveImageCache(countLimit: 2, costLimit: 1_024_000)
        let token = cache.token()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in UIColor.cyan.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 20, height: 20)) }
        XCTAssertTrue(cache.insert(image, for: "fictional", token: token))
        cache.clear()
        XCTAssertFalse(cache.insert(image, for: "fictional", token: token))
        XCTAssertNil(cache.image(for: "fictional"))
        XCTAssertTrue(cache.insert(image, for: "fictional", token: cache.token()))
    }

    func testInFlightDecodeCannotRefillAfterClear() async {
        let started = expectation(description: "decode started")
        let resume = DispatchSemaphore(value: 0)
        let loader = ThumbnailImageLoader { _, _ in
            started.fulfill()
            _ = resume.wait(timeout: .now() + 5)
            return UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in }
        }
        let task = Task { await loader.image(for: "synthetic-in-flight", data: Data([1])) }
        await fulfillment(of: [started], timeout: 3)
        loader.clearAll()
        resume.signal()
        let result = await task.value
        XCTAssertNil(result, "Late decoder result must be discarded, not only removed from NSCache")
    }

    @MainActor func testRevokedSessionCannotPresentAfterAnotherLogin() {
        let auth = AuthenticationViewModel()
        let old = auth.presentationGeneration
        auth.isAuthenticated = true
        GuestModeManager.shared.setAuthenticationMode(.owner)
        XCTAssertTrue(auth.canPresentSensitiveResult(old))
        auth.logout()
        XCTAssertFalse(auth.canPresentSensitiveResult(old))
        auth.isAuthenticated = true
        GuestModeManager.shared.setAuthenticationMode(.owner)
        XCTAssertFalse(auth.canPresentSensitiveResult(old))
        XCTAssertTrue(auth.canPresentSensitiveResult(auth.presentationGeneration))
        GuestModeManager.shared.setAuthenticationMode(.guest)
        XCTAssertFalse(auth.canPresentSensitiveResult(auth.presentationGeneration))
        XCTAssertNil(SecretNoteDraftManager.shared.loadDraft(ownerAuthenticated: false))
        auth.isAuthenticated = false
        GuestModeManager.shared.reset()
    }

    func testExportCleanupOnlyRemovesTheOwnedRequest() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ZeroNetExport")
        let first = root.appendingPathComponent(UUID().uuidString)
        let second = root.appendingPathComponent(UUID().uuidString)
        for folder in [first, second] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        defer { for folder in [first, second] { try? FileManager.default.removeItem(at: folder) } }
        let a = first.appendingPathComponent("fictional.txt"), b = second.appendingPathComponent("fictional.txt")
        try Data("fictional".utf8).write(to: a); try Data("fictional".utf8).write(to: b)
        ExportService.shared.cleanupExportedFiles([a])
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: b.path))
    }
    @MainActor private func fictionalEncryptedFile() throws -> (MediaItem, Data) {
        let content = Data("Fictional document for local import, preview and export regression.".utf8)
        let encrypted = try EncryptionService.shared.encrypt(data: content, password: "Synthetic7391")
        let path = try FileStorageService.shared.saveEncrypted(data: encrypted, originalFileName: "Synthetic.txt")
        return (MediaItem(fileName: "Synthetic-" + UUID().uuidString, fileExtension: ".txt",
                          fileSize: Int64(content.count), type: .document, encryptedPath: path), content)
    }

    @MainActor func testNormalDocumentExportRoundTrip() async throws {
        let (item, content) = try fictionalEncryptedFile()
        defer { try? FileStorageService.shared.deleteFile(path: item.encryptedPath) }
        let service = ExportService()
        let result = await withCheckedContinuation { continuation in
            service.exportItems([item], password: "Synthetic7391") { continuation.resume(returning: $0) }
        }
        let urls = try result.get()
        defer { service.cleanupExportedFiles(urls) }
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(try Data(contentsOf: urls[0]), content)
    }

    @MainActor func testCancellationAfterWorkerBeforeMainCallbackCannotSucceed() async throws {
        let (item, _) = try fictionalEncryptedFile()
        defer { try? FileStorageService.shared.deleteFile(path: item.encryptedPath) }
        let queue = DispatchQueue(label: "synthetic-export-race")
        let service = ExportService(exportQueue: queue)
        let callback = expectation(description: "revoked export completion")
        service.exportItems([item], password: "Synthetic7391") { result in
            if case .success(let urls) = result {
                service.cleanupExportedFiles(urls)
                XCTFail("A queued success must become cancellation after revocation")
            } else if case .failure(let error) = result {
                if case .cancelled = error {} else { XCTFail("Expected cancellation") }
            }
            callback.fulfill()
        }
        // Hold the main actor until the worker has queued its completion. This
        // deterministically exercises the narrow race, without arbitrary delays.
        let workerFinished = DispatchSemaphore(value: 0)
        queue.async { workerFinished.signal() }
        XCTAssertEqual(workerFinished.wait(timeout: .now() + 5), .success)
        service.cancelCurrentExport()
        await fulfillment(of: [callback], timeout: 3)
    }

    @MainActor func testGuestCannotReadOwnerDraftWithStaleOwnerFlag() {
        let identifier = "synthetic-draft-" + UUID().uuidString
        let keychain = KeychainService(service: identifier)
        let defaults = UserDefaults(suiteName: identifier)!
        let drafts = SecretNoteDraftManager(keychainService: keychain, defaults: defaults)
        defer {
            keychain.clearAllKeychainData()
            defaults.removePersistentDomain(forName: identifier)
            GuestModeManager.shared.reset()
        }
        GuestModeManager.shared.setAuthenticationMode(.owner)
        drafts.saveDraft(title: "Fictional owner title", content: "Fictional owner body")
        XCTAssertEqual(drafts.loadDraft(ownerAuthenticated: true)?.content, "Fictional owner body")
        GuestModeManager.shared.setAuthenticationMode(.guest)
        XCTAssertNil(drafts.loadDraft(ownerAuthenticated: true), "Actual guest mode overrides a stale view flag")
        XCTAssertNil(drafts.loadDraft(ownerAuthenticated: false))
        GuestModeManager.shared.setAuthenticationMode(.owner)
        XCTAssertEqual(drafts.loadDraft(ownerAuthenticated: true)?.title, "Fictional owner title")
    }

}
