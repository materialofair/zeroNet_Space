//
//  AppSettings.swift
//  ZeroNet-Space
//
//  应用设置管理（UserDefaults包装）
//  管理用户偏好设置
//

internal import Combine
import Foundation
import SwiftUI

/// 离开后自动锁定时长
enum AutoLockTimeout: Int, CaseIterable, Identifiable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case never = -1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .immediately: return String(localized: "settings.autoLock.immediately")
        case .oneMinute: return String(localized: "settings.autoLock.after1min")
        case .fiveMinutes: return String(localized: "settings.autoLock.after5min")
        case .never: return String(localized: "settings.autoLock.never")
        }
    }
}

/// 应用设置管理器
class AppSettings: ObservableObject {

    // MARK: - Singleton

    static let shared = AppSettings()

    // MARK: - UserDefaults

    private let defaults = UserDefaults.standard

    // MARK: - Published Properties

    /// 排序方式
    @Published var sortOrder: MediaItem.SortOrder {
        didSet {
            defaults.set(sortOrder.rawValue, forKey: AppConstants.UserDefaultsKeys.sortOrder)
            print("📝 排序方式已更新: \(sortOrder.rawValue)")
        }
    }

    /// 网格列数
    @Published var gridColumns: Int {
        didSet {
            // 确保在有效范围内
            let validColumns = min(
                max(gridColumns, AppConstants.gridColumnsRange.lowerBound),
                AppConstants.gridColumnsRange.upperBound)
            if validColumns != gridColumns {
                gridColumns = validColumns
            }
            defaults.set(gridColumns, forKey: AppConstants.UserDefaultsKeys.gridColumns)
            print("📝 网格列数已更新: \(gridColumns)")
        }
    }

    /// 是否首次启动
    @Published var isFirstLaunch: Bool {
        didSet {
            defaults.set(isFirstLaunch, forKey: AppConstants.UserDefaultsKeys.isFirstLaunch)
        }
    }

    /// 最后访问时间
    @Published var lastAccessTime: Date {
        didSet {
            defaults.set(lastAccessTime, forKey: AppConstants.UserDefaultsKeys.lastAccessTime)
        }
    }

    /// 是否已解锁无限导入（通过内购）
    @Published var hasUnlockedUnlimited: Bool {
        didSet {
            defaults.set(
                hasUnlockedUnlimited, forKey: AppConstants.UserDefaultsKeys.hasUnlockedUnlimited)
            print("📝 无限导入状态已更新: \(hasUnlockedUnlimited ? "已解锁" : "未解锁")")
        }
    }

    /// 访客模式是否启用
    @Published var guestModeEnabled: Bool {
        didSet {
            defaults.set(guestModeEnabled, forKey: AppConstants.UserDefaultsKeys.guestModeEnabled)
            print("📝 访客模式状态已更新: \(guestModeEnabled ? "已启用" : "未启用")")
        }
    }

    /// 离开后自动锁定时长
    @Published var autoLockTimeout: AutoLockTimeout {
        didSet {
            defaults.set(
                autoLockTimeout.rawValue, forKey: AppConstants.UserDefaultsKeys.autoLockTimeout)
        }
    }

    // MARK: - Initialization

    private init() {
        // 从UserDefaults读取设置
        if let sortOrderString = defaults.string(forKey: AppConstants.UserDefaultsKeys.sortOrder),
            let sortOrder = MediaItem.SortOrder(rawValue: sortOrderString)
        {
            self.sortOrder = sortOrder
        } else {
            self.sortOrder = .dateNewest  // 默认最新优先
        }

        let savedColumns = defaults.integer(forKey: AppConstants.UserDefaultsKeys.gridColumns)
        self.gridColumns = savedColumns > 0 ? savedColumns : AppConstants.defaultGridColumns

        self.isFirstLaunch =
            defaults.object(forKey: AppConstants.UserDefaultsKeys.isFirstLaunch) == nil
            ? true : defaults.bool(forKey: AppConstants.UserDefaultsKeys.isFirstLaunch)

        if let lastAccess = defaults.object(forKey: AppConstants.UserDefaultsKeys.lastAccessTime)
            as? Date
        {
            self.lastAccessTime = lastAccess
        } else {
            self.lastAccessTime = Date()
        }

        self.hasUnlockedUnlimited = defaults.bool(
            forKey: AppConstants.UserDefaultsKeys.hasUnlockedUnlimited)

        self.guestModeEnabled = defaults.bool(
            forKey: AppConstants.UserDefaultsKeys.guestModeEnabled)

        // 未设置时默认"立即锁定"（隐私优先）
        if defaults.object(forKey: AppConstants.UserDefaultsKeys.autoLockTimeout) == nil {
            self.autoLockTimeout = .immediately
        } else {
            self.autoLockTimeout =
                AutoLockTimeout(
                    rawValue: defaults.integer(forKey: AppConstants.UserDefaultsKeys.autoLockTimeout)
                ) ?? .immediately
        }

        // 🎭 检查演示模式状态，如果已启用则自动解锁功能
        if AppConstants.isDemoModeEnabled {
            self.hasUnlockedUnlimited = true
            print("🎭 检测到演示模式已启用 - 自动解锁所有功能")
        }

        print("⚙️ 应用设置已加载")
        print("   - 排序: \(sortOrder.rawValue)")
        print("   - 网格列数: \(gridColumns)")
        print("   - 首次启动: \(isFirstLaunch)")
        print("   - 无限导入: \(hasUnlockedUnlimited ? "已解锁" : "未解锁")")
        print("   - 访客模式: \(guestModeEnabled ? "已启用" : "未启用")")
        print("   - 演示模式: \(AppConstants.isDemoModeEnabled ? "已启用" : "未启用")")
    }

    // MARK: - Public Methods

    /// 重置所有设置为默认值
    func resetToDefaults() {
        sortOrder = .dateNewest
        gridColumns = AppConstants.defaultGridColumns
        isFirstLaunch = false
        lastAccessTime = Date()

        print("🔄 应用设置已重置为默认值")
    }

    /// 更新最后访问时间
    func updateLastAccessTime() {
        lastAccessTime = Date()
    }

    /// 标记已完成首次启动
    func completeFirstLaunch() {
        isFirstLaunch = false
        print("✅ 首次启动已完成")
    }

    // MARK: - Grid Settings

    /// 增加网格列数
    func increaseGridColumns() {
        if gridColumns < AppConstants.gridColumnsRange.upperBound {
            gridColumns += 1
        }
    }

    /// 减少网格列数
    func decreaseGridColumns() {
        if gridColumns > AppConstants.gridColumnsRange.lowerBound {
            gridColumns -= 1
        }
    }

    /// 网格项宽度（根据屏幕宽度和列数计算）
    func gridItemWidth(containerWidth: CGFloat) -> CGFloat {
        let spacing = AppConstants.gridSpacing * CGFloat(gridColumns - 1)
        let padding: CGFloat = 32  // 左右各16
        let availableWidth = containerWidth - spacing - padding
        return availableWidth / CGFloat(gridColumns)
    }

    // MARK: - Statistics

    /// 应用使用时长（自首次启动以来的天数）
    var daysSinceFirstLaunch: Int {
        if isFirstLaunch {
            return 0
        }
        return Calendar.current.dateComponents([.day], from: lastAccessTime, to: Date()).day ?? 0
    }
}

// MARK: - Preview Helper

#if DEBUG
    extension AppSettings {
        /// 预览用的模拟设置
        static var preview: AppSettings {
            let settings = AppSettings.shared
            settings.sortOrder = .dateNewest
            settings.gridColumns = 3
            return settings
        }
    }
#endif
