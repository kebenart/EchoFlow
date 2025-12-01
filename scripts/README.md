# EchoFlow 脚本工具

本目录包含 EchoFlow 项目的自动化脚本工具。

## 📁 脚本列表

| 脚本 | 用途 | 使用频率 |
|------|------|---------|
| `build-package.sh` | 本地构建安装包 | 本地测试/分发 |
| `check-signature.sh` | 检测安装包签名 | 验证构建结果 |
| `fix-permissions.sh` | 权限修复工具 | 权限问题 |
| `check-tcc-permissions.sh` | 检查 TCC 数据库权限 | 诊断权限问题 |
| `release.sh` | 完整发布流程 | 正式发布 |
| `quick-release.sh` | 快速发布 | 热修复/小版本 |
| `clean-git-history.sh` | 清理 Git 历史 | 初始化/重置 |

---

## 📦 build-package.sh - 本地构建安装包

在本地构建 DMG 和 ZIP 安装包，无需推送到 GitHub。

### 用法

```bash
./scripts/build-package.sh [version]
```

### 示例

```bash
# 使用当前项目版本号构建
./scripts/build-package.sh

# 指定版本号构建
./scripts/build-package.sh 1.0.1
```

### 执行步骤

1. ✅ 清理旧的构建文件
2. ✅ 构建 Release Archive
3. ✅ 导出 .app 文件
4. ✅ 创建 DMG 安装包
5. ✅ 创建 ZIP 压缩包

### 输出文件

构建完成后，会在 `build/` 目录下生成：

- `EchoFlow-x.x.x.dmg` - DMG 安装包（可直接双击安装）
- `EchoFlow-x.x.x.zip` - ZIP 压缩包（备用分发方式）

### 安装说明

1. 双击 DMG 文件打开
2. 将 EchoFlow.app 拖入 Applications 文件夹
3. 首次运行时，右键选择"打开"以绕过 Gatekeeper

---

## 🔐 check-signature.sh - 检测安装包签名

检测 .app 文件或 DMG 安装包的代码签名信息，用于验证构建结果。

### 用法

```bash
./scripts/check-signature.sh <app_path_or_dmg>
```

### 示例

```bash
# 检测已安装的应用
./scripts/check-signature.sh /Applications/EchoFlow.app

# 检测构建输出的应用
./scripts/check-signature.sh build/Export/EchoFlow.app

# 检测 DMG 安装包（会自动挂载并检测内部应用）
./scripts/check-signature.sh EchoFlow-1.0.0.dmg
```

### 功能

1. ✅ 基本签名信息（格式、标识符、签名者）
2. ✅ 详细签名信息（证书、时间戳、哈希值）
3. ✅ 签名验证（深度验证、严格模式）
4. ✅ 签名要求（Designated Requirement）
5. ✅ 权限声明（Entitlements）
6. ✅ 隔离属性检查（Quarantine）
7. ✅ 可执行文件签名检查

### 检测内容

#### 对于 .app 文件：
- 应用签名信息
- 签名验证结果
- 签名要求和权限声明
- 隔离属性状态
- 可执行文件签名

#### 对于 .dmg 文件：
- DMG 签名信息（如果有）
- 自动挂载 DMG
- 检测内部 .app 文件的签名
- 自动卸载 DMG

### 示例输出

```
📋 检查应用签名: /Applications/EchoFlow.app

ℹ️ 基本签名信息:
  Format=app bundle with Mach-O thin (x86_64)
  Identifier=xyz.keben.EchoFlow
  Signature=adhoc
  CodeDirectory v=20400 size=...

ℹ️ 详细签名信息:
  Format: app bundle with Mach-O thin (x86_64)
  Identifier: xyz.keben.EchoFlow
  Signature: adhoc
  ...

✅ 签名验证通过

ℹ️ 签名要求 (Designated Requirement):
  identifier "xyz.keben.EchoFlow" and ...

ℹ️ 权限声明 (Entitlements):
  com.apple.security.app-sandbox
  com.apple.developer.icloud-container-identifiers
  ...

✅ 无隔离属性
```

### 使用场景

- 验证构建后的应用是否正确签名
- 检查签名者信息
- 诊断签名相关问题
- 验证 DMG 安装包中的应用签名
- 检查隔离属性（可能导致"文件已损坏"提示）

---

## 🔍 check-tcc-permissions.sh - 检查 TCC 数据库权限

检查 TCC 数据库中的辅助功能权限，用于诊断权限问题。

### 用法

```bash
sudo ./scripts/check-tcc-permissions.sh
```

### 功能

1. ✅ 查询 TCC 数据库中所有辅助功能权限
2. ✅ 显示 EchoFlow 相关的权限记录
3. ✅ 对比应用的实际 Bundle ID 和路径
4. ✅ 提供修复建议

### 使用场景

- TCC 数据库显示有权限，但 API 返回 false
- 需要确认系统授权的是哪个 Bundle ID/路径
- 诊断权限不匹配问题

### 示例输出

```
🔍 查询 TCC 数据库中的辅助功能权限

所有辅助功能权限记录:
xyz.keben.EchoFlow|2|1732950000|已授权
xyz.keben.EchoFlow|2|1732864000|已授权  ← 旧 Bundle ID

🔍 查找 EchoFlow 相关记录
xyz.keben.EchoFlow|2|2025-11-30 10:30:00|✅ 已授权
xyz.keben.EchoFlow|2|2025-11-29 15:20:00|✅ 已授权
```

