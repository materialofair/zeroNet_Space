import Foundation
import SwiftData

/// Reuses the vault data password and the existing AES-GCM envelope, never a new key.
/// Recovery files contain the very same ciphertext as the committed SwiftData value.
nonisolated final class DiaryStorage: @unchecked Sendable {
    static let shared = DiaryStorage()
    enum SaveError: Error, Equatable { case conflict }
    struct RecoveryScan: Sendable { var documents: [DiaryDocument] = []; var unreadableCount = 0 }
    let recoveryDirectory: URL
    let maximumPlaintextBytes: Int

    init(directory: URL? = nil, maximumPlaintextBytes: Int = 80 * 1_024 * 1_024) {
        self.maximumPlaintextBytes = maximumPlaintextBytes
        recoveryDirectory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory,
            in: .userDomainMask)[0].appendingPathComponent("DiaryRecovery", isDirectory: true)
    }

    func encrypt(_ document: DiaryDocument, password: String) throws -> Data {
        let data = try JSONEncoder().encode(document)
        guard data.count <= maximumPlaintextBytes else { throw CocoaError(.fileWriteOutOfSpace) }
        return try EncryptionService.shared.encrypt(data: data, password: password)
    }

    func decrypt(_ data: Data, password: String) throws -> DiaryDocument {
        guard data.count <= maximumPlaintextBytes + 44 else { throw CocoaError(.fileReadTooLarge) }
        let plain = try EncryptionService.shared.decrypt(encryptedData: data, password: password)
        let document = try JSONDecoder().decode(DiaryDocument.self, from: plain)
        guard document.version == 1 else { throw CocoaError(.coderReadCorrupt) }
        return document
    }

    func writeRecovery(_ encrypted: Data, id: UUID) throws {
        try FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        try encrypted.write(to: recoveryURL(id), options: [.atomic, .completeFileProtection])
    }

    func recoveryURL(_ id: UUID) -> URL {
        recoveryDirectory.appendingPathComponent(id.uuidString).appendingPathExtension("zns")
    }

    func removeRecovery(_ id: UUID) throws {
        let url = recoveryURL(id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    func scanRecoveries(password: String) throws -> RecoveryScan {
        guard FileManager.default.fileExists(atPath: recoveryDirectory.path) else { return .init() }
        var scan = RecoveryScan()
        let files = try FileManager.default.contentsOfDirectory(at: recoveryDirectory, includingPropertiesForKeys: nil)
        for url in files where url.pathExtension == "zns" {
            do {
                let document = try decrypt(Data(contentsOf: url), password: password)
                guard url.deletingPathExtension().lastPathComponent == document.recoveryID.uuidString else {
                    throw CocoaError(.coderReadCorrupt)
                }
                scan.documents.append(document)
            } catch { scan.unreadableCount += 1 } // Keep the failed file; continue the other drafts.
        }
        return scan
    }

    func recoveries(password: String) throws -> [DiaryDocument] {
        try scanRecoveries(password: password).documents
    }

    /// A failed commit keeps the encrypted recovery and rolls back only this isolated context.
    @MainActor func commit(_ document: DiaryDocument, encrypted: Data, container: ModelContainer,
                           expectedModifiedAt: Date? = nil,
                           save: ((ModelContext) throws -> Void)? = nil) throws {
        try writeRecovery(encrypted, id: document.recoveryID)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let id = document.id
        let descriptor = FetchDescriptor<SecretNote>(predicate: #Predicate { $0.id == id })
        let existing = try context.fetch(descriptor).first
        guard existing?.modifiedAt == expectedModifiedAt else { throw SaveError.conflict }
        let note = existing ?? SecretNote()
        if note.modelContext == nil { note.id = id; note.createdAt = document.entryDate; context.insert(note) }
        note.encryptedDiary = encrypted
        // The plaintext legacy copy is removed only on an explicit save of this entry.
        note.title = ""
        note.content = ""
        note.modifiedAt = document.updatedAt
        do {
            if let save { try save(context) } else { try context.save() }
        } catch {
            context.rollback()
            throw error
        }
        // Failure to remove a redundant recovery is harmless; revision checks suppress it.
        try? removeRecovery(document.recoveryID)
    }
}
