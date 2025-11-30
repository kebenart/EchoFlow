//
//  SnapshotHelper.swift
//  EchoFlow
//
//  Created by keben on 2025/11/30.
//

import SwiftUI
import AppKit

/// 视图快照工具类
/// 用于将剪贴板内容预渲染为图片，以提升列表滚动性能
@MainActor
final class SnapshotHelper {
    static let shared = SnapshotHelper()
    
    // 内存缓存 (Memory Cache)
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 100 // 限制缓存数量
    }
    
    /// 获取内容的预览图（有内存缓存则取缓存，有磁盘缓存则取磁盘，无则生成）
    /// - Parameters:
    ///   - item: 剪贴板数据模型
    ///   - size: 卡片尺寸
    ///   - completion: 回调生成的图片
    func getPreviewImage(for item: ClipboardItem, size: CGSize, completion: @escaping (NSImage?) -> Void) {
        let key = item.id.uuidString as NSString
        
        // 1. 检查内存缓存 (L1 Cache)
        if let cachedImage = cache.object(forKey: key) {
            completion(cachedImage)
            return
        }
        
        // 2. 异步处理：检查磁盘缓存 (L2 Cache) 或生成新快照
        Task {
            // 尝试从磁盘加载
            if let diskImage = loadFromDisk(filename: item.id.uuidString) {
                // 加载成功，写入内存缓存并返回
                self.cache.setObject(diskImage, forKey: key)
                completion(diskImage)
                return
            }
            
            // 3. 生成新快照 (Cache Miss)
            let image = await generateSnapshot(for: item, size: size)
            if let image = image {
                // 写入内存缓存
                self.cache.setObject(image, forKey: key)
                // 写入磁盘缓存
                saveToDisk(image: image, filename: item.id.uuidString)
            }
            completion(image)
        }
    }
    
    // MARK: - Snapshot Generation
    
    /// 核心逻辑：将内容转换为图片
    private func generateSnapshot(for item: ClipboardItem, size: CGSize) async -> NSImage? {
        // 创建一个专门用于渲染的视图（简化版 CardView）
        // 注意：这里需要根据 item 类型进行不同的渲染，类似于 ClipboardCard 中的逻辑
        let renderView = VStack(alignment: .leading, spacing: 8) {
            Text(item.content)
                .font(.system(size: 13))
                .foregroundColor(.black) // 强制使用固定颜色，避免深色模式问题
                .lineLimit(8)
                .padding(12)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(Color.white) // 强制白色背景
        
        // 使用 ImageRenderer (macOS 13+)
        if #available(macOS 13.0, *) {
            let renderer = ImageRenderer(content: renderView)
            renderer.scale = 2.0 // 设置缩放比例，保证清晰度
            return renderer.nsImage
        } else {
            // Fallback for older macOS versions (optional)
            return nil
        }
    }
    
    /// 通用方法：将任意 SwiftUI View 转换为 NSImage
    static func render<V: View>(view: V, size: CGSize? = nil) -> NSImage? {
        if #available(macOS 13.0, *) {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2.0
            return renderer.nsImage
        }
        return nil
    }
    
    // MARK: - Disk Cache Helpers
    
    private func getCacheDirectory() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Snapshots")
    }
    
    private func saveToDisk(image: NSImage, filename: String) {
        guard let data = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }
        
        guard let directory = getCacheDirectory() else { return }
        
        do {
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let fileURL = directory.appendingPathComponent("\(filename).png")
            try pngData.write(to: fileURL)
        } catch {
            print("Failed to save snapshot to disk: \(error)")
        }
    }
    
    private func loadFromDisk(filename: String) -> NSImage? {
        guard let directory = getCacheDirectory() else { return nil }
        let fileURL = directory.appendingPathComponent("\(filename).png")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return NSImage(contentsOf: fileURL)
        }
        return nil
    }
}
