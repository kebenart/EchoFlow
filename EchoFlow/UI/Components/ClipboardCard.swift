//
//  ClipboardCard.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import SwiftUI
import AppKit
import CryptoKit

/// 剪贴板卡片视图 - 极致性能优化版
struct ClipboardCard: View, Equatable {
    let item: ClipboardItem
    let index: Int
    let isFocused: Bool
    let timeRefreshTrigger: Int
    let onTap: () -> Void
    let onDelete: () -> Void

    static func == (lhs: ClipboardCard, rhs: ClipboardCard) -> Bool {
        return lhs.item.id == rhs.item.id &&
               lhs.index == rhs.index &&
               lhs.isFocused == rhs.isFocused &&
               lhs.timeRefreshTrigger == rhs.timeRefreshTrigger
    }

    @State private var isDragging: Bool = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // 1. 头部视图
                CardHeaderView(
                    item: item,
                    timeRefreshTrigger: timeRefreshTrigger
                )
                // 确保头部背景色区域不进行不必要的透明度混合
                .background(Color(hex: item.themeColorHex) ?? Color.blue)

                // 2. 内容视图
                CardBodyView(item: item)
                    .background(Color.white) // 明确背景色，提升渲染效率
            }
            .frame(width: 240, height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // 优化：移除内部的 drawingGroup，由父视图统一管理以提升滚动性能
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFocused ? Color.blue.opacity(0.08) : Color.white.opacity(0.96))
                    .shadow(color: isFocused ? Color.blue.opacity(0.2) : Color.black.opacity(0.08), radius: isFocused ? 12 : 8, x: 0, y: 4)
            )
            .overlay(selectionBorder)
            .opacity(isDragging ? 0.5 : 1.0)
            .scaleEffect(isDragging ? 0.95 : 1.0)
            .contextMenu {
                CardContextMenu(item: item, onDelete: onDelete, onToggleLock: {
                    toggleLock()
                })
            }
            .overlay(alignment: .bottomTrailing) {
                if index < 9 {
                    ShortcutBadge(index: index)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if item.isLocked {
                    LockedBadge()
                }
            }
        }
        .buttonStyle(InstantButtonStyle())
        .onDrag {
            isDragging = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isDragging = false }
            return DragItemProvider(item: item).itemProvider
        }
    }

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(isFocused ? Color.blue : Color.white.opacity(0.2), lineWidth: isFocused ? 3 : 1)
            // 优化点：关闭动画，响应更跟手
            .animation(nil, value: isFocused)
    }
    
    private func toggleLock() {
        item.isLocked.toggle()
        do {
            try modelContext.save()
        } catch {
            print("❌ 切换锁定状态失败: \(error)")
        }
    }
}

// MARK: - 1. 头部组件

private struct CardHeaderView: View {
    let item: ClipboardItem
    let timeRefreshTrigger: Int

    var body: some View {
        HStack(spacing: 8) {
            // 优化点：使用全局缓存的 App 图标视图
            CachedAppIconView(bundleID: item.sourceAppBundleID)
                .frame(width: 44, height: 44)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.type.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(item.relativeTimeString)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.75))
                    // 仅当时间触发器变化时才重绘时间
                    .id("time-\(item.id)-\(timeRefreshTrigger)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6) // 稍微增加高度以容纳内容
        .frame(height: 54)
    }
}

// MARK: - 2. 内容组件

private struct CardBodyView: View {
    let item: ClipboardItem
    @State private var backgroundColor: Color?

