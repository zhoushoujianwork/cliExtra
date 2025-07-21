#!/bin/bash

# cliExtra 配置脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示配置
show_config() {
    echo "当前配置:"
    echo "CLIEXTRA_HOME=\"$CLIEXTRA_HOME\""
    
    if [ -f "$HOME/.cliExtra/config" ]; then
        echo ""
        echo "用户配置文件 ($HOME/.cliExtra/config):"
        cat "$HOME/.cliExtra/config"
    else
        echo ""
        echo "配置文件不存在，使用默认配置"
    fi
}

# 设置配置
set_config() {
    local key="$1"
    local value="$2"
    local config_file="$HOME/.cliExtra/config"
    
    # 创建配置目录
    mkdir -p "$(dirname "$config_file")"
    
    # 如果配置文件不存在，创建它
    if [ ! -f "$config_file" ]; then
        cat > "$config_file" << EOF
# cliExtra 用户配置
CLIEXTRA_HOME="$HOME/Library/Application Support/cliExtra"
EOF
    fi
    
    # 更新配置
    if grep -q "^$key=" "$config_file"; then
        # 更新现有配置
        sed -i.bak "s/^$key=.*/$key=\"$value\"/" "$config_file"
    else
        # 添加新配置
        echo "$key=\"$value\"" >> "$config_file"
    fi
    
    echo "✓ 配置已更新: $key=\"$value\""
}

# 交互式配置
interactive_config() {
    echo "=== cliExtra 配置向导 ==="
    echo ""
    
    # 设置主目录
    echo "请设置cliExtra主目录 (用于存储全局项目):"
    echo "当前值: $CLIEXTRA_HOME"
    read -p "新值 (回车保持当前值): " new_home
    
    if [ -n "$new_home" ]; then
        set_config "CLIEXTRA_HOME" "$new_home"
    fi
    
    echo ""
    echo "✓ 配置完成"
    show_config
}

# 主逻辑
case "${1:-}" in
    "show")
        show_config
        ;;
    "set")
        if [ -n "$2" ] && [ -n "$3" ]; then
            set_config "$2" "$3"
        else
            echo "用法: cliExtra-config.sh set <key> <value>"
            echo "示例: cliExtra-config.sh set CLIEXTRA_HOME \"/path/to/home\""
        fi
        ;;
    "interactive"|"")
        interactive_config
        ;;
    *)
        echo "用法: cliExtra-config.sh [show|set|interactive]"
        echo "  show         - 显示当前配置"
        echo "  set <k> <v>  - 设置配置项"
        echo "  interactive  - 交互式配置 (默认)"
        ;;
esac 