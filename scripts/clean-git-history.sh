#!/bin/bash

# =============================================================================
# Git 历史清理脚本
# =============================================================================
#
# 用法:
#   ./scripts/clean-git-history.sh [commit_message]
#
# 示例:
#   ./scripts/clean-git-history.sh "🎉 Initial commit: EchoFlow v1.0.0"
#
# 功能:
#   1. 备份当前分支
#   2. 清理所有 Git 历史
#   3. 创建单次初始提交
#   4. 可选推送到远程
#
# =============================================================================

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认提交信息
DEFAULT_MESSAGE="🎉 Initial commit: EchoFlow v1.0.0"
COMMIT_MESSAGE="${1:-$DEFAULT_MESSAGE}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo ""
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║              ⚠️  Git 历史清理脚本                          ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查是否在 git 仓库中
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ 当前目录不是 Git 仓库${NC}"
    exit 1
fi

# 显示当前状态
CURRENT_BRANCH=$(git branch --show-current)
COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "无远程仓库")

echo -e "${BLUE}📋 当前状态:${NC}"
echo -e "   分支: ${GREEN}$CURRENT_BRANCH${NC}"
echo -e "   提交数: ${GREEN}$COMMIT_COUNT${NC}"
echo -e "   远程: ${GREEN}$REMOTE_URL${NC}"
echo ""

# 警告
echo -e "${RED}⚠️  警告: 此操作将删除所有 Git 历史记录！${NC}"
echo -e "${RED}   - 所有提交历史将被清除${NC}"
echo -e "${RED}   - 所有 Tag 将被删除${NC}"
echo -e "${RED}   - 此操作不可逆！${NC}"
echo ""

# 确认
read -p "确定要继续吗? (输入 'yes' 确认): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}已取消${NC}"
    exit 0
fi

echo ""

# Step 1: 备份当前分支
echo -e "${BLUE}📦 Step 1/5: 创建备份分支...${NC}"
BACKUP_BRANCH="backup-$(date +%Y%m%d-%H%M%S)"
git branch "$BACKUP_BRANCH"
echo -e "${GREEN}   ✅ 已创建备份: $BACKUP_BRANCH${NC}"

# Step 2: 保存所有更改
echo -e "${BLUE}💾 Step 2/5: 保存当前更改...${NC}"
git add -A
git commit -m "Temp save before cleanup" 2>/dev/null || echo -e "${YELLOW}   没有新的更改需要保存${NC}"

# Step 3: 创建孤儿分支
echo -e "${BLUE}🌱 Step 3/5: 创建新的历史...${NC}"
git checkout --orphan temp_clean_branch

# 添加所有文件
git add -A

# 创建新的初始提交
git commit -m "$COMMIT_MESSAGE"
echo -e "${GREEN}   ✅ 已创建新的初始提交${NC}"

# Step 4: 替换主分支
echo -e "${BLUE}🔄 Step 4/5: 替换主分支...${NC}"
git branch -D "$CURRENT_BRANCH"
git branch -m "$CURRENT_BRANCH"
echo -e "${GREEN}   ✅ 主分支已更新${NC}"

# Step 5: 清理
echo -e "${BLUE}🧹 Step 5/5: 清理旧数据...${NC}"
git gc --aggressive --prune=all
echo -e "${GREEN}   ✅ 清理完成${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    ✅ 清理完成!                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 显示结果
NEW_COMMIT_COUNT=$(git rev-list --count HEAD)
echo -e "${BLUE}📊 清理结果:${NC}"
echo -e "   之前提交数: ${YELLOW}$COMMIT_COUNT${NC}"
echo -e "   现在提交数: ${GREEN}$NEW_COMMIT_COUNT${NC}"
echo -e "   备份分支: ${GREEN}$BACKUP_BRANCH${NC}"
echo ""

# 询问是否推送
echo -e "${YELLOW}是否要强制推送到远程仓库?${NC}"
echo -e "${RED}⚠️  这将覆盖远程仓库的所有历史！${NC}"
read -p "推送到远程? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🚀 推送到远程...${NC}"
    
    # 删除远程所有 tag
    echo -e "${BLUE}   删除远程 tags...${NC}"
    git push origin --delete $(git ls-remote --tags origin | awk -F/ '{print $3}') 2>/dev/null || true
    
    # 删除本地所有 tag
    git tag -l | xargs git tag -d 2>/dev/null || true
    
    # 强制推送
    git push -f origin "$CURRENT_BRANCH"
    
    echo -e "${GREEN}✅ 已推送到远程仓库${NC}"
else
    echo ""
    echo -e "${YELLOW}📝 如需稍后推送，请运行:${NC}"
    echo -e "   ${BLUE}git push -f origin $CURRENT_BRANCH${NC}"
fi

echo ""
echo -e "${YELLOW}📝 如需恢复，请运行:${NC}"
echo -e "   ${BLUE}git checkout $BACKUP_BRANCH${NC}"
echo -e "   ${BLUE}git branch -D $CURRENT_BRANCH${NC}"
echo -e "   ${BLUE}git branch -m $CURRENT_BRANCH${NC}"
echo ""