    var body: some View {
        Group {
            switch item.type {
            case .text, .code:
                AsyncRichTextView(
                    item: item,
                    text: item.content,
                    rtfData: item.richTextData,
                    fallbackText: item.contentPreview,
                    isCode: item.type == .code,
                    onBackgroundColorChanged: { color in
                        backgroundColor = color
                    }
                )
            case .image:
                ImageContentView(item: item)
            case .link:
                LinkContentView(item: item)
            case .color:
                ColorContentView(item: item)
            case .file:
                FileContentView(item: item)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding([.horizontal, .bottom], 12)
        .padding(.top, 8)
        .background(backgroundColor ?? Color.clear) // 背景色覆盖整个内容区域，包括 padding
    }
}

// MARK: - 3. 具体内容子视图 (添加了缓存和降采样)

private struct ImageContentView: View {
    let item: ClipboardItem
    
    private func truncateString(_ string: String, maxLength: Int) -> String {
        guard string.count > maxLength else { return string }
        let truncated = String(string.prefix(maxLength))
        return truncated + "..."
    }
    
    private var imageName: String {
        if item.content.starts(with: "/") {
            // 是文件路径
            return URL(fileURLWithPath: item.content).lastPathComponent
        } else {
            // 可能是 "Image" 或其他，使用默认名称
            return "图片"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            if let imageData = item.imageData {
                // 优化点：使用降采样缓存视图，不再直接加载原图
                CachedThumbnailView(imageData: imageData, targetSize: CGSize(width: 90, height: 90))
                    .frame(width: 90, height: 90)
            } else {
                PlaceholderImage(icon: "photo")
            }

            Text(truncateString(imageName, maxLength: 30))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if let fileSize = item.fileSize {
                FileSizeText(size: fileSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LinkContentView: View {
    let item: ClipboardItem
    
    private func truncateString(_ string: String, maxLength: Int) -> String {
        guard string.count > maxLength else { return string }
        let truncated = String(string.prefix(maxLength))
        return truncated + "..."
    }

    var body: some View {
        VStack(spacing: 6) {
            if let faviconData = item.linkFaviconData {
                // Favicon 通常很小，不需要降采样，但可以用普通 Image 缓存
                CachedThumbnailView(imageData: faviconData, targetSize: CGSize(width: 32, height: 32))
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }

            if let title = item.linkTitle {
                Text(truncateString(title, maxLength: 30))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            Text(truncateString(item.content, maxLength: 40))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FileContentView: View {
    let item: ClipboardItem
    
    private func truncateString(_ string: String, maxLength: Int) -> String {
        guard string.count > maxLength else { return string }
        let truncated = String(string.prefix(maxLength))
        return truncated + "..."
    }

    var body: some View {
        VStack(spacing: 8) {
            if let filePath = item.firstFilePath {
                // 优化点：文件图标也走缓存
                CachedFileIconView(path: filePath)
                    .frame(width: 80, height: 80)
            } else {
                PlaceholderImage(icon: "doc.fill", color: .orange)
            }

            if let fileName = item.fileName {
                Text(truncateString(fileName, maxLength: 30))
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            if let fileSize = item.fileSize {
                FileSizeText(size: fileSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ColorContentView: View {
    let item: ClipboardItem

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: item.content) ?? .gray)
                .frame(width: 80, height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )

            Text(item.content)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 4. 核心优化组件：缓存与异步加载

/// 1. App 图标缓存视图 (全局单例缓存)
struct CachedAppIconView: View {
    let bundleID: String
    @State private var icon: NSImage?
    
    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .task(id: bundleID) {
            // 优先从内存同步获取
            if let cached = AppIconCache.shared.get(bundleID: bundleID) {
                self.icon = cached
            } else {
                // 异步加载
                let loaded = await AppIconCache.shared.load(bundleID: bundleID)
                await MainActor.run { self.icon = loaded }
            }
        }
    }
}

/// 2. 图片缩略图缓存视图 (降采样 + 缓存)
struct CachedThumbnailView: View {
    let imageData: Data
    let targetSize: CGSize
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Color.gray.opacity(0.1)
            }
        }
        .task(id: imageData.sha256Hash) { // 使用 hash 作为 id，确保内容变化时重新加载
            // 尝试内存缓存
            let key = imageData.sha256Hash
            if let cached = ImageThumbnailCache.shared.get(key: key) {
                await MainActor.run { self.image = cached }
                return
            }
            
            // 异步降采样
            let loaded = await ImageThumbnailCache.shared.downsample(data: imageData, to: targetSize, key: key)
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) {
                    self.image = loaded
                }
            }
        }
    }
}

/// 3. 文件图标缓存视图
struct CachedFileIconView: View {
    let path: String
    @State private var icon: NSImage?
    
    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "doc")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
            }
        }
        .task(id: path) { // 监听 path 变化，支持路径改变时重新加载
            let loaded = await Task.detached {
                NSWorkspace.shared.icon(forFile: path)
            }.value
            await MainActor.run { self.icon = loaded }
        }
    }
}

/// 4. 富文本视图 (优化了 L1 缓存命中逻辑)
struct AsyncRichTextView: View {
    let item: ClipboardItem
    let text: String
    let rtfData: Data?
    let fallbackText: String
    let isCode: Bool
    let onBackgroundColorChanged: ((Color?) -> Void)?
    
    @State private var attributedContent: AttributedString?
    @State private var backgroundColor: Color?
    
    var body: some View {
        Group {
            if let content = attributedContent {
                Text(content)
            } else {
                Text(fallbackText)
            }
        }
        .font(.system(size: 12, design: isCode ? .monospaced : .default))
        .foregroundColor(.primary)
        .lineLimit(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .task(id: text) { // 绑定 text 变化
            await loadRichText()
        }
        .onChange(of: backgroundColor) { oldValue, newValue in
            onBackgroundColorChanged?(newValue)
        }
    }
    
    private func loadRichText() async {
        // 1. 如果有 richTextData，检测格式并解析（富文本逻辑）
        if let richData = rtfData {
            let cacheKey = richData.sha256Hash
            
            // 同步检查 L1 内存缓存
            if let cached = await RichTextCache.shared.getFromMemory(key: cacheKey) {
                await MainActor.run {
                    self.attributedContent = cached.attributedString
                    self.backgroundColor = cached.backgroundColor
                    onBackgroundColorChanged?(cached.backgroundColor)
                }
                return
            }
            
            // 检测数据格式：RTF 还是 HTML
            let isHTML = detectHTMLFormat(in: richData)
            
            // 异步加载（富文本渲染）
            let result = await RichTextCache.shared.load(data: richData, key: cacheKey, isHTML: isHTML)
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.1)) {
                    self.attributedContent = result.attributedString
                    self.backgroundColor = result.backgroundColor
                    onBackgroundColorChanged?(result.backgroundColor)
                }
            }
            return
        }
        
        // 2. 如果没有 richTextData，检查 text 是否包含 RTF（可能是纯文本中的 RTF）
        let isRTF = text.hasPrefix("{\\rtf") || text.hasPrefix("{\\rtf1")
        
        if isRTF {
            // 尝试解析 RTF
            if let textData = text.data(using: .utf8) {
                let cacheKey = textData.sha256Hash
                
                // 同步检查缓存
                if let cached = await RichTextCache.shared.getFromMemory(key: cacheKey) {
                    await MainActor.run {
                        self.attributedContent = cached.attributedString
                        self.backgroundColor = cached.backgroundColor
                        onBackgroundColorChanged?(cached.backgroundColor)
                    }
                    return
                }
                
                // 异步加载
                let result = await RichTextCache.shared.load(data: textData, key: cacheKey, isHTML: false)
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.1)) {
                        self.attributedContent = result.attributedString
                        self.backgroundColor = result.backgroundColor
                        onBackgroundColorChanged?(result.backgroundColor)
                    }
                }
                return
            }
        }
        
        // 3. 纯文本（包括包含 HTML 标签的纯文本），直接显示（不设置 attributedContent，使用 fallbackText）
        // 不尝试解析或去除 HTML 标签，正常显示原始文本
    }
    
    /// 检测数据是否为 HTML 格式
    private func detectHTMLFormat(in data: Data) -> Bool {
        // 检查数据开头是否是 RTF 格式
        if data.count >= 5 {
            let prefix = data.prefix(5)
            if let prefixString = String(data: prefix, encoding: .utf8),
               prefixString.hasPrefix("{\\rtf") {
                return false // 是 RTF 格式
            }
        }
        
        // 检查是否包含 HTML 标签
        if let content = String(data: data, encoding: .utf8) {
            let lowerContent = content.lowercased()
            return lowerContent.contains("<html") ||
                   lowerContent.contains("<!doctype html") ||
                   lowerContent.contains("<div") ||
                   lowerContent.contains("<span") ||
                   lowerContent.contains("<p>") ||
                   lowerContent.contains("<body")
        }
        
        return false
    }
}

// MARK: - Cache Managers (Singletons)

/// App 图标缓存管理器
final class AppIconCache {
    static let shared = AppIconCache()
    private let cache = NSCache<NSString, NSImage>()
    
