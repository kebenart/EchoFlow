//
//  PasteboardManager.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import AppKit
import Foundation
import SwiftData

/// 剪贴板监听管理器
@Observable
final class PasteboardManager {
    // MARK: - Singleton

    static let shared = PasteboardManager()

    // MARK: - Properties

    /// 系统剪贴板
    private let pasteboard = NSPasteboard.general

    /// 上一次的 changeCount
    private var lastChangeCount: Int = 0

    /// 定时器
    private var timer: Timer?

    /// 模型上下文 (用于存储数据)
    var modelContext: ModelContext?

    /// 最近一次保存的内容哈希（在 ModelContext 未初始化时用于简单去重）
    private var lastSavedHash: String?

    /// 记录最近保存的内容哈希及其时间，用于防止短时间内保存重复内容
    private var recentSavedItems: [(hash: String, timestamp: Date)] = []

    /// 去重时间窗口（秒）
    private let deduplicationWindowSeconds: TimeInterval = 2.0

    /// 最多保留最近的 20 条记录
    private let maxRecentItemsCount = 20

    /// 获取过滤的应用 Bundle ID 列表（从 UserDefaults 读取用户添加的应用 + 默认密码管理器）
    private var filteredApps: [String] {
        let defaultApps = [
            "com.agilebits.onepassword7",
            "com.agilebits.onepassword-osx",
            "com.lastpass.LastPass",
            "com.apple.keychainaccess",
            "ws.agile.1PasswordSafari"
        ]
        let userFilteredApps = UserDefaults.standard.stringArray(forKey: "userFilteredApps") ?? []
        return defaultApps + userFilteredApps
    }

    /// 是否正在监听
    var isMonitoring: Bool = false
    
    /// 剪贴板检查计数器（用于调试日志）
    private var checkCount: Int = 0
    
    /// 应用自己的 Bundle ID（用于识别内部写入）
    private let appBundleID = Bundle.main.bundleIdentifier ?? ""
    
    /// 最近一次内部写入的时间（用于短暂忽略内部写入后的变化）
    private var lastInternalWriteTime: Date?
    
    /// 内部写入后的忽略窗口（秒）
    private let ignoreWindowAfterInternalWrite: TimeInterval = 0.3

    // MARK: - Initialization

    private init() {
        self.lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Public Methods

    /// 开始监听剪贴板
    func startMonitoring() {
        guard !isMonitoring else { 
            print("⚠️ 剪贴板监听已在运行")
            return 
        }

        isMonitoring = true
        lastChangeCount = pasteboard.changeCount

        // 使用 0.5 秒的轮询间隔，确保在主线程的 RunLoop 上运行
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        
        // 确保 Timer 在主线程的 RunLoop 上运行
        RunLoop.main.add(timer!, forMode: .common)
        
        // 立即检查一次，确保初始状态正确
        DispatchQueue.main.async { [weak self] in
            self?.checkPasteboard()
        }
    }

    /// 停止监听剪贴板
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        print("📋 剪贴板监听已停止")
    }

    /// 将内容写入剪贴板
    func writeToPasteboard(content: String) {
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        let newChangeCount = pasteboard.changeCount
        
        // 记录内部写入时间
        lastInternalWriteTime = Date()
        
        // 延迟更新 lastChangeCount，给外部变化一个检测窗口
        DispatchQueue.main.asyncAfter(deadline: .now() + ignoreWindowAfterInternalWrite) { [weak self] in
            guard let self = self else { return }
            // 只有在 changeCount 没有变化时才更新（说明没有外部变化）
            if self.pasteboard.changeCount == newChangeCount {
                self.lastChangeCount = newChangeCount
            }
        }
    }

