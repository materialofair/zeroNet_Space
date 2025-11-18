//
//  EncryptionService.swift
//  ZeroNet-Space
//
//  文件加密/解密服务
//  使用AES-256-GCM加密算法
//

import CommonCrypto
import CryptoKit
import Foundation

/// 加密错误类型
enum EncryptionError: Error {
    case invalidPassword  // 无效密码
    case encryptionFailed(underlying: Error?)  // 加密失败（包含底层错误）
    case decryptionFailed(underlying: Error?)  // 解密失败（包含底层错误）
    case invalidData  // 无效数据
    case keyDerivationFailed  // 密钥派生失败
    case dataCorrupted  // 数据损坏或被篡改
    case fileTooLarge(size: Int64, limit: Int64)  // 文件过大
    case fileNotFound(path: String)  // 文件不存在
    case fileAccessDenied(path: String)  // 文件访问权限不足
    case insufficientStorage  // 存储空间不足
    case ioError(underlying: Error)  // IO错误

    var localizedDescription: String {
        switch self {
        case .invalidPassword:
            return String(localized: "encryptionError.invalidPassword")
        case .encryptionFailed(let error):
            if let error = error {
                return String(
                    format: String(localized: "encryptionError.encryptFailedWithReason"),
                    error.localizedDescription)
            }
            return String(localized: "encryptionError.encryptFailed")
        case .decryptionFailed(let error):
            if let error = error {
                return String(
                    format: String(localized: "encryptionError.decryptFailedWithReason"),
                    error.localizedDescription)
            }
            return String(localized: "encryptionError.decryptFailed")
        case .invalidData:
            return String(localized: "encryptionError.invalidData")
        case .keyDerivationFailed:
            return String(localized: "encryptionError.keyDerivationFailed")
        case .dataCorrupted:
            return String(localized: "encryptionError.dataCorrupted")
        case .fileTooLarge(let size, let limit):
            let sizeMB = Double(size) / (1024 * 1024)
            let limitMB = Double(limit) / (1024 * 1024)
            return String(
                format: String(localized: "encryptionError.fileTooLargeDetail"),
                sizeMB,
                limitMB)
        case .fileNotFound(let path):
            return String(
                format: String(localized: "encryptionError.fileNotFound"),
                path)
        case .fileAccessDenied(let path):
            return String(
                format: String(localized: "encryptionError.accessDenied"),
                path)
        case .insufficientStorage:
            return String(localized: "encryptionError.storageInsufficient")
        case .ioError(let error):
            return String(
                format: String(localized: "encryptionError.ioError"),
                error.localizedDescription)
        }
    }
}

/// 加密服务
/// 提供AES-256-GCM加密和解密功能
class EncryptionService {

    // MARK: - Singleton

    static let shared = EncryptionService()
    private init() {}

    // MARK: - Constants

    private let saltLength = AppConstants.saltLength  // 16字节
    private let ivLength = AppConstants.ivLength  // 12字节（GCM推荐）
    private let tagLength = AppConstants.tagLength  // 16字节
    private let iterations = AppConstants.pbkdf2Iterations  // 10万次
    private let chunkMagic = "ZNSC".data(using: .utf8)!
    private let chunkVersion: UInt8 = 1
    private let chunkSize = 4 * 1024 * 1024  // 4MB
    private let maxFileSize: Int64 = 500 * 1024 * 1024  // 500MB（单个文件限制）
    private let minFreeSpace: Int64 = 100 * 1024 * 1024  // 100MB（最小可用空间）

    // MARK: - Public Methods

