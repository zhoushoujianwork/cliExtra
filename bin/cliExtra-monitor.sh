#!/bin/bash

# cliExtra 监控脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 监控tmux实例输出
monitor_tmux_instance() {
    local instance_id="$1"
    local session_name="q_instance_$instance_id"
    
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "✗ 实例 $instance_id 不存在或未运行"
        echo "请先启动实例: cliExtra start $instance_id"
        return 1
    fi
    
    echo "正在监控实例 $instance_id..."
    echo "按 Ctrl+C 停止监控"
    
    # 查找实例的项目目录和日志文件
    local project_dir=$(find_instance_project "$instance_id")
    if [ $? -eq 0 ]; then
        local session_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
        local log_file="$session_dir/tmux.log"
        
        if [ -f "$log_file" ]; then
            # 实时显示现有日志
            tail -f "$log_file" 2>/dev/null &
            local tail_pid=$!
            
            # 等待用户中断
            trap "kill $tail_pid 2>/dev/null; exit" INT
            
            wait $tail_pid
        else
            echo "日志文件不存在: $log_file"
            echo "尝试直接监控tmux会话..."
            
            # 直接监控tmux会话（需要用户手动接管）
            echo "请使用以下命令接管会话进行监控:"
            echo "tmux attach-session -t $session_name"
        fi
    else
        echo "无法找到实例 $instance_id 的项目目录"
        echo "请使用以下命令接管会话进行监控:"
        echo "tmux attach-session -t $session_name"
    fi
}

# 主逻辑
if [ -n "$1" ]; then
    monitor_tmux_instance "$1"
else
    echo "用法: cliExtra-monitor.sh <instance_id>"
    echo "示例: cliExtra-monitor.sh myproject"
fi 