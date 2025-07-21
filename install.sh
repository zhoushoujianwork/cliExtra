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
    
    # 检查 Amazon Q CLI
    if ! command -v q &> /dev/null; then
        echo -e "${RED}错误: Amazon Q CLI 未安装${NC}"
        echo -e "${YELLOW}请先安装并初始化 Amazon Q CLI:${NC}"
        echo "1. 访问: https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-installing.html"
        echo "2. 安装适合您系统的版本"
        echo "3. 运行: q auth login"
        echo "4. 验证: q --version"
        exit 1
    fi
    
    # 检查 Amazon Q CLI 是否已初始化
    if ! q --version &> /dev/null; then
        echo -e "${YELLOW}警告: Amazon Q CLI 可能未正确初始化${NC}"
        echo -e "${YELLOW}如果遇到问题，请运行: q auth login${NC}"
    else
        echo -e "${GREEN}✓ Amazon Q CLI 已安装并可用${NC}"
    fi
    
    if ! command -v tmux &> /dev/null; then
        echo -e "${RED}错误: tmux 未安装${NC}"
        echo "请安装: brew install tmux (macOS) 或 apt-get install tmux (Linux)"
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
        echo -e "${YELLOW}删除旧链接 cliExtra...${NC}"
        rm -f "$install_dir/cliExtra"
    fi
    
    if [ -L "$install_dir/qq" ]; then
        echo -e "${YELLOW}删除旧链接 qq...${NC}"
        rm -f "$install_dir/qq"
    fi
    
    # 创建软链接
    echo -e "${YELLOW}创建软链接...${NC}"
    ln -sf "$SCRIPT_DIR/cliExtra.sh" "$install_dir/cliExtra"
    ln -sf "$SCRIPT_DIR/cliExtra.sh" "$install_dir/qq"
    
    # 设置执行权限
    chmod +x "$install_dir/cliExtra"
    chmod +x "$install_dir/qq"
    
    echo -e "${GREEN}✓ 软链接创建完成${NC}"
    echo -e "${GREEN}  - cliExtra (完整命令)${NC}"
    echo -e "${GREEN}  - qq (简化命令)${NC}"
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
    echo "  完整命令: $install_dir/cliExtra"
    echo "  简化命令: $install_dir/qq"
    echo "  实际位置: $SCRIPT_DIR/cliExtra.sh"
    echo ""
    echo -e "${BLUE}使用方法 (两种命令等效):${NC}"
    echo "  cliExtra start    或  qq start"
    echo "  cliExtra list     或  qq list"
    echo "  cliExtra clean    或  qq clean"
    echo "  cliExtra help     或  qq help"
    echo ""
    echo -e "${BLUE}推荐使用简化命令:${NC}"
    echo "  qq start --name myproject"
    echo "  qq send myproject 'Hello!'"
    echo "  qq attach myproject"
    echo ""
    echo -e "${BLUE}如果命令不可用，请运行:${NC}"
    echo "  source ~/.zshrc  # 或 source ~/.bashrc"
    echo ""
}

# 卸载功能
uninstall() {
    local install_dir="$1"
    
    echo -e "${YELLOW}卸载 cliExtra...${NC}"
    
    local removed=false
    
    if [ -L "$install_dir/cliExtra" ]; then
        rm -f "$install_dir/cliExtra"
        echo -e "${GREEN}✓ cliExtra 软链接已删除${NC}"
        removed=true
    fi
    
    if [ -L "$install_dir/qq" ]; then
        rm -f "$install_dir/qq"
        echo -e "${GREEN}✓ qq 软链接已删除${NC}"
        removed=true
    fi
    
    if [ "$removed" = false ]; then
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