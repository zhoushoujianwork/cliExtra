#!/bin/bash

# cliExtra 对话回放脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra replay <command> [options]"
    echo ""
    echo "命令:"
    echo "  instance <id>        回放指定实例的对话记录"
    echo "  namespace <ns>       回放指定namespace的消息历史"
    echo "  list                 列出可用的对话记录"
    echo ""
    echo "选项:"
    echo "  --format <format>    输出格式: text(默认), json, timeline"
    echo "  --since <time>       只显示指定时间之后的记录"
    echo "  --limit <n>          限制显示的记录数量"
    echo "  --project <path>     指定项目路径（默认当前目录）"
    echo ""
    echo "示例:"
    echo "  cliExtra replay instance backend-api           # 回放backend-api实例的对话"
    echo "  cliExtra replay namespace development          # 回放development namespace的消息历史"
    echo "  cliExtra replay instance frontend-dev --format json  # JSON格式输出"
    echo "  cliExtra replay namespace backend --since \"2025-01-20\"  # 显示指定日期后的记录"
    echo "  cliExtra replay list                           # 列出所有可用的对话记录"
}

# 获取项目目录
get_project_dir() {
    local project_path="${1:-$(pwd)}"
    
    # 转换为绝对路径
    if [[ "$project_path" = /* ]]; then
        echo "$project_path"
    else
        echo "$(pwd)/$project_path"
    fi
}

# 列出可用的对话记录
list_conversation_records() {
    local project_dir="$1"
    local namespaces_dir="$project_dir/.cliExtra/namespaces"
    
    if [[ ! -d "$namespaces_dir" ]]; then
        echo "项目中没有找到对话记录"
        return 1
    fi
    
    echo "=== 可用的对话记录 ==="
    printf "%-15s %-20s %-15s %s\n" "Namespace" "实例ID" "记录数" "最后更新"
    printf "%-15s %-20s %-15s %s\n" "---------" "------" "----" "--------"
    
    for ns_dir in "$namespaces_dir"/*; do
        if [[ -d "$ns_dir" ]]; then
            local namespace=$(basename "$ns_dir")
            local conversations_dir="$ns_dir/conversations"
            
            if [[ -d "$conversations_dir" ]]; then
                for conv_file in "$conversations_dir"/instance_*.json; do
                    if [[ -f "$conv_file" ]]; then
                        local instance_id=$(basename "$conv_file" .json | sed 's/instance_//')
                        
                        if command -v jq >/dev/null 2>&1; then
                            local count=$(jq '.conversations | length' "$conv_file" 2>/dev/null || echo "0")
                            local last_update=$(jq -r '.conversations[-1].timestamp // "N/A"' "$conv_file" 2>/dev/null || echo "N/A")
                        else
                            local count="N/A"
                            local last_update="N/A"
                        fi
                        
                        printf "%-15s %-20s %-15s %s\n" "$namespace" "$instance_id" "$count" "$last_update"
                    fi
                done
            fi
        fi
    done
}

# 回放实例对话
replay_instance_conversation() {
    local project_dir="$1"
    local instance_id="$2"
    local format="$3"
    local since="$4"
    local limit="$5"
    
    # 查找实例的对话文件
    local conversation_file=""
    local namespaces_dir="$project_dir/.cliExtra/namespaces"
    
    for ns_dir in "$namespaces_dir"/*; do
        if [[ -d "$ns_dir" ]]; then
            local conv_file="$ns_dir/conversations/instance_$instance_id.json"
            if [[ -f "$conv_file" ]]; then
                conversation_file="$conv_file"
                break
            fi
        fi
    done
    
    if [[ -z "$conversation_file" ]]; then
        echo "错误: 未找到实例 $instance_id 的对话记录"
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "错误: 需要安装jq来处理对话记录"
        return 1
    fi
    
    # 构建jq过滤器
    local jq_filter=".conversations"
    
    if [[ -n "$since" ]]; then
        jq_filter="$jq_filter | map(select(.timestamp >= \"$since\"))"
    fi
    
    if [[ -n "$limit" ]]; then
        jq_filter="$jq_filter | .[-$limit:]"
    fi
    
    case "$format" in
        "json")
            jq "$jq_filter" "$conversation_file"
            ;;
        "timeline")
            echo "=== 实例 $instance_id 对话时间线 ==="
            jq -r "$jq_filter | .[] | \"[\(.timestamp)] \(.sender): \(.message)\"" "$conversation_file"
            ;;
        "text"|*)
            echo "=== 实例 $instance_id 对话记录 ==="
            local namespace=$(jq -r '.namespace' "$conversation_file")
            local created_at=$(jq -r '.created_at' "$conversation_file")
            echo "Namespace: $namespace"
            echo "创建时间: $created_at"
            echo ""
            
            jq -r "$jq_filter | .[] | \"[\(.timestamp | strftime(\"%Y-%m-%d %H:%M:%S\"))] \(.sender): \(.message)\"" "$conversation_file" 2>/dev/null || \
            jq -r "$jq_filter | .[] | \"[\(.timestamp)] \(.sender): \(.message)\"" "$conversation_file"
            ;;
    esac
}

# 回放namespace消息历史
replay_namespace_history() {
    local project_dir="$1"
    local namespace="$2"
    local format="$3"
    local since="$4"
    local limit="$5"
    
    local cache_file="$(get_namespace_dir "$namespace")/namespace_cache.json"
    
    if [[ ! -f "$cache_file" ]]; then
        echo "错误: 未找到namespace $namespace 的消息历史"
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "错误: 需要安装jq来处理消息历史"
        return 1
    fi
    
    # 构建jq过滤器
    local jq_filter=".message_history"
    
    if [[ -n "$since" ]]; then
        jq_filter="$jq_filter | map(select(.timestamp >= \"$since\"))"
    fi
    
    if [[ -n "$limit" ]]; then
        jq_filter="$jq_filter | .[-$limit:]"
    fi
    
    case "$format" in
        "json")
            jq "$jq_filter" "$cache_file"
            ;;
        "timeline")
            echo "=== Namespace $namespace 消息时间线 ==="
            jq -r "$jq_filter | .[] | \"[\(.timestamp)] \(.action): \(.message // \"N/A\")\"" "$cache_file"
            ;;
        "text"|*)
            echo "=== Namespace $namespace 消息历史 ==="
            local created_at=$(jq -r '.created_at' "$cache_file")
            echo "创建时间: $created_at"
            echo ""
            
            jq -r "$jq_filter | .[] | \"[\(.timestamp | strftime(\"%Y-%m-%d %H:%M:%S\"))] \(.action) (\(.instance_id)): \(.message // \"N/A\")\"" "$cache_file" 2>/dev/null || \
            jq -r "$jq_filter | .[] | \"[\(.timestamp)] \(.action) (\(.instance_id)): \(.message // \"N/A\")\"" "$cache_file"
            ;;
    esac
}

# 解析参数
COMMAND=""
TARGET=""
FORMAT="text"
SINCE=""
LIMIT=""
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --since)
            SINCE="$2"
            shift 2
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        --project)
            PROJECT_DIR="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        instance|namespace|list)
            COMMAND="$1"
            if [[ "$1" != "list" ]]; then
                TARGET="$2"
                shift 2
            else
                shift
            fi
            ;;
        *)
            echo "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 设置默认项目目录
if [[ -z "$PROJECT_DIR" ]]; then
    PROJECT_DIR=$(get_project_dir)
fi

# 主逻辑
case "$COMMAND" in
    "instance")
        if [[ -z "$TARGET" ]]; then
            echo "错误: 请指定实例ID"
            show_help
            exit 1
        fi
        replay_instance_conversation "$PROJECT_DIR" "$TARGET" "$FORMAT" "$SINCE" "$LIMIT"
        ;;
    "namespace")
        if [[ -z "$TARGET" ]]; then
            echo "错误: 请指定namespace"
            show_help
            exit 1
        fi
        replay_namespace_history "$PROJECT_DIR" "$TARGET" "$FORMAT" "$SINCE" "$LIMIT"
        ;;
    "list")
        list_conversation_records "$PROJECT_DIR"
        ;;
    "")
        echo "错误: 请指定命令"
        show_help
        exit 1
        ;;
    *)
        echo "未知命令: $COMMAND"
        show_help
        exit 1
        ;;
esac
