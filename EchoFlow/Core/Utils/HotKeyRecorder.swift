//
//  HotKeyRecorder.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import AppKit
import Carbon

/// 快捷键录制器
final class HotKeyRecorder {
    // MARK: - Singleton
    
    static let shared = HotKeyRecorder()
    
    // MARK: - Properties
    
    private var eventMonitor: Any?
    private var onKeyCaptured: ((Int, UInt32) -> Void)?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 开始录制快捷键
    func startRecording(onKeyCaptured: @escaping (Int, UInt32) -> Void) {
        self.onKeyCaptured = onKeyCaptured
        
        // 创建本地事件监控
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else { return event }
            
            // 只处理键盘按下事件
            if event.type == .keyDown {
                let keyCode = Int(event.keyCode)
                let modifiers = self.getModifiers(from: event.modifierFlags)
                
                // 确保至少有一个修饰键
                if modifiers != 0 {
                    self.onKeyCaptured?(keyCode, modifiers)
                    self.stopRecording()
                    return nil  // 消费事件，不传递给其他处理程序
                }
            }
            
            return event
        }
        
        print("⌨️ 开始录制快捷键...")
    }
    
    /// 停止录制快捷键
    func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        onKeyCaptured = nil
        print("⌨️ 停止录制快捷键")
    }
    
    // MARK: - Private Methods
    
    /// 从 NSEvent.ModifierFlags 转换为 Carbon 修饰键
    private func getModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        
        return modifiers
    }
}

