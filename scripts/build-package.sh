#!/bin/bash

# =============================================================================
# EchoFlow (macOS Native) 构建与打包脚本 - 修正版
# =============================================================================
#
# 修复内容:
#   1. 解决 "Signature invalid" (签名无效) 问题
#   2. 解决 TCC 权限无法触发的问题
#   3. 自动生成 DMG 和 ZIP
#   4. 解决 Release 模式下 SwiftUI 预览导致的构建失败 (ENABLE_PREVIEWS=NO)
#   5. [本次新增] 强制手动签名模式，移除 -quiet 以便显示详细错误
#
# =============================================================================

set -e  # 遇到错误立即退出

# --- 配置项 ---
PROJECT_NAME="EchoFlow"
SCHEME="EchoFlow"
BUNDLE_ID="xyz.keben.EchoFlow"  # 请确认这与 Xcode 中的 Bundle Identifier 一致

# 路径配置
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODEPROJ="${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/Export"
DMG_DIR="${BUILD_DIR}/dmg-contents"
APP_PATH="${EXPORT_DIR}/${PROJECT_NAME}.app"

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- 辅助函数 ---
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# --- 1. 清理环境 ---
clean_build() {
    print_info "清理旧的构建文件..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
}

# --- 2. 构建 Archive ---
build_archive() {
    print_info "正在构建 Release Archive (详细日志模式)..."
    
    # 使用 xcodebuild 构建
    # 1. -destination: 明确指定构建目标为 macOS
    # 2. ENABLE_PREVIEWS=NO: 禁止构建 SwiftUI 预览
    # 3. CODE_SIGN_STYLE="Manual": [关键] 禁用自动签名管理，防止寻找证书失败
    # 4. PROVISIONING_PROFILE_SPECIFIER="": [关键] 明确不使用描述文件
    # 5. CODE_SIGN_IDENTITY="-": 使用 Ad-hoc 本地签名
    # 6. 移除了 -quiet: 显示完整日志以便排错
    xcodebuild archive \
        -project "$XCODEPROJ" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=macOS" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=YES \
        CODE_SIGN_STYLE="Manual" \
        PROVISIONING_PROFILE_SPECIFIER="" \
        ENABLE_PREVIEWS=NO \
        DEVELOPMENT_TEAM="" \
        || {
            print_error "xcodebuild 构建失败"
            print_info "请检查上方日志寻找具体错误原因 (搜索 'error:')"
            exit 1
        }
    
    print_success "Archive 构建成功"
}

# --- 3. 导出 App ---
export_app() {
    print_info "导出 App 文件..."
    mkdir -p "$EXPORT_DIR"
    
    # 直接从 Archive 内部复制 App
    # 相比 -exportArchive，这种方式更适合没有开发者证书的本地构建
    cp -R "$ARCHIVE_PATH/Products/Applications/${PROJECT_NAME}.app" "$EXPORT_DIR/"
    
    if [ ! -d "$APP_PATH" ]; then
        print_error "App 导出失败: 未找到 $APP_PATH"
        exit 1
    fi
}

# --- 4. [关键] 修复签名与权限 ---
fix_signature_and_quarantine() {
    print_info "正在修复代码签名 (解决权限问题的关键)..."

    # 1. 移除隔离属性 (防止系统报 "文件已损坏" 或 "下载自互联网")
    xattr -cr "$APP_PATH"

    # 2. 强制深度重签名 (Ad-hoc)
    # --preserve-metadata=identifier,entitlements,flags: 尽量保留原有的权限声明
    # -f: 强制覆盖
    # -s -: 使用本地 Ad-hoc 签名
    codesign --force --deep --preserve-metadata=identifier,entitlements,flags --sign - "$APP_PATH" || {
        print_error "签名修复失败"
        exit 1
    }

    # 验证签名
    print_success "签名已修复"
    codesign -dv "$APP_PATH" 2>&1 | grep "Signature="
}

# --- 5. 重置 TCC 权限 ---
reset_permissions() {
    print_info "重置系统辅助功能权限记录..."
    # 只有清理了旧记录，新的签名才能触发新的弹窗
    tccutil reset Accessibility "$BUNDLE_ID" || true
    print_success "权限已重置 (下次运行将触发弹窗)"
}

# --- 6. 打包 DMG ---
create_dmg() {
    print_info "创建 DMG 安装包..."
    local version=$1
    local dmg_path="${BUILD_DIR}/${PROJECT_NAME}-${version}.dmg"
    
    rm -rf "$DMG_DIR"
    mkdir -p "$DMG_DIR"
    cp -R "$APP_PATH" "$DMG_DIR/"
    ln -s /Applications "$DMG_DIR/Applications"
    
    hdiutil create -volname "$PROJECT_NAME" \
        -srcfolder "$DMG_DIR" \
        -ov -format UDZO \
        "$dmg_path" -quiet
        
    print_success "DMG 已生成: $dmg_path"
}

# --- 主流程 ---
main() {
    local version=$1
    if [ -z "$version" ]; then version="1.0.0"; fi

    print_info "开始构建 EchoFlow v${version} (macOS Native)"

    clean_build
    build_archive
    export_app
    
    # 核心修复步骤在此
    fix_signature_and_quarantine
    
    create_dmg "$version"
    reset_permissions
    
    echo ""
    print_success "🎉 构建完成！"
    echo "请运行以下命令启动并测试权限:"
    echo "open \"$APP_PATH\""
}

