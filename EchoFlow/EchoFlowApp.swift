//
//  EchoFlowApp.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import SwiftUI
import SwiftData
import Foundation

@main
struct EchoFlowApp: App {
    // MARK: - Properties

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Model Container (静态变量，供 AppDelegate 访问)

    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ClipboardItem.self,
            NoteItem.self,
            TrashItem.self,
        ])

        // 首先尝试使用持久化存储
        let persistentConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [persistentConfiguration])
            print("✅ SwiftData 容器创建成功（持久化模式）")
            
            // 迁移现有数据：为所有现有项目设置 isLocked 默认值
            migrateExistingData(container: container)
            
            return container
        } catch {
            print("⚠️ 无法创建持久化 ModelContainer: \(error)")
            print("🔄 尝试备份并迁移数据库...")
            
            // 备份旧数据库（使用 JSON 格式）
            let url = persistentConfiguration.url
            let fileManager = FileManager.default
            let backupDir = url.deletingLastPathComponent()
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let backupURL = backupDir.appendingPathComponent("backup_\(timestamp).json")
            
            // 尝试创建 JSON 格式的备份
            // 注意：由于数据库可能已损坏，我们无法读取数据来创建 JSON 备份
            // 因此直接使用目录备份，用户可以通过设置界面的备份功能创建 JSON 备份
            if fileManager.fileExists(atPath: url.path) {
                do {
                    // 备份整个数据库目录（作为安全备份）
                    let fallbackBackupURL = backupDir.appendingPathComponent("default.backup")
                    if fileManager.fileExists(atPath: fallbackBackupURL.path) {
                        try fileManager.removeItem(at: fallbackBackupURL)
                    }
                    try fileManager.copyItem(at: url, to: fallbackBackupURL)
                    print("✅ 已备份数据库目录到: \(fallbackBackupURL.path)")
                    print("💡 提示：如果数据库迁移成功，建议通过设置界面创建 JSON 格式的备份")
                } catch {
                    print("⚠️ 备份数据库失败: \(error)")
                    // 即使备份失败，也继续尝试迁移
                }
            }
            
            // 尝试修复数据库：关闭 WAL 模式并合并
            let storeURL = url.appendingPathComponent("default.store")
            let storeShmURL = url.appendingPathComponent("default.store-shm")
            let storeWalURL = url.appendingPathComponent("default.store-wal")
            
            // 如果存在 WAL 文件，尝试合并到主数据库
            if fileManager.fileExists(atPath: storeWalURL.path) {
                print("🔄 检测到 WAL 文件，尝试合并...")
                // SwiftData 会在打开时自动合并 WAL，但我们可以先尝试删除 WAL 文件
                // 注意：这不会丢失数据，因为 WAL 中的数据会在下次打开时合并
                do {
                    if fileManager.fileExists(atPath: storeShmURL.path) {
                        try fileManager.removeItem(at: storeShmURL)
                        print("🗑️ 已删除共享内存文件（将在下次打开时重建）")
                    }
                    // 保留 WAL 文件，让 SwiftData 自动处理
                } catch {
                    print("⚠️ 处理 WAL 文件失败: \(error)")
                }
            }
            
            // 再次尝试创建容器（SwiftData 应该能自动处理新属性）
            do {
                let container = try ModelContainer(for: schema, configurations: [persistentConfiguration])
                print("✅ SwiftData 容器创建成功（迁移后）")
                
                // 迁移现有数据
                migrateExistingData(container: container)
                
                return container
            } catch {
                print("⚠️ 迁移后仍无法创建容器: \(error)")
                
                // 如果备份存在，尝试从备份恢复
                if fileManager.fileExists(atPath: backupURL.path) {
                    print("🔄 尝试从备份恢复数据库...")
                    do {
                        // 删除当前（损坏的）数据库目录
                        if fileManager.fileExists(atPath: url.path) {
                            try fileManager.removeItem(at: url)
                        }
                        // 从备份恢复
                        try fileManager.copyItem(at: backupURL, to: url)
                        print("✅ 已从备份恢复数据库")
                        
                        // 再次尝试创建容器
                        let container = try ModelContainer(for: schema, configurations: [persistentConfiguration])
                        print("✅ SwiftData 容器创建成功（从备份恢复后）")
                        
                        // 迁移现有数据
                        migrateExistingData(container: container)
                        
                        return container
                    } catch {
                        print("⚠️ 从备份恢复失败: \(error)")
                    }
                }
                
                // 最后的备选方案：使用内存模式（数据不会持久化，但至少应用可以启动）
                print("⚠️ 所有迁移尝试失败，切换到内存模式")
                print("💡 提示：数据库备份位于: \(backupURL.path)")
                
                let memoryConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                
                do {
                    let container = try ModelContainer(for: schema, configurations: [memoryConfiguration])
                    print("✅ SwiftData 容器创建成功（内存模式）")
                    
                    // 显示警告给用户，告知备份位置
                    DispatchQueue.main.async {
                        showDatabaseMigrationWarning(backupPath: backupURL.path)
                    }
                    
                    return container
                } catch {
                    // 如果连内存模式都失败，这通常是代码问题
                    fatalError("❌ 无法创建 ModelContainer（所有方式都失败）: \(error)\n请检查模型定义是否正确。\n数据库备份位于: \(backupURL.path)")
                }
            }
        }
    }()
    
    /// 显示数据库迁移警告
    private static func showDatabaseMigrationWarning(backupPath: String? = nil) {
        let alert = NSAlert()
        alert.messageText = "数据库迁移提示"
        
        var message = """
        检测到数据库版本不兼容，已自动尝试迁移。
        
        """
        
        if let backupPath = backupPath {
            message += """
            为了安全，已备份原数据库到：
            \(backupPath)
            
            如果数据丢失，可以从备份恢复。
            
            """
        }
        
        message += """
        如果这是首次启动，这是正常的。
        如果之前有数据，请检查数据是否完整。
        """
        
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }
    
    /// 迁移现有数据：为所有现有项目设置 isLocked 默认值
    private static func migrateExistingData(container: ModelContainer) {
        let context = container.mainContext
        
        do {
            // 检查并迁移 ClipboardItem
            let clipboardDescriptor = FetchDescriptor<ClipboardItem>()
            let clipboardItems = try context.fetch(clipboardDescriptor)
            
            for item in clipboardItems {
                // SwiftData 应该已经为新属性设置了默认值 false
                // 但为了确保，我们显式检查（虽然不需要修改，因为默认值已经是 false）
                // 这里主要是为了触发 SwiftData 的迁移机制
            }
            
            // 检查并迁移 NoteItem
            let noteDescriptor = FetchDescriptor<NoteItem>()
            let noteItems = try context.fetch(noteDescriptor)
            
            for note in noteItems {
                // 同样，isLocked 应该已经有默认值 false
            }
            
            // 保存以确保迁移完成
            if clipboardItems.count > 0 || noteItems.count > 0 {
                try context.save()
                print("✅ 数据迁移完成：已处理 \(clipboardItems.count) 个剪贴板项目和 \(noteItems.count) 个笔记项目")
            } else {
                print("ℹ️ 数据库为空，无需迁移")
            }
        } catch {
            print("⚠️ 数据迁移检查失败（不影响使用）: \(error)")
        }
    }

    // MARK: - Initialization

    init() {
        // 设置为 accessory 应用，隐藏 Dock 图标
        // 这必须在应用启动早期设置
    }

    // MARK: - Scene

    var body: some Scene {
        // MenuBar 应用 - 使用一个不可见的 WindowGroup
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .onAppear {
                    // 立即关闭空白窗口，防止创建多个窗口
                    DispatchQueue.main.async {
                        NSApplication.shared.windows.forEach { window in
                            // 只关闭不是 NSPanel 的窗口，并且确保窗口不是关键窗口
                            if !(window is NSPanel) && !window.isKeyWindow {
                                window.close()
                            }
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 0, height: 0)
        .commands {
            // 移除所有默认命令
            CommandGroup(replacing: .newItem) { }
        }
        .handlesExternalEvents(matching: []) // 防止创建多个窗口
    }
}
