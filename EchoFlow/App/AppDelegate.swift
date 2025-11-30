//
//  AppDelegate.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import AppKit
import SwiftUI
import SwiftData

/// 应用生命周期管理
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private let windowManager = WindowManager.shared
    private let pasteboardManager = PasteboardManager.shared
    private let hotKeyManager = HotKeyManager.shared

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 EchoFlow 启动中...")

        // 隐藏 Dock 图标（设置为 accessory 应用）
        NSApp.setActivationPolicy(.accessory)
        
        // 从 UserDefaults 加载停靠位置设置
        if let savedPosition = UserDefaults.standard.string(forKey: "dockPosition"),
           let position = DockPosition(rawValue: savedPosition) {
            windowManager.dockPosition = position
            print("📋 已加载保存的停靠位置: \(position.rawValue)")
        }

        // 获取共享的 ModelContainer
        let container = EchoFlowApp.sharedModelContainer

        // 创建主面板
        let windowManager = WindowManager.shared
        let rootView = RootView()
            .modelContainer(container)

        windowManager.createPanel(with: rootView)

        // 设置菜单栏图标（根据设置决定是否显示）
        // 延迟创建以确保系统准备就绪
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            if UserDefaults.standard.object(forKey: "showStatusBarIcon") == nil {
                UserDefaults.standard.set(true, forKey: "showStatusBarIcon")
            }
            if UserDefaults.standard.bool(forKey: "showStatusBarIcon") {
                self.setupMenuBarItem()
            }
        }
        
        // 监听状态栏图标显示设置的变化
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UpdateStatusBarIcon"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let show = notification.userInfo?["show"] as? Bool else { return }
            if show {
                if self.statusItem == nil {
                    self.setupMenuBarItem()
                }
            } else {
                if let statusItem = self.statusItem {
                    NSStatusBar.system.removeStatusItem(statusItem)
                    self.statusItem = nil
                }
            }
        }

        // 配置热键
        setupHotKeys()

        // 启动剪贴板监听
        pasteboardManager.modelContext = container.mainContext
        print("🔗 已设置 ModelContext 到 PasteboardManager")
        pasteboardManager.startMonitoring()
        
        // 初始化历史记录清理管理器
        HistoryCleanupManager.shared.modelContext = container.mainContext
        print("🧹 已设置 ModelContext 到 HistoryCleanupManager")
        
        // 生成样例数据（如果需要）
        SampleDataGenerator.shared.generateSampleDataIfNeeded(context: container.mainContext)

        // 延迟关闭空白窗口（确保面板已创建）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.windows.forEach { window in
                // 只关闭不是 NSPanel 的窗口，并且确保窗口不是关键窗口
                if !(window is NSPanel) && !window.isKeyWindow {
                    window.close()
                }
            }
        }
        
        // 检查更新（根据用户设置）
        checkForUpdatesOnLaunch()

        print("✅ EchoFlow 启动完成")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 停止监听
        pasteboardManager.stopMonitoring()
        hotKeyManager.unregisterHotKey()

        print("👋 EchoFlow 已退出")
    }

    // MARK: - Setup

    private func setupMenuBarItem() {
        print("🔧 开始设置状态栏图标...")
        
        // 如果已存在，先移除旧的
        if let oldItem = statusItem {
            NSStatusBar.system.removeStatusItem(oldItem)
            statusItem = nil
            print("  - 已移除旧的状态栏项目")
        }
        
        // 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let statusItem = statusItem else {
            print("❌ 无法创建状态栏项目")
            return
        }
        
        print("  - 状态栏项目已创建")

        // 创建菜单（包含所有选项）
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // 显示/隐藏面板（放在最前面，方便快速访问）
        let toggleItem = NSMenuItem(title: "显示/隐藏面板", action: #selector(togglePanel), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.isEnabled = true
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 打开设置
        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.isEnabled = true
        menu.addItem(settingsItem)
        
        // 检查更新
        let checkUpdatesItem = NSMenuItem(title: "检查更新...", action: #selector(checkForUpdates), keyEquivalent: "")
        checkUpdatesItem.target = self
        checkUpdatesItem.isEnabled = true
        menu.addItem(checkUpdatesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出 EchoFlow", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)
        
        print("  - 菜单已创建，共 \(menu.items.count) 个项目")

        // 配置按钮
        if let button = statusItem.button {
            // 使用 SF Symbol 图标
            if let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "EchoFlow") {
                image.isTemplate = true  // 让图标适应系统主题
                button.image = image
                button.imagePosition = .imageOnly
                print("  - 按钮图标已设置")
            } else {
                // 如果 SF Symbol 不可用，使用文字
                button.title = "📋"
                print("  - 使用备用文字图标")
            }
        } else {
            print("❌ 无法获取状态栏按钮")
        }
        
        // 设置菜单
        statusItem.menu = menu
        
        print("✅ 状态栏设置完成")
    }

    private func setupHotKeys() {
        // 设置快捷键回调
        hotKeyManager.onHotKeyPressed = { [weak self] in
            self?.togglePanel()
        }

        // 从 UserDefaults 加载保存的快捷键设置
        let savedKeyCode = UserDefaults.standard.object(forKey: "hotKeyKeyCode") as? Int
        let savedModifiers = UserDefaults.standard.object(forKey: "hotKeyModifiersRaw") as? Int
        
        if let keyCode = savedKeyCode, let modifiers = savedModifiers {
            // 使用保存的快捷键
            hotKeyManager.registerHotKey(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
            print("⌨️ 已加载保存的快捷键: keyCode=\(keyCode), modifiers=\(modifiers)")
        } else {
            // 使用默认快捷键 (Cmd + B)
            hotKeyManager.registerDefaultHotKey()
            print("⌨️ 使用默认快捷键: ⌘B")
        }
    }

    // MARK: - Actions

    @objc private func togglePanel() {
        windowManager.togglePanel()
    }

    @objc private func openSettings() {
        let container = EchoFlowApp.sharedModelContainer
        let settingsView = SettingsView()
            .modelContainer(container)
        windowManager.createSettingsPanel(with: settingsView)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func checkForUpdates() {
        Task { @MainActor in
            await UpdateManager.shared.checkForUpdates(silent: false)
            if case .available(let release) = UpdateManager.shared.status {
                UpdateWindowController.shared.showUpdateAlert(for: release)
            } else if case .upToDate = UpdateManager.shared.status {
                // 显示已是最新版本的提示
                let alert = NSAlert()
                alert.messageText = "检查更新"
                alert.informativeText = "当前已是最新版本"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "好的")
                alert.runModal()
            } else if case .error(let message) = UpdateManager.shared.status {
                // 显示错误提示
                let alert = NSAlert()
                alert.messageText = "检查更新失败"
                alert.informativeText = message
                alert.alertStyle = .warning
                alert.addButton(withTitle: "好的")
                alert.runModal()
            }
        }
    }
    
    /// 启动时检查更新（如果用户启用了该选项）
    private func checkForUpdatesOnLaunch() {
        // 如果设置不存在，默认为 true
        if UserDefaults.standard.object(forKey: "checkForUpdatesOnLaunch") == nil {
            UserDefaults.standard.set(true, forKey: "checkForUpdatesOnLaunch")
        }
        
        // 检查用户是否启用了启动时检查更新
        guard UserDefaults.standard.bool(forKey: "checkForUpdatesOnLaunch") else {
            print("ℹ️ 用户已禁用启动时检查更新")
            return
        }
        
        // 延迟几秒后检查更新，避免影响启动速度
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.updateCheckDelay) {
            Task { @MainActor in
                print("🔄 正在检查更新...")
                await UpdateManager.shared.checkForUpdates(silent: true)
                
                if case .available(let release) = UpdateManager.shared.status {
                    print("✨ 发现新版本: \(release.version)")
                    UpdateWindowController.shared.showUpdateAlert(for: release)
                } else {
                    print("✅ 当前已是最新版本")
                }
            }
        }
    }
}
