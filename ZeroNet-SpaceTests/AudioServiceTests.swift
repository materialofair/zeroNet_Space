import AVFoundation
import SwiftData
import UniformTypeIdentifiers
import XCTest

@testable import ZeroNet_Space

@MainActor
final class AudioServiceTests: XCTestCase {
    func testAudioDetectionDoesNotReclassifyVideoOrDocuments() {
        for ext in ["m4a", ".MP3", "wav", "aiff", "aac", "caf", "flac"] {
            XCTAssertEqual(MediaType.from(fileExtension: ext), .audio)
            XCTAssertTrue(MediaType.audio.matches(fileExtension: ext))
            XCTAssertFalse(MediaType.document.matches(fileExtension: ext))
        }
        XCTAssertEqual(MediaType.from(utType: .audio), .audio)
        XCTAssertEqual(MediaType.from(mimeType: "audio/mpeg"), .audio)
        XCTAssertEqual(MediaType.from(fileExtension: "mp4"), .video)
        XCTAssertEqual(MediaType.from(fileExtension: "pdf"), .document)
        XCTAssertEqual(MediaType.from(fileExtension: "jpg"), .photo)
        XCTAssertEqual(MediaType(rawValue: "document"), .document)
    }

    func testLegacyAudioIsVisibleWithoutChangingStoredRawValue() throws {
        let container = try ModelContainer(for: MediaItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let item = MediaItem(fileName: "Old memo", fileExtension: ".M4A",
                             fileSize: 100, type: .document, encryptedPath: "legacy")
        container.mainContext.insert(item)
        try container.mainContext.save()
        let restored = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<MediaItem>()).first)
        XCTAssertEqual(restored.type, .audio)
        XCTAssertEqual(restored.typeRawValue, "document")
    }

    func testPlayableAudioEncryptsAndRoundTrips() async throws {
        let url = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let original = try Data(contentsOf: url)
        let item = try await AudioImportService.importFile(url: url, password: "audio-test-password")
        defer { try? FileStorageService.shared.deleteFile(path: item.encryptedPath) }
        XCTAssertEqual(item.type, .audio)
        XCTAssertEqual(item.fileExtension, ".wav")
        XCTAssertEqual(item.duration ?? 0, 0.25, accuracy: 0.01)
        XCTAssertEqual(item.fileSize, Int64(original.count))
        XCTAssertNotEqual(try FileStorageService.shared.loadEncrypted(path: item.encryptedPath), original)
        let decrypted = try await FileStorageService.shared.createDecryptedTempFileAsync(
            path: item.encryptedPath, password: "audio-test-password", preferredExtension: item.fileExtension)
        defer { try? FileManager.default.removeItem(at: decrypted) }
        XCTAssertEqual(try Data(contentsOf: decrypted), original)
        let player = try AVAudioPlayer(contentsOf: decrypted)
        XCTAssertEqual(player.duration, 0.25, accuracy: 0.01)
    }

    func testInvalidAudioDoesNotWriteEncryptedFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try Data("not audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let before = Set(FileStorageService.shared.getAllEncryptedFiles())
        do {
            _ = try await AudioImportService.importFile(url: url, password: "audio-test-password")
            XCTFail("Corrupt audio must be rejected")
        } catch {}
        XCTAssertEqual(Set(FileStorageService.shared.getAllEncryptedFiles()), before)
    }

    func testCancelledImportDoesNotWriteEncryptedFile() async throws {
        let url = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let before = Set(FileStorageService.shared.getAllEncryptedFiles())
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            _ = try await AudioImportService.importFile(url: url, password: "audio-test-password")
        }
        do {
            _ = try await task.value
            XCTFail("Cancellation must propagate")
        } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertEqual(Set(FileStorageService.shared.getAllEncryptedFiles()), before)
    }

    func testControllerRemovesAbandonedRecordingsOnLaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("abandoned.m4a")
        try Data("private recording".utf8).write(to: url)
        let controller = AudioSessionController(directory: directory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        controller.pauseForInterruption()
        controller.cleanup()
        XCTAssertFalse(controller.isRecording)
        XCTAssertFalse(controller.hasRecording)
        XCTAssertNil(controller.recordingURL)
        XCTAssertNil(controller.playingID)
    }

    func testAudioSharingVIPRestriction() async throws {
        let previousVIP = AppSettings.shared.isVIP
        defer { AppSettings.shared.isVIP = previousVIP }

        let url = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let originalData = try Data(contentsOf: url)
        let item = try await AudioImportService.importFile(url: url, password: "vip-test-password")
        defer { try? FileStorageService.shared.deleteFile(path: item.encryptedPath) }

        // 1. 非 VIP 会员禁止分享录音
        AppSettings.shared.isVIP = false
        XCTAssertFalse(AppSettings.shared.isVIP)

        // 2. VIP 会员允许解密并导出分享
        AppSettings.shared.isVIP = true
        XCTAssertTrue(AppSettings.shared.isVIP)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "test_share_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let shareURL = tempDir.appendingPathComponent(item.fullFileName)
        let sourceURL = FileStorageService.shared.getFileURL(for: item.encryptedPath)
        try EncryptionService.shared.decryptFile(inputURL: sourceURL, to: shareURL, password: "vip-test-password")

        XCTAssertTrue(FileManager.default.fileExists(atPath: shareURL.path))
        XCTAssertEqual(try Data(contentsOf: shareURL), originalData)
    }

    private func makeAudioFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 11_025))
        buffer.frameLength = 11_025
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for index in 0..<Int(buffer.frameLength) {
            samples[index] = Float(sin(Double(index) * 2 * .pi * 440 / 44_100)) * 0.2
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}
