//
//  WindowManager.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import AppKit
import SwiftUI

/// 窗口停靠位置
enum DockPosition: String, CaseIterable {
    case bottom = "bottom"
    case top = "top"
    case left = "left"
    case right = "right"

    var isHorizontal: Bool {
        self == .bottom || self == .top
    }

    var isVertical: Bool {
        self == .left || self == .right
    }
}

/// 窗口管理器 - 管理 NSPanel 悬浮窗和停靠逻辑
@Observable
final class WindowManager {
    // MARK: - Singleton

    static let shared = WindowManager()

    // MARK: - Properties

    /// 主面板窗口
    var panel: NSPanel?
    
    /// 设置窗口
    var settingsWindow: NSWindow?

    /// 当前停靠位置
    var dockPosition: DockPosition = .bottom {
        didSet {
            if dockPosition != oldValue {
                updatePanelPosition()
            }
        }
    }

    /// 面板是否可见
    var isVisible: Bool = false

    /// 动画是否正在进行中
    var isAnimating: Bool = false

    // MARK: - Constants

    /// 水平模式下的面板尺寸（将根据屏幕宽度动态计算）
    private func getHorizontalSize() -> NSSize {
        guard let screen = NSScreen.main else {
            return NSSize(width: 800, height: 340)
        }
        let screenWidth = screen.visibleFrame.width
        // 铺满屏幕宽度，留 20pt 边距
        // 高度增加到 340 以适应更大的卡片 (256 + 工具栏 44 + 上下边距 28 + 余量)
        return NSSize(width: screenWidth - 40, height: 340)
    }

