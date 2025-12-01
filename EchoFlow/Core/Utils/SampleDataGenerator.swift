//
//  SampleDataGenerator.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import Foundation
import SwiftData
import AppKit

/// 样例数据生成器
final class SampleDataGenerator {
    static let shared = SampleDataGenerator()
    
    private init() {}
    
    /// 检查并生成样例数据
    func generateSampleDataIfNeeded(context: ModelContext) {
        // 检查是否已经生成过样例数据
        let hasGeneratedKey = "hasGeneratedSampleData"
        if UserDefaults.standard.bool(forKey: hasGeneratedKey) {
            return
        }
        
        // 生成样例数据
        generateSampleClipboardItems(context: context)
        generateSampleNotes(context: context)
        
        // 标记已生成
        UserDefaults.standard.set(true, forKey: hasGeneratedKey)
        print("✅ 已生成样例数据")
    }
    
    /// 生成样例剪贴板项目
    private func generateSampleClipboardItems(context: ModelContext) {
        let sampleItems: [(content: String, type: ContentType, sourceApp: String, themeColor: String)] = [
            ("https://www.apple.com", .link, "Safari", "#007AFF"),
            ("Hello, World!\n这是一个示例文本内容。", .text, "TextEdit", "#34C759"),
            ("func greet(name: String) {\n    print(\"Hello, \\(name)!\")\n}", .code, "Xcode", "#007ACC"),
            ("#FF5733", .color, "Color Picker", "#FF5733"),
            ("https://github.com", .link, "Safari", "#24292E"),
        ]
        
        let now = Date()
        for (index, item) in sampleItems.enumerated() {
            let clipboardItem = ClipboardItem(
                content: item.content,
                richTextData: nil,
                imageData: nil,
                type: item.type,
                sourceApp: item.sourceApp,
                sourceAppBundleID: "com.example.\(item.sourceApp.lowercased())",
                themeColorHex: item.themeColor,
                fileSize: nil
            )
            // 设置不同的创建时间，让它们看起来是不同时间创建的
            clipboardItem.createdAt = now.addingTimeInterval(-Double(index * 60))
            clipboardItem.isFavorite = false
            
            context.insert(clipboardItem)
        }
        
        do {
            try context.save()
            print("✅ 已生成 \(sampleItems.count) 条样例剪贴板数据")
        } catch {
            print("❌ 生成样例剪贴板数据失败: \(error.localizedDescription)")
        }
    }
    
    /// 生成样例笔记
    private func generateSampleNotes(context: ModelContext) {
        let sampleNotes: [(content: String, colorTheme: String)] = [
            ("欢迎使用 EchoFlow！\n\n这是一个强大的剪贴板管理工具。\n\n你可以：\n• 保存剪贴板历史\n• 创建笔记\n• 快速搜索和访问", "#FF5733"),
            ("待办事项\n\n- [ ] 完成项目文档\n- [ ] 测试新功能\n- [ ] 代码审查", "#FFC300"),
            ("会议记录\n\n时间：2025-01-15\n主题：产品规划\n\n要点：\n1. 新功能设计\n2. 用户体验优化\n3. 性能提升", "#3498DB"),
            ("灵感笔记\n\n今天想到一个很棒的想法...\n\n需要进一步思考和完善。", "#9B59B6"),
        ]
        
        let now = Date()
        for (index, note) in sampleNotes.enumerated() {
            let noteItem = NoteItem(
                content: note.content,
                colorTheme: note.colorTheme
            )
            // 设置不同的创建和更新时间
            let timeOffset = -Double(index * 3600) // 每小时一个
            noteItem.createdAt = now.addingTimeInterval(timeOffset)
            noteItem.updatedAt = now.addingTimeInterval(timeOffset)
            noteItem.isPinned = index == 0 // 第一个笔记置顶
            
            context.insert(noteItem)
        }
        
        do {
            try context.save()
            print("✅ 已生成 \(sampleNotes.count) 条样例笔记")
        } catch {
            print("❌ 生成样例笔记失败: \(error.localizedDescription)")
        }
    }
}