---

## 🚀 quick-release.sh - 快速发布

一键完成版本发布，适合小版本更新和 Bug 修复。

### 用法

```bash
./scripts/quick-release.sh <version> [release_notes]
```

### 示例

```bash
# 发布 1.0.1，带自定义说明
./scripts/quick-release.sh 1.0.1 "修复状态栏图标问题"

# 发布 1.0.2，使用默认说明
./scripts/quick-release.sh 1.0.2
```

### 执行步骤

1. ✅ 验证版本号格式 (X.Y.Z)
2. ✅ 更新 Xcode 项目版本号
3. ✅ 更新 CHANGELOG.md
4. ✅ Git commit
5. ✅ 创建 Git tag (v1.0.1)
6. ✅ 推送到 GitHub
7. ✅ 触发 GitHub Actions 自动构建

---

## 📦 release.sh - 完整发布

完整的发布流程，带交互式确认和更多检查。

### 用法

```bash
./scripts/release.sh <version> [options]
```

### 选项

| 选项 | 说明 |
|------|------|
| `--dry-run` | 测试模式，不执行实际操作 |
| `--no-push` | 不推送到远程仓库 |
| `--help` | 显示帮助信息 |

### 示例

```bash
# 正常发布
./scripts/release.sh 1.0.1

# 测试发布流程（不执行）
./scripts/release.sh 1.0.1 --dry-run

# 只本地操作，不推送
./scripts/release.sh 1.0.1 --no-push
```

### 执行步骤

1. 📋 检查 Git 状态和分支
2. 📝 检查/创建 CHANGELOG 条目
3. 🔢 更新版本号
4. 💾 提交更改
5. 🏷️ 创建 Tag
6. 🚀 推送到远程

### 与 quick-release.sh 的区别

| 功能 | quick-release.sh | release.sh |
|------|-----------------|------------|
| 交互确认 | ❌ | ✅ |
| 分支检查 | ❌ | ✅ |
| CHANGELOG 检查 | 自动添加 | 提示编辑 |
| Dry-run 模式 | ❌ | ✅ |
| 适用场景 | 快速修复 | 正式发布 |

---

## 🧹 clean-git-history.sh - 清理 Git 历史

将所有 Git 历史压缩为单次提交，用于清理项目历史。

### ⚠️ 警告

此操作**不可逆**！会删除所有提交历史和 Tags。

### 用法

```bash
./scripts/clean-git-history.sh [commit_message]
```

### 示例

```bash
# 使用默认提交信息
./scripts/clean-git-history.sh

# 自定义提交信息
./scripts/clean-git-history.sh "🎉 Initial commit: EchoFlow v1.0.0"
```

### 执行步骤

1. 📦 创建备份分支 (backup-YYYYMMDD-HHMMSS)
2. 💾 保存当前更改
3. 🌱 创建孤儿分支
4. 🔄 替换主分支
5. 🧹 清理旧数据
6. ❓ 询问是否推送到远程

### 恢复方法

如果需要恢复：

```bash
git checkout backup-YYYYMMDD-HHMMSS
git branch -D main
git branch -m main
```

---

## 🔄 GitHub Actions 自动化

推送 tag 后，GitHub Actions 会自动执行：

```
.github/workflows/release.yml
```

### 自动构建流程

1. 检出代码
2. 设置 Xcode 环境
3. 更新项目版本号
4. 构建 Release Archive
5. 导出 App
6. 创建 DMG 安装包
7. 创建 ZIP 压缩包
8. 发布到 GitHub Releases

### 触发条件

当推送以 `v` 开头的 tag 时触发：

```yaml
on:
  push:
    tags:
      - 'v*'  # 如 v1.0.0, v1.0.1
```

---

## 📋 版本号规范

遵循 [语义化版本](https://semver.org/lang/zh-CN/) 规范：

```
MAJOR.MINOR.PATCH
主版本.次版本.修订号
```

| 类型 | 何时递增 | 示例 |
|------|---------|------|
| MAJOR | 不兼容的 API 变更 | 1.0.0 → 2.0.0 |
| MINOR | 新功能（向后兼容）| 1.0.0 → 1.1.0 |
| PATCH | Bug 修复 | 1.0.0 → 1.0.1 |

---

## 🛠️ 常用命令速查

```bash
# 快速发布新版本
./scripts/quick-release.sh 1.0.1 "修复问题"

# 测试发布流程
./scripts/release.sh 1.0.1 --dry-run

# 清理 Git 历史（谨慎使用）
./scripts/clean-git-history.sh

# 查看当前版本
agvtool what-marketing-version

# 查看构建号
agvtool what-version

# 检测应用签名
./scripts/check-signature.sh /Applications/EchoFlow.app

# 检测 DMG 签名
./scripts/check-signature.sh EchoFlow-1.0.0.dmg

# 手动创建 tag
git tag -a v1.0.1 -m "Release v1.0.1"
git push origin v1.0.1

# 删除 tag
git tag -d v1.0.1
git push origin --delete v1.0.1
```

---

## 📚 相关文档

- [README.md](../README.md) - 项目说明
- [CHANGELOG.md](../CHANGELOG.md) - 更新日志
- [QUICKSTART.md](../QUICKSTART.md) - 快速开始指南


