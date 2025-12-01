# 辅助功能权限自动关闭问题修复指南

## 🎯 问题描述

应用启动后发现辅助功能权限自动关闭，即使之前已经授权过。

## 🔍 可能的原因

### 1. Bundle ID 变更

**症状**：修改 Bundle ID 后，系统认为这是新应用，旧权限失效。

**解决方案**：
- 在系统设置中重新授权新 Bundle ID 的应用
- 如果从 `xyz.keben.EchoFlow` 改为 `xyz.keben.EchoFlow`，需要重新授权

### 2. 应用路径变更

**症状**：从 Xcode 的 DerivedData 运行改为从 `/Applications` 运行，系统认为这是不同的应用。

**解决方案**：
- Debug 版本和 Release 版本使用不同的 Bundle ID，需要分别授权
- 确保在正确的路径下授权正确的应用

### 3. 代码签名问题

**症状**：应用没有正确签名，系统不信任应用。

**解决方案**：
- 在 Xcode 中配置代码签名
- 选择正确的开发团队
- 确保 Entitlements 文件正确配置

### 4. 系统安全策略

**症状**：macOS 安全策略自动重置了权限。

**解决方案**：
- 检查是否有安全软件阻止
- 尝试重启 Mac
- 检查系统日志中的安全相关错误

## 🔧 诊断步骤

### 步骤 1: 查看详细日志

运行应用后，在 Xcode 控制台查看日志：

```
🔍 启动时权限检查:
   应用名称: EchoFlow
   Bundle ID: xyz.keben.EchoFlow
   应用路径: /Applications/EchoFlow.app
✅ 辅助功能权限已授权
```

如果看到权限状态变化：
```
🔄 权限状态变化: 已授权 → 未授权
```

说明权限确实被关闭了。

### 步骤 2: 检查 Bundle ID

在终端运行：

```bash
# 查看应用的 Bundle ID
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" /Applications/EchoFlow.app/Contents/Info.plist
```

确保与系统设置中授权的 Bundle ID 一致。

### 步骤 3: 检查系统设置

1. 打开 **系统设置** > **隐私与安全性** > **辅助功能**
2. 查找应用（可能是 "EchoFlow" 或 "EchoFlow (Debug)"）
3. 检查是否已勾选
4. 如果未勾选，勾选并重新启动应用

### 步骤 4: 使用诊断脚本

运行诊断脚本：

```bash
./scripts/fix-permissions.sh
```

选择选项查看详细诊断信息。

## 🛠️ 修复方法

### 方法一：重新授权（推荐）

1. **完全退出应用**
   ```bash
   # 在终端中强制退出
   killall EchoFlow
   ```

2. **清理权限**
   ```bash
   # 重置权限（需要管理员权限）
   sudo tccutil reset Accessibility xyz.keben.EchoFlow
   sudo tccutil reset Accessibility xyz.keben.EchoFlow.debug
   ```

3. **重新运行应用并授权**
   - 运行应用
   - 触发权限提示
   - 在系统设置中授权

### 方法二：检查代码签名

1. **查看代码签名状态**
   ```bash
   codesign -dv --verbose=4 /Applications/EchoFlow.app
   ```

2. **验证签名**
   ```bash
   codesign --verify --deep --strict /Applications/EchoFlow.app
   ```

3. **如果签名无效，重新签名**
   - 在 Xcode 中配置正确的开发团队
   - 重新构建应用

### 方法三：检查 Entitlements

确保 `EchoFlow.entitlements` 和 `EchoFlowRelease.entitlements` 文件正确配置。

## 📊 权限状态监控

应用现在会在以下时机检查权限状态：

1. **应用启动时** - 记录详细的权限信息
2. **应用激活时** - 检测权限是否被关闭
3. **设置页面打开时** - 实时显示权限状态
4. **权限检查时** - 记录状态变化

查看 Xcode 控制台日志可以了解权限状态的变化。

## 🐛 常见问题

### Q1: 为什么每次启动权限都被关闭？

**可能原因**：
- Bundle ID 每次构建都不同（不应该发生）
- 应用路径变化
- 代码签名问题

**解决方案**：
- 检查 Xcode 项目设置中的 Bundle ID 是否固定
- 确保使用正确的构建配置（Debug/Release）
- 检查代码签名配置

### Q2: Debug 和 Release 版本权限互相影响？

**答案**：不应该。两个版本使用不同的 Bundle ID：
- Debug: `xyz.keben.EchoFlow.debug`
- Release: `xyz.keben.EchoFlow`

需要分别授权，互不影响。

### Q3: 如何确认权限真的被关闭了？

**方法**：
1. 查看 Xcode 控制台日志
2. 在设置页面查看权限状态
3. 在系统设置中手动检查

### Q4: 权限自动关闭后如何恢复？

**步骤**：
1. 在系统设置中重新勾选应用
2. 完全退出并重新启动应用
3. 在设置页面点击"重新检查"按钮

## 💡 预防措施

1. **固定 Bundle ID**
   - 不要在构建时动态修改 Bundle ID
   - Debug 和 Release 使用不同的但固定的 Bundle ID

2. **正确配置代码签名**
   - 使用有效的开发团队证书
   - 确保 Entitlements 文件正确

3. **避免频繁修改应用路径**
   - Debug 版本在 DerivedData 中运行是正常的
   - Release 版本应该安装在固定位置（如 /Applications）

4. **监控权限状态**
   - 定期检查设置页面中的权限状态
   - 关注 Xcode 控制台中的权限日志

## 📚 相关文档

- [PERMISSION_FIX_GUIDE.md](PERMISSION_FIX_GUIDE.md) - 权限修复指南
- [DEBUG_RELEASE_DIFF.md](DEBUG_RELEASE_DIFF.md) - Debug 与 Release 版本差异
- [XCODE_DEBUG_GUIDE.md](XCODE_DEBUG_GUIDE.md) - Xcode 调试指南

