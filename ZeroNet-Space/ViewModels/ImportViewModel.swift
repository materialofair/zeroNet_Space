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

    /// 是否显示加密文件密码输入对话框
    @Published var showEncryptedPasswordInput: Bool = false

    /// 当前待处理的加密文件信息
    @Published var pendingEncryptedFile: (fileName: String, url: URL)?

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

        // 检测是否有加密文件
        let encryptedFiles = urls.filter { $0.pathExtension == "encrypted" }

        if !encryptedFiles.isEmpty {
            // 如果有加密文件，优先处理第一个加密文件
            let firstEncryptedFile = encryptedFiles[0]
            pendingEncryptedFile = (
                fileName: firstEncryptedFile.lastPathComponent,
                url: firstEncryptedFile
            )
            isImporting = true
            showEncryptedPasswordInput = true

            // 如果有多个文件，暂时只处理加密文件
            // TODO: 可以支持批量处理混合文件类型
            return
        }

        // 正常导入非加密文件
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

// MARK: - Encrypted File Password Handling

extension ImportViewModel {
    /// 处理加密文件密码输入确认
    func handleEncryptedFilePassword(_ password: String) {
        guard let pendingFile = pendingEncryptedFile else { return }

        // 清空待处理文件
        pendingEncryptedFile = nil

        // 使用输入的密码重新导入文件
        importEncryptedFileWithPassword(url: pendingFile.url, originalPassword: password)
    }

    /// 取消加密文件密码输入
    func cancelEncryptedFilePasswordInput() {
        pendingEncryptedFile = nil
        showEncryptedPasswordInput = false
        isImporting = false
        errorMessage = String(localized: "import.encryptedFile.cancelled")
    }

    /// 使用原始密码导入加密文件并用新密码重新加密
    private func importEncryptedFileWithPassword(url: URL, originalPassword: String) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = String(localized: "import.error.accessDenied")
            showEncryptedPasswordInput = false
            isImporting = false
            return
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }

        isImporting = true
        errorMessage = nil

        currentImportTask = Task { [weak self] in
            guard let self else { return }

            do {
                // 获取当前会话密码（用于重新加密）
                guard let newPassword = await self.getCurrentPassword() else {
                    await MainActor.run {
                        self.errorMessage = String(localized: "import.error.noPassword")
                        self.isImporting = false
                    }
                    return
                }

                // 使用原始密码导入并用新密码重新加密
                let items = try await self.importService.importEncryptedFileWithReencryption(
                    url: url,
                    originalPassword: originalPassword,
                    newPassword: newPassword
                )

                await MainActor.run {
                    // 保存到数据库
                    for item in items {
                        self.modelContext?.insert(item)
                    }
                    try? self.modelContext?.save()

                    self.importedCount = items.count
                    self.isImporting = false
                    self.showEncryptedPasswordInput = false

                    self.onImportComplete?(items)

                    print("✅ 加密文件导入成功: \(items.count) 个项目")
                }
            } catch {
                await MainActor.run {
                    if error is EncryptionError {
                        // 解密失败，可能是密码错误
                        self.errorMessage = String(localized: "import.encryptedFile.wrongPassword")
                    } else {
                        self.errorMessage = String(
                            format: String(localized: "import.error.failedWithReason"),
                            error.localizedDescription)
                    }
                    self.isImporting = false
                    self.showEncryptedPasswordInput = false

                    print("❌ 加密文件导入失败: \(error)")
                }
            }
        }
    }
}
