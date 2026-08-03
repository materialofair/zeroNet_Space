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

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // 视频播放器（自绘控制条；用无控件的容器替代 AVKit VideoPlayer，
            // 避免系统原生控制条与自绘顶/底控制栏重叠）
            if let player = player {
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
            setupPlayer()
        }
        .onDisappear {
            if let player = player, let observer = timeObserver {
                player.removeTimeObserver(observer)
                timeObserver = nil
            }
            player?.pause()
            cleanupTempFile()
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

        // 异步解密并创建播放器
        Task {
            do {
                let storageService = FileStorageService.shared
                let tempURL = try storageService.createDecryptedTempFile(
                    path: video.encryptedPath,
                    password: password,
                    preferredExtension: video.fileExtension
                )

                // 创建播放器（不立即播放，等视图出现后再播放）
                await MainActor.run {
                    self.tempVideoURL = tempURL
                    let playerItem = AVPlayerItem(url: tempURL)
                    let avPlayer = AVPlayer(playerItem: playerItem)

                    self.player = avPlayer
                    self.isPlaying = false

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
                            let time = CMTime(seconds: newValue, preferredTimescale: 600)
                            player.seek(
                                to: time,
                                toleranceBefore: .zero,
                                toleranceAfter: .zero
                            ) { _ in
                                isScrubbing = false
                            }
                        }
                    ),
                    in: 0...max(duration, 1),
                    step: 1
                )

                HStack {
                    Text(formatTime(currentTime))
                    Spacer()
                    Text(formatTime(duration))
                }
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
            }

            // 倍速 + 静音控制
            HStack(spacing: 20) {
                // 倍速选择
                HStack(spacing: 8) {
                    speedButton(title: "0.5x", rate: 0.5)
                    speedButton(title: "1x", rate: 1.0)
                    speedButton(title: "1.5x", rate: 1.5)
                    speedButton(title: "2x", rate: 2.0)
                }

                Spacer()

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
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
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
        player.isMuted = isMuted
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