    /// 将图片写入剪贴板
    func writeToPasteboard(image: NSImage) {
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        let newChangeCount = pasteboard.changeCount
        
        // 记录内部写入时间
        lastInternalWriteTime = Date()
        
        // 延迟更新 lastChangeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + ignoreWindowAfterInternalWrite) { [weak self] in
            guard let self = self else { return }
            if self.pasteboard.changeCount == newChangeCount {
                self.lastChangeCount = newChangeCount
            }
        }
    }

    /// 将文件 URL 写入剪贴板
    func writeToPasteboard(fileURLs: [URL]) {
        pasteboard.clearContents()
        pasteboard.writeObjects(fileURLs as [NSURL])
        let newChangeCount = pasteboard.changeCount
        
        // 记录内部写入时间
        lastInternalWriteTime = Date()
        
        // 延迟更新 lastChangeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + ignoreWindowAfterInternalWrite) { [weak self] in
            guard let self = self else { return }
            if self.pasteboard.changeCount == newChangeCount {
                self.lastChangeCount = newChangeCount
            }
        }
    }

    // MARK: - Private Methods

    /// 检查剪贴板变化
    private func checkPasteboard() {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.checkPasteboard()
            }
            return
        }
        
        // 检查监听状态
        guard isMonitoring else {
            return
        }
        
        let currentChangeCount = pasteboard.changeCount

        // 如果没有变化，直接返回
        if currentChangeCount == lastChangeCount {
            return
        }
        
        // 重置计数器（当检测到变化时）
        checkCount = 0
        
        // 检查是否在内部写入后的忽略窗口内
        if let lastWriteTime = lastInternalWriteTime {
            let timeSinceWrite = Date().timeIntervalSince(lastWriteTime)
            if timeSinceWrite < ignoreWindowAfterInternalWrite {
                // 更新 lastChangeCount 但不处理内容
                lastChangeCount = currentChangeCount
                return
            }
        }
        
        // 更新 lastChangeCount
        lastChangeCount = currentChangeCount

        // 获取当前活动的应用
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return
        }

        // 过滤自己的应用（避免处理自己写入的内容）
        if frontApp.bundleIdentifier == appBundleID {
            return
        }

        // 过滤敏感应用 (密码管理器等)
        if filteredApps.contains(frontApp.bundleIdentifier ?? "") {
            return
        }

        // 处理剪贴板内容
        processClipboardContent(from: frontApp)
    }

    /// 处理剪贴板内容
    private func processClipboardContent(from app: NSRunningApplication) {
        // 优先检查是否有文件 URL（文件操作优先级最高）
        // 这样可以确保复制文件（包括图片文件）时被识别为文件类型
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            // 检查是否是 HTTP/HTTPS URL（这些应该作为链接处理，而不是文件）
            let httpURLs = urls.filter { url in
                guard let scheme = url.scheme?.lowercased() else { return true }
                return scheme != "http" && scheme != "https"
            }
            
            if !httpURLs.isEmpty {
                // 有非 HTTP/HTTPS 的文件 URL，按文件处理
                processFileContent(httpURLs, from: app)
                return
            }
            // 只有 HTTP/HTTPS URL，继续下面的文本处理流程
        }

        // 检查是否有图片内容（截图、从应用复制的图片等）
        if let image = NSImage(pasteboard: pasteboard) {
            processImageContent(image, from: app)
            return
        }

        // 最后检查文本内容（包括链接）
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            processTextContent(string, from: app)
            return
        }
    }

    /// 处理文本内容
    private func processTextContent(_ content: String, from app: NSRunningApplication) {
        // 检测内容类型
        let type = detectContentType(content)

        // 生成哈希用于去重
        let hash = ClipboardItem.generateHash(from: content)

        // 检查最近时间窗口内是否已保存过相同内容
        if isRecentlySaved(hash: hash) {
            return
        }

        // 检查数据库中是否已存在相同内容
        if let existingItem = findExistingItem(hash: hash) {
            updateItemTimestamp(existingItem)
            recordRecentSave(hash: hash)
            return
        }

        // 从剪贴板尝试获取富文本数据 (RTF 优先，其次 HTML)
        let richData = pasteboard.data(forType: .rtf) ?? pasteboard.data(forType: .html)

        // 创建剪贴板项目（同时保存纯文本和富文本）
        let item = ClipboardItem(
            content: content,
            richTextData: richData,
            type: type,
            sourceApp: app.localizedName ?? "Unknown",
            sourceAppBundleID: app.bundleIdentifier ?? "",
            themeColorHex: extractThemeColor(for: app)
        )

        // 存储到数据库
        saveItem(item)

        // 记录到最近保存列表
        recordRecentSave(hash: hash)


        // 如果是链接类型，且启用了链接预览（默认启用），则异步获取元数据
        let enableLinkPreview = UserDefaults.standard.object(forKey: "enableLinkPreview") as? Bool ?? true
        if type == .link, enableLinkPreview {
            // 尝试创建 URL，如果失败则添加 https:// 前缀
            var url: URL?
            if let directURL = URL(string: content) {
                url = directURL
            } else if let prefixedURL = URL(string: "https://" + content) {
                url = prefixedURL
            }
            
            if let validURL = url {
                fetchLinkMetadata(for: item, url: validURL)
            }
        }
    }

    /// 处理图片内容
    private func processImageContent(_ image: NSImage, from app: NSRunningApplication) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        // 生成哈希
        let hash = ClipboardItem.generateHash(from: "", imageData: pngData)

        // 检查最近时间窗口内是否已保存过相同内容
        if isRecentlySaved(hash: hash) {
            return
        }

        // 检查数据库中是否已存在
        if let existingItem = findExistingItem(hash: hash) {
            updateItemTimestamp(existingItem)
            recordRecentSave(hash: hash)
            return
        }

        // 创建剪贴板项目
        let item = ClipboardItem(
            content: "Image",
            richTextData: nil,
            imageData: pngData,
            type: .image,
            sourceApp: app.localizedName ?? "Unknown",
            sourceAppBundleID: app.bundleIdentifier ?? "",
            themeColorHex: extractThemeColor(for: app),
            fileSize: Int64(pngData.count)
        )

        saveItem(item)

        // 记录到最近保存列表
        recordRecentSave(hash: hash)

    }

    /// 处理文件内容
    private func processFileContent(_ urls: [URL], from app: NSRunningApplication) {
        let paths = urls.map { $0.path }.joined(separator: "\n")

        // 检查是否是图片文件（单个文件且是图片格式）
        if urls.count == 1, let url = urls.first, isImageFile(url) {
            processImageFile(url, from: app)
            return
        }

        let hash = ClipboardItem.generateHash(from: paths)

        // 检查最近时间窗口内是否已保存过相同内容
        if isRecentlySaved(hash: hash) {
            return
        }

        // 检查数据库中是否已存在
        if let existingItem = findExistingItem(hash: hash) {
            updateItemTimestamp(existingItem)
            recordRecentSave(hash: hash)
            return
        }

        // 计算文件总大小
        var totalSize: Int64 = 0
        for url in urls {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }

        let item = ClipboardItem(
            content: paths,
            richTextData: nil,
            type: .file,
            sourceApp: app.localizedName ?? "Unknown",
            sourceAppBundleID: app.bundleIdentifier ?? "",
            themeColorHex: extractThemeColor(for: app),
            fileSize: totalSize > 0 ? totalSize : nil
        )

        saveItem(item)

        // 记录到最近保存列表
        recordRecentSave(hash: hash)

        let fileInfo = urls.count > 1 ? "\(urls.count)个文件" : "文件"
        let sizeInfo = totalSize > 0 ? "，大小: \(formatFileSize(totalSize))" : ""
    }

    /// 判断是否是图片文件
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "ico"]
        let ext = url.pathExtension.lowercased()
        return imageExtensions.contains(ext)
    }

    /// 处理图片文件
    private func processImageFile(_ url: URL, from app: NSRunningApplication) {
        guard let image = NSImage(contentsOf: url) else {
            return
        }

        // 生成缩略图
        guard let thumbnailData = generateThumbnail(from: image) else {
            return
        }

        // 生成哈希
        let hash = ClipboardItem.generateHash(from: url.path, imageData: thumbnailData)

        // 检查最近时间窗口内是否已保存过相同内容
        if isRecentlySaved(hash: hash) {
            return
        }

        // 检查数据库中是否已存在
        if let existingItem = findExistingItem(hash: hash) {
            updateItemTimestamp(existingItem)
            recordRecentSave(hash: hash)
            return
        }

        // 获取文件大小
        var fileSize: Int64? = nil
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int64 {
            fileSize = size
        }

        // 创建剪贴板项目
        let item = ClipboardItem(
            content: url.path,  // 保存文件路径
            richTextData: nil,
            imageData: thumbnailData,  // 保存缩略图
            type: .image,
            sourceApp: app.localizedName ?? "Unknown",
            sourceAppBundleID: app.bundleIdentifier ?? "",
            themeColorHex: extractThemeColor(for: app),
            fileSize: fileSize
        )


        saveItem(item)

        // 记录到最近保存列表
        recordRecentSave(hash: hash)

    }

    /// 生成缩略图（类似macOS文件系统预览）
    private func generateThumbnail(from image: NSImage) -> Data? {
        // 获取原始尺寸
        let originalSize = image.size

        // 计算缩略图尺寸（最大边不超过512px，保持宽高比）
        let maxDimension: CGFloat = 512
        var targetSize = originalSize

        if originalSize.width > maxDimension || originalSize.height > maxDimension {
            let aspectRatio = originalSize.width / originalSize.height
            if originalSize.width > originalSize.height {
                targetSize = NSSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                targetSize = NSSize(width: maxDimension * aspectRatio, height: maxDimension)
            }
        }

        // 创建缩略图
        let thumbnail = NSImage(size: targetSize)
        thumbnail.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy,
                   fraction: 1.0)

        thumbnail.unlockFocus()

        // 转换为PNG数据
        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        return pngData
    }

    /// 检查哈希是否在最近的时间窗口内已保存过
    private func isRecentlySaved(hash: String) -> Bool {
        let now = Date()

        // 清理过期的记录
        recentSavedItems.removeAll { now.timeIntervalSince($0.timestamp) > deduplicationWindowSeconds }

        // 检查是否存在相同哈希
        return recentSavedItems.contains { $0.hash == hash }
    }

    /// 记录最近保存的哈希
    private func recordRecentSave(hash: String) {
        let now = Date()
        recentSavedItems.append((hash: hash, timestamp: now))

        // 只保留最近的 N 条记录
        if recentSavedItems.count > maxRecentItemsCount {
            recentSavedItems.removeFirst(recentSavedItems.count - maxRecentItemsCount)
        }
    }

    /// 检测内容类型
    private func detectContentType(_ content: String) -> ContentType {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. 检测标准 URL 协议（最可靠）
        if trimmedContent.starts(with: "http://") || trimmedContent.starts(with: "https://") {
            return .link
        }
        
        // 2. 检测其他 URL 协议
        let urlSchemes = ["ftp://", "mailto:", "tel:", "sms:"]
        if urlSchemes.contains(where: { trimmedContent.starts(with: $0) }) {
            return .link
        }
        
        // 3. 检测 www. 开头的 URL（需要包含点号，且不包含空格）
        if trimmedContent.starts(with: "www.") && trimmedContent.contains(".") && !trimmedContent.contains(" ") {
            // 验证是否包含有效的域名结构（至少包含一个点号分隔的域名）
            let parts = trimmedContent.dropFirst(4).split(separator: ".")
            if parts.count >= 2 && parts.allSatisfy({ !$0.isEmpty }) {
                // 进一步验证：不能是纯数字（避免误判 IP 地址）
                let firstPart = String(parts[0])
                if !firstPart.allSatisfy({ $0.isNumber }) {
                    return .link
                }
            }
        }
        
        // 4. 使用 URL 检测器验证（如果已经有 scheme 和 host）
        if let url = URL(string: trimmedContent), url.scheme != nil && url.host != nil {
            // 排除 file:// 协议（这些应该是文件类型）
            if url.scheme?.lowercased() != "file" {
                return .link
            }
        }
        
        // 5. 检测颜色代码（必须在链接检测之后）
        if trimmedContent.starts(with: "#") && trimmedContent.count == 7 {
            // 验证是否为有效的十六进制颜色代码
            let hexString = String(trimmedContent.dropFirst())
            if hexString.allSatisfy({ $0.isHexDigit }) {
                return .color
            }
        }

        // 6. 检测代码 (简单判断：包含特定关键字)
        let codeKeywords = ["func ", "class ", "import ", "let ", "var ", "def ", "function "]
        if codeKeywords.contains(where: { content.contains($0) }) {
            return .code
        }

        return .text
    }

    /// 查找已存在的项目
    private func findExistingItem(hash: String) -> ClipboardItem? {
        // 若还没有持久化上下文，返回 nil
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.contentHash == hash }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            print("❌ 查询已存在项目失败: \(error)")
            return nil
        }
    }

    /// 更新项目时间戳，将其移到第一位
    func updateItemTimestamp(_ item: ClipboardItem) {
        guard let context = modelContext else {
            print("❌ ModelContext 未设置，无法更新")
            return
        }

        // 检查是否是第一位的项目
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: .reverse)]
        )

        do {
            let allItems = try context.fetch(descriptor)
            let isFirstItem = allItems.first?.id == item.id

            // 更新创建时间为当前时间
            item.createdAt = Date()

            try context.save()

            // 如果不是第一位，才需要刷新 UI（移动位置）
            if !isFirstItem {
                // 延迟发送通知，确保 SwiftData 的变化已经传播
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NewClipboardItemAdded"),
                        object: nil,
                        userInfo: ["item": item]
                    )
                }
            } else {
                // 即使是第一位，也需要发送一个轻量级的通知来更新时间显示
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UpdateTimeOnly"),
                        object: nil,
                        userInfo: ["item": item]
                    )
                }
            }
        } catch {
            print("❌ 更新项目时间失败: \(error.localizedDescription)")
        }
    }

    /// 保存项目到数据库
    private func saveItem(_ item: ClipboardItem) {
        guard let context = modelContext else {
            print("❌ ModelContext 未设置，无法保存")
            return
        }

        // 已经在主线程上（checkPasteboard 确保了这一点）
        context.insert(item)
        // 记录最近一次保存的哈希，防止在 ModelContext 尚未可用时重复写入
        self.lastSavedHash = item.contentHash

        do {
            try context.save()

            // 延迟发送通知，确保 SwiftData 的变化已经传播
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NewClipboardItemAdded"),
                    object: nil,
                    userInfo: ["item": item]
                )
            }
        } catch {
            print("❌ 保存失败: \(error.localizedDescription)")
        }
    }

    /// 提取应用主题色（从图标中提取）
    private func extractThemeColor(for app: NSRunningApplication) -> String {
        // 尝试从 App 图标提取主色调
        if let bundleID = app.bundleIdentifier,
           !bundleID.isEmpty,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            if let color = getDominantColorFromIcon(icon) {
                return color.toHexString()
            }
        }

        // 回退到默认颜色
        return "#666666"
    }

    /// 从图标提取主色调（根据用户选择的算法）
    private func getDominantColorFromIcon(_ nsImage: NSImage) -> NSColor? {
        // 获取用户选择的算法
        let algorithmRaw = UserDefaults.standard.string(forKey: "colorSamplingAlgorithm") ?? ColorSamplingAlgorithm.edgePriority.rawValue
        let algorithm = ColorSamplingAlgorithm(rawValue: algorithmRaw) ?? .edgePriority
        
        switch algorithm {
        case .edgePriority:
            return getDominantColorEdgePriority(nsImage)
        case .centerPriority:
            return getDominantColorCenterPriority(nsImage)
        case .average:
            return getDominantColorAverage(nsImage)
        case .saturationPriority:
            return getDominantColorSaturationPriority(nsImage)
        }
    }
    
    /// 边缘优先检测
    private func getDominantColorEdgePriority(_ nsImage: NSImage) -> NSColor? {
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh

        // 使用字典统计颜色，包含加权分数
        struct ColorEntry {
            var count: Int
            var color: NSColor
            var totalScore: Double  // 加权总分
            var rSum: Double
            var gSum: Double
            var bSum: Double
        }
        
        var colorMap: [String: ColorEntry] = [:]

        // 采样步长，平衡性能和精度
        let step = max(1, min(width, height) / 40)
        
        // 计算中心点和边缘区域
        let centerX = Double(width) / 2.0
        let centerY = Double(height) / 2.0
        let maxDistance = sqrt(centerX * centerX + centerY * centerY)

        for x in stride(from: 0, to: width, by: step) {
            for y in stride(from: 0, to: height, by: step) {
                guard let color = bitmap.colorAt(x: x, y: y) else { continue }
                
                // 转换为 sRGB 色彩空间以确保准确性
                guard let rgbColor = color.usingColorSpace(.sRGB) else { continue }

                let alpha = rgbColor.alphaComponent
                
                // 跳过透明像素
                if alpha < 0.6 {
                    continue
                }

                let r = rgbColor.redComponent
                let g = rgbColor.greenComponent
                let b = rgbColor.blueComponent
                
                // 计算亮度和饱和度
                let brightness = (r + g + b) / 3.0
                let maxComponent = max(r, g, b)
                let minComponent = min(r, g, b)
                let saturation = maxComponent > 0 ? (maxComponent - minComponent) / maxComponent : 0
                
                // 跳过过于极端的值
                if brightness < 0.1 || brightness > 0.95 {
                    continue
                }
                
                // 计算位置权重：边缘优先检测（使用平方函数增强边缘权重）
                let dx = Double(x) - centerX
                let dy = Double(y) - centerY
                let distance = sqrt(dx * dx + dy * dy)
                let normalizedDistance = distance / maxDistance  // 0.0 (中心) 到 1.0 (边缘)
                
                // 定义边缘区域：距离中心超过 60% 的区域
                let edgeThreshold = maxDistance * 0.6
                
                // 边缘优先权重：使用平方函数，边缘区域权重显著更高
                // 中心区域权重 1.0-1.5，边缘区域权重 2.5-5.0
                let edgeWeight: Double
                if distance > edgeThreshold {
                    // 边缘区域：使用平方函数，权重 2.5-5.0
                    let edgeRatio = (distance - edgeThreshold) / (maxDistance - edgeThreshold)
                    edgeWeight = 2.5 + pow(edgeRatio, 2) * 2.5  // 2.5-5.0
                } else {
                    // 中心区域：权重较低，但不会完全忽略
                    let centerRatio = distance / edgeThreshold
                    edgeWeight = 1.0 + centerRatio * 0.5  // 1.0-1.5
                }
                
                // 计算饱和度权重：更鲜艳的颜色权重更高
                let saturationWeight = 0.5 + saturation * 0.5  // 0.5-1.0
                
                // 计算亮度权重：避免过暗或过亮（偏好中等亮度）
                let brightnessWeight = 1.0 - abs(brightness - 0.5) * 1.5  // 0.25-1.0
                
                // 综合权重：边缘权重占主导地位
                let weight = edgeWeight * saturationWeight * max(0.3, brightnessWeight)
                
                // 降低颜色精度以聚合相似颜色（使用 LAB 色彩空间的近似）
                // 简化版：在 RGB 空间中使用更精细的量化
                let quantizedR = Int((r * 20).rounded())  // 0-20，比之前的 0-15 更精细
                let quantizedG = Int((g * 20).rounded())
                let quantizedB = Int((b * 20).rounded())
                let key = "\(quantizedR)-\(quantizedG)-\(quantizedB)"

                if var entry = colorMap[key] {
                    entry.count += 1
                    entry.totalScore += weight
                    // 累积颜色值用于后续平均
                    entry.rSum += r * weight
                    entry.gSum += g * weight
                    entry.bSum += b * weight
                    colorMap[key] = entry
                } else {
                    colorMap[key] = ColorEntry(
                        count: 1,
                        color: rgbColor,
                        totalScore: weight,
                        rSum: r * weight,
                        gSum: g * weight,
                        bSum: b * weight
                    )
                }
            }
        }

        // 找出加权分数最高的颜色
        guard let dominantEntry = colorMap.max(by: { $0.value.totalScore < $1.value.totalScore }) else {
            return nil
        }
        
        // 使用加权平均计算最终颜色（更准确）
        let entry = dominantEntry.value
        let avgR = entry.rSum / entry.totalScore
        let avgG = entry.gSum / entry.totalScore
        let avgB = entry.bSum / entry.totalScore
        
        return NSColor(srgbRed: avgR, green: avgG, blue: avgB, alpha: 1.0)
    }
    
    /// 中心优先检测
    private func getDominantColorCenterPriority(_ nsImage: NSImage) -> NSColor? {
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh

        struct ColorEntry {
            var count: Int
            var totalScore: Double
            var rSum: Double
            var gSum: Double
            var bSum: Double
        }
        
        var colorMap: [String: ColorEntry] = [:]
        let step = max(1, min(width, height) / 40)
        let centerX = Double(width) / 2.0
        let centerY = Double(height) / 2.0
        let maxDistance = sqrt(centerX * centerX + centerY * centerY)
        let centerThreshold = maxDistance * 0.4  // 中心区域：距离中心40%以内

        for x in stride(from: 0, to: width, by: step) {
            for y in stride(from: 0, to: height, by: step) {
                guard let color = bitmap.colorAt(x: x, y: y),
                      let rgbColor = color.usingColorSpace(.sRGB) else { continue }

                if rgbColor.alphaComponent < 0.6 { continue }

                let r = rgbColor.redComponent
                let g = rgbColor.greenComponent
                let b = rgbColor.blueComponent
                let brightness = (r + g + b) / 3.0
                
                if brightness < 0.1 || brightness > 0.95 { continue }

                let dx = Double(x) - centerX
                let dy = Double(y) - centerY
                let distance = sqrt(dx * dx + dy * dy)
                
                // 中心优先权重：中心区域权重高，边缘区域权重低
                let centerWeight: Double
                if distance < centerThreshold {
                    let centerRatio = distance / centerThreshold
                    centerWeight = 3.0 - centerRatio * 2.0  // 3.0-1.0
                } else {
                    let edgeRatio = (distance - centerThreshold) / (maxDistance - centerThreshold)
                    centerWeight = 1.0 - edgeRatio * 0.5  // 1.0-0.5
                }
                
                let maxComponent = max(r, g, b)
                let minComponent = min(r, g, b)
                let saturation = maxComponent > 0 ? (maxComponent - minComponent) / maxComponent : 0
                let saturationWeight = 0.5 + saturation * 0.5
                let brightnessWeight = 1.0 - abs(brightness - 0.5) * 1.5
                
                let weight = centerWeight * saturationWeight * max(0.3, brightnessWeight)
                
                let quantizedR = Int((r * 20).rounded())
                let quantizedG = Int((g * 20).rounded())
                let quantizedB = Int((b * 20).rounded())
                let key = "\(quantizedR)-\(quantizedG)-\(quantizedB)"

                if var entry = colorMap[key] {
                    entry.count += 1
                    entry.totalScore += weight
                    entry.rSum += r * weight
                    entry.gSum += g * weight
                    entry.bSum += b * weight
                    colorMap[key] = entry
                } else {
                    colorMap[key] = ColorEntry(
                        count: 1,
                        totalScore: weight,
                        rSum: r * weight,
                        gSum: g * weight,
                        bSum: b * weight
                    )
                }
            }
        }

        guard let dominantEntry = colorMap.max(by: { $0.value.totalScore < $1.value.totalScore }) else {
            return nil
        }
        
        let entry = dominantEntry.value
        let avgR = entry.rSum / entry.totalScore
        let avgG = entry.gSum / entry.totalScore
        let avgB = entry.bSum / entry.totalScore
        
        return NSColor(srgbRed: avgR, green: avgG, blue: avgB, alpha: 1.0)
    }
    
    /// 平均采样
    private func getDominantColorAverage(_ nsImage: NSImage) -> NSColor? {
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh

        struct ColorEntry {
            var count: Int
            var rSum: Double
            var gSum: Double
            var bSum: Double
        }
        
        var colorMap: [String: ColorEntry] = [:]
        let step = max(1, min(width, height) / 40)

        for x in stride(from: 0, to: width, by: step) {
            for y in stride(from: 0, to: height, by: step) {
                guard let color = bitmap.colorAt(x: x, y: y),
                      let rgbColor = color.usingColorSpace(.sRGB) else { continue }

                if rgbColor.alphaComponent < 0.6 { continue }

                let r = rgbColor.redComponent
                let g = rgbColor.greenComponent
                let b = rgbColor.blueComponent
                let brightness = (r + g + b) / 3.0
                
                if brightness < 0.1 || brightness > 0.95 { continue }

                // 平均采样：所有像素权重相同
                let quantizedR = Int((r * 20).rounded())
                let quantizedG = Int((g * 20).rounded())
                let quantizedB = Int((b * 20).rounded())
                let key = "\(quantizedR)-\(quantizedG)-\(quantizedB)"

                if var entry = colorMap[key] {
                    entry.count += 1
                    entry.rSum += r
                    entry.gSum += g
                    entry.bSum += b
                    colorMap[key] = entry
                } else {
                    colorMap[key] = ColorEntry(
                        count: 1,
                        rSum: r,
                        gSum: g,
                        bSum: b
                    )
                }
            }
        }

        // 找出出现次数最多的颜色
        guard let dominantEntry = colorMap.max(by: { $0.value.count < $1.value.count }) else {
            return nil
        }
        
        let entry = dominantEntry.value
        let avgR = entry.rSum / Double(entry.count)
        let avgG = entry.gSum / Double(entry.count)
        let avgB = entry.bSum / Double(entry.count)
        
        return NSColor(srgbRed: avgR, green: avgG, blue: avgB, alpha: 1.0)
    }
    
    /// 饱和度优先检测
    private func getDominantColorSaturationPriority(_ nsImage: NSImage) -> NSColor? {
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh

        struct ColorEntry {
            var count: Int
            var totalScore: Double
            var rSum: Double
            var gSum: Double
            var bSum: Double
        }
        
        var colorMap: [String: ColorEntry] = [:]
        let step = max(1, min(width, height) / 40)

        for x in stride(from: 0, to: width, by: step) {
            for y in stride(from: 0, to: height, by: step) {
                guard let color = bitmap.colorAt(x: x, y: y),
                      let rgbColor = color.usingColorSpace(.sRGB) else { continue }

                if rgbColor.alphaComponent < 0.6 { continue }

                let r = rgbColor.redComponent
                let g = rgbColor.greenComponent
                let b = rgbColor.blueComponent
                let brightness = (r + g + b) / 3.0
                
                if brightness < 0.1 || brightness > 0.95 { continue }

                let maxComponent = max(r, g, b)
                let minComponent = min(r, g, b)
                let saturation = maxComponent > 0 ? (maxComponent - minComponent) / maxComponent : 0
                
                // 饱和度优先：饱和度越高，权重越高
                let saturationWeight = 0.2 + saturation * 2.8  // 0.2-3.0
                let brightnessWeight = 1.0 - abs(brightness - 0.5) * 1.5
                
                let weight = saturationWeight * max(0.3, brightnessWeight)
                
                let quantizedR = Int((r * 20).rounded())
                let quantizedG = Int((g * 20).rounded())
                let quantizedB = Int((b * 20).rounded())
                let key = "\(quantizedR)-\(quantizedG)-\(quantizedB)"

                if var entry = colorMap[key] {
                    entry.count += 1
                    entry.totalScore += weight
                    entry.rSum += r * weight
                    entry.gSum += g * weight
                    entry.bSum += b * weight
                    colorMap[key] = entry
                } else {
                    colorMap[key] = ColorEntry(
                        count: 1,
                        totalScore: weight,
                        rSum: r * weight,
                        gSum: g * weight,
                        bSum: b * weight
                    )
                }
            }
        }

        guard let dominantEntry = colorMap.max(by: { $0.value.totalScore < $1.value.totalScore }) else {
            return nil
        }
        
        let entry = dominantEntry.value
        let avgR = entry.rSum / entry.totalScore
        let avgG = entry.gSum / entry.totalScore
        let avgB = entry.bSum / entry.totalScore
        
        return NSColor(srgbRed: avgR, green: avgG, blue: avgB, alpha: 1.0)
    }

    /// 异步获取链接元数据并更新item
    private func fetchLinkMetadata(for item: ClipboardItem, url: URL) {
        // 异步获取元数据，不应该阻塞后续的剪贴板处理
        LinkMetadataFetcher.shared.fetchMetadata(for: url) { [weak self] title, faviconData in
            guard let self = self, let context = self.modelContext else {
                return
            }

            // 在主线程更新数据
            DispatchQueue.main.async {
                do {
                    // 尝试访问 item 的属性来验证它是否仍然有效
                    _ = item.id
                    _ = item.content
                    
                    item.linkTitle = title
                    item.linkFaviconData = faviconData

                    try context.save()
                    
                    // 发送通知以刷新卡片显示
                    NotificationCenter.default.post(
                        name: NSNotification.Name("LinkMetadataUpdated"),
                        object: nil,
                        userInfo: ["itemId": item.id]
                    )
                } catch {
                    print("❌ 保存链接元数据失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 格式化文件大小
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - NSColor Extension

extension NSColor {
    /// 将 NSColor 转换为十六进制字符串
    func toHexString() -> String {
        guard let rgbColor = self.usingColorSpace(.sRGB) else {
            return "#666666"
        }

        let red = Int(rgbColor.redComponent * 255)
        let green = Int(rgbColor.greenComponent * 255)
        let blue = Int(rgbColor.blueComponent * 255)

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
