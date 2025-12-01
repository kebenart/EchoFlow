//
//  AppSelector.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import AppKit
import Foundation

/// 应用信息
struct AppInfo: Identifiable, Hashable {
    let id: String  // Bundle ID
    let name: String
    let icon: NSImage?
    
    init(bundleID: String, name: String, icon: NSImage? = nil) {
        self.id = bundleID
        self.name = name
        self.icon = icon
    }
}

/// 应用选择器 - 获取已安装的应用列表
final class AppSelector {
    // MARK: - Singleton
    
    static let shared = AppSelector()
    
    // MARK: - Properties
    
    /// 已安装的应用列表
    private var cachedApps: [AppInfo]?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 获取所有已安装的应用列表
    func getAllApps() -> [AppInfo] {
        if let cached = cachedApps {
            return cached
        }
        
        var apps: [AppInfo] = []
        let fileManager = FileManager.default
        
        // 搜索常见的应用目录
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Library/CoreServices",
            NSHomeDirectory() + "/Applications"
        ]
        
        for searchPath in searchPaths {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: searchPath) else {
                continue
            }
            
            for item in contents {
                let appPath = (searchPath as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                guard fileManager.fileExists(atPath: appPath, isDirectory: &isDirectory),
                      isDirectory.boolValue,
                      item.hasSuffix(".app") else {
                    continue
                }
                
                // 获取应用信息
                if let appInfo = getAppInfo(from: appPath) {
                    apps.append(appInfo)
                }
            }
        }
        
        // 按名称排序
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        cachedApps = apps
        return apps
    }
    
    /// 显示应用选择对话框
    func showAppPicker(completion: @escaping (AppInfo?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.application]
        openPanel.message = "选择要过滤的应用"
        openPanel.prompt = "选择"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                if let appInfo = self.getAppInfo(from: url.path) {
                    completion(appInfo)
                } else {
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 从应用路径获取应用信息
    private func getAppInfo(from appPath: String) -> AppInfo? {
        guard let bundle = Bundle(path: appPath),
              let bundleID = bundle.bundleIdentifier else {
            return nil
        }
        
        // 获取应用名称
        let name = bundle.localizedInfoDictionary?["CFBundleName"] as? String ??
                   bundle.infoDictionary?["CFBundleName"] as? String ??
                   (appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        
        // 获取应用图标
        let icon = NSWorkspace.shared.icon(forFile: appPath)
        
        return AppInfo(bundleID: bundleID, name: name, icon: icon)
    }
}




