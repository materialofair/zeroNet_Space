//
//  PurchaseManager.swift
//  ZeroNet-Space
//
//  内购管理器
//  使用StoreKit 2处理应用内购买
//

import Foundation
import StoreKit

/// 内购产品ID
enum PurchaseProduct: String, CaseIterable {
    // Keep this ID in sync with Products.storekit so StoreKit can return the stubbed item.
    case unlimitedImport = "com.zeronetspace.unlimited_imports"

    var displayName: String {
        switch self {
        case .unlimitedImport:
            return String(localized: "iap.unlimitedImport.name")
        }
    }

    var description: String {
        switch self {
        case .unlimitedImport:
            return String(localized: "iap.unlimitedImport.description")
        }
    }
}

/// 内购管理器
@MainActor
class PurchaseManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PurchaseManager()

    // MARK: - Published Properties

    /// 是否正在加载
    @Published var isLoading = false

    /// 购买错误信息
    @Published var purchaseError: String?

    /// 可用的产品
    @Published private(set) var products: [Product] = []

    /// 是否已解锁无限导入
    @Published private(set) var hasUnlockedUnlimited = false

    /// 购买状态监听任务
    private var updateListenerTask: Task<Void, Error>?

    /// 是否已初始化 StoreKit（用于延迟加载，避免触发网络权限）
    private var isStoreKitInitialized = false

    // MARK: - Initialization

    private init() {
        // 🔴 重要：不在 init 中初始化 StoreKit，避免触发网络权限请求
        // StoreKit 会在首次调用 loadProducts() 或 purchase() 时才初始化

        // 🎭 检查演示模式
        if AppConstants.isDemoModeEnabled {
            hasUnlockedUnlimited = true
            print("🎭 PurchaseManager初始化 - 检测到演示模式，自动解锁")
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Lazy Initialization

    /// 延迟初始化 StoreKit（仅在首次需要时调用）
    private func initializeStoreKitIfNeeded() {
        guard !isStoreKitInitialized else { return }

        isStoreKitInitialized = true

        // 启动购买状态监听
        updateListenerTask = listenForTransactions()

        // 检查已购买的产品
        Task {
            await updatePurchaseStatus()
        }
    }

    // MARK: - Public Methods

    /// 加载产品信息
    func loadProducts() async {
        // 🔴 延迟初始化：仅在用户主动访问内购功能时才初始化 StoreKit
        initializeStoreKitIfNeeded()

        isLoading = true
        purchaseError = nil

        do {
            // 从App Store加载产品
            let productIds = PurchaseProduct.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIds)

            print("✅ 成功加载 \(products.count) 个内购产品")

            // 检查购买状态
            await updatePurchaseStatus()

        } catch {
            print("❌ 加载产品失败: \(error)")
            purchaseError = String(localized: "iap.error.loadFailed")
        }

        isLoading = false
    }

    /// 购买产品
    func purchase() async -> Bool {
        // 🔴 延迟初始化：仅在用户主动购买时才初始化 StoreKit
        initializeStoreKitIfNeeded()

        guard
            let product = products.first(where: {
                $0.id == PurchaseProduct.unlimitedImport.rawValue
            })
        else {
            purchaseError = String(localized: "iap.error.productNotFound")
            return false
        }

        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // 验证交易
                let transaction = try checkVerified(verification)

                // 更新购买状态
                await updatePurchaseStatus()

                // 完成交易
                await transaction.finish()

                print("✅ 购买成功")
                isLoading = false
                return true

            case .userCancelled:
                print("ℹ️ 用户取消购买")
                purchaseError = String(localized: "iap.error.cancelled")
                isLoading = false
                return false

            case .pending:
                print("⏳ 购买等待中（需要家长批准等）")
                purchaseError = String(localized: "iap.error.pending")
                isLoading = false
                return false

            @unknown default:
                print("❌ 未知购买结果")
                purchaseError = String(localized: "iap.error.unknown")
                isLoading = false
                return false
            }

        } catch {
            print("❌ 购买失败: \(error)")

            // Check if it's a network-related error
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                // Network error from StoreKit
                purchaseError = String(localized: "network.iap.alert.message")
            } else {
                // Other purchase errors
                purchaseError = String(localized: "iap.error.purchaseFailed")
            }

            isLoading = false
            return false
        }
    }

    /// 恢复购买
    func restorePurchases() async {
        // 🔴 延迟初始化：仅在用户主动恢复购买时才初始化 StoreKit
        initializeStoreKitIfNeeded()

        isLoading = true
        purchaseError = nil

        do {
            try await AppStore.sync()
            await updatePurchaseStatus()

            if hasUnlockedUnlimited {
                print("✅ 成功恢复购买")
            } else {
                print("ℹ️ 没有可恢复的购买")
                purchaseError = String(localized: "iap.error.noPurchaseToRestore")
            }
        } catch {
            print("❌ 恢复购买失败: \(error)")
            purchaseError = String(localized: "iap.error.restoreFailed")
        }

        isLoading = false
    }

    /// 获取价格字符串
    func getPriceString() -> String {
        guard
            let product = products.first(where: {
                $0.id == PurchaseProduct.unlimitedImport.rawValue
            })
        else {
            return "..."
        }
        return product.displayPrice
    }

    // MARK: - Private Methods

    /// 监听交易更新
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // 监听交易更新
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // 更新购买状态
                    await self.updatePurchaseStatus()

                    // 完成交易
                    await transaction.finish()
                } catch {
                    print("❌ 交易验证失败: \(error)")
                }
            }
        }
    }

    /// 更新购买状态
    private func updatePurchaseStatus() async {
        // 🎭 如果启用了演示模式，直接解锁
        if AppConstants.isDemoModeEnabled {
            hasUnlockedUnlimited = true
            print("🎭 演示模式已启用 - 自动解锁无限导入")
            return
        }

        var unlocked = false

        // 检查所有当前的权利
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // 检查是否是无限导入产品
                if transaction.productID == PurchaseProduct.unlimitedImport.rawValue {
                    unlocked = true
                }
            } catch {
                print("❌ 验证交易失败: \(error)")
            }
        }

        hasUnlockedUnlimited = unlocked
        print("📊 购买状态更新: \(unlocked ? "已解锁" : "未解锁")")
    }

    /// 验证交易
    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            // 未通过StoreKit验证
            throw PurchaseError.failedVerification
        case .verified(let safe):
            // 通过验证,返回安全的数据
            return safe
        }
    }
}

// MARK: - Purchase Error

enum PurchaseError: LocalizedError {
    case failedVerification
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return String(localized: "iap.error.verification")
        case .productNotFound:
            return String(localized: "iap.error.productNotFound")
        }
    }
}
