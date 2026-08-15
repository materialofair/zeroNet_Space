//
//  MediaDetailView.swift
//  ZeroNet-Space
//
//  媒体详情视图
//  全屏查看照片、播放视频、预览文件
//

import AVKit
import CryptoKit
import PDFKit
import QuickLook
import SwiftUI

struct MediaDetailView: View {

    // MARK: - Properties

    let mediaItem: MediaItem

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var authViewModel: AuthenticationViewModel

    @State private var decryptedData: Data?
    @State private var decryptedImage: UIImage?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation: Bool = false
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero

    // 视频播放器和临时文件管理
    @State private var videoPlayer: AVPlayer?
    @State private var videoTempURL: URL?
    @State private var showFullScreenVideoPlayer = false

    // 文档临时文件管理（用于QuickLook预览）
    @State private var documentTempURL: URL?

    // 分享功能
    @State private var showShareSheet = false
    @State private var exportedURLs: [URL] = []
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showAlert = false

    // MARK: - Services

    private let storageService = FileStorageService.shared
    private let keychainService = KeychainService.shared

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else if let data = decryptedData {
                mediaContentView(data: data)
            } else if mediaItem.type == .video {
                videoContainerView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            String(localized: "gallery.delete.title"), isPresented: $showDeleteConfirmation
        ) {
            Button(String(localized: "common.delete"), role: .destructive) {
                deleteMedia()
            }
        } message: {
            Text(String(localized: "media.delete.confirmation"))
        }
        .task {
            print("⚡️ MediaDetailView.task 开始执行")
            print("⚡️ Task执行环境 - MediaItem ID: \(mediaItem.id)")
            print("⚡️ Task执行环境 - 文件路径: \(mediaItem.encryptedPath)")
            await loadAndDecryptMedia()
            print("⚡️ MediaDetailView.task 执行完成")
        }
        .onAppear {
            print("👀 MediaDetailView appeared - 媒体类型: \(mediaItem.type.rawValue)")
            print("👀 MediaDetailView appeared - 文件名: \(mediaItem.fullFileName)")
            print("👀 MediaDetailView appeared - 加密路径: \(mediaItem.encryptedPath)")
        }
        .fullScreenCover(isPresented: $showFullScreenVideoPlayer) {
            VideoPlayerView(video: mediaItem)
                .environmentObject(authViewModel)
        }
        .safeAreaInset(edge: .top) {
            topTitleBar
        }
        .sheet(
            isPresented: $showShareSheet,
            onDismiss: {
                exportedURLs.removeAll()
            }
        ) {
            ShareSheet(items: exportedURLs)
        }
        .alert(String(localized: "filePreview.alert.title"), isPresented: $showAlert) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            if let error = exportError {
                Text(error)
            }
        }
        .loadingOverlay(
            isShowing: isExporting,
            message: String(localized: "filePreview.exporting")
        )
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)

            Text(String(localized: "media.decrypting"))
                .foregroundColor(.white)
                .font(.subheadline)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text(String(localized: "media.loadFailed"))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
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
    }

    // MARK: - Media Content View

    @ViewBuilder
    private func mediaContentView(data: Data) -> some View {
        VStack(spacing: 0) {
            // 媒体内容
            mediaContent(data: data)

            // 信息栏
            mediaInfoBar
        }
    }

    private var videoContainerView: some View {
        VStack(spacing: 0) {
            videoView()
            mediaInfoBar
        }
    }

    @ViewBuilder
    private func mediaContent(data: Data) -> some View {
        switch mediaItem.type {
        case .photo:
            // 照片已在后台降采样解码为 decryptedImage，避免主线程解码全分辨率大图
            if let image = decryptedImage {
                photoView(image: image)
            }
        case .video:
            videoView()
        case .document:
            documentView(data: data)
        }
    }

    // MARK: - Photo View

    private func photoView(image: UIImage) -> some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(imageScale)
                .offset(imageOffset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            imageScale = value
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                if imageScale < 1 {
                                    imageScale = 1
                                    imageOffset = .zero
                                } else if imageScale > 3 {
                                    imageScale = 3
                                }
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if imageScale > 1 {
                                imageOffset = value.translation
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                if imageScale <= 1 {
                                    imageOffset = .zero
                                }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        if imageScale == 1 {
                            imageScale = 2
                        } else {
                            imageScale = 1
                            imageOffset = .zero
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    // MARK: - Video View

    private func videoView() -> some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let player = videoPlayer {
                    VideoPlayer(player: player)
                        .onDisappear {
                            cleanupVideoPlayer()
                        }
                } else {
                    ProgressView()
                        .tint(.white)
                        .onAppear {
                            if let url = videoTempURL {
                                setupVideoPlayer(url: url)
                            }
                        }
                }
            }

            // 全屏播放按钮
            Button {
                // 暂停当前内嵌播放器，打开全屏播放器
                videoPlayer?.pause()
                showFullScreenVideoPlayer = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                    Text(String(localized: "media.fullscreen"))
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding()
                .disabled(videoPlayer == nil)
            }
        }
    }

    // MARK: - Document View

    private func documentView(data: Data) -> some View {
        let ext = mediaItem.fileExtension.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        return Group {
            switch ext {
            case "pdf":
                pdfDocumentView(data: data)
            case "md":
                markdownDocumentView(data: data)
            case "txt":
                textDocumentView(data: data)
            default:
                genericDocumentQuickLookView(data: data)
            }
        }
    }

    // MARK: - PDF Document View

    private func pdfDocumentView(data: Data) -> some View {
        // PDF阅读器全屏显示，不添加额外的信息栏
        PDFReaderView(data: data, onShare: shareMedia)
            .ignoresSafeArea()
    }

    // MARK: - Markdown Document View

    private func markdownDocumentView(data: Data) -> some View {
        let text = String(data: data, encoding: .utf8) ?? String(localized: "media.text.parseError")
        let attributed: AttributedString? = try? AttributedString(
            markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))

        return ScrollView {
            if let attributed = attributed {
                Text(attributed)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            } else {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Text Document View

    private func textDocumentView(data: Data) -> some View {
        let text = String(data: data, encoding: .utf8) ?? String(localized: "media.text.parseError")

        return ScrollView {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Generic Document View (QuickLook fallback)

    private func genericDocumentQuickLookView(data: Data) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let url = documentTempURL {
                QuickLookPreview(url: url)
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)

                    Text(String(localized: "media.preparing"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .task {
            await prepareDocumentTempFile(data: data)
        }
        .onDisappear {
            cleanupDocumentTempFile()
        }
    }

    // MARK: - Media Info Bar

    private var mediaInfoBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 详细信息
            HStack {
                Label(mediaItem.formattedFileSize, systemImage: "doc")

                if let dimensions = mediaItem.formattedDimensions {
                    Label(dimensions, systemImage: "rectangle")
                }

                if let duration = mediaItem.formattedDuration {
                    Label(duration, systemImage: "clock")
                }

                Spacer()
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))

            // 导入日期
            Text(mediaItem.formattedCreatedDate)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Image(systemName: "trash")
        }
    }

    // MARK: - Private Methods

    /// 重新尝试加载并解密媒体（加载失败时使用）
    private func retryLoad() {
        isLoading = true
        errorMessage = nil
        decryptedData = nil
        Task {
            await loadAndDecryptMedia()
        }
    }

    /// 加载并解密媒体
    private func loadAndDecryptMedia() async {
        print("🔓 开始加载和解密媒体...")
        print("📁 文件类型: \(mediaItem.type.rawValue)")
        print("📄 文件名: \(mediaItem.fullFileName)")
        print("📊 媒体元数据:")
        print("   - 尺寸: \(mediaItem.width ?? 0)×\(mediaItem.height ?? 0)")
        print("   - 时长: \(mediaItem.duration ?? 0)秒")
        print("   - 文件大小: \(mediaItem.formattedFileSize)")
        print(
            "   - 缩略图: \(mediaItem.thumbnailData != nil ? "有(\(mediaItem.thumbnailData!.count) bytes)" : "无")"
        )

        do {
            // 获取用户密码（临时方案）
            guard let password = getSessionPassword() else {
                print("❌ 无法获取密码")
                errorMessage = String(localized: "media.error.noPassword")
                isLoading = false
                return
            }

            print("✅ 密码已获取")

            // 读取加密文件
            print("📂 正在读取加密文件: \(mediaItem.encryptedPath)")

            // 检查文件是否存在（使用FileStorageService的方法，会自动处理相对路径）
            let fileExists = storageService.fileExists(path: mediaItem.encryptedPath)
            print("📁 文件存在性检查: \(fileExists ? "存在" : "不存在")")

            if !fileExists {
                throw NSError(
                    domain: "MediaDetailView", code: 404,
                    userInfo: [
                        NSLocalizedDescriptionKey: "加密文件不存在: \(mediaItem.encryptedPath)"
                    ])
            }

            if mediaItem.type == .video {
                let tempURL = try await storageService.createDecryptedTempFileAsync(
                    path: mediaItem.encryptedPath,
                    password: password,
                    preferredExtension: mediaItem.fileExtension
                )

                await MainActor.run {
                    self.isLoading = false
                    self.setupVideoPlayer(url: tempURL)
                    print("🎬 视频临时文件已就绪: \(tempURL.lastPathComponent)")
                }
                return
            }

            let data = try await storageService.loadDecryptedDataAsync(
                path: mediaItem.encryptedPath,
                password: password,
                preferredExtension: mediaItem.fileExtension
            )

            // 照片在后台降采样解码，避免主线程解码 12MP+ 大图造成卡顿
            if mediaItem.type == .photo {
                let image = await ThumbnailImageLoader.shared.image(
                    for: mediaItem.id.uuidString,
                    data: data,
                    maxPixelSize: AppConstants.previewImageMaxPixelSize
                )

                await MainActor.run {
                    guard let image = image else {
                        self.errorMessage = MediaLoaderError.invalidImageData.localizedDescription
                        self.isLoading = false
                        return
                    }
                    self.decryptedImage = image
                    self.decryptedData = data
                    self.isLoading = false
                    print("✅ 图片已降采样解码: \(Int(image.size.width * image.scale))x\(Int(image.size.height * image.scale))")
                }
                return
            }

            await MainActor.run {
                self.decryptedData = data
                self.isLoading = false
                print("✅ 媒体数据已加载到视图")
            }

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("❌ 媒体加载失败: \(error)")
            print("❌ 错误详情: \(error.localizedDescription)")
        }
    }

    /// 分享媒体
    private func shareMedia() {
        guard !isExporting else { return }
        guard let password = authViewModel.sessionPassword, !password.isEmpty else {
            exportError = String(localized: "filePreview.error.noPassword")
            showAlert = true
            return
        }

        isExporting = true
        exportError = nil

        ExportService.shared.exportItems([mediaItem], password: password) { result in
            switch result {
            case .success(let urls):
                exportedURLs = urls
                showShareSheet = true
            case .failure(let error):
                exportError = error.localizedDescription
                showAlert = true
            }
            isExporting = false
        }
    }

    /// 删除媒体
    private func deleteMedia() {
        Task {
            do {
                // 如果是视频，先清理播放器资源
                if mediaItem.type == .video {
                    await MainActor.run {
                        cleanupVideoPlayer()
                    }
                    // 等待资源释放
                    try await Task.sleep(nanoseconds: 100_000_000)  // 0.1秒
                }

                // 先提交数据库删除，成功后再删文件，
                // 避免 save 失败时留下指向已删除文件的记录
                let encryptedPath = mediaItem.encryptedPath
                modelContext.delete(mediaItem)
                try modelContext.save()

                do {
                    try storageService.deleteFile(path: encryptedPath)
                } catch {
                    print("⚠️ 加密文件删除失败: \(error)")
                }

                // 返回上一页
                await MainActor.run {
                    dismiss()
                }

                print("🗑️ 媒体已删除")

            } catch {
                await MainActor.run {
                    modelContext.rollback()
                    errorMessage = "删除失败: \(error.localizedDescription)"
                }
                print("❌ 删除失败: \(error)")
            }
        }
    }

    /// 设置视频播放器
    private func setupVideoPlayer(url: URL) {
        videoTempURL = url
        videoPlayer = AVPlayer(url: url)
        // 激活音频会话，保证静音开关打开时内嵌预览也有声音
        AVAudioSession.activateForVideoPlayback()
        print("▶️ 视频播放器已创建")
    }

    /// 清理视频播放器资源
    private func cleanupVideoPlayer() {
        // 停止播放
        videoPlayer?.pause()
        videoPlayer?.replaceCurrentItem(with: nil)
        videoPlayer = nil
        AVAudioSession.deactivateAfterVideoPlayback()

        // 删除临时文件
        if let tempURL = videoTempURL {
            try? FileManager.default.removeItem(at: tempURL)
            print("🧹 临时视频文件已清理: \(tempURL.lastPathComponent)")
            videoTempURL = nil
        }
    }

    /// 清理文档临时文件
    private func cleanupDocumentTempFile() {
        if let tempURL = documentTempURL {
            try? FileManager.default.removeItem(at: tempURL)
            print("🧹 临时文档文件已清理: \(tempURL.lastPathComponent)")
            documentTempURL = nil
        }
    }

    /// 保存临时文件（用于文档预览）
    private func prepareDocumentTempFile(data: Data) async {
        // 避免重复创建
        if documentTempURL != nil {
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + mediaItem.fileExtension
        let tempURL = tempDir.appendingPathComponent(fileName)

        do {
            // 明文文档临时文件使用最高文件保护级别，防止锁屏后被读取
            try data.write(to: tempURL, options: [.atomic, .completeFileProtection])
            await MainActor.run {
                documentTempURL = tempURL
            }
            print("📄 文档临时文件已创建: \(tempURL.lastPathComponent)")
        } catch {
            print("❌ 文档临时文件创建失败: \(error)")
        }
    }

    /// 获取会话密码
    private func getSessionPassword() -> String? {
        return authViewModel.sessionPassword
    }

    // MARK: - Top Title Bar

    private var topTitleBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }

                Text(mediaItem.fullFileName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // 分享按钮
                Button {
                    shareMedia()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.85), Color.black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - QuickLook Preview

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MediaDetailView(
            mediaItem: MediaItem(
                fileName: "Sample",
                fileExtension: ".jpg",
                fileSize: 1_024_000,
                type: .photo,
                encryptedPath: "/path/to/file",
                width: 1920,
                height: 1080
            )
        )
    }
    .modelContainer(for: MediaItem.self, inMemory: true)
}
