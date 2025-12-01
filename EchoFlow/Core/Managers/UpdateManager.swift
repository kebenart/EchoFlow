//
//  UpdateManager.swift
//  EchoFlow
//
//  自动更新管理器 - 从 GitHub Releases 检测和下载更新
//

import Foundation
import AppKit

// MARK: - Models

/// GitHub Release 信息
struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String?
    let htmlUrl: String
    let publishedAt: String?
    let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }
    
    /// 从 tag 中提取版本号 (v1.0.0 -> 1.0.0)
    var version: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
}

/// GitHub Release 资源文件
struct GitHubAsset: Codable {
    let name: String
    let size: Int
    let downloadCount: Int
    let browserDownloadUrl: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case size
        case downloadCount = "download_count"
        case browserDownloadUrl = "browser_download_url"
    }
}

/// 更新状态
enum UpdateStatus: Equatable {
    case idle
    case checking
    case available(GitHubRelease)
    case downloading(progress: Double)
    case readyToInstall(URL)
    case upToDate
    case error(String)
    
    static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking), (.upToDate, .upToDate):
            return true
        case (.available(let l), .available(let r)):
            return l.tagName == r.tagName
        case (.downloading(let l), .downloading(let r)):
            return l == r
        case (.readyToInstall(let l), .readyToInstall(let r)):
            return l == r
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - UpdateManager

@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var status: UpdateStatus = .idle
    @Published private(set) var latestRelease: GitHubRelease?
    
    // MARK: - Private Properties
    
    private var downloadTask: URLSessionDownloadTask?
    private var downloadObservation: NSKeyValueObservation?
    
    // MARK: - Public Methods
    
    /// 检查更新
    /// - Parameter silent: 如果为 true，在没有更新时不会改变状态
    func checkForUpdates(silent: Bool = false) async {
        guard status != .checking else { return }
        
        status = .checking
        
        do {
            let release = try await fetchLatestRelease()
            latestRelease = release
            
            if isNewerVersion(release.version) {
                status = .available(release)
            } else {
                status = silent ? .idle : .upToDate
            }
        } catch {
            if !silent {
                status = .error("检查更新失败: \(error.localizedDescription)")
            } else {
                status = .idle
            }
        }
    }
    
    /// 下载更新
    func downloadUpdate() async {
        guard case .available(let release) = status else { return }
        
        // 优先查找 DMG，其次 ZIP
        guard let asset = release.assets.first(where: { $0.name.hasSuffix(".dmg") })
                ?? release.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
            status = .error("未找到可用的安装包")
            return
        }
        
        guard let downloadURL = URL(string: asset.browserDownloadUrl) else {
            status = .error("下载链接无效")
            return
        }
        
        status = .downloading(progress: 0)
        
        do {
            let localURL = try await downloadFile(from: downloadURL, fileName: asset.name)
            status = .readyToInstall(localURL)
        } catch {
            status = .error("下载失败: \(error.localizedDescription)")
        }
    }
    
    /// 安装更新 (打开下载的 DMG/ZIP)
    func installUpdate() {
        guard case .readyToInstall(let url) = status else { return }
        
        NSWorkspace.shared.open(url)
        
        // 提示用户手动完成安装
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.showInstallationInstructions()
        }
    }
    
    /// 取消下载
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadObservation = nil
        status = .idle
    }
    
    /// 跳过此版本
    func skipVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: "skippedVersion")
        status = .idle
    }
    
    /// 重置状态
    func resetStatus() {
        status = .idle
    }
    
    // MARK: - Private Methods
    
    /// 获取最新发布版本
    private func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: AppConfig.latestReleaseURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.updateCheckerUserAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw UpdateError.noReleases
            }
            throw UpdateError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(GitHubRelease.self, from: data)
    }
    
    /// 下载文件
    private func downloadFile(from url: URL, fileName: String) async throws -> URL {
        let session = URLSession.shared
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url) { [weak self] localURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let localURL = localURL else {
                    continuation.resume(throwing: UpdateError.downloadFailed)
                    return
                }
                
                // 移动到 Downloads 目录
                let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                let destinationURL = downloadsURL.appendingPathComponent(fileName)
                
                do {
                    // 如果文件已存在，先删除
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: localURL, to: destinationURL)
                    continuation.resume(returning: destinationURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            // 监听下载进度
            downloadObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                Task { @MainActor in
                    self?.status = .downloading(progress: progress.fractionCompleted)
                }
            }
            
            downloadTask = task
            task.resume()
        }
    }
    
    /// 比较版本号，判断是否有新版本
    private func isNewerVersion(_ remoteVersion: String) -> Bool {
        // 检查是否跳过此版本
        let skippedVersion = UserDefaults.standard.string(forKey: "skippedVersion")
        if skippedVersion == remoteVersion {
            return false
        }
        
        return compareVersions(remoteVersion, AppConfig.currentVersion) == .orderedDescending
    }
    
    /// 比较两个版本号
    private func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let components1 = v1.split(separator: ".").compactMap { Int($0) }
        let components2 = v2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(components1.count, components2.count)
        
        for i in 0..<maxLength {
            let c1 = i < components1.count ? components1[i] : 0
            let c2 = i < components2.count ? components2[i] : 0
            
            if c1 > c2 { return .orderedDescending }
            if c1 < c2 { return .orderedAscending }
        }
        
        return .orderedSame
    }
    
    /// 显示安装说明
    private func showInstallationInstructions() {
        let alert = NSAlert()
        alert.messageText = "安装说明"
        alert.informativeText = """
        1. 打开下载的 DMG 文件
        2. 将 EchoFlow 拖入 Applications 文件夹
        3. 如果提示替换，选择"替换"
        4. 重新启动 EchoFlow
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }
}

// MARK: - Errors

enum UpdateError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case noReleases
    case downloadFailed
    case installationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应无效"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .noReleases:
            return "暂无发布版本"
        case .downloadFailed:
            return "下载失败"
        case .installationFailed:
            return "安装失败"
        }
    }
}




