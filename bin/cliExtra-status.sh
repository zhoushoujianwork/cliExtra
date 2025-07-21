#!/bin/bash

# cliExtra 状态查看脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示tmux会话状态
show_tmux_status() {
    local instance_id="$1"
    local session_name="q_instance_$instance_id"
    
    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo "实例 $instance_id 状态:"
        
        # 显示会话信息
        tmux list-sessions -F "#{session_name}: #{session_windows} windows (created #{session_created_string})" | grep "$session_name"
        
        # 检查客户端连接状态
        local client_count=$(tmux list-clients -t "$session_name" 2>/dev/null | wc -l)
        if [ "$client_count" -gt 0 ]; then
            echo "状态: Attached ($client_count 个客户端连接)"
        else
            echo "状态: Detached"
        fi
        
        # 查找实例的项目目录
        local project_dir=$(find_instance_project "$instance_id")
        if [ $? -eq 0 ]; then
            local session_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
            echo "项目目录: $project_dir"
            echo "会话目录: $session_dir"
            if [ -f "$session_dir/tmux.log" ]; then
                local log_size=$(wc -l < "$session_dir/tmux.log")
                echo "日志行数: $log_size"
            fi
        fi
    else
        echo "实例 $instance_id 未运行"
    fi
}

# 主逻辑
if [ -n "$1" ]; then
    show_tmux_status "$1"
else
    echo "用法: cliExtra-status.sh <instance_id>"
    echo "示例: cliExtra-status.sh myproject"
fi 