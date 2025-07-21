#!/bin/bash

# cliExtra 安装脚本 - 使用软链接

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 确定系统类型和安装目录
get_install_dir() {
    case "$(uname)" in
        "Darwin")  # macOS
            # 检查是否有管理员权限
            if [ "$EUID" -eq 0 ]; then
                echo "/usr/local/bin"
            else
                # 检查用户本地bin目录
                if [ -d "$HOME/bin" ]; then
                    echo "$HOME/bin"
                else
                    echo "/usr/local/bin"
                fi
            fi
            ;;
        "Linux")
            # 检查是否有管理员权限
            if [ "$EUID" -eq 0 ]; then
                echo "/usr/local/bin"
            else
                # 检查用户本地bin目录
                if [ -d "$HOME/bin" ]; then
                    echo "$HOME/bin"
                else
                    echo "/usr/local/bin"
                fi
            fi
            ;;
        *)
            echo "/usr/local/bin"
            ;;
    esac
}

# 检查依赖
check_dependencies() {
    echo -e "${BLUE}检查依赖...${NC}"
    
    if ! command -v screen &> /dev/null; then
        echo -e "${RED}错误: screen 未安装${NC}"
        echo "请安装: brew install screen (macOS) 或 apt-get install screen (Linux)"
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        echo -e "${RED}错误: git 未安装${NC}"
        echo "请安装 git"
        exit 1
    fi
    
    echo -e "${GREEN}✓ 依赖检查通过${NC}"
}

# 创建软链接
create_symlink() {
    local install_dir="$1"
    
    echo -e "${BLUE}创建软链接到: $install_dir${NC}"
    
    # 检查权限
    if [ ! -w "$install_dir" ] && [ "$EUID" -ne 0 ]; then
        echo -e "${RED}错误: 没有写入权限到 $install_dir${NC}"
        echo "请使用 sudo 运行此脚本，或选择用户目录安装"
        exit 1
    fi
    
    # 创建安装目录（如果不存在）
    if [ ! -d "$install_dir" ]; then
        echo -e "${YELLOW}创建安装目录: $install_dir${NC}"
        mkdir -p "$install_dir"
    fi
    
    # 删除可能存在的旧链接
    if [ -L "$install_dir/cliExtra" ]; then
        echo -e "${YELLOW}删除旧链接...${NC}"
        rm -f "$install_dir/cliExtra"
    fi
    
    # 创建软链接
    echo -e "${YELLOW}创建软链接...${NC}"
    ln -sf "$SCRIPT_DIR/cliExtra.sh" "$install_dir/cliExtra"
    
    # 设置执行权限
    chmod +x "$install_dir/cliExtra"
    
    echo -e "${GREEN}✓ 软链接创建完成${NC}"
}

# 更新PATH环境变量
update_path() {
    local install_dir="$1"
    
    echo -e "${BLUE}检查PATH环境变量...${NC}"
    
    # 获取shell配置文件
    local shell_rc=""
    case "$SHELL" in
        */zsh)
            shell_rc="$HOME/.zshrc"
            ;;
        */bash)
            shell_rc="$HOME/.bashrc"
            ;;
        *)
            shell_rc="$HOME/.bashrc"
            ;;
    esac
    
    # 检查是否已经在PATH中
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        echo -e "${YELLOW}添加 $install_dir 到 PATH...${NC}"
        
        # 备份原文件
        if [ -f "$shell_rc" ]; then
            cp "$shell_rc" "$shell_rc.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # 添加PATH
        echo "" >> "$shell_rc"
        echo "# cliExtra PATH" >> "$shell_rc"
        echo "export PATH=\"$install_dir:\$PATH\"" >> "$shell_rc"
        
        echo -e "${GREEN}✓ PATH已更新到 $shell_rc${NC}"
        echo -e "${YELLOW}请运行 'source $shell_rc' 或重新打开终端以生效${NC}"
    else
        echo -e "${GREEN}✓ PATH已包含 $install_dir${NC}"
    fi
}

# 显示安装信息
show_install_info() {
    local install_dir="$1"
    
    echo ""
    echo -e "${GREEN}=== cliExtra 安装完成 ===${NC}"
    echo ""
    echo -e "${BLUE}安装位置:${NC}"
    echo "  软链接: $install_dir/cliExtra"
    echo "  实际位置: $SCRIPT_DIR/cliExtra.sh"
    echo ""
    echo -e "${BLUE}使用方法:${NC}"
    echo "  cliExtra config"
    echo "  cliExtra start 123"
    echo "  cliExtra monitor 123"
    echo ""
    echo -e "${BLUE}如果命令不可用，请运行:${NC}"
    echo "  source ~/.zshrc  # 或 source ~/.bashrc"
    echo ""
}

# 卸载功能
uninstall() {
    local install_dir="$1"
    
    echo -e "${YELLOW}卸载 cliExtra...${NC}"
    
    if [ -L "$install_dir/cliExtra" ]; then
        rm -f "$install_dir/cliExtra"
        echo -e "${GREEN}✓ 软链接已删除${NC}"
    else
        echo -e "${YELLOW}未找到软链接${NC}"
    fi
    
    echo -e "${GREEN}✓ 卸载完成${NC}"
    echo -e "${YELLOW}注意: 请手动从shell配置文件中删除PATH设置${NC}"
}

# 主逻辑
main() {
    echo -e "${BLUE}=== cliExtra 安装脚本 ===${NC}"
    echo ""
    
    # 检查参数
    if [ "$1" = "uninstall" ]; then
        local install_dir=$(get_install_dir)
        uninstall "$install_dir"
        exit 0
    fi
    
    # 检查依赖
    check_dependencies
    
    # 获取安装目录
    local install_dir=$(get_install_dir)
    echo -e "${BLUE}安装目录: $install_dir${NC}"
    
    # 创建软链接
    create_symlink "$install_dir"
    
    # 更新PATH
    update_path "$install_dir"
    
    # 显示安装信息
    show_install_info "$install_dir"
}

# 运行主函数
main "$@" 