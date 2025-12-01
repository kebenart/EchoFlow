//
//  NoteCard.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import SwiftUI

/// 笔记卡片视图
struct NoteCard: View, Equatable {
    let note: NoteItem
    let index: Int
    let isFocused: Bool
    let onTap: () -> Void
    
    // MARK: - Local State
    @State private var isEditingTitle = false
    @State private var isEditingContent = false
    
    // 临时编辑缓存
    @State private var editingTitle: String = ""
    @State private var editingContent: String = ""
    
    @Environment(\.modelContext) private var modelContext

    // MARK: - Equatable Implementation
    // 关键优化：只在关键属性变化时重绘，极大提升列表滚动性能
    static func == (lhs: NoteCard, rhs: NoteCard) -> Bool {
        return lhs.note.id == rhs.note.id &&
               lhs.note.updatedAt == rhs.note.updatedAt && // 监听内容变更
               lhs.index == rhs.index &&
               lhs.isFocused == rhs.isFocused
    }

    var body: some View {
        Button(action: handleSingleTap) {
            cardContent
        }
        .buttonStyle(NoteCardButtonStyle()) // 使用原生风格避免手势冲突
        // 仅在聚焦时允许双击编辑
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            if isFocused && !isEditingTitle && !isEditingContent {
                startEditingContent()
            }
        })
        .contextMenu {
            NoteCardContextMenu(
                note: note,
                onToggleLock: {
                    toggleLock()
                },
                onDelete: {
                    deleteNote()
                }
            )
        }
        .onAppear(perform: syncStateFromModel)
        // 监听焦点丢失，自动保存
        .onChange(of: isFocused) { _, newValue in
            if !newValue { handleLostFocus() }
        }
    }

    // MARK: - Subviews

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            bodyTextView
            footerView
        }
        .padding(18)
        .frame(width: 240, height: 240)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // 样式修饰符提取
        .modifier(CardStyleModifier(
            isFocused: isFocused,
            themeColor: note.uiColor
        ))
        // 使用 ID 强制刷新视图（解决 TextField 有时无法获取焦点的问题）
        .id("card-\(note.id)-\(isFocused)")
    }

    @ViewBuilder
    private var headerView: some View {
        if isEditingTitle {
            TextField("标题", text: $editingTitle, onCommit: saveTitle)
                .font(.system(size: 13, weight: .semibold))
                .textFieldStyle(.plain)
                .foregroundColor(.primary)
                .onChange(of: isFocused) { _, newValue in
                    // 失去焦点时自动保存
                    if !newValue && isEditingTitle {
                        saveTitle()
                    }
                }
        } else {
            Text(note.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .allowsHitTesting(false) // 允许点击穿透给 Button
        }
    }

    @ViewBuilder
    private var bodyTextView: some View {
        if isEditingContent {
            // 自定义 NSViewWrapper 用于多行编辑和 ESC 捕捉
            NoteTextEditor(
                text: $editingContent,
                onSave: saveContent,
                onFocusLost: {
                    // 失去焦点时自动保存
                    if isEditingContent {
                        saveContent()
                    }
                }
            )
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(maxHeight: .infinity)
            .onChange(of: isFocused) { _, newValue in
                // 卡片失去焦点时自动保存
                if !newValue && isEditingContent {
                    saveContent()
                }
            }
        } else {
            Text(note.contentPreview)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(8)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
        }
    }

    private var footerView: some View {
        HStack {
            if note.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
            Spacer()
            Text(note.relativeTimeString)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Logic & Actions

    private func handleSingleTap() {
        if !isEditingTitle && !isEditingContent {
            onTap()
        }
    }

    private func startEditingContent() {
        syncStateFromModel() // 确保编辑前数据最新
        isEditingContent = true
    }

    private func syncStateFromModel() {
        editingTitle = note.title
        editingContent = note.content
    }

    private func handleLostFocus() {
        if isEditingTitle { saveTitle() }
        if isEditingContent { saveContent() }
        
        // 退出编辑状态
        isEditingTitle = false
        isEditingContent = false
        
        // 保存后重新同步，防止本地缓存过时
        syncStateFromModel()
    }

    private func saveTitle() {
        guard editingTitle != note.title else { 
            isEditingTitle = false
            return 
        }
        
        note.updateTitle(editingTitle)
        saveContext()
        isEditingTitle = false
        // 因为 updateTitle 修改了底层 content，需要刷新 content 缓存
        editingContent = note.content
    }

    private func saveContent() {
        guard editingContent != note.content else { 
            isEditingContent = false
            return 
        }
        
        note.content = editingContent
        saveContext()
        isEditingContent = false
        // 刷新 Title 缓存
        editingTitle = note.title
    }

    private func saveContext() {
        note.updatedAt = Date() // 手动更新时间戳触发排序
        do {
            try modelContext.save()
        } catch {
            print("❌ 保存失败: \(error)")
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
            // 显示提示，告知用户需要先解锁
            let alert = NSAlert()
            alert.messageText = "无法删除"
            alert.informativeText = "该笔记已锁定，请先解锁后再删除。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "知道了")
            alert.runModal()
            return
        }
        
        // 检查是否启用回收站
        if TrashManager.isEnabled {
            // 移动到回收站
            do {
                try TrashManager.shared.moveToTrash(note)
            } catch {
                print("❌ 移动到回收站失败: \(error)")
                // 如果失败，直接删除
                modelContext.delete(note)
                try? modelContext.save()
            }
        } else {
            // 直接删除
            modelContext.delete(note)
            try? modelContext.save()
        }
    }
}

// MARK: - Note Card Context Menu

private struct NoteCardContextMenu: View {
    let note: NoteItem
    let onToggleLock: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(note.isLocked ? "解锁" : "锁定") {
            onToggleLock()
        }
        
        Divider()
        
        Button("删除", role: .destructive) {
            onDelete()
        }
        .disabled(note.isLocked) // 锁定状态下禁用删除按钮
    }
}

// MARK: - Styling Components

struct CardStyleModifier: ViewModifier {
    let isFocused: Bool
    let themeColor: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isFocused ? Color.blue : themeColor.opacity(0.5),
                        lineWidth: isFocused ? 3 : 2
                    )
            )
            .shadow(
                color: isFocused ? Color.blue.opacity(0.3) : Color.black.opacity(0.1),
                radius: isFocused ? 16 : 12,
                x: 0,
                y: isFocused ? 8 : 6
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            // 关键优化：仅对焦点变化做 Snappy 动画，避免列表加载时的动画干扰
            .animation(.snappy(duration: 0.2), value: isFocused)
    }
}

