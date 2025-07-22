#!/bin/bash

# cliExtra 对话回放脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra replay <type> <target> [options]"
    echo ""
    echo "类型:"
    echo "  instance <id>     回放指定实例的对话记录"
    echo "  namespace <ns>    回放指定namespace的消息历史"
    echo ""
    echo "选项:"
    echo "  --format <fmt>    输出格式 (text|json|timeline)"
    echo "  --limit <n>       限制显示记录数量"
    echo "  --since <date>    显示指定时间后的记录"
    echo "  --type <type>     过滤消息类型 (message|broadcast)"
    echo ""
    echo "示例:"
    echo "  cliExtra replay instance backend-api"
    echo "  cliExtra replay instance frontend-dev --format json"
    echo "  cliExtra replay namespace development --limit 10"
    echo "  cliExtra replay namespace backend --since \"2025-01-20\""
}

# 格式化时间戳
format_timestamp() {
    local timestamp="$1"
    local format="$2"
    
    case "$format" in
        "timeline")
            date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" "+%H:%M:%S" 2>/dev/null || echo "$timestamp"
            ;;
        *)
            date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp"
            ;;
    esac
}

# 格式化消息发送者
format_sender() {
    local sender="$1"
    local type="$2"
    
    case "$sender" in
        "external")
            echo "👤 用户"
            ;;
        "broadcast")
            echo "📢 广播"
            ;;
        *)
            echo "❓ $sender"
            ;;
    esac
}

# 文本格式输出
output_text_format() {
    local conversations="$1"
    local limit="$2"
    local since="$3"
    local type_filter="$4"
    
    echo "$conversations" | jq -r --arg limit "$limit" --arg since "$since" --arg type_filter "$type_filter" '
        .conversations[]
        | select(
            (if $since != "" then .timestamp >= $since else true end) and
            (if $type_filter != "" then .type == $type_filter else true end)
        )
        | "\(.timestamp)|\(.type)|\(.sender)|\(.message)"
    ' | head -n "${limit:-1000}" | while IFS='|' read -r timestamp type sender message; do
        local formatted_time=$(format_timestamp "$timestamp" "text")
        local formatted_sender=$(format_sender "$sender" "$type")
        
        echo "[$formatted_time] $formatted_sender"
        echo "$message"
        echo ""
    done
}

# 时间线格式输出
output_timeline_format() {
    local conversations="$1"
    local limit="$2"
    local since="$3"
    local type_filter="$4"
    
    echo "=== 对话时间线 ==="
    echo ""
    
    echo "$conversations" | jq -r --arg limit "$limit" --arg since "$since" --arg type_filter "$type_filter" '
        .conversations[]
        | select(
            (if $since != "" then .timestamp >= $since else true end) and
            (if $type_filter != "" then .type == $type_filter else true end)
        )
        | "\(.timestamp)|\(.type)|\(.sender)|\(.message)"
    ' | head -n "${limit:-1000}" | while IFS='|' read -r timestamp type sender message; do
        local formatted_time=$(format_timestamp "$timestamp" "timeline")
        local formatted_sender=$(format_sender "$sender" "$type")
        
        # 根据消息类型使用不同的颜色
        case "$type" in
            "message")
                echo -e "\033[0;36m$formatted_time\033[0m $formatted_sender: $message"
                ;;
            "broadcast")
                echo -e "\033[0;33m$formatted_time\033[0m $formatted_sender: $message"
                ;;
            *)
                echo "$formatted_time $formatted_sender: $message"
                ;;
        esac
    done
}

# JSON格式输出
output_json_format() {
    local conversations="$1"
    local limit="$2"
    local since="$3"
    local type_filter="$4"
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "错误: 需要安装 jq 才能使用 JSON 格式"
        return 1
    fi
    
    echo "$conversations" | jq --arg limit "${limit:-1000}" --arg since "${since:-}" --arg type_filter "${type_filter:-}" '{
        instance_id: .instance_id,
        namespace: .namespace,
        project_dir: .project_dir,
        created_at: .created_at,
        conversations: [
            .conversations[]
            | select(
                (if $since != "" then .timestamp >= $since else true end) and
                (if $type_filter != "" then .type == $type_filter else true end)
            )
        ][:($limit | tonumber)]
    }'
}

# 回放实例对话
replay_instance() {
    local instance_id="$1"
    local format="$2"
    local limit="$3"
    local since="$4"
    local type_filter="$5"
    
    # 查找对话文件
    local instance_dir=$(find_instance_info_dir "$instance_id")
    local conversation_file=""
    
    if [[ $? -eq 0 && -n "$instance_dir" ]]; then
        local ns_dir=$(dirname "$(dirname "$instance_dir")")
        conversation_file="$ns_dir/conversations/instance_$instance_id.json"
    else
        echo "错误: 无法找到实例 $instance_id"
        return 1
    fi
    
    if [[ ! -f "$conversation_file" ]]; then
        echo "错误: 实例 $instance_id 没有对话记录"
        return 1
    fi
    
    local conversations=$(cat "$conversation_file")
    local total_count=$(echo "$conversations" | jq '.conversations | length')
    
    echo "实例: $instance_id"
    echo "对话记录: $total_count 条"
    echo ""
    
    case "$format" in
        "json")
            output_json_format "$conversations" "$limit" "$since" "$type_filter"
            ;;
        "timeline")
            output_timeline_format "$conversations" "$limit" "$since" "$type_filter"
            ;;
        *)
            output_text_format "$conversations" "$limit" "$since" "$type_filter"
            ;;
    esac
}

