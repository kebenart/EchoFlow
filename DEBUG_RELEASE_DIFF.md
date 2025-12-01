# Debug 与 Release 版本差异说明

## 📋 配置差异

为了区分 Xcode 中运行的 Debug 版本和正式安装的 Release 版本，项目配置了不同的标识：

| 配置项 | Debug 版本 | Release 版本 |
|--------|-----------|-------------|
| **Bundle Identifier** | `xyz.keben.EchoFlow.debug` | `xyz.keben.EchoFlow` |
| **应用显示名称** | `EchoFlow (Debug)` | `EchoFlow` |
| **Entitlements** | `EchoFlow.entitlements` | `EchoFlowRelease.entitlements` |

## 🎯 为什么需要区分？

### 问题

在 Xcode 中运行应用和从 `/Applications` 运行正式版本时，如果使用相同的 Bundle ID，会导致：

1. **辅助功能权限混乱**：系统无法区分两个版本，授权状态可能互相影响
2. **用户数据混淆**：UserDefaults、SwiftData 等数据可能共享或冲突
3. **调试困难**：无法同时运行两个版本进行对比测试

### 解决方案

通过使用不同的 Bundle ID 和应用名称，系统会将 Debug 和 Release 版本视为完全不同的应用：

- ✅ 权限独立管理
- ✅ 数据完全隔离
- ✅ 可以同时运行两个版本

## 🔧 如何修改

### 在 Xcode 中修改

1. 选择项目文件（最顶层的 EchoFlow）
2. 选择 **TARGETS** > **EchoFlow**
3. 切换到 **Build Settings** 标签
4. 搜索 `PRODUCT_BUNDLE_IDENTIFIER`
5. 展开配置，分别设置：
   - **Debug**: `xyz.keben.EchoFlow.debug`
   - **Release**: `xyz.keben.EchoFlow`

6. 搜索 `INFOPLIST_KEY_CFBundleName`
7. 在 **Debug** 配置中添加：`EchoFlow (Debug)`
8. **Release** 配置保持为空（使用默认名称）

### 验证配置

运行以下命令检查配置：

```bash
# 检查 Debug 配置
xcodebuild -project EchoFlow.xcodeproj -scheme EchoFlow -configuration Debug -showBuildSettings | grep PRODUCT_BUNDLE_IDENTIFIER

# 检查 Release 配置
xcodebuild -project EchoFlow.xcodeproj -scheme EchoFlow -configuration Release -showBuildSettings | grep PRODUCT_BUNDLE_IDENTIFIER
```

## 📱 使用场景

### Debug 版本（Xcode 运行）

- **用途**：开发和调试
- **标识**：`EchoFlow (Debug)`
- **Bundle ID**：`xyz.keben.EchoFlow.debug`
- **权限**：需要单独授权
- **数据**：独立的 UserDefaults 和数据库

### Release 版本（正式安装）

- **用途**：日常使用
- **标识**：`EchoFlow`
- **Bundle ID**：`xyz.keben.EchoFlow`
- **权限**：需要单独授权
- **数据**：独立的 UserDefaults 和数据库

## 🔐 权限授权

### Debug 版本授权

1. 在 Xcode 中运行应用
2. 触发权限提示
3. 在系统设置中查找 **EchoFlow (Debug)**
4. 勾选授权

### Release 版本授权

1. 从 `/Applications` 运行应用
2. 触发权限提示
3. 在系统设置中查找 **EchoFlow**
4. 勾选授权

### 同时授权两个版本

两个版本的权限是独立的，可以同时授权：

- ✅ Debug 版本：用于开发测试
- ✅ Release 版本：用于日常使用
- ✅ 互不干扰

## 💾 数据隔离

由于使用不同的 Bundle ID，以下数据完全隔离：

- **UserDefaults**：`com.apple.nsuserdefaults.xyz.keben.EchoFlow.debug` vs `com.apple.nsuserdefaults.xyz.keben.EchoFlow`
- **SwiftData**：不同的数据库文件
- **文件存储**：不同的应用沙盒目录
- **缓存数据**：完全独立

## 🐛 常见问题

### Q: 为什么 Debug 版本显示为 "EchoFlow (Debug)"？

**A**: 这是为了在系统设置中清晰区分 Debug 和 Release 版本，避免权限授权混乱。

### Q: 可以修改 Debug 版本的显示名称吗？

**A**: 可以，在 Xcode 项目设置中修改 `INFOPLIST_KEY_CFBundleName` 的 Debug 配置值即可。

### Q: 两个版本的数据会共享吗？

**A**: 不会。由于 Bundle ID 不同，所有数据（UserDefaults、SwiftData、文件等）都是完全隔离的。

### Q: 如果修改了 Bundle ID，需要重新授权吗？

**A**: 是的。每次修改 Bundle ID 后，系统会将其视为新应用，需要重新授权辅助功能权限。

## 📚 相关文档

- [XCODE_DEBUG_GUIDE.md](XCODE_DEBUG_GUIDE.md) - Xcode 调试指南
- [QUICKSTART.md](QUICKSTART.md) - 快速开始指南

