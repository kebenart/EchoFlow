//
//  RootView.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import SwiftUI
import AppKit
import Combine

/// 内容模式
enum ContentMode: String, CaseIterable {
    case clipboard = "剪贴板"
    case notes = "笔记"
}

/// 主视图容器
struct RootView: View {
    @State private var contentMode: ContentMode = .clipboard
    @State private var searchText = ""
    @State private var showingSearch = false
    @State private var showingSettings = false
    @State private var showingTrash = false

    // 使用 @State 来观察 WindowManager 的变化
    @State private var windowManager = WindowManager.shared
    
    // 直接使用 WindowManager 的 dockPosition，这样当它改变时会自动刷新视图
    private var dockPosition: DockPosition {
        windowManager.dockPosition
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            if dockPosition.isHorizontal {
                horizontalToolbar
            } else {
                verticalToolbar
            }

            // 内容区（紧贴工具栏，无分隔线）
            contentArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)  // 确保从顶部开始，无额外边距
        .ignoresSafeArea(.all, edges: .top)  // 忽略顶部安全区域
        .background(.ultraThinMaterial)
        .onAppear {
            // 监听 Tab 键切换标签页
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Tab 键 (keyCode = 48) 且无修饰键
                if event.keyCode == 48 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                    // 使用通知来切换，避免闭包捕获问题
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchContentMode"), object: nil)
                    return nil // 消费事件
                }
                return event
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchContentMode"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                contentMode = contentMode == .clipboard ? .notes : .clipboard
            }
        }
        .onChange(of: showingSettings) { oldValue, newValue in
            if newValue {
                // 使用 WindowManager 创建居中的设置窗口
                // 必须传递 modelContainer，否则清空数据功能无法工作
                let settingsView = SettingsView()
                    .modelContainer(EchoFlowApp.sharedModelContainer)
                windowManager.createSettingsPanel(with: settingsView)
                showingSettings = false
            }
        }
        .onChange(of: showingTrash) { oldValue, newValue in
            if newValue {
                // 使用 WindowManager 创建回收站窗口
                let trashView = TrashView(isPresented: $showingTrash)
                    .modelContainer(EchoFlowApp.sharedModelContainer)
                windowManager.createTrashWindow(with: trashView)
                showingTrash = false
            }
        }
    }

    // MARK: - Horizontal Toolbar

    private var horizontalToolbar: some View {
        HStack(spacing: 16) {  // 添加整体间距
            // 模式切换
            Picker("", selection: $contentMode) {
                ForEach(ContentMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            Spacer()

            // 搜索图标或搜索框
            if showingSearch {
                // 搜索框
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    NonFocusableTextField(text: $searchText, placeholder: "搜索...")
                        .font(.system(size: 13))
                        .frame(width: 200)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // 关闭搜索框按钮
                    Button(action: { 
                        showingSearch = false
                        searchText = ""
                        // 让搜索框失焦，让卡片列表获得焦点
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            // 发送通知让 ClipboardListView 重置焦点
                            NotificationCenter.default.post(name: NSNotification.Name("ResetCardFocus"), object: nil)
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                // 搜索图标
                Button(action: { showingSearch = true }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("搜索")
            }

            Spacer()
            
            // 回收站按钮
            Button(action: openTrash) {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .help("回收站")

            // 设置按钮
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .help("设置")
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 0)
        .frame(height: 40)
        .animation(.easeInOut, value: showingSearch)
    }

    // MARK: - Vertical Toolbar

    private var verticalToolbar: some View {
        VStack(spacing: 8) {  // 从 10 减少到 8
            HStack(spacing: 12) {
                // 模式切换
                Picker("", selection: $contentMode) {
                    ForEach(ContentMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue)
                            .font(.system(size: 12))
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()

                // 搜索按钮
                Button(action: { showingSearch.toggle() }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("搜索")

                // 回收站按钮
                Button(action: openTrash) {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("回收站")
                
                // 设置按钮
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("设置")
            }

            // 搜索框 (折叠)
            if showingSearch {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    NonFocusableTextField(text: $searchText, placeholder: "搜索...")
                        .font(.system(size: 13))

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)  // 从 6 减少到 5
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 0)
        .animation(.easeInOut, value: showingSearch)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        switch contentMode {
        case .clipboard:
            ClipboardListView(searchText: $searchText, dockPosition: dockPosition)
        case .notes:
            NotesListView(searchText: $searchText, dockPosition: dockPosition)
        }
    }

    // MARK: - Actions

    private func openSettings() {
        showingSettings = true
    }
    
    private func openTrash() {
        showingTrash = true
    }
}

// MARK: - Non-Focusable TextField

/// 不会自动获得焦点的 TextField（用于搜索框）
private struct NonFocusableTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 13)
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.textChanged)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.text = $text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textChanged(_ sender: NSTextField) {
            text.wrappedValue = sender.stringValue
        }
    }
}

// MARK: - Preview

#Preview("Horizontal") {
    // 设置 WindowManager 的停靠位置用于预览
    WindowManager.shared.dockPosition = .bottom
    return RootView()
        .frame(width: 800, height: 180)
}

#Preview("Vertical") {
    // 设置 WindowManager 的停靠位置用于预览
    WindowManager.shared.dockPosition = .left
    return RootView()
        .frame(width: 280, height: 600)
}
