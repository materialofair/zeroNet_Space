import Foundation
import Testing

@testable import ZeroNet_Space

struct AsyncMediaDecryptionTests {

    @Test
    func loadsStandardEncryptedDataOffMainPath() async throws {
        let originalData = Data("standard encrypted document".utf8)
        let password = "test-password"
        let encryptedData = try EncryptionService.shared.encrypt(
            data: originalData,
            password: password
        )
        let path = try FileStorageService.shared.saveEncrypted(
            data: encryptedData,
            originalFileName: "async-test.txt"
        )
        defer { try? FileStorageService.shared.deleteFile(path: path) }

        let decryptedData = try await FileStorageService.shared.loadDecryptedDataAsync(
            path: path,
            password: password,
            preferredExtension: ".txt"
        )

        #expect(decryptedData == originalData)
    }

    @Test
    func createsPlayableFileFromStreamEncryptedData() async throws {
        let originalData = Data(repeating: 0x5A, count: 32 * 1_024)
        let password = "test-password"
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        try originalData.write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let path = try FileStorageService.shared.saveEncryptedFile(
            from: sourceURL,
            password: password,
            originalFileName: "async-test.mp4"
        )
        defer { try? FileStorageService.shared.deleteFile(path: path) }

        let decryptedURL = try await FileStorageService.shared.createDecryptedTempFileAsync(
            path: path,
            password: password,
            preferredExtension: ".mp4"
        )
        defer { try? FileManager.default.removeItem(at: decryptedURL) }

        #expect(try Data(contentsOf: decryptedURL) == originalData)
    }

    @Test
    func loadsStreamEncryptedDataThroughAsyncBridge() async throws {
        // 覆盖 loadDecryptedDataAsync 的 ZNSC 流式加密分支
        let originalData = Data("stream encrypted content for async bridge".utf8)
        let password = "test-password"
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        try originalData.write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        // saveEncryptedFile 使用流式加密（ZNSC 魔数）
        let path = try FileStorageService.shared.saveEncryptedFile(
            from: sourceURL,
            password: password,
            originalFileName: "stream-async.mp4"
        )
        defer { try? FileStorageService.shared.deleteFile(path: path) }

        let decryptedData = try await FileStorageService.shared.loadDecryptedDataAsync(
            path: path,
            password: password,
            preferredExtension: ".mp4"
        )

        #expect(decryptedData == originalData)
    }
}
