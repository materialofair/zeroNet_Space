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

        errorMessage = nil
        isImporting = true
        importedCount = 0

        Task {
            do {
                // 获取用户密码（这里使用一个临时方案，实际应该从认证系统获取）
                // TODO: 从AuthenticationViewModel获取当前会话密码
                guard let password = await getCurrentPassword() else {
                    throw ImportError.permissionDenied
                }

                // 导入媒体
                let items = try await importService.importMedia(
                    from: results,
                    password: password
                ) { [weak self] progress in
                    self?.importProgress = progress
                }

                // 保存到SwiftData
                print("💾 准备保存到 SwiftData...")
                print("📊 ModelContext 状态: \(modelContext != nil ? "已设置" : "未设置")")

                for item in items {
                    modelContext?.insert(item)
                }

                try? modelContext?.save()

                print("✅ 数据已成功保存: \(items.count) 个项目")

                importedCount = items.count
                importProgress = nil
                isImporting = false

                // 通知完成
                onImportComplete?(items)

                print("✅ 导入完成: \(items.count) 个媒体文件")

            } catch {
                errorMessage = String(
                    format: String(localized: "import.error.failedWithReason"),
                    error.localizedDescription)
                importProgress = nil
                isImporting = false
                print("❌ 导入失败: \(error)")
            }
        }
    }

    /// 从文件导入
    func importFromFiles(urls: [URL]) {
        guard !isImporting else { return }

        errorMessage = nil
        isImporting = true
        importedCount = 0

        Task {
            do {
                // 获取用户密码
                guard let password = await getCurrentPassword() else {
                    throw ImportError.permissionDenied
                }

                // 导入文件
                let items = try await importService.importFiles(
                    from: urls,
                    password: password
                ) { [weak self] progress in
                    self?.importProgress = progress
                }

                // 保存到SwiftData
                print("💾 准备保存文件到 SwiftData...")
                print("📊 ModelContext 状态: \(modelContext != nil ? "已设置" : "未设置")")

                for item in items {
                    modelContext?.insert(item)
                }

                try? modelContext?.save()

                print("✅ 文件数据已成功保存: \(items.count) 个项目")

                importedCount = items.count
                importProgress = nil
                isImporting = false

                // 通知完成
                onImportComplete?(items)

                print("✅ 导入完成: \(items.count) 个文件")

            } catch {
                errorMessage = String(
                    format: String(localized: "import.error.failedWithReason"),
                    error.localizedDescription)
                importProgress = nil
                isImporting = false
                print("❌ 导入失败: \(error)")
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
