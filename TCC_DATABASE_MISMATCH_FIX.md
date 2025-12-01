# TCC 数据库有权限但 API 返回 false 修复指南

## 🎯 问题描述

通过 SQLite 查询 TCC 数据库显示权限已授权（`auth_value = 2`），但 `AXIsProcessTrustedWithOptions` API 返回 `false`。

## 🔍 问题原因

这是 macOS 权限系统的常见问题，主要原因包括：

### 1. 代码签名不匹配（最常见）⚠️

**问题**：TCC 数据库中的 `csreq` 字段存储了代码签名要求（Code Signing Requirement），如果应用的签名与数据库中存储的 CSReq 不匹配，即使 Bundle ID 和路径匹配，API 也会返回 false。

**检查方法**：
```bash
# 查看 TCC 数据库中的 CSReq（十六进制）
sudo sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
"SELECT client, hex(csreq) as csreq_hex FROM access WHERE service = 'kTCCServiceAccessibility' AND client LIKE '%EchoFlow%';"

# 查看应用的代码签名
codesign -dv --verbose=4 /Applications/EchoFlow.app

# 验证签名
codesign --verify --deep --strict /Applications/EchoFlow.app
```

**解决方案**：
1. 重置权限（会清除旧的 CSReq）
2. 重新授权（会使用新的签名更新 CSReq）
3. 确保使用相同的代码签名证书

### 2. Bundle ID 或路径不匹配

**问题**：TCC 数据库中的 `client` 字段存储的是旧 Bundle ID 或路径，与当前运行的应用不匹配。

**检查方法**：
```bash
# 查看 TCC 数据库中的记录
sudo sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
"SELECT client, auth_value, last_modified FROM access WHERE service = 'kTCCServiceAccessibility';"
```

**对比**：
- TCC 数据库中的 `client` 字段（可能是 `xyz.keben.EchoFlow` 或旧路径）
- 当前应用的 Bundle ID（`xyz.keben.EchoFlow`）
- 当前应用的路径（可能是 `/Applications/EchoFlow.app` 或 DerivedData 路径）

### 3. 运行方式导致路径变动

**问题**：从 Xcode DerivedData 运行 vs 从 /Applications 运行，路径不同导致系统认为这是不同的应用。

**常见情况**：
- Debug 版本在 `~/Library/Developer/Xcode/DerivedData/...` 中
- Release 版本在 `/Applications/EchoFlow.app`
- 两个版本使用不同的 Bundle ID，需要分别授权

### 4. 权限需要应用重启

**问题**：即使 TCC 数据库已更新，`AXIsProcessTrustedWithOptions` 可能需要应用重启才能识别新权限。

### 5. 系统缓存未同步

**问题**：TCC 数据库已更新，但系统权限服务（tccd）的缓存未刷新。

## 🛠️ 修复步骤

### 步骤 1: 检查 TCC 数据库（包含 CSReq）

运行检查脚本：

```bash
sudo ./scripts/check-tcc-permissions.sh
```

或手动查询（包含 CSReq）：

```bash
# 查看所有字段（包括 CSReq）
sudo sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
"SELECT client, auth_value, datetime(last_modified, 'unixepoch', 'localtime') as time, CASE WHEN csreq IS NULL THEN 'NULL' WHEN length(csreq) = 0 THEN 'EMPTY' ELSE 'EXISTS (' || length(csreq) || ' bytes)' END as csreq_status FROM access WHERE service = 'kTCCServiceAccessibility' AND (client LIKE '%EchoFlow%' OR client LIKE '%echoflow%');"

# 查看 CSReq 的十六进制（用于调试）
sudo sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
"SELECT client, hex(csreq) as csreq_hex FROM access WHERE service = 'kTCCServiceAccessibility' AND client LIKE '%EchoFlow%';"
```

### 步骤 2: 检查代码签名

**这是最重要的步骤！**

