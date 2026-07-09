//
//  AuthenticationViewModel.swift
//  ZeroNet-Space
//
//  认证逻辑视图模型
//  管理登录、设置密码、认证状态
//

internal import Combine
import Foundation
import SwiftUI

/// 认证视图模型
@MainActor
final class AuthenticationViewModel: ObservableObject {

    // MARK: - Published Properties

    /// 是否已认证
    @Published var isAuthenticated: Bool = false

    /// 是否已设置密码
    @Published var isPasswordSet: Bool = false

    /// 当前输入的密码
    @Published var password: String = ""

    /// 确认密码（设置时使用）
    @Published var confirmPassword: String = ""

    /// 错误消息
    @Published var errorMessage: String?

    /// 是否正在处理
    @Published var isProcessing: Bool = false

    /// 是否显示密码
    @Published var showPassword: Bool = false

    /// 加密用密码（引用语义容器，置换/登出时就地清零）
    @Published private(set) var sessionPasswordData: SecureBytes? {
        willSet {
            // 零化旧密码内存
            sessionPasswordData?.wipe()
        }
    }

    /// 当前登录密码（用户本次输入，用于显示/修改配置）
    @Published private(set) var sessionLoginPassword: String?

    /// 获取会话密码（String格式，仅在需要时转换）
    var sessionPassword: String? {
        sessionPasswordData?.string
    }

    /// 登录失败次数
    @Published private(set) var failedAttempts: Int = 0

    /// 锁定截止时间
    @Published private(set) var lockoutUntil: Date?

    // MARK: - Constants

    private let maxAttempts = 5  // 最多尝试5次
    private let lockoutDuration: TimeInterval = 300  // 锁定5分钟

    // MARK: - Services

    private let keychainService = KeychainService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Task Management

