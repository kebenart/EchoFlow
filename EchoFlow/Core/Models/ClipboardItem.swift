//
//  ClipboardItem.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import Foundation
import SwiftData

/// 剪贴板内容类型
enum ContentType: String, Codable {
    case text = "text"
    case image = "image"
    case file = "file"
    case link = "link"
    case code = "code"
    case color = "color"

    /// 中文显示名称
    var displayName: String {
        switch self {
        case .text: return "文本"
        case .image: return "图片"
        case .file: return "文件"
        case .link: return "链接"
        case .code: return "代码"
        case .color: return "颜色"
        }
    }
}

/// 剪贴板历史项目模型
@Model
final class ClipboardItem {
    /// 唯一标识符
    @Attribute(.unique) var id: UUID

    /// 文本内容或文件路径（纯文本）
    var content: String

    /// 富文本数据 (RTF / HTML)，用于还原原软件中的样式（代码高亮等）
    var richTextData: Data?

    /// 图片二进制数据 (SwiftData 自动优化大文件存储)
    var imageData: Data?

    /// 内容类型 (使用 String 存储以便 SwiftData 序列化)
    var typeRaw: String

    /// 来源应用名称
    var sourceApp: String

    /// 来源应用 Bundle ID
    var sourceAppBundleID: String

    /// 主题色 (十六进制)
    var themeColorHex: String

    /// 创建时间
    var createdAt: Date

    /// 是否收藏
    var isFavorite: Bool

    /// 内容哈希值 (用于去重)
    var contentHash: String

    /// 网站标题 (仅用于链接类型)
    var linkTitle: String?

    /// 网站 Favicon 数据 (仅用于链接类型)
    var linkFaviconData: Data?

    /// 文件大小（字节）(仅用于文件/图片类型)
    var fileSize: Int64?

    // MARK: - Computed Properties

    /// 内容类型枚举
    var type: ContentType {
        get { ContentType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }

    /// 相对时间显示（现在、30秒前、1分钟前、2小时前等）
    var relativeTimeString: String {
        let now = Date()
        let interval = now.timeIntervalSince(createdAt)

        if interval < 30 {
            // 30秒内显示为"现在"
            return "现在"
        } else if interval < 60 {
            // 30秒-1分钟显示为"30秒前"
            return "30秒前"
        } else if interval < 3600 {
            // 小于1小时
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            // 小于1天
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else if interval < 604800 {
            // 小于1周
            let days = Int(interval / 86400)
            return "\(days)天前"
        } else {
            // 超过1周，显示具体日期
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: createdAt)
        }
    }

    /// 内容预览 (截取前几行或前几个字符)
    var contentPreview: String {
        let maxLength = 100
        if content.count > maxLength {
            return String(content.prefix(maxLength)) + "..."
        }
        return content
    }

    /// 第一个文件路径（用于文件类型）
    var firstFilePath: String? {
        guard type == .file else { return nil }
        let paths = content.split(separator: "\n")
        return paths.first.map(String.init)
    }

    /// 文件名（从第一个文件路径提取）
    var fileName: String? {
        guard let filePath = firstFilePath else { return nil }
        return URL(fileURLWithPath: filePath).lastPathComponent
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        content: String,
        richTextData: Data? = nil,
        imageData: Data? = nil,
        type: ContentType = .text,
        sourceApp: String = "",
        sourceAppBundleID: String = "",
        themeColorHex: String = "#007ACC",
        createdAt: Date = Date(),
        isFavorite: Bool = false,
        linkTitle: String? = nil,
        linkFaviconData: Data? = nil,
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.content = content
        self.richTextData = richTextData
        self.imageData = imageData
        self.typeRaw = type.rawValue
        self.sourceApp = sourceApp
        self.sourceAppBundleID = sourceAppBundleID
        self.themeColorHex = themeColorHex
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.linkTitle = linkTitle
        self.linkFaviconData = linkFaviconData
        self.fileSize = fileSize

        // 生成内容哈希用于去重
        self.contentHash = Self.generateHash(from: content, imageData: imageData)
    }

    // MARK: - Static Methods

    /// 生成内容哈希
    static func generateHash(from content: String, imageData: Data? = nil) -> String {
        var hashString = content
        if let data = imageData {
            hashString += data.base64EncodedString()
        }
        return String(hashString.hashValue)
    }
}

// MARK: - Preview Helper

#if DEBUG
extension ClipboardItem {
    /// 创建预览数据
    static func preview(
        content: String = "Sample clipboard content",
        type: ContentType = .text,
        sourceApp: String = "Xcode"
    ) -> ClipboardItem {
        ClipboardItem(
            content: content,
            type: type,
            sourceApp: sourceApp,
            createdAt: Date()
        )
    }
}
#endif