    /// 加密数据
    /// - Parameters:
    ///   - data: 原始数据
    ///   - password: 用户密码
    /// - Returns: 加密后的数据（格式：盐值 + IV + 标签 + 密文）
    /// - Throws: EncryptionError
    func encrypt(data: Data, password: String) throws -> Data {
        guard !password.isEmpty else {
            throw EncryptionError.invalidPassword
        }

        // 1. 生成随机盐值
        let salt = generateSalt()

        // 2. 从密码派生加密密钥
        let key = try deriveKey(from: password, salt: salt)

        // 3. 生成随机IV（初始化向量）
        let iv = generateIV()

        // 4. 使用AES-GCM加密
        do {
            let sealedBox = try AES.GCM.seal(
                data,
                using: key,
                nonce: AES.GCM.Nonce(data: iv)
            )

            guard let ciphertext = sealedBox.ciphertext.withUnsafeBytes({ Data($0) }) as Data?,
                let tag = sealedBox.tag.withUnsafeBytes({ Data($0) }) as Data?
            else {
                throw EncryptionError.encryptionFailed(underlying: nil)
            }

            // 5. 组合：盐值(16) + IV(12) + 标签(16) + 密文(N)
            var encryptedData = Data()
            encryptedData.append(salt)
            encryptedData.append(iv)
            encryptedData.append(tag)
            encryptedData.append(ciphertext)

            print("🔐 数据加密成功：\(data.count) bytes → \(encryptedData.count) bytes")
            return encryptedData

        } catch {
            print("❌ 加密失败: \(error.localizedDescription)")
            throw EncryptionError.encryptionFailed(underlying: error)
        }
    }

    /// 解密数据
    /// - Parameters:
    ///   - encryptedData: 加密的数据
    ///   - password: 用户密码
    /// - Returns: 解密后的原始数据
    /// - Throws: EncryptionError
    func decrypt(encryptedData: Data, password: String) throws -> Data {
        guard !password.isEmpty else {
            throw EncryptionError.invalidPassword
        }

        // 验证数据长度
        let minLength = saltLength + ivLength + tagLength
        guard encryptedData.count > minLength else {
            throw EncryptionError.invalidData
        }

        // 1. 解析加密数据：盐值 + IV + 标签 + 密文
        let salt = encryptedData.subdata(in: 0..<saltLength)
        let iv = encryptedData.subdata(in: saltLength..<(saltLength + ivLength))
        let tag = encryptedData.subdata(
            in: (saltLength + ivLength)..<(saltLength + ivLength + tagLength))
        let ciphertext = encryptedData.subdata(
            in: (saltLength + ivLength + tagLength)..<encryptedData.count)

        // 2. 从密码派生密钥（使用相同的盐值）
        let key = try deriveKey(from: password, salt: salt)

        // 3. 使用AES-GCM解密
        do {
            let sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: iv),
                ciphertext: ciphertext,
                tag: tag
            )

            let decryptedData = try AES.GCM.open(sealedBox, using: key)