    private init() { cache.countLimit = 100 }
    
    func get(bundleID: String) -> NSImage? {
        cache.object(forKey: bundleID as NSString)
    }
    
    func load(bundleID: String) async -> NSImage? {
        if bundleID.isEmpty { return nil }
        
        // 如果已经有缓存，再次返回
        if let cached = get(bundleID: bundleID) { return cached }
        
        // 在 detached task 中安全访问 cache
        let cacheRef = self.cache
        return await Task.detached(priority: .background) {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                cacheRef.setObject(icon, forKey: bundleID as NSString)
                return icon
            }
            return nil
        }.value
    }
}

/// 图片缩略图缓存管理器 (支持 Downsampling)
final class ImageThumbnailCache {
    static let shared = ImageThumbnailCache()
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 50 // 限制图片数量
        cache.totalCostLimit = 50 * 1024 * 1024 // 限制 50MB
    }
    
    func get(key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }
    
    /// 生成降采样缩略图
    func downsample(data: Data, to pointSize: CGSize, key: String, scale: CGFloat = 2.0) async -> NSImage? {
        // 在 detached task 中安全访问 cache
        let cacheRef = self.cache
        return await Task.detached(priority: .userInitiated) {
            // 1. 创建 ImageSource
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
            
            // 2. 计算像素尺寸
            let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
            
            // 3. 配置降采样参数
            let downsampleOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
            ] as CFDictionary
            
            // 4. 生成缩略图
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
            
            let image = NSImage(cgImage: cgImage, size: pointSize)
            cacheRef.setObject(image, forKey: key as NSString)
            return image
        }.value
    }
}

