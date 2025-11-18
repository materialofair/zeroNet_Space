/*@ai:risk=2|deps=SwiftData|lines=80*/
//
//  SecretNote.swift
//  ZeroNet-Space
//
//  隐藏空间笔记数据模型
//  支持Markdown格式的私密笔记
//

import Foundation
import SwiftData

@Model
final class SecretNote {

    // MARK: - Properties

    /// 笔记唯一标识符
    var id: UUID

    /// 笔记标题
    var title: String

    /// 笔记内容 (Markdown格式)
    var content: String

    /// 创建时间
    var createdAt: Date

    /// 最后修改时间
    var modifiedAt: Date

    /// 是否收藏
    var isFavorite: Bool

    /// 标签 (可选,用于分类)
    var tags: [String]

    // MARK: - Initialization

    init(
        title: String = String(localized: "secretNote.defaultTitle"),
        content: String = "",
        isFavorite: Bool = false,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isFavorite = isFavorite
        self.tags = tags
    }

    // MARK: - Computed Properties

    /// 格式化的创建时间
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = .autoupdatingCurrent
        return formatter.string(from: createdAt)
    }

    /// 格式化的修改时间
    var formattedModifiedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = .autoupdatingCurrent
        return formatter.string(from: modifiedAt)
    }

    /// 笔记预览 (前100个字符)
    var preview: String {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanContent.isEmpty {
            return String(localized: "secretNote.empty")
        }
        return String(cleanContent.prefix(100))
    }

    /// 字数统计
    var wordCount: Int {
        return content.count
    }
}
