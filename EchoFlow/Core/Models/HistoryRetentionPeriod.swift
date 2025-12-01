//
//  HistoryRetentionPeriod.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import Foundation

/// 历史记录保留时间选项
enum HistoryRetentionPeriod: String, CaseIterable {
    case oneDay = "1day"
    case oneWeek = "7days"
    case oneMonth = "1month"
    case oneYear = "1year"
    case forever = "forever"
    
    var displayName: String {
        switch self {
        case .oneDay: return "1天"
        case .oneWeek: return "7天"
        case .oneMonth: return "1个月"
        case .oneYear: return "1年"
        case .forever: return "永久(Pro)"
        }
    }
    
    var timeInterval: TimeInterval? {
        switch self {
        case .oneDay: return 86400 // 1天
        case .oneWeek: return 604800 // 7天
        case .oneMonth: return 2592000 // 30天
        case .oneYear: return 31536000 // 365天
        case .forever: return nil // 永久保留
        }
    }
    
    var isProFeature: Bool {
        return self == .forever
    }
}




