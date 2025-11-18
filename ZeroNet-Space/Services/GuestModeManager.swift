//
//  GuestModeManager.swift
//  ZeroNet_Space
//
//  Created by Claude on 2025-01-17.
//  访客模式管理器 - 管理认证模式和内容可见性
//

internal import Combine
import Foundation

/// 访客模式管理器
/// 功能：
/// 1. 跟踪当前认证模式（主人/访客/未认证）
/// 2. 提供内容可见性控制
/// 3. 会话级别存储（App重启后需重新认证）
///
/// 安全特性：
/// - 默认为未认证状态，防止重启后数据泄露
/// - @MainActor 确保线程安全
@MainActor
final class GuestModeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = GuestModeManager()

    private init() {}

    // MARK: - Published Properties

    /// 当前认证模式
    @Published private(set) var currentMode: AuthenticationMode = .unauthenticated

    // MARK: - Public Methods

    /// 设置认证模式
    /// - Parameter mode: 认证模式（主人/访客/未认证）
    func setAuthenticationMode(_ mode: AuthenticationMode) {
        currentMode = mode
        let modeText: String
        switch mode {
        case .owner: modeText = "主人模式"
        case .guest: modeText = "访客模式"
        case .unauthenticated: modeText = "未认证"
        }
        print("🔐 认证模式已切换为: \(modeText)")
    }

    /// 判断是否应该显示内容
    /// - Returns: 主人模式返回true，访客模式返回false
    var shouldShowContent: Bool {
        return currentMode == .owner
    }

    /// 判断是否为访客模式
    var isGuestMode: Bool {
        return currentMode == .guest
    }

    /// 判断是否为主人模式
    var isOwnerMode: Bool {
        return currentMode == .owner
    }

    /// 重置为未认证状态（用于登出时）
    func reset() {
        currentMode = .unauthenticated
        print("🔐 认证模式已重置为未认证")
    }
}
