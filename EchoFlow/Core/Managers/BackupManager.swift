//
//  BackupManager.swift
//  EchoFlow
//
//  Created by keben on 2025/11/30.
//

import Foundation
import SwiftData

/// 备份内容选项
struct BackupOptions: OptionSet {
    let rawValue: Int
    
    static let clipboard = BackupOptions(rawValue: 1 << 0)
    static let notes = BackupOptions(rawValue: 1 << 1)
    static let trash = BackupOptions(rawValue: 1 << 2)
    static let settings = BackupOptions(rawValue: 1 << 3)
    
    static let all: BackupOptions = [.clipboard, .notes, .trash, .settings]
}

/// 备份数据结构
struct BackupData: Codable {
    let version: String
    let createdAt: Date
    let clipboardItems: [ClipboardItemData]?
    let notes: [NoteItemData]?
    let trashItems: [TrashItemBackupData]?
    let settings: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case version
        case createdAt
        case clipboardItems
        case notes
        case trashItems
        case settings
    }
}

/// 回收站项目备份数据
struct TrashItemBackupData: Codable {
    let id: UUID
    let itemTypeRaw: String
    let originalId: UUID
    let itemData: Data
    let deletedAt: Date
}

/// 用于编码/解码 Any 类型的辅助结构
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解码 AnyCodable")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "无法编码 AnyCodable"))
        }
    }
}

/// 备份管理器
@Observable
final class BackupManager {
    static let shared = BackupManager()
    
    var modelContext: ModelContext?
    
    private init() {}
    
    /// 创建备份
    func createBackup(options: BackupOptions, to url: URL) throws {
        var backupData = BackupData(
            version: "1.0",
            createdAt: Date(),
            clipboardItems: nil,
            notes: nil,
            trashItems: nil,
            settings: nil
        )
        
        guard let context = modelContext else {
            throw BackupError.contextNotSet
        }
        
        // 备份剪贴板项目
        if options.contains(.clipboard) {
            let descriptor = FetchDescriptor<ClipboardItem>()
            let items = try context.fetch(descriptor)
            backupData = BackupData(
                version: backupData.version,
                createdAt: backupData.createdAt,
                clipboardItems: items.map { ClipboardItemData(from: $0) },
                notes: backupData.notes,
                trashItems: backupData.trashItems,
                settings: backupData.settings
            )
        }
        
        // 备份笔记
        if options.contains(.notes) {
            let descriptor = FetchDescriptor<NoteItem>()
            let notes = try context.fetch(descriptor)
            backupData = BackupData(
                version: backupData.version,
                createdAt: backupData.createdAt,
                clipboardItems: backupData.clipboardItems,
                notes: notes.map { NoteItemData(from: $0) },
                trashItems: backupData.trashItems,
                settings: backupData.settings
            )
        }
        
        // 备份回收站
        if options.contains(.trash) {
            let descriptor = FetchDescriptor<TrashItem>()
            let trashItems = try context.fetch(descriptor)
            backupData = BackupData(
                version: backupData.version,
                createdAt: backupData.createdAt,
                clipboardItems: backupData.clipboardItems,
                notes: backupData.notes,
                trashItems: trashItems.map { TrashItemBackupData(
                    id: $0.id,
                    itemTypeRaw: $0.itemTypeRaw,
                    originalId: $0.originalId,
                    itemData: $0.itemData,
                    deletedAt: $0.deletedAt
                ) },
                settings: backupData.settings
            )
        }
        
        // 备份设置
        if options.contains(.settings) {
            let userDefaults = UserDefaults.standard
            let settingsKeys = [
                "dockPosition", "autoHide", "copyBehavior", "historyRetentionPeriod",
                "launchAtLogin", "showStatusBarIcon", "enableDeduplication", "deduplicationWindow",
                "enableLinkPreview", "enableCoolMode", "checkForUpdatesOnLaunch",
                "hotKeyKeyCode", "hotKeyModifiersRaw", "deleteLockedItems", "enableTrash"
            ]
            
            var settings: [String: AnyCodable] = [:]
            for key in settingsKeys {
                if let value = userDefaults.object(forKey: key) {
                    settings[key] = AnyCodable(value)
                }
            }
            
            backupData = BackupData(
                version: backupData.version,
                createdAt: backupData.createdAt,
                clipboardItems: backupData.clipboardItems,
                notes: backupData.notes,
                trashItems: backupData.trashItems,
                settings: settings
            )
        }
        
        // 编码为 JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(backupData)
        
        // 写入文件
        try jsonData.write(to: url)
        
        print("✅ 备份已创建: \(url.path)")
    }
    
