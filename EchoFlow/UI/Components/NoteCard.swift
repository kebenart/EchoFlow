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
            NoteTextEditor(text: $editingContent, onSave: saveContent)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(maxHeight: .infinity)
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

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 11)
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: -4, height: 0) 
        
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
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteTextEditor
        init(_ parent: NoteTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
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