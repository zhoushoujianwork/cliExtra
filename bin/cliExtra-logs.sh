#!/bin/bash

# cliExtra 日志查看脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 查看实例日志
view_instance_logs() {
    local instance_id="$1"
    local lines="${2:-50}"
    
    # 使用新的实例查找函数
    local instance_dir=$(find_instance_info_dir "$instance_id")
    local log_file=""
    local project_dir=""
    
    if [[ $? -eq 0 && -n "$instance_dir" ]]; then
        # 从工作目录结构中获取日志文件
        local ns_dir=$(dirname "$(dirname "$instance_dir")")
        log_file="$ns_dir/logs/instance_$instance_id.log"
        
        # 获取项目目录
        if [ -f "$instance_dir/project_path" ]; then
            project_dir=$(cat "$instance_dir/project_path")
        elif [ -f "$instance_dir/info" ]; then
            source "$instance_dir/info"
            project_dir="$PROJECT_DIR"
        fi
    else
        # 向后兼容：查找实例的项目目录
        project_dir=$(find_instance_project "$instance_id")
        if [ $? -ne 0 ]; then
            echo "未找到实例 $instance_id"
            return 1
        fi
        
        # 尝试新的namespace结构
        if [ -d "$project_dir/.cliExtra/namespaces" ]; then
            for ns_dir in "$project_dir/.cliExtra/namespaces"/*; do
                if [ -d "$ns_dir/instances/instance_$instance_id" ]; then
                    log_file="$ns_dir/logs/instance_$instance_id.log"
                    break
                fi
            done
        fi
        
        # 回退到旧结构
        if [ -z "$log_file" ]; then
            log_file="$project_dir/.cliExtra/logs/instance_$instance_id.log"
        fi
    fi
    
    if [ -f "$log_file" ]; then
        echo "=== 实例 $instance_id 的日志 (最近 $lines 行) ==="
        echo "项目目录: ${project_dir:-"未知"}"
        echo "日志文件: $log_file"
        echo ""
        # 清理ANSI转义序列并显示
        tail -n "$lines" "$log_file" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'
    else
        echo "日志文件不存在: ${log_file:-"未找到日志文件路径"}"
        echo "提示: 日志只在实例运行时生成"
    fi
}

# 主逻辑
if [ -n "$1" ]; then
    view_instance_logs "$1" "$2"
else
    echo "用法: cliExtra-logs.sh <instance_id> [lines]"
    echo "示例: cliExtra-logs.sh myproject 20"
fi 