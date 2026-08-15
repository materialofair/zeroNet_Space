//
//  PhotosView.swift
//  ZeroNet-Space
//
//  相片视图
//  网格展示所有图片，支持预览、缩放、搜索和批量选择
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
    @State private var searchText = ""
    @State private var isSelectionMode = false
    @State private var selectedPhotoIDs: Set<UUID> = []
    @State private var batchPhotosToDelete: [MediaItem] = []
    @State private var showBatchDeleteConfirmation = false

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
                } else if filteredPhotos.isEmpty {
                    searchEmptyView
                } else {
                    photoGridView
                }
            }
            .navigationTitle(String(localized: "photos.title"))
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: String(localized: "gallery.search.placeholder")
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode && !filteredPhotos.isEmpty {
                        selectAllButton
                    } else if !photos.isEmpty {
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
                    if isSelectionMode {
                        cancelButton
                    } else if guestModeManager.isOwnerMode {
                        HStack(spacing: 16) {
                            if !photos.isEmpty {
                                selectButton
                            }
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
            }
            .safeAreaInset(edge: .bottom) {
                if isSelectionMode && !selectedPhotoIDs.isEmpty {
                    batchActionsToolbar
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
                PhotoDetailView(photo: photo, allPhotos: filteredPhotos)
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
                String(localized: "photo.delete.confirmTitle"),
                isPresented: $showBatchDeleteConfirmation
            ) {
                Button(String(localized: "common.delete"), role: .destructive) {
                    deletePhotos(batchPhotosToDelete)
                }
                Button(String(localized: "common.cancel"), role: .cancel) {}
            } message: {
                Text(
                    String(
                        format: String(localized: "photos.delete.multipleMessage"),
                        batchPhotosToDelete.count))
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
            .onChange(of: searchText) { _, _ in
                // 搜索条件变化后清除选择，避免"已选择 N 项"与实际可见结果不一致
                selectedPhotoIDs.removeAll()
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

    // MARK: - Search Empty State

    private var searchEmptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text(String(localized: "photos.search.noResults"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Photo Grid

    private var photoGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(filteredPhotos) { photo in
                    if isSelectionMode {
                        // 选择模式：点击切换选择状态
                        Button {
                            toggleSelection(for: photo)
                        } label: {
                            GridItemView(
                                mediaItem: photo,
                                isSelectionMode: true,
                                isSelected: selectedPhotoIDs.contains(photo.id)
                            )
                            .aspectRatio(1, contentMode: .fill)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // 正常模式：点击预览
                        GridItemView(mediaItem: photo)
                            .aspectRatio(1, contentMode: .fill)
                            .onTapGesture {
                                selectedPhoto = photo
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    photoToDelete = photo
                                } label: {
                                    Label(
                                        String(localized: "common.delete"),
                                        systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Toolbar Items

    private var selectButton: some View {
        Button {
            isSelectionMode = true
        } label: {
            Text(String(localized: "common.select"))
        }
    }

    private var selectAllButton: some View {
        Button {
            if selectedPhotoIDs.count == filteredPhotos.count {
                selectedPhotoIDs.removeAll()
            } else {
                selectedPhotoIDs = Set(filteredPhotos.map { $0.id })
            }
        } label: {
            Text(
                selectedPhotoIDs.count == filteredPhotos.count
                    ? String(localized: "export.deselectAll")
                    : String(localized: "common.selectAll"))
        }
    }

    private var cancelButton: some View {
        Button {
            isSelectionMode = false
            selectedPhotoIDs.removeAll()
        } label: {
            Text(String(localized: "common.cancel"))
        }
    }

    // MARK: - Batch Actions Toolbar

    private var batchActionsToolbar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 20) {
                Text(
                    String(
                        format: String(localized: "gallery.selectedCount"),
                        selectedPhotoIDs.count)
                )
                .font(.subheadline)
                .foregroundColor(.secondary)

                Spacer()

                Button(role: .destructive) {
                    batchPhotosToDelete = filteredPhotos.filter {
                        selectedPhotoIDs.contains($0.id)
                    }
                    showBatchDeleteConfirmation = true
                } label: {
                    Label(String(localized: "common.delete"), systemImage: "trash")
                        .font(.subheadline)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Computed Properties

    /// 按搜索关键词过滤后的相片列表
    private var filteredPhotos: [MediaItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return photos }

        return photos.filter { item in
            item.fileName.localizedCaseInsensitiveContains(query)
                || item.fileExtension.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Methods

    private func toggleSelection(for photo: MediaItem) {
        if selectedPhotoIDs.contains(photo.id) {
            selectedPhotoIDs.remove(photo.id)
        } else {
            selectedPhotoIDs.insert(photo.id)
        }
    }

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

    /// 批量删除选中的相片
    private func deletePhotos(_ items: [MediaItem]) {
        guard !items.isEmpty else { return }

        let encryptedPaths = items.map { $0.encryptedPath }

        // 先提交数据库删除，成功后再删文件，
        // 避免 save 失败时留下指向已删除文件的记录
        for item in items {
            modelContext.delete(item)
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deleteErrorMessage = String(
                format: String(localized: "gallery.error.deleteFailed"),
                error.localizedDescription)
            return
        }

        for path in encryptedPaths {
            do {
                try FileStorageService.shared.deleteFile(path: path)
            } catch {
                // 记录已删除，文件删除失败只会残留无引用的加密文件
                print("⚠️ 加密文件删除失败: \(path) - \(error)")
            }
        }

        // 退出选择模式并清空选择
        isSelectionMode = false
        selectedPhotoIDs.removeAll()
        batchPhotosToDelete = []
        showBatchDeleteConfirmation = false
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
