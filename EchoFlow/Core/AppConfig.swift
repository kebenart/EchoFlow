//
//  AppConfig.swift
//  EchoFlow
//
//  应用配置文件 - 集中管理可配置参数
//

import Foundation

/// 应用配置
enum AppConfig {
    
    // MARK: - GitHub 配置
    
    /// GitHub 仓库 (格式: owner/repo)
    /// 用于自动更新检测
    static let githubRepo = "kebenart/EchoFlow"
    
    /// GitHub API 基础地址
    static let githubAPIBaseURL = "https://api.github.com"
    
    /// 获取最新发布版本的 API 地址
    static var latestReleaseURL: URL {
        URL(string: "\(githubAPIBaseURL)/repos/\(githubRepo)/releases/latest")!
    }
    
    /// GitHub Releases 页面地址
    static var releasesPageURL: URL {
        URL(string: "https://github.com/\(githubRepo)/releases")!
    }
    
    /// GitHub 仓库主页地址
    static var githubRepoURL: URL {
        URL(string: "https://github.com/\(githubRepo)")!
    }
    
    // MARK: - 应用信息
    
    /// 应用名称
    static let appName = "EchoFlow"
    
    /// 当前版本号
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// 当前构建号
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - 更新检测配置
    
    /// 启动后延迟检查更新的时间（秒）
    static let updateCheckDelay: TimeInterval = 3.0
    
    /// 更新检测 User-Agent
    static let updateCheckerUserAgent = "EchoFlow-UpdateChecker"
}

