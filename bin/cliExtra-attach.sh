#!/bin/bash

# cliExtra 接管实例脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 接管tmux实例
attach_to_instance() {
    local instance_id="$1"
    local session_name="q_instance_$instance_id"
    
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "✗ 实例 $instance_id 不存在或未运行"
        echo "请先启动实例: cliExtra start $instance_id"
        return 1
    fi
    
    echo "正在接管实例 $instance_id..."
    echo "提示: 按 Ctrl+B, D 可以分离会话但保持运行"
    
    # 接管tmux会话
    tmux attach-session -t "$session_name"
}

# 主逻辑
if [ -n "$1" ]; then
    attach_to_instance "$1"
else
    echo "用法: cliExtra-attach.sh <instance_id>"
    echo "示例: cliExtra-attach.sh myproject"
fi 