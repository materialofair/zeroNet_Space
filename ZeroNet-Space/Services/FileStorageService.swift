//
//  FileStorageService.swift
//  ZeroNet-Space
//
//  文件存储管理服务
//  管理加密文件的保存、读取、删除
//

import Foundation

/// 文件存储错误类型
enum FileStorageError: Error {
    case directoryCreationFailed  // 目录创建失败
    case fileNotFound  // 文件不存在
    case fileSaveFailed  // 文件保存失败
    case fileDeleteFailed  // 文件删除失败
    case insufficientStorage  // 存储空间不足
    case fileTooLarge  // 文件过大
    case invalidPath  // 无效路径

    var localizedDescription: String {
        switch self {
        case .directoryCreationFailed:
            return String(localized: "fileStorage.error.directoryCreation")
        case .fileNotFound:
            return AppConstants.ErrorMessages.fileNotFound
        case .fileSaveFailed:
            return String(localized: "fileStorage.error.fileSave")
        case .fileDeleteFailed:
            return String(localized: "fileStorage.error.fileDelete")
        case .insufficientStorage:
            return AppConstants.ErrorMessages.storageInsufficient
        case .fileTooLarge:
            return AppConstants.ErrorMessages.fileTooLarge
        case .invalidPath:
            return String(localized: "fileStorage.error.invalidPath")
        }
    }
}

