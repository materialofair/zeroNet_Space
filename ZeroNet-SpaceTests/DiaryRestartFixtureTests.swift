import XCTest
import SwiftData
import UIKit
@testable import ZeroNet_Space

/// This fixture can only touch the explicitly named, synthetic SealedPocket demo vault.
/// It exercises recovery across separate app processes, without shipping a debug bypass.
@MainActor final class DiaryRestartFixtureTests: XCTestCase {
    func testPrepareEncryptedRecoveryAndSyntheticGuest() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"]?.hasPrefix("SealedPocket-Demo-") == true)
        let keychain = KeychainService.shared
        try XCTSkipUnless(keychain.verifyPassword("Pocket7391"), "Prepare the named synthetic demo via normal setup first")
        let password = try keychain.retrieveDataPassword(using: "Pocket7391")
        for draft in try DiaryStorage.shared.recoveries(password: password) where draft.title == "Fictional restart recovery" {
            try DiaryStorage.shared.removeRecovery(draft.recoveryID)
        }
        try keychain.saveGuestPassword("830196")
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 180), format: format).image { _ in
            UIColor.systemTeal.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 320, height: 180))
        }
        let document = DiaryDocument(id: UUID(), title: "Fictional restart recovery",
            runs: [.init(text: "Owner-only fictional recovery before the photo.\n"),
                   .init(photo: .init(jpeg: image.jpegData(compressionQuality: 0.8)!, width: 320, height: 180)),
                   .init(text: "\nThe fictional text after the photo also survived restart.")], updatedAt: Date())
        let encrypted = try DiaryStorage.shared.encrypt(document, password: password)
        // A real commit failure path writes its recovery before the injected disk-full error.
        let isolated = try ModelContainer(for: SecretNote.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        XCTAssertThrowsError(try DiaryStorage.shared.commit(document, encrypted: encrypted, container: isolated,
            save: { _ in throw CocoaError(.fileWriteOutOfSpace) }))
        XCTAssertTrue(FileManager.default.fileExists(atPath: DiaryStorage.shared.recoveryURL(document.recoveryID).path))
    }
}
