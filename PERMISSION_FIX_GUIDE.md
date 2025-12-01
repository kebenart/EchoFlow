# EchoFlow 权限修复指南

## 🎯 问题说明

如果辅助功能权限出现混乱（例如：授权了但无效、重复授权、无法识别等），可以按照以下步骤清理并重新授权。

## 🔧 快速修复

### 方法一：使用修复脚本（推荐）

```bash
./scripts/fix-permissions.sh
```

脚本会提供交互式菜单，引导你完成清理和重新授权。

### 方法二：手动清理

#### 步骤 1: 清理系统权限

1. **打开系统设置**
   - 点击 Apple 菜单 > **系统设置**
   - 或按 `⌘,` 打开系统设置

2. **进入隐私与安全性**
   - 在左侧边栏找到 **隐私与安全性**
   - 点击进入

3. **打开辅助功能设置**
   - 在右侧找到 **辅助功能**
   - 点击进入

4. **清理所有 EchoFlow 相关权限**
   - 查找以下应用（如果存在）：
     - ✅ **EchoFlow** (正式版本)
     - ✅ **EchoFlow (Debug)** (Debug 版本)
     - ✅ **EchoFlow.app** (任何路径下的)
   - **取消勾选**所有 EchoFlow 相关项
   - 或者点击 **➖** 按钮**删除**这些项

5. **关闭系统设置**

#### 步骤 2: 清理应用缓存（可选）

如果权限仍然有问题，可以清理应用缓存：

```bash
# 清理 UserDefaults
rm -f ~/Library/Preferences/xyz.keben.EchoFlow.plist
rm -f ~/Library/Preferences/xyz.keben.EchoFlow.debug.plist

# 清理 SwiftData 数据库（会删除所有数据）
rm -rf ~/Library/Application\ Support/xyz.keben.EchoFlow
rm -rf ~/Library/Application\ Support/xyz.keben.EchoFlow.debug
```

⚠️ **警告**：删除数据库会清除所有剪贴板历史和笔记数据！

#### 步骤 3: 使用命令行工具清理（需要管理员权限）

```bash
# 重置 EchoFlow 权限
sudo tccutil reset Accessibility xyz.keben.EchoFlow

# 重置 EchoFlow Debug 权限
sudo tccutil reset Accessibility xyz.keben.EchoFlow.debug
```

#### 步骤 4: 重新授权

清理完成后，需要重新授权：

**对于 Debug 版本（Xcode 运行）：**
1. 在 Xcode 中运行应用（⌘R）
2. 点击任意剪贴板卡片触发权限提示
3. 点击 **"打开系统设置"**
4. 在辅助功能中查找 **"EchoFlow (Debug)"**
5. 勾选授权
6. 重新启动应用

**对于 Release 版本（正式安装）：**
1. 从 `/Applications` 运行应用
2. 点击任意剪贴板卡片触发权限提示
3. 点击 **"打开系统设置"**
4. 在辅助功能中查找 **"EchoFlow"**
5. 勾选授权
6. 重新启动应用

## 🔍 验证权限是否生效

### 方法一：在应用内检查

1. 运行应用
2. 点击菜单栏图标 → **设置**
3. 查看 **"权限设置"** 部分
4. 如果显示 **"已授权"**（绿色勾选图标），说明权限已生效

### 方法二：测试自动粘贴

1. 复制一段文本
2. 打开 EchoFlow 面板（⌘B）
3. 在设置中将 **"复制行为"** 设置为 **"复制并粘贴到当前应用"**
4. 点击剪贴板卡片
5. 如果内容自动粘贴到当前应用，说明权限正常

### 方法三：查看系统日志

在终端中运行：

```bash
# 查看权限相关日志
log show --predicate 'subsystem == "com.apple.TCC"' --last 5m | grep -i "echoflow"
```

## 🐛 常见问题

### Q1: 清理后仍然无法授权

**解决方案**：
1. 完全退出应用（⌘Q）
2. 重启 Mac（可选，但推荐）
3. 重新运行应用并授权

### Q2: 系统设置中找不到应用

**解决方案**：
1. 确保应用至少运行过一次
2. 触发权限提示对话框
3. 点击 **"打开系统设置"** 按钮
4. 如果仍然找不到，点击列表下方的 **➕** 按钮手动添加

### Q3: 授权后仍然提示需要权限

**解决方案**：
1. 在应用设置页面点击 **"重新检查"** 按钮
2. 完全退出并重新启动应用
3. 检查系统设置中权限是否真的已勾选

### Q4: Debug 和 Release 版本权限互相影响

**解决方案**：
- 这是正常的，因为现在两个版本使用不同的 Bundle ID
- Debug 版本：`xyz.keben.EchoFlow.debug` → 显示为 "EchoFlow (Debug)"
- Release 版本：`xyz.keben.EchoFlow` → 显示为 "EchoFlow"
- 需要分别授权，互不影响

### Q5: 清理数据库后数据丢失

**解决方案**：
- ⚠️ 这是预期行为，清理数据库会删除所有数据
- 建议在清理前先备份重要数据
- 或者只清理权限，不清理数据库

## 💡 预防措施

为了避免权限混乱，建议：

1. **区分 Debug 和 Release 版本**
   - Debug 版本：只在开发时使用
   - Release 版本：日常使用

2. **定期检查权限状态**
   - 在设置页面查看权限状态
   - 如果显示异常，及时清理并重新授权

3. **避免频繁切换版本**
   - 如果同时使用两个版本，确保分别授权
   - 不要在一个版本未授权时切换到另一个版本

## 📚 相关文档

- [XCODE_DEBUG_GUIDE.md](XCODE_DEBUG_GUIDE.md) - Xcode 调试指南
- [DEBUG_RELEASE_DIFF.md](DEBUG_RELEASE_DIFF.md) - Debug 与 Release 版本差异
- [QUICKSTART.md](QUICKSTART.md) - 快速开始指南

## 🆘 仍然无法解决？

如果按照以上步骤仍然无法解决问题：

1. 检查 macOS 版本是否支持（需要 macOS 14.0+）
2. 检查是否有其他安全软件阻止权限
3. 尝试重启 Mac
4. 查看 Xcode 控制台或系统日志中的错误信息
5. 提交 Issue 到 GitHub 仓库