/// 文件存储服务
nonisolated class FileStorageService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = FileStorageService()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let storageDirectoryName = AppConstants.encryptedMediaDirectory
    private let fileExtension = AppConstants.encryptedFileExtension
    private let encryptionService = EncryptionService.shared
    private let decryptionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.zeronetspace.media-decryption"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

    // 存储目录URL
    private let storageDirectory: URL

    // MARK: - Initialization

    private init() {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageDirectory = documentsURL.appendingPathComponent(storageDirectoryName)
        // 确保存储目录存在
        createStorageDirectoryIfNeeded()
    }

    // MARK: - Public Methods

    /// 保存加密数据
    /// - Parameters:
    ///   - data: 加密后的数据
    ///   - fileName: 原始文件名（可选，用于生成唯一文件名）
    /// - Returns: 保存后的相对文件路径（仅文件名）
    /// - Throws: FileStorageError
    func saveEncrypted(data: Data, originalFileName: String? = nil) throws -> String {
        // 检查文件大小
        guard data.count <= AppConstants.maxFileSize else {
            throw FileStorageError.fileTooLarge
        }

        // 检查存储空间
        try checkStorageSpace(requiredBytes: Int64(data.count))

        // 生成唯一文件名
        let fileName = generateUniqueFileName(originalName: originalFileName)
        let fileURL = storageDirectory.appendingPathComponent(fileName)

        // 保存文件
        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            print(
                "💾 文件已保存: \(fileName) (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))"
            )
            // 返回相对路径（仅文件名），而不是绝对路径
            return fileName
        } catch {
            print("❌ 文件保存失败: \(error)")
            throw FileStorageError.fileSaveFailed
        }
    }

    /// 保存大文件（流式加密）
    func saveEncryptedFile(
        from sourceURL: URL,
        password: String,
        originalFileName: String? = nil
    ) throws -> String {
        let attributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        try checkStorageSpace(requiredBytes: fileSize)

        let fileName = generateUniqueFileName(originalName: originalFileName)
        let destinationURL = storageDirectory.appendingPathComponent(fileName)

        try encryptionService.encryptFile(
            inputURL: sourceURL,
            to: destinationURL,
            password: password
        )

        return fileName
    }

    /// 读取加密数据
    /// - Parameter path: 文件相对路径（文件名）
    /// - Returns: 加密的数据
    /// - Throws: FileStorageError
    func loadEncrypted(path: String) throws -> Data {
        let fileURL = getFileURL(for: path)

        // 检查文件是否存在
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("❌ 文件不存在: \(fileURL.path)")
            throw FileStorageError.fileNotFound
        }

        // 读取文件
        do {
            let data = try Data(contentsOf: fileURL)
            print(
                "📂 文件已读取: \(fileURL.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))"
            )
            return data
        } catch {
            print("❌ 文件读取失败: \(error)")
            throw FileStorageError.fileNotFound
        }
    }

    /// 删除文件
    /// - Parameter path: 文件相对路径（文件名）
    /// - Throws: FileStorageError
    func deleteFile(path: String) throws {
        let fileURL = getFileURL(for: path)

        // 检查文件是否存在
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("⚠️ 文件不存在，无需删除: \(fileURL.path)")
            return
        }

        // 删除文件
        do {
            try fileManager.removeItem(at: fileURL)
            print("🗑️ 文件已删除: \(fileURL.lastPathComponent)")
        } catch {
            print("❌ 文件删除失败: \(error)")
            throw FileStorageError.fileDeleteFailed
        }
    }

    /// 获取文件大小
    /// - Parameter path: 文件相对路径（文件名）
    /// - Returns: 文件大小（字节）
    func getFileSize(path: String) -> Int64? {
        let fileURL = getFileURL(for: path)

        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }

    /// 检查文件是否存在
    /// - Parameter path: 文件相对路径（文件名）
    /// - Returns: 是否存在
    func fileExists(path: String) -> Bool {
        let fileURL = getFileURL(for: path)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// 获取存储目录路径
    /// - Returns: 存储目录URL
    func getStorageDirectory() -> URL {
        return storageDirectory
    }

    /// 计算总存储大小
    /// - Returns: 总大小（字节）
    func getTotalStorageSize() -> Int64 {
        var totalSize: Int64 = 0

        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: storageDirectory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            )

            for fileURL in fileURLs {
                let resources = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resources.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        } catch {
            print("❌ 计算存储大小失败: \(error)")
        }

        return totalSize
    }

    /// 获取所有加密文件列表
    /// - Returns: 文件路径数组
    func getAllEncryptedFiles() -> [String] {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: storageDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            return
                fileURLs
                .filter {
                    $0.pathExtension
                        == fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                }
                .map { $0.lastPathComponent }
        } catch {
            print("❌ 获取文件列表失败: \(error)")
            return []
        }
    }

    /// 清空所有加密文件
    /// - Throws: FileStorageError
    func clearAllFiles() throws {
        let files = getAllEncryptedFiles()

        for filePath in files {
            try deleteFile(path: filePath)
        }

        print("🗑️ 已清空所有加密文件 (\(files.count)个)")
    }

    // MARK: - Private Methods

    /// 创建存储目录（如果不存在）
    private func createStorageDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: storageDirectory,
                    withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.complete]
                )
                print("📁 存储目录已创建: \(storageDirectory.path)")
            } catch {
                print("❌ 存储目录创建失败: \(error)")
            }
        }
    }

    /// 生成唯一文件名
    /// - Parameter originalName: 原始文件名（可选）
    /// - Returns: 唯一文件名
    private func generateUniqueFileName(originalName: String?) -> String {
        let uuid = UUID().uuidString

        if let originalName = originalName {
            // 保留原始扩展名
            let fileExtension = (originalName as NSString).pathExtension
            if !fileExtension.isEmpty {
                return "\(uuid)_\(originalName)\(self.fileExtension)"
            }
        }

        return "\(uuid)\(fileExtension)"
    }

    /// 检查存储空间
    /// - Parameter requiredBytes: 需要的字节数
    /// - Throws: FileStorageError
    private func checkStorageSpace(requiredBytes: Int64) throws {
        do {
            let systemAttributes = try fileManager.attributesOfFileSystem(
                forPath: storageDirectory.path)

            if let freeSpace = systemAttributes[.systemFreeSize] as? Int64 {
                // 预留100MB安全空间
                let safetyMargin: Int64 = 100 * 1024 * 1024
                let availableSpace = freeSpace - safetyMargin

                if requiredBytes > availableSpace {
                    print(
                        "❌ 存储空间不足: 需要 \(ByteCountFormatter.string(fromByteCount: requiredBytes, countStyle: .file)), 可用 \(ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .file))"
                    )
                    throw FileStorageError.insufficientStorage
                }
            }
        } catch {
            print("⚠️ 无法检查存储空间: \(error)")
            // 不抛出错误，继续尝试保存
        }
    }
}

