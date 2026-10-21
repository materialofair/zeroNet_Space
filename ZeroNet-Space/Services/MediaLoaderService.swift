//
//  MediaLoaderService.swift
//  ZeroNet-Space
//
//  媒体加载服务
//  负责解密和加载图片、视频等媒体文件
//

import Foundation
import SwiftUI
import UIKit

/// 媒体加载服务
///
/// The cache serializes invalidation with insertion. The operation queue only
/// decodes pixels; view publication remains on the main actor.
nonisolated final class MediaLoaderService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = MediaLoaderService()

    // MARK: - Services

    private let storage = FileStorageService.shared

    // MARK: - Cache

    private let imageCache = SensitiveImageCache(countLimit: 100, costLimit: 100 * 1_024 * 1_024)
    private let loadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.zeronetspace.image-loading"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    // MARK: - Public Methods

    /// 加载图片（带缓存）
    @MainActor
    func loadImage(from mediaItem: MediaItem, password: String) async throws -> UIImage {
        let encryptedPath = mediaItem.encryptedPath
        let cacheKey = encryptedPath
        let generation = imageCache.token()

        // 检查缓存
        if let cachedImage = imageCache.image(for: cacheKey) {
            return cachedImage
        }

        // 统一走 ZNSC 感知的解密管线，加密格式检测只存在 FileStorageService 一处
        try Task.checkCancellation()
        let decryptedData = try await storage.loadDecryptedDataAsync(
            path: encryptedPath,
            password: password,
            preferredExtension: mediaItem.fileExtension
        )
        try Task.checkCancellation()

        // 后台解码，避免阻塞主线程
        let image = await withCheckedContinuation { continuation in
            loadQueue.addOperation {
                continuation.resume(
                    returning: ThumbnailImageLoader.decode(
                        data: decryptedData,
                        maxPixelSize: AppConstants.previewImageMaxPixelSize
                    )
                )
            }
        }
        guard let image = image else {
            throw MediaLoaderError.invalidImageData
        }

        try Task.checkCancellation()
        guard imageCache.insert(image, for: cacheKey, token: generation) else {
            throw CancellationError()
        }
        return image
    }

    /// 清除缓存（NSCache 线程安全，可在任意线程调用）
    func clearCache() {
        imageCache.clear()
    }

    /// 清除指定图片的缓存（NSCache 线程安全，可在任意线程调用）
    func clearCache(forPath encryptedPath: String) {
        imageCache.remove(encryptedPath)
    }

    // MARK: - Notifications

    @objc private func handleMemoryWarning() {
        imageCache.clear()
        print("⚠️ 内存警告，已清空图片缓存")
    }
}

// MARK: - Errors

enum MediaLoaderError: Error {
    case invalidImageData
    case fileNotFound
    case decryptionFailed

    var localizedDescription: String {
        switch self {
        case .invalidImageData:
            return String(localized: "mediaLoader.error.invalidImageData")
        case .fileNotFound:
            return AppConstants.ErrorMessages.fileNotFound
        case .decryptionFailed:
            return AppConstants.ErrorMessages.decryptionFailed
        }
    }
}
