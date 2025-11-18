//
//  MediaType.swift
//  ZeroNet-Space
//
//  媒体类型枚举
//  定义支持的媒体类型：照片、视频、文档
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 媒体类型
enum MediaType: String, Codable, CaseIterable {
    case photo  // 照片（jpg, png, heic等）
    case video  // 视频（mp4, mov等）
    case document  // 文档（pdf, doc, txt等）

    // MARK: - Display Properties

    /// 类型显示名称
    var displayName: String {
        switch self {
        case .photo:
            return "照片"
        case .video:
            return "视频"
        case .document:
            return "文档"
        }
    }

    /// SF Symbol图标名称
    var iconName: String {
        switch self {
        case .photo:
            return "photo.fill"
        case .video:
            return "video.fill"
        case .document:
            return "doc.fill"
        }
    }

    /// 图标颜色
    var iconColor: Color {
        switch self {
        case .photo:
            return .blue
        case .video:
            return .purple
        case .document:
            return .orange
        }
    }

    // MARK: - File Extension Detection

    /// 从文件扩展名推断媒体类型
    /// - Parameter fileExtension: 文件扩展名（如 "jpg", "mp4"）
    /// - Returns: 媒体类型，如果无法识别则返回document
    static func from(fileExtension: String) -> MediaType {
        let ext = fileExtension.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))

        // 图片格式
        if AppConstants.supportedImageFormats.contains(ext) {
            return .photo
        }

        // 视频格式
        if AppConstants.supportedVideoFormats.contains(ext) {
            return .video
        }

        // 其他文档
        return .document
    }

    /// 从UTType推断媒体类型
    /// - Parameter utType: UTType
    /// - Returns: 媒体类型
    static func from(utType: UTType) -> MediaType {
        if utType.conforms(to: .image) {
            return .photo
        } else if utType.conforms(to: .movie) || utType.conforms(to: .video) {
            return .video
        } else {
            return .document
        }
    }

    /// 从MIME类型推断媒体类型
    /// - Parameter mimeType: MIME类型（如 "image/jpeg"）
    /// - Returns: 媒体类型
    static func from(mimeType: String) -> MediaType {
        if mimeType.hasPrefix("image/") {
            return .photo
        } else if mimeType.hasPrefix("video/") {
            return .video
        } else {
            return .document
        }
    }

    // MARK: - File Validation

    /// 验证文件是否为此媒体类型
    /// - Parameter fileExtension: 文件扩展名
    /// - Returns: 是否匹配
    func matches(fileExtension: String) -> Bool {
        let ext = fileExtension.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))

        switch self {
        case .photo:
            return AppConstants.supportedImageFormats.contains(ext)
        case .video:
            return AppConstants.supportedVideoFormats.contains(ext)
        case .document:
            return !AppConstants.supportedImageFormats.contains(ext)
                && !AppConstants.supportedVideoFormats.contains(ext)
        }
    }

    // MARK: - Quick Look Support

    /// 是否支持Quick Look预览
    var supportsQuickLook: Bool {
        // 所有类型都支持Quick Look
        return true
    }

    /// 是否需要解密后才能预览
    var requiresDecryptionForPreview: Bool {
        // 所有类型都需要解密
        return true
    }
}

// MARK: - Identifiable

extension MediaType: Identifiable {
    var id: String { rawValue }
}

// MARK: - Sorting Helper

extension MediaType: Comparable {
    static func < (lhs: MediaType, rhs: MediaType) -> Bool {
        // 排序顺序：照片 < 视频 < 文档
        let order: [MediaType] = [.photo, .video, .document]
        guard let lhsIndex = order.firstIndex(of: lhs),
            let rhsIndex = order.firstIndex(of: rhs)
        else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}