// MARK: - Storage Statistics

nonisolated extension FileStorageService {

    /// 存储统计信息
    struct StorageStatistics {
        let totalFiles: Int
        let totalSize: Int64
        let formattedSize: String
        let availableSpace: Int64
        let formattedAvailableSpace: String

        init(totalFiles: Int, totalSize: Int64, availableSpace: Int64) {
            self.totalFiles = totalFiles
            self.totalSize = totalSize
            self.formattedSize = ByteCountFormatter.string(
                fromByteCount: totalSize, countStyle: .file)
            self.availableSpace = availableSpace
            self.formattedAvailableSpace = ByteCountFormatter.string(
                fromByteCount: availableSpace, countStyle: .file)
        }
    }

    /// 获取存储统计信息
    /// - Returns: 存储统计
    func getStorageStatistics() -> StorageStatistics {
        let files = getAllEncryptedFiles()
        let totalSize = getTotalStorageSize()

        var availableSpace: Int64 = 0
        do {
            let systemAttributes = try fileManager.attributesOfFileSystem(
                forPath: storageDirectory.path)
            availableSpace = systemAttributes[.systemFreeSize] as? Int64 ?? 0
        } catch {
            print("❌ 获取可用空间失败: \(error)")
        }

        return StorageStatistics(
            totalFiles: files.count,
            totalSize: totalSize,
            availableSpace: availableSpace
        )
    }

    /// 获取存储文件的完整 URL
    func getFileURL(for path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return storageDirectory.appendingPathComponent(path)
    }

    /// 将加密文件解密到临时文件
    func createDecryptedTempFile(
        path: String,
        password: String,
        preferredExtension: String
    ) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString + sanitizedExtension(preferredExtension)
        )

        let sourceURL = getFileURL(for: path)
        do {
            try encryptionService.decryptFile(
                inputURL: sourceURL,
                to: tempURL,
                password: password
            )

            // 明文临时文件必须使用最高文件保护级别，防止锁屏后被读取
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: tempURL.path
            )

            return tempURL
        } catch {
            // 解密失败时清理可能残留的半成品文件
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }

    /// 在受控后台队列中解密媒体，避免翻页或打开播放器时阻塞主线程。
    func createDecryptedTempFileAsync(
        path: String,
        password: String,
        preferredExtension: String
    ) async throws -> URL {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            decryptionQueue.addOperation {
                do {
                    continuation.resume(
                        returning: try self.createDecryptedTempFile(
                            path: path,
                            password: password,
                            preferredExtension: preferredExtension
                        )
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 在受控后台队列中读取并解密文件数据，兼容标准和流式加密格式。
    func loadDecryptedDataAsync(
        path: String,
        password: String,
        preferredExtension: String
    ) async throws -> Data {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            decryptionQueue.addOperation {
                do {
                    let sourceURL = self.getFileURL(for: path)

                    // 只读取 4 字节魔数判断加密格式，避免把整个加密文件读入内存
                    let handle = try FileHandle(forReadingFrom: sourceURL)
                    let magic = try handle.read(upToCount: 4) ?? Data()
                    try handle.close()
                    let chunkMagic = Data("ZNSC".utf8)

                    if magic == chunkMagic {
                        // 流式加密：解密到临时文件后读取（临时文件用完即删）
                        let tempURL = try self.createDecryptedTempFile(
                            path: path,
                            password: password,
                            preferredExtension: preferredExtension
                        )
                        defer { try? FileManager.default.removeItem(at: tempURL) }
                        continuation.resume(returning: try Data(contentsOf: tempURL))
                    } else {
                        let encryptedData = try self.loadEncrypted(path: path)
                        continuation.resume(
                            returning: try self.encryptionService.decrypt(
                                encryptedData: encryptedData,
                                password: password
                            )
                        )
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 清洗文件扩展名，防止非法字符混入临时文件名（未来调用方的路径穿越风险）
    private func sanitizedExtension(_ fileExtension: String) -> String {
        let cleaned = fileExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .filter { $0.isLetter || $0.isNumber }
        return cleaned.isEmpty ? "" : "." + cleaned
    }
}
