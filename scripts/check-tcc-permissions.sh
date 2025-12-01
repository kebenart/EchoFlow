#!/bin/bash

# =============================================================================
# 检查 TCC 数据库中的辅助功能权限
# =============================================================================
# 
# 用法:
#   ./scripts/check-tcc-permissions.sh
#
# 功能:
#   1. 查询 TCC 数据库中所有辅助功能权限
#   2. 显示 EchoFlow 相关的权限记录
#   3. 对比应用的实际 Bundle ID 和路径
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
    echo -e "${BLUE}🔍 $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# 检查是否有管理员权限
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        print_warning "此脚本需要管理员权限来访问 TCC 数据库"
        print_info "请使用: sudo $0"
        exit 1
    fi
}

# 查询 TCC 数据库
query_tcc_database() {
    local tcc_db="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
    
    if [ ! -f "$tcc_db" ]; then
        print_error "TCC 数据库不存在: $tcc_db"
        exit 1
    fi
    
    print_step "查询 TCC 数据库中的辅助功能权限"
    
    echo "所有辅助功能权限记录:"
    echo ""
    sqlite3 "$tcc_db" "SELECT 
        client,
        auth_value,
        last_modified,
        CASE 
            WHEN auth_value = 2 THEN '已授权'
            WHEN auth_value = 0 THEN '未授权'
            ELSE '未知'
        END as status
    FROM access 
    WHERE service = 'kTCCServiceAccessibility'
    ORDER BY last_modified DESC;" 2>/dev/null || {
        print_error "无法查询 TCC 数据库"
        print_info "请确保使用 sudo 运行此脚本"
        exit 1
    }
    
    echo ""
    print_step "查找 EchoFlow 相关记录"
    
    echo "EchoFlow 相关权限（包含 CSReq）:"
    echo ""
    sqlite3 "$tcc_db" "SELECT 
        client,
        auth_value,
        datetime(last_modified, 'unixepoch', 'localtime') as last_modified_time,
        CASE 
            WHEN auth_value = 2 THEN '✅ 已授权'
            WHEN auth_value = 0 THEN '❌ 未授权'
            ELSE '❓ 未知'
        END as status,
        CASE 
            WHEN csreq IS NULL THEN '无签名要求'
            WHEN length(csreq) = 0 THEN '空签名要求'
            ELSE '有签名要求 (' || length(csreq) || ' bytes)'
        END as csreq_info
    FROM access 
    WHERE service = 'kTCCServiceAccessibility'
    AND (client LIKE '%EchoFlow%' OR client LIKE '%echoflow%')
    ORDER BY last_modified DESC;" 2>/dev/null
    
    echo ""
    print_info "💡 CSReq (Code Signing Requirement) 说明:"
    echo "   - CSReq 是代码签名要求的二进制数据"
    echo "   - 如果应用的签名与 CSReq 不匹配，API 会返回 false"
    echo "   - 即使 Bundle ID 和路径匹配，签名不匹配也会导致权限失效"
    echo ""
}

# 显示应用信息
show_app_info() {
    print_step "当前应用信息"
    
    # 尝试从多个位置获取应用信息
    local app_paths=(
        "/Applications/EchoFlow.app"
        "$HOME/Applications/EchoFlow.app"
    )
    
    # 查找 DerivedData 中的应用
    local derived_data_paths=$(find ~/Library/Developer/Xcode/DerivedData -name "EchoFlow.app" -type d 2>/dev/null | head -1)
    
    if [ -n "$derived_data_paths" ]; then
        app_paths+=("$derived_data_paths")
    fi
    
    for app_path in "${app_paths[@]}"; do
        if [ -d "$app_path" ]; then
            print_info "找到应用: $app_path"
            
            # 获取 Bundle ID
            local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app_path/Contents/Info.plist" 2>/dev/null)
            if [ -n "$bundle_id" ]; then
                echo "   Bundle ID: $bundle_id"
            fi
            
            # 获取应用名称
            local app_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$app_path/Contents/Info.plist" 2>/dev/null)
            if [ -n "$app_name" ]; then
                echo "   应用名称: $app_name"
            fi
            
            # 检查代码签名
            echo "   代码签名:"
            if codesign -dv "$app_path" 2>&1 | grep -q "code object is not signed"; then
                print_warning "   未签名"
            else
                local signer=$(codesign -dv "$app_path" 2>&1 | grep "Authority=" | head -1 | sed 's/.*Authority=\([^,]*\).*/\1/')
                if [ -n "$signer" ]; then
                    echo "   签名者: $signer"
                else
                    echo "   签名者: 未知"
                fi
                
                # 验证签名
                if codesign --verify --deep --strict "$app_path" 2>/dev/null; then
                    print_success "   签名有效"
                else
                    print_warning "   签名无效或验证失败"
                fi
            fi
            
            echo ""
        fi
    done
}

# 对比分析
compare_and_analyze() {
    print_step "对比分析"
    
    print_info "请对比以下信息:"
    echo ""
    echo "1. TCC 数据库中的 'client' 字段（Bundle ID 或路径）"
    echo "2. TCC 数据库中的 'csreq' 字段（代码签名要求）"
    echo "3. 应用的实际 Bundle ID"
    echo "4. 应用的实际路径"
    echo "5. 应用的代码签名"
    echo ""
    echo "⚠️ 重要：即使 client 字段匹配，如果 csreq（代码签名要求）"
    echo "   与当前应用的签名不匹配，API 也会返回 false。"
    echo ""
    echo "常见不匹配情况:"
    echo "  • client 字段是旧 Bundle ID（如 xyz.keben.EchoFlow）"
    echo "  • client 字段是旧路径（如 DerivedData 路径）"
    echo "  • csreq 是旧签名的要求，当前应用使用新签名"
    echo ""
    echo "解决方案:"
    echo "  重置权限并重新授权，这会更新 client 和 csreq 字段。"
    echo ""
}

# 主函数
main() {
    # 检查是否有管理员权限
    if [ "$EUID" -ne 0 ]; then
        print_warning "此脚本需要管理员权限"
        print_info "请使用: sudo $0"
        exit 1
    fi
    
    query_tcc_database
    show_app_info
    compare_and_analyze
    
    print_step "建议操作"
    echo "如果 TCC 数据库中的 client 字段与当前应用不匹配:"
    echo ""
    echo "1. 重置权限:"
    echo "   sudo tccutil reset Accessibility xyz.keben.EchoFlow"
    echo "   sudo tccutil reset Accessibility xyz.keben.EchoFlow.debug"
    echo ""
    echo "2. 完全退出应用（⌘Q）"
    echo ""
    echo "3. 重新运行应用并授权"
    echo ""
}

# 运行主函数
main "$@"

