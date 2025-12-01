//
//  LaunchAtLoginManager.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import Foundation
import ServiceManagement

/// 登录时自动启动管理器
@Observable
final class LaunchAtLoginManager {
    // MARK: - Singleton
    
    static let shared = LaunchAtLoginManager()
    
    // MARK: - Properties
    
    /// 是否启用登录时自动启动
    var isEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
            updateLaunchAtLogin(enabled: newValue)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // 初始化时同步状态
        let savedValue = UserDefaults.standard.bool(forKey: "launchAtLogin")
        if savedValue {
            updateLaunchAtLogin(enabled: true)
        }
    }
    
    // MARK: - Public Methods
    
    /// 更新登录时自动启动设置
    func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                // 启用登录时自动启动
                try SMAppService.mainApp.register()
                print("✅ 已启用登录时自动启动")
            } else {
                // 禁用登录时自动启动
                try SMAppService.mainApp.unregister()
                print("✅ 已禁用登录时自动启动")
            }
        } catch {
            print("❌ 更新登录时自动启动失败: \(error.localizedDescription)")
            // 如果使用新 API 失败，尝试使用旧方法（兼容性，仅 macOS 12 及以下）
            if #available(macOS 13.0, *) {
                // macOS 13+ 应该使用 SMAppService，如果失败则提示用户
                print("⚠️ 请检查系统权限设置")
            } else {
                updateLaunchAtLoginLegacy(enabled: enabled)
            }
        }
    }
    
    // MARK: - Private Methods (Legacy Support)
    
    /// 使用旧方法更新登录时自动启动（兼容 macOS 12 及以下）
    private func updateLaunchAtLoginLegacy(enabled: Bool) {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.echoflow.app"
        let helperBundleID = "\(bundleID).LaunchHelper"
        
        // 使用 SMLoginItemSetEnabled (macOS 12 及以下)
        let success = SMLoginItemSetEnabled(helperBundleID as CFString, enabled)
        if success {
            print("✅ 已\(enabled ? "启用" : "禁用")登录时自动启动（旧方法）")
        } else {
            print("❌ 更新登录时自动启动失败（旧方法）")
        }
    }
}




