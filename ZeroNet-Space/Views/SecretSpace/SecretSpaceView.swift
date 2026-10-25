import SwiftData
import SwiftUI

struct SecretSpaceView: View {
    @Environment(\.vaultUsesSidebar) private var usesSidebar
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var guest: GuestModeManager
    @EnvironmentObject private var authentication: AuthenticationViewModel
    @Query(sort: \SecretNote.modifiedAt, order: .reverse) private var notes: [SecretNote]
    @State private var destination: DiaryDestination?
    @State private var recoveries: [DiaryDocument] = []
    @State private var error: String?
    @State private var loadTask: Task<Void, Never>?
    @State private var loading = false

    private struct DiaryDestination: Identifiable, Hashable {
        static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
        let document: DiaryDocument
        var editing = false
        var legacy = false
        var legacyDraft = false
        var expectedModifiedAt: Date?
        var sourceRecoveryID: UUID?
        var id: UUID { document.recoveryID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !guest.isOwnerMode || (notes.isEmpty && recoveries.isEmpty) {
                    VStack(spacing: 16) {
                        Image(systemName: "note.text").font(.system(size: 56)).foregroundStyle(.secondary)
                        Text(String(localized: "secretSpace.empty.title")).font(.title3)
                        Text(String(localized: "secretSpace.empty.subtitle")).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        if guest.isOwnerMode { Button(String(localized: "note.new")) { create() }.buttonStyle(.borderedProminent) }
                    }.padding()
                } else {
                    List {
                        if !recoveries.isEmpty {
                            Section(String(localized: "diary.recovered")) {
                                ForEach(recoveries, id: \.recoveryID) { document in
                                    Button { destination = .init(document: document, editing: true,
                                        expectedModifiedAt: document.baseModifiedAt, sourceRecoveryID: document.recoveryID) } label: {
                                        VStack(alignment: .leading) {
                                            Text(document.title.isEmpty ? String(localized: "secretNote.defaultTitle") : document.title)
                                            Text(String(localized: "diary.recoveryHint")).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        ForEach(notes.sorted { left, right in
                            if left.isFavorite != right.isFavorite { return left.isFavorite }
                            return left.modifiedAt > right.modifiedAt
                        }) { note in
                            Button { open(note) } label: { DiaryNoteRow(note: note) }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { delete(note) } label: {
                                        Label(String(localized: "common.delete"), systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button { pin(note) } label: {
                                        Label(String(localized: note.isFavorite ? "secretSpace.unpin" : "secretSpace.pin"), systemImage: "pin")
                                    }.tint(.orange)
                                }
                        }
                    }.listStyle(.insetGrouped)
                }
            }
            .overlay { if loading { ProgressView().padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
            .toolbar(usesSidebar ? .hidden : .visible, for: .tabBar)
            .navigationTitle(String(localized: "secretSpace.title"))
            .toolbar {
                if guest.isOwnerMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { create() } label: { Image(systemName: "plus") }
                            .accessibilityLabel(String(localized: "note.new"))
                            .accessibilityIdentifier("diary.new")
                    }
                }
            }
            .navigationDestination(item: $destination) { item in
                NoteEditorView(document: item.document, editing: item.editing, legacy: item.legacy, legacyDraft: item.legacyDraft, expectedModifiedAt: item.expectedModifiedAt,
                               sourceRecoveryID: item.sourceRecoveryID)
            }
            .alert(String(localized: "common.error"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button(String(localized: "common.ok")) { error = nil }
            } message: { Text(error ?? "") }
        }
        .task(id: notes.map { "\($0.id)-\($0.modifiedAt.timeIntervalSince1970)" }.joined()) { await loadRecoveries() }
        .onChange(of: guest.currentMode) { _, mode in
            if mode != .owner { loadTask?.cancel(); loading = false; destination = nil; recoveries = []; error = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vaultWillLock)) { _ in
            loadTask?.cancel(); loading = false; destination = nil; recoveries = []; error = nil
        }
    }

    private func create() {
        guard guest.isOwnerMode, authentication.isAuthenticated else { return }
        let draft = SecretNoteDraftManager.shared.loadDraft(ownerAuthenticated: true)
        destination = .init(document: .legacy(id: UUID(), title: draft?.title ?? "", content: draft?.content ?? "", date: Date()),
                            editing: true, legacyDraft: draft != nil)
    }

    private func open(_ note: SecretNote) {
        guard guest.isOwnerMode, let password = authentication.sessionPassword else { return }
        let generation = authentication.presentationGeneration
        let id = note.id, title = note.title, content = note.content, date = note.createdAt, modified = note.modifiedAt, cipher = note.encryptedDiary
        loading = true; loadTask?.cancel()
        loadTask = Task { @MainActor in
            do {
                let document = try await Task.detached(priority: .userInitiated) {
                    if let cipher {
                        let document = try DiaryStorage.shared.decrypt(cipher, password: password)
                        guard document.id == id else { throw CocoaError(.coderReadCorrupt) }
                        return document
                    }
                    var document = DiaryDocument.legacy(id: id, title: title, content: content, date: date)
                    document.updatedAt = modified
                    return document
                }.value
                guard !Task.isCancelled, authentication.canPresentSensitiveResult(generation) else { return }
                loading = false
                destination = .init(document: document, legacy: cipher == nil, expectedModifiedAt: modified)
            } catch {
                guard !Task.isCancelled, authentication.canPresentSensitiveResult(generation) else { return }
                loading = false; self.error = String(localized: "diary.openFailed")
            }
        }
    }

    private func loadRecoveries() async {
        guard guest.isOwnerMode, let password = authentication.sessionPassword else { recoveries = []; return }
        let generation = authentication.presentationGeneration
        do {
            let scan = try await Task.detached(priority: .utility) { try DiaryStorage.shared.scanRecoveries(password: password) }.value
            guard !Task.isCancelled, authentication.canPresentSensitiveResult(generation) else { return }
            var committed: [UUID: Data] = [:]
            for document in scan.documents {
                if let note = notes.first(where: { $0.id == document.id }), let cipher = note.encryptedDiary { committed[document.id] = cipher }
            }
            let filtered = await Task.detached(priority: .utility) {
                scan.documents.filter { document in
                    guard let cipher = committed[document.id],
                          let saved = try? DiaryStorage.shared.decrypt(cipher, password: password) else { return true }
                    return saved.recoveryID != document.recoveryID || saved.updatedAt != document.updatedAt
                }
            }.value
            guard !Task.isCancelled, authentication.canPresentSensitiveResult(generation) else { return }
            recoveries = filtered.sorted { $0.updatedAt > $1.updatedAt }
            if scan.unreadableCount > 0 { self.error = String(localized: "diary.recoveryFailed") }
        } catch {
            guard !Task.isCancelled, authentication.canPresentSensitiveResult(generation) else { return }
            self.error = String(localized: "diary.recoveryFailed")
        }
    }

    private func delete(_ note: SecretNote) {
        guard guest.isOwnerMode else { return }
        do {
            let cipher = note.encryptedDiary
            context.delete(note); try context.save()
            if let cipher, let password = authentication.sessionPassword,
               let saved = try? DiaryStorage.shared.decrypt(cipher, password: password) {
                try DiaryStorage.shared.removeRecovery(saved.recoveryID)
            }
            // A different window's unsaved recovery remains a separate draft, never silently deleted.
        } catch { context.rollback(); self.error = String(localized: "diary.deleteFailed") }
    }
    private func pin(_ note: SecretNote) {
        guard guest.isOwnerMode else { return }
        note.isFavorite.toggle()
        do { try context.save() } catch { context.rollback(); self.error = String(localized: "diary.saveFailed.message") }
    }
}

private struct DiaryNoteRow: View {
    let note: SecretNote
    @EnvironmentObject private var authentication: AuthenticationViewModel
    @State private var title = ""
    @State private var preview = ""
    @State private var photoCount = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.isEmpty ? String(localized: "secretNote.defaultTitle") : title).font(.headline).lineLimit(1)
                if note.isFavorite { Image(systemName: "pin.fill").foregroundStyle(.orange).font(.caption) }
            }
            if !preview.isEmpty { Text(preview).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
            HStack {
                Text(note.createdAt, format: .dateTime.year().month().day()).font(.caption).foregroundStyle(.secondary)
                if photoCount > 0 { Label("\(photoCount)", systemImage: "photo").font(.caption).foregroundStyle(.secondary) }
            }
        }.padding(.vertical, 6)
        .task(id: note.modifiedAt) {
            guard let password = authentication.sessionPassword else { return }
            let generation = authentication.presentationGeneration
            if let cipher = note.encryptedDiary {
                do {
                    let document = try await Task.detached(priority: .utility) { try DiaryStorage.shared.decrypt(cipher, password: password) }.value
                    guard !Task.isCancelled, authentication.canPresentSensitiveResult(generation) else { return }
                    title = document.title; preview = String(document.plainText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100)); photoCount = document.photoCount
                } catch {
                    guard authentication.canPresentSensitiveResult(generation) else { return }
                    title = String(localized: "diary.openFailed"); preview = ""; photoCount = 0
                }
            } else { title = note.title; preview = note.preview }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vaultWillLock)) { _ in title = ""; preview = ""; photoCount = 0 }
    }
}
