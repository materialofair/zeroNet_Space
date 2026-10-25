import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

@MainActor protocol DiarySessionProviding: AnyObject {
    var isAuthenticated: Bool { get }
    var isDiaryOwner: Bool { get }
    var sessionPassword: String? { get }
    var presentationGeneration: UUID { get }
    func canPresentSensitiveResult(_ generation: UUID) -> Bool
}

extension AuthenticationViewModel: DiarySessionProviding {
    var isDiaryOwner: Bool { GuestModeManager.shared.isOwnerMode }
}

@MainActor final class DiaryEditorModel: ObservableObject {
    @Published var document: DiaryDocument
    @Published var editing: Bool
    @Published var error: String?
    @Published var status: String = ""
    @Published var importing = false
    @Published var importProgress = 0
    @Published var importTotal = 0
    @Published var revoked = false
    @Published var conflicted = false
    let text = DiaryTextController()
    var isLegacy: Bool
    private var dirty = false
    private var forcePersistence = false
    private var revision = 0
    private var task: Task<Void, Never>?
    private var providerProgress: Progress?
    private var currentSelection: NSItemProvider?
    private var failedSelection: [NSItemProvider] = []
    private var batchSelection: [NSItemProvider] = []
    private var pendingSelection: [NSItemProvider] = []
    private var importedPhotos: [DiaryDocument.Photo] = []
    private var insertionRange = NSRange(location: 0, length: 0)
    private var importToken = UUID()
    private var existingImageBytesAtImport = 0
    private var oversizedSelection = false
    private var container: ModelContainer?
    private weak var authentication: (any DiarySessionProviding)?
    private var generation = UUID()
    private let storage: DiaryStorage
    private var clearLegacyDraft: Bool
    private var expectedModifiedAt: Date?
    private let sourceRecoveryID: UUID?
    private let saveContext: ((ModelContext) throws -> Void)?

    init(document: DiaryDocument, editing: Bool, legacy: Bool = false,
         clearLegacyDraft: Bool = false, storage: DiaryStorage = .shared,
         expectedModifiedAt: Date? = nil, sourceRecoveryID: UUID? = nil,
         saveContext: ((ModelContext) throws -> Void)? = nil) {
        self.document = document; self.editing = editing; self.isLegacy = legacy
        self.clearLegacyDraft = clearLegacyDraft; self.storage = storage
        self.expectedModifiedAt = expectedModifiedAt; self.sourceRecoveryID = sourceRecoveryID
        self.saveContext = saveContext
        self.document.recoveryID = UUID()
        dirty = editing && (!document.isEmpty || sourceRecoveryID != nil)
    }