            print("🔓 数据解密成功：\(encryptedData.count) bytes → \(decryptedData.count) bytes")
            return decryptedData

        } catch CryptoKitError.authenticationFailure {
            // 认证失败 - 密码错误或数据被篡改
            print("❌ 解密失败：认证失败（密码错误或数据被篡改）")
            throw EncryptionError.dataCorrupted
        } catch {
            print("❌ 解密失败: \(error.localizedDescription)")
            throw EncryptionError.decryptionFailed(underlying: error)
        }
    }

    // MARK: - Convenience Methods

    /// 加密文件
    /// - Parameters:
    ///   - fileURL: 文件URL
    ///   - password: 密码
    /// - Returns: 加密后的数据
    /// - Throws: EncryptionError
    func encryptFile(at fileURL: URL, password: String) throws -> Data {
        // 1. 检查文件是否存在
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw EncryptionError.fileNotFound(path: fileURL.path)
        }

        // 2. 检查文件是否可读
        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            throw EncryptionError.fileAccessDenied(path: fileURL.path)
        }

        // 3. 检查文件大小
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            if fileSize > maxFileSize {
                throw EncryptionError.fileTooLarge(size: fileSize, limit: maxFileSize)
            }

            // 4. 检查存储空间（加密后大小会稍大）
            let requiredSpace = Int64(Double(fileSize) * 1.1) + minFreeSpace
            if let freeSpace = try? getFreeSpace(), freeSpace < requiredSpace {
                throw EncryptionError.insufficientStorage
            }
        } catch let error as EncryptionError {
            throw error
        } catch {
            throw EncryptionError.ioError(underlying: error)
        }

        // 5. 读取并加密
        do {
            let data = try Data(contentsOf: fileURL)
            return try encrypt(data: data, password: password)
        } catch let error as EncryptionError {
            throw error
        } catch {
            throw EncryptionError.ioError(underlying: error)
        }
    }

    /// 解密并保存到文件
    /// - Parameters:
    ///   - encryptedData: 加密数据
    ///   - fileURL: 目标文件URL
    ///   - password: 密码
    /// - Throws: EncryptionError
    func decryptAndSave(encryptedData: Data, to fileURL: URL, password: String) throws {
        // 1. 解密数据
        let decryptedData = try decrypt(encryptedData: encryptedData, password: password)

        // 2. 检查存储空间
        let requiredSpace = Int64(decryptedData.count) + minFreeSpace
        if let freeSpace = try? getFreeSpace(), freeSpace < requiredSpace {
            throw EncryptionError.insufficientStorage
        }

        // 3. 检查目标目录是否可写
        let parentDir = fileURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parentDir.path) else {
            throw EncryptionError.fileAccessDenied(path: parentDir.path)
        }

        // 4. 写入文件
        do {
            try decryptedData.write(to: fileURL, options: .atomic)
        } catch {
            throw EncryptionError.ioError(underlying: error)
        }
    }

    /// 流式加密文件，避免一次性占用大量内存
    func encryptFile(
        inputURL: URL,
        to outputURL: URL,
        password: String,
        preferredChunkSize: Int? = nil
    ) throws {
        guard !password.isEmpty else {
            throw EncryptionError.invalidPassword
        }

        let chunkSize = max(256 * 1024, preferredChunkSize ?? self.chunkSize)
        let salt = generateSalt()
        let key = try deriveKey(from: password, salt: salt)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)

        let reader = try FileHandle(forReadingFrom: inputURL)
        let writer = try FileHandle(forWritingTo: outputURL)

        // 写入头部
        var header = Data()
        header.append(chunkMagic)
        header.append(chunkVersion)
        header.append(0)  // 保留字段
        let chunkIndicator = UInt16(min(UInt32(chunkSize / 1024), UInt32(UInt16.max)))
        header.append(chunkIndicator.bigEndianData)
        header.append(salt)
        writer.write(header)

        defer {
            try? reader.close()
            try? writer.close()
        }

        while true {
            let shouldBreak = try autoreleasepool { () -> Bool in
                let chunk = reader.readData(ofLength: chunkSize)
                if chunk.isEmpty {
                    writer.write(UInt32(0).bigEndianData)
                    return true
                }

                do {
                    let iv = generateIV()
                    let sealed = try AES.GCM.seal(
                        chunk,
                        using: key,
                        nonce: AES.GCM.Nonce(data: iv)
                    )

                    writer.write(UInt32(sealed.ciphertext.count).bigEndianData)
                    writer.write(iv)
                    writer.write(sealed.tag)
                    writer.write(sealed.ciphertext)
                    return false
                } catch {
                    print("❌ 流式加密失败: \(error)")
                    throw EncryptionError.encryptionFailed(underlying: error)
                }
            }
            
            if shouldBreak {
                break
            }
        }
    }

    /// 流式解密文件
    func decryptFile(
        inputURL: URL,
        to outputURL: URL,
        password: String
    ) throws {
        guard !password.isEmpty else {
            throw EncryptionError.invalidPassword
        }

        let reader = try FileHandle(forReadingFrom: inputURL)
        defer { try? reader.close() }

        let magic = reader.readData(ofLength: chunkMagic.count)
        guard magic == chunkMagic else {
            try reader.seek(toOffset: 0)
            let encryptedData = try Data(contentsOf: inputURL)
            let decrypted = try decrypt(encryptedData: encryptedData, password: password)
            try decrypted.write(to: outputURL)
            return
        }

        let versionData = reader.readData(ofLength: 1)
        guard versionData.first == chunkVersion else {
            throw EncryptionError.invalidData
        }

        _ = reader.readData(ofLength: 1)  // reserved
        _ = reader.readData(ofLength: 2)  // chunk indicator
        let salt = reader.readData(ofLength: saltLength)

        let key = try deriveKey(from: password, salt: salt)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        let writer = try FileHandle(forWritingTo: outputURL)
        defer { try? writer.close() }

        while true {
            let shouldBreak = try autoreleasepool { () -> Bool in
                let lengthData = reader.readData(ofLength: 4)
                if lengthData.count < 4 {
                    return true
                }
                let length = UInt32(bigEndianData: lengthData)
                if length == 0 {
                    return true
                }

                let iv = reader.readData(ofLength: ivLength)
                let tag = reader.readData(ofLength: tagLength)
                let ciphertext = reader.readData(ofLength: Int(length))

                do {
                    let sealed = try AES.GCM.SealedBox(
                        nonce: AES.GCM.Nonce(data: iv),
                        ciphertext: ciphertext,
                        tag: tag
                    )

                    let plaintext = try AES.GCM.open(sealed, using: key)
                    writer.write(plaintext)
                    return false
                } catch {
                    print("❌ 流式解密失败: \(error)")
                    throw EncryptionError.decryptionFailed(underlying: error)
                }
            }

            if shouldBreak {
                break
            }
        }
    }

    // MARK: - Private Methods

    /// 获取可用存储空间
    private func getFreeSpace() throws -> Int64 {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return capacity
            }
            // Fallback to volumeAvailableCapacityKey
            let fallbackValues = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return Int64(fallbackValues.volumeAvailableCapacity ?? 0)
        } catch {
            throw EncryptionError.ioError(underlying: error)
        }
    }

    /// 生成随机盐值
    private func generateSalt() -> Data {
        var salt = Data(count: saltLength)
        _ = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, saltLength, bytes.baseAddress!)
        }
        return salt
    }

    /// 生成随机IV（初始化向量）
    private func generateIV() -> Data {
        var iv = Data(count: ivLength)
        _ = iv.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, ivLength, bytes.baseAddress!)
        }
        return iv
    }

    /// 从密码派生加密密钥（使用PBKDF2）
    /// - Parameters:
    ///   - password: 用户密码
    ///   - salt: 盐值
    /// - Returns: 256位对称密钥
    /// - Throws: EncryptionError
    private func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw EncryptionError.invalidPassword
        }

        // 使用PBKDF2派生密钥
        // 参数：10万次迭代，SHA-256哈希，32字节输出（256位）
        let derivedKey = try deriveKeyPBKDF2(
            password: passwordData,
            salt: salt,
            iterations: iterations,
            keyLength: 32
        )

        return SymmetricKey(data: derivedKey)
    }

    /// PBKDF2密钥派生
    private func deriveKeyPBKDF2(
        password: Data,
        salt: Data,
        iterations: Int,
        keyLength: Int
    ) throws -> Data {
        var derivedKeyData = Data(count: keyLength)

        let result = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard result == kCCSuccess else {
            throw EncryptionError.keyDerivationFailed
        }

        return derivedKeyData
    }
}

private extension FixedWidthInteger {
    var bigEndianData: Data {
        var value = bigEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }

    init(bigEndianData data: Data) {
        let count = Swift.min(data.count, MemoryLayout<Self>.size)
        var value: Self = 0
        _ = withUnsafeMutableBytes(of: &value) { buffer in
            buffer.copyBytes(from: data.prefix(count))
        }
        self = Self(bigEndian: value)
    }
}

// CCKeyDerivationPBKDF 需要 CommonCrypto
// 已在上面的实现中使用
