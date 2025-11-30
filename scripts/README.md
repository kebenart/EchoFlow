# EchoFlow 脚本工具

本目录包含 EchoFlow 项目的自动化脚本工具。

## 📁 脚本列表

| 脚本 | 用途 | 使用频率 |
|------|------|---------|
| `release.sh` | 完整发布流程 | 正式发布 |
| `quick-release.sh` | 快速发布 | 热修复/小版本 |
| `clean-git-history.sh` | 清理 Git 历史 | 初始化/重置 |

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