    /// 垂直模式下的面板尺寸（宽度增加到 300 以确保卡片有足够空间，高度 900）
    private let verticalSize = NSSize(width: 300, height: 900)

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 创建设置面板（居中显示）
    func createSettingsPanel<Content: View>(with contentView: Content) {
        // 如果设置窗口已存在，先关闭它
        if let existingWindow = settingsWindow {
            existingWindow.close()
        }

        // 创建 NSWindow（不是 NSPanel）
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 700, height: 500)),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        // 配置窗口属性
        configureSettingsWindow(window)

        // 设置 SwiftUI 内容视图
        window.contentView = NSHostingView(rootView: contentView)

        // 设置窗口居中位置
        centerWindow(window)

        // 保存窗口引用
        settingsWindow = window

        // 激活应用并显示窗口
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()  // 确保在所有窗口前面
        
        // 延迟一点时间确保窗口完全显示后再聚焦（提高聚焦成功率）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeKey()
            window.makeFirstResponder(window.contentView)
            NSApp.activate(ignoringOtherApps: true)
        }

        print("🪟 设置面板已显示（居中，置于最前面，已聚焦）")
    }
    
    /// 关闭设置面板
    func closeSettingsPanel() {
        if let window = settingsWindow {
            window.close()
            settingsWindow = nil
            print("🪟 设置面板已关闭")
        }
    }

    /// 创建并配置主面板
    func createPanel<Content: View>(with contentView: Content) {
        // 如果已有面板，先清理旧的
        if let oldPanel = panel {
            // 移除通知观察者
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: oldPanel)
            // 如果面板可见，先隐藏
            if oldPanel.isVisible {
                oldPanel.orderOut(nil)
            }
        }
        
        // 创建 NSPanel
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: getHorizontalSize()),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // 配置面板属性
        configurePanelProperties(panel)

        // 设置 SwiftUI 内容视图
        panel.contentView = NSHostingView(rootView: contentView)

        // 设置面板位置
        updatePanelPosition(for: panel)

        self.panel = panel

        // 监听面板失去焦点事件
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] notification in
            // 确保是当前面板的通知
            guard let self = self,
                  let notifiedPanel = notification.object as? NSPanel,
                  notifiedPanel === self.panel else {
                return
            }
            self.hidePanel()
        }
    }

    /// 显示面板（带动画）
    func showPanel() {
        guard let panel = panel, let screen = NSScreen.main else { return }

        // 如果正在显示中，忽略
        if isAnimating && isVisible {
            return
        }

        // 如果已经显示，忽略
        if isVisible && !isAnimating {
            return
        }

        let visibleFrame = screen.visibleFrame
        let panelSize = dockPosition.isHorizontal ? getHorizontalSize() : verticalSize
        let finalOrigin = calculatePanelOrigin(visibleFrame: visibleFrame, panelSize: panelSize)
        let initialOrigin = calculateOffScreenOrigin(visibleFrame: visibleFrame, panelSize: panelSize, finalOrigin: finalOrigin)

        // 设置初始状态
        panel.setFrame(NSRect(origin: initialOrigin, size: panelSize), display: false)
        panel.alphaValue = 0.0
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        
        // 更新状态
        isVisible = true
        isAnimating = true

        // 执行动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(NSRect(origin: finalOrigin, size: panelSize), display: true)
            panel.animator().alphaValue = 1.0
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            self.isAnimating = false
            NotificationCenter.default.post(name: NSNotification.Name("RefreshClipboardData"), object: nil)
        })
    }

    /// 隐藏面板（带动画）
    func hidePanel(completion: (() -> Void)? = nil) {
        guard let panel = panel, let screen = NSScreen.main else {
            isVisible = false
            isAnimating = false
            completion?()
            return
        }

        // 如果已经隐藏，直接执行 completion
        if !isVisible && !isAnimating {
            completion?()
            return
        }

        // 如果正在隐藏中，直接执行 completion（不重复隐藏）
        if isAnimating && !isVisible {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion?()
            }
            return
        }

        // 计算隐藏位置
        let visibleFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let currentOrigin = panel.frame.origin
        let hideOrigin = calculateOffScreenOrigin(visibleFrame: visibleFrame, panelSize: panelSize, finalOrigin: currentOrigin)

        // 更新状态
        isVisible = false
        isAnimating = true

        // 执行动画（优化：减少动画时间以提高响应速度）
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2  // 从 0.25 秒减少到 0.15 秒
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(NSRect(origin: hideOrigin, size: panelSize), display: true)
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            
            // 重置状态
            self.isAnimating = false
            
            // 隐藏窗口
            panel.orderOut(nil)
            
            // 执行回调
            completion?()
        })
    }


    /// 切换面板显示/隐藏
    func togglePanel() {
        // 如果动画正在进行，忽略切换请求
        if isAnimating {
            print("⚠️ 动画进行中，忽略切换请求")
            return
        }

        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    /// 更新面板位置
    func updatePanelPosition() {
        guard let panel = panel else { return }
        updatePanelPosition(for: panel)
    }

    // MARK: - Private Methods

    /// 配置设置窗口属性
    private func configureSettingsWindow(_ window: NSWindow) {
        // 窗口样式
        window.isReleasedWhenClosed = false
        
        // 标题栏
        window.title = "设置"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        
        // 标准窗口按钮显示
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        
        // 窗口行为 - 置于所有窗口最前面
        window.level = .floating
        window.isMovable = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    /// 将窗口居中显示
    private func centerWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        
        // 计算居中位置
        let x = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
        let y = screenFrame.origin.y + (screenFrame.height - windowFrame.height) / 2
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// 配置面板属性
    private func configurePanelProperties(_ panel: NSPanel) {
        // 窗口样式
        panel.level = .floating // 浮动层级
        panel.isOpaque = false // 透明
        panel.backgroundColor = .clear // 清除背景色
        panel.hasShadow = true

        // 窗口行为
        panel.collectionBehavior = [
            .canJoinAllSpaces, // 出现在所有空间
            .fullScreenAuxiliary // 全屏应用之上显示
        ]

        // 标题栏
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        // 不抢占焦点
        panel.hidesOnDeactivate = false

        // 设置为不可移动
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
    }

    /// 计算并设置面板位置
    private func updatePanelPosition(for panel: NSPanel) {
        guard let screen = NSScreen.main else { return }

        let visibleFrame = screen.visibleFrame
        let panelSize = dockPosition.isHorizontal ? getHorizontalSize() : verticalSize

        let origin = calculatePanelOrigin(visibleFrame: visibleFrame, panelSize: panelSize)

        panel.setFrame(
            NSRect(origin: origin, size: panelSize),
            display: true,
            animate: true
        )

        print("🪟 面板位置已更新: \(dockPosition.rawValue), 尺寸: \(panelSize)")
    }

    /// 计算面板的最终显示位置
    private func calculatePanelOrigin(visibleFrame: NSRect, panelSize: NSSize) -> NSPoint {
        var origin = NSPoint.zero

        switch dockPosition {
        case .bottom:
            origin = NSPoint(
                x: visibleFrame.minX + 20, // 左对齐，留 20pt 边距
                y: visibleFrame.minY + 10 // 距离底部 10pt
            )

        case .top:
            origin = NSPoint(
                x: visibleFrame.minX + 20, // 左对齐，留 20pt 边距
                y: visibleFrame.maxY - panelSize.height - 10 // 距离顶部 10pt
            )

        case .left:
            origin = NSPoint(
                x: visibleFrame.minX + 20, // 距离左侧 20pt
                y: visibleFrame.midY - panelSize.height / 2
            )

        case .right:
            origin = NSPoint(
                x: visibleFrame.maxX - panelSize.width - 20, // 距离右侧 20pt
                y: visibleFrame.midY - panelSize.height / 2
            )
        }

        return origin
    }

    /// 计算屏幕外的位置（用于动画起始/结束点）
    private func calculateOffScreenOrigin(visibleFrame: NSRect, panelSize: NSSize, finalOrigin: NSPoint) -> NSPoint {
        var origin = finalOrigin

        switch dockPosition {
        case .bottom:
            // 从底部屏幕外滑入
            origin.y = visibleFrame.minY - panelSize.height - 20

        case .top:
            // 从顶部屏幕外滑入
            origin.y = visibleFrame.maxY + 20

        case .left:
            // 从左侧屏幕外滑入
            origin.x = visibleFrame.minX - panelSize.width - 20

        case .right:
            // 从右侧屏幕外滑入
            origin.x = visibleFrame.maxX + 20
        }

        return origin
    }
}
