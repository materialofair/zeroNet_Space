//
//  KeychainService.swift
//  ZeroNet-Space
//
//  Keychain密码管理服务
//  功能：安全存储和验证用户密码
//

import CryptoKit
import Foundation
import Security
import UIKit

/// Keychain操作错误类型
enum KeychainError: Error {
    case duplicateItem  // 重复项
    case itemNotFound  // 项不存在
    case invalidData  // 无效数据
    case unexpectedStatus(OSStatus)  // 未预期的状态码

    var localizedDescription: String {
        switch self {
        case .duplicateItem:
            return String(localized: "keychain.error.duplicateItem")
        case .itemNotFound:
            return String(localized: "keychain.error.itemNotFound")
        case .invalidData:
            return String(localized: "keychain.error.invalidData")
        case .unexpectedStatus(let status):
            return String(
                format: String(localized: "keychain.error.status"),
                status)
        }
    }
}

/// Keychain密码管理服务
/// 使用SHA-256哈希 + 随机盐值存储密码
/// 安全级别：kSecAttrAccessibleWhenUnlockedThisDeviceOnly
class KeychainService {

    // MARK: - Singleton

    static let shared = KeychainService()
    private init() {}

    // MARK: - Constants

    private let service = "com.zeronetspace.unlimited-imports"
    private let passwordAccount = "userPassword"
    private let saltAccount = "passwordSalt"
    private let isSetAccount = "isPasswordSet"
    private let dataPasswordAccount = "dataEncryptionPassword"

    // 访客模式相关账户
    private let guestPasswordAccount = "guestPassword"
    private let guestSaltAccount = "guestPasswordSalt"
    private let isGuestSetAccount = "isGuestPasswordSet"

    // 计算器登录模式相关账户
    private let disguisePasswordAccount = "disguisePassword"
    private let isDisguiseSetAccount = "isDisguisePasswordSet"

    private let encryptionService = EncryptionService.shared

    // MARK: - Public Methods

    /// 保存密码（首次设置）
    /// - Parameter password: 用户密码
    /// - Throws: KeychainError
    @discardableResult
    func savePassword(_ password: String) throws -> String {
        let dataPassword = password
        try storeLoginPassword(password)
        try storeDataPassword(dataPassword, using: password)
        print("✅ 密码已安全保存到Keychain")
        return dataPassword
    }

