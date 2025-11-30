#!/bin/bash

# =============================================================================
# EchoFlow Release Script
# =============================================================================
# 
# 用法:
#   ./scripts/release.sh <version>
#   ./scripts/release.sh 1.0.0
#   ./scripts/release.sh 1.0.0 --dry-run   # 仅测试，不实际执行
#
# 功能:
#   1. 更新项目版本号
#   2. 更新 CHANGELOG.md (如果未更新)
#   3. 提交所有更改
#   4. 创建 Git tag
#   5. 推送到远程仓库
#   6. 触发 GitHub Actions 自动构建和发布
#
# =============================================================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_NAME="EchoFlow"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODEPROJ="${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj"
CHANGELOG_FILE="${PROJECT_DIR}/CHANGELOG.md"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📦 $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# 显示使用帮助
show_help() {
    echo "EchoFlow Release Script"
    echo ""
    echo "用法:"
    echo "  $0 <version> [options]"
    echo ""
    echo "参数:"
    echo "  version     版本号 (例如: 1.0.0, 1.2.3)"
    echo ""
    echo "选项:"
    echo "  --dry-run   仅测试，不实际执行任何操作"
    echo "  --no-push   不推送到远程仓库"
    echo "  --help      显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 1.0.0              # 发布版本 1.0.0"
    echo "  $0 1.0.0 --dry-run    # 测试发布流程"
    echo ""
}

# 验证版本号格式
validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "无效的版本号格式: $version"
        print_info "版本号应该是 X.Y.Z 格式 (例如: 1.0.0)"
        exit 1
    fi
}

# 检查是否有未提交的更改
check_git_status() {
    if [[ -n $(git -C "$PROJECT_DIR" status --porcelain) ]]; then
        return 1
    fi
    return 0
}

# 获取当前版本
get_current_version() {
    cd "$PROJECT_DIR"
    agvtool what-marketing-version -terse1 2>/dev/null || echo "0.0.0"
}

