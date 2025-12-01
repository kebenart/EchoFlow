//
//  ClipboardWindowView.swift
//  EchoFlow
//
//  Created by keben on 2025/11/30.
//

import SwiftUI
import SwiftData

/// 窗口模式的剪贴板列表视图
struct ClipboardWindowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var clipboardItems: [ClipboardItem]
    @Query(sort: \NoteItem.updatedAt, order: .reverse) private var noteItems: [NoteItem]
    
    @State private var searchText: String = ""
    @State private var focusedIndex: Int = 0
    @State private var timeRefreshTrigger: Int = 0
    @State private var selectedTab: WindowTab = .clipboard
    @State private var isAlwaysOnTop: Bool = UserDefaults.standard.bool(forKey: "alwaysOnTop")
    @State private var copyToastMessage: String?
    @State private var isShowingCopyToast: Bool = false
    
    @AppStorage("copyBehavior") private var copyBehaviorRaw: String = "copyToPasteboard"
    
    enum WindowTab: String, CaseIterable {
        case clipboard = "剪贴板"
        case notes = "笔记"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbarView
            
            Divider()
            
            // 标签切换
            tabPickerView
            
            Divider()
            
            // 内容区域
            if selectedTab == .clipboard {
                clipboardListView
            } else {
                notesListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            if isShowingCopyToast, let message = copyToastMessage {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onKeyPress(.tab) {
            toggleTab()
            return .handled
        }
        .onAppear {
            resetFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UpdateTimeOnly"))) { _ in
            timeRefreshTrigger += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewClipboardItemAdded"))) { _ in
            resetFocus()
        }
    }
    
    // MARK: - Subviews
    
    private var toolbarView: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Spacer()
            
            // 置顶按钮
            Button(action: toggleAlwaysOnTop) {
                Image(systemName: isAlwaysOnTop ? "pin.fill" : "pin.slash")
                    .font(.system(size: 16))
                    .foregroundColor(isAlwaysOnTop ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .help(isAlwaysOnTop ? "取消置顶" : "窗口置顶")
            
            // 设置按钮
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .help("设置")
            
            // 回收站按钮
            Button(action: openTrash) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .help("回收站")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    private var tabPickerView: some View {
        Picker("", selection: $selectedTab) {
            ForEach(WindowTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onChange(of: selectedTab) { _, _ in
            resetFocus()
        }
    }
    
    private var clipboardListView: some View {
        Group {
            if filteredClipboardItems.isEmpty {
                emptyStateView
            } else {
                ClipboardWindowListView(
                    items: filteredClipboardItems,
                    searchText: searchText,
                    focusedIndex: $focusedIndex,
                    timeRefreshTrigger: timeRefreshTrigger,
                    onItemSelected: { index, item in
                        handleCardSingleTap(at: index)
                    },
                    onItemDoubleClick: { item in
                        handleCardDoubleTap(at: filteredClipboardItems.firstIndex(where: { $0.id == item.id }) ?? 0)
                    },
                    onTabKey: {
                        toggleTab()
                    },
                    onDelete: { item in
                        deleteItem(item)
                    }
                )
            }
        }
    }
    
    private var notesListView: some View {
        Group {
            if filteredNoteItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "note.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("暂无笔记")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("创建笔记来记录重要内容")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredNoteItems) { note in
                            NoteRowCard(note: note)
                                .padding(.horizontal, 12)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("暂无剪贴板内容")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("复制一些内容来开始使用")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var filteredClipboardItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardItems
        } else {
            return clipboardItems.filter { item in
                item.content.localizedStandardContains(searchText) ||
                item.sourceApp.localizedStandardContains(searchText)
            }
        }
    }
    
    private var filteredNoteItems: [NoteItem] {
        if searchText.isEmpty {
            return noteItems
        } else {
            return noteItems.filter { note in
                note.title.localizedStandardContains(searchText) ||
                note.content.localizedStandardContains(searchText)
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleCardSingleTap(at index: Int) {
        guard index < filteredClipboardItems.count else { return }
        focusedIndex = index
    }
    
    private func handleCardDoubleTap(at index: Int) {
        guard index < filteredClipboardItems.count else { return }
        focusedIndex = index
        copyToPasteboard(filteredClipboardItems[index])
    }
    
    private func toggleAlwaysOnTop() {
        isAlwaysOnTop.toggle()
        UserDefaults.standard.set(isAlwaysOnTop, forKey: "alwaysOnTop")
        WindowManager.shared.isAlwaysOnTop = isAlwaysOnTop
    }
    
    private func toggleTab() {
        selectedTab = selectedTab == .clipboard ? .notes : .clipboard
    }
    
    private func copyToPasteboard(_ item: ClipboardItem) {
        print("📋 复制内容: \(item.content.prefix(20))...")
        
        // 执行复制逻辑
        switch item.type {
        case .image:
            if item.content.starts(with: "/") {
                let fileURL = URL(fileURLWithPath: item.content)
                PasteboardManager.shared.writeToPasteboard(fileURLs: [fileURL])
            } else if let imageData = item.imageData, let image = NSImage(data: imageData) {
                PasteboardManager.shared.writeToPasteboard(image: image)
            } else {
                PasteboardManager.shared.writeToPasteboard(content: item.content)
            }
        case .file:
            let paths = item.content.split(separator: "\n").map { String($0) }
            let fileURLs = paths.map { URL(fileURLWithPath: $0) }
            PasteboardManager.shared.writeToPasteboard(fileURLs: fileURLs)
        default:
            PasteboardManager.shared.writeToPasteboard(content: item.content)
        }
        
        NSSound.beep()
        
        // 根据复制行为决定是否粘贴
        let shouldPaste = (copyBehaviorRaw == "copyToCurrentApp")
        if shouldPaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                PasteSimulator.shared.simulatePaste(delay: 0.05)
            }
        }
        
        // 显示复制成功提示，由全局剪贴板监听负责后续时间戳更新与列表刷新
        showCopyToast("已复制到剪贴板")
    }
    
    private func deleteItem(_ item: ClipboardItem) {
        // 检查是否锁定
        if item.isLocked {
            let alert = NSAlert()
            alert.messageText = "无法删除"
            alert.informativeText = "该卡片已锁定，请先解锁后再删除"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }
        
        // 检查回收站是否启用
        if TrashManager.isEnabled {
            do {
                try TrashManager.shared.moveToTrash(item)
                print("🗑️ 已移动到回收站")
            } catch {
                print("❌ 移动到回收站失败: \(error)")
            }
        } else {
            modelContext.delete(item)
            do {
                try modelContext.save()
                print("🗑️ 已删除")
            } catch {
                print("❌ 删除失败: \(error)")
            }
        }
    }
    
    // MARK: - Toast
    
    private func showCopyToast(_ text: String) {
        copyToastMessage = text
        withAnimation(.easeOut(duration: 0.15)) {
            isShowingCopyToast = true
        }
        
        // 自动隐藏，若期间有新的复制提示则以最新一次为准
        let currentText = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copyToastMessage == currentText {
                withAnimation(.easeIn(duration: 0.15)) {
                    isShowingCopyToast = false
                }
            }
        }
    }
    
    private func resetFocus() {
        focusedIndex = 0
    }
    
    private func openSettings() {
        let container = EchoFlowApp.sharedModelContainer
        let settingsView = SettingsView()
            .modelContainer(container)
        
        WindowManager.shared.createSettingsPanel(with: settingsView)
    }
    
    private func openTrash() {
        // 创建回收站视图并显示
        Task { @MainActor in
            let container = EchoFlowApp.sharedModelContainer
            let trashView = TrashView(isPresented: .constant(true))
                .modelContainer(container)
            
            WindowManager.shared.createTrashWindow(with: trashView)
        }
    }
}
