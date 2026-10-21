import UIKit

/// Cache invalidation and the last decode insertion share one lock. A decode from
/// before logout cannot repopulate the cache, even when cancellation arrives late.
nonisolated final class SensitiveImageCache: @unchecked Sendable {
    private let lock = NSLock()
    private let cache = NSCache<NSString, UIImage>()
    private var generation = UUID()

    init(countLimit: Int, costLimit: Int) {
        cache.countLimit = countLimit
        cache.totalCostLimit = costLimit
    }

    func token() -> UUID { lock.withLock { generation } }
    func image(for key: String) -> UIImage? {
        lock.withLock { cache.object(forKey: key as NSString) }
    }
    @discardableResult
    func insert(_ image: UIImage, for key: String, token: UUID) -> Bool {
        lock.withLock {
            guard token == generation else { return false }
            cache.setObject(image, forKey: key as NSString,
                            cost: Int(image.size.width * image.scale) * Int(image.size.height * image.scale) * 4)
            return true
        }
    }
    func clear() {
        lock.withLock {
            generation = UUID()
            cache.removeAllObjects()
        }
    }
    func remove(_ key: String) { lock.withLock { cache.removeObject(forKey: key as NSString) } }
}
