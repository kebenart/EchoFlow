//
//  SoftwareProfileCard.swift
//  Clipboard
//
//  Created by crown on 2025/11/30.
//

import SwiftUI
import AppKit

// MARK: - 3D 软件资料卡片

struct SoftwareProfileCard: View {
    // 数据模型
    let appName: String
    let appDesc: String
    let iconImage: NSImage
    let statusText: String
    let statusColor: Color

    // 交互状态
    @State private var mouseLocation: CGPoint = .zero
    @State private var isHovering: Bool = false
    
    // 配置常量
    private let cardWidth: CGFloat = 440
    private let cardHeight: CGFloat = 130
    private let maxRotationAngle: Double = 10.0 // 最大倾斜角度

    var body: some View {
        ZStack {
            // 1. 鼠标追踪层 (最底层，负责捕获坐标)
            MouseTrackingView(mouseLocation: $mouseLocation, isHovering: $isHovering)
                .frame(width: cardWidth, height: cardHeight)
            
            // 2. 卡片主体
            cardContent
                .frame(width: cardWidth, height: cardHeight)
                // 3D 旋转核心
                .rotation3DEffect(
                    .degrees(isHovering ? rotationX : 0),
                    axis: (x: 1, y: 0, z: 0) // 绕 X 轴旋转 (上下倾斜)
                )
                .rotation3DEffect(
                    .degrees(isHovering ? rotationY : 0),
                    axis: (x: 0, y: 1, z: 0) // 绕 Y 轴旋转 (左右倾斜)
                )
                // 悬浮放大效果
                .scaleEffect(isHovering ? 1.02 : 1.0)
                // 动画曲线：鼠标移入时灵敏，移出时弹簧回弹
                .animation(isHovering ? .linear(duration: 0.1) : .spring(response: 0.5, dampingFraction: 0.6), value: mouseLocation)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isHovering)
        }
    }

    // MARK: - 卡片内容构建

    private var cardContent: some View {
        ZStack {
            // --- A. 背景与光效层 ---
            GeometryReader { _ in
                // 1. 环境光晕 (Ambient Glow)
                // 原理：使用图标图片本身，极度放大并模糊，作为背景
                Image(nsImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    // 关键滤镜链
                    .blur(radius: 60) // 极度模糊
                    .opacity(0.5)     // 降低不透明度
                    .saturation(1.8)  // 增加饱和度，让光更艳丽
                    // 稍微放大避免模糊白边，并向左偏移让重心在图标侧
                    .scaleEffect(1.5)
                    .offset(x: -50)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            // 2. 遮罩层 (Overlay Gradient)
            // 保证右侧文字区域有足够的对比度
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.1),
                            Color.black.opacity(0.6)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // 3. 动态反光层 (Shine Layer)
            // 跟随鼠标移动的径向渐变
            if isHovering {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    // 将光圈中心定位到鼠标位置
                    .position(x: mouseLocation.x, y: mouseLocation.y)
                    // 混合模式，让光看起来像叠加的亮度
                    .blendMode(.overlay)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            
            // 细微边框光泽
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)

            // --- B. 内容层 (悬浮视差) ---
            HStack(spacing: 20) {
                // 图标容器
                Image(nsImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 10)
                    // 视差位移：图标凸起更多
                    .offset(x: isHovering ? parallaxOffset(factor: 10).x : 0,
                            y: isHovering ? parallaxOffset(factor: 10).y : 0)

                // 文本信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(appName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    
                    Text(appDesc)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // 状态标签
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                            .shadow(color: statusColor.opacity(0.8), radius: 4, x: 0, y: 0)
                        
                        Text(statusText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // 视差位移：文字凸起较少，形成层次感
                .offset(x: isHovering ? parallaxOffset(factor: 5).x : 0,
                        y: isHovering ? parallaxOffset(factor: 5).y : 0)
            }
            .padding(.horizontal, 24)
        }
        .background(Color(nsColor: NSColor(white: 0.11, alpha: 1.0))) // 兜底背景色
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10) // 外部大阴影
    }

    // MARK: - 计算逻辑

    // 计算绕 X 轴旋转角度 (由鼠标 Y 坐标决定)
    private var rotationX: Double {
        let centerY = cardHeight / 2
        // 鼠标在上方 -> 向上仰 (负角度)
        // 鼠标在下方 -> 向下俯 (正角度)
        let percent = (mouseLocation.y - centerY) / centerY
        return percent * -maxRotationAngle // 取反以符合自然物理直觉
    }

    // 计算绕 Y 轴旋转角度 (由鼠标 X 坐标决定)
    private var rotationY: Double {
        let centerX = cardWidth / 2
        // 鼠标在左方 -> 向左倾 (负角度)
        // 鼠标在右方 -> 向右倾 (正角度)
        let percent = (mouseLocation.x - centerX) / centerX
        return percent * maxRotationAngle
    }
    
    // 计算视差位移
    private func parallaxOffset(factor: CGFloat) -> CGPoint {
        let centerX = cardWidth / 2
        let centerY = cardHeight / 2
        let x = (mouseLocation.x - centerX) / centerX * factor
        let y = (mouseLocation.y - centerY) / centerY * factor
        return CGPoint(x: x, y: y)
    }
}

