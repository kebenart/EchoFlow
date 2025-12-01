//
//  NoteItem.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import Foundation
import SwiftData
import SwiftUI

/// 笔记项目模型
@Model
final class NoteItem {
    /// 唯一标识符
    @Attribute(.unique) var id: UUID

    /// 笔记内容
    var content: String

    /// 创建时间
    var createdAt: Date

    /// 最后修改时间
    var updatedAt: Date

    /// 笔记卡片主题色 (十六进制)
    var colorTheme: String

    /// 是否置顶
    var isPinned: Bool = false
    
    /// 是否锁定（锁定的笔记不会被自动删除）
    var isLocked: Bool = false
    
    var uiColor: Color {
        Color(hex: self.colorTheme) ?? .gray
    }

    // MARK: - Computed Properties

    /// 相对时间显示（现在、30秒前、1分钟前、2小时前等）
    var relativeTimeString: String {
        let now = Date()
        let interval = now.timeIntervalSince(updatedAt)

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
            return formatter.string(from: updatedAt)
        }
    }

    /// 内容预览 (截取前几行，最多8行，优先显示前面的内容)
    var contentPreview: String {
        if content.isEmpty {
            return "空笔记"
        }
        
        // 按换行符分割，保留空行
        let lines = content.components(separatedBy: "\n")
        
        // 取前8行（卡片中最多显示8行，确保标题和时间区域有足够空间）
        let maxLines = 8
        let previewLines = Array(lines.prefix(maxLines))
        
        // 如果只有一行，检查长度
        if previewLines.count == 1 {
            let firstLine = previewLines[0]
            if firstLine.count > 80 {
                return String(firstLine.prefix(80)) + "..."
            }
            return firstLine
        }
        
        // 多行情况：处理前8行，每行最多80字符
        let processedLines = previewLines.map { line -> String in
            if line.count > 80 {
                return String(line.prefix(80)) + "..."
            }
            return line
        }
        
        var result = processedLines.joined(separator: "\n")
        
        // 如果原始内容超过8行，添加省略号
        if lines.count > maxLines {
            result += "\n..."
        }
        
        return result
    }

    /// 笔记标题 (第一行或默认标题)
    var title: String {
        let firstLine = content.split(separator: "\n").first
        if let line = firstLine, !line.isEmpty {
            return String(line.prefix(50))
        }
        return "未命名笔记"
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        colorTheme: String = "#FF6B6B",
        isPinned: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.colorTheme = colorTheme
        self.isPinned = isPinned
        self.isLocked = isLocked
    }

    /// 仅更新标题（保留剩余内容）
    func updateTitle(_ newTitle: String) {
        let lines = self.content.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count > 1 {
            let restLines = lines.dropFirst().joined(separator: "\n")
            self.content = newTitle + "\n" + restLines
        } else {
            self.content = newTitle
        }
    }
    


    // MARK: - Methods

    /// 更新笔记内容
    func updateContent(_ newContent: String) {
        self.content = newContent
        self.updatedAt = Date()
    }
}

// MARK: - Preview Helper

#if DEBUG
extension NoteItem {
    /// 创建预览数据
    static func preview(
        content: String = "这是一个示例笔记\n可以包含多行内容",
        colorTheme: String = "#FF6B6B"
    ) -> NoteItem {
        NoteItem(
            content: content,
            createdAt: Date().addingTimeInterval(-3600),
            colorTheme: colorTheme
        )
    }
}
#endif

// MARK: - Color Extension

extension Color {
    /// 从十六进制字符串创建颜色
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0

        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }

        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
