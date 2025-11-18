//
//  GalleryViewModel.swift
//  ZeroNet-Space
//
//  图库视图模型
//  管理媒体列表、排序、删除等操作
//

internal import Combine
import Foundation
import SwiftData
import SwiftUI

/// 图库视图模型
@MainActor
class GalleryViewModel: ObservableObject {

    // MARK: - Published Properties

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误消息
    @Published var errorMessage: String?

    /// 是否显示导入视图
    @Published var showImportView: Bool = false

    /// 是否显示导入限制提示
    @Published var showLimitAlert: Bool = false

    /// 待删除的媒体项
    @Published var mediaItemToDelete: MediaItem?

    /// 是否显示删除确认
    @Published var showDeleteConfirmation: Bool = false

    /// 排序方式
    @Published var sortOrder: MediaItem.SortOrder {
        didSet {
            AppSettings.shared.sortOrder = sortOrder
        }
    }

    /// 是否显示排序选项
    @Published var showSortOptions: Bool = false

    /// 是否处于批量选择模式
    @Published var isSelectionMode: Bool = false

    /// 已选择的媒体项ID集合
    @Published var selectedItemIDs: Set<UUID> = []

    // MARK: - Properties

    var modelContext: ModelContext?

    private let storageService = FileStorageService.shared
    private let encryptionService = EncryptionService.shared
    private let appSettings = AppSettings.shared

    // MARK: - Initialization

    init() {
        self.sortOrder = AppSettings.shared.sortOrder
    }

    // MARK: - Import Limit Checking

    /// 获取当前导入总数
    private func getCurrentMediaCount() -> Int {
        guard let context = modelContext else { return 0 }
        let descriptor = FetchDescriptor<MediaItem>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// 检查是否可以导入
    private func canImport() -> Bool {
        if appSettings.hasUnlockedUnlimited {
            return true
        }
        let currentCount = getCurrentMediaCount()
        return currentCount < AppConstants.freeImportLimit
    }

    // MARK: - Public Methods

    /// 删除媒体项
    func deleteMediaItem(_ item: MediaItem) {
        mediaItemToDelete = item
        showDeleteConfirmation = true
    }

    /// 确认删除
    func confirmDelete() {
        guard let item = mediaItemToDelete else { return }

        Task {
            do {
                // 删除加密文件
                try storageService.deleteFile(path: item.encryptedPath)

                // 从SwiftData删除
                modelContext?.delete(item)
                try? modelContext?.save()

                print("🗑️ 媒体项已删除: \(item.fileName)")

            } catch {
                errorMessage = String(
                    format: String(localized: "gallery.error.deleteFailed"),
                    error.localizedDescription)
                print("❌ 删除失败: \(error)")
            }

            mediaItemToDelete = nil
            showDeleteConfirmation = false
        }
    }

    /// 取消删除
    func cancelDelete() {
        mediaItemToDelete = nil
        showDeleteConfirmation = false
    }

    /// 显示导入视图
    func showImport() {
        // Check import limit
        if canImport() {
            showImportView = true
        } else {
            showLimitAlert = true
        }
    }

    /// 切换排序方式
    func toggleSortOptions() {
        showSortOptions.toggle()
    }

    /// 更改排序方式
    func changeSortOrder(to newOrder: MediaItem.SortOrder) {
        sortOrder = newOrder
        showSortOptions = false
    }

    /// 批量删除
    func deleteMultipleItems(_ items: [MediaItem]) {
        Task {
            var successCount = 0

            for item in items {
                do {
                    try storageService.deleteFile(path: item.encryptedPath)
                    modelContext?.delete(item)
                    successCount += 1
                } catch {
                    print("❌ 删除失败: \(item.fileName) - \(error)")
                }
            }

            try? modelContext?.save()

            print("🗑️ 批量删除完成: \(successCount)/\(items.count)")
        }
    }

    /// 获取存储统计
    func getStorageStatistics() -> FileStorageService.StorageStatistics {
        return storageService.getStorageStatistics()
    }

    // MARK: - Batch Selection Methods

    /// 切换批量选择模式
    func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            selectedItemIDs.removeAll()
        }
    }

    /// 切换单个媒体项的选择状态
    func toggleSelection(for item: MediaItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    /// 全选
    func selectAll(_ items: [MediaItem]) {
        selectedItemIDs = Set(items.map { $0.id })
    }

    /// 取消全选
    func deselectAll() {
        selectedItemIDs.removeAll()
    }

    /// 删除已选择的媒体项
    func deleteSelectedItems(_ allItems: [MediaItem]) {
        let itemsToDelete = allItems.filter { selectedItemIDs.contains($0.id) }
        deleteMultipleItems(itemsToDelete)
        selectedItemIDs.removeAll()
        isSelectionMode = false
    }

}

// MARK: - Filter Methods

extension GalleryViewModel {

    /// 按类型过滤媒体
    func filterByType(_ items: [MediaItem], type: MediaType?) -> [MediaItem] {
        guard let type = type else {
            return items
        }
        return items.filter { $0.type == type }
    }

    /// 搜索媒体
    func search(_ items: [MediaItem], query: String) -> [MediaItem] {
        guard !query.isEmpty else {
            return items
        }

        return items.filter { item in
            item.fileName.localizedCaseInsensitiveContains(query)
                || item.fileExtension.localizedCaseInsensitiveContains(query)
        }
    }
}
