//
//  TrashItem.swift
//  EchoFlow
//
//  Created by keben on 2025/11/30.
//

import Foundation
import SwiftData

/// 回收站项目类型
enum TrashItemType: String, Codable {
    case clipboard = "clipboard"
    case note = "note"
}

/// 回收站项目模型
@Model
final class TrashItem {
    /// 唯一标识符
    @Attribute(.unique) var id: UUID
    
    /// 项目类型
    var itemTypeRaw: String
    
    /// 原始项目的 ID（用于恢复时查找）
    var originalId: UUID
    
    /// 项目数据（JSON 编码的完整数据）
    var itemData: Data
    
    /// 删除时间
    var deletedAt: Date
    
    /// 项目类型枚举
    var itemType: TrashItemType {
        get { TrashItemType(rawValue: itemTypeRaw) ?? .clipboard }
        set { itemTypeRaw = newValue.rawValue }
    }
    
    /// 是否已过期（3天后）
    var isExpired: Bool {
        let threeDaysAgo = Date().addingTimeInterval(-3 * 24 * 3600)
        return deletedAt < threeDaysAgo
    }
    
    /// 剩余天数
    var remainingDays: Int {
        let threeDaysInSeconds: TimeInterval = 3 * 24 * 3600
        let expirationDate = deletedAt.addingTimeInterval(threeDaysInSeconds)
        let remaining = expirationDate.timeIntervalSinceNow
        return max(0, Int(ceil(remaining / (24 * 3600))))
    }
    
    init(
        id: UUID = UUID(),
        itemType: TrashItemType,
        originalId: UUID,
        itemData: Data,
        deletedAt: Date = Date()
    ) {
        self.id = id
        self.itemTypeRaw = itemType.rawValue
        self.originalId = originalId
        self.itemData = itemData
        self.deletedAt = deletedAt
    }
}
