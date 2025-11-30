//
//  HotKeyManager.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import AppKit
import Carbon

/// 全局快捷键管理器
final class HotKeyManager {
    // MARK: - Singleton

    static let shared = HotKeyManager()

    // MARK: - Properties

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    /// 快捷键回调
    var onHotKeyPressed: (() -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 注册全局快捷键
    /// - Parameters:
    ///   - keyCode: 虚拟键码 (例如: 0x08 代表 'C')
    ///   - modifiers: 修饰键 (例如: cmdKey + shiftKey)
    func registerHotKey(keyCode: UInt32, modifiers: UInt32) {
        // 如果已经注册，先取消
        unregisterHotKey()

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(("ECFL" as NSString).fourCharCode)
        hotKeyID.id = 1

        // 注册热键
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onHotKeyPressed?()

                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        print("⌨️ 全局快捷键已注册")
    }

    /// 注册默认快捷键 (Cmd + B)
    func registerDefaultHotKey() {
        // Cmd + B
        // B 的虚拟键码是 0x0B
        let keyCode: UInt32 = 0x0B // 'B'
        let modifiers: UInt32 = UInt32(cmdKey)

        registerHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    /// 取消注册快捷键
    func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        print("⌨️ 全局快捷键已取消注册")
    }

    deinit {
        unregisterHotKey()
    }
}

// MARK: - Extensions

extension NSString {
    var fourCharCode: FourCharCode {
        var result: FourCharCode = 0
        let length = min(self.length, 4)

        for i in 0..<length {
            let char = self.character(at: i)
            result = (result << 8) + FourCharCode(char)
        }

        return result
    }
}