    func configure(container: ModelContainer, authentication: any DiarySessionProviding) {
        self.container = container; self.authentication = authentication
        generation = authentication.presentationGeneration
        if sourceRecoveryID != nil, expectedModifiedAt != nil {
            // A recovered legacy edit keeps its explicit-conversion boundary across restart.
            // If lookup fails, preserve the original conservatively until Done/Back.
            isLegacy = true
            let id = document.id
            let descriptor = FetchDescriptor<SecretNote>(predicate: #Predicate { $0.id == id })
            if let note = try? ModelContext(container).fetch(descriptor).first {
                isLegacy = note.encryptedDiary == nil
            }
        }
    }
    var authorized: Bool {
        !revoked && authentication?.canPresentSensitiveResult(generation) == true
    }
    var canRetryImport: Bool { !failedSelection.isEmpty }

    func changed() {
        guard authorized else { return }
        dirty = true; revision += 1
        document.updatedAt = Date()
        status = String(localized: "diary.saving")
        task?.cancel()
        task = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 700_000_000) } catch { return }
            guard let self, self.authorized else { return }
            await self.saveInBackground()
        }
    }

    func snapshot() -> DiaryDocument {
        var copy = document
        if text.view != nil { copy.runs = text.runs() }
        copy.baseModifiedAt = expectedModifiedAt
        return copy
    }

    private func saveInBackground() async {
        guard dirty, let authentication, let password = authentication.sessionPassword,
              let container else { return }
        let current = revision, snapshot = snapshot()
        guard shouldPersist(snapshot) else { return }
        do {
            let storage = storage
            let encrypted = try await Task.detached(priority: .utility) {
                try storage.encrypt(snapshot, password: password)
            }.value
            guard authorized, !Task.isCancelled, current == revision else { return }
            if isLegacy {
                try storage.writeRecovery(encrypted, id: snapshot.recoveryID)
                status = String(localized: "diary.recoverySaved")
            } else {
                try storage.commit(snapshot, encrypted: encrypted, container: container, expectedModifiedAt: expectedModifiedAt, save: saveContext)
                saved(snapshot)
            }
        } catch {
            guard authorized, !Task.isCancelled else { return }
            reportSaveError(error)
        }
    }

    /// Used before lock/key revocation, backgrounding and explicit navigation.
    /// No suspension is allowed between this snapshot and the write.
    @discardableResult func flush(atLockBoundary: Bool = false, explicitCommit: Bool = true) -> Bool {
        task?.cancel()
        guard authorized || (atLockBoundary && !revoked && authentication?.isAuthenticated == true
            && authentication?.isDiaryOwner == true) else { return false }
        guard dirty else { return true }
        let snapshot = snapshot()
        guard shouldPersist(snapshot) else { return true }
        guard let password = authentication?.sessionPassword, let container else { return false }
        do {
            let encrypted = try storage.encrypt(snapshot, password: password)
            if isLegacy && (!explicitCommit || atLockBoundary) {
                try storage.writeRecovery(encrypted, id: snapshot.recoveryID)
                status = String(localized: "diary.recoverySaved")
                return true
            }
            try storage.commit(snapshot, encrypted: encrypted, container: container, expectedModifiedAt: expectedModifiedAt, save: saveContext)
            saved(snapshot); return true
        } catch {
            reportSaveError(error)
            return false
        }
    }

    private func shouldPersist(_ snapshot: DiaryDocument) -> Bool {
        // Clearing existing content is a real edit; only a new blank entry is omitted.
        !snapshot.isEmpty || expectedModifiedAt != nil || clearLegacyDraft || sourceRecoveryID != nil || forcePersistence
    }

    private func saved(_ snapshot: DiaryDocument) {
        document.runs = snapshot.runs
        expectedModifiedAt = snapshot.updatedAt; conflicted = false
        if let sourceRecoveryID { try? storage.removeRecovery(sourceRecoveryID) }
        dirty = false; isLegacy = false; forcePersistence = false
        status = String(localized: "diary.saved")
        if clearLegacyDraft { SecretNoteDraftManager.shared.clearDraft(); clearLegacyDraft = false }
    }

    private func reportSaveError(_ error: Error) {
        conflicted = (error as? DiaryStorage.SaveError) == .conflict
        status = String(localized: "diary.saveFailed")
        self.error = conflicted ? String(localized: "diary.conflict") : String(localized: "diary.saveFailed.message")
    }

    @discardableResult func saveAsCopy() -> Bool {
        guard authorized else { return false }
        document.id = UUID(); expectedModifiedAt = nil; conflicted = false; dirty = true; forcePersistence = true
        document.updatedAt = Date()
        return flush()
    }

    func beginImport(_ results: [PHPickerResult], at range: NSRange) {
        beginImport(providers: results.map(\.itemProvider), at: range)
    }

    func beginImport(providers results: [NSItemProvider], at range: NSRange) {
        guard authorized, !results.isEmpty, !importing else { return }
        // A bounded entry prevents an accidental multi-gigabyte document.
        guard snapshot().photoCount + results.count <= 20 else {
            error = String(localized: "diary.photoLimit"); return
        }
        insertionRange = range; importToken = UUID()
        existingImageBytesAtImport = snapshot().runs.compactMap(\.photo).reduce(0) { $0 + $1.jpeg.count }
        oversizedSelection = false
        failedSelection = []; importedPhotos = []; pendingSelection = results; batchSelection = results
        importTotal = results.count; importProgress = 0; importing = true
        importNext(token: importToken)
    }

    func retryImport() {
        let results = failedSelection
        beginImport(providers: results, at: insertionRange)
    }

    private func importNext(token: UUID) {
        guard authorized, token == importToken else { return }
        guard !pendingSelection.isEmpty else {
            importing = false
            if !failedSelection.isEmpty {
                // Insert the selection atomically, so retry cannot reverse the user's order.
                importedPhotos = []; failedSelection = batchSelection
                error = oversizedSelection ? String(localized: "diary.selectionTooLarge") : String(localized: "diary.importFailed")
                if oversizedSelection { failedSelection = [] }
            } else if !importedPhotos.isEmpty {
                text.insert(importedPhotos, at: insertionRange)
                importedPhotos = []
                _ = flush(explicitCommit: false)
                // Resume at the inserted photos after SwiftUI re-enables the text view.
                // A lock or a newer import invalidates this delayed focus request.
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.authorized, self.importToken == token, !self.importing else { return }
                    self.text.focusBody()
                }
            }
            batchSelection = []
            return
        }
        let result = pendingSelection.removeFirst()
        currentSelection = result
        providerProgress = result.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, _ in
            let normalized: Result<DiaryDocument.Photo, Error>
            if let url { normalized = Result { try autoreleasepool { try DiaryPhotoImport.normalize(url: url) } } }
            else { normalized = .failure(CocoaError(.fileReadUnknown)) }
            Task { @MainActor [weak self] in
                guard let self, self.authorized, self.importToken == token else { return }
                switch normalized {
                case .success(let photo):
                    let totalBytes = self.existingImageBytesAtImport + self.importedPhotos.reduce(0) { $0 + $1.jpeg.count } + photo.jpeg.count
                    if totalBytes > 32 * 1_024 * 1_024 {
                        self.oversizedSelection = true
                        if let selection = self.currentSelection { self.failedSelection.append(selection) }
                    } else { self.importedPhotos.append(photo) }
                case .failure: if let selection = self.currentSelection { self.failedSelection.append(selection) }
                }
                self.currentSelection = nil
                self.importProgress += 1
                self.importNext(token: token)
            }
        }
    }

    func cancelImport() {
        importToken = UUID(); providerProgress?.cancel(); providerProgress = nil
        currentSelection = nil; pendingSelection = []; batchSelection = []; importedPhotos = []; importing = false
    }

    func revoke() {
        guard !revoked else { return }
        _ = flush(atLockBoundary: true)
        cancelImport(); failedSelection = []; task?.cancel()
        revoked = true; text.clear(); error = nil; status = ""
        document = .legacy(id: document.id, title: "", content: "", date: document.updatedAt)
    }
}