```bash
# 查看代码签名详细信息
codesign -dv --verbose=4 /Applications/EchoFlow.app

# 验证签名
codesign --verify --deep --strict /Applications/EchoFlow.app

# 如果验证失败，查看详细错误
codesign --verify --deep --strict --verbose=4 /Applications/EchoFlow.app
```

**关键信息**：
- `Authority=` - 签名者（开发团队）
- `Identifier=` - Bundle ID
- 如果显示 "code object is not signed"，说明应用未签名

### 步骤 3: 对比应用信息

查看当前应用的实际信息：

```bash
# 查看 Bundle ID
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" /Applications/EchoFlow.app/Contents/Info.plist

# 查看应用路径
echo $(cd /Applications/EchoFlow.app && pwd)

# 查看代码签名要求（当前应用的）
codesign -d -r- /Applications/EchoFlow.app 2>&1 | grep -A 10 "designated requirement"
```

### 步骤 4: 如果 CSReq 不匹配或 Bundle ID/路径不匹配

**清理旧权限并重新授权**（这会更新 CSReq）：

```bash
# 重置所有 EchoFlow 相关权限（包括旧的 xyz.keben 前缀）
sudo tccutil reset Accessibility xyz.keben.EchoFlow
sudo tccutil reset Accessibility xyz.keben.EchoFlow.debug
sudo tccutil reset Accessibility xyz.keben.EchoFlow 2>/dev/null || true
sudo tccutil reset Accessibility xyz.keben.EchoFlow.debug 2>/dev/null || true

# 刷新权限服务（清除缓存）
sudo killall tccd
```

### 步骤 5: 完全退出并重新启动应用

1. **完全退出应用**（⌘Q，不要只是关闭窗口）
2. **等待几秒**（确保进程完全退出）
3. **重新启动应用**
4. **触发权限提示并重新授权**

### 步骤 6: 重新授权（使用新的签名）

1. **重新运行应用**
2. **触发权限提示**
3. **在系统设置中授权**
   - 这会使用当前应用的签名更新 CSReq
   - 确保 CSReq 与当前签名匹配

### 步骤 7: 验证修复

1. 在应用设置页面查看权限状态
2. 应该显示"已授权"（绿色勾选）
3. 测试自动粘贴功能

## 🔧 使用诊断工具

### 方法一：在应用内诊断

1. 打开应用设置页面
2. 找到"权限设置"部分
3. 点击 **"诊断权限"** 按钮
4. 查看详细的诊断信息，包括：
   - 当前 Bundle ID 和路径
   - API 检查结果
   - 多种检查方式的对比
   - 可能的原因和建议

### 方法二：使用命令行脚本

```bash
# 检查 TCC 数据库（包含 CSReq 信息）
sudo ./scripts/check-tcc-permissions.sh
```

脚本会：
- 显示所有辅助功能权限记录
- 查找 EchoFlow 相关记录（包含 CSReq 状态）
- 显示应用的实际信息和代码签名
- 提供对比分析

## 📊 诊断输出示例

### TCC 数据库查询结果

```
client                                    | auth_value | time                | csreq_status
------------------------------------------|------------|---------------------|------------------
xyz.keben.EchoFlow                        | 2          | 2025-11-30 10:30:00 | EXISTS (256 bytes)
xyz.keben.EchoFlow                        | 2          | 2025-11-29 15:20:00 | EXISTS (256 bytes)  ← 旧 Bundle ID
```

**关键字段**：
- `client`: Bundle ID 或应用路径
- `auth_value`: 2 = 已授权, 0 = 未授权
- `csreq`: 代码签名要求（二进制数据）
  - 如果为 NULL 或空，表示没有签名要求
  - 如果有值，必须与当前应用的签名匹配

### 应用诊断结果

```
🔍 权限诊断信息:
   应用名称: EchoFlow
   Bundle ID: xyz.keben.EchoFlow
   应用路径: /Applications/EchoFlow.app
   可执行文件: /Applications/EchoFlow.app/Contents/MacOS/EchoFlow

API 检查结果: ❌ 未授权
   (AXIsProcessTrustedWithOptions 返回值)

⚠️ TCC 数据库有权限但 API 返回 false 的可能原因:

1. Bundle ID 或路径不匹配（最常见）
   - TCC 数据库中存储的 client 字段可能是:
     • 旧 Bundle ID（如 xyz.keben.EchoFlow）
     • 旧应用路径（如 DerivedData 路径）
```

