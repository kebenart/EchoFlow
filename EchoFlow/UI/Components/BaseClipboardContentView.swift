//
//  BaseClipboardContentView.swift
//  EchoFlow
//
//  Created by keben on 2025/12/01.
//

import SwiftUI
import AppKit
import CryptoKit

// MARK: - Layout Configuration

/// 布局模式配置
enum ClipboardLayoutMode {
    /// 卡片布局（垂直模式）- 240x240 正方形卡片
    case card
    /// 行布局（窗口模式）- 横向紧凑行
    case row
}

/// 布局配置参数
struct ClipboardLayoutConfig {
    let mode: ClipboardLayoutMode
    
    // 尺寸配置
    let width: CGFloat?
    let height: CGFloat?
    let cornerRadius: CGFloat
    
    // 图标配置
    let iconSize: CGFloat
    let showAppIcon: Bool
    
    // 内容配置
    let contentLineLimit: Int
    let showHeader: Bool
    let headerHeight: CGFloat
    
    // 效果配置
    let enable3DEffect: Bool
    let maxRotationAngle: CGFloat
    let hoverScale: CGFloat
    let shadowRadius: CGFloat
    let focusedShadowRadius: CGFloat
    
    // 徽章配置
    let showShortcutBadge: Bool
    let showLockBadge: Bool
    
    // 缩略图配置
    let thumbnailSize: CGSize
    
    /// 卡片模式预设配置
    static var card: ClipboardLayoutConfig {
        ClipboardLayoutConfig(
            mode: .card,
            width: 240,
            height: 240,
            cornerRadius: 12,
            iconSize: 44,
            showAppIcon: true,
            contentLineLimit: 8,
            showHeader: true,
            headerHeight: 54,
            enable3DEffect: true,
            maxRotationAngle: 8.0,
            hoverScale: 1.03,
            shadowRadius: 8,
            focusedShadowRadius: 12,
            showShortcutBadge: true,
            showLockBadge: true,
            thumbnailSize: CGSize(width: 90, height: 90)
        )
    }
    
    /// 行模式预设配置
    static var row: ClipboardLayoutConfig {
        ClipboardLayoutConfig(
            mode: .row,
            width: nil,  // 自适应宽度
            height: 80,
            cornerRadius: 10,
            iconSize: 36,
            showAppIcon: true,
            contentLineLimit: 2,
            showHeader: false,
            headerHeight: 0,
            enable3DEffect: true,
            maxRotationAngle: 5.0,
            hoverScale: 1.02,
            shadowRadius: 4,
            focusedShadowRadius: 6,
            showShortcutBadge: true,
            showLockBadge: true,
            thumbnailSize: CGSize(width: 40, height: 40)
        )
    }
}

// MARK: - Base Clipboard Content View

/// 剪贴板内容基础视图 - 支持卡片和行两种布局模式
struct BaseClipboardContentView: View, Equatable {
    let item: ClipboardItem
    let index: Int
    let isFocused: Bool
    let timeRefreshTrigger: Int
    let config: ClipboardLayoutConfig
    let onTap: () -> Void
    let onDoubleTap: (() -> Void)?
    let onDelete: () -> Void
    
    static func == (lhs: BaseClipboardContentView, rhs: BaseClipboardContentView) -> Bool {
        return lhs.item.id == rhs.item.id &&
               lhs.index == rhs.index &&
               lhs.isFocused == rhs.isFocused &&
               lhs.timeRefreshTrigger == rhs.timeRefreshTrigger &&
               lhs.config.mode == rhs.config.mode
    }
    
    @State private var isDragging: Bool = false
    @State private var isHovered: Bool = false
    @State private var mouseLocation: CGPoint = .zero
    @State private var richTextBackgroundColor: Color?
    @Environment(\.modelContext) private var modelContext
    @AppStorage("enableCoolMode") private var enableCoolMode: Bool = true
    
