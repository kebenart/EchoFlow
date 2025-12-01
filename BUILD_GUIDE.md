# EchoFlow 构建安装包指南

## 📦 快速构建

### 方法一：使用构建脚本（推荐）

```bash
# 使用当前项目版本号构建
./scripts/build-package.sh

# 指定版本号构建
./scripts/build-package.sh 1.0.1
```

### 方法二：在 Xcode 中构建

1. 打开 `EchoFlow.xcodeproj`
2. 选择 **Product** > **Archive**
3. 等待构建完成
4. 在 Organizer 中选择 Archive
5. 点击 **Distribute App**
6. 选择 **Copy App** 或导出为 DMG

## 📁 输出文件

构建完成后，安装包位于 `build/` 目录：

- **DMG 安装包**: `build/EchoFlow-1.0.0.dmg` (约 7.4MB)
- **ZIP 压缩包**: `build/EchoFlow-1.0.0.zip` (约 7.1MB)

## 🚀 安装步骤

### 使用 DMG 安装（推荐）

1. 双击 `EchoFlow-1.0.0.dmg` 文件
2. 将 `EchoFlow.app` 拖入 `Applications` 文件夹
3. 首次运行时：
   - 右键点击 `EchoFlow.app`
   - 选择 **"打开"**
   - 在安全提示中点击 **"打开"**

### 使用 ZIP 安装

1. 解压 `EchoFlow-1.0.0.zip`
2. 将 `EchoFlow.app` 拖入 `Applications` 文件夹
3. 按照上述首次运行步骤操作

## ⚙️ 构建配置

### 代码签名

当前构建脚本使用无签名模式（`CODE_SIGN_IDENTITY="-"`），适合本地测试。

如需发布到 App Store 或进行代码签名：

1. 在 Xcode 中配置 **Signing & Capabilities**
2. 选择你的开发团队
3. 修改构建脚本，移除 `CODE_SIGN_IDENTITY="-"` 参数

### 版本号

版本号从 `EchoFlow.xcodeproj/project.pbxproj` 中的 `MARKETING_VERSION` 读取。

手动修改版本号：

1. 在 Xcode 中：**Project** > **General** > **Identity** > **Version**
2. 或使用命令行：
   ```bash
   agvtool new-marketing-version 1.0.1
   ```

## 🔧 故障排除

### 构建失败

**问题**: `xcodebuild: error: ...`

**解决方案**:
1. 检查 Xcode 是否正确安装
2. 确保 Scheme 名称正确（默认: `EchoFlow`）
3. 清理构建缓存：`Product` > `Clean Build Folder` (⇧⌘K)

### DMG 创建失败

**问题**: `hdiutil: create failed`

**解决方案**:
1. 检查磁盘空间是否充足
2. 确保 `build/dmg-contents` 目录可写
3. 手动清理 `build/` 目录后重试

### 应用无法运行

**问题**: "无法打开，因为来自身份不明的开发者"

**解决方案**:
1. 右键点击应用，选择 **"打开"**
2. 或在 **系统设置** > **隐私与安全性** 中允许运行
3. 使用代码签名可避免此问题

## 📝 相关文档

- [scripts/README.md](scripts/README.md) - 脚本工具说明
- [QUICKSTART.md](QUICKSTART.md) - 快速开始指南
- [README.md](README.md) - 项目说明

## 💡 提示

- 构建前建议先运行测试：`Product` > `Test` (⌘U)
- 可以使用 `--dry-run` 测试构建流程（如果脚本支持）
- 定期清理 `build/` 目录以节省磁盘空间

