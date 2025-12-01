# Xcode 调试指南 - 辅助功能权限授权

## 🎯 问题说明

在 Xcode 中直接运行应用时，应用的实际路径在 `DerivedData` 目录中，这可能导致在系统设置的辅助功能列表中找不到应用，或者应用名称显示不同。

**重要更新**：Debug 版本现在使用不同的 Bundle ID (`xyz.keben.EchoFlow.debug`) 和应用名称 (`EchoFlow (Debug)`)，与正式版本 (`xyz.keben.EchoFlow`) 完全分离，不会互相影响权限授权。

## 📋 授权步骤

### 方法一：通过应用提示授权（最简单）

1. **运行应用**
   ```bash
   # 在 Xcode 中按 ⌘R 运行
   ```

2. **触发权限检查**
   - 点击任意剪贴板卡片
   - 或打开设置页面查看权限状态
   - 会弹出权限提示对话框

3. **查看应用信息**
   - 对话框会显示：
     - 应用名称
     - 可执行文件名
     - 完整应用路径

4. **打开系统设置**
   - 点击"打开系统设置"按钮
   - 会自动打开：**系统设置** > **隐私与安全性** > **辅助功能**

5. **查找并添加应用**
   - 在列表中查找 **EchoFlow (Debug)** 或 **EchoFlow.app**
   - **注意**：Debug 版本显示为 "EchoFlow (Debug)"，与正式版本 "EchoFlow" 是分开的
   - 如果找不到：
     - 点击列表下方的 **➕** 按钮
     - 在文件选择器中按 `⌘⇧G` 打开"前往文件夹"
     - 输入对话框显示的应用路径
     - 选择 `EchoFlow.app` 并打开

6. **启用权限**
   - 在辅助功能列表中勾选 EchoFlow

7. **重新启动应用**
   - 在 Xcode 中停止应用（⌘.）
   - 重新运行应用（⌘R）

### 方法二：手动查找应用路径

如果对话框没有显示路径，可以手动查找：

1. **获取应用路径**
   ```bash
   # 在 Xcode 控制台中查找类似输出：
   # Bundle path: /Users/yourname/Library/Developer/Xcode/DerivedData/EchoFlow-xxxxx/Build/Products/Debug/EchoFlow.app
   ```

2. **打开系统设置**
   - **系统设置** > **隐私与安全性** > **辅助功能**

3. **添加应用**
   - 点击 **➕** 按钮
   - 按 `⌘⇧G` 打开"前往文件夹"
   - 粘贴应用路径（去掉最后的 `.app`）
   - 选择 `EchoFlow.app`

4. **启用权限并重启应用**

### 方法三：使用终端命令（高级）

```bash
# 1. 查找应用路径
find ~/Library/Developer/Xcode/DerivedData -name "EchoFlow.app" -type d

# 2. 打开系统设置到辅助功能页面
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

# 3. 手动添加应用（需要 GUI 操作）
```

## ✅ 验证权限

### 方法一：在设置页面查看

1. 运行应用
2. 点击菜单栏图标 → **设置**
3. 查看"权限设置"部分
4. 如果显示 **"已授权"**（绿色勾选图标），说明权限已生效

### 方法二：测试自动粘贴

1. 复制一段文本
2. 打开 EchoFlow 面板（⌘B）
3. 在设置中将"复制行为"设置为"复制并粘贴到当前应用"
4. 点击剪贴板卡片
5. 如果内容自动粘贴到当前应用，说明权限正常

### 方法三：查看控制台日志

在 Xcode 控制台中查找：
```
✅ 辅助功能权限已授权
```

如果看到：
```
⚠️ 辅助功能权限未授权
```
说明权限未生效，需要重新授权。

## 🔧 常见问题

### Q1: 在辅助功能列表中找不到应用

**原因**：应用路径在 DerivedData 中，系统可能还没有识别到。

**解决方案**：
1. 确保应用至少运行过一次
2. 点击列表下方的 **➕** 按钮手动添加
3. 使用对话框显示的应用路径

### Q2: 授权后仍然提示需要权限

**原因**：权限缓存或应用需要重启。

**解决方案**：
1. 在 Xcode 中完全停止应用（⌘.）
2. 重新运行应用（⌘R）
3. 在设置页面点击"重新检查"按钮

### Q3: 每次重新构建后都需要重新授权

**原因**：Xcode 每次构建可能生成新的 DerivedData 路径。

**解决方案**：
1. 使用 Archive 构建并安装到 `/Applications`
2. 或每次构建后重新授权（这是正常的开发流程）

### Q4: 权限提示对话框显示的应用路径很长

**原因**：DerivedData 路径通常很长。

**解决方案**：
1. 复制对话框显示的完整路径
2. 在文件选择器中按 `⌘⇧G` 粘贴路径
3. 或使用终端 `open` 命令打开路径

## 💡 开发建议

### 推荐工作流程

1. **首次运行**：按照提示授权
2. **日常开发**：权限会保持，除非 DerivedData 路径改变
3. **测试权限功能**：使用 Archive 构建的版本测试完整流程

### 调试技巧

1. **查看应用信息**：
   ```swift
   print("Bundle path: \(Bundle.main.bundlePath)")
   print("Executable: \(Bundle.main.executableURL?.path ?? "unknown")")
   print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
   ```

2. **检查权限状态**：
   ```swift
   let hasPermission = PasteSimulator.shared.checkAccessibilityPermission()
   print("Accessibility permission: \(hasPermission)")
   ```

3. **清除权限缓存**：
   ```swift
   PasteSimulator.shared.clearPermissionCache()
   ```

## 📝 注意事项

1. **每次重新构建**：如果 DerivedData 路径改变，可能需要重新授权
2. **系统重启**：权限会保持，不需要重新授权
3. **Xcode 更新**：通常不影响权限
4. **macOS 更新**：可能需要重新授权

## 🔗 相关资源

- [Apple 文档：Accessibility API](https://developer.apple.com/documentation/applicationservices/accessibility)
- [系统设置路径](x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility)

