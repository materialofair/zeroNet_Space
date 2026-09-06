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

    struct ShareAudioItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    @ObservedObject private var audio = AudioSessionController.shared
    @State private var showImportView = false
    @State private var isSaving = false
    @State private var isSharing = false
    @State private var saveTask: Task<Void, Never>?
    @State private var shareTask: Task<Void, Never>?
    @State private var shareAudioItem: ShareAudioItem?
    @State private var showVIPRequiredAlert = false
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
    private var busy: Bool { isSaving || isSharing || audio.isRequestingPermission }

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
            ToolbarItem(placement: .navigationBarTrailing) {
                if guest.isOwnerMode {
                    Button {
                        audio.stopPlayback()
                        showImportView = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
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
            if isSaving || isSharing {
                ProgressView(String(localized: isSharing ? "export.preparingShare" : "audio.saving"))
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .sheet(isPresented: $showImportView) {
            ImportButtonsView(onImportComplete: { items in
                print("✅ 导入完成: \(items.count) 个项目")
            })
            .environment(\.modelContext, modelContext)
            .environmentObject(auth)
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
        .alert(
            String(localized: "audio.share.vipRequired.title"),
            isPresented: $showVIPRequiredAlert
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(String(localized: "audio.share.vipRequired.message"))
        }
        .sheet(item: $shareAudioItem) { item in
            ShareSheet(items: [item.url])
                .onDisappear {
                    let parentDir = item.url.deletingLastPathComponent()
                    try? FileManager.default.removeItem(at: parentDir)
                }
        }
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
            if phase == .inactive {
                if !audio.isRecording { audio.pauseForInterruption() }
            }
            if phase == .background {
                if !audio.isRecording {
                    audio.stopPlayback()
                }
            }
            if phase == .active {
                audio.tick()
            }
        }
        .onChange(of: auth.isAuthenticated) { _, authenticated in
            if !authenticated { revokeAccess() }
        }
        .onChange(of: guest.isOwnerMode) { _, owner in
            if !owner { revokeAccess() }
        }
        .onDisappear {
            if !audio.hasRecording {
                leaveAudio()
            } else {
                audio.stopPlayback()
            }
        }
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
                Button {
                    shareAudio(item)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.borderless)
                .disabled(busy || audio.hasRecording)
                .accessibilityLabel(String(localized: "common.share"))
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
            Button {
                shareAudio(item)
            } label: {
                Label(String(localized: "common.share"), systemImage: "square.and.arrow.up")
            }
            Button(String(localized: "audio.rename"), systemImage: "pencil") {
                newName = item.fileName
                renameItem = item
            }
            Button(String(localized: "common.delete"), systemImage: "trash", role: .destructive) { deleteItem = item }
        }
        .swipeActions(edge: .trailing) {
            Button(String(localized: "common.delete"), role: .destructive) { deleteItem = item }
            Button(String(localized: "audio.rename")) { newName = item.fileName; renameItem = item }
                .tint(.blue)
        }
        .swipeActions(edge: .leading) {
            Button {
                shareAudio(item)
            } label: {
                Label(String(localized: "common.share"), systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
        }
        .disabled(busy)
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

    private func shareAudio(_ item: MediaItem) {
        guard canAccess, !busy, let password = auth.sessionPassword else { return }

        // 分享录音前严格检查 VIP 会员权限
        guard AppSettings.shared.isVIP else {
            showVIPRequiredAlert = true
            return
        }

        isSharing = true
        shareTask = Task {
            defer { isSharing = false }
            do {
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
                    "shared_audio_\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let name = item.fileName.hasSuffix(item.fileExtension) ? item.fileName : item.fullFileName
                let shareURL = tempDir.appendingPathComponent(name)
                let sourceURL = FileStorageService.shared.getFileURL(for: item.encryptedPath)
                try EncryptionService.shared.decryptFile(inputURL: sourceURL, to: shareURL, password: password)
                try FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.complete],
                    ofItemAtPath: shareURL.path)

                guard !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: tempDir)
                    return
                }
                shareAudioItem = ShareAudioItem(url: shareURL)
            } catch {
                errorMessage = String(localized: "export.failed")
            }
        }
    }

    private func leaveAudio() {
        audio.stopPlayback()
        if canAccess, audio.hasRecording { saveRecording() }
        else if !isSaving { audio.discardRecording() }
    }

    private func revokeAccess() {
        showImportView = false
        saveTask?.cancel()
        shareTask?.cancel()
        shareAudioItem = nil
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
