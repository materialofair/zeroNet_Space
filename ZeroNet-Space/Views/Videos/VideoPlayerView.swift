//
//  VideoPlayerView.swift
//  ZeroNet-Space
//
//  视频播放器视图
//  支持全屏播放、控制条、手势操作
//

import AVFoundation
import SwiftUI

struct VideoPlayerView: View {

    // MARK: - Properties

    let video: MediaItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    @State private var player: AVPlayer?
    @State private var showControls = true
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isScrubbing: Bool = false
    @State private var playbackRate: Float = 1.0
    @State private var isMuted: Bool = false
    @State private var timeObserver: Any?
    @State private var errorMessage: String?
    @State private var tempVideoURL: URL?
    @State private var showDeleteConfirmation: Bool = false
    @State private var isDecrypting: Bool = false
    @State private var decryptMessage: String = String(localized: "video.loading")
    @State private var isSharing: Bool = false
    @State private var exportedURLs: [URL] = []
    @State private var showShareSheet = false
    @State private var shareError: String?
    @State private var showShareAlert = false
    @State private var showDeleteErrorAlert = false
    @State private var deleteErrorMessage: String?
    @State private var volume: Float = 1.0
    @State private var isBuffering = false
    @State private var wasPlayingBeforeInterruption = false
    @State private var seekFeedbackIcon: String?
    @State private var seekFeedbackText: String?
    @State private var controlsHideTask: Task<Void, Never>?
    @State private var feedbackTask: Task<Void, Never>?
    @State private var endObserver: NSObjectProtocol?
    @State private var interruptionObserver: NSObjectProtocol?
    @State private var statusObservation: NSKeyValueObservation?
    @State private var loadTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // 视频播放器（自绘控制条；用无控件的容器替代 AVKit VideoPlayer，
            // 避免系统原生控制条与自绘顶/底控制栏重叠）
            if let player = player {
                GeometryReader { proxy in
                    PlayerContainerView(player: player)
                        .ignoresSafeArea()
                        .onAppear {
                            // 视图出现后再开始播放，避免只出声音没有画面
                            if !isPlaying {
                                player.play()
                                isPlaying = true
                            }
                        }
                        .onDisappear {
                            player.pause()
                            isPlaying = false
                        }
                        .onTapGesture {
                            withAnimation {
                                showControls.toggle()
                            }
                        }
                        .highPriorityGesture(
                            // 双击左右区域快退/快进 10 秒（不切换控制条）
                            SpatialTapGesture(count: 2)
                                .onEnded { value in
                                    let backward = value.location.x < proxy.size.width / 2
                                    seek(by: backward ? -10 : 10)
                                    showSeekFeedback(backward: backward)
                                }
                        )
                }
                .ignoresSafeArea()
            } else if let errorMessage = errorMessage {
                // 错误提示
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text(String(localized: "video.error.loadFailed"))
                        .font(.title2)
                        .foregroundColor(.white)

                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // 重试按钮
                    Button {
                        retryLoad()
                    } label: {
                        Label(String(localized: "common.retry"), systemImage: "arrow.clockwise")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            } else {
                // 加载中
                ProgressView()
                    .tint(.white)
            }

            // 缓冲提示（播放中卡顿时显示）
            if isBuffering && isPlaying && player != nil {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.3)
            }