// 富文本缓存 (优化后的逻辑)
actor RichTextCache {
    static let shared = RichTextCache()
    
    struct CachedResult {
        let attributedString: AttributedString
        let backgroundColor: Color?
    }
    
    private let memoryCache = NSCache<NSString, RichTextCacheEntry>()
    
    func getFromMemory(key: String) -> CachedResult? {
        guard let entry = memoryCache.object(forKey: key as NSString) else { return nil }
        return CachedResult(attributedString: entry.attributedString, backgroundColor: entry.backgroundColor)
    }
    
    func load(data: Data, key: String, isHTML: Bool = false) async -> CachedResult {
        // Double check memory inside actor
        if let entry = memoryCache.object(forKey: key as NSString) {
            return CachedResult(attributedString: entry.attributedString, backgroundColor: entry.backgroundColor)
        }
        
        // Load from disk or parse
        // 这里简化逻辑，实际项目中应包含磁盘读取
        return await parseAndCache(data: data, key: key, isHTML: isHTML)
    }
    
    private func parseAndCache(data: Data, key: String, isHTML: Bool = false) async -> CachedResult {
        // 在 detached task 中解析 RTF 或 HTML，避免阻塞 Actor
        let result = await Task.detached { () -> CachedResult in
            var nsAttr: NSAttributedString?
            var backgroundColor: Color?
            
            // 1. 如果是 HTML 格式，直接尝试解析 HTML
            if isHTML {
                // 尝试作为 HTML 解析
                nsAttr = try? NSAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ],
                    documentAttributes: nil
                )
                
                // 如果 HTML 解析失败，尝试从纯文本创建（去除 HTML 标签）
                if nsAttr == nil {
                    if let htmlString = String(data: data, encoding: .utf8) {
                        // 简单去除 HTML 标签（作为最后的回退）
                        let plainText = htmlString
                            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        nsAttr = NSAttributedString(string: plainText.isEmpty ? htmlString : plainText)
                    }
                }
            } else {
                // 2. 尝试解析 RTF
                nsAttr = try? NSAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.rtf,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ],
                    documentAttributes: nil
                )
                
                // 3. 如果 RTF 失败，尝试作为 HTML 解析（可能是误判）
                if nsAttr == nil {
                    nsAttr = try? NSAttributedString(
                        data: data,
                        options: [
                            .documentType: NSAttributedString.DocumentType.html,
                            .characterEncoding: String.Encoding.utf8.rawValue
                        ],
                        documentAttributes: nil
                    )
                }
                
                // 4. 如果都失败，使用纯文本
                if nsAttr == nil {
                    let str = String(data: data, encoding: .utf8) ?? ""
                    nsAttr = NSAttributedString(string: str)
                }
            }
            
            // 5. 提取背景色
            if let attributedString = nsAttr {
                backgroundColor = RichTextCache.extractBackgroundColor(from: attributedString)
                return CachedResult(
                    attributedString: AttributedString(attributedString),
                    backgroundColor: backgroundColor
                )
            } else {
                // 最后的回退：纯文本
                let str = String(data: data, encoding: .utf8) ?? ""
                return CachedResult(
                    attributedString: AttributedString(str),
                    backgroundColor: nil
                )
            }
        }.value
        
        let entry = RichTextCacheEntry(attributedString: result.attributedString, backgroundColor: result.backgroundColor)
        memoryCache.setObject(entry, forKey: key as NSString)
        
        return result
    }
    
    /// 从 NSAttributedString 中提取背景色（静态方法，可在 detached task 中使用）
    static func extractBackgroundColor(from attributedString: NSAttributedString) -> Color? {
        // 检查整个字符串范围的背景色
        let fullRange = NSRange(location: 0, length: attributedString.length)
        
        // 尝试获取背景色属性
        if let bgColor = attributedString.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor {
            return Color(nsColor: bgColor)
        }
        
        // 遍历所有属性范围，查找最常见的背景色
        var colorCounts: [NSColor: Int] = [:]
        attributedString.enumerateAttribute(.backgroundColor, in: fullRange, options: []) { value, _, _ in
            if let color = value as? NSColor {
                colorCounts[color, default: 0] += 1
            }
        }
        
        // 返回最常见的背景色（如果存在）
        if let mostCommonColor = colorCounts.max(by: { $0.value < $1.value })?.key {
            return Color(nsColor: mostCommonColor)
        }
        
        return nil
    }
}