    /// 恢复备份
    func restoreBackup(from url: URL, options: BackupOptions) throws {
        guard let context = modelContext else {
            throw BackupError.contextNotSet
        }
        
        // 读取备份文件
        let jsonData = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backupData = try decoder.decode(BackupData.self, from: jsonData)
        
        print("📦 恢复备份版本: \(backupData.version), 创建时间: \(backupData.createdAt)")
        
        // 恢复剪贴板项目
        if options.contains(.clipboard), let items = backupData.clipboardItems {
            // 先清空现有数据（可选，根据需求决定）
            // 这里我们选择合并而不是替换
            for itemData in items {
                // 检查是否已存在（根据 ID）
                let descriptor = FetchDescriptor<ClipboardItem>(
                    predicate: #Predicate { $0.id == itemData.id }
                )
                let existing = try context.fetch(descriptor)
                
                if existing.isEmpty {
                    let item = itemData.toClipboardItem()
                    context.insert(item)
                }
            }
            print("✅ 已恢复 \(items.count) 个剪贴板项目")
        }
        
        // 恢复笔记
        if options.contains(.notes), let notes = backupData.notes {
            for noteData in notes {
                let descriptor = FetchDescriptor<NoteItem>(
                    predicate: #Predicate { $0.id == noteData.id }
                )
                let existing = try context.fetch(descriptor)
                
                if existing.isEmpty {
                    let note = noteData.toNoteItem()
                    context.insert(note)
                }
            }
            print("✅ 已恢复 \(notes.count) 个笔记")
        }
        
        // 恢复回收站
        if options.contains(.trash), let trashItems = backupData.trashItems {
            for trashData in trashItems {
                let descriptor = FetchDescriptor<TrashItem>(
                    predicate: #Predicate { $0.id == trashData.id }
                )
                let existing = try context.fetch(descriptor)
                
                if existing.isEmpty {
                    let trashItem = TrashItem(
                        id: trashData.id,
                        itemType: TrashItemType(rawValue: trashData.itemTypeRaw) ?? .clipboard,
                        originalId: trashData.originalId,
                        itemData: trashData.itemData,
                        deletedAt: trashData.deletedAt
                    )
                    context.insert(trashItem)
                }
            }
            print("✅ 已恢复 \(trashItems.count) 个回收站项目")
        }
        
        // 恢复设置
        if options.contains(.settings), let settings = backupData.settings {
            let userDefaults = UserDefaults.standard
            for (key, anyCodable) in settings {
                let value = anyCodable.value
                userDefaults.set(value, forKey: key)
            }
            print("✅ 已恢复设置")
        }
        
        // 保存上下文
        try context.save()
        print("✅ 恢复完成")
    }
    
    /// 验证备份文件
    func validateBackup(at url: URL) throws -> BackupData {
        let jsonData = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupData.self, from: jsonData)
    }
}

enum BackupError: LocalizedError {
    case contextNotSet
    case fileNotFound
    case invalidFormat
    case decodeFailed
    
    var errorDescription: String? {
        switch self {
        case .contextNotSet:
            return "ModelContext 未设置"
        case .fileNotFound:
            return "备份文件不存在"
        case .invalidFormat:
            return "备份文件格式无效"
        case .decodeFailed:
            return "解码备份文件失败"
        }
    }
}