    var body: some View {
        Button(action: {
            onTap()
            if config.mode == .row, let doubleTap = onDoubleTap {
                // 行模式下单击即复制（保持与原 WindowClipboardContentView 一致）
            }
        }) {
            contentLayout
        }
        .buttonStyle(BaseInstantButtonStyle())
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    onDoubleTap?()
                }
        )
        .onDrag {
            isDragging = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isDragging = false }
            return BaseDragItemProvider(item: item).itemProvider
        } preview: {
            dragPreviewView
        }
    }
    
    // MARK: - Content Layout
    
    @ViewBuilder
    private var contentLayout: some View {
        Group {
            switch config.mode {
            case .card:
                cardLayout
            case .row:
                rowLayout
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius))
        .background(backgroundView)
        .overlay(selectionBorder)
        .opacity(isDragging ? 0.5 : 1.0)
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .contextMenu {
            BaseCardContextMenu(item: item, onDelete: onDelete, onToggleLock: toggleLock)
        }
        .overlay(alignment: .bottomTrailing) {
            if config.showShortcutBadge && index < 9 {
                BaseShortcutBadge(index: index, isCompact: config.mode == .row)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if config.showLockBadge && item.isLocked {
                BaseLockedBadge(isCompact: config.mode == .row)
            }
        }
        .modifier(HoverEffect3D(
            isEnabled: enableCoolMode && config.enable3DEffect,
            isHovered: $isHovered,
            mouseLocation: $mouseLocation,
            maxRotationAngle: config.maxRotationAngle,
            hoverScale: config.hoverScale
        ))
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    // MARK: - Card Layout (垂直模式)
    
    @ViewBuilder
    private var cardLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部视图
            if config.showHeader {
                BaseCardHeaderView(
                    item: item,
                    iconSize: config.iconSize,
                    headerHeight: config.headerHeight,
                    timeRefreshTrigger: timeRefreshTrigger
                )
                .background(Color(hex: item.themeColorHex) ?? Color.blue)
            }
            
            // 内容视图
            BaseCardBodyView(
                item: item,
                lineLimit: config.contentLineLimit,
                thumbnailSize: config.thumbnailSize,
                onBackgroundColorChanged: { color in
                    richTextBackgroundColor = color
                }
            )
            .background(richTextBackgroundColor ?? Color.white)
        }
        .frame(width: config.width, height: config.height)
    }
    
    // MARK: - Row Layout (窗口模式)
    
    @ViewBuilder
    private var rowLayout: some View {
        HStack(spacing: 12) {
            // 左侧图标
            leftIconView
                .frame(width: config.iconSize, height: config.iconSize)
            
            // 中间内容
            VStack(alignment: .leading, spacing: 4) {
                // 内容预览
                BaseRowContentView(
                    item: item,
                    lineLimit: config.contentLineLimit,
                    thumbnailSize: config.thumbnailSize,
                    onBackgroundColorChanged: { color in
                        richTextBackgroundColor = color
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 时间标签
                Text(item.relativeTimeString)
                    .font(.system(size: 10))
                    .foregroundColor(adaptiveSecondaryTextColor)
                    .id("time-\(item.id)-\(timeRefreshTrigger)")
            }
            
            // 右侧锁定图标（已由 overlay 处理，这里可以放其他内容）
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(height: config.height)
        .frame(maxWidth: .infinity)
        .background(richTextBackgroundColor ?? Color.white)
    }
    
    // MARK: - Left Icon View
    
    @ViewBuilder
    private var leftIconView: some View {
        switch item.type {
        case .image:
            if let imageData = item.imageData {
                CachedThumbnailView(imageData: imageData, targetSize: CGSize(width: config.iconSize, height: config.iconSize))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                CachedAppIconView(bundleID: item.sourceAppBundleID)
            }
        case .file:
            if let filePath = item.firstFilePath {
                CachedFileIconView(path: filePath)
            } else {
                CachedAppIconView(bundleID: item.sourceAppBundleID)
            }
        case .link:
            if let faviconData = item.linkFaviconData {
                CachedThumbnailView(imageData: faviconData, targetSize: CGSize(width: config.iconSize, height: config.iconSize))
            } else {
                CachedAppIconView(bundleID: item.sourceAppBundleID)
            }
        default:
            CachedAppIconView(bundleID: item.sourceAppBundleID)
        }
    }
    
    // MARK: - Background View
    
    @ViewBuilder
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: config.cornerRadius)
            .fill(backgroundColor)
            .shadow(
                color: shadowColor,
                radius: isFocused ? config.focusedShadowRadius : config.shadowRadius,
                x: 0,
                y: isFocused ? 6 : 4
            )
    }
    
    private var backgroundColor: Color {
        if let bgColor = richTextBackgroundColor {
            return isFocused ? bgColor.lighter(by: 0.08) : bgColor
        }
        return isFocused ? Color.blue.opacity(0.08) : Color.white.opacity(0.96)
    }
    
    private var shadowColor: Color {
        isFocused ? Color.blue.opacity(0.2) : Color.black.opacity(0.08)
    }
    
    // MARK: - Selection Border
    
    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: config.cornerRadius)
            .strokeBorder(
                isFocused ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color.black.opacity(0.1),
                lineWidth: isFocused ? 3 : 1
            )
            .animation(nil, value: isFocused)
    }
    
    // MARK: - Adaptive Text Color
    
    private var adaptiveSecondaryTextColor: Color {
        guard let bgColor = richTextBackgroundColor else {
            return Color(NSColor.darkGray)
        }
        return contrastColor(for: bgColor).opacity(0.7)
    }
    
    private func contrastColor(for backgroundColor: Color) -> Color {
        let nsColor = NSColor(backgroundColor)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            return .primary
        }
        let luminance = 0.2126 * rgbColor.redComponent + 0.7152 * rgbColor.greenComponent + 0.0722 * rgbColor.blueComponent
        return luminance > 0.5 ? Color.black : Color.white
    }
    
    // MARK: - Drag Preview
    
    @ViewBuilder
    private var dragPreviewView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部 - 与内容区域同宽
            HStack(spacing: 8) {
                Image(systemName: item.type == .text ? "text.alignleft" :
                      item.type == .code ? "chevron.left.forwardslash.chevron.right" :
                      item.type == .image ? "photo" :
                      item.type == .file ? "doc" :
                      item.type == .link ? "link" : "paintpalette")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Text(item.type.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 220, height: 36)
            .background(Color(hex: item.themeColorHex) ?? Color.blue)
            
            // 内容区域
            Text(item.contentPreview)
                .font(.system(size: 11))
                .foregroundColor(Color(NSColor.black))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .frame(width: 220, height: 64)
                .background(Color.white)
        }
        .frame(width: 220)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Actions
    
    private func toggleLock() {
        item.isLocked.toggle()
        do {
            try modelContext.save()
        } catch {
            print("❌ 切换锁定状态失败: \(error)")
        }
    }
}

