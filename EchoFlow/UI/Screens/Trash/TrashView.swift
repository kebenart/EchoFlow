//
//  TrashView.swift
//  EchoFlow
//
//  Created by keben on 2025/11/30.
//

import SwiftUI
import SwiftData

/// 回收站视图
struct TrashView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrashItem.deletedAt, order: .reverse) private var trashItems: [TrashItem]
    @State private var selectedItems: Set<UUID> = []
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            Divider()
            
            // 列表内容
            if trashItems.isEmpty {
                emptyStateView
            } else {
                listView
            }
            
            Divider()
            
            // 底部操作栏
            footerView
        }
        .frame(width: 600, height: 500)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "trash")
                .font(.title2)
                .foregroundColor(.orange)
            
            Text("回收站")
                .font(.headline)
            
            Spacer()
            
            Text("\(trashItems.count) 个项目")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: { 
                WindowManager.shared.closeTrashWindow()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("回收站为空")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("删除的项目会在这里保留 3 天")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - List View
    
    private var listView: some View {
        List(selection: $selectedItems) {
            ForEach(trashItems) { item in
                TrashItemRow(item: item)
                    .tag(item.id)
                    .contentShape(Rectangle())
            }
        }
        .listStyle(.plain)
        .onDeleteCommand {
            // 支持 ⌘Delete 快捷键删除选中项
            if !selectedItems.isEmpty {
                deleteSelected()
            }
        }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            // 选中数量
            if !selectedItems.isEmpty {
                Text("已选择 \(selectedItems.count) 项")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 12) {
                // 恢复选中
                Button("恢复选中") {
                    restoreSelected()
                }
                .disabled(selectedItems.isEmpty)
                
                // 删除选中
                Button("删除选中") {
                    deleteSelected()
                }
                .disabled(selectedItems.isEmpty)
                .foregroundColor(.red)
                
                Divider()
                    .frame(height: 20)
                
                // 清空回收站
                Button("清空回收站") {
                    emptyTrash()
                }
                .disabled(trashItems.isEmpty)
                .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func restoreSelected() {
        let itemsToRestore = trashItems.filter { selectedItems.contains($0.id) }
        
        guard !itemsToRestore.isEmpty else { return }
        
        // 批量恢复，使用批量操作提高性能
        do {
            try TrashManager.shared.restoreBatch(itemsToRestore)
            // 线程安全地清除缓存
            TrashItemRow.cacheQueue.async(flags: .barrier) {
                for item in itemsToRestore {
                    TrashItemRow.contentCache.removeValue(forKey: item.id)
                }
            }
        } catch {
            print("❌ 批量恢复失败: \(error)")
            // 如果批量失败，尝试单个恢复
            for item in itemsToRestore {
                do {
                    try TrashManager.shared.restore(item)
                    TrashItemRow.cacheQueue.async(flags: .barrier) {
                        TrashItemRow.contentCache.removeValue(forKey: item.id)
                    }
                } catch {
                    print("❌ 恢复失败: \(error)")
                }
            }
        }
        
        selectedItems.removeAll()
    }
    
    private func deleteSelected() {
        let itemsToDelete = trashItems.filter { selectedItems.contains($0.id) }
        
        guard !itemsToDelete.isEmpty else { return }
        
        let alert = NSAlert()
        alert.messageText = "确认删除"
        alert.informativeText = "确定要永久删除选中的 \(itemsToDelete.count) 个项目吗？此操作无法撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // 批量删除，使用批量操作提高性能
            do {
                try TrashManager.shared.permanentlyDeleteBatch(itemsToDelete)
                // 线程安全地清除缓存
                TrashItemRow.cacheQueue.async(flags: .barrier) {
                    for item in itemsToDelete {
                        TrashItemRow.contentCache.removeValue(forKey: item.id)
                    }
                }
            } catch {
                print("❌ 批量删除失败: \(error)")
                // 如果批量失败，尝试单个删除
                for item in itemsToDelete {
                    do {
                        try TrashManager.shared.permanentlyDelete(item)
                        TrashItemRow.cacheQueue.async(flags: .barrier) {
                            TrashItemRow.contentCache.removeValue(forKey: item.id)
                        }
                    } catch {
                        print("❌ 删除失败: \(error)")
                    }
                }
            }
            selectedItems.removeAll()
        }
    }
    
    private func emptyTrash() {
        let alert = NSAlert()
        alert.messageText = "确认清空"
        alert.informativeText = "确定要清空回收站吗？此操作无法撤销，所有项目将被永久删除。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try TrashManager.shared.emptyTrash()
                // 线程安全地清空缓存
                TrashItemRow.cacheQueue.async(flags: .barrier) {
                    TrashItemRow.contentCache.removeAll()
                }
            } catch {
                print("❌ 清空回收站失败: \(error)")
            }
        }
    }
}

