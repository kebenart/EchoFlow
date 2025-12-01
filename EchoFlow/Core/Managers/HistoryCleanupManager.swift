//
//  HistoryCleanupManager.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import Foundation
import SwiftData

/// 历史记录清理管理器
@Observable
final class HistoryCleanupManager {
    // MARK: - Singleton
    
    static let shared = HistoryCleanupManager()
    
    // MARK: - Properties
    
    /// 模型上下文
    var modelContext: ModelContext?
    
    /// 清理定时器
    private var cleanupTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        // 启动定时清理任务（每小时检查一次）
        startPeriodicCleanup()
    }
    
    // MARK: - Public Methods
    
    /// 立即执行清理任务
    func scheduleCleanup() {
        // 确保在主线程执行
        if Thread.isMainThread {
            performCleanup()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.performCleanup()
            }
        }
    }
    
    /// 启动定期清理任务
    func startPeriodicCleanup() {
        // 停止现有定时器
        cleanupTimer?.invalidate()
        
        // 创建新的定时器（每小时执行一次）
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
        
        // 确保定时器在主线程的 RunLoop 上运行
        if let timer = cleanupTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("🧹 历史记录定期清理已启动（每小时检查一次）")
        
        // 立即执行一次清理
        scheduleCleanup()
    }
    
    /// 停止定期清理任务
    func stopPeriodicCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        print("🧹 历史记录定期清理已停止")
    }
    
    // MARK: - Private Methods
    
    /// 执行清理任务
    private func performCleanup() {
        guard let context = modelContext else {
            print("⚠️ ModelContext 未设置，无法执行清理")
            return
        }
        
        // 获取保留时间设置
        let retentionPeriodRaw = UserDefaults.standard.string(forKey: "historyRetentionPeriod") ?? HistoryRetentionPeriod.oneWeek.rawValue
        guard let retentionPeriod = HistoryRetentionPeriod(rawValue: retentionPeriodRaw) else {
            print("⚠️ 无效的保留时间设置: \(retentionPeriodRaw)")
            return
        }
        
        // 如果是永久保留，跳过清理
        guard let timeInterval = retentionPeriod.timeInterval else {
            print("ℹ️ 历史记录设置为永久保留，跳过清理")
            return
        }
        
        // 计算截止日期
        let cutoffDate = Date().addingTimeInterval(-Double(timeInterval))
        
        // 获取是否删除锁定卡片的设置
        let deleteLockedItems = UserDefaults.standard.bool(forKey: "deleteLockedItems")
        
        // 查询需要删除的项目（排除收藏的项目，根据设置决定是否排除锁定的项目）
        // 注意：SwiftData 的 #Predicate 不支持计算属性，必须直接使用 Date 比较
        // 注意：Predicate 闭包内只能包含一个表达式，不能使用多个 let 语句
        let descriptor: FetchDescriptor<ClipboardItem>
        if deleteLockedItems {
            // 如果启用删除锁定卡片，则只排除收藏的项目
            descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate<ClipboardItem> { item in
                    item.createdAt < cutoffDate && !item.isFavorite
                },
                sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: .forward)]
            )
        } else {
            // 如果未启用删除锁定卡片，则排除收藏和锁定的项目
            descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate<ClipboardItem> { item in
                    item.createdAt < cutoffDate && !item.isFavorite && !item.isLocked
                },
                sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: .forward)]
            )
        }
        
        do {
            let itemsToDelete = try context.fetch(descriptor)
            let count = itemsToDelete.count
            
            if count > 0 {
                // 删除过期项目
                for item in itemsToDelete {
                    context.delete(item)
                }
                
                try context.save()
                print("🧹 已清理 \(count) 条过期历史记录（截止日期: \(cutoffDate)）")
            } else {
                print("ℹ️ 没有需要清理的历史记录")
            }
        } catch {
            print("❌ 清理历史记录失败: \(error.localizedDescription)")
        }
    }
}




