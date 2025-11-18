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
final class MediaLoaderService {

    // MARK: - Singleton

    static let shared = MediaLoaderService()

    // MARK: - Services

    private let storage = FileStorageService.shared
    private let encryption = EncryptionService.shared

    // MARK: - Cache

    private var imageCache = NSCache<NSString, UIImage>()

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
    func loadImage(from mediaItem: MediaItem, password: String) async throws -> UIImage {
        let cacheKey = mediaItem.encryptedPath as NSString

        // 检查缓存
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        // 在后台线程读取并解密，避免阻塞主线程
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let encryptedData = try self.storage.loadEncrypted(path: mediaItem.encryptedPath)
                    let decryptedData = try self.encryption.decrypt(
                        encryptedData: encryptedData,
                        password: password
                    )

                    guard let image = UIImage(data: decryptedData) else {
                        throw MediaLoaderError.invalidImageData
                    }

                    self.imageCache.setObject(image, forKey: cacheKey)
                    continuation.resume(returning: image)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 清除缓存
    func clearCache() {
        imageCache.removeAllObjects()
    }

    /// 清除指定图片的缓存
    func clearCache(for mediaItem: MediaItem) {
        let cacheKey = mediaItem.encryptedPath as NSString
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
            return "无效的图片数据"
        case .fileNotFound:
            return "文件不存在"
        case .decryptionFailed:
            return "解密失败"
        }
    }
}
