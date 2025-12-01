//
//  NoteEditView.swift
//  EchoFlow
//
//  Created by keben on 2025/11/30.
//

import SwiftUI
import SwiftData
import AppKit

// MARK: - 多行文本编辑器（支持回车换行）
struct MultilineTextEditor: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        // 创建滚动视图
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        
        // 创建文本容器
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        
        // 创建布局管理器
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        
        // 创建文本存储
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        
        // 创建 NSTextView
        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        
        // 禁用自动替换
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        
        // 关键配置：允许回车换行
        textView.isFieldEditor = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        // 设置滚动视图
        scrollView.documentView = textView
        
        // 设置代理
        textView.delegate = context.coordinator
        
        // 设置初始文本
        textView.string = text
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // 只有当文本真的不同且不在编辑时才更新
        if textView.string != text && !context.coordinator.isEditing {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MultilineTextEditor
        var isEditing = false
        
        init(_ parent: MultilineTextEditor) {
            self.parent = parent
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }
        
        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
        
        // 关键：允许回车键换行
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                textView.insertNewlineIgnoringFieldEditor(nil)
                return true
            }
            return false
        }
    }
}

// MARK: - 笔记编辑视图

/// 窗口模式下的笔记编辑视图
struct NoteEditView: View {
    let note: NoteItem
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var title: String
    @State private var content: String
    @FocusState private var focusedField: Field?
    
    enum Field {
        case title
        case content
    }
    
    init(note: NoteItem, isPresented: Binding<Bool>) {
        self.note = note
        self._isPresented = isPresented
        
        // 从content中提取标题和内容
        let lines = note.content.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        if lines.count > 1 {
            self._title = State(initialValue: String(lines[0]))
            self._content = State(initialValue: String(lines[1]))
        } else {
            self._title = State(initialValue: note.content)
            self._content = State(initialValue: "")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack(spacing: 12) {
                Image(systemName: "note.text")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                
                Text("编辑笔记")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Button(action: saveAndClose) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("完成")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
            
            Divider()
            
            // 编辑区域
            VStack(spacing: 16) {
                // 标题输入框
                VStack(alignment: .leading, spacing: 6) {
                    Text("标题")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("输入笔记标题...", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    focusedField == .title ? Color.blue.opacity(0.5) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .focused($focusedField, equals: .title)
                }
                
                // 内容输入框
                VStack(alignment: .leading, spacing: 6) {
                    Text("内容")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("在这里记录你的想法...")
                                .foregroundColor(.secondary.opacity(0.4))
                                .font(.system(size: 14))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                        
                        MultilineTextEditor(text: $content)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .focused($focusedField, equals: .content)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                focusedField == .content ? Color.blue.opacity(0.5) : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
            }
            .padding(20)
        }
        .frame(width: 600, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            focusedField = .title
        }
    }
    
    private func saveAndClose() {
        // 合并标题和内容
        if title.isEmpty && content.isEmpty {
            note.content = ""
        } else if content.isEmpty {
            note.content = title
        } else {
            note.content = title + "\n" + content
        }
        
        note.updatedAt = Date()
        
        do {
            try modelContext.save()
            print("✅ 笔记已保存")
        } catch {
            print("❌ 保存笔记失败: \(error)")
        }
        
        isPresented = false
    }
}