## 💡 快速修复命令

如果确认是 CSReq 不匹配或 Bundle ID 不匹配，使用以下命令快速修复：

```bash
# 1. 检查代码签名
codesign -dv --verbose=4 /Applications/EchoFlow.app
codesign --verify --deep --strict /Applications/EchoFlow.app

# 2. 重置所有相关权限（会清除旧的 CSReq）
sudo tccutil reset Accessibility xyz.keben.EchoFlow
sudo tccutil reset Accessibility xyz.keben.EchoFlow.debug
sudo tccutil reset Accessibility xyz.keben.EchoFlow 2>/dev/null || true
sudo tccutil reset Accessibility xyz.keben.EchoFlow.debug 2>/dev/null || true

# 3. 刷新权限服务（清除缓存）
sudo killall tccd

# 4. 完全退出应用
killall EchoFlow

# 5. 重新运行应用并授权（会使用新的签名更新 CSReq）
```

## 🐛 常见问题

### Q: 为什么 TCC 数据库显示有权限，但 API 返回 false？

**A**: 最常见的原因是：

1. **代码签名不匹配（CSReq）** - TCC 数据库中的 `csreq` 字段存储了代码签名要求，如果应用的签名与 CSReq 不匹配，API 会返回 false。即使 Bundle ID 和路径匹配，签名不匹配也会导致权限失效。

2. **Bundle ID 或路径不匹配** - TCC 数据库中的 `client` 字段与当前应用的 Bundle ID 或路径不匹配。

3. **需要应用重启** - 权限更新后需要完全退出并重新启动应用。

### Q: 如何确认 TCC 数据库中的 client 和 csreq 字段？

**A**: 运行以下命令：

```bash
# 查看 client 字段
sudo sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
"SELECT client FROM access WHERE service = 'kTCCServiceAccessibility' AND client LIKE '%EchoFlow%';"

# 查看 csreq 字段（十六进制）
sudo sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
"SELECT client, hex(csreq) as csreq_hex, length(csreq) as csreq_size FROM access WHERE service = 'kTCCServiceAccessibility' AND client LIKE '%EchoFlow%';"
```

### Q: 如何修复 CSReq 不匹配的问题？

**A**: 
1. 重置权限：`sudo tccutil reset Accessibility xyz.keben.EchoFlow`
2. 刷新权限服务：`sudo killall tccd`
3. 完全退出应用（⌘Q）
4. 重新运行应用并授权（会使用新的签名更新 CSReq）

### Q: 重置权限后需要做什么？

**A**: 
1. 完全退出应用（⌘Q）
2. 重新运行应用
3. 触发权限提示
4. 在系统设置中重新授权
5. 再次完全退出并重新启动应用

### Q: 重启 tccd 服务安全吗？

**A**: 是的，这是 macOS 的标准操作。`tccd` 是系统权限服务，重启它只会刷新权限缓存，不会影响其他功能。

### Q: 如果修复后仍然无效？

**A**: 尝试以下步骤：
1. 重启 Mac（最彻底的方法）
2. 检查代码签名是否正确
3. 确认应用路径没有变化
4. 查看系统日志：`log show --predicate 'subsystem == "com.apple.TCC"' --last 10m`

## 📚 相关文档

- [PERMISSION_DETECTION_FIX.md](PERMISSION_DETECTION_FIX.md) - 权限检测问题修复
- [PERMISSION_AUTO_CLOSE_FIX.md](PERMISSION_AUTO_CLOSE_FIX.md) - 权限自动关闭问题
- [scripts/check-tcc-permissions.sh](scripts/check-tcc-permissions.sh) - TCC 数据库检查脚本

