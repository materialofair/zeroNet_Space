import AVFoundation
import Foundation

/// Validates audio before writing encrypted content. Database ownership stays with the caller.
@MainActor
enum AudioImportService {
    static func importFile(url: URL, password: String) async throws -> MediaItem {
        try Task.checkCancellation()
        guard !password.isEmpty else { throw ImportError.permissionDenied }
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let duration = try await asset.load(.duration).seconds
        guard !tracks.isEmpty, duration.isFinite, duration > 0,
            try await asset.load(.isPlayable)
        else { throw ImportError.unsupportedType }
        try Task.checkCancellation()
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        // Stream large files off the UI thread; await completion even on cancellation so
        // the caller's security-scoped URL stays valid until the write has finished.
        let path = try await Task.detached(priority: .userInitiated) {
            try FileStorageService.shared.saveEncryptedFile(
                from: url, password: password, originalFileName: url.lastPathComponent)
        }.value
        do {
            try Task.checkCancellation()
            return MediaItem(
                fileName: url.deletingPathExtension().lastPathComponent,
                fileExtension: "." + url.pathExtension,
                fileSize: Int64(size), type: .audio, encryptedPath: path, duration: duration)
        } catch {
            try? FileStorageService.shared.deleteFile(path: path)
            throw error
        }
    }
}
