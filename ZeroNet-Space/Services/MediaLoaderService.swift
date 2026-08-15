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
/// 线程安全约定：`imageCache` 为 NSCache（本身线程安全），仅由
/// `@MainActor` 的 `loadImage` 在主线程读写；`loadQueue` 只做纯解码计算，
/// 不接触缓存。类标记 `@unchecked Sendable` 的前提是这一隔离约定。
nonisolated final class MediaLoaderService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = MediaLoaderService()

    // MARK: - Services

    private let storage = FileStorageService.shared

    // MARK: - Cache

    private var imageCache = NSCache<NSString, UIImage>()
    private let loadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.zeronetspace.image-loading"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

    private init() {
        // 配置缓存
        imageCache.countLimit = 100  // 最多缓存 100 张图片
        imageCache.totalCostLimit = 100 * 1024 * 1024  // 100MB

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
        let cacheKey = encryptedPath as NSString

        // 检查缓存
        if let cachedImage = imageCache.object(forKey: cacheKey) {
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

        let pixelWidth = Int(image.size.width * image.scale)
        let pixelHeight = Int(image.size.height * image.scale)
        imageCache.setObject(
            image,
            forKey: cacheKey,
            cost: pixelWidth * pixelHeight * 4
        )
        return image
    }

    /// 清除缓存（NSCache 线程安全，可在任意线程调用）
    func clearCache() {
        imageCache.removeAllObjects()
    }

    /// 清除指定图片的缓存（NSCache 线程安全，可在任意线程调用）
    func clearCache(forPath encryptedPath: String) {
        let cacheKey = encryptedPath as NSString
        imageCache.removeObject(forKey: cacheKey)
    }

    // MARK: - Notifications

    @objc private func handleMemoryWarning() {
        imageCache.removeAllObjects()
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
