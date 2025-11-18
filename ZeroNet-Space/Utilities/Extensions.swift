//
//  Extensions.swift
//  ZeroNet-Space
//
//  常用扩展
//

import Foundation
import SwiftUI
import UIKit

// MARK: - View Extensions

extension View {
    /// 条件性应用修饰符
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// 隐藏键盘
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// 添加圆角和阴影
    func cardStyle(cornerRadius: CGFloat = 12, shadowRadius: CGFloat = 5) -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(cornerRadius)
            .shadow(radius: shadowRadius)
    }
}

// MARK: - Date Extensions

extension Date {
    /// 相对时间描述
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// 短日期格式
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }

    /// 详细日期时间格式
    var detailedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }
}

// MARK: - Int64 Extensions

extension Int64 {
    /// 格式化文件大小
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

// MARK: - String Extensions

extension String {
    /// 文件扩展名
    var fileExtension: String {
        (self as NSString).pathExtension
    }

    /// 不带扩展名的文件名
    var fileNameWithoutExtension: String {
        (self as NSString).deletingPathExtension
    }
}

// MARK: - Color Extensions

extension Color {
    /// 从十六进制创建颜色
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /// 调整图片大小
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// 生成缩略图
    func thumbnail(maxSize: CGFloat) -> UIImage? {
        let aspectRatio = self.size.width / self.size.height
        var thumbnailSize: CGSize

        if aspectRatio > 1 {
            // 横向图片
            thumbnailSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            // 纵向图片
            thumbnailSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }

        return resized(to: thumbnailSize)
    }

    /// 压缩为JPEG数据
    func compressedJPEGData(quality: CGFloat = 0.7) -> Data? {
        return self.jpegData(compressionQuality: quality)
    }
}

// MARK: - Data Extensions

extension Data {
    /// 转换为UIImage
    var asUIImage: UIImage? {
        return UIImage(data: self)
    }
}