            // 双击快进/快退反馈
            if let icon = seekFeedbackIcon {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 36))
                        .foregroundColor(.white)

                    if let text = seekFeedbackText {
                        Text(text)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.6))
                .cornerRadius(14)
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: seekFeedbackIcon)
            }

            // 顶部/底部控制栏
            VStack {
                topBar
                Spacer()
                if player != nil {
                    bottomBar
                }
            }
            .opacity(showControls ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: showControls)
        }
        .statusBar(hidden: !showControls)
        .confirmationDialog(
            String(localized: "video.delete.confirmTitle"),
            isPresented: $showDeleteConfirmation
        ) {
            Button(String(localized: "common.delete"), role: .destructive) {
                deleteVideo()
            }
        } message: {
            Text(String(localized: "video.delete.confirmMessage"))
        }
        .onAppear {
            // 激活音频会话，保证静音开关打开时视频仍有声音
            AVAudioSession.activateForVideoPlayback()
            setupPlayer()
            registerInterruptionObserver()
        }
        .onDisappear {
            loadTask?.cancel()
            removePlaybackObservers()
            if let player = player, let observer = timeObserver {
                player.removeTimeObserver(observer)
                timeObserver = nil
            }
            player?.pause()
            cleanupTempFile()
            AVAudioSession.deactivateAfterVideoPlayback()
            UIApplication.shared.isIdleTimerDisabled = false
            controlsHideTask?.cancel()
            feedbackTask?.cancel()
        }
        .onChange(of: isPlaying) { _, playing in
            // 播放时禁用自动锁屏，暂停时恢复
            UIApplication.shared.isIdleTimerDisabled = playing
            if playing {
                scheduleControlsAutoHide()
            } else {
                controlsHideTask?.cancel()
                withAnimation {
                    showControls = true
                }
            }
        }
        .onChange(of: showControls) { _, visible in
            if visible {
                scheduleControlsAutoHide()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // `.playback` 类别允许后台出声；退到后台必须暂停，避免声音在后台继续播放
            if newPhase == .background, isPlaying {
                player?.pause()
                isPlaying = false
            }
        }
        .sheet(
            isPresented: $showShareSheet,
            onDismiss: {
                exportedURLs.removeAll()
            }
        ) {
            ShareSheet(items: exportedURLs)
        }
        .alert(String(localized: "export.failed"), isPresented: $showShareAlert) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(shareError ?? String(localized: "common.unknownError"))
        }
        .alert(String(localized: "common.error"), isPresented: $showDeleteErrorAlert) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? String(localized: "common.unknownError"))
        }
        .loadingOverlay(
            isShowing: isDecrypting || isSharing,
            message: isDecrypting ? decryptMessage : String(localized: "video.export.inProgress")
        )
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // 关闭按钮
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }

            Spacer()

            // 标题
            Text(video.fileName)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            // 更多按钮
            Menu {
                Button {
                    shareVideo()
                } label: {
                    Label(String(localized: "video.share"), systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(String(localized: "common.delete"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Methods

    private func setupPlayer() {
        guard let password = authViewModel.sessionPassword else {
            errorMessage = String(localized: "video.error.passwordMissing")
            return
        }

        decryptMessage = String(localized: "video.decrypt.status")
        isDecrypting = true

        // 异步解密并创建播放器（持有 Task 引用，视图消失时可取消）
        loadTask?.cancel()
        loadTask = Task {
            do {
                let storageService = FileStorageService.shared
                let tempURL = try await storageService.createDecryptedTempFileAsync(
                    path: video.encryptedPath,
                    password: password,
                    preferredExtension: video.fileExtension
                )

                // 视图已消失：立即清理解密出的临时文件，避免明文残留
                if Task.isCancelled {
                    try? FileManager.default.removeItem(at: tempURL)
                    return
                }

                // 创建播放器（不立即播放，等视图出现后再播放）
                await MainActor.run {
                    self.tempVideoURL = tempURL
                    let playerItem = AVPlayerItem(url: tempURL)
                    let avPlayer = AVPlayer(playerItem: playerItem)

                    self.player = avPlayer
                    self.isPlaying = false

                    // 播放结束后回到开头并显示重播状态
                    self.endObserver = NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: playerItem,
                        queue: .main
                    ) { _ in
                        self.isPlaying = false
                        self.currentTime = 0
                        self.player?.seek(to: .zero)
                    }

                    // 监听缓冲状态，卡顿时显示加载提示
                    self.statusObservation = avPlayer.observe(
                        \.timeControlStatus, options: [.initial, .new]
                    ) { observedPlayer, _ in
                        let waiting = observedPlayer.timeControlStatus == .waitingToPlayAtSpecifiedRate
                        DispatchQueue.main.async {
                            self.isBuffering = waiting
                        }
                    }

                    // 同步总时长（优先使用播放器的时长，退回到元数据）
                    let assetDuration = playerItem.asset.duration
                    let totalSeconds = CMTimeGetSeconds(assetDuration)
                    if totalSeconds.isFinite && totalSeconds > 0 {
                        self.duration = totalSeconds
                    } else if let metaDuration = video.duration {
                        self.duration = metaDuration
                    }

                    // 添加周期性时间观察者，更新当前播放时间
                    addTimeObserver(to: avPlayer)
                }

                await MainActor.run {
                    isDecrypting = false
                }

            } catch {
                await MainActor.run {
                    errorMessage = String(
                        format: String(localized: "video.error.decryptFailed"),
                        error.localizedDescription)
                    isDecrypting = false
                }
            }
        }
    }

    private func shareVideo() {
        guard !isSharing else { return }
        guard let password = authViewModel.sessionPassword, !password.isEmpty else {
            shareError = String(localized: "video.error.passwordMissing")
            showShareAlert = true
            return
        }

        isSharing = true
        shareError = nil

        ExportService.shared.exportItems([video], password: password) { result in
            switch result {
            case .success(let urls):
                exportedURLs = urls
                showShareSheet = true
            case .failure(let error):
                shareError = error.localizedDescription
                showShareAlert = true
            }

            isSharing = false
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            // 播放控制按钮（快退 / 播放 / 快进）
            HStack(spacing: 40) {
                Button {
                    seek(by: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                Button {
                    togglePlayPause()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 46))
                        .foregroundColor(.white)
                }

                Button {
                    seek(by: 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }

            // 进度条 + 时间
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: {
                            currentTime
                        },
                        set: { newValue in
                            currentTime = newValue
                            guard let player = player else { return }
                            isScrubbing = true
                            controlsHideTask?.cancel()
                            let time = CMTime(seconds: newValue, preferredTimescale: 600)
                            // 拖动过程中宽松容差快速预览，松手后再精确 seek
                            player.seek(
                                to: time,
                                toleranceBefore: .positiveInfinity,
                                toleranceAfter: .positiveInfinity
                            )
                        }
                    ),
                    in: 0...max(duration, 1),
                    onEditingChanged: { editing in
                        if !editing {
                            guard let player = player else { return }
                            let time = CMTime(seconds: currentTime, preferredTimescale: 600)
                            player.seek(
                                to: time,
                                toleranceBefore: .zero,
                                toleranceAfter: .zero
                            ) { _ in
                                isScrubbing = false
                                scheduleControlsAutoHide()
                            }
                        }
                    }
                )

                HStack {
                    Text(formatTime(currentTime))
                    Spacer()
                    Text(formatTime(duration))
                }
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
            }

            // 倍速 + 音量 + 静音控制
            HStack(spacing: 8) {
                // 倍速选择
                HStack(spacing: 8) {
                    speedButton(title: "0.5x", rate: 0.5)
                    speedButton(title: "1x", rate: 1.0)
                    speedButton(title: "1.5x", rate: 1.5)
                    speedButton(title: "2x", rate: 2.0)
                }

                Spacer()

                // 音量调节
                Image(systemName: volumeIconName)
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 18)

                Slider(value: $volume, in: 0...1)
                    .frame(width: 80)
                    .tint(.white)
                    .onChange(of: volume) { _, newValue in
                        player?.volume = newValue
                        scheduleControlsAutoHide()
                    }

                // 静音切换
                Button {
                    toggleMute()
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func cleanupTempFile() {
        guard let tempURL = tempVideoURL else { return }

        try? FileManager.default.removeItem(at: tempURL)
        tempVideoURL = nil
    }

    // MARK: - Playback Helpers

    private func togglePlayPause() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            player.rate = playbackRate
            isPlaying = true
        }
    }

    private func seek(by offset: Double) {
        guard let player = player else { return }
        let newTime = max(0, min(currentTime + offset, duration))
        let time = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: time)
        currentTime = newTime
    }

    private func addTimeObserver(to player: AVPlayer) {
        // 避免重复添加
        if timeObserver != nil { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { time in
            guard !isScrubbing else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite {
                currentTime = seconds
            }
        }
    }

    private func speedButton(title: String, rate: Float) -> some View {
        Button {
            playbackRate = rate
            if isPlaying, let player = player {
                player.rate = playbackRate
            }
        } label: {
            Text(title)
                .font(.caption)
                .fontWeight(rate == playbackRate ? .bold : .regular)
                // 固定宽高，保证所有倍速按钮大小一致
                .frame(width: 40, height: 26)
                .background(
                    Capsule().fill(
                        rate == playbackRate
                            ? Color.white.opacity(0.9)
                            : Color.white.opacity(0.2)
                    )
                )
                .foregroundColor(rate == playbackRate ? .black : .white)
        }
    }

    private func toggleMute() {
        guard let player = player else { return }
        isMuted.toggle()
        // 取消静音时如果音量为 0，恢复到可听见的音量
        if !isMuted && volume <= 0.01 {
            volume = 0.5
            player.volume = 0.5
        }
        player.isMuted = isMuted
    }

    // MARK: - Playback Observers

    /// 注册音频中断监听（来电、闹钟等），中断时暂停、结束后恢复
    private func registerInterruptionObserver() {
        guard interruptionObserver == nil else { return }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let info = notification.userInfo,
                let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: rawType)
            else { return }

            if type == .began {
                wasPlayingBeforeInterruption = isPlaying
                player?.pause()
                isPlaying = false
            } else if type == .ended, wasPlayingBeforeInterruption {
                wasPlayingBeforeInterruption = false
                // 仅当系统明确允许恢复时才自动继续播放
                let rawOptions = (info[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
                let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
                guard options.contains(.shouldResume) else { return }
                player?.play()
                player?.rate = playbackRate
                isPlaying = true
            }
        }
    }

    /// 移除与播放器相关的通知观察者和 KVO
    private func removePlaybackObservers() {
        statusObservation?.invalidate()
        statusObservation = nil

        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
    }

    // MARK: - Controls Auto-Hide

    /// 播放中无操作一段时间后自动隐藏控制条
    private func scheduleControlsAutoHide() {
        controlsHideTask?.cancel()
        guard isPlaying, !isScrubbing else { return }
        controlsHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showControls = false
            }
        }
    }

    /// 显示双击快进/快退的反馈提示，短暂停留后自动消失
    private func showSeekFeedback(backward: Bool) {
        seekFeedbackIcon = backward ? "gobackward.10" : "goforward.10"
        seekFeedbackText = backward ? "-10s" : "+10s"
        feedbackTask?.cancel()
        feedbackTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                seekFeedbackIcon = nil
            }
        }
    }

    /// 音量图标：随静音状态和当前音量变化
    private var volumeIconName: String {
        if isMuted || volume <= 0.01 { return "speaker.slash.fill" }
        return volume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.2.fill"
    }

    // MARK: - Delete Video

    private func deleteVideo() {
        let storage = FileStorageService.shared
        let encryptedPath = video.encryptedPath

        // 先提交数据库删除，成功后再停播放器/删文件（与列表页保持一致），
        // 避免 save 失败时留下指向已删除文件的记录，也让播放器保持可用
        modelContext.delete(video)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deleteErrorMessage = String(
                format: String(localized: "gallery.error.deleteFailed"),
                error.localizedDescription)
            showDeleteErrorAlert = true
            return
        }

        // 停止播放并清理观察者
        if let player = player, let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()

        // 删除加密文件
        do {
            try storage.deleteFile(path: encryptedPath)
        } catch {
            // 记录已删除，文件删除失败只会残留无引用的加密文件
            print("⚠️ 加密视频文件删除失败: \(error)")
        }

        // 清理临时文件并退出播放器
        cleanupTempFile()
        dismiss()
    }

    /// 重新尝试加载视频（解密失败时使用）
    private func retryLoad() {
        cleanupTempFile()
        removePlaybackObservers()
        errorMessage = nil
        player = nil
        timeObserver = nil
        setupPlayer()
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Player Container View

/// 仅承载 AVPlayer 画面、不带任何系统控制条的无控件播放视图
struct PlayerContainerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

final class PlayerUIView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
}

// MARK: - Preview

#Preview {
    let sampleVideo = MediaItem(
        fileName: "sample.mp4",
        fileExtension: "mp4",
        fileSize: 10_240_000,
        type: .video,
        encryptedPath: "/path/to/file"
    )

    VideoPlayerView(video: sampleVideo)
}
