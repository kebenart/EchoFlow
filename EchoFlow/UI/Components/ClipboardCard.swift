//
//  ClipboardCard.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import SwiftUI
import AppKit
import CryptoKit

/// 剪贴板卡片视图 - 使用 BaseClipboardContentView 实现
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
    
    var body: some View {
        BaseClipboardContentView(
            item: item,
            index: index,
            isFocused: isFocused,
            timeRefreshTrigger: timeRefreshTrigger,
            config: .card,
            onTap: onTap,
            onDoubleTap: nil,
            onDelete: onDelete
        )
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
        return await parseAndCache(data: data, key: key, isHTML: isHTML)
    }
    
    private func parseAndCache(data: Data, key: String, isHTML: Bool = false) async -> CachedResult {
        // 在 detached task 中解析 RTF 或 HTML，避免阻塞 Actor
        let result = await Task.detached { () -> CachedResult in
            var nsAttr: NSAttributedString?
            var backgroundColor: Color?
            
            // 1. 如果是 HTML 格式，直接尝试解析 HTML
            if isHTML {
                nsAttr = try? NSAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ],
                    documentAttributes: nil
                )
                
                // 如果 HTML 解析失败，尝试从纯文本创建
                if nsAttr == nil {
                    if let htmlString = String(data: data, encoding: .utf8) {
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
                
                // 3. 如果 RTF 失败，尝试作为 HTML 解析
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
    
    /// 从 NSAttributedString 中提取背景色
    static func extractBackgroundColor(from attributedString: NSAttributedString) -> Color? {
        let fullRange = NSRange(location: 0, length: attributedString.length)
        
        if let bgColor = attributedString.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor {
            return Color(nsColor: bgColor)
        }
        
        var colorCounts: [NSColor: Int] = [:]
        attributedString.enumerateAttribute(.backgroundColor, in: fullRange, options: []) { value, _, _ in
            if let color = value as? NSColor {
                colorCounts[color, default: 0] += 1
            }
        }
        
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

// MARK: - Cached Views

/// App 图标缓存视图 (全局单例缓存)
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
            if let cached = AppIconCache.shared.get(bundleID: bundleID) {
                self.icon = cached
            } else {
                let loaded = await AppIconCache.shared.load(bundleID: bundleID)
                await MainActor.run { self.icon = loaded }
            }
        }
    }
}

/// 图片缩略图缓存视图 (降采样 + 缓存)
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
        .task(id: imageData.sha256Hash) {
            let key = imageData.sha256Hash
            if let cached = ImageThumbnailCache.shared.get(key: key) {
                await MainActor.run { self.image = cached }
                return
            }
            
            let loaded = await ImageThumbnailCache.shared.downsample(data: imageData, to: targetSize, key: key)
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) {
                    self.image = loaded
                }
            }
        }
    }
}

/// 文件图标缓存视图
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
        .task(id: path) {
            let loaded = await Task.detached {
                NSWorkspace.shared.icon(forFile: path)
            }.value
            await MainActor.run { self.icon = loaded }
        }
    }
}

/// 富文本视图
struct AsyncRichTextView: View {
    let item: ClipboardItem
    let text: String
    let rtfData: Data?
    let fallbackText: String
    let isCode: Bool
    let onBackgroundColorChanged: ((Color?) -> Void)?
    
    @State private var attributedContent: AttributedString?
    @State private var backgroundColor: Color?
    @AppStorage("cardFontName") private var cardFontName: String = "SF Pro Text"
    @AppStorage("cardFontSize") private var cardFontSize: Double = 12.0
    
    private var cardFont: Font {
        let fontSize = CGFloat(cardFontSize)
        if isCode {
            return .system(size: fontSize, design: .monospaced)
        } else {
            if let font = NSFont(name: cardFontName, size: fontSize) {
                return Font(font)
            }
            return .system(size: fontSize, design: .default)
        }
    }
    
    var body: some View {
        Group {
            if let content = attributedContent {
                Text(content)
            } else {
                Text(fallbackText)
            }
        }
        .font(cardFont)
        .foregroundColor(Color(NSColor.black))
        .lineLimit(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .task(id: text) {
            await loadRichText()
        }
        .onChange(of: backgroundColor) { oldValue, newValue in
            onBackgroundColorChanged?(newValue)
        }
    }
    
    private func loadRichText() async {
        if let richData = rtfData {
            let cacheKey = richData.sha256Hash
            
            if let cached = await RichTextCache.shared.getFromMemory(key: cacheKey) {
                await MainActor.run {
                    self.attributedContent = cached.attributedString
                    self.backgroundColor = cached.backgroundColor
                    onBackgroundColorChanged?(cached.backgroundColor)
                }
                return
            }
            
            let isHTML = detectHTMLFormat(in: richData)
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
        
        let isRTF = text.hasPrefix("{\\rtf") || text.hasPrefix("{\\rtf1")
        
        if isRTF {
            if let textData = text.data(using: .utf8) {
                let cacheKey = textData.sha256Hash
                
                if let cached = await RichTextCache.shared.getFromMemory(key: cacheKey) {
                    await MainActor.run {
                        self.attributedContent = cached.attributedString
                        self.backgroundColor = cached.backgroundColor
                        onBackgroundColorChanged?(cached.backgroundColor)
                    }
                    return
                }
                
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
    }
    
    private func detectHTMLFormat(in data: Data) -> Bool {
        if data.count >= 5 {
            let prefix = data.prefix(5)
            if let prefixString = String(data: prefix, encoding: .utf8),
               prefixString.hasPrefix("{\\rtf") {
                return false
            }
        }
        
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
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f
    }()

    var body: some View {
        Text(Self.formatter.string(fromByteCount: size))
            .font(.system(size: 10))
            .foregroundColor(Color(NSColor.gray))
    }
}

// 保留旧的类型别名以保持兼容性
typealias ShortcutBadge = BaseShortcutBadge
typealias InstantButtonStyle = BaseInstantButtonStyle
typealias CardContextMenu = BaseCardContextMenu
