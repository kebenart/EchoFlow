//
//  EchoFlowApp.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import SwiftUI
import SwiftData

@main
struct EchoFlowApp: App {
    // MARK: - Properties

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Model Container (静态变量，供 AppDelegate 访问)

    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ClipboardItem.self,
            NoteItem.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ SwiftData 容器创建成功")
            return container
        } catch {
            fatalError("❌ 无法创建 ModelContainer: \(error)")
        }
    }()

    // MARK: - Initialization

    init() {
        // 设置为 accessory 应用，隐藏 Dock 图标
        // 这必须在应用启动早期设置
    }

    // MARK: - Scene

    var body: some Scene {
        // MenuBar 应用 - 使用一个不可见的 WindowGroup
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .onAppear {
                    // 延迟关闭空白窗口，避免 ViewBridge 错误
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NSApplication.shared.windows.forEach { window in
                            // 只关闭不是 NSPanel 的窗口，并且确保窗口不是关键窗口
                            if !(window is NSPanel) && !window.isKeyWindow {
                                window.close()
                            }
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 0, height: 0)
        .commands {
            // 移除所有默认命令
            CommandGroup(replacing: .newItem) { }
        }
        .handlesExternalEvents(matching: []) // 防止创建多个窗口
    }
}