// MARK: - Card Header View

private struct BaseCardHeaderView: View {
    let item: ClipboardItem
    let iconSize: CGFloat
    let headerHeight: CGFloat
    let timeRefreshTrigger: Int
    
    var body: some View {
        HStack(spacing: 8) {
            CachedAppIconView(bundleID: item.sourceAppBundleID)
                .frame(width: iconSize, height: iconSize)
            
            Spacer(minLength: 0)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.type.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(item.relativeTimeString)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.75))
                    .id("time-\(item.id)-\(timeRefreshTrigger)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: headerHeight)
    }
}

// MARK: - Card Body View (for Card Layout)

private struct BaseCardBodyView: View {
    let item: ClipboardItem
    let lineLimit: Int
    let thumbnailSize: CGSize
    let onBackgroundColorChanged: ((Color?) -> Void)?
    
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
                        onBackgroundColorChanged?(color)
                    }
                )
            case .image:
                BaseImageContentView(item: item, thumbnailSize: thumbnailSize)
            case .link:
                BaseLinkContentView(item: item, thumbnailSize: thumbnailSize)
            case .color:
                BaseColorContentView(item: item)
            case .file:
                BaseFileContentView(item: item, thumbnailSize: thumbnailSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding([.horizontal, .bottom], 12)
        .padding(.top, 8)
        .background(backgroundColor ?? Color.clear)
    }
}

// MARK: - Row Content View (for Row Layout)
// 注意：行布局下左侧已有图标，内容区域不再重复显示图标/缩略图

private struct BaseRowContentView: View {
    let item: ClipboardItem
    let lineLimit: Int
    let thumbnailSize: CGSize
    let onBackgroundColorChanged: ((Color?) -> Void)?
    
    @AppStorage("cardFontName") private var cardFontName: String = "SF Pro Text"
    @AppStorage("cardFontSize") private var cardFontSize: Double = 12.0
    
    private var cardFont: Font {
        let fontSize = CGFloat(cardFontSize)
        if let font = NSFont(name: cardFontName, size: fontSize) {
            return Font(font)
        }
        return .system(size: fontSize, design: .default)
    }
    
