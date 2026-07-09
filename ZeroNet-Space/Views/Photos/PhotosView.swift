//
//  PhotosView.swift
//  ZeroNet-Space
//
//  相片视图
//  网格展示所有图片，支持预览和缩放
//

import SwiftData
import SwiftUI

struct PhotosView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthenticationViewModel

    // 只查询图片类型的媒体
    @Query(
        filter: #Predicate<MediaItem> { item in
            item.typeRawValue == "photo"
        },
        sort: \MediaItem.createdAt,
        order: .reverse
    )
    private var photos: [MediaItem]

    // MARK: - State

    @StateObject private var viewModel = PhotosViewModel()
    @EnvironmentObject private var guestModeManager: GuestModeManager
    @State private var showImportView = false
    @State private var showExportView = false
    @State private var selectedPhoto: MediaItem?
    @State private var photoToDelete: MediaItem?
    @State private var deleteErrorMessage: String?

    // MARK: - Constants

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 访客模式下始终显示空状态
                if guestModeManager.isGuestMode || photos.isEmpty {
                    emptyStateView
                } else {
                    photoGridView
                }
            }
            .navigationTitle(String(localized: "photos.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !photos.isEmpty {
                        Button {
                            showExportView = true
                        } label: {
                            Label(
                                String(localized: "photos.export"),
                                systemImage: "square.and.arrow.up")
                        }
                    }
                }

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
                    print("✅ 导入完成: \(items.count) 张相片")
                })
                .environment(\.modelContext, modelContext)
                .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showExportView) {
                BatchExportView()
                    .environment(\.modelContext, modelContext)
                    .environmentObject(authViewModel)
            }
            .fullScreenCover(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo, allPhotos: photos)
                    .environmentObject(authViewModel)
            }
            .alert(
                String(localized: "photo.delete.confirmTitle"),
                isPresented: Binding(
                    get: { photoToDelete != nil },
                    set: { if !$0 { photoToDelete = nil } }
                ),
                presenting: photoToDelete
            ) { photo in
                Button(String(localized: "common.delete"), role: .destructive) {
                    deletePhoto(photo)
                }
                Button(String(localized: "common.cancel"), role: .cancel) {}
            } message: { _ in
                Text(String(localized: "photo.delete.confirmMessage"))
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
                cleanupInvalidPhotos()
            }
        }
    }

    // MARK: - Cleanup

    /// 清理失效的图片记录
    private func cleanupInvalidPhotos() {
        let storage = FileStorageService.shared
        var removedCount = 0

        for photo in photos {
            if !storage.fileExists(path: photo.encryptedPath) {
                modelContext.delete(photo)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            do {
                try modelContext.save()
                print("🗑️ 已清理 \(removedCount) 条失效的图片记录")
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
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: "photo.stack")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(String(localized: "photos.empty.title"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: "photos.empty.subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button {
                showImportView = true
            } label: {
                Label(String(localized: "photos.startImport"), systemImage: "photo.badge.plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Photo Grid

    private var photoGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(photos) { photo in
                    GridItemView(mediaItem: photo)
                        .aspectRatio(1, contentMode: .fill)
                        .onTapGesture {
                            selectedPhoto = photo
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                photoToDelete = photo
                            } label: {
                                Label(String(localized: "common.delete"), systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    // MARK: - Methods

    private func deletePhoto(_ photo: MediaItem) {
        let encryptedPath = photo.encryptedPath

        // 先提交数据库删除，成功后再删文件，
        // 避免 save 失败时留下指向已删除文件的记录
        modelContext.delete(photo)
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

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let photo: MediaItem

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                // TODO: 加载真实的缩略图
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            }
            .clipped()
    }
}

// MARK: - Preview

#Preview {
    PhotosView()
        .modelContainer(for: MediaItem.self, inMemory: true)
        .environmentObject(AuthenticationViewModel())
}