    /// 验证密码
    /// - Parameter password: 用户输入的密码
    /// - Returns: 密码是否正确
    func verifyPassword(_ password: String) -> Bool {
        do {
            // 读取保存的哈希和盐值
            let savedHash = try readFromKeychain(account: passwordAccount)
            let salt = try readFromKeychain(account: saltAccount)

            // 计算输入密码的哈希
            let inputHash = hashPassword(password, salt: salt)

            // 对比哈希值
            return savedHash == inputHash
        } catch {
            print("❌ 密码验证失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 检查是否已设置密码
    /// - Returns: 是否已设置密码
    func isPasswordSet() -> Bool {
        do {
            let data = try readFromKeychain(account: isSetAccount)
            return data.first == 1
        } catch {
            return false
        }
    }

    /// 删除密码（重置应用）
    /// - Throws: KeychainError
    func deletePassword() throws {
        try deleteFromKeychain(account: passwordAccount)
        try deleteFromKeychain(account: saltAccount)
        try deleteFromKeychain(account: isSetAccount)
        try deleteFromKeychain(account: dataPasswordAccount)

        print("✅ 密码已从Keychain删除")
    }

    /// 清空所有Keychain数据（包括主密码、访客密码、计算器登录密码）
    /// 用于卸载重装后的数据清理
    func clearAllKeychainData() {
        // 清空主密码
        try? deleteFromKeychain(account: passwordAccount)
        try? deleteFromKeychain(account: saltAccount)
        try? deleteFromKeychain(account: isSetAccount)
        try? deleteFromKeychain(account: dataPasswordAccount)

        // 清空访客密码
        try? deleteFromKeychain(account: guestPasswordAccount)
        try? deleteFromKeychain(account: guestSaltAccount)
        try? deleteFromKeychain(account: isGuestSetAccount)

        // 清空计算器登录密码
        try? deleteFromKeychain(account: disguisePasswordAccount)
        try? deleteFromKeychain(account: isDisguiseSetAccount)

        print("✅ 已清空所有Keychain数据（卸载重装检测）")
    }

    /// 更改密码
    /// - Parameters:
    ///   - oldPassword: 旧密码
    ///   - newPassword: 新密码
    /// - Throws: KeychainError
    @discardableResult
    func changePassword(oldPassword: String, newPassword: String) throws -> String {
        guard verifyPassword(oldPassword) else {
            throw KeychainError.invalidData
        }

        let dataPassword = try retrieveDataPassword(using: oldPassword)
        try storeLoginPassword(newPassword)
        try storeDataPassword(dataPassword, using: newPassword)

        // 🎭 自动同步计算器登录模式密码序列（如果计算器登录模式已启用）
        let disguiseModeEnabled = UserDefaults.standard.bool(
            forKey: AppConstants.UserDefaultsKeys.disguiseModeEnabled
        )
        if disguiseModeEnabled {
            do {
                try saveDisguisePassword(newPassword)
                print("✅ 计算器登录模式密码序列已自动同步为新密码")
            } catch {
                print("⚠️ 同步计算器登录密码序列失败: \(error)")
            }
        }

        print("✅ 密码已成功更改")
        return dataPassword
    }

    func retrieveDataPassword(using loginPassword: String) throws -> String {
        do {
            let encrypted = try readFromKeychain(account: dataPasswordAccount)
            let decrypted = try encryptionService.decrypt(
                encryptedData: encrypted,
                password: loginPassword
            )
            guard let string = String(data: decrypted, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return string
        } catch let error as KeychainError {
            if case .itemNotFound = error {
                // 兼容旧版本：使用登录密码本身作为数据密码
                try storeDataPassword(loginPassword, using: loginPassword)
                return loginPassword
            }
            throw error
        } catch {
            throw KeychainError.invalidData
        }
    }

    // MARK: - Private Methods

    /// 生成随机盐值（16字节）
    private func generateSalt() -> Data {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 16, bytes.baseAddress!)
        }
        return salt
    }

    /// 保存登录密码哈希和盐
    private func storeLoginPassword(_ password: String) throws {
        let salt = generateSalt()
        let hash = hashPassword(password, salt: salt)
        try saveToKeychain(account: passwordAccount, data: hash)
        try saveToKeychain(account: saltAccount, data: salt)
        try saveToKeychain(account: isSetAccount, data: Data([1]))
    }

    /// 保存数据加密密码（使用登录密码加密）
    private func storeDataPassword(_ dataPassword: String, using loginPassword: String) throws {
        let data = Data(dataPassword.utf8)
        let encrypted = try encryptionService.encrypt(data: data, password: loginPassword)
        try saveToKeychain(account: dataPasswordAccount, data: encrypted)
    }

    /// 使用SHA-256哈希密码
    /// - Parameters:
    ///   - password: 密码字符串
    ///   - salt: 盐值
    /// - Returns: 哈希值
    private func hashPassword(_ password: String, salt: Data) -> Data {
        let passwordData = Data(password.utf8)
        let combined = passwordData + salt
        let hash = SHA256.hash(data: combined)
        return Data(hash)
    }

    /// 保存数据到Keychain
    private func saveToKeychain(account: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        // 先尝试删除已存在的项
        SecItemDelete(query as CFDictionary)

        // 添加新项
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 从Keychain读取数据
    private func readFromKeychain(account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    /// 从Keychain删除数据
    private func deleteFromKeychain(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

// MARK: - Guest Mode Password Management

extension KeychainService {

    /// 保存访客密码
    /// - Parameter password: 访客密码（必须是纯数字）
    /// - Throws: KeychainError
    func saveGuestPassword(_ password: String) throws {
        // 1. 验证必须是纯数字
        guard password.allSatisfy({ $0.isNumber }), password.count >= 6, password.count <= 8 else {
            throw KeychainError.invalidData
        }

        // 2. 服务层校验：访客密码不能与主密码相同（安全约束）
        guard !verifyPassword(password) else {
            throw KeychainError.invalidData
        }

        let salt = generateSalt()
        let hash = hashPassword(password, salt: salt)

        try saveToKeychain(account: guestPasswordAccount, data: hash)
        try saveToKeychain(account: guestSaltAccount, data: salt)
        try saveToKeychain(account: isGuestSetAccount, data: Data([1]))

        print("✅ 访客密码已安全保存到Keychain")
    }

    /// 验证访客密码
    /// - Parameter password: 用户输入的密码
    /// - Returns: 密码是否正确
    func verifyGuestPassword(_ password: String) -> Bool {
        do {
            let savedHash = try readFromKeychain(account: guestPasswordAccount)
            let salt = try readFromKeychain(account: guestSaltAccount)
            let inputHash = hashPassword(password, salt: salt)
            return savedHash == inputHash
        } catch {
            return false
        }
    }

    /// 检查是否已设置访客密码
    /// - Returns: 是否已设置访客密码
    func isGuestPasswordSet() -> Bool {
        do {
            let data = try readFromKeychain(account: isGuestSetAccount)
            return data.first == 1
        } catch {
            return false
        }
    }

    /// 删除访客密码
    /// - Throws: KeychainError
    func deleteGuestPassword() throws {
        try deleteFromKeychain(account: guestPasswordAccount)
        try deleteFromKeychain(account: guestSaltAccount)
        try deleteFromKeychain(account: isGuestSetAccount)
        print("✅ 访客密码已从Keychain删除")
    }

    /// 验证访客密码格式（纯数字，6-8位）
    /// - Parameter password: 密码
    /// - Returns: (是否有效, 错误信息)
    static func validateGuestPassword(_ password: String) -> (isValid: Bool, message: String?) {
        if password.isEmpty {
            return (false, String(localized: "guestPassword.error.empty"))
        }

        if !password.allSatisfy({ $0.isNumber }) {
            return (false, String(localized: "guestPassword.error.numeric"))
        }

        if password.count < 6 {
            return (false, String(localized: "guestPassword.error.minLength"))
        }

        if password.count > 8 {
            return (false, String(localized: "guestPassword.error.maxLength"))
        }

        return (true, nil)
    }
}

// MARK: - Password Validation

extension KeychainService {

    /// 验证密码强度
    /// - Parameter password: 密码
    /// - Returns: (是否有效, 错误信息)
    static func validatePasswordStrength(_ password: String) -> (isValid: Bool, message: String?) {
        if password.isEmpty {
            return (false, AppConstants.ErrorMessages.passwordEmpty)
        }

        if password.count < 6 {
            return (false, AppConstants.ErrorMessages.passwordTooShort)
        }

        if password.count > 128 {
            return (false, AppConstants.ErrorMessages.passwordTooLong)
        }

        return (true, nil)
    }
}

// MARK: - Disguise Mode Password Management

extension KeychainService {

    /// 保存计算器登录模式密码（加密存储）
    /// - Parameter password: 计算器登录密码（仅数字和小数点）
    /// - Throws: KeychainError
    func saveDisguisePassword(_ password: String) throws {
        // 1. 验证计算器登录密码格式（仅数字和小数点）
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        let passwordCharacters = CharacterSet(charactersIn: password)
        guard passwordCharacters.isSubset(of: allowedCharacters), password.count >= 4 else {
            throw KeychainError.invalidData
        }

        // 2. 使用设备唯一标识生成加密密钥
        let deviceKey =
            "ZNS_DISGUISE_\(UIDevice.current.identifierForVendor?.uuidString ?? "DEFAULT")"

        // 3. 加密计算器登录密码
        let passwordData = Data(password.utf8)
        let encryptedData = try encryptionService.encrypt(data: passwordData, password: deviceKey)

        // 4. 存储到 Keychain
        try saveToKeychain(account: disguisePasswordAccount, data: encryptedData)
        try saveToKeychain(account: isDisguiseSetAccount, data: Data([1]))

        print("✅ 计算器登录密码已加密并安全保存到Keychain")
    }

    /// 读取计算器登录模式密码
    /// - Returns: 计算器登录密码，如果未设置返回 nil
    func loadDisguisePassword() -> String? {
        do {
            // 1. 从 Keychain 读取加密数据
            let encryptedData = try readFromKeychain(account: disguisePasswordAccount)

            // 2. 使用设备唯一标识解密
            let deviceKey =
                "ZNS_DISGUISE_\(UIDevice.current.identifierForVendor?.uuidString ?? "DEFAULT")"
            let decryptedData = try encryptionService.decrypt(
                encryptedData: encryptedData,
                password: deviceKey
            )

            // 3. 转换为字符串
            guard let password = String(data: decryptedData, encoding: .utf8) else {
                print("❌ 计算器登录密码解密失败：数据格式错误")
                return nil
            }

            return password
        } catch KeychainError.itemNotFound {
            // 计算器登录密码未设置，返回 nil
            return nil
        } catch {
            print("❌ 读取计算器登录密码失败: \(error)")
            return nil
        }
    }

    /// 检查是否已设置伪装密码
    /// - Returns: 是否已设置伪装密码
    func isDisguisePasswordSet() -> Bool {
        do {
            let data = try readFromKeychain(account: isDisguiseSetAccount)
            return data.first == 1
        } catch {
            return false
        }
    }

    /// 删除伪装密码
    /// - Throws: KeychainError
    func deleteDisguisePassword() throws {
        try deleteFromKeychain(account: disguisePasswordAccount)
        try deleteFromKeychain(account: isDisguiseSetAccount)
        print("✅ 伪装密码已从Keychain删除")
    }

    /// 迁移旧的 UserDefaults 伪装密码到 Keychain
    /// - Returns: 是否成功迁移
    @discardableResult
    func migrateDisguisePasswordFromUserDefaults() -> Bool {
        // 检查是否已经设置了 Keychain 密码
        if isDisguisePasswordSet() {
            return false
        }

        // 尝试从 UserDefaults 读取旧密码
        if let oldPassword = UserDefaults.standard.string(
            forKey: AppConstants.UserDefaultsKeys.disguisePasswordSequence
        ), !oldPassword.isEmpty {
            do {
                // 保存到 Keychain
                try saveDisguisePassword(oldPassword)

                // 从 UserDefaults 删除（安全清理）
                UserDefaults.standard.removeObject(
                    forKey: AppConstants.UserDefaultsKeys.disguisePasswordSequence
                )

                print("✅ 已将伪装密码从 UserDefaults 迁移到 Keychain")
                return true
            } catch {
                print("❌ 伪装密码迁移失败: \(error)")
                return false
            }
        }

        return false
    }
}