    var body: some View {
        switch item.type {
        case .text, .code:
            if let rtfData = item.richTextData {
                BaseRichTextRowPreview(
                    rtfData: rtfData,
                    fontSize: CGFloat(cardFontSize),
                    lineLimit: lineLimit,
                    onBackgroundColorExtracted: onBackgroundColorChanged
                )
            } else {
                Text(item.contentPreview)
                    .font(cardFont)
                    .foregroundColor(Color(NSColor.black))
                    .lineLimit(lineLimit)
                    .truncationMode(.tail)
            }
            
        case .link:
            // 只显示文本，图标已在左侧显示
            Text(item.linkTitle ?? item.content)
                .font(.system(size: CGFloat(cardFontSize - 1)))
                .foregroundColor(.blue)
                .lineLimit(lineLimit)
                .truncationMode(.middle)
            
        case .file:
            // 只显示文件名，图标已在左侧显示
            Text(item.fileName ?? item.contentPreview)
                .font(cardFont)
                .foregroundColor(Color(NSColor.darkGray))
                .lineLimit(lineLimit)
                .truncationMode(.middle)
            
        case .image:
            // 只显示图片信息，缩略图已在左侧显示
            VStack(alignment: .leading, spacing: 2) {
                Text(item.contentPreview)
                    .font(cardFont)
                    .foregroundColor(Color(NSColor.darkGray))
                    .lineLimit(1)
                if let fileSize = item.fileSize {
                    FileSizeText(size: fileSize)
                }
            }
            
        case .color:
            // 颜色类型：左侧显示 App 图标，这里显示颜色块 + 颜色值
            HStack(spacing: 8) {
                if let color = Color(hex: item.content) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                Text(item.content)
                    .font(.system(size: CGFloat(cardFontSize), design: .monospaced))
                    .foregroundColor(Color(NSColor.darkGray))
            }
        }
    }
}

// MARK: - Rich Text Row Preview

private struct BaseRichTextRowPreview: View {
    let rtfData: Data
    let fontSize: CGFloat
    let lineLimit: Int
    let onBackgroundColorExtracted: ((Color?) -> Void)?
    
    @State private var attributedContent: AttributedString?
    @State private var backgroundColor: Color?
    