# 更新 Xcode 项目版本号
update_xcode_version() {
    local version=$1
    print_info "更新 Xcode 项目版本号为 $version..."
    
    cd "$PROJECT_DIR"
    
    # 方式1: 使用 agvtool 更新版本号
    agvtool new-marketing-version "$version" 2>/dev/null || true
    agvtool next-version -all 2>/dev/null || true
    
    # 方式2: 直接更新 Info.plist (如果存在)
    local info_plist="$PROJECT_DIR/EchoFlow/Info.plist"
    if [ -f "$info_plist" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$info_plist" 2>/dev/null || true
        print_info "已更新 Info.plist"
    fi
    
    # 方式3: 更新 project.pbxproj 中的版本号
    local pbxproj="$PROJECT_DIR/EchoFlow.xcodeproj/project.pbxproj"
    if [ -f "$pbxproj" ]; then
        # 支持 X.Y 和 X.Y.Z 格式
        sed -i '' "s/MARKETING_VERSION = [0-9]*\.[0-9]*\(\.[0-9]*\)*/MARKETING_VERSION = $version/g" "$pbxproj" 2>/dev/null || true
        print_info "已更新 project.pbxproj"
    fi
    
    # 验证版本号
    local new_version=$(agvtool what-marketing-version -terse1 2>/dev/null || echo "未知")
    print_success "版本号已更新为: $new_version"
}

# 检查 CHANGELOG 是否包含当前版本
check_changelog() {
    local version=$1
    if [ -f "$CHANGELOG_FILE" ]; then
        if grep -q "## \[v$version\]\|## v$version\|## $version" "$CHANGELOG_FILE"; then
            return 0
        fi
    fi
    return 1
}

# 添加 CHANGELOG 条目模板
add_changelog_entry() {
    local version=$1
    local date=$(date +%Y-%m-%d)
    
    if [ ! -f "$CHANGELOG_FILE" ]; then
        # 创建新的 CHANGELOG
        cat > "$CHANGELOG_FILE" << EOF
# Changelog

All notable changes to this project will be documented in this file.

## [v$version] - $date

### Added
- Initial release

### Changed
- N/A

### Fixed
- N/A

EOF
    else
        # 在文件开头添加新版本条目
        local temp_file=$(mktemp)
        cat > "$temp_file" << EOF
# Changelog

All notable changes to this project will be documented in this file.

## [v$version] - $date

### Added
- 

### Changed
- 

### Fixed
- 

EOF
        # 提取旧内容（跳过标题）
        tail -n +4 "$CHANGELOG_FILE" >> "$temp_file"
        mv "$temp_file" "$CHANGELOG_FILE"
    fi
    
    print_warning "已创建 CHANGELOG 模板，请编辑 CHANGELOG.md 添加更新说明"
}

# 主函数
main() {
    local version=""
    local dry_run=false
    local no_push=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --no-push)
                no_push=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                if [[ -z "$version" ]]; then
                    version=$1
                fi
                shift
                ;;
        esac
    done
    
    # 检查版本号
    if [[ -z "$version" ]]; then
        print_error "请指定版本号"
        show_help
        exit 1
    fi
    
    validate_version "$version"
    
    # 显示发布信息
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    EchoFlow 发布脚本                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local current_version=$(get_current_version)
    print_info "当前版本: $current_version"
    print_info "目标版本: $version"
    
    if $dry_run; then
        print_warning "Dry Run 模式 - 不会执行实际操作"
    fi
    
    # Step 1: 检查 Git 状态
    print_step "Step 1/6: 检查 Git 状态"
    
    cd "$PROJECT_DIR"
    
    # 检查是否在 git 仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "当前目录不是 Git 仓库"
        exit 1
    fi
    
    # 检查当前分支
    local current_branch=$(git branch --show-current)
    print_info "当前分支: $current_branch"
    
    if [[ "$current_branch" != "main" && "$current_branch" != "master" ]]; then
        print_warning "当前不在 main/master 分支，请确认是否要从 $current_branch 分支发布"
        read -p "继续? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "已取消"
            exit 0
        fi
    fi
    
    # 检查 tag 是否已存在
    if git tag -l "v$version" | grep -q "v$version"; then
        print_error "Tag v$version 已存在"
        exit 1
    fi
    
    print_success "Git 状态检查通过"
    
    # Step 2: 检查 CHANGELOG
    print_step "Step 2/6: 检查 CHANGELOG"
    
    if ! check_changelog "$version"; then
        print_warning "CHANGELOG.md 中没有找到版本 $version 的记录"
        add_changelog_entry "$version"
        
        if ! $dry_run; then
            print_info "请编辑 CHANGELOG.md 后重新运行此脚本"
            print_info "或者使用 --dry-run 参数测试"
            
            # 打开编辑器
            if command -v code &> /dev/null; then
                code "$CHANGELOG_FILE"
            elif command -v nano &> /dev/null; then
                nano "$CHANGELOG_FILE"
            fi
            
            exit 0
        fi
    else
        print_success "CHANGELOG 已包含版本 $version 的记录"
    fi
    
    # Step 3: 更新版本号
    print_step "Step 3/6: 更新版本号"
    
    if ! $dry_run; then
        update_xcode_version "$version"
    else
        print_info "[Dry Run] 将更新版本号为 $version"
    fi
    
    # Step 4: 提交更改
    print_step "Step 4/6: 提交更改"
    
    if ! $dry_run; then
        git add -A
        
        if ! check_git_status; then
            git commit -m "chore: bump version to $version"
            print_success "已提交更改"
        else
            print_info "没有需要提交的更改"
        fi
    else
        print_info "[Dry Run] 将提交版本更新"
    fi
    
    # Step 5: 创建 Tag
    print_step "Step 5/6: 创建 Git Tag"
    
    if ! $dry_run; then
        git tag -a "v$version" -m "Release v$version"
        print_success "已创建 tag: v$version"
    else
        print_info "[Dry Run] 将创建 tag: v$version"
    fi
    
    # Step 6: 推送到远程
    print_step "Step 6/6: 推送到远程仓库"
    
    if ! $dry_run && ! $no_push; then
        print_info "推送提交..."
        git push origin "$current_branch"
        
        print_info "推送 tag..."
        git push origin "v$version"
        
        print_success "已推送到远程仓库"
    else
        if $dry_run; then
            print_info "[Dry Run] 将推送到远程仓库"
        fi
        if $no_push; then
            print_warning "已跳过推送 (--no-push)"
        fi
    fi
    
    # 完成
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                      🎉 发布完成!                           ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_success "版本 v$version 已发布!"
    echo ""
    print_info "GitHub Actions 将自动:"
    print_info "  1. 构建 Release 版本"
    print_info "  2. 创建 DMG 和 ZIP 安装包"
    print_info "  3. 发布到 GitHub Releases"
    echo ""
    print_info "查看构建状态: https://github.com/kebenart/EchoFlow/actions"
    print_info "查看发布页面: https://github.com/kebenart/EchoFlow/releases"
    echo ""
}

# 运行主函数
main "$@"
