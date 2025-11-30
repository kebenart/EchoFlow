# EchoFlow

<div align="center">

**专为 macOS 设计的高性能原生剪贴板管理工具**

<img src="https://img.shields.io/badge/macOS-14.0+-blue.svg" alt="macOS 14.0+">
<img src="https://img.shields.io/badge/Swift-5.9+-orange.svg" alt="Swift 5.9+">
<img src="https://img.shields.io/badge/SwiftUI-Native-green.svg" alt="SwiftUI">
<img src="https://img.shields.io/badge/License-MIT-green.svg" alt="MIT License">

[下载最新版本](https://github.com/kebenart/EchoFlow/releases/latest) · [问题反馈](https://github.com/kebenart/EchoFlow/issues)

</div>

---

## ✨ 功能特性

- **🚀 零延迟启动** - 原生 Swift 实现，毫秒级响应
- **🪟 原生玻璃拟态** - 使用 macOS 原生 Material 效果
- **📍 四向停靠** - 支持屏幕底部、顶部、左侧、右侧停靠
- **🎯 智能识别** - 自动识别文本、图片、链接、颜色、代码、文件
- **⚡ 自动粘贴** - 一键粘贴到当前应用
- **📝 笔记功能** - 快速创建和管理轻量笔记
- **☁️ iCloud 同步** - 多设备无缝同步（可选）
- **⌨️ 全局快捷键** - 默认 `⌘B` 快速唤出
- **🔄 自动更新** - 内置更新检测，一键升级

---

## 📥 安装

### 方式一：下载安装包（推荐）

1. 前往 [Releases 页面](https://github.com/kebenart/EchoFlow/releases/latest)
2. 下载 `EchoFlow-x.x.x.dmg`
3. 打开 DMG，将 EchoFlow 拖入 Applications 文件夹
4. 首次运行时，右键选择"打开"以绕过 Gatekeeper

### 方式二：从源码构建

```bash
git clone https://github.com/kebenart/EchoFlow.git
cd EchoFlow
open EchoFlow.xcodeproj
```

在 Xcode 中按 `⌘R` 运行。

---

## 🎯 快速开始

### 1. 启动应用

- 应用启动后会显示在 **菜单栏**（状态栏）
- 不会在 Dock 中显示图标

### 2. 唤出面板

- **快捷键**: `⌘B`（可在设置中自定义）
- **鼠标**: 点击菜单栏图标

### 3. 基本操作

| 操作 | 方式 |
|------|------|
| 复制项目 | 点击卡片 |
| 切换标签 | 按 `Tab` 键 |
| 导航卡片 | 方向键 `↑↓←→` |
| 删除项目 | 选中后按 `⌫` |
| 隐藏面板 | 按 `ESC` 或点击外部 |

### 4. 授予权限

首次使用自动粘贴功能时，需要授予辅助功能权限：

1. 打开 **系统设置** → **隐私与安全性** → **辅助功能**
2. 找到并启用 **EchoFlow**

---

## ⌨️ 快捷键

### 全局快捷键

| 快捷键 | 功能 |
|--------|------|
| `⌘B` | 显示/隐藏面板（可自定义）|

### 面板内快捷键

| 快捷键 | 功能 |
|--------|------|
| `Tab` | 切换剪贴板/笔记标签 |
| `↑↓←→` | 导航卡片 |
| `⌘C` / `⏎` | 复制选中项 |
| `⌫` | 删除选中项 |
| `ESC` | 隐藏面板 |

---

## 🎨 支持的内容类型

| 类型 | 识别标识 | 说明 |
|------|---------|------|
| 📝 文本 | TEXT | 普通文本内容 |
| 💻 代码 | CODE | 包含代码关键字的文本 |
| 🔗 链接 | LINK | HTTP/HTTPS URL |
| 🎨 颜色 | COLOR | 十六进制颜色代码 |
| 🖼️ 图片 | IMG | 图片数据 |
| 📁 文件 | FILE | 文件路径 |

---

## ⚙️ 设置

点击菜单栏图标，选择「设置」打开设置面板：

- **通用** - 停靠位置、复制行为、历史保留时间等
- **规则** - 去重设置、链接预览、颜色采样算法
- **快捷键** - 自定义全局快捷键
- **关于** - 版本信息、检查更新

---

## 🛠️ 技术栈

- **Swift 5.9+** - 现代 Swift 特性
- **SwiftUI** - 声明式 UI 框架
- **SwiftData** - 现代化数据持久层
- **CloudKit** - 苹果原生云同步
- **AppKit** - 高级窗口管理

---

## 📁 项目结构

```
EchoFlow/
├── App/
│   ├── EchoFlowApp.swift      # 应用入口
│   └── AppDelegate.swift      # 生命周期管理
├── Core/
│   ├── Models/                # 数据模型
│   ├── Managers/              # 核心管理器
│   └── Utils/                 # 工具类
├── UI/
│   ├── Components/            # UI 组件
│   └── Screens/               # 主要视图
├── scripts/                   # 自动化脚本
│   ├── release.sh             # 完整发布脚本
│   ├── quick-release.sh       # 快速发布脚本
│   └── clean-git-history.sh   # Git 历史清理
└── .github/workflows/         # GitHub Actions
```

---

## 🚀 发布新版本

使用内置脚本快速发布：

```bash
# 快速发布
./scripts/quick-release.sh 1.0.1 "修复问题"

# 完整发布（带交互）
./scripts/release.sh 1.0.1

# 测试发布流程
./scripts/release.sh 1.0.1 --dry-run
```

详见 [scripts/README.md](scripts/README.md)

---

## 🔮 开发计划

### 近期 (v1.1.0)
- 完善分类系统
- 自定义标签功能
- 数据导出/导入（备份功能）

### 中期 (v1.2.0)
- iCloud 云同步完善
- 多设备实时同步状态
- Markdown 笔记支持

### 长期 (v2.0.0)
- 📱 iPhone / iPad 版本
- 🤖 Android 版本
- 🖥️ Windows 版本
- 🔄 多端数据同步
- ☁️ 云端备份与恢复

详见 [CHANGELOG.md](CHANGELOG.md)

---

## 🐛 常见问题

<details>
<summary><b>Q: 自动粘贴不工作？</b></summary>

请确保已在系统设置中授予 EchoFlow 辅助功能权限。
</details>

<details>
<summary><b>Q: 如何更改全局快捷键？</b></summary>

打开设置 → 快捷键 → 点击「更改」按钮 → 按下新的快捷键组合。
</details>

<details>
<summary><b>Q: 面板位置可以拖动吗？</b></summary>

不可以。面板位置固定，可在设置中更改停靠位置（底部/顶部/左侧/右侧）。
</details>

<details>
<summary><b>Q: 数据存储在哪里？</b></summary>

数据使用 SwiftData 存储在应用沙盒中。启用 CloudKit 后会同步到 iCloud。
</details>

---

## 📄 许可证

[MIT License](LICENSE)

---

## 🙏 致谢

- 感谢 Apple 提供优秀的开发框架
- 感谢所有贡献者和测试用户

---

<div align="center">

**Made with ❤️ using pure Swift**

[⬆ 返回顶部](#echoflow)

</div>