// MARK: - 鼠标追踪器 (AppKit 桥接)

/// 一个不可见的视图，用于实时捕获鼠标在视图内的坐标
struct MouseTrackingView: NSViewRepresentable {
    @Binding var mouseLocation: CGPoint
    @Binding var isHovering: Bool

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onMouseUpdate = { location in
            self.mouseLocation = location
        }
        view.onHoverChange = { hovering in
            withAnimation {
                self.isHovering = hovering
            }
        }
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {}

    class TrackingView: NSView {
        var onMouseUpdate: ((CGPoint) -> Void)?
        var onHoverChange: ((Bool) -> Void)?
        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea = trackingArea {
                removeTrackingArea(trackingArea)
            }
            
            // 关键：启用 mouseMoved 和 activeInKeyWindow
            let options: NSTrackingArea.Options = [
                .mouseEnteredAndExited,
                .mouseMoved,
                .activeInKeyWindow,
                .inVisibleRect
            ]
            
            trackingArea = NSTrackingArea(
                rect: bounds,
                options: options,
                owner: self,
                userInfo: nil
            )
            addTrackingArea(trackingArea!)
        }

        override func mouseEntered(with event: NSEvent) {
            onHoverChange?(true)
        }

        override func mouseExited(with event: NSEvent) {
            onHoverChange?(false)
        }

        override func mouseMoved(with event: NSEvent) {
            // 将窗口坐标转换为视图局部坐标
            let localPoint = convert(event.locationInWindow, from: nil)
            // AppKit 的 Y 轴是从底部向上的，SwiftUI 是从顶部向下的
            // 但在这里我们主要需要相对中心的偏移量，直接使用转换后的坐标通常即可
            // 如果需要完全对齐 SwiftUI 的左上角原点：
            let flippedPoint = CGPoint(x: localPoint.x, y: bounds.height - localPoint.y)
            onMouseUpdate?(flippedPoint)
        }
    }
}

// MARK: - 预览

struct SoftwareProfileCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // 示例 1: Notion (黑白)
                if let notionIcon = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: nil) {
                    SoftwareProfileCard(
                        appName: "Notion",
                        appDesc: "All-in-one workspace for your notes and tasks.",
                        iconImage: notionIcon, // 实际使用中替换为真实图片
                        statusText: "Synced",
                        statusColor: .green
                    )
                }
                
                // 示例 2: Linear (紫色)
                // 这里为了演示颜色效果，用代码生成一个紫色图标
                let purpleIcon = generateColorIcon(color: .purple)
                SoftwareProfileCard(
                    appName: "Linear",
                    appDesc: "Streamlined issue tracking for software teams.",
                    iconImage: purpleIcon,
                    statusText: "Updating",
                    statusColor: .yellow
                )
            }
        }
        .frame(width: 800, height: 600)
    }
    
    // 辅助：生成纯色图标用于预览
    static func generateColorIcon(color: NSColor) -> NSImage {
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
    }
}