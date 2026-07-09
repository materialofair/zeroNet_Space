//
//  VideosView.swift
//  ZeroNet-Space
//
//  视频视图
//  列表展示所有视频，支持播放
//

import AVKit
import SwiftData
import SwiftUI

struct VideosView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthenticationViewModel

    // 只查询视频类型的媒体
    @Query(
        filter: #Predicate<MediaItem> { item in
            item.typeRawValue == "video"
        },
        sort: \MediaItem.createdAt,
        order: .reverse
    )
    private var videos: [MediaItem]

    // MARK: - State

    @EnvironmentObject private var guestModeManager: GuestModeManager
    @State private var showImportView = false
    @State private var selectedVideo: MediaItem?
    @State private var videoToDelete: MediaItem?
    @State private var deleteErrorMessage: String?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 访客模式下始终显示空状态
                if guestModeManager.isGuestMode || videos.isEmpty {
                    emptyStateView
                } else {
                    videoListView
                }
            }
            .navigationTitle(String(localized: "videos.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 访客模式下隐藏导入按钮
                    if guestModeManager.isOwnerMode {
                        Button {
                            showImportView = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
            }
            .sheet(isPresented: $showImportView) {
                ImportButtonsView(onImportComplete: { items in
                    print("✅ 导入完成: \(items.count) 个视频")
                })
                .environment(\.modelContext, modelContext)
                .environmentObject(authViewModel)
            }
            .fullScreenCover(item: $selectedVideo) { video in
                VideoPlayerView(video: video)
            }
            .alert(
                String(localized: "video.delete.confirmTitle"),
                isPresented: Binding(
                    get: { videoToDelete != nil },
                    set: { if !$0 { videoToDelete = nil } }
                ),
                presenting: videoToDelete
            ) { video in
                Button(String(localized: "common.delete"), role: .destructive) {
                    deleteVideo(video)
                }
                Button(String(localized: "common.cancel"), role: .cancel) {}
            } message: { _ in
                Text(String(localized: "video.delete.confirmMessage"))
            }
            .alert(
                String(localized: "common.error"),
                isPresented: Binding(
                    get: { deleteErrorMessage != nil },
                    set: { if !$0 { deleteErrorMessage = nil } }
                )
            ) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(deleteErrorMessage ?? "")
            }
            .task {
                cleanupInvalidVideos()
            }
        }
    }

    // MARK: - Cleanup

    /// 清理失效的视频记录
    private func cleanupInvalidVideos() {
        let storage = FileStorageService.shared
        var removedCount = 0

        for video in videos {
            if !storage.fileExists(path: video.encryptedPath) {
                modelContext.delete(video)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            do {
                try modelContext.save()
                print("🗑️ 已清理 \(removedCount) 条失效的视频记录")
            } catch {
                print("❌ 清理失效记录失败: \(error)")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // 渐变图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.pink.opacity(0.2), .orange.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(String(localized: "videos.empty.title"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: "videos.empty.subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button {
                showImportView = true
            } label: {
                Label(
                    String(localized: "videos.startImport"),
                    systemImage: "plus.rectangle.on.rectangle"
                )
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.pink, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .pink.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Video List

    private var videoListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(videos) { video in
                    VideoCardView(video: video)
                        .onTapGesture {
                            selectedVideo = video
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                videoToDelete = video
                            } label: {
                                Label(String(localized: "common.delete"), systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
    }

    // MARK: - Methods

    private func deleteVideo(_ video: MediaItem) {
        let encryptedPath = video.encryptedPath

        // 先提交数据库删除，成功后再删文件，
        // 避免 save 失败时留下指向已删除文件的记录
        modelContext.delete(video)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deleteErrorMessage = String(
                format: String(localized: "gallery.error.deleteFailed"),
                error.localizedDescription)
            return
        }

        do {
            try FileStorageService.shared.deleteFile(path: encryptedPath)
        } catch {
            // 记录已删除，文件删除失败只会残留无引用的加密文件
            print("⚠️ 加密文件删除失败: \(error)")
        }
    }
}

// MARK: - Video Card View

struct VideoCardView: View {
    let video: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 视频缩略图
            ZStack {
                // 缩略图或占位背景
                if let thumbnailData = video.thumbnailData,
                    let uiImage = UIImage(data: thumbnailData)
                {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(16 / 9, contentMode: .fill)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.pink.opacity(0.3), .orange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(16 / 9, contentMode: .fit)
                }

                // 播放图标
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10)

                // 时长标签（右下角）
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(video.formattedDuration ?? "00:00")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                            .padding(8)
                    }
                }
            }

            // 视频信息
            VStack(alignment: .leading, spacing: 6) {
                Text(video.fileName)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Label(
                        formatFileSize(video.fileSize),
                        systemImage: "doc"
                    )

                    Spacer()

                    Text(formatDate(video.createdAt))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    VideosView()
        .modelContainer(for: MediaItem.self, inMemory: true)
        .environmentObject(AuthenticationViewModel())
}
