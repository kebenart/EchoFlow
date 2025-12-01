# EchoFlow 权限帮助指南

## 📋 概述

EchoFlow 需要**辅助功能权限**来实现自动粘贴功能。本指南将帮助你理解、授权和解决权限相关问题。

## 🎯 为什么需要权限？

EchoFlow 使用 macOS 的 Accessibility API 来模拟键盘操作（⌘V），实现自动粘贴功能。这是 macOS 的安全机制，需要用户明确授权。

## ✅ 如何授权

### 方法一：首次使用时授权（推荐）

1. **运行应用** - 启动 EchoFlow
2. **触发权限提示** - 点击任意剪贴板卡片
3. **打开系统设置** - 点击对话框中的"打开系统设置"按钮
4. **勾选授权** - 在辅助功能列表中找到 EchoFlow 并勾选
5. **重新启动应用** - 完全退出（⌘Q）后重新启动

### 方法二：手动授权

1. 打开 **系统设置** → **隐私与安全性** → **辅助功能**
2. 点击列表下方的 **➕** 按钮
3. 导航到应用位置：
   - **正式版本**：`/Applications/EchoFlow.app`
   - **Debug 版本**：`~/Library/Developer/Xcode/DerivedData/.../EchoFlow.app`
4. 选择应用并添加
5. 在列表中勾选 EchoFlow
6. 重新启动应用

## 🔍 检查权限状态

### 在应用内检查

1. 点击菜单栏图标 → **设置**
2. 查看 **"权限设置"** 部分
3. 如果显示 **"已授权"**（绿色勾选图标），说明权限已生效

### 测试自动粘贴

1. 复制一段文本
2. 打开 EchoFlow 面板（⌘B）
3. 在设置中将 **"复制行为"** 设置为 **"复制并粘贴到当前应用"**
4. 点击剪贴板卡片
5. 如果内容自动粘贴到当前应用，说明权限正常

## ⚠️ 常见问题

### Q1: 授权后仍然提示需要权限

**解决方案**：
1. 在设置页面点击 **"重新检查"** 按钮
2. 完全退出应用（⌘Q）并重新启动
3. 检查系统设置中权限是否真的已勾选
4. 如果仍然无效，尝试重启 Mac

### Q2: 系统设置中找不到应用

**解决方案**：
1. 确保应用至少运行过一次
2. 触发权限提示对话框
3. 点击 **"打开系统设置"** 按钮
4. 如果仍然找不到，点击列表下方的 **➕** 按钮手动添加

### Q3: Debug 和 Release 版本权限混乱

**说明**：
- Debug 版本：Bundle ID 为 `xyz.keben.EchoFlow.debug`，显示为 "EchoFlow (Debug)"
- Release 版本：Bundle ID 为 `xyz.keben.EchoFlow`，显示为 "EchoFlow"
- 两个版本需要分别授权，互不影响

**解决方案**：
1. 在系统设置中分别授权两个版本
2. 确保授权的是正确的应用路径
3. 如果混乱，可以清理权限后重新授权（见下方"清理权限"部分）

### Q4: 权限自动关闭

**可能原因**：
- Bundle ID 变更（系统认为这是新应用）
- 应用路径变更（从 DerivedData 到 /Applications）
- 代码签名变更
- 系统安全策略重置

**解决方案**：
1. 重新在系统设置中授权
2. 如果频繁发生，检查是否有代码签名问题
3. 确保使用相同的代码签名证书

## 🧹 清理权限

如果权限出现混乱，可以清理后重新授权：

### 使用修复脚本（推荐）

```bash
./scripts/fix-permissions.sh
```

### 手动清理

1. **在系统设置中清理**：
   - 打开 **系统设置** → **隐私与安全性** → **辅助功能**
   - 取消勾选或删除所有 EchoFlow 相关项

2. **使用命令行清理**（需要管理员权限）：
   ```bash
   # 重置正式版本权限
   sudo tccutil reset Accessibility xyz.keben.EchoFlow
   
   # 重置 Debug 版本权限
   sudo tccutil reset Accessibility xyz.keben.EchoFlow.debug
   
   # 刷新权限服务
   sudo killall tccd
   ```

3. **重新授权**：
   - 完全退出应用（⌘Q）
   - 重新运行应用
   - 按照"如何授权"部分重新授权

## 🔧 高级诊断

### 检查 TCC 数据库

如果需要深入诊断权限问题，可以检查系统的 TCC（Transparency, Consent, and Control）数据库：

```bash
# 运行诊断脚本（需要管理员权限）
sudo ./scripts/check-tcc-permissions.sh
```

### 查看系统日志

```bash
# 查看权限相关日志
log show --predicate 'subsystem == "com.apple.TCC"' --last 5m | grep -i "echoflow"
```

## 📚 相关文档

- [快速开始指南](QUICKSTART.md) - 包含权限授权的详细步骤
- [权限修复指南](PERMISSION_FIX_GUIDE.md) - 详细的权限问题修复步骤
- [Xcode 调试指南](XCODE_DEBUG_GUIDE.md) - 在 Xcode 中运行时如何授权

## 💡 提示

1. **首次授权后需要重启应用** - 权限更改需要应用重启才能生效
2. **Debug 和 Release 版本分离** - 两个版本使用不同的 Bundle ID，需要分别授权
3. **定期检查权限状态** - 在设置页面可以随时查看权限状态
4. **权限不会自动丢失** - 如果权限自动关闭，可能是应用签名或路径变更导致的

## 🆘 仍然无法解决？

如果按照以上步骤仍然无法解决问题：

1. 检查 macOS 版本是否支持（需要 macOS 14.0+）
2. 检查是否有其他安全软件阻止权限
3. 尝试重启 Mac
4. 查看 Xcode 控制台或系统日志中的错误信息
5. 提交 Issue 到 [GitHub 仓库](https://github.com/kebenart/EchoFlow/issues)

---

**最后更新**：2025-11-30

