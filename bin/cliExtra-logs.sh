#!/bin/bash

# cliExtra 日志查看脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 查看实例日志
view_screen_logs() {
    local instance_id="$1"
    local lines="${2:-50}"
    
    # 查找实例的项目目录
    local project_dir=$(find_instance_project "$instance_id")
    if [ $? -ne 0 ]; then
        echo "未找到实例 $instance_id 的项目目录"
        return 1
    fi
    
    local log_file="$project_dir/.cliExtra/logs/instance_$instance_id.log"
    if [ -f "$log_file" ]; then
        echo "=== 实例 $instance_id 的日志 (最近 $lines 行) ==="
        echo "项目目录: $project_dir"
        # 清理ANSI转义序列并显示
        tail -n "$lines" "$log_file" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'
    else
        echo "日志文件不存在: $log_file"
        echo "提示: 日志只在实例运行时生成"
    fi
}

# 主逻辑
if [ -n "$1" ]; then
    view_screen_logs "$1" "$2"
else
    echo "用法: cliExtra-logs.sh <instance_id> [lines]"
    echo "示例: cliExtra-logs.sh myproject 20"
fi 