// MARK: - Trash Item Row

private struct TrashItemRow: View, Equatable {
    let item: TrashItem
    let decodedContent: String
    let itemTypeName: String
    
    // 使用静态缓存来避免重复解码（线程安全）
    static var contentCache: [UUID: (content: String, typeName: String)] = [:]
    static let cacheQueue = DispatchQueue(label: "com.echoflow.trash.cache", attributes: .concurrent)
    
    init(item: TrashItem) {
        self.item = item
        
        // 线程安全地检查缓存
        var cached: (content: String, typeName: String)?
        Self.cacheQueue.sync {
            cached = Self.contentCache[item.id]
        }
        
        if let cached = cached {
            self.decodedContent = cached.content
            self.itemTypeName = cached.typeName
        } else {
            // 解码并缓存
            let (content, typeName) = Self.decodeContent(for: item)
            Self.cacheQueue.async(flags: .barrier) {
                Self.contentCache[item.id] = (content, typeName)
            }
            self.decodedContent = content
            self.itemTypeName = typeName
        }
    }
    
    static func == (lhs: TrashItemRow, rhs: TrashItemRow) -> Bool {
        return lhs.item.id == rhs.item.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            Image(systemName: item.itemType == .clipboard ? "doc.on.clipboard" : "note.text")
                .foregroundColor(item.itemType == .clipboard ? .blue : .orange)
                .frame(width: 24)
            
            // 内容预览
            VStack(alignment: .leading, spacing: 4) {
                Text(itemTypeName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(decodedContent)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 剩余时间
            VStack(alignment: .trailing, spacing: 4) {
                if item.isExpired {
                    Text("已过期")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("\(item.remainingDays) 天后删除")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(item.deletedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100)
            
            // 操作按钮
            HStack(spacing: 8) {
                Button(action: { restoreItem() }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("恢复")
                
                Button(action: { deleteItem() }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("永久删除")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
    
    private static func decodeContent(for item: TrashItem) -> (content: String, typeName: String) {
        do {
            let decoder = JSONDecoder()
            switch item.itemType {
            case .clipboard:
                let data = try decoder.decode(ClipboardItemData.self, from: item.itemData)
                let preview = String(data.content.prefix(100))
                let content = preview.count < data.content.count ? preview + "..." : preview
                let typeName = "剪贴板: \(ContentType(rawValue: data.typeRaw)?.displayName ?? "未知")"
                return (content, typeName)
            case .note:
                let data = try decoder.decode(NoteItemData.self, from: item.itemData)
                let preview = String(data.content.prefix(100))
                let content = preview.count < data.content.count ? preview + "..." : preview
                return (content, "笔记")
            }
        } catch {
            return ("无法解码内容", item.itemType == .clipboard ? "剪贴板" : "笔记")
        }
    }
    
    private func restoreItem() {
        do {
            try TrashManager.shared.restore(item)
            // 线程安全地清除缓存
            TrashItemRow.cacheQueue.async(flags: .barrier) {
                TrashItemRow.contentCache.removeValue(forKey: item.id)
            }
        } catch {
            print("❌ 恢复失败: \(error)")
        }
    }
    
    private func deleteItem() {
        let alert = NSAlert()
        alert.messageText = "确认删除"
        alert.informativeText = "确定要永久删除这个项目吗？此操作无法撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try TrashManager.shared.permanentlyDelete(item)
                // 线程安全地清除缓存
                TrashItemRow.cacheQueue.async(flags: .barrier) {
                    TrashItemRow.contentCache.removeValue(forKey: item.id)
                }
            } catch {
                print("❌ 删除失败: \(error)")
            }
        }
    }
}
