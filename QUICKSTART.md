# EchoFlow 快速开始指南

## 🚀 立即运行

### 1. 在 Xcode 中运行

1. 打开 Xcode
2. 选择 `File` > `Open` > 选择 `EchoFlow.xcodeproj`
3. 确保选择了 `EchoFlow` scheme（在顶部工具栏）
4. 点击 Run 按钮 (⌘R) 或者选择 `Product` > `Run`

**重要提示**：
- 首次运行时，Xcode 可能会创建一个空白窗口，这是正常的，应用会自动关闭它
- 应用启动后会立即隐藏，请查看菜单栏右上角

### 2. 应用启动后

应用启动后：

1. **不会看到 Dock 图标** - 这是正常的，EchoFlow 是菜单栏应用
2. **在菜单栏右上角找到图标** - 查找剪贴板图标（📋）
3. **按 `⌘B`** 或点击菜单栏图标来显示面板
4. **空白窗口会自动关闭** - 如果看到空白窗口，会在 0.2 秒后自动关闭

### 3. 授予必要权限

#### 辅助功能权限（自动粘贴功能）

首次点击剪贴板项目时，如果未授权，会弹出提示：

1. 点击 **"打开系统设置"**
2. 在 **"隐私与安全性"** > **"辅助功能"** 中
3. 找到 **EchoFlow** 并启用
4. 重新启动应用

## 📋 基本使用

### 剪贴板功能

1. **自动捕获** - 复制任何内容，EchoFlow 会自动保存
2. **查看历史** - 按 `⌘B` 打开面板
3. **快速粘贴** - 点击任意卡片，内容会自动粘贴到当前应用

### 笔记功能

1. 点击顶部的 **"笔记"** 标签
2. 点击 **"+ 新建笔记"** 卡片
3. 输入笔记内容
4. 自动保存

### 停靠位置

右键点击菜单栏图标 > **"停靠位置"**：

- **Bottom** - 底部停靠（水平布局）
- **Top** - 顶部停靠（水平布局）
- **Left** - 左侧停靠（垂直布局）
- **Right** - 右侧停靠（垂直布局）

### 搜索功能

- **水平模式**：直接在顶部搜索框输入
- **垂直模式**：点击 🔍 图标展开搜索框

## 🎯 支持的内容类型

| 类型 | 图标标识 | 说明 |
|------|---------|------|
| 文本 | TEXT | 普通文本内容 |
| 代码 | CODE | 包含代码关键字的文本 |
| 链接 | LINK | HTTP/HTTPS URL |
| 颜色 | COLOR | 十六进制颜色代码（#RRGGBB）|
| 图片 | IMG | 图片数据 |
| 文件 | FILE | 文件路径 |

## ⚙️ 项目配置说明

### 必需配置

如果你克隆了项目，需要确保以下配置正确：

1. **Bundle Identifier** - 在 Xcode 中设置你自己的 Bundle ID
   - 打开项目设置 > General > Identity
   - 修改 Bundle Identifier（例如：`com.yourname.EchoFlow`）

2. **Signing** - 配置代码签名
   - 打开项目设置 > Signing & Capabilities
   - 选择你的开发团队（Team）

### 可选配置

#### 启用 iCloud 同步

1. 在项目设置中，点击 **+ Capability**
2. 添加 **iCloud**
3. 勾选 **CloudKit**
4. 使用你的 Apple ID 登录

#### 自定义快捷键

默认快捷键为 `⌘B`，可以在设置中自定义：

1. 点击菜单栏图标 → 设置
2. 选择「快捷键」标签
3. 点击「更改」按钮
4. 按下新的快捷键组合（需要包含修饰键如 ⌘、⌥、⌃）

## 🐛 故障排除

### 问题：应用启动后什么都看不到

**解决方案**：
- 检查菜单栏右上角是否有图标
- 按 `⌘B` 尝试唤出面板
- 空白窗口会在启动后自动关闭
- 查看 Xcode 控制台是否有错误信息

