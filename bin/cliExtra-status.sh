#!/bin/bash

# cliExtra 状态查看脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示Screen会话状态
show_screen_status() {
    local instance_id="$1"
    local session_name="q_instance_$instance_id"
    
    if screen -list | grep -q "$session_name"; then
        echo "实例 $instance_id 状态:"
        screen -list | grep "$session_name"
        
        # 查找实例的项目目录
        local project_dir=$(find_instance_project "$instance_id")
        if [ $? -eq 0 ]; then
            local session_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
            echo "项目目录: $project_dir"
            echo "会话目录: $session_dir"
            if [ -f "$session_dir/screen.log" ]; then
                local log_size=$(wc -l < "$session_dir/screen.log")
                echo "日志行数: $log_size"
            fi
        fi
    else
        echo "实例 $instance_id 未运行"
    fi
}

# 主逻辑
if [ -n "$1" ]; then
    show_screen_status "$1"
else
    echo "用法: cliExtra-status.sh <instance_id>"
    echo "示例: cliExtra-status.sh myproject"
fi 