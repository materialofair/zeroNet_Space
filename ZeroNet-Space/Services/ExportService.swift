/*@ai:risk=4|deps=EncryptionService,FileStorageService|lines=200*/
//
//  ExportService.swift
//  ZeroNet-Space
//
//  批量导出服务
//  解密文件并导出到系统分享界面
//

import Foundation
import UIKit

/// 导出错误类型
enum ExportError: Error {
    case noItemsSelected  // 未选择项目
    case decryptionFailed  // 解密失败
    case exportFailed  // 导出失败
    case invalidPassword  // 密码无效
    case tempDirectoryError  // 临时目录错误

    var localizedDescription: String {
        switch self {
        case .noItemsSelected:
            return String(localized: "exportError.noSelection")
        case .decryptionFailed:
            return AppConstants.ErrorMessages.decryptionFailed
        case .exportFailed:
            return String(localized: "export.failed")
        case .invalidPassword:
            return AppConstants.ErrorMessages.passwordIncorrect
        case .tempDirectoryError:
            return String(localized: "exportError.tempDirectory")
        }
    }
}

/// 批量导出服务
class ExportService {

    static let shared = ExportService()

    private let encryptionService = EncryptionService.shared
    private let fileStorageService = FileStorageService.shared

    private init() {}

    // MARK: - Public Methods

    /// 批量导出媒体项
    /// - Parameters:
    ///   - items: 要导出的媒体项列表
    ///   - password: 解密密码
    ///   - progressHandler: 进度回调（已导出数量，总数）
    ///   - completion: 完成回调,返回导出的URL数组或错误
    func exportItems(
        _ items: [MediaItem],
        password: String,
        progressHandler: ((Int, Int) -> Void)? = nil,
        completion: @escaping (Result<[URL], ExportError>) -> Void
    ) {
        guard !items.isEmpty else {
            completion(.failure(.noItemsSelected))
            return
        }

        // 在后台线程执行导出
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                // 创建临时导出目录
                let exportDirectory = try self.createExportDirectory()

                var exportedURLs: [URL] = []
                let totalCount = items.count
                var processedCount = 0

                // 逐个解密并导出文件
                for item in items {
                    let exportedURL = try self.exportSingleItem(
                        item,
                        to: exportDirectory,
                        password: password
                    )
                    exportedURLs.append(exportedURL)

                    processedCount += 1
                    if let progressHandler = progressHandler {
                        DispatchQueue.main.async {
                            progressHandler(processedCount, totalCount)
                        }
                    }
                }

                // 成功回调
                DispatchQueue.main.async {
                    completion(.success(exportedURLs))
                }

            } catch let error as ExportError {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.exportFailed))
                }
            }
        }
    }

    /// 清理临时导出文件
    func cleanupExportedFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent("ZeroNetExport", isDirectory: true)

        do {
            if FileManager.default.fileExists(atPath: exportDir.path) {
                try FileManager.default.removeItem(at: exportDir)
                print("✅ 清理导出临时文件成功")
            }
        } catch {
            print("❌ 清理导出临时文件失败: \(error)")
        }
    }

    // MARK: - Private Methods

    /// 创建临时导出目录
    private func createExportDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent("ZeroNetExport", isDirectory: true)

        // 如果目录已存在,先删除
        if FileManager.default.fileExists(atPath: exportDir.path) {
            try FileManager.default.removeItem(at: exportDir)
        }

        // 创建新目录
        try FileManager.default.createDirectory(
            at: exportDir,
            withIntermediateDirectories: true
        )

        return exportDir
    }

    /// 导出单个媒体项
    /// - Parameters:
    ///   - item: 媒体项
    ///   - directory: 导出目录
    ///   - password: 解密密码
    /// - Returns: 导出文件的URL
    private func exportSingleItem(
        _ item: MediaItem,
        to directory: URL,
        password: String
    ) throws -> URL {
        let sourceURL = fileStorageService.getFileURL(for: item.encryptedPath)
        // Always restore the original filename with extension so iOS recognizes the media type
        let fileName = item.fullFileName
        let exportURL = directory.appendingPathComponent(fileName)

        do {
            try encryptionService.decryptFile(
                inputURL: sourceURL,
                to: exportURL,
                password: password
            )
        } catch {
            print("❌ 导出失败: \(error)")
            throw ExportError.decryptionFailed
        }

        print("✅ 导出文件: \(fileName)")
        return exportURL
    }
}

// MARK: - UIActivityViewController Extension

extension ExportService {

    /// 创建分享视图控制器
    /// - Parameter urls: 要分享的文件URL列表
    /// - Returns: UIActivityViewController
    static func createShareController(for urls: [URL]) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: urls,
            applicationActivities: nil
        )

        // 排除一些不需要的活动类型
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .postToFlickr,
            .postToVimeo,
        ]

        // 完成回调 - 清理临时文件
        activityVC.completionWithItemsHandler = { _, completed, _, error in
            if completed || error != nil {
                // 延迟清理,确保系统完成文件访问
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    ExportService.shared.cleanupExportedFiles()
                }
            }
        }

        return activityVC
    }
}
