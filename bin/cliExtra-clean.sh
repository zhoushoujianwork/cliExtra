#!/bin/bash

# cliExtra 清理脚本

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

# 清理单个实例
clean_single_instance() {
    local instance_id="$1"
    local session_name="q_instance_$instance_id"
    
    echo "清理实例 $instance_id..."
    
    # 停止实例
    stop_tmux_instance "$instance_id"
    
    # 查找并清理项目目录中的实例文件
    local project_dir=$(find_instance_project "$instance_id")
    if [ $? -eq 0 ]; then
        local instance_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
        local log_file="$project_dir/.cliExtra/logs/instance_$instance_id.log"
        
        # 删除实例目录
        if [ -d "$instance_dir" ]; then
            rm -rf "$instance_dir"
            echo "✓ 实例目录已删除: $instance_dir"
        fi
        
        # 删除日志文件
        if [ -f "$log_file" ]; then
            rm -f "$log_file"
            echo "✓ 日志文件已删除: $log_file"
        fi
        
        echo "✓ 实例 $instance_id 已完全清理"
    else
        echo "⚠ 未找到实例 $instance_id 的项目目录"
        echo "✓ 实例 $instance_id 已停止"
    fi
}

# 清理所有tmux实例
clean_all_tmux() {
    echo "清理所有tmux q CLI实例..."
    
    local cleaned=false
    while IFS= read -r session_line; do
        if [[ "$session_line" == q_instance_* ]]; then
            session_info=$(echo "$session_line" | cut -d: -f1)
            instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            
            echo "停止实例 $instance_id..."
            stop_tmux_instance "$instance_id"
            cleaned=true
        fi
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    if [ "$cleaned" = true ]; then
        echo "✓ 所有实例已清理"
    else
        echo "没有需要清理的实例"
    fi
}

# 主逻辑
if [ "$1" = "all" ]; then
    clean_all_tmux
elif [ -n "$1" ]; then
    clean_single_instance "$1"
else
    echo "用法: cliExtra-clean.sh <instance_id> 或 cliExtra-clean.sh all"
    echo "示例:"
    echo "  cliExtra-clean.sh myproject    # 清理指定实例"
    echo "  cliExtra-clean.sh all          # 清理所有实例"
fi 