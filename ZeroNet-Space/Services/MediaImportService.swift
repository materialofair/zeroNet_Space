//
//  MediaImportService.swift
//  ZeroNet-Space
//
//  媒体导入服务
//  处理照片、视频、文件的导入、加密和保存
//

import AVFoundation
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 导入错误
enum ImportError: Error {
    case loadFailed  // 加载失败
    case unsupportedType  // 不支持的类型
    case encryptionFailed  // 加密失败
    case saveFailed  // 保存失败
    case cancelled  // 用户取消
    case permissionDenied  // 权限被拒绝

    var localizedDescription: String {
        switch self {
        case .loadFailed:
            return String(localized: "importError.loadFailed")
        case .unsupportedType:
            return String(localized: "importError.unsupportedType")
        case .encryptionFailed:
            return AppConstants.ErrorMessages.encryptionFailed
        case .saveFailed:
            return AppConstants.ErrorMessages.saveFailed
        case .cancelled:
            return String(localized: "importError.cancelled")
        case .permissionDenied:
            return AppConstants.ErrorMessages.permissionDenied
        }
    }
}

/// 导入进度
struct ImportProgress {
    let current: Int
    let total: Int
    let currentFileName: String

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
}

/// 媒体导入服务
class MediaImportService {

    // MARK: - Singleton

    static let shared = MediaImportService()

    // MARK: - Services

    private let encryptionService = EncryptionService.shared
    private let storageService = FileStorageService.shared

    // MARK: - Public Methods

    /// 导入照片/视频（从PHPicker）
    /// - Parameters:
    ///   - results: PHPicker结果数组
    ///   - password: 加密密码
    ///   - progress: 进度回调
    /// - Returns: 导入成功的MediaItem数组
    func importMedia(
        from results: [PHPickerResult],
        password: String,
        progress: @escaping (ImportProgress) -> Void = { _ in }
    ) async throws -> [MediaItem] {
        var importedItems: [MediaItem] = []
        let total = results.count

        for (index, result) in results.enumerated() {
            try Task.checkCancellation()

            let currentProgress = ImportProgress(
                current: index + 1,
                total: total,
                currentFileName: "媒体 \(index + 1)"
            )
            await MainActor.run {
                progress(currentProgress)
            }

            do {
                if let item = try await importSingleMedia(result: result, password: password) {
                    importedItems.append(item)
                }
            } catch {
                print("⚠️ 导入媒体失败: \(error)")
                // 继续导入其他文件
            }
        }

        print("✅ 成功导入 \(importedItems.count)/\(total) 个媒体文件")
        return importedItems
    }

    /// 导入文件（从文档选择器）
    /// - Parameters:
    ///   - urls: 文件URL数组
    ///   - password: 加密密码
    ///   - progress: 进度回调
    /// - Returns: 导入成功的MediaItem数组
    func importFiles(
        from urls: [URL],
        password: String,
        progress: @escaping (ImportProgress) -> Void = { _ in }
    ) async throws -> [MediaItem] {
        var importedItems: [MediaItem] = []
        let total = urls.count

        for (index, url) in urls.enumerated() {
            try Task.checkCancellation()

            let currentProgress = ImportProgress(
                current: index + 1,
                total: total,
                currentFileName: url.lastPathComponent
            )
            await MainActor.run {
                progress(currentProgress)
            }

            // 开始访问安全作用域资源
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ 无法访问文件: \(url.lastPathComponent)")
                continue
            }
            defer {
                url.stopAccessingSecurityScopedResource()
            }

            do {
                if let item = try await importSingleFile(url: url, password: password) {
                    importedItems.append(item)
                }
            } catch {
                if error is CancellationError {
                    throw error
                }
                print("⚠️ 导入文件失败: \(error)")
                // 继续导入其他文件
            }
        }

