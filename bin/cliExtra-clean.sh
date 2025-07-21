#!/bin/bash

# cliExtra 清理脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 停止Screen实例
stop_screen_instance() {
    local instance_id="$1"
    local session_name="q_instance_$instance_id"
    
    if screen -list | grep -q "$session_name"; then
        # 发送退出命令
        screen -S "$session_name" -X stuff "exit"
        screen -S "$session_name" -X stuff $'\015'
        sleep 1
        
        # 如果还在运行，强制终止
        if screen -list | grep -q "$session_name"; then
            screen -S "$session_name" -X quit
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
    stop_screen_instance "$instance_id"
    
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

# 清理所有Screen实例
clean_all_screen() {
    echo "清理所有Screen q CLI实例..."
    
    local cleaned=false
    while IFS= read -r line; do
        if [[ "$line" == *"q_instance_"* ]]; then
            session_info=$(echo "$line" | grep -o 'q_instance_[^[:space:]]*')
            instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            
            echo "停止实例 $instance_id..."
            stop_screen_instance "$instance_id"
            cleaned=true
        fi
    done < <(screen -list 2>/dev/null)
    
    if [ "$cleaned" = true ]; then
        echo "✓ 所有实例已清理"
    else
        echo "没有需要清理的实例"
    fi
}

# 主逻辑
if [ "$1" = "all" ]; then
    clean_all_screen
elif [ -n "$1" ]; then
    clean_single_instance "$1"
else
    echo "用法: cliExtra-clean.sh <instance_id> 或 cliExtra-clean.sh all"
    echo "示例:"
    echo "  cliExtra-clean.sh myproject    # 清理指定实例"
    echo "  cliExtra-clean.sh all          # 清理所有实例"
fi 