struct NoteCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Text Editor Wrapper

struct NoteTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onSave: () -> Void
    var onFocusLost: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        // 隐藏滚动条
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 11)
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: -4, height: 0)
        
        // 监听窗口失去焦点
        context.coordinator.setupFocusNotifications(for: textView)
        
        // 自动聚焦
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
        // 更新 coordinator 的 onFocusLost 回调
        context.coordinator.onFocusLost = onFocusLost
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteTextEditor
        var onFocusLost: (() -> Void)?
        private var focusObserver: NSObjectProtocol?
        
        init(_ parent: NoteTextEditor) {
            self.parent = parent
            self.onFocusLost = parent.onFocusLost
        }
        
        func setupFocusNotifications(for textView: NSTextView) {
            // 监听文本编辑结束（当用户点击其他地方或切换焦点时）
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleTextDidEndEditing),
                name: NSText.didEndEditingNotification,
                object: textView
            )
            
            // 监听窗口失去焦点
            if let window = textView.window {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(windowDidResignKey),
                    name: NSWindow.didResignKeyNotification,
                    object: window
                )
            }
        }
        
        @objc private func windowDidResignKey(_ notification: Notification) {
            // 窗口失去焦点时保存
            handleFocusLost()
        }
        
        @objc private func handleTextDidEndEditing(_ notification: Notification) {
            // 文本编辑结束时保存
            handleFocusLost()
        }
        
        private func handleFocusLost() {
            // 延迟一点保存，确保文本已更新
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.onFocusLost?()
            }
        }
        
        deinit {
            if let observer = focusObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            NotificationCenter.default.removeObserver(self)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
        
        // NSTextDelegate 方法：文本编辑结束（必须与协议一致）
        func textDidEndEditing(_ notification: Notification) {
            // 文本编辑结束时保存
            handleFocusLost()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // ESC 退出保存
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onSave()
                return true
            }
            return false
        }
    }
}