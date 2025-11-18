//
//  MediaItem.swift
//  ZeroNet-Space
//
//  媒体项数据模型（SwiftData）
//  存储媒体文件的元数据
//

import Foundation
import SwiftData

/// 媒体项模型
@Model
@MainActor
final class MediaItem {

    // MARK: - Properties

    /// 唯一标识符
    var id: UUID

    /// 原始文件名（如 "IMG_1234.jpg"）
    var fileName: String

    /// 文件扩展名（如 ".jpg"）
    var fileExtension: String

    /// 文件大小（字节）
    var fileSize: Int64

    /// 媒体类型（照片/视频/文档）
    var typeRawValue: String

    /// 加密文件的完整路径
    var encryptedPath: String

    /// 缩略图数据（加密后的）
    var thumbnailData: Data?

    /// 导入时间
    var createdAt: Date

    /// 最后修改时间
    var modifiedAt: Date

    /// 图片/视频宽度（像素）
    var width: Int?

    /// 图片/视频高度（像素）
    var height: Int?

    /// 视频时长（秒）
    var duration: Double?

    // MARK: - Computed Properties

    /// 媒体类型（计算属性）
    @Transient
    var type: MediaType {
        get {
            MediaType(rawValue: typeRawValue) ?? .document
        }
        set {
            typeRawValue = newValue.rawValue
        }
    }

    /// 完整文件名（带扩展名）
    @Transient
    var fullFileName: String {
        fileName + fileExtension
    }

    /// 格式化的文件大小
    @Transient
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// 格式化的创建时间
    @Transient
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: createdAt)
    }

    /// 是否有尺寸信息
    @Transient
    var hasDimensions: Bool {
        width != nil && height != nil
    }

    /// 格式化的尺寸信息
    @Transient
    var formattedDimensions: String? {
        guard let width = width, let height = height else {
            return nil
        }
        return "\(width) × \(height)"
    }

    /// 格式化的视频时长
    @Transient
    var formattedDuration: String? {
        guard let duration = duration else {
            return nil
        }

        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        fileName: String,
        fileExtension: String,
        fileSize: Int64,
        type: MediaType,
        encryptedPath: String,
        thumbnailData: Data? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        width: Int? = nil,
        height: Int? = nil,
        duration: Double? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.fileSize = fileSize
        self.typeRawValue = type.rawValue
        self.encryptedPath = encryptedPath
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.width = width
        self.height = height
        self.duration = duration
    }

    // MARK: - Methods

    /// 更新最后修改时间
    func touch() {
        modifiedAt = Date()
    }

    /// 设置尺寸信息
    func setDimensions(width: Int, height: Int) {
        self.width = width
        self.height = height
        touch()
    }

    /// 设置视频时长
    func setDuration(_ duration: Double) {
        self.duration = duration
        touch()
    }

    /// 更新缩略图
    func updateThumbnail(_ data: Data?) {
        self.thumbnailData = data
        touch()
    }
}

// MARK: - Comparable

extension MediaItem: Comparable {
    static func < (lhs: MediaItem, rhs: MediaItem) -> Bool {
        // 默认按创建时间降序排序（最新在前）
        lhs.createdAt > rhs.createdAt
    }
}

// MARK: - Sorting Options

extension MediaItem {

    /// Sort order options
    enum SortOrder: String, CaseIterable, Identifiable {
        case dateNewest
        case dateOldest
        case nameAZ
        case nameZA
        case sizeSmallest
        case sizeLargest
        case typeGrouped

        var id: String { rawValue }

        /// Localized display name
        var displayName: String {
            switch self {
            case .dateNewest:
                return String(localized: "sort.dateNewest")
            case .dateOldest:
                return String(localized: "sort.dateOldest")
            case .nameAZ:
                return String(localized: "sort.nameAZ")
            case .nameZA:
                return String(localized: "sort.nameZA")
            case .sizeSmallest:
                return String(localized: "sort.sizeSmallest")
            case .sizeLargest:
                return String(localized: "sort.sizeLargest")
            case .typeGrouped:
                return String(localized: "sort.typeGrouped")
            }
        }

        /// 排序描述符
        var sortDescriptor: [SortDescriptor<MediaItem>] {
            switch self {
            case .dateNewest:
                return [SortDescriptor(\MediaItem.createdAt, order: .reverse)]
            case .dateOldest:
                return [SortDescriptor(\MediaItem.createdAt, order: .forward)]
            case .nameAZ:
                return [SortDescriptor(\MediaItem.fileName, order: .forward)]
            case .nameZA:
                return [SortDescriptor(\MediaItem.fileName, order: .reverse)]
            case .sizeSmallest:
                return [SortDescriptor(\MediaItem.fileSize, order: .forward)]
            case .sizeLargest:
                return [SortDescriptor(\MediaItem.fileSize, order: .reverse)]
            case .typeGrouped:
                return [
                    SortDescriptor(\MediaItem.typeRawValue, order: .forward),
                    SortDescriptor(\MediaItem.createdAt, order: .reverse),
                ]
            }
        }

        /// SF Symbol图标
        var icon: String {
            switch self {
            case .dateNewest:
                return "calendar.badge.clock"
            case .dateOldest:
                return "calendar"
            case .nameAZ:
                return "textformat.abc"
            case .nameZA:
                return "textformat.abc"
            case .sizeSmallest:
                return "arrow.up.circle"
            case .sizeLargest:
                return "arrow.down.circle"
            case .typeGrouped:
                return "square.grid.2x2"
            }
        }
    }
}
