#!/bin/bash

# =============================================================================
# EchoFlow 快速发布脚本
# =============================================================================
# 
# 用法:
#   ./scripts/quick-release.sh <version> [release_notes]
#
# 示例:
#   ./scripts/quick-release.sh 1.0.1 "修复状态栏图标问题"
#
# =============================================================================

set -e

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

VERSION=$1
NOTES=${2:-"Bug fixes and improvements"}

if [ -z "$VERSION" ]; then
    echo -e "${RED}❌ 请指定版本号${NC}"
    echo "用法: $0 <version> [release_notes]"
    echo "示例: $0 1.0.1 \"修复状态栏图标问题\""
    exit 1
fi

# 验证版本号格式
if [[ ! $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}❌ 无效的版本号格式: $VERSION${NC}"
    echo "版本号应该是 X.Y.Z 格式 (例如: 1.0.0)"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo ""
echo -e "${GREEN}🚀 EchoFlow 快速发布${NC}"
echo -e "${BLUE}版本: v$VERSION${NC}"
echo -e "${BLUE}说明: $NOTES${NC}"
echo ""

# 检查 tag 是否已存在
if git tag -l "v$VERSION" | grep -q "v$VERSION"; then
    echo -e "${RED}❌ Tag v$VERSION 已存在${NC}"
    exit 1
fi

# 获取当前版本
CURRENT_VERSION=$(agvtool what-marketing-version -terse1 2>/dev/null || echo "未知")
echo -e "${BLUE}当前版本: $CURRENT_VERSION${NC}"
echo -e "${BLUE}目标版本: $VERSION${NC}"
echo ""

# 1. 更新版本号 (多种方式确保更新成功)
echo -e "${YELLOW}📝 更新版本号...${NC}"

# 方式1: 使用 agvtool
agvtool new-marketing-version "$VERSION" 2>/dev/null || true
agvtool next-version -all 2>/dev/null || true

# 方式2: 直接更新 Info.plist (如果存在)
INFO_PLIST="$PROJECT_DIR/EchoFlow/Info.plist"
if [ -f "$INFO_PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST" 2>/dev/null || true
    echo -e "${GREEN}  ✓ 已更新 Info.plist${NC}"
fi

# 方式3: 更新 project.pbxproj 中的版本号
PBXPROJ="$PROJECT_DIR/EchoFlow.xcodeproj/project.pbxproj"
if [ -f "$PBXPROJ" ]; then
    # 更新 MARKETING_VERSION (支持 X.Y 和 X.Y.Z 格式)
    sed -i '' "s/MARKETING_VERSION = [0-9]*\.[0-9]*\(\.[0-9]*\)*/MARKETING_VERSION = $VERSION/g" "$PBXPROJ" 2>/dev/null || true
    echo -e "${GREEN}  ✓ 已更新 project.pbxproj${NC}"
fi

# 验证版本号更新
NEW_VERSION=$(agvtool what-marketing-version -terse1 2>/dev/null || echo "未知")
echo -e "${GREEN}  ✓ 版本号已更新为: $NEW_VERSION${NC}"

# 2. 更新 CHANGELOG
echo -e "${YELLOW}📋 更新 CHANGELOG...${NC}"
DATE=$(date +%Y-%m-%d)

if [ -f "CHANGELOG.md" ]; then
    # 检查是否已有该版本
    if grep -q "## \[v$VERSION\]" CHANGELOG.md; then
        echo -e "${BLUE}  ℹ️  CHANGELOG 已包含 v$VERSION${NC}"
    else
        # 创建临时文件，在第一个版本条目前插入新版本
        TEMP_FILE=$(mktemp)
        
        # 写入标题
        echo "# 更新日志" > "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        
        # 写入新版本
        echo "## [v$VERSION] - $DATE" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        echo "### Changed" >> "$TEMP_FILE"
        echo "- $NOTES" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        echo "---" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        
        # 追加旧内容（跳过标题行）
        tail -n +3 CHANGELOG.md >> "$TEMP_FILE"
        
        mv "$TEMP_FILE" CHANGELOG.md
        echo -e "${GREEN}  ✓ 已添加 v$VERSION 到 CHANGELOG${NC}"
    fi
else
    # 创建新的 CHANGELOG
    cat > CHANGELOG.md << EOF
# 更新日志

## [v$VERSION] - $DATE

### Changed
- $NOTES

---
EOF
    echo -e "${GREEN}  ✓ 已创建 CHANGELOG.md${NC}"
fi

# 3. 提交
echo -e "${YELLOW}💾 提交更改...${NC}"
git add -A

# 检查是否有更改需要提交
if git diff --cached --quiet; then
    echo -e "${BLUE}  ℹ️  没有新的更改需要提交${NC}"
else
    git commit -m "chore: release v$VERSION - $NOTES"
    echo -e "${GREEN}  ✓ 已提交更改${NC}"
fi

# 4. 创建 tag
echo -e "${YELLOW}🏷️  创建 Tag...${NC}"
git tag -a "v$VERSION" -m "Release v$VERSION: $NOTES"
echo -e "${GREEN}  ✓ 已创建 tag v$VERSION${NC}"

# 5. 推送
echo -e "${YELLOW}🚀 推送到 GitHub...${NC}"
BRANCH=$(git branch --show-current)
git push origin "$BRANCH"
git push origin "v$VERSION"
echo -e "${GREEN}  ✓ 已推送到远程仓库${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    🎉 发布成功!                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "版本: ${GREEN}v$VERSION${NC}"
echo -e "说明: $NOTES"
echo ""
echo -e "GitHub Actions 正在自动构建..."
echo -e "查看进度: ${BLUE}https://github.com/kebenart/EchoFlow/actions${NC}"
echo -e "发布页面: ${BLUE}https://github.com/kebenart/EchoFlow/releases${NC}"
echo ""