### 问题：点击卡片没有自动粘贴

**解决方案**：
1. 确认已授予辅助功能权限
2. 打开 **系统设置** > **隐私与安全性** > **辅助功能**
3. 确保 EchoFlow 已勾选

### 问题：剪贴板历史没有记录

**解决方案**：
- 检查是否从密码管理器复制（这些会被过滤）
- 查看 Xcode 控制台的日志输出
- 确认 PasteboardManager 已启动（应看到 "剪贴板监听已启动"）

### 问题：构建失败

**解决方案**：
1. 清理构建缓存：`Product` > `Clean Build Folder` (⇧⌘K)
2. 确保 Xcode 版本 ≥ 16.0
3. 确保 macOS 版本 ≥ 14.0
4. 检查 Bundle Identifier 和 Signing 配置

## 📁 项目文件说明

### 核心文件

| 文件 | 功能 |
|------|------|
| `EchoFlowApp.swift` | 应用入口和初始化 |
| `AppDelegate.swift` | 菜单栏管理和生命周期 |
| `ClipboardItem.swift` | 剪贴板数据模型 |
| `NoteItem.swift` | 笔记数据模型 |
| `PasteboardManager.swift` | 剪贴板监听和存储 |
| `WindowManager.swift` | 窗口显示和停靠 |
| `HotKeyManager.swift` | 全局快捷键 |
| `PasteSimulator.swift` | 自动粘贴功能 |

### UI 文件

| 文件 | 功能 |
|------|------|
| `RootView.swift` | 主容器视图 |
| `ClipboardListView.swift` | 剪贴板历史列表 |
| `NotesListView.swift` | 笔记列表 |
| `ClipboardCard.swift` | 剪贴板卡片组件 |
| `NoteCard.swift` | 笔记卡片组件 |

### 配置文件

| 文件 | 功能 |
|------|------|
| `Info.plist` | 应用配置（LSUIElement 等）|
| `EchoFlow.entitlements` | 权限配置（CloudKit 等）|

## 🔧 开发调试

### 查看日志

在 Xcode 控制台中查看日志输出：

- `🚀 EchoFlow 启动中...` - 应用启动
- `✅ SwiftData 容器创建成功` - 数据库初始化
- `✅ 主面板创建完成` - 窗口创建
- `📋 剪贴板监听已启动` - 监听启动
- `⌨️ 全局快捷键已注册` - 快捷键注册
- `✅ 已保存 ... 内容` - 内容保存
- `🪟 面板已显示/隐藏` - 窗口状态

### 添加示例数据

在 Xcode 中运行后，复制以下内容来测试：

1. 普通文本：`Hello, World!`
2. 代码：`func greet() { print("Hello") }`
3. 链接：`https://www.apple.com`
4. 颜色：`#FF6B6B`
5. 复制一张图片
6. 复制一个文件

## 📚 下一步

- 阅读 [README.md](README.md) 了解详细功能
- 查看 [需求文档.md](EchoFlow/需求文档.md) 了解产品设计
- 查看 [开发文档.md](EchoFlow/开发文档.md) 了解技术架构
- 查看 [.cursorrules](EchoFlow/.cursorrules) 了解开发规范

## 💡 提示

- 按 `Tab` 键可以快速切换剪贴板和笔记标签
- 使用方向键 `↑↓←→` 导航卡片
- 点击面板外任意位置会自动隐藏面板
- 点击菜单栏图标查看更多选项
- 剪贴板内容会自动去重，不用担心重复保存

## 🚀 发布新版本

如果你是开发者，可以使用内置脚本发布新版本：

```bash
# 快速发布
./scripts/quick-release.sh 1.0.1 "修复问题"

# 完整发布（带交互）
./scripts/release.sh 1.0.1
```

详见 [scripts/README.md](scripts/README.md)

---

祝使用愉快！如有问题请查看 [README.md](README.md) 或 [提交 Issue](https://github.com/kebenart/EchoFlow/issues)。
