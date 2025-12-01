//
//  NoteRowCard.swift
//  EchoFlow
//
//  Created by keben on 2025/11/30.
//

import SwiftUI
import AppKit

/// 长条状笔记卡片视图 - 用于窗口模式
struct NoteRowCard: View {
    let note: NoteItem
    
    @Environment(\.modelContext) private var modelContext
    @AppStorage("cardFontName") private var cardFontName: String = "SF Pro Text"
    @AppStorage("cardFontSize") private var cardFontSize: Double = 12.0
    @State private var showEditView: Bool = false
    @State private var isHovered: Bool = false
    
    private var cardFont: Font {
        let fontSize = CGFloat(cardFontSize)
        if let font = NSFont(name: cardFontName, size: fontSize) {
            return Font(font)
        }
        return .system(size: fontSize, design: .default)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题栏
            HStack {
                // 标题 - 使用固定深色以在白色背景上保持可见（深色模式兼容）
                Text(note.title.isEmpty ? "未命名笔记" : note.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(NSColor.black))
                    .lineLimit(1)
                
                Spacer()
                
                // 锁定图标
                if note.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                
                // 更新时间 - 使用固定深灰色
                Text(note.relativeTimeString)
                    .font(.system(size: 11))
                    .foregroundColor(Color(NSColor.darkGray))
            }
            
            // 内容预览 - 使用固定深灰色
            if !note.content.isEmpty {
                Text(note.content)
                    .font(cardFont)
                    .foregroundColor(Color(NSColor.darkGray))
                    .lineLimit(3)
                    .truncationMode(.tail)
            } else {
                Text("空笔记")
                    .font(cardFont)
                    .foregroundColor(Color(NSColor.gray))
                    .italic()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .shadow(
            color: isHovered ? Color.blue.opacity(0.15) : Color.black.opacity(0.08),
            radius: isHovered ? 8 : 4,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            showEditView = true
        }
        .contextMenu {
            NoteRowContextMenu(note: note, onToggleLock: toggleLock, onDelete: deleteNote, onEdit: {
                showEditView = true
            })
        }
        .sheet(isPresented: $showEditView) {
            NoteEditView(note: note, isPresented: $showEditView)
        }
    }
    
    private func toggleLock() {
        note.isLocked.toggle()
        do {
            try modelContext.save()
        } catch {
            print("❌ 切换锁定状态失败: \(error)")
        }
    }
    
    private func deleteNote() {
        // 检查是否锁定
        if note.isLocked {
            let alert = NSAlert()
            alert.messageText = "无法删除"
            alert.informativeText = "该笔记已锁定，请先解锁后再删除"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }
        
        // 检查回收站是否启用
        if TrashManager.isEnabled {
            do {
                try TrashManager.shared.moveToTrash(note)
                print("🗑️ 笔记已移动到回收站")
            } catch {
                print("❌ 移动到回收站失败: \(error)")
            }
        } else {
            modelContext.delete(note)
            do {
                try modelContext.save()
                print("🗑️ 笔记已删除")
            } catch {
                print("❌ 删除失败: \(error)")
            }
        }
    }
}

// MARK: - Context Menu

private struct NoteRowContextMenu: View {
    let note: NoteItem
    let onToggleLock: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        Button("编辑") {
            onEdit()
        }
        
        Divider()
        
        Button(note.isLocked ? "解锁" : "锁定") {
            onToggleLock()
        }
        
        Divider()
        
        Button("删除", role: .destructive) {
            if !note.isLocked {
                onDelete()
            }
        }
        .disabled(note.isLocked)
    }
}
