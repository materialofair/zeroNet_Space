import ImageIO
import UIKit

/// 在后台完成缩略图解码，并在不同列表视图之间共享结果。
nonisolated final class ThumbnailImageLoader: @unchecked Sendable {
    static let shared = ThumbnailImageLoader()

    private let cache = SensitiveImageCache(countLimit: 150, costLimit: 48 * 1_024 * 1_024)
    private let decoder: @Sendable (Data, CGFloat) -> UIImage?
    private let decodeQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.zeronetspace.thumbnail-decoding"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

    init(decoder: @escaping @Sendable (Data, CGFloat) -> UIImage? = {
        ThumbnailImageLoader.decode(data: $0, maxPixelSize: $1)
    }) { self.decoder = decoder }

    func image(
        for key: String,
        data: Data,
        maxPixelSize: CGFloat = AppConstants.thumbnailMaxSize
    ) async -> UIImage? {
        // 缓存键包含内容指纹：同一 id 下缩略图数据变化时不会命中旧缓存。
        // 指纹取长度 + 首尾字节哈希，避免对大图做全量哈希。
        let fingerprint = "\(data.count)-\(data.prefix(64).hashValue)-\(data.suffix(64).hashValue)"
        let cacheKey = "\(key)-\(Int(maxPixelSize))-\(fingerprint)"
        let generation = cache.token()
        if let cachedImage = cache.image(for: cacheKey) {
            return cachedImage
        }

        // 已被取消的任务不再入队解码（滚动离开的网格项等）
        if Task.isCancelled {
            return nil
        }

        return await withCheckedContinuation { continuation in
            decodeQueue.addOperation { [weak self] in
                guard let self else { continuation.resume(returning: nil); return }
                let decoded = self.decoder(data, maxPixelSize)
                let image = decoded.flatMap {
                    self.cache.insert($0, for: cacheKey, token: generation) ? $0 : nil
                }
                continuation.resume(returning: image)
            }
        }
    }

    /// 清空全部缓存。
    ///
    /// 线程安全（NSCache 本身线程安全）。在登出等鉴权边界调用，
    /// 确保解密出的明文像素不在进程内残留。
    func clearAll() {
        cache.clear()
    }

    static func decode(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard maxPixelSize > 0,
            let source = CGImageSourceCreateWithData(data as CFData, nil)
        else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
