#!/bin/bash

# =============================================================================
# EchoFlow 安装包签名检测脚本
# =============================================================================
# 
# 用法:
#   ./scripts/check-signature.sh <app_path>
#   ./scripts/check-signature.sh /Applications/EchoFlow.app
#   ./scripts/check-signature.sh build/Export/EchoFlow.app
#   ./scripts/check-signature.sh EchoFlow-1.0.0.dmg
#
# 功能:
#   1. 检测 .app 文件的代码签名
#   2. 检测 DMG 文件的签名（如果有）
#   3. 显示详细的签名信息
#   4. 验证签名是否有效
#   5. 检查签名者、证书、权限等信息
#
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_section() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📋 $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# 显示使用帮助
show_help() {
    echo "EchoFlow 签名检测脚本"
    echo ""
    echo "用法:"
    echo "  $0 <app_path_or_dmg>"
    echo ""
    echo "参数:"
    echo "  app_path_or_dmg  应用路径或 DMG 文件路径"
    echo ""
    echo "示例:"
    echo "  $0 /Applications/EchoFlow.app"
    echo "  $0 build/Export/EchoFlow.app"
    echo "  $0 EchoFlow-1.0.0.dmg"
    echo ""
}

# 检查 .app 文件的签名
check_app_signature() {
    local app_path=$1
    
    if [ ! -d "$app_path" ]; then
        print_error "应用不存在: $app_path"
        return 1
    fi
    
    print_section "检查应用签名: $app_path"
    
    # 1. 基本签名信息
    print_info "基本签名信息:"
    echo ""
    if codesign -dv "$app_path" 2>&1 | grep -q "code object is not signed"; then
        print_error "应用未签名"
        return 1
    else
        codesign -dv "$app_path" 2>&1 | while IFS= read -r line; do
            if [[ "$line" =~ ^(Format|Identifier|Authority|TeamIdentifier|Sealed Resources|Signature|Timestamp|Info.plist|CodeDirectory|Signature size|CDHash|Version|Platform) ]]; then
                echo "  $line"
            fi
        done
    fi
    echo ""
    
    # 2. 详细签名信息
    print_info "详细签名信息:"
    echo ""
    codesign -dv --verbose=4 "$app_path" 2>&1 | grep -E "^(Format|Identifier|Authority|TeamIdentifier|Sealed Resources|Signature|Timestamp|Info.plist|CodeDirectory|Signature size|CDHash|Version|Platform|Executable|Designated requirement)" | sed 's/^/  /'
    echo ""
    
    # 3. 验证签名
    print_info "验证签名:"
    echo ""
    if codesign --verify --deep --strict "$app_path" 2>&1; then
        print_success "签名验证通过"
    else
        print_error "签名验证失败"
        echo ""
        print_info "详细验证信息:"
        codesign --verify --deep --strict --verbose=4 "$app_path" 2>&1 | sed 's/^/  /'
        return 1
    fi
    echo ""
    
    # 4. 检查签名要求（Designated Requirement）
    print_info "签名要求 (Designated Requirement):"
    echo ""
    local req=$(codesign -d -r- "$app_path" 2>&1 | grep -A 10 "designated requirement" || echo "未找到")
    if [ "$req" != "未找到" ]; then
        echo "$req" | sed 's/^/  /'
    else
        echo "  未设置签名要求"
    fi
    echo ""
    
    # 5. 检查 Entitlements
    print_info "权限声明 (Entitlements):"
    echo ""
    local entitlements=$(codesign -d --entitlements - "$app_path" 2>&1)
    if [ -n "$entitlements" ] && ! echo "$entitlements" | grep -q "no entitlements"; then
        echo "$entitlements" | sed 's/^/  /'
    else
        echo "  无权限声明"
    fi
    echo ""
    
    # 6. 检查隔离属性
    print_info "隔离属性 (Quarantine):"
    echo ""
    local quarantine=$(xattr -l "$app_path" 2>/dev/null | grep -i quarantine || echo "")
    if [ -n "$quarantine" ]; then
        print_warning "发现隔离属性:"
        echo "$quarantine" | sed 's/^/  /'
        echo ""
        print_info "建议移除隔离属性: xattr -cr \"$app_path\""
    else
        print_success "无隔离属性"
    fi
    echo ""
    
    # 7. 检查可执行文件签名
    local executable_path="$app_path/Contents/MacOS/EchoFlow"
    if [ -f "$executable_path" ]; then
        print_info "可执行文件签名:"
        echo ""
        codesign -dv "$executable_path" 2>&1 | grep -E "^(Format|Identifier|Authority|Signature)" | sed 's/^/  /' || echo "  未签名"
        echo ""
    fi
    
    return 0
}

# 检查 DMG 文件的签名
check_dmg_signature() {
    local dmg_path=$1
    
    if [ ! -f "$dmg_path" ]; then
        print_error "DMG 文件不存在: $dmg_path"
        return 1
    fi
    
    print_section "检查 DMG 签名: $dmg_path"
    
    # 1. 检查 DMG 签名
    print_info "DMG 签名信息:"
    echo ""
    if codesign -dv "$dmg_path" 2>&1 | grep -q "code object is not signed"; then
        print_warning "DMG 未签名（这是正常的，DMG 通常不签名）"
    else
        codesign -dv "$dmg_path" 2>&1 | grep -E "^(Format|Identifier|Authority|Signature)" | sed 's/^/  /'
    fi
    echo ""
    
    # 2. 挂载 DMG 并检查内部应用
    print_info "挂载 DMG 并检查内部应用..."
    echo ""
    
    local mount_point=$(hdiutil attach "$dmg_path" -nobrowse -noverify -noautoopen 2>&1 | grep -E "Apple_HFS|Apple_APFS" | awk '{print $3}' | head -1)
    
    if [ -z "$mount_point" ]; then
        print_error "无法挂载 DMG"
        return 1
    fi
    
    print_info "DMG 已挂载到: $mount_point"
    echo ""
    
    # 查找 .app 文件
    local app_in_dmg=$(find "$mount_point" -name "*.app" -type d | head -1)
    
    if [ -n "$app_in_dmg" ]; then
        print_info "找到应用: $app_in_dmg"
        echo ""
        check_app_signature "$app_in_dmg"
    else
        print_warning "DMG 中未找到 .app 文件"
    fi
    
    # 卸载 DMG
    hdiutil detach "$mount_point" > /dev/null 2>&1 || true
    print_info "DMG 已卸载"
    echo ""
    
    return 0
}

# 主函数
main() {
    local target_path=$1
    
    # 检查参数
    if [ -z "$target_path" ]; then
        print_error "请指定应用路径或 DMG 文件路径"
        show_help
        exit 1
    fi
    
    # 转换为绝对路径
    if [[ "$target_path" != /* ]]; then
        target_path="$(cd "$(dirname "$target_path")" && pwd)/$(basename "$target_path")"
    fi
    
    # 显示标题
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              EchoFlow 签名检测工具                         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    print_info "检测目标: $target_path"
    echo ""
    
    # 判断是 .app 还是 .dmg
    if [[ "$target_path" == *.dmg ]]; then
        check_dmg_signature "$target_path"
    elif [[ "$target_path" == *.app ]] || [ -d "$target_path" ] && [[ "$target_path" == *.app ]]; then
        check_app_signature "$target_path"
    else
        print_error "不支持的文件类型: $target_path"
        print_info "请提供 .app 文件或 .dmg 文件"
        exit 1
    fi
    
    # 总结
    echo ""
    print_section "检测完成"
    print_success "签名检测已完成"
    echo ""
}

# 运行主函数
main "$@"

