//
//  PasteSimulator.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import AppKit
import ApplicationServices

/// 粘贴模拟器 - 使用 Accessibility API 模拟键盘粘贴
final class PasteSimulator {
    // MARK: - Singleton

    static let shared = PasteSimulator()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 检查辅助功能权限
    func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            print("⚠️ 需要辅助功能权限才能模拟粘贴")
        }

        return accessEnabled
    }

    /// 模拟粘贴操作 (Cmd + V)
    func simulatePaste(delay: TimeInterval = 0.05) {
        // 检查权限
        guard checkAccessibilityPermission() else {
            showPermissionAlert()
            return
        }

        // 延迟执行，确保窗口已隐藏且目标应用已激活
        // 优化：使用最小必要延迟，提高响应速度
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.performPaste()
            }
        } else {
            // 如果延迟为0，立即执行
            self.performPaste()
        }
    }

    // MARK: - Private Methods

    /// 执行粘贴操作
    private func performPaste() {
        // 创建事件源
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            print("❌ 无法创建事件源")
            return
        }

        // V 键的虚拟键码是 0x09
        let vKeyCode: CGKeyCode = 0x09

        // 创建按键按下事件
        guard let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: vKeyCode, keyDown: true) else {
            print("❌ 无法创建按键按下事件")
            return
        }

        // 创建按键释放事件
        guard let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: vKeyCode, keyDown: false) else {
            print("❌ 无法创建按键释放事件")
            return
        }

        // 设置 Cmd 修饰键
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // 发送事件（优化：减少按键间隔延迟）
        keyDown.post(tap: .cghidEventTap)
        // 优化：减少延迟时间（从 10ms 减少到 5ms）
        usleep(5000) // 5ms
        keyUp.post(tap: .cghidEventTap)
    }

    /// 显示权限请求对话框
    private func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "EchoFlow 需要辅助功能权限来实现自动粘贴功能。\n\n请在\"系统设置 > 隐私与安全性 > 辅助功能\"中授予权限。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "取消")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                // 打开系统设置
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