        print("✅ 成功导入 \(importedItems.count)/\(total) 个文件")
        return importedItems
    }

    // MARK: - Private Methods - Media Import

    /// 导入单个媒体（照片/视频）
    private func importSingleMedia(result: PHPickerResult, password: String) async throws
        -> MediaItem?
    {
        let itemProvider = result.itemProvider

        // 检查是否为图片
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            return try await importImage(from: itemProvider, password: password)
        }

        // 检查是否为视频
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            return try await importVideo(from: itemProvider, password: password)
        }

        print("⚠️ 不支持的媒体类型")
        return nil
    }

    /// 导入图片
    private func importImage(from itemProvider: NSItemProvider, password: String) async throws
        -> MediaItem?
    {
        return try await withCheckedThrowingContinuation { continuation in
            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] (image, error) in
                guard let self = self else {
                    continuation.resume(throwing: ImportError.loadFailed)
                    return
                }

                if let error = error {
                    print("❌ 图片加载失败: \(error)")
                    continuation.resume(throwing: ImportError.loadFailed)
                    return
                }

                guard let image = image as? UIImage else {
                    continuation.resume(throwing: ImportError.loadFailed)
                    return
                }

                Task {
                    do {
                        let item = try await self.processImage(image, password: password)
                        continuation.resume(returning: item)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// 导入视频
    private func importVideo(from itemProvider: NSItemProvider, password: String) async throws
        -> MediaItem?
    {
        return try await withCheckedThrowingContinuation { continuation in
            itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) {
                [weak self] (url, error) in
                guard let self = self else {
                    continuation.resume(throwing: ImportError.loadFailed)
                    return
                }

                if let error = error {
                    print("❌ 视频加载失败: \(error)")
                    continuation.resume(throwing: ImportError.loadFailed)
                    return
                }

                guard let originalURL = url else {
                    continuation.resume(throwing: ImportError.loadFailed)
                    return
                }

                // ⚠️ 关键: 立即复制临时文件到我们自己的临时目录
                // 因为系统提供的临时文件会在回调后立即被删除
                let fileManager = FileManager.default
                let ourTempDir = fileManager.temporaryDirectory.appendingPathComponent(
                    "video_import", isDirectory: true)

                do {
                    // 创建临时目录
                    try? fileManager.createDirectory(
                        at: ourTempDir, withIntermediateDirectories: true)

                    // 复制到我们的临时目录
                    let copiedURL = ourTempDir.appendingPathComponent(originalURL.lastPathComponent)

                    // 如果已存在则删除
                    try? fileManager.removeItem(at: copiedURL)

                    // 复制文件
                    try fileManager.copyItem(at: originalURL, to: copiedURL)
                    print("📋 临时视频已复制: \(originalURL.lastPathComponent)")

                    Task {
                        do {
                            // 使用复制后的文件处理
                            let item = try await self.processVideo(copiedURL, password: password)

                            // 处理完成后删除复制的临时文件
                            try? fileManager.removeItem(at: copiedURL)

                            continuation.resume(returning: item)
                        } catch {
                            // 失败时也要清理
                            try? fileManager.removeItem(at: copiedURL)
                            continuation.resume(throwing: error)
                        }
                    }
                } catch {
                    print("❌ 复制临时文件失败: \(error)")
                    continuation.resume(throwing: ImportError.loadFailed)
                }
            }
        }
    }

    /// 导入单个文件
    private func importSingleFile(url: URL, password: String) async throws -> MediaItem? {
        try Task.checkCancellation()

        let fileName = url.deletingPathExtension().lastPathComponent
        let fileExtension = "." + url.pathExtension
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        let mediaType = MediaType.from(fileExtension: url.pathExtension)

        // 针对视频文件走专用处理流程，保证缩略图与元数据一致
        if mediaType == .video {
            return try await processVideo(url, password: password)
        }

        var encryptedPath: String
        var thumbnailData: Data?

        if mediaType == .photo {
            let data = try Data(contentsOf: url)
            try Task.checkCancellation()
            let encryptedData = try encryptionService.encrypt(data: data, password: password)
            encryptedPath = try storageService.saveEncrypted(
                data: encryptedData,
                originalFileName: url.lastPathComponent
            )
            thumbnailData = generateThumbnail(
                for: data,
                type: mediaType,
                fileExtension: url.pathExtension
            )
        } else {
            encryptedPath = try storageService.saveEncryptedFile(
                from: url,
                password: password,
                originalFileName: url.lastPathComponent
            )
            thumbnailData = nil
        }

        let mediaItem = MediaItem(
            fileName: fileName,
            fileExtension: fileExtension,
            fileSize: fileSize,
            type: mediaType,
            encryptedPath: encryptedPath,
            thumbnailData: thumbnailData
        )

        print("📥 文件已导入: \(url.lastPathComponent)")
        return mediaItem
    }

    // MARK: - Image Processing

    /// 处理图片
    private func processImage(_ image: UIImage, password: String) async throws -> MediaItem {
        try Task.checkCancellation()
        // 转换为JPEG数据
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw ImportError.loadFailed
        }

        let fileName = "IMG_\(Date().timeIntervalSince1970)"
        let fileExtension = ".jpg"
        let fileSize = Int64(imageData.count)

        // 加密图片
        let encryptedData = try encryptionService.encrypt(data: imageData, password: password)

        // 保存加密文件
        let encryptedPath = try storageService.saveEncrypted(
            data: encryptedData, originalFileName: fileName + fileExtension)

        // 生成缩略图
        let thumbnail = image.thumbnail(maxSize: AppConstants.thumbnailMaxSize)
        let thumbnailData = thumbnail?.compressedJPEGData(
            quality: AppConstants.thumbnailCompressionQuality)

        // 获取图片尺寸
        let width = Int(image.size.width)
        let height = Int(image.size.height)

        // 创建MediaItem
        let mediaItem = MediaItem(
            fileName: fileName,
            fileExtension: fileExtension,
            fileSize: fileSize,
            type: .photo,
            encryptedPath: encryptedPath,
            thumbnailData: thumbnailData,
            width: width,
            height: height
        )

        print("📷 照片已导入: \(width)×\(height)")
        return mediaItem
    }

    // MARK: - Video Processing

    /// 处理视频
    private func processVideo(_ url: URL, password: String) async throws -> MediaItem {
        try Task.checkCancellation()
        // ⚠️ 重要: 必须先提取元数据和缩略图，再读取数据
        // 因为临时 URL 可能在读取数据后就失效

        print("📹 开始处理视频: \(url.lastPathComponent)")

        // 1️⃣ 先获取视频元数据（此时临时文件还存在）
        let (width, height, duration) = await getVideoMetadata(url: url)
        print("📊 视频元数据: \(width ?? 0)×\(height ?? 0), \(duration ?? 0)秒")

        // 2️⃣ 生成缩略图（此时临时文件还存在）
        let thumbnailData = try? await generateVideoThumbnail(url: url)
        if let thumbnailSize = thumbnailData?.count {
            print("🖼️ 缩略图生成成功: \(thumbnailSize) bytes")
        } else {
            print("⚠️ 缩略图生成失败，将使用默认图标")
        }

        // 3️⃣ 获取文件大小
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let fileName = url.deletingPathExtension().lastPathComponent
        let fileExtension = "." + url.pathExtension

        // 4️⃣ 流式加密并保存
        let encryptedPath = try storageService.saveEncryptedFile(
            from: url,
            password: password,
            originalFileName: url.lastPathComponent
        )
        print("💾 加密文件已保存: \(encryptedPath)")

        // 6️⃣ 创建MediaItem（确保所有参数都正确传递）
        let mediaItem = MediaItem(
            fileName: fileName,
            fileExtension: fileExtension,
            fileSize: fileSize,
            type: .video,
            encryptedPath: encryptedPath,
            thumbnailData: thumbnailData,
            width: width,
            height: height,
            duration: duration
        )

        // 7️⃣ 验证MediaItem数据
        print("✅ 视频处理完成:")
        print("   - 尺寸: \(mediaItem.width ?? 0)×\(mediaItem.height ?? 0)")
        print("   - 时长: \(mediaItem.duration ?? 0)秒")
        print(
            "   - 缩略图: \(mediaItem.thumbnailData != nil ? "有(\(mediaItem.thumbnailData!.count) bytes)" : "无")"
        )
        print("   - 文件大小: \(mediaItem.formattedFileSize)")

        return mediaItem
    }

    // MARK: - Thumbnail Generation

    /// 生成缩略图
    private func generateThumbnail(for data: Data, type: MediaType, fileExtension: String) -> Data?
    {
        switch type {
        case .photo:
            guard let image = UIImage(data: data),
                let thumbnail = image.thumbnail(maxSize: AppConstants.thumbnailMaxSize)
            else {
                return nil
            }
            return thumbnail.compressedJPEGData(quality: AppConstants.thumbnailCompressionQuality)

        case .video:
            // 视频缩略图需要URL，这里返回nil，在processVideo中单独处理
            return nil

        case .document:
            // 文档使用默认图标，不需要缩略图
            return nil
        }
    }

    /// 生成视频缩略图
    private func generateVideoThumbnail(url: URL) async throws -> Data? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: AppConstants.videoThumbnailTime, preferredTimescale: 600)

        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                if let error = error {
                    print("⚠️ 视频缩略图生成失败: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let cgImage = cgImage else {
                    continuation.resume(returning: nil)
                    return
                }

                let image = UIImage(cgImage: cgImage)
                if let thumbnail = image.thumbnail(maxSize: AppConstants.thumbnailMaxSize),
                    let thumbnailData = thumbnail.compressedJPEGData(
                        quality: AppConstants.thumbnailCompressionQuality)
                {
                    continuation.resume(returning: thumbnailData)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// 获取视频元数据
    private func getVideoMetadata(url: URL) async -> (width: Int?, height: Int?, duration: Double?)
    {
        let asset = AVAsset(url: url)

        // 获取时长
        let duration = try? await asset.load(.duration)
        let durationSeconds = duration.map { CMTimeGetSeconds($0) }

        // 获取视频尺寸
        guard let track = try? await asset.loadTracks(withMediaType: .video).first else {
            return (nil, nil, durationSeconds)
        }

        let size = try? await track.load(.naturalSize)
        let width = size.map { Int($0.width) }
        let height = size.map { Int($0.height) }

        return (width, height, durationSeconds)
    }
}