    var body: some View {
        Group {
            if let content = attributedContent {
                Text(content)
            } else {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .lineLimit(lineLimit)
        .truncationMode(.tail)
        .task(id: rtfData.sha256Hash) {
            await loadRichText()
        }
        .onChange(of: backgroundColor) { _, newValue in
            onBackgroundColorExtracted?(newValue)
        }
    }
    
    private func loadRichText() async {
        let cacheKey = rtfData.sha256Hash
        let isHTML = detectHTMLFormat(in: rtfData)
        let result = await RichTextCache.shared.load(data: rtfData, key: cacheKey, isHTML: isHTML)
        
        await MainActor.run {
            self.attributedContent = result.attributedString
            self.backgroundColor = result.backgroundColor
            onBackgroundColorExtracted?(result.backgroundColor)
        }
    }
    
    private func detectHTMLFormat(in data: Data) -> Bool {
        guard let str = String(data: data.prefix(500), encoding: .utf8)?.lowercased() else { return false }
        return str.contains("<html") || str.contains("<!doctype") || str.contains("<body") || str.contains("<div") || str.contains("<span")
    }
}

// MARK: - Content Type Views

private struct BaseImageContentView: View {
    let item: ClipboardItem
    let thumbnailSize: CGSize
    @AppStorage("cardFontName") private var cardFontName: String = "SF Pro Text"
    @AppStorage("cardFontSize") private var cardFontSize: Double = 12.0
    
    private var cardContentFont: Font {
        let fontSize = CGFloat(cardFontSize * 0.92)
        if let font = NSFont(name: cardFontName, size: fontSize) {
            return Font(font)
        }
        return .system(size: fontSize, design: .default)
    }
    
    private var imageName: String {
        if item.content.starts(with: "/") {
            return URL(fileURLWithPath: item.content).lastPathComponent
        }
        return "图片"
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if let imageData = item.imageData {
                CachedThumbnailView(imageData: imageData, targetSize: thumbnailSize)
                    .frame(width: thumbnailSize.width, height: thumbnailSize.height)
            } else {
                PlaceholderImage(icon: "photo")
            }
            
            Text(imageName.truncated(maxLength: 30))
                .font(cardContentFont)
                .foregroundColor(Color(NSColor.darkGray))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            if let fileSize = item.fileSize {
                FileSizeText(size: fileSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BaseLinkContentView: View {
    let item: ClipboardItem
    let thumbnailSize: CGSize
    @AppStorage("cardFontName") private var cardFontName: String = "SF Pro Text"
    @AppStorage("cardFontSize") private var cardFontSize: Double = 12.0
    
    private var cardContentFont: Font {
        let fontSize = CGFloat(cardFontSize * 0.75)
        if let font = NSFont(name: cardFontName, size: fontSize) {
            return Font(font)
        }
        return .system(size: fontSize, design: .default)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            if let faviconData = item.linkFaviconData {
                CachedThumbnailView(imageData: faviconData, targetSize: CGSize(width: 32, height: 32))
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            
            if let title = item.linkTitle {
                Text(title.truncated(maxLength: 30))
                    .font(cardContentFont.bold())
                    .foregroundColor(Color(NSColor.black))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            
            Text(item.content.truncated(maxLength: 40))
                .font(cardContentFont)
                .foregroundColor(Color(NSColor.darkGray))
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BaseFileContentView: View {
    let item: ClipboardItem
    let thumbnailSize: CGSize
    @AppStorage("cardFontName") private var cardFontName: String = "SF Pro Text"
    @AppStorage("cardFontSize") private var cardFontSize: Double = 12.0
    
    private var cardContentFont: Font {
        let fontSize = CGFloat(cardFontSize * 0.92)
        if let font = NSFont(name: cardFontName, size: fontSize) {
            return Font(font)
        }
        return .system(size: fontSize, design: .default)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if let filePath = item.firstFilePath {
                CachedFileIconView(path: filePath)
                    .frame(width: thumbnailSize.width, height: thumbnailSize.height)
            } else {
                PlaceholderImage(icon: "doc.fill", color: .orange)
            }
            
            if let fileName = item.fileName {
                Text(fileName.truncated(maxLength: 30))
                    .font(cardContentFont)
                    .foregroundColor(Color(NSColor.black))
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

private struct BaseColorContentView: View {
    let item: ClipboardItem
    @AppStorage("cardFontName") private var cardFontName: String = "SF Pro Text"
    @AppStorage("cardFontSize") private var cardFontSize: Double = 12.0
    
    private var cardContentFont: Font {
        let fontSize = CGFloat(cardFontSize * 0.92)
        return .system(size: fontSize, design: .monospaced)
    }
    
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
                .font(cardContentFont)
                .foregroundColor(Color(NSColor.darkGray))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 3D Hover Effect Modifier

struct HoverEffect3D: ViewModifier {
    let isEnabled: Bool
    @Binding var isHovered: Bool
    @Binding var mouseLocation: CGPoint
    let maxRotationAngle: CGFloat
    let hoverScale: CGFloat
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                rotationAngle,
                axis: rotationAxis,
                perspective: 0.5
            )
            .scaleEffect(isEnabled && isHovered ? hoverScale : 1.0)
            .animation(.easeOut(duration: 0.2), value: isHovered)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    mouseLocation = location
                case .ended:
                    break
                }
            }
    }
    
    private var rotationAngle: Angle {
        guard isEnabled && isHovered else { return .zero }
        let offsetX = mouseLocation.x
        let offsetY = mouseLocation.y
        let angle = sqrt(pow(offsetX, 2) + pow(offsetY, 2)) * maxRotationAngle / 100
        return .degrees(min(angle, maxRotationAngle))
    }
    
    private var rotationAxis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        guard isEnabled && isHovered else { return (0, 0, 0) }
        return (-mouseLocation.y / 100, mouseLocation.x / 100, 0)
    }
}

// MARK: - Shortcut Badge

struct BaseShortcutBadge: View {
    let index: Int
    let isCompact: Bool
    
    var body: some View {
        Text("⌘\(index + 1)")
            .font(.system(size: isCompact ? 9 : 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, isCompact ? 4 : 6)
            .padding(.vertical, isCompact ? 1 : 2)
            .background(Color.black.opacity(0.4))
            .clipShape(Capsule())
            .padding(isCompact ? 4 : 6)
    }
}

// MARK: - Locked Badge

struct BaseLockedBadge: View {
    let isCompact: Bool
    
    var body: some View {
        HStack(spacing: isCompact ? 2 : 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: isCompact ? 8 : 10))
            if !isCompact {
                Text("已锁定")
                    .font(.system(size: 9, weight: .medium))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, isCompact ? 4 : 6)
        .padding(.vertical, isCompact ? 2 : 3)
        .background(Color.orange.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(isCompact ? 4 : 8)
    }
}

// MARK: - Button Style

struct BaseInstantButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .onTapGesture(perform: configuration.trigger)
    }
}

// MARK: - Context Menu

struct BaseCardContextMenu: View {
    let item: ClipboardItem
    let onDelete: () -> Void
    let onToggleLock: () -> Void
    
    var body: some View {
        Group {
            // 复制纯文本
            if item.type == .text || item.type == .code {
                Button("复制纯文本") {
                    copyPlainText()
                }
                Divider()
            }
            
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
                
            case .file, .image:
                let filePath = item.type == .image && item.content.starts(with: "/") ? item.content : item.firstFilePath
                if let path = filePath {
                    Button("复制文件名") {
                        let fileName = URL(fileURLWithPath: path).lastPathComponent
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(fileName, forType: .string)
                    }
                    Button("复制文件地址") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(path, forType: .string)
                    }
                    Button("跳转至文件夹") {
                        let url = URL(fileURLWithPath: path)
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                    }
                    Divider()
                }
                
            default:
                EmptyView()
            }
            
            Button("删除", role: .destructive) {
                if !item.isLocked {
                    onDelete()
                }
            }
            .disabled(item.isLocked)
        }
    }
    
    private func copyPlainText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
    }
}

// MARK: - Drag Item Provider

private class BaseDragItemProvider: NSObject {
    let item: ClipboardItem
    init(item: ClipboardItem) { self.item = item }
    
    var itemProvider: NSItemProvider {
        let provider = NSItemProvider()
        
        switch item.type {
        case .text, .code:
            provider.registerDataRepresentation(forTypeIdentifier: "public.plain-text", visibility: .all) { completion in
                let data = self.item.content.data(using: .utf8) ?? Data()
                completion(data, nil)
                return nil
            }
            if let rtfData = item.richTextData {
                provider.registerDataRepresentation(forTypeIdentifier: "public.rtf", visibility: .all) { completion in
                    completion(rtfData, nil)
                    return nil
                }
            }
            
        case .file:
            let fileURL = URL(fileURLWithPath: item.content)
            if FileManager.default.fileExists(atPath: item.content) {
                provider.registerFileRepresentation(forTypeIdentifier: "public.file-url", fileOptions: [], visibility: .all) { completion in
                    completion(fileURL, false, nil)
                    return nil
                }
                provider.registerDataRepresentation(forTypeIdentifier: "public.plain-text", visibility: .all) { completion in
                    let data = self.item.content.data(using: .utf8) ?? Data()
                    completion(data, nil)
                    return nil
                }
            }
            
        case .image:
            if let imageData = item.imageData {
                provider.registerDataRepresentation(forTypeIdentifier: "public.image", visibility: .all) { completion in
                    completion(imageData, nil)
                    return nil
                }
            }
            
        case .link:
            provider.registerDataRepresentation(forTypeIdentifier: "public.url", visibility: .all) { completion in
                let data = self.item.content.data(using: .utf8) ?? Data()
                completion(data, nil)
                return nil
            }
            provider.registerDataRepresentation(forTypeIdentifier: "public.plain-text", visibility: .all) { completion in
                let data = self.item.content.data(using: .utf8) ?? Data()
                completion(data, nil)
                return nil
            }
            
        case .color:
            provider.registerDataRepresentation(forTypeIdentifier: "public.plain-text", visibility: .all) { completion in
                let data = self.item.content.data(using: .utf8) ?? Data()
                completion(data, nil)
                return nil
            }
        }
        
        return provider
    }
}

// MARK: - Color Extension

extension Color {
    func lighter(by amount: CGFloat = 0.1) -> Color {
        let nsColor = NSColor(self)
        guard let rgb = nsColor.usingColorSpace(.deviceRGB) else { return self }
        let r = min(rgb.redComponent + amount, 1.0)
        let g = min(rgb.greenComponent + amount, 1.0)
        let b = min(rgb.blueComponent + amount, 1.0)
        return Color(NSColor(calibratedRed: r, green: g, blue: b, alpha: rgb.alphaComponent))
    }
}

// MARK: - String Extension

extension String {
    func truncated(maxLength: Int) -> String {
        guard count > maxLength else { return self }
        return String(prefix(maxLength)) + "..."
    }
}