# 回放namespace消息历史
replay_namespace() {
    local namespace="$1"
    local format="$2"
    local limit="$3"
    local since="$4"
    local type_filter="$5"
    
    local ns_dir="$CLIEXTRA_HOME/namespaces/$namespace"
    if [[ ! -d "$ns_dir" ]]; then
        echo "错误: namespace '$namespace' 不存在"
        return 1
    fi
    
    local conversations_dir="$ns_dir/conversations"
    if [[ ! -d "$conversations_dir" ]]; then
        echo "错误: namespace '$namespace' 没有对话记录"
        return 1
    fi
    
    echo "Namespace: $namespace"
    echo ""
    
    # 收集所有实例的对话记录
    local all_conversations="[]"
    
    for conv_file in "$conversations_dir"/instance_*.json; do
        if [[ -f "$conv_file" ]]; then
            local instance_conversations=$(cat "$conv_file")
            local instance_id=$(echo "$instance_conversations" | jq -r '.instance_id')
            
            # 为每条对话添加实例ID信息
            local enhanced_conversations=$(echo "$instance_conversations" | jq --arg instance_id "$instance_id" '
                .conversations[] | . + {"instance_id": $instance_id}
            ')
            
            all_conversations=$(echo "$all_conversations" | jq --argjson new "$enhanced_conversations" '. + [$new]')
        fi
    done
    
    # 按时间戳排序
    all_conversations=$(echo "$all_conversations" | jq 'sort_by(.timestamp)')
    
    local total_count=$(echo "$all_conversations" | jq 'length')
    echo "总对话记录: $total_count 条"
    echo ""
    
    # 根据格式输出
    case "$format" in
        "json")
            echo "$all_conversations" | jq --arg limit "$limit" --arg since "$since" --arg type_filter "$type_filter" '[
                .[]
                | select(
                    (if $since != "" then .timestamp >= $since else true end) and
                    (if $type_filter != "" then .type == $type_filter else true end)
                )
            ][:($limit | tonumber // 1000)]'
            ;;
        "timeline")
            echo "=== Namespace 对话时间线 ==="
            echo ""
            
            echo "$all_conversations" | jq -r --arg limit "$limit" --arg since "$since" --arg type_filter "$type_filter" '
                .[]
                | select(
                    (if $since != "" then .timestamp >= $since else true end) and
                    (if $type_filter != "" then .type == $type_filter else true end)
                )
                | "\(.timestamp)|\(.type)|\(.sender)|\(.instance_id)|\(.message)"
            ' | head -n "${limit:-1000}" | while IFS='|' read -r timestamp type sender instance_id message; do
                local formatted_time=$(format_timestamp "$timestamp" "timeline")
                local formatted_sender=$(format_sender "$sender" "$type")
                
                case "$type" in
                    "message")
                        echo -e "\033[0;36m$formatted_time\033[0m [$instance_id] $formatted_sender: $message"
                        ;;
                    "broadcast")
                        echo -e "\033[0;33m$formatted_time\033[0m [$instance_id] $formatted_sender: $message"
                        ;;
                    *)
                        echo "$formatted_time [$instance_id] $formatted_sender: $message"
                        ;;
                esac
            done
            ;;
        *)
            echo "$all_conversations" | jq -r --arg limit "$limit" --arg since "$since" --arg type_filter "$type_filter" '
                .[]
                | select(
                    (if $since != "" then .timestamp >= $since else true end) and
                    (if $type_filter != "" then .type == $type_filter else true end)
                )
                | "\(.timestamp)|\(.type)|\(.sender)|\(.instance_id)|\(.message)"
            ' | head -n "${limit:-1000}" | while IFS='|' read -r timestamp type sender instance_id message; do
                local formatted_time=$(format_timestamp "$timestamp" "text")
                local formatted_sender=$(format_sender "$sender" "$type")
                
                echo "[$formatted_time] [$instance_id] $formatted_sender"
                echo "$message"
                echo ""
            done
            ;;
    esac
}

# 解析参数
TYPE=""
TARGET=""
FORMAT="text"
LIMIT=""
SINCE=""
TYPE_FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        --since)
            SINCE="$2"
            shift 2
            ;;
        --type)
            TYPE_FILTER="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            echo "未知选项: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$TYPE" ]]; then
                TYPE="$1"
            elif [[ -z "$TARGET" ]]; then
                TARGET="$1"
            fi
            shift
            ;;
    esac
done

# 主逻辑
if [[ -z "$TYPE" || -z "$TARGET" ]]; then
    echo "错误: 请指定类型和目标"
    show_help
    exit 1
fi

case "$TYPE" in
    "instance")
        replay_instance "$TARGET" "$FORMAT" "$LIMIT" "$SINCE" "$TYPE_FILTER"
        ;;
    "namespace")
        replay_namespace "$TARGET" "$FORMAT" "$LIMIT" "$SINCE" "$TYPE_FILTER"
        ;;
    *)
        echo "错误: 未知类型 '$TYPE'"
        show_help
        exit 1
        ;;
esac
