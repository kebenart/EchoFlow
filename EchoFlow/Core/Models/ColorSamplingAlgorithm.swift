//
//  ColorSamplingAlgorithm.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import Foundation

/// 颜色采样算法类型
enum ColorSamplingAlgorithm: String, CaseIterable {
    case edgePriority = "edgePriority"
    case centerPriority = "centerPriority"
    case average = "average"
    case saturationPriority = "saturationPriority"
    
    var displayName: String {
        switch self {
        case .edgePriority:
            return "边缘优先"
        case .centerPriority:
            return "中心优先"
        case .average:
            return "平均采样"
        case .saturationPriority:
            return "饱和度优先"
        }
    }
    
    var description: String {
        switch self {
        case .edgePriority:
            return "优先提取图标边缘的颜色，适合大多数应用图标"
        case .centerPriority:
            return "优先提取图标中心的颜色，适合简单图标"
        case .average:
            return "平均采样所有像素，提取整体主色调"
        case .saturationPriority:
            return "优先提取饱和度高的颜色，适合鲜艳的图标"
        }
    }
}

