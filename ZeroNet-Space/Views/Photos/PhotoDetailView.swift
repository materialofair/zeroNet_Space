//
//  PhotoDetailView.swift
//  ZeroNet-Space
//
//  相片详细预览视图
//  支持缩放、滑动切换、手势交互
//

import SwiftUI

struct PhotoDetailView: View {

    // MARK: - Properties

    let photo: MediaItem

    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // 本地副本：删除成功后先从数组移除，避免 dismiss 动画期间渲染已删除的对象
    @State private var photos: [MediaItem]
    @State private var currentIndex: Int
    @State private var showControls = true
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var isExporting = false
    @State private var exportedURLs: [URL] = []
    @State private var showShareSheet = false
    @State private var exportError: String?
    @State private var showExportError = false

    // MARK: - Initialization

    init(photo: MediaItem, allPhotos: [MediaItem]) {
        self.photo = photo
        _photos = State(initialValue: allPhotos)

        // 找到当前图片的索引
        if let index = allPhotos.firstIndex(where: { $0.id == photo.id }) {
            _currentIndex = State(initialValue: index)
        } else {
            _currentIndex = State(initialValue: 0)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 黑色背景
            Color.black
                .ignoresSafeArea()

            // 图片浏览器
            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    ZoomableImageView(photo: photo)
                        .environmentObject(authViewModel)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // 顶部控制栏
            VStack {
                topBar
                Spacer()
            }
            .opacity(showControls ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: showControls)

            // 底部信息栏
            if let current = currentPhoto {
                VStack {
                    Spacer()
                    bottomBar(for: current)
                }
                .opacity(showControls ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: showControls)
            }
        }
        .statusBar(hidden: !showControls)
        .onTapGesture {
            withAnimation {
                showControls.toggle()
            }
        }
        .alert(String(localized: "photo.delete.confirmTitle"), isPresented: $showDeleteAlert) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.delete"), role: .destructive) {
                Task {
                    await deletePhoto()
                }
            }
        } message: {
            Text(String(localized: "photo.delete.confirmMessage"))
        }
        .alert(String(localized: "export.failed"), isPresented: $showExportError) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(exportError ?? String(localized: "common.unknownError"))
        }
        .sheet(
            isPresented: $showShareSheet,
            onDismiss: {
                exportedURLs.removeAll()
            }
        ) {
            ShareSheet(items: exportedURLs)
        }
        .loadingOverlay(
            isShowing: isDeleting || isExporting,
            message: isDeleting
                ? String(localized: "photo.deleting") : String(localized: "photo.decrypting")
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

            // 操作按钮
            HStack(spacing: 16) {
                // 分享按钮
                Button {
                    sharePhoto()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(isExporting ? .gray.opacity(0.6) : .white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .disabled(isExporting)

                // 删除按钮
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Circle())
                }
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

    // MARK: - Bottom Bar

    private func bottomBar(for photo: MediaItem) -> some View {
        VStack(spacing: 12) {
            // 文件信息
            VStack(spacing: 4) {
                Text(photo.fileName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 16) {
                    // 文件大小
                    Label(
                        formatFileSize(photo.fileSize),
                        systemImage: "doc"
                    )

                    // 创建日期
                    Label(
                        formatDate(photo.createdAt),
                        systemImage: "calendar"
                    )
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            }

            // 页码指示器
            if photos.count > 1 {
                Text("\(currentIndex + 1) / \(photos.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Computed Properties

    private var currentPhoto: MediaItem? {
        guard photos.indices.contains(currentIndex) else {
            return photos.first
        }
        return photos[currentIndex]
    }

    // MARK: - Methods

    private func sharePhoto() {
        guard !isExporting else { return }
        guard let item = currentPhoto else { return }

        guard let password = authViewModel.sessionPassword, !password.isEmpty else {
            exportError = String(localized: "photo.error.noPassword")
            showExportError = true
            return
        }

        isExporting = true

        ExportService.shared.exportItems([item], password: password) { result in
            switch result {
            case .success(let urls):
                exportedURLs = urls
                showShareSheet = true
            case .failure(let error):
                exportError = error.localizedDescription
                showExportError = true
            }

            isExporting = false
        }
    }

    private func deletePhoto() async {
        guard let photoToDelete = currentPhoto else { return }
        isDeleting = true

        let encryptedPath = photoToDelete.encryptedPath

        // 先提交数据库删除，成功后再关页面、删文件；
        // 失败时留在页面上提示，而不是无声地 dismiss
        modelContext.delete(photoToDelete)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            isDeleting = false
            exportError = String(
                format: String(localized: "gallery.error.deleteFailed"),
                error.localizedDescription)
            showExportError = true
            return
        }

        // 从本地数组移除，避免 dismiss 动画期间渲染已删除的对象
        if let index = photos.firstIndex(where: { $0.id == photoToDelete.id }) {
            photos.remove(at: index)
            if currentIndex >= photos.count {
                currentIndex = max(photos.count - 1, 0)
            }
        }

        do {
            try FileStorageService.shared.deleteFile(path: encryptedPath)
        } catch {
            // 记录已删除，文件删除失败只会残留无引用的加密文件
            print("⚠️ 加密文件删除失败: \(error)")
        }

        isDeleting = false
        dismiss()
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Zoomable Image View

struct ZoomableImageView: View {
    let photo: MediaItem

    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadError: String?
    // 缩放/平移状态归每页私有，避免翻页时把上一张的缩放带到下一张
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = loadedImage {
                    // 显示加载的图片
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if isLoading {
                    // 加载中
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else if let error = loadError {
                    // 加载失败
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text(String(localized: "media.loadFailed"))
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    // 初始占位
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 80))
                                .foregroundColor(.gray)
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        scale *= delta

                        // 限制缩放范围
                        scale = min(max(scale, 1.0), 5.0)
                    }
                    .onEnded { _ in
                        lastScale = 1.0

                        // 如果缩放小于1，重置
                        if scale < 1.0 {
                            withAnimation(.spring()) {
                                scale = 1.0
                                offset = .zero
                            }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if scale > 1.0 {
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                // 双击缩放
                withAnimation(.spring()) {
                    if scale > 1.0 {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.0
                    }
                }
            }
            .task {
                await loadImage()
            }
        }
    }

    private func loadImage() async {
        isLoading = true
        loadError = nil

        do {
            let image = try await MediaLoaderService.shared.loadImage(
                from: photo,
                password: authViewModel.sessionPassword ?? ""
            )
            await MainActor.run {
                self.loadedImage = image
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let samplePhoto = MediaItem(
        fileName: "sample.jpg",
        fileExtension: "jpg",
        fileSize: 1_024_000,
        type: .photo,
        encryptedPath: "/path/to/file"
    )

    return PhotoDetailView(photo: samplePhoto, allPhotos: [samplePhoto])
        .environmentObject(AuthenticationViewModel())
}