private class RichTextCacheEntry: NSObject {
    let attributedString: AttributedString
    let backgroundColor: Color?
    init(attributedString: AttributedString, backgroundColor: Color?) {
        self.attributedString = attributedString
        self.backgroundColor = backgroundColor
    }
}

// MARK: - Helpers

extension Data {
    var sha256Hash: String {
        SHA256.hash(data: self).compactMap { String(format: "%02x", $0) }.joined()
    }
}

struct PlaceholderImage: View {
    let icon: String
    var color: Color = .gray

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .frame(width: 90, height: 90)
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color.opacity(0.7))
        }
    }
}

struct FileSizeText: View {
    let size: Int64
    // 静态 formatter 避免重复创建
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f
    }()

    var body: some View {
        Text(Self.formatter.string(fromByteCount: size))
            .font(.system(size: 10))
            .foregroundColor(.secondary)
    }
}

struct ShortcutBadge: View {
    let index: Int
    var body: some View {
        Text("⌘\(index + 1)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.4))
            .clipShape(Capsule())
            .padding(6)
    }
}

struct InstantButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .onTapGesture(perform: configuration.trigger)
    }
}

// 占位 Menu 和 Helper
struct CardContextMenu: View {
    let item: ClipboardItem
    let onDelete: () -> Void
    let onToggleLock: () -> Void
    
    var body: some View {
        Group {
            // 锁定/解锁选项
            Button(item.isLocked ? "解锁" : "锁定") {
                onToggleLock()
            }
            
            Divider()
            
            switch item.type {
            case .link:
                Button("跳转至") {
                    if let url = URL(string: item.content) {
                        NSWorkspace.shared.open(url)
                    }
                }
                Divider()
                Button("删除", role: .destructive) {
                    handleDelete()
                }
                .disabled(item.isLocked) // 锁定状态下禁用删除按钮
                
            case .file, .image:
                Button("复制文件名") {
                    let fileName: String
                    if item.type == .image && item.content.starts(with: "/") {
                        fileName = URL(fileURLWithPath: item.content).lastPathComponent
                    } else if let filePath = item.firstFilePath {
                        fileName = URL(fileURLWithPath: filePath).lastPathComponent
                    } else {
                        return
                    }
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(fileName, forType: .string)
                }
                Button("复制文件地址") {
                    let filePath: String
                    if item.type == .image && item.content.starts(with: "/") {
                        filePath = item.content
                    } else if let path = item.firstFilePath {
                        filePath = path
                    } else {
                        return
                    }
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(filePath, forType: .string)
                }
                Button("跳转至文件夹") {
                    let filePath: String
                    if item.type == .image && item.content.starts(with: "/") {
                        filePath = item.content
                    } else if let path = item.firstFilePath {
                        filePath = path
                    } else {
                        return
                    }
                    let url = URL(fileURLWithPath: filePath)
                    NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                }
                Divider()
                Button("删除", role: .destructive) {
                    handleDelete()
                }
                .disabled(item.isLocked) // 锁定状态下禁用删除按钮
                
            default:
                Button("删除", role: .destructive) {
                    handleDelete()
                }
                .disabled(item.isLocked) // 锁定状态下禁用删除按钮
            }
        }
    }
    
    private func handleDelete() {
        // 检查是否锁定（锁定状态下按钮已禁用，这里作为双重保护）
        if item.isLocked {
            return
        }
        
        // 执行删除（会移动到回收站）
        onDelete()
    }
}

// MARK: - Locked Badge

private struct LockedBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
            Text("已锁定")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(8)
    }
}

private class DragItemProvider: NSObject {
    let item: ClipboardItem
    init(item: ClipboardItem) { self.item = item }
    var itemProvider: NSItemProvider { NSItemProvider(object: item.content as NSString) }
}
