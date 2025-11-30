//
//  UpdateAlertView.swift
//  EchoFlow
//
//  更新提示弹框视图
//

import SwiftUI

/// 更新提示弹框
struct UpdateAlertView: View {
    @ObservedObject var updateManager = UpdateManager.shared
    @Environment(\.dismiss) private var dismiss
    
    let release: GitHubRelease
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            headerView
            
            Divider()
            
            // 内容区
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    releaseInfoView
                    
                    if let body = release.body, !body.isEmpty {
                        changelogView(body)
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: 300)
            
            Divider()
            
            // 底部按钮
            footerView
        }
        .frame(width: 480)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 20)
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack(spacing: 16) {
            // App 图标
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("发现新版本")
                    .font(.headline)
                
                Text("EchoFlow \(release.version) 现已可用")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("当前版本: \(currentVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(20)
    }
    
    private var releaseInfoView: some View {
        HStack {
            Label(release.name, systemImage: "tag.fill")
                .font(.subheadline)
                .foregroundColor(.blue)
            
            Spacer()
            
            if let publishedAt = release.publishedAt {
                Text(formatDate(publishedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func changelogView(_ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("更新内容")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(body)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
    
    private var footerView: some View {
        HStack(spacing: 12) {
            // 跳过此版本
            Button("跳过此版本") {
                updateManager.skipVersion(release.version)
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            
            Spacer()
            
            // 稍后提醒
            Button("稍后提醒") {
                updateManager.resetStatus()
                dismiss()
            }
            .buttonStyle(.bordered)
            
            // 下载更新
            Button(action: {
                Task {
                    await updateManager.downloadUpdate()
                }
            }) {
                HStack(spacing: 6) {
                    if case .downloading(let progress) = updateManager.status {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                        Text("\(Int(progress * 100))%")
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("下载更新")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(updateManager.status == .checking || 
                     (updateManager.status != .available(release) && !isDownloading))
        }
        .padding(20)
        .onChange(of: updateManager.status) { _, newStatus in
            if case .readyToInstall = newStatus {
                updateManager.installUpdate()
                dismiss()
            }
        }
    }
    
    // MARK: - Helpers
    
    private var currentVersion: String {
        AppConfig.currentVersion
    }
    
    private var isDownloading: Bool {
        if case .downloading = updateManager.status {
            return true
        }
        return false
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            displayFormatter.locale = Locale(identifier: "zh_CN")
            return displayFormatter.string(from: date)
        }
        
        // 尝试不带毫秒的格式
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            displayFormatter.locale = Locale(identifier: "zh_CN")
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - Update Window Controller

/// 更新窗口控制器 - 用于显示更新弹框
final class UpdateWindowController {
    private var window: NSWindow?
    private var hostingController: NSHostingController<UpdateAlertView>?
    
    static let shared = UpdateWindowController()
    
    private init() {}
    
    /// 显示更新弹框
    func showUpdateAlert(for release: GitHubRelease) {
        // 如果窗口已存在，只需激活
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let alertView = UpdateAlertView(release: release)
        let hostingController = NSHostingController(rootView: alertView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable]
        window.title = "软件更新"
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating
        
        self.window = window
        self.hostingController = hostingController
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// 关闭更新弹框
    func closeUpdateAlert() {
        window?.close()
        window = nil
        hostingController = nil
    }
}

// MARK: - Preview

#Preview {
    UpdateAlertView(release: GitHubRelease(
        tagName: "v1.2.0",
        name: "EchoFlow v1.2.0",
        body: """
        ## 新功能
        - 添加炫酷模式支持
        - 优化滚动性能
        
        ## 修复
        - 修复卡片选择问题
        - 修复内存泄漏
        """,
        htmlUrl: "https://github.com/example/EchoFlow/releases/tag/v1.2.0",
        publishedAt: "2025-11-30T10:00:00Z",
        assets: [
            GitHubAsset(
                name: "EchoFlow-1.2.0.dmg",
                size: 15_000_000,
                downloadCount: 100,
                browserDownloadUrl: "https://github.com/example/EchoFlow/releases/download/v1.2.0/EchoFlow-1.2.0.dmg"
            )
        ]
    ))
    .frame(width: 500, height: 500)
}

