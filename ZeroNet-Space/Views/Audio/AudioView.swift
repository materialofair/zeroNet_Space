import AVFoundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AudioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var auth: AuthenticationViewModel
    @EnvironmentObject private var guest: GuestModeManager
    @Query(filter: #Predicate<MediaItem> {
        $0.typeRawValue == "audio" || $0.typeRawValue == "document"
    }, sort: \MediaItem.createdAt, order: .reverse)
    private var candidates: [MediaItem]

    @StateObject private var audio = AudioSessionController()
    @State private var showImporter = false
    @State private var isImporting = false
    @State private var isSaving = false
    @State private var importTask: Task<Void, Never>?
    @State private var saveTask: Task<Void, Never>?
    @State private var renameItem: MediaItem?
    @State private var newName = ""
    @State private var deleteItem: MediaItem?
    @State private var confirmDiscard = false
    @State private var errorMessage: String?
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var items: [MediaItem] {
        guest.isOwnerMode ? candidates.filter { $0.type == .audio } : []
    }

    private var canAccess: Bool { auth.isAuthenticated && guest.isOwnerMode }
    private var busy: Bool { isImporting || isSaving || audio.isRequestingPermission }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "audio.empty.title"), systemImage: "waveform")
                } description: {
                    Text(String(localized: "audio.empty.message"))
                }
            } else {
                List(items) { item in
                    audioRow(item)
                }
                .listStyle(.plain)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if guest.isOwnerMode {
                    Button {
                        audio.stopPlayback()
                        showImporter = true
                    } label: {
                        Label(String(localized: "audio.import"), systemImage: "square.and.arrow.down")
                    }
                    .disabled(busy || audio.hasRecording)
                    .accessibilityIdentifier("audio.import")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if guest.isOwnerMode { recordingPanel }
        }
        .overlay {
            if isImporting || isSaving {
                ProgressView(String(localized: "audio.saving"))
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): importFiles(urls)
            case .failure: errorMessage = String(localized: "audio.error.import")
            }
        }
        .alert(String(localized: "audio.rename"), isPresented: Binding(
            get: { renameItem != nil }, set: { if !$0 { renameItem = nil } })
        ) {
            TextField(String(localized: "audio.name"), text: $newName)
            Button(String(localized: "common.save")) { rename() }
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(String(localized: "common.cancel"), role: .cancel) {}
        }
        .alert(String(localized: "audio.delete.title"), isPresented: Binding(
            get: { deleteItem != nil }, set: { if !$0 { deleteItem = nil } }), presenting: deleteItem
        ) { item in
            Button(String(localized: "common.delete"), role: .destructive) { delete(item) }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: { _ in Text(String(localized: "audio.delete.message")) }
        .confirmationDialog(String(localized: "audio.discard.title"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(String(localized: "audio.discard"), role: .destructive) { audio.discardRecording() }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        }
        .alert(String(localized: "common.error"), isPresented: Binding(
            get: { errorMessage != nil || audio.errorMessage != nil },
            set: { if !$0 { errorMessage = nil; audio.errorMessage = nil } })
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {
                errorMessage = nil
                audio.errorMessage = nil
            }
        } message: { Text(errorMessage ?? audio.errorMessage ?? "") }
        .onReceive(timer) { _ in audio.tick() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            if notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt == AVAudioSession.InterruptionType.began.rawValue {
                audio.pauseForInterruption()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
            if notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                audio.pauseForInterruption()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive { audio.pauseForInterruption() }
            if phase == .background { leaveAudio() }
        }
        .onChange(of: auth.isAuthenticated) { _, authenticated in
            if !authenticated { revokeAccess() }
        }
        .onChange(of: guest.isOwnerMode) { _, owner in
            if !owner { revokeAccess() }
        }
        .onDisappear { leaveAudio() }
    }

    private func audioRow(_ item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Button {
                    guard canAccess, let password = auth.sessionPassword else { return }
                    audio.togglePlayback(item: item, password: password)
                } label: {
                    Image(systemName: audio.playingID == item.id && audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .disabled(busy || audio.hasRecording)
                .accessibilityLabel(String(localized: audio.playingID == item.id && audio.isPlaying ? "audio.pause" : "audio.play"))
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.fileName).font(.headline).lineLimit(2)
                    Text(item.createdAt, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.formattedDuration ?? item.formattedFileSize)
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if audio.playingID == item.id {
                if audio.isLoading {
                    ProgressView()
                } else {
                    Slider(value: Binding(get: { audio.playbackTime }, set: { audio.seek(to: $0) }),
                           in: 0...max(audio.playbackDuration, 0.1))
                        .tint(.red)
                        .accessibilityLabel(String(localized: "audio.progress"))
                    HStack {
                        Text(formatTime(audio.playbackTime))
                        Spacer()
                        Text(formatTime(audio.playbackDuration))
                    }
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button(String(localized: "audio.rename"), systemImage: "pencil") {
                newName = item.fileName
                renameItem = item
            }
            Button(String(localized: "common.delete"), systemImage: "trash", role: .destructive) { deleteItem = item }
        }
        .swipeActions {
            Button(String(localized: "common.delete"), role: .destructive) { deleteItem = item }
            Button(String(localized: "audio.rename")) { newName = item.fileName; renameItem = item }
                .tint(.blue)
        }
        .disabled(isImporting || isSaving)
    }

    private var recordingPanel: some View {
        VStack(spacing: 14) {
            if audio.hasRecording {
                HStack(spacing: 3) {
                    ForEach(audio.levels.indices, id: \.self) { index in
                        Capsule().fill(.red.opacity(audio.isRecording ? 1 : 0.4))
                            .frame(height: max(3, CGFloat(audio.levels[index]) * 48))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 48)
                .accessibilityHidden(true)
                Text(formatTime(audio.elapsed)).font(.largeTitle.monospacedDigit())
                Text(String(localized: audio.isRecording ? "audio.recording" : "audio.paused"))
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(String(localized: "common.cancel")) { confirmDiscard = true }
                    Spacer()
                    Button { audio.toggleRecording() } label: {
                        Label(String(localized: audio.isRecording ? "audio.pause" : "audio.resume"),
                              systemImage: audio.isRecording ? "pause.fill" : "mic.fill")
                    }
                    .disabled(!audio.canResume)
                    Spacer()
                    Button(String(localized: "common.save")) { saveRecording() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("audio.save")
                }
            } else {
                Button {
                    guard canAccess, hasCapacity(for: 1) else { return }
                    audio.startRecording()
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().stroke(.red.opacity(0.3), lineWidth: 3).frame(width: 68, height: 68)
                            Circle().fill(.red).frame(width: 56, height: 56)
                            Image(systemName: "mic.fill").foregroundStyle(.white).font(.title2)
                        }
                        Text(String(localized: "audio.record")).font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("audio.record")
            }
            Text(String(localized: "audio.localOnly"))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .background(.bar)
        .disabled(busy)
    }

    private func hasCapacity(for count: Int) -> Bool {
        guard !AppSettings.shared.hasUnlockedUnlimited else { return true }
        do {
            let current = try modelContext.fetchCount(FetchDescriptor<MediaItem>())
            guard current + count <= AppConstants.freeImportLimit else {
                errorMessage = String(localized: "iap.limitExceeded.message")
                return false
            }
            return true
        } catch {
            errorMessage = String(localized: "audio.error.save")
            return false
        }
    }

    private func persist(_ item: MediaItem) throws {
        guard canAccess, !Task.isCancelled else {
            try? FileStorageService.shared.deleteFile(path: item.encryptedPath)
            throw CancellationError()
        }
        modelContext.insert(item)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            try? FileStorageService.shared.deleteFile(path: item.encryptedPath)
            throw error
        }
    }

    private func importFiles(_ urls: [URL]) {
        guard canAccess, !busy, !audio.hasRecording, !urls.isEmpty,
            let password = auth.sessionPassword, hasCapacity(for: urls.count)
        else { return }
        isImporting = true
        importTask = Task {
            defer { isImporting = false }
            var failed = 0
            for url in urls {
                guard !Task.isCancelled, canAccess else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    let item = try await AudioImportService.importFile(url: url, password: password)
                    try persist(item)
                } catch is CancellationError { return }
                catch { failed += 1 }
            }
            if failed > 0 {
                errorMessage = String(format: String(localized: "audio.error.importCount"), failed, urls.count)
            }
        }
    }

    private func saveRecording() {
        guard !isSaving, canAccess, let password = auth.sessionPassword,
            let url = audio.finishRecording()
        else { return }
        guard hasCapacity(for: 1) else { return }
        isSaving = true
        // Allow a recording already in progress to finish encrypting when entering the background.
        let backgroundID = UIApplication.shared.beginBackgroundTask(withName: "Save audio memo") {
            saveTask?.cancel()
        }
        saveTask = Task {
            defer {
                isSaving = false
                if backgroundID != .invalid { UIApplication.shared.endBackgroundTask(backgroundID) }
            }
            do {
                let item = try await AudioImportService.importFile(url: url, password: password)
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
                item.fileName = String(localized: "audio.newRecording") + " " + formatter.string(from: Date())
                try persist(item)
                audio.discardRecording()
            } catch is CancellationError {
                audio.discardRecording()
            } catch {
                errorMessage = String(localized: "audio.error.save")
                if !canAccess { audio.discardRecording() }
            }
        }
    }

    private func leaveAudio() {
        audio.stopPlayback()
        importTask?.cancel()
        if canAccess, audio.hasRecording { saveRecording() }
        else if !isSaving { audio.discardRecording() }
    }

    private func revokeAccess() {
        showImporter = false
        importTask?.cancel()
        saveTask?.cancel()
        audio.stopPlayback()
        if !isSaving { audio.discardRecording() }
    }

    private func rename() {
        guard canAccess, let item = renameItem else { return }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 200, !name.contains("/"), !name.contains("\\") else {
            errorMessage = String(localized: "audio.error.name")
            return
        }
        item.fileName = name
        item.touch()
        do { try modelContext.save() }
        catch { modelContext.rollback(); errorMessage = String(localized: "audio.error.save") }
    }

    private func delete(_ item: MediaItem) {
        guard canAccess else { return }
        let path = item.encryptedPath
        let itemID = item.id
        modelContext.delete(item)
        do { try modelContext.save() }
        catch {
            modelContext.rollback()
            errorMessage = String(localized: "audio.error.save")
            return
        }
        if audio.playingID == itemID { audio.stopPlayback() }
        do { try FileStorageService.shared.deleteFile(path: path) }
        catch { errorMessage = String(localized: "audio.error.deleteFile") }
    }

    private func formatTime(_ time: Double) -> String {
        let seconds = time.isFinite ? Int(max(0, time)) : 0
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
