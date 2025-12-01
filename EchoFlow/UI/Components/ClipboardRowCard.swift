//
//  ClipboardRowCard.swift
//  EchoFlow
//
//  Created by keben on 2025/11/30.
//

import SwiftUI
import AppKit

/// 长条状剪贴板卡片视图 - 使用 BaseClipboardContentView 实现
struct ClipboardRowCard: View {
    let item: ClipboardItem
    let index: Int
    let isFocused: Bool
    let timeRefreshTrigger: Int
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        BaseClipboardContentView(
            item: item,
            index: index,
            isFocused: isFocused,
            timeRefreshTrigger: timeRefreshTrigger,
            config: .row,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onDelete: onDelete
        )
    }
}

// MARK: - Convenience Initializer (保持向后兼容)

extension ClipboardRowCard {
    /// 简化初始化器（不需要 timeRefreshTrigger）
    init(
        item: ClipboardItem,
        index: Int = 0,
        isFocused: Bool = false,
        onTap: @escaping () -> Void = {},
        onDoubleTap: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) {
        self.item = item
        self.index = index
        self.isFocused = isFocused
        self.timeRefreshTrigger = 0
        self.onTap = onTap
        self.onDoubleTap = onDoubleTap
        self.onDelete = onDelete
    }
}
