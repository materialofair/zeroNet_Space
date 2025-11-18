//
//  ImportViewModel.swift
//  ZeroNet-Space
//
//  导入视图模型
//  管理媒体导入流程
//

internal import Combine
import Foundation
import PhotosUI
import SwiftData
import SwiftUI

/// 导入视图模型
@MainActor
class ImportViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 是否正在导入
    @Published var isImporting: Bool = false

    /// 导入进度
    @Published var importProgress: ImportProgress?

    /// 错误消息
    @Published var errorMessage: String?

    /// 是否显示照片选择器
    @Published var showPhotoPicker: Bool = false

    /// 是否显示文件选择器
    @Published var showFilePicker: Bool = false

    /// 导入成功的数量
    @Published var importedCount: Int = 0

    /// 是否显示导入限制提示
    @Published var showLimitAlert: Bool = false

    /// 导入限制提示消息
    @Published var limitAlertMessage: String = ""

    // MARK: - Services

    private let importService = MediaImportService.shared
    private let keychainService = KeychainService.shared
    let appSettings = AppSettings.shared

    // MARK: - Properties

    var modelContext: ModelContext?
    var onImportComplete: (([MediaItem]) -> Void)?

    /// 认证视图模型（用于获取会话密码）
    var authViewModel: AuthenticationViewModel?

    private var currentImportTask: Task<Void, Never>?

    // MARK: - Import Limit Checking

    /// 获取当前导入总数（照片+视频+文件）
    func getCurrentMediaCount() -> Int {
        guard let context = modelContext else { return 0 }
        let descriptor = FetchDescriptor<MediaItem>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// 获取剩余可导入数量
    func getRemainingImports() -> Int {
        if appSettings.hasUnlockedUnlimited {
            return Int.max
        }
        let currentCount = getCurrentMediaCount()
        return max(0, AppConstants.freeImportLimit - currentCount)
    }

    /// 检查是否可以导入指定数量的项目
    func canImport(itemCount: Int) -> Bool {
        let remaining = getRemainingImports()
        return remaining >= itemCount || appSettings.hasUnlockedUnlimited
    }

    /// 检查并显示限制提示（返回true表示可以继续导入）
    func checkImportLimit(itemCount: Int) -> Bool {
        if appSettings.hasUnlockedUnlimited {
            return true
        }

        let currentCount = getCurrentMediaCount()
        let remaining = getRemainingImports()

        if remaining <= 0 {
            // 已达到限制
            limitAlertMessage = String(localized: "iap.limitReached.message")
            showLimitAlert = true
            return false
        } else if itemCount > remaining {
            // 本次导入会超过限制
            limitAlertMessage = String(localized: "iap.limitExceeded.message")
                .replacingOccurrences(of: "{count}", with: "\(remaining)")
            showLimitAlert = true
            return false
        }

        return true
    }

    // MARK: - Public Methods

    /// 从照片库导入
    func importFromPhotoLibrary(results: [PHPickerResult]) {
        guard !isImporting else { return }
        guard !results.isEmpty else { return }

        guard checkImportLimit(itemCount: results.count) else {
            return
        }

        errorMessage = nil
        isImporting = true
        importedCount = 0

        startImportTask {
            try await self.importService.importMedia(
                from: results,
                password: $0
            ) { [weak self] progress in
                DispatchQueue.main.async {
                    self?.importProgress = progress
                }
            }
        }
    }

    /// 从文件导入
    func importFromFiles(urls: [URL]) {
        guard !isImporting else { return }
        guard !urls.isEmpty else { return }

        guard checkImportLimit(itemCount: urls.count) else {
            return
        }

        errorMessage = nil
        isImporting = true
        importedCount = 0

        startImportTask {
            try await self.importService.importFiles(
                from: urls,
                password: $0
            ) { [weak self] progress in
                DispatchQueue.main.async {
                    self?.importProgress = progress
                }
            }
        }
    }

    /// 显示照片选择器
    func selectPhotos() {
        showPhotoPicker = true
    }

    /// 显示文件选择器
    func selectFiles() {
        showFilePicker = true
    }

    /// 取消导入
    func cancelImport() {
        currentImportTask?.cancel()
        currentImportTask = nil
        isImporting = false
        importProgress = nil
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// 获取当前用户密码
    /// 从AuthenticationViewModel获取会话中的密码
    private func getCurrentPassword() async -> String? {
        return authViewModel?.sessionPassword
    }

    /// 统一封装导入流程，负责密码获取、任务管理与状态更新
    private func startImportTask(
        operation: @escaping (_ password: String) async throws -> [MediaItem]
    ) {
        currentImportTask?.cancel()

        currentImportTask = Task { [weak self] in
            guard let self else { return }
            await self.performImport(operation: operation)
        }
    }

    @MainActor
    private func performImport(
        operation: @escaping (_ password: String) async throws -> [MediaItem]
    ) async {
        do {
            guard let password = await getCurrentPassword() else {
                throw ImportError.permissionDenied
            }

            let items = try await operation(password)

            for item in items {
                modelContext?.insert(item)
            }

            try? modelContext?.save()

            importedCount = items.count
            importProgress = nil
            isImporting = false

            onImportComplete?(items)

            print("✅ 导入完成: \(items.count) 个项目")
        } catch is CancellationError {
            errorMessage = nil
            importProgress = nil
            isImporting = false
        } catch {
            errorMessage = String(
                format: String(localized: "import.error.failedWithReason"),
                error.localizedDescription)
            importProgress = nil
            isImporting = false
            print("❌ 导入失败: \(error)")
        }

        currentImportTask = nil
    }
}

// MARK: - Import Progress Extension

extension ImportViewModel {
    /// 格式化的进度文本
    var progressText: String {
        guard let progress = importProgress else {
            return isImporting ? String(localized: "import.status.preparing") : ""
        }
        return String(
            format: String(localized: "import.status.progress"),
            progress.current,
            progress.total,
            progress.currentFileName)
    }

    /// 进度百分比
    var progressPercentage: Double {
        importProgress?.percentage ?? 0
    }
}