    private var loginTask: Task<Void, Never>?
    private var savePasswordTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        detectAndClearOrphanedKeychain()
        checkPasswordStatus()
        setupNotificationObservers()
    }

    deinit {
        // 取消所有进行中的任务
        loginTask?.cancel()
        savePasswordTask?.cancel()
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // 监听伪装模式解锁通知
        NotificationCenter.default.publisher(for: .unlockFromDisguise)
            .sink { [weak self] notification in
                Task { @MainActor in
                    // 获取解锁模式（owner 或 guest）和密码
                    let mode = notification.userInfo?["mode"] as? String ?? "owner"
                    let password = notification.userInfo?["password"] as? String ?? ""
                    await self?.handleDisguiseUnlock(mode: mode, password: password)
                }
            }
            .store(in: &cancellables)
    }

    private func handleDisguiseUnlock(mode: String, password: String) async {
        print("🔓 收到伪装模式解锁通知 - 模式: \(mode)")

        if mode == "guest" {
            // 访客模式解锁
            await MainActor.run {
                // 保存访客密码
                sessionPasswordData = SecureBytes(password)
                sessionLoginPassword = password
                isAuthenticated = true

                // 设置为访客模式
                GuestModeManager.shared.setAuthenticationMode(.guest)

                print("✅ 伪装模式解锁到访客模式成功")
                print("   isAuthenticated: \(isAuthenticated)")
                print("   currentMode: \(GuestModeManager.shared.currentMode)")
            }
        } else {
            // 主人模式解锁
            do {
                let dataPassword = try await Task.detached {
                    try self.keychainService.retrieveDataPassword(using: password)
                }.value

                await MainActor.run {
                    sessionPasswordData = SecureBytes(dataPassword)
                    sessionLoginPassword = password
                    isAuthenticated = true

                    // 设置为主人模式
                    GuestModeManager.shared.setAuthenticationMode(.owner)

                    print("✅ 伪装模式解锁到主人模式成功")
                    print("   isAuthenticated: \(isAuthenticated)")
                    print("   currentMode: \(GuestModeManager.shared.currentMode)")
                }
            } catch {
                await MainActor.run {
                    print("❌ 获取数据密码失败: \(error)")
                    isAuthenticated = false
                    errorMessage = String(localized: "auth.error.disguiseUnlockFailed")
                }
            }
        }
    }

    // MARK: - Public Methods

    /// 检测并清理孤立的Keychain数据（卸载重装场景）
    private func detectAndClearOrphanedKeychain() {
        let defaults = UserDefaults.standard
        let isAppInitialized = defaults.bool(forKey: AppConstants.UserDefaultsKeys.appInitialized)
        let hasKeychainPassword = keychainService.isPasswordSet()

        // 如果应用未初始化但Keychain有密码 → 说明是卸载重装 → 清空Keychain
        if !isAppInitialized && hasKeychainPassword {
            print("🔄 检测到卸载重装，清空旧的Keychain数据")
            keychainService.clearAllKeychainData()
        }

        // 如果是全新安装，设置初始化标记
        if !isAppInitialized {
            defaults.set(true, forKey: AppConstants.UserDefaultsKeys.appInitialized)
            print("✅ 应用初始化标记已设置")
        }
    }

    /// 检查密码设置状态
    func checkPasswordStatus() {
        isPasswordSet = keychainService.isPasswordSet()
        print("📱 密码状态检查: \(isPasswordSet ? "已设置" : "未设置")")
    }

    /// 设置密码（首次）
    func setupPassword() {
        guard !isProcessing else { return }

        // 清除之前的错误
        errorMessage = nil

        // 验证密码
        let validation = KeychainService.validatePasswordStrength(password)
        guard validation.isValid else {
            errorMessage = validation.message
            return
        }

        // 检查密码匹配
        guard password == confirmPassword else {
            errorMessage = AppConstants.ErrorMessages.passwordMismatch
            return
        }

        isProcessing = true

        // 检查是否为演示密码
        let isDemoPassword = AppConstants.isDemoPassword(password)

        // 异步保存密码
        Task {
            do {
                let dataPassword = try keychainService.savePassword(password)

                // 保存成功
                sessionPasswordData = SecureBytes(dataPassword)
                sessionLoginPassword = password
                isPasswordSet = true
                isAuthenticated = true

                // 设置为主人模式（首次设置密码后直接进入主页）
                GuestModeManager.shared.setAuthenticationMode(.owner)

                // 🎭 如果是演示密码，启用演示模式并解锁所有功能
                if isDemoPassword {
                    AppConstants.enableDemoMode()
                    AppSettings.shared.hasUnlockedUnlimited = true
                    print("🎭 检测到演示密码 - 已自动启用演示模式并解锁所有功能")
                }

                clearFields()

                print("✅ 密码设置成功，已自动登录")
            } catch {
                errorMessage = String(
                    format: String(localized: "auth.error.savePasswordFailed"),
                    error.localizedDescription)
                print("❌ 密码设置失败: \(error)")
            }

            isProcessing = false
        }
    }

    /// 登录验证
    func login() {
        guard !isProcessing else { return }

        // 取消之前的登录任务
        loginTask?.cancel()

        // 清除之前的错误
        errorMessage = nil

        // 🔒 检查是否被锁定
        if let lockoutUntil = lockoutUntil, Date() < lockoutUntil {
            let remaining = Int(lockoutUntil.timeIntervalSinceNow)
            let minutes = remaining / 60
            let seconds = remaining % 60
            if minutes > 0 {
                errorMessage = String(
                    format: String(localized: "auth.error.tooManyAttemptsMinutes"),
                    minutes,
                    seconds)
            } else {
                errorMessage = String(
                    format: String(localized: "auth.error.tooManyAttemptsSeconds"),
                    seconds)
            }
            return
        }

        // 检查密码非空
        guard !password.isEmpty else {
            errorMessage = AppConstants.ErrorMessages.passwordEmpty
            return
        }

        isProcessing = true
        let inputPassword = password

        // 创建新的登录任务
        loginTask = Task(priority: .userInitiated) {
            // 在后台执行耗时的Keychain操作，避免阻塞主线程
            let ownerMatch = await Task.detached {
                self.keychainService.verifyPassword(inputPassword)
            }.value

            let guestMatch = await Task.detached {
                self.keychainService.isGuestPasswordSet()
                    && self.keychainService.verifyGuestPassword(inputPassword)
            }.value

            // 检查任务是否被取消
            guard !Task.isCancelled else {
                await MainActor.run {
                    isProcessing = false
                }
                return
            }

            // 回到主线程更新UI状态
            if ownerMatch {
                do {
                    let dataPassword = try await Task.detached {
                        try self.keychainService.retrieveDataPassword(using: inputPassword)
                    }.value

                    sessionPasswordData = SecureBytes(dataPassword)
                    sessionLoginPassword = inputPassword
                    isAuthenticated = true

                    // 设置为主人模式
                    GuestModeManager.shared.setAuthenticationMode(.owner)

                    // 🎭 如果是演示密码，启用演示模式并解锁所有功能
                    if AppConstants.isDemoPassword(inputPassword) {
                        AppConstants.enableDemoMode()
                        AppSettings.shared.hasUnlockedUnlimited = true
                        print("🎭 检测到演示密码登录 - 已自动启用演示模式并解锁所有功能")
                    }

                    // ✅ 登录成功，重置失败计数
                    failedAttempts = 0
                    lockoutUntil = nil

                    clearFields()
                    print("✅ 登录成功（主人模式）")
                } catch {
                    errorMessage = String(localized: "auth.error.loadKeyFailed")
                    print("❌ 登录失败：\(error)")
                }
            } else if guestMatch {
                // 访客模式登录成功
                // 保存访客密码以便伪装模式解锁时使用
                sessionPasswordData = SecureBytes(inputPassword)
                sessionLoginPassword = inputPassword
                isAuthenticated = true

                // 设置为访客模式
                GuestModeManager.shared.setAuthenticationMode(.guest)

                // ✅ 登录成功，重置失败计数
                failedAttempts = 0
                lockoutUntil = nil

                clearFields()
                print("✅ 登录成功（访客模式）")
            } else {
                // ❌ 两个密码都验证失败
                failedAttempts += 1
                password = ""

                // 检查是否需要锁定
                if failedAttempts >= maxAttempts {
                    lockoutUntil = Date().addingTimeInterval(lockoutDuration)
                    errorMessage = String(
                        format: String(localized: "auth.error.lockedMinutes"),
                        Int(lockoutDuration / 60))
                    print("🔒 账户已锁定 \(Int(lockoutDuration / 60)) 分钟")
                } else {
                    let remaining = maxAttempts - failedAttempts
                    errorMessage = String(
                        format: String(localized: "auth.error.remainingAttempts"),
                        remaining)
                    print("❌ 登录失败：密码错误（剩余尝试次数：\(remaining)）")
                }
            }

            isProcessing = false
        }
    }

    /// 登出
    func logout() {
        isAuthenticated = false

        // 🔒 安全清理密码内存（willSet 中就地清零）
        sessionPasswordData = nil
        sessionLoginPassword = nil

        // 重置访客模式为主人模式
        GuestModeManager.shared.reset()

        clearFields()
        print("👋 用户已登出，密码内存已安全清理")
    }

    /// 切换密码可见性
    func togglePasswordVisibility() {
        showPassword.toggle()
    }

    /// 清除输入字段
    func clearFields() {
        password = ""
        confirmPassword = ""
        errorMessage = nil
    }

    /// 验证密码是否正确
    func verifyPassword(_ password: String) -> Bool {
        return keychainService.verifyPassword(password)
    }

    /// 更新密码（重新加密后调用）
    func updatePassword(oldPassword: String, newPassword: String) throws {
        let dataPassword = try keychainService.changePassword(
            oldPassword: oldPassword,
            newPassword: newPassword
        )
        sessionPasswordData = SecureBytes(dataPassword)
        sessionLoginPassword = newPassword
    }

    // MARK: - Computed Properties

    /// 设置密码按钮是否可用
    var isSetupButtonEnabled: Bool {
        !password.isEmpty && !confirmPassword.isEmpty && !isProcessing
    }

    /// 登录按钮是否可用
    var isLoginButtonEnabled: Bool {
        !password.isEmpty && !isProcessing
    }
}

// MARK: - Password Strength Indicator

extension AuthenticationViewModel {

    /// 密码强度等级
    enum PasswordStrength {
        case weak  // 弱
        case medium  // 中等
        case strong  // 强

        var color: Color {
            switch self {
            case .weak: return .red
            case .medium: return .orange
            case .strong: return .green
            }
        }

        var text: String {
            switch self {
            case .weak: return String(localized: "passwordStrength.weak")
            case .medium: return String(localized: "passwordStrength.medium")
            case .strong: return String(localized: "passwordStrength.strong")
            }
        }
    }

    /// 计算密码强度
    var passwordStrength: PasswordStrength {
        let length = password.count
        let hasNumbers = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasLetters = password.rangeOfCharacter(from: .letters) != nil
        let hasSpecialChars =
            password.rangeOfCharacter(
                from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:',.<>?/")) != nil

        if length < 6 {
            return .weak
        } else if length >= 8 && ((hasNumbers && hasLetters) || hasSpecialChars) {
            return .strong
        } else {
            return .medium
        }
    }
}
