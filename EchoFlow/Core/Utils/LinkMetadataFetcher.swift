//
//  LinkMetadataFetcher.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import Foundation
import LinkPresentation
import AppKit

/// 网站元数据获取器 - 获取网站标题、favicon等信息
final class LinkMetadataFetcher {
    // MARK: - Singleton

    static let shared = LinkMetadataFetcher()

    // MARK: - Properties

    /// 超时时间（秒）
    private let timeout: TimeInterval = 5.0
    
    /// 正在进行的请求（用于防止重复请求）
    private var activeRequests: [URL: LPMetadataProvider] = [:]

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 异步获取链接元数据
    /// - Parameters:
    ///   - url: 要获取元数据的URL
    ///   - completion: 完成回调，返回标题和favicon数据
    func fetchMetadata(for url: URL, completion: @escaping (String?, Data?) -> Void) {
        // 检查是否已有相同 URL 的请求正在进行
        if activeRequests[url] != nil {
            // 使用 URL 的域名作为临时标题
            let fallbackTitle = url.host ?? url.absoluteString
            completion(fallbackTitle, nil)
            return
        }

        // 创建新的元数据提供者（LPMetadataProvider 是一次性对象）
        let metadataProvider = LPMetadataProvider()
        metadataProvider.timeout = timeout
        
        // 记录正在进行的请求
        activeRequests[url] = metadataProvider

        // 开始获取元数据
        metadataProvider.startFetchingMetadata(for: url) { [weak self] metadata, error in
            guard let self = self else { return }
            
            // 移除已完成的请求
            self.activeRequests.removeValue(forKey: url)

            if let error = error {
                // 失败时使用URL的域名作为标题
                let fallbackTitle = url.host ?? url.absoluteString
                completion(fallbackTitle, nil)
                return
            }

            guard let metadata = metadata else {
                completion(url.host, nil)
                return
            }

            // 提取标题
            let title = metadata.title ?? url.host ?? "未知网站"

            // 提取favicon
            self.extractFavicon(from: metadata) { faviconData in
                completion(title, faviconData)
            }
        }
    }

    // MARK: - Private Methods

    /// 从元数据中提取favicon
    private func extractFavicon(from metadata: LPLinkMetadata, completion: @escaping (Data?) -> Void) {
        // 尝试从图标提供者中获取图标
        guard let iconProvider = metadata.iconProvider else {
            completion(nil)
            return
        }

        // 加载图标
        iconProvider.loadObject(ofClass: NSImage.self) { image, error in
            if error != nil {
                completion(nil)
                return
            }

            guard let nsImage = image as? NSImage else {
                completion(nil)
                return
            }

            // 将NSImage转换为PNG数据
            if let tiffData = nsImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                completion(pngData)
            } else {
                completion(nil)
            }
        }
    }
}
