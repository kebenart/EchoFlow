#!/bin/bash

# =============================================================================
# EchoFlow 权限修复脚本
# =============================================================================
# 
# 用法:
#   ./scripts/fix-permissions.sh
#
# 功能:
#   1. 显示当前辅助功能权限状态
#   2. 提供清理权限的选项
#   3. 重新授权指南
#
# =============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo -e "${BLUE}🔧 $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# 检查辅助功能权限
check_permissions() {
    print_step "检查当前权限状态"
    
    echo "正在检查辅助功能权限..."
    echo ""
    
    # 使用 tccutil 检查（如果可用）
    if command -v tccutil &> /dev/null; then
        print_info "使用 tccutil 检查权限..."
        tccutil reset Accessibility xyz.keben.EchoFlow 2>/dev/null && print_success "已重置 EchoFlow 权限" || print_warning "无法重置（可能需要管理员权限）"
        tccutil reset Accessibility xyz.keben.EchoFlow.debug 2>/dev/null && print_success "已重置 EchoFlow.debug 权限" || print_warning "无法重置（可能需要管理员权限）"
    else
        print_warning "tccutil 不可用，需要手动清理"
    fi
    
    echo ""
    print_info "请按照以下步骤手动清理权限："
}

# 显示清理步骤
show_cleanup_steps() {
    print_step "权限清理步骤"
    
    echo "1️⃣  打开系统设置"
    echo "   - 点击 Apple 菜单 > 系统设置"
    echo "   - 或按 ⌘, 打开系统设置"
    echo ""
    
    echo "2️⃣  进入隐私与安全性"
    echo "   - 在左侧边栏找到"隐私与安全性""
    echo "   - 点击进入"
    echo ""
    
    echo "3️⃣  打开辅助功能设置"
    echo "   - 在右侧找到"辅助功能""
    echo "   - 点击右侧的"i"图标或直接点击进入"
    echo ""
    
    echo "4️⃣  清理 EchoFlow 相关权限"
    echo "   - 查找以下应用（如果存在）："
    echo "     • EchoFlow"
    echo "     • EchoFlow (Debug)"
    echo "     • EchoFlow.app（任何路径下的）"
    echo "   - 取消勾选所有 EchoFlow 相关项"
    echo "   - 或者点击减号按钮删除"
    echo ""
    
    echo "5️⃣  关闭系统设置"
    echo "   - 关闭系统设置窗口"
    echo ""
    
    echo "6️⃣  清理应用缓存（可选）"
    echo "   - 删除以下目录（如果存在）："
    echo "     ~/Library/Preferences/xyz.keben.EchoFlow.plist"
    echo "     ~/Library/Preferences/xyz.keben.EchoFlow.debug.plist"
    echo ""
}

# 显示重新授权步骤
show_reauth_steps() {
    print_step "重新授权步骤"
    
    echo "清理完成后，需要重新授权："
    echo ""
    
    echo "📱 对于 Debug 版本（Xcode 运行）："
    echo "   1. 在 Xcode 中运行应用（⌘R）"
    echo "   2. 点击任意剪贴板卡片触发权限提示"
    echo "   3. 点击\"打开系统设置\""
    echo "   4. 在辅助功能中查找\"EchoFlow (Debug)\""
    echo "   5. 勾选授权"
    echo ""
    
    echo "📦 对于 Release 版本（正式安装）："
    echo "   1. 从 /Applications 运行应用"
    echo "   2. 点击任意剪贴板卡片触发权限提示"
    echo "   3. 点击\"打开系统设置\""
    echo "   4. 在辅助功能中查找\"EchoFlow\""
    echo "   5. 勾选授权"
    echo ""
}

# 清理缓存文件
clean_cache() {
    print_step "清理应用缓存"
    
    local cleaned=false
    
    # 清理 UserDefaults
    if [ -f "$HOME/Library/Preferences/xyz.keben.EchoFlow.plist" ]; then
        rm -f "$HOME/Library/Preferences/xyz.keben.EchoFlow.plist"
        print_success "已删除 EchoFlow UserDefaults"
        cleaned=true
    fi
    
    if [ -f "$HOME/Library/Preferences/xyz.keben.EchoFlow.debug.plist" ]; then
        rm -f "$HOME/Library/Preferences/xyz.keben.EchoFlow.debug.plist"
        print_success "已删除 EchoFlow.debug UserDefaults"
        cleaned=true
    fi
    
    # 清理 SwiftData 数据库（如果存在）
    local db_path="$HOME/Library/Application Support/xyz.keben.EchoFlow"
    if [ -d "$db_path" ]; then
        print_warning "发现 SwiftData 数据库：$db_path"
        read -p "是否删除数据库？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$db_path"
            print_success "已删除数据库"
            cleaned=true
        fi
    fi
    
    local db_path_debug="$HOME/Library/Application Support/xyz.keben.EchoFlow.debug"
    if [ -d "$db_path_debug" ]; then
        print_warning "发现 Debug 版本数据库：$db_path_debug"
        read -p "是否删除数据库？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$db_path_debug"
            print_success "已删除 Debug 数据库"
            cleaned=true
        fi
    fi
    
    if [ "$cleaned" = false ]; then
        print_info "未找到需要清理的缓存文件"
    fi
}

# 打开系统设置
open_settings() {
    print_info "正在打开系统设置..."
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    print_success "已打开辅助功能设置页面"
}

# 主菜单
show_menu() {
    echo ""
    print_step "EchoFlow 权限修复工具"
    echo ""
    echo "请选择操作："
    echo ""
    echo "  1) 显示清理步骤（推荐）"
    echo "  2) 打开系统设置"
    echo "  3) 清理应用缓存"
    echo "  4) 显示重新授权步骤"
    echo "  5) 执行完整清理流程"
    echo "  6) 退出"
    echo ""
    read -p "请输入选项 (1-6): " choice
    
    case $choice in
        1)
            show_cleanup_steps
            show_reauth_steps
            ;;
        2)
            open_settings
            ;;
        3)
            clean_cache
            ;;
        4)
            show_reauth_steps
            ;;
        5)
            check_permissions
            show_cleanup_steps
            clean_cache
            open_settings
            show_reauth_steps
            ;;
        6)
            print_info "退出"
            exit 0
            ;;
        *)
            print_error "无效选项"
            show_menu
            ;;
    esac
}

# 主函数
main() {
    # 检查是否在 macOS 上运行
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "此脚本只能在 macOS 上运行"
        exit 1
    fi
    
    show_menu
}

# 运行主函数
main "$@"

