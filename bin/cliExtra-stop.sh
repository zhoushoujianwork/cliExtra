#!/bin/bash

# cliExtra 停止实例脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 停止tmux实例
stop_tmux_instance() {
    local instance_id="$1"
    local session_name="q_instance_$instance_id"
    
    if tmux has-session -t "$session_name" 2>/dev/null; then
        # 发送退出命令
        tmux send-keys -t "$session_name" "exit" Enter
        sleep 1
        
        # 如果还在运行，强制终止
        if tmux has-session -t "$session_name" 2>/dev/null; then
            tmux kill-session -t "$session_name"
        fi
        
        echo "✓ 实例 $instance_id 已停止"
    else
        echo "实例 $instance_id 未运行"
    fi
}

# 主逻辑
if [ -n "$1" ]; then
    stop_tmux_instance "$1"
else
    echo "用法: cliExtra-stop.sh <instance_id>"
    echo "示例: cliExtra-stop.sh myproject"
fi 