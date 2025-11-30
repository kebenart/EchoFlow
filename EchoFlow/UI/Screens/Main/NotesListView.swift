//
//  NotesListView.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import SwiftUI
import SwiftData
import AppKit

/// 笔记列表入口视图 (负责构建查询环境)
struct NotesListView: View {
    @Binding var searchText: String
    let dockPosition: DockPosition
    
    var body: some View {
        // 将具体列表逻辑剥离，确保 Query 能根据 searchText 动态重建
        NotesListContent(searchText: searchText, dockPosition: dockPosition)
    }
}

/// 笔记列表内容视图 (负责渲染、布局和键盘交互)
fileprivate struct NotesListContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [NoteItem]
    
    let dockPosition: DockPosition
    
    // MARK: - State
    /// 当前聚焦的索引 (-1 代表新建按钮, 0...N 代表笔记)
    @State private var focusedIndex: Int = 0
    /// 记录上次滚动到的索引，用于智能滚动判断
    @State private var lastScrolledIndex: Int = -1  // 初始为 -1（添加按钮位置）
    
    // MARK: - Init (Build Predicate)
    init(searchText: String, dockPosition: DockPosition) {
        self.dockPosition = dockPosition
        
        let predicate: Predicate<NoteItem>
        if searchText.isEmpty {
            predicate = #Predicate<NoteItem> { _ in true }
        } else {
            predicate = #Predicate<NoteItem> { note in
                note.content.localizedStandardContains(searchText)
            }
        }
        
        // 按更新时间倒序排列
        _notes = Query(filter: predicate, sort: \NoteItem.updatedAt, order: .reverse)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(dockPosition.isHorizontal ? .horizontal : .vertical, showsIndicators: false) {
                notesContent(proxy: proxy)
                    .padding(dockPosition.isHorizontal ? .horizontal : .vertical, 20)
                    .padding(dockPosition.isHorizontal ? .vertical : .horizontal, 14)
            }
            // 限制 ScrollView 的点击区域，避免拦截工具栏事件
            .contentShape(Rectangle())
            // 键盘事件监听（使用 hitTest 返回 nil 避免拦截鼠标事件）
            .background(KeyEventHandler(
                onLeftArrow:  { if dockPosition.isHorizontal { handleArrowKey(offset: -1, proxy: proxy) } },
                onRightArrow: { if dockPosition.isHorizontal { handleArrowKey(offset: 1, proxy: proxy) } },
                onUpArrow:    { if !dockPosition.isHorizontal { handleArrowKey(offset: -1, proxy: proxy) } },
                onDownArrow:  { if !dockPosition.isHorizontal { handleArrowKey(offset: 1, proxy: proxy) } }
            ))
            .onAppear {
                // 初始聚焦第一个笔记（如果有笔记），否则聚焦添加按钮
                if !notes.isEmpty {
                    focusedIndex = 0
                    lastScrolledIndex = 0
                } else {
                    focusedIndex = -1
                    lastScrolledIndex = -1
                }
            }
            .onChange(of: notes.count) { _, newCount in
                // 搜索或删除导致数量变化时，防止索引溢出
                if focusedIndex >= newCount {
                    let newIndex = max(-1, newCount - 1)
                    focusedIndex = newIndex
                    lastScrolledIndex = newIndex
                }
            }
        }
    }
    
    // MARK: - Content Builder
    
    @ViewBuilder
    private func notesContent(proxy: ScrollViewProxy) -> some View {
        if dockPosition.isHorizontal {
            LazyHStack(spacing: 16) {
                noteItems(proxy: proxy)
            }
        } else {
            LazyVStack(spacing: 16) {
                noteItems(proxy: proxy)
            }
        }
    }
    
    @ViewBuilder
    private func noteItems(proxy: ScrollViewProxy) -> some View {
        // 1. 新建笔记按钮 (Index: -1)
        AddNoteButton {
            // 点击时更新焦点并创建笔记
//            updateFocus(to: -1, proxy: proxy)
            createNewNote(proxy: proxy)
        }
        .id("add-button") // 用于滚动定位
        .modifier(FocusHighlightModifier(isFocused: focusedIndex == -1))
        .onTapGesture {
            // 鼠标点击使用智能滚动（不强制滚动）
            updateFocus(to: -1, proxy: proxy)
            createNewNote(proxy: proxy)
        }

        // 2. 笔记列表 (Index: 0...N)
        ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
            NoteCard(
                note: note,
                index: index,
                isFocused: index == focusedIndex,
                onTap: {
                    updateFocus(to: index, proxy: proxy)
                }
            )
            .id(note.id) // 使用 Stable ID 用于滚动定位
        }
    }

    // MARK: - Actions

    private func createNewNote(proxy: ScrollViewProxy) {
        let newNote = NoteItem()
        // 设置默认标题或其他属性
        newNote.content = "新笔记" 
        newNote.updatedAt = Date()
        
        modelContext.insert(newNote)
        
        // 插入后，由于是倒序，新笔记通常在 index 0
        // 稍微延迟以等待 Query 刷新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 新建笔记强制滚动到可见
            updateFocus(to: 0, proxy: proxy, forceScroll: true)
        }
    }
    
    private func updateFocus(to index: Int, proxy: ScrollViewProxy, forceScroll: Bool = false) {
        // 估算可视区域能容纳的卡片数量（卡片 240 + 间距 16 = 256，通常可见 3 张）
        // 可视范围：[lastScrolledIndex - 1, lastScrolledIndex + 1]
        let visibleRange = 1
        
        // 计算新索引是否在当前可视范围外
        let isOutOfVisibleRange = index < (lastScrolledIndex - visibleRange) || 
                                   index > (lastScrolledIndex + visibleRange)
        let shouldScroll = forceScroll || isOutOfVisibleRange
        
        withAnimation(.easeInOut(duration: 0.25)) {
            focusedIndex = index
            
            // 智能滚动：只在卡片即将离开可视区域时才滚动
            if shouldScroll {
                if index == -1 {
                    // 滚动到添加按钮
                    proxy.scrollTo("add-button", anchor: .center)
                } else if index >= 0 && index < notes.count {
                    // 滚动到笔记卡片
                    proxy.scrollTo(notes[index].id, anchor: .center)
                }
                // 更新上次滚动位置
                lastScrolledIndex = index
            }
        }
    }
    
    private func handleArrowKey(offset: Int, proxy: ScrollViewProxy) {
        let totalCount = notes.count
        let minIndex = -1 // Add Button
        let maxIndex = totalCount - 1
        
        var nextIndex = focusedIndex + offset
        
        // 边界限制
        if nextIndex < minIndex { nextIndex = minIndex }
        if nextIndex > maxIndex { nextIndex = maxIndex }
        
        if nextIndex != focusedIndex {
            updateFocus(to: nextIndex, proxy: proxy)
        }
    }
}

// MARK: - Helper Views

/// 新建笔记按钮组件
struct AddNoteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                Text("新建笔记")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .frame(width: 240, height: 240)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.blue.opacity(0.5),
                        style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

/// 焦点高亮修饰符 (用于 AddButton)
struct FocusHighlightModifier: ViewModifier {
    let isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 3)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

/// 键盘事件处理 (macOS NSView 桥接)
private struct KeyEventHandler: NSViewRepresentable {
    var onLeftArrow: (() -> Void)?
    var onRightArrow: (() -> Void)?
    var onUpArrow: (() -> Void)?
    var onDownArrow: (() -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        updateKeyView(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? KeyView {
            updateKeyView(view)
        }
    }
    
    private func updateKeyView(_ view: KeyView) {
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow
        view.onUpArrow = onUpArrow
        view.onDownArrow = onDownArrow
    }
    
    private class KeyView: NSView {
        var onLeftArrow: (() -> Void)?
        var onRightArrow: (() -> Void)?
        var onUpArrow: (() -> Void)?
        var onDownArrow: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                self?.window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 123: onLeftArrow?()
            case 124: onRightArrow?()
            case 126: onUpArrow?()
            case 125: onDownArrow?()
            default: super.keyDown(with: event)
            }
        }
    }
}
