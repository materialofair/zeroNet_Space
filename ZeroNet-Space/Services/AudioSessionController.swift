import AVFoundation
internal import Combine
import Foundation

@MainActor
final class AudioSessionController: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var hasRecording = false
    @Published private(set) var isRecording = false
    @Published private(set) var canResume = false
    @Published private(set) var isRequestingPermission = false
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var levels = Array(repeating: Float(0), count: 40)
    @Published private(set) var playingID: UUID?
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var playbackTime: Double = 0
    @Published private(set) var playbackDuration: Double = 0
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private(set) var recordingURL: URL?
    private var playbackURL: URL?
    private var operation: Task<Void, Never>?
    private var generation = UUID()
    private let directory: URL

    init(directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("AudioMemos", isDirectory: true)) {
        self.directory = directory
        super.init()
        // The application has one audio controller. Remove plaintext left by a terminated run.
        do {
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
        } catch {
            errorMessage = String(localized: "audio.error.cleanup")
        }
    }

    func startRecording() {
        guard !hasRecording, !isRequestingPermission else { return }
        stopPlayback()
        isRequestingPermission = true
        let token = generation
        operation = Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            guard !Task.isCancelled, token == generation else { return }
            isRequestingPermission = false
            guard granted else {
                errorMessage = String(localized: "audio.error.permission")
                return
            }
            do {
                try FileManager.default.createDirectory(
                    at: directory, withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.complete])
                let url = directory.appendingPathComponent(UUID().uuidString + ".m4a")
                recordingURL = url
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.record, mode: .default)
                try session.setActive(true)
                let recorder = try AVAudioRecorder(url: url, settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                ])
                self.recorder = recorder
                recorder.delegate = self
                recorder.isMeteringEnabled = true
                guard recorder.prepareToRecord() else { throw ImportError.saveFailed }
                try FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
                guard recorder.record() else { throw ImportError.saveFailed }
                elapsed = 0
                levels = Array(repeating: 0, count: 40)
                hasRecording = true
                isRecording = true
                canResume = true
            } catch {
                discardRecording()
                errorMessage = String(localized: "audio.error.recording")
            }
        }
    }

    func toggleRecording() {
        guard let recorder else { return }
        if isRecording {
            recorder.pause()
            isRecording = false
        } else {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                guard recorder.record() else { throw ImportError.saveFailed }
                isRecording = true
            } catch {
                errorMessage = String(localized: "audio.error.recording")
            }
        }
    }

    func pauseForInterruption() {
        if isRecording {
            recorder?.pause()
            isRecording = false
        }
        player?.pause()
        isPlaying = false
    }

    func finishRecording() -> URL? {
        if let recorder {
            elapsed = recorder.currentTime
            self.recorder = nil
            recorder.stop()
        }
        isRecording = false
        canResume = false
        deactivateSession()
        return recordingURL
    }

    func discardRecording() {
        generation = UUID()
        operation?.cancel()
        isRequestingPermission = false
        recorder?.stop()
        recorder = nil
        if let url = recordingURL { removeTemporaryFile(url) }
        recordingURL = nil
        hasRecording = false
        isRecording = false
        canResume = false
        elapsed = 0
        levels = Array(repeating: 0, count: 40)
        deactivateSession()
    }

    func togglePlayback(item: MediaItem, password: String) {
        guard !hasRecording, !isRequestingPermission else { return }
        if playingID == item.id, let player {
            if player.isPlaying {
                player.pause()
            } else {
                if player.currentTime >= player.duration { player.currentTime = 0 }
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    guard player.play() else { throw ImportError.loadFailed }
                } catch {
                    errorMessage = String(localized: "audio.error.playback")
                }
            }
            isPlaying = player.isPlaying
            return
        }
        stopPlayback()
        playingID = item.id
        isLoading = true
        let token = generation
        let path = item.encryptedPath
        let fileExtension = item.fileExtension
        operation = Task {
            do {
                let url = try await FileStorageService.shared.createDecryptedTempFileAsync(
                    path: path, password: password, preferredExtension: fileExtension)
                guard !Task.isCancelled, token == generation else {
                    removeTemporaryFile(url)
                    return
                }
                playbackURL = url
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
                let player = try AVAudioPlayer(contentsOf: url)
                self.player = player
                guard player.play() else { throw ImportError.loadFailed }
                playbackDuration = player.duration
                isPlaying = true
                isLoading = false
            } catch {
                guard token == generation, !Task.isCancelled else { return }
                stopPlayback()
                errorMessage = String(localized: "audio.error.playback")
            }
        }
    }

    func seek(to time: Double) {
        guard time.isFinite else { return }
        let time = min(max(time, 0), playbackDuration)
        player?.currentTime = time
        playbackTime = time
    }

    func tick() {
        if let recorder, isRecording {
            elapsed = recorder.currentTime
            recorder.updateMeters()
            levels.removeFirst()
            levels.append(pow(10, recorder.averagePower(forChannel: 0) / 40))
        }
        if let player {
            playbackTime = player.currentTime
            isPlaying = player.isPlaying
        }
    }

    func stopPlayback() {
        generation = UUID()
        operation?.cancel()
        operation = nil
        isRequestingPermission = false
        player?.stop()
        player = nil
        if let url = playbackURL { removeTemporaryFile(url) }
        playbackURL = nil
        playingID = nil
        isPlaying = false
        isLoading = false
        playbackTime = 0
        playbackDuration = 0
        if !hasRecording { deactivateSession() }
    }

    func cleanup() {
        stopPlayback()
        discardRecording()
    }

    private func removeTemporaryFile(_ url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            errorMessage = String(localized: "audio.error.cleanup")
        }
    }

    private func deactivateSession() {
        // Failure to relinquish the audio session does not affect persisted content.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder else { return }
            self.isRecording = false
            self.errorMessage = String(localized: "audio.error.recording")
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder else { return }
            self.isRecording = false
            if !flag { self.errorMessage = String(localized: "audio.error.recording") }
        }
    }
}
