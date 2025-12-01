//
//  TrashManager.swift
//  EchoFlow
//
//  Created by keben on 2025/11/30.
//

import Foundation
import SwiftData

/// 回收站管理器
@Observable
final class TrashManager {
    // MARK: - Singleton
    
    static let shared = TrashManager()
    
    // MARK: - Properties
    
    /// 模型上下文
    var modelContext: ModelContext?
    
    /// 清理定时器
    private var cleanupTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        // 启动定期清理任务（每小时检查一次）
        startPeriodicCleanup()
    }
    
    // MARK: - Public Methods
    
    /// 检查是否启用回收站（默认开启）
    static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: "enableTrash") == nil {
            return true // 默认开启
        }
        return UserDefaults.standard.bool(forKey: "enableTrash")
    }
    
    /// 将剪贴板项目移动到回收站
    func moveToTrash(_ item: ClipboardItem) throws {
        guard let context = modelContext else {
            throw TrashError.contextNotSet
        }
        
        // 创建可编码的数据结构（不包含收藏功能，因为当前项目没有收藏功能）
        let clipboardData = ClipboardItemData(from: item)
        
        // 序列化项目数据（使用优化的编码器）
        let encoder = JSONEncoder()
        encoder.outputFormatting = [] // 不格式化，减少数据大小
        let itemData = try encoder.encode(clipboardData)
        
        // 创建回收站项目
        let trashItem = TrashItem(
            itemType: .clipboard,
            originalId: item.id,
            itemData: itemData
        )
        
        // 保存到回收站
        context.insert(trashItem)
        
        // 从原列表删除
        context.delete(item)
        
        try context.save()
        print("✅ 已移动到回收站: \(item.id)")
    }
    
    /// 将笔记项目移动到回收站
    func moveToTrash(_ note: NoteItem) throws {
        guard let context = modelContext else {
            throw TrashError.contextNotSet
        }
        
        // 创建可编码的数据结构
        let noteData = NoteItemData(from: note)
        
        // 序列化项目数据（使用优化的编码器）
        let encoder = JSONEncoder()
        encoder.outputFormatting = [] // 不格式化，减少数据大小
        let itemData = try encoder.encode(noteData)
        
        // 创建回收站项目
        let trashItem = TrashItem(
            itemType: .note,
            originalId: note.id,
            itemData: itemData
        )
        
        // 保存到回收站
        context.insert(trashItem)
        
        // 从原列表删除
        context.delete(note)
        
        try context.save()
        print("✅ 已移动到回收站: \(note.id)")
    }
    
    /// 恢复回收站项目
    func restore(_ trashItem: TrashItem) throws {
        guard let context = modelContext else {
            throw TrashError.contextNotSet
        }
        
        let decoder = JSONDecoder()
        
        switch trashItem.itemType {
        case .clipboard:
            let data = try decoder.decode(ClipboardItemData.self, from: trashItem.itemData)
            let item = data.toClipboardItem()
            context.insert(item)
            
        case .note:
            let data = try decoder.decode(NoteItemData.self, from: trashItem.itemData)
            let note = data.toNoteItem()
            context.insert(note)
        }
        
        // 从回收站删除
        context.delete(trashItem)
        
        try context.save()
        print("✅ 已恢复: \(trashItem.id)")
    }
    
    /// 批量恢复回收站项目（性能优化）
    func restoreBatch(_ trashItems: [TrashItem]) throws {
        guard let context = modelContext else {
            throw TrashError.contextNotSet
        }
        
        let decoder = JSONDecoder()
        
        for trashItem in trashItems {
            switch trashItem.itemType {
            case .clipboard:
                let data = try decoder.decode(ClipboardItemData.self, from: trashItem.itemData)
                let item = data.toClipboardItem()
                context.insert(item)
                
            case .note:
                let data = try decoder.decode(NoteItemData.self, from: trashItem.itemData)
                let note = data.toNoteItem()
                context.insert(note)
            }
            
            context.delete(trashItem)
        }
        
        try context.save()
        print("✅ 已批量恢复 \(trashItems.count) 个项目")
    }
    
    /// 永久删除回收站项目
    func permanentlyDelete(_ trashItem: TrashItem) throws {
        guard let context = modelContext else {
            throw TrashError.contextNotSet
        }
        
        context.delete(trashItem)
        try context.save()
        print("✅ 已永久删除: \(trashItem.id)")
    }
    
    /// 批量永久删除回收站项目（性能优化）
    func permanentlyDeleteBatch(_ trashItems: [TrashItem]) throws {
        guard let context = modelContext else {
            throw TrashError.contextNotSet
        }
        
        for item in trashItems {
            context.delete(item)
        }
        
        try context.save()
        print("✅ 已批量永久删除 \(trashItems.count) 个项目")
    }
    
    /// 清空回收站
    func emptyTrash() throws {
        guard let context = modelContext else {
            throw TrashError.contextNotSet
        }
        
        let descriptor = FetchDescriptor<TrashItem>()
        let items = try context.fetch(descriptor)
        
        for item in items {
            context.delete(item)
        }
        
        try context.save()
        print("✅ 已清空回收站: \(items.count) 个项目")
    }
    
    /// 启动定期清理任务
    func startPeriodicCleanup() {
        // 停止现有定时器
        cleanupTimer?.invalidate()
        
        // 创建新的定时器（每小时执行一次）
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
        
        // 确保定时器在主线程的 RunLoop 上运行
        if let timer = cleanupTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("🗑️ 回收站定期清理已启动（每小时检查一次）")
        
        // 立即执行一次清理
        performCleanup()
    }
    
    /// 停止定期清理任务
    func stopPeriodicCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        print("🗑️ 回收站定期清理已停止")
    }
    
    // MARK: - Private Methods
    
    /// 执行清理任务（删除3天前的项目）
    private func performCleanup() {
        guard let context = modelContext else {
            print("⚠️ ModelContext 未设置，无法执行清理")
            return
        }
        
        let threeDaysAgo = Date().addingTimeInterval(-3 * 24 * 3600)
        
        let descriptor = FetchDescriptor<TrashItem>(
            predicate: #Predicate<TrashItem> { item in
                item.deletedAt < threeDaysAgo
            },
            sortBy: [SortDescriptor(\TrashItem.deletedAt, order: .forward)]
        )
        
        do {
            let itemsToDelete = try context.fetch(descriptor)
            let count = itemsToDelete.count
            
            if count > 0 {
                for item in itemsToDelete {
                    context.delete(item)
                }
                
                try context.save()
                print("🧹 已清理 \(count) 个过期回收站项目（3天前）")
            }
        } catch {
            print("❌ 清理回收站失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - Data Structures

/// 剪贴板项目数据（可编码）
struct ClipboardItemData: Codable {
    let id: UUID
    let content: String
    let richTextData: Data?
    let imageData: Data?
    let typeRaw: String
    let sourceApp: String
    let sourceAppBundleID: String
    let themeColorHex: String
    let createdAt: Date
    let isFavorite: Bool
    let isLocked: Bool
    let contentHash: String
    let linkTitle: String?
    let linkFaviconData: Data?
    let fileSize: Int64?
    
    init(from item: ClipboardItem) {
        self.id = item.id
        self.content = item.content
        self.richTextData = item.richTextData
        self.imageData = item.imageData
        self.typeRaw = item.typeRaw
        self.sourceApp = item.sourceApp
        self.sourceAppBundleID = item.sourceAppBundleID
        self.themeColorHex = item.themeColorHex
        self.createdAt = item.createdAt
        self.isFavorite = item.isFavorite
        self.isLocked = item.isLocked
        self.contentHash = item.contentHash
        self.linkTitle = item.linkTitle
        self.linkFaviconData = item.linkFaviconData
        self.fileSize = item.fileSize
    }
    
    func toClipboardItem() -> ClipboardItem {
        let item = ClipboardItem(
            id: id,
            content: content,
            richTextData: richTextData,
            imageData: imageData,
            type: ContentType(rawValue: typeRaw) ?? .text,
            sourceApp: sourceApp,
            sourceAppBundleID: sourceAppBundleID,
            themeColorHex: themeColorHex,
            createdAt: createdAt,
            isFavorite: isFavorite,
            isLocked: isLocked,
            linkTitle: linkTitle,
            linkFaviconData: linkFaviconData,
            fileSize: fileSize
        )
        return item
    }
}

/// 笔记项目数据（可编码）
struct NoteItemData: Codable {
    let id: UUID
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let colorTheme: String
    let isPinned: Bool
    let isLocked: Bool
    
    init(from note: NoteItem) {
        self.id = note.id
        self.content = note.content
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
        self.colorTheme = note.colorTheme
        self.isPinned = note.isPinned
        self.isLocked = note.isLocked
    }
    
    func toNoteItem() -> NoteItem {
        let note = NoteItem(
            id: id,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            colorTheme: colorTheme,
            isPinned: isPinned,
            isLocked: isLocked
        )
        return note
    }
}

// MARK: - Errors

enum TrashError: LocalizedError {
    case contextNotSet
    case decodeFailed
    
    var errorDescription: String? {
        switch self {
        case .contextNotSet:
            return "ModelContext 未设置"
        case .decodeFailed:
            return "数据解码失败"
        }
    }
}
