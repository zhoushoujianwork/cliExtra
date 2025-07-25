#!/bin/bash

# cliExtra 发送者标识管理器
# 用于在消息中自动添加发送者信息，支持协作追踪和DAG流程管理

# 加载配置和公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 获取当前发送者信息
get_sender_info() {
    local current_instance=""
    local current_namespace=""
    
    # 尝试从环境变量获取当前实例信息
    if [[ -n "$CLIEXTRA_CURRENT_INSTANCE" ]]; then
        current_instance="$CLIEXTRA_CURRENT_INSTANCE"
    fi
    
    if [[ -n "$CLIEXTRA_CURRENT_NAMESPACE" ]]; then
        current_namespace="$CLIEXTRA_CURRENT_NAMESPACE"
    fi
    
    # 如果环境变量不存在，尝试从当前目录推断
    if [[ -z "$current_instance" ]]; then
        # 检查是否在实例目录中
        local pwd_path=$(pwd)
        if [[ "$pwd_path" == *"/cliExtra/"* ]]; then
            # 尝试从路径推断实例信息
            current_instance="system"
            current_namespace="default"
        else
            # 使用默认值
            current_instance="admin"
            current_namespace="system"
        fi
    fi
    
    echo "${current_namespace}:${current_instance}"
}

# 格式化发送者标识
format_sender_id() {
    local sender_info="$1"
    local format_type="${2:-bracket}"  # bracket, prefix, suffix
    
    case "$format_type" in
        "bracket")
            echo "[发送者: $sender_info]"
            ;;
        "prefix")
            echo "[$sender_info]"
            ;;
        "suffix")
            echo "($sender_info)"
            ;;
        "simple")
            echo "$sender_info:"
            ;;
        *)
            echo "[发送者: $sender_info]"
            ;;
    esac
}

# 添加发送者标识到消息
add_sender_id_to_message() {
    local message="$1"
    local sender_info="${2:-$(get_sender_info)}"
    local format_type="${3:-bracket}"
    local auto_mode="${4:-true}"
    
    # 如果不是自动模式，直接返回原消息
    if [[ "$auto_mode" != "true" ]]; then
        echo "$message"
        return 0
    fi
    
    # 检查消息是否已经包含发送者标识
    if [[ "$message" =~ ^\[发送者:.*\] ]] || [[ "$message" =~ ^\[.*:.*\] ]]; then
        echo "$message"
        return 0
    fi
    
    # 格式化发送者标识
    local sender_tag=$(format_sender_id "$sender_info" "$format_type")
    
    # 添加发送者标识
    echo "$sender_tag $message"
}

# 从消息中提取发送者信息
extract_sender_from_message() {
    local message="$1"
    
    # 匹配不同格式的发送者标识
    if [[ "$message" =~ ^\[发送者:\ ([^]]+)\] ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$message" =~ ^\[([^:]+:[^]]+)\] ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$message" =~ ^([^:]+:[^:]+): ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# 从消息中移除发送者标识
remove_sender_id_from_message() {
    local message="$1"
    
    # 移除不同格式的发送者标识
    if [[ "$message" =~ ^\[发送者:\ [^]]+\]\ (.*) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$message" =~ ^\[[^]]+\]\ (.*) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$message" =~ ^[^:]+:[^:]+:\ (.*) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "$message"
    fi
}

# 验证发送者标识格式
validate_sender_id() {
    local sender_id="$1"
    
    # 检查格式：namespace:instance_id
    if [[ "$sender_id" =~ ^[a-zA-Z0-9_-]+:[a-zA-Z0-9_-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# 解析发送者标识
parse_sender_id() {
    local sender_id="$1"
    local output_format="${2:-space}"  # space, json, array
    
    if ! validate_sender_id "$sender_id"; then
        echo "错误: 无效的发送者标识格式: $sender_id" >&2
        return 1
    fi
    
    local namespace="${sender_id%:*}"
    local instance_id="${sender_id#*:}"
    
    case "$output_format" in
        "json")
            echo "{\"namespace\": \"$namespace\", \"instance_id\": \"$instance_id\"}"
            ;;
        "array")
            echo "$namespace $instance_id"
            ;;
        "space")
            echo "$namespace $instance_id"
            ;;
        *)
            echo "$namespace $instance_id"
            ;;
    esac
}

# 记录发送者追踪信息
record_sender_tracking() {
    local sender_id="$1"
    local receiver_id="$2"
    local message="$3"
    local timestamp="${4:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
    
    # 创建追踪记录目录
    local tracking_dir="$CLIEXTRA_HOME/tracking"
    mkdir -p "$tracking_dir"
    
    # 追踪文件路径
    local tracking_file="$tracking_dir/message_tracking.log"
    
    # 记录追踪信息
    local tracking_entry="$timestamp|$sender_id|$receiver_id|$(echo "$message" | head -c 100)..."
    echo "$tracking_entry" >> "$tracking_file"
    
    # 保持追踪文件大小（最多1000行）
    if [[ $(wc -l < "$tracking_file") -gt 1000 ]]; then
        tail -n 500 "$tracking_file" > "${tracking_file}.tmp"
        mv "${tracking_file}.tmp" "$tracking_file"
    fi
}

# 获取发送者统计信息
get_sender_statistics() {
    local tracking_file="$CLIEXTRA_HOME/tracking/message_tracking.log"
    local time_range="${1:-24h}"  # 24h, 7d, 30d, all
    
    if [[ ! -f "$tracking_file" ]]; then
        echo "暂无追踪数据"
        return 0
    fi
    
    local cutoff_time=""
    case "$time_range" in
        "24h")
            cutoff_time=$(date -u -d "24 hours ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-24H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
            ;;
        "7d")
            cutoff_time=$(date -u -d "7 days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-7d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
            ;;
        "30d")
            cutoff_time=$(date -u -d "30 days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-30d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
            ;;
        "all")
            cutoff_time=""
            ;;
    esac
    
    echo "=== 发送者统计 ($time_range) ==="
    
    # 过滤时间范围内的记录
    local filtered_data
    if [[ -n "$cutoff_time" ]]; then
        filtered_data=$(awk -F'|' -v cutoff="$cutoff_time" '$1 >= cutoff' "$tracking_file")
    else
        filtered_data=$(cat "$tracking_file")
    fi
    
    if [[ -z "$filtered_data" ]]; then
        echo "指定时间范围内无数据"
        return 0
    fi
    
    echo "发送者排行:"
    echo "$filtered_data" | awk -F'|' '{print $2}' | sort | uniq -c | sort -nr | head -10
    
    echo -e "\n接收者排行:"
    echo "$filtered_data" | awk -F'|' '{print $3}' | sort | uniq -c | sort -nr | head -10
    
    echo -e "\n总消息数: $(echo "$filtered_data" | wc -l)"
}

# 显示帮助信息
show_help() {
    cat << 'EOF'
cliExtra 发送者标识管理器

用法:
  cliExtra-sender-id.sh <command> [options]

命令:
  get-sender                    获取当前发送者信息
  add-id <message>             为消息添加发送者标识
  extract-id <message>         从消息中提取发送者信息
  remove-id <message>          从消息中移除发送者标识
  validate <sender_id>         验证发送者标识格式
  parse <sender_id>            解析发送者标识
  track <sender> <receiver> <message>  记录追踪信息
  stats [time_range]           显示发送者统计信息

选项:
  --format <type>              标识格式: bracket, prefix, suffix, simple
  --auto <true|false>          自动模式开关
  --output <format>            输出格式: space, json, array

示例:
  # 获取当前发送者信息
  cliExtra-sender-id.sh get-sender
  
  # 为消息添加发送者标识
  cliExtra-sender-id.sh add-id "API开发完成"
  
  # 提取发送者信息
  cliExtra-sender-id.sh extract-id "[发送者: backend:api-dev] API开发完成"
  
  # 查看统计信息
  cliExtra-sender-id.sh stats 24h
EOF
}

# 主函数
main() {
    local command="${1:-help}"
    shift
    
    case "$command" in
        "get-sender")
            get_sender_info
            ;;
        "add-id")
            local message="$1"
            local sender_info="$2"
            local format_type="$3"
            local auto_mode="$4"
            add_sender_id_to_message "$message" "$sender_info" "$format_type" "$auto_mode"
            ;;
        "extract-id")
            extract_sender_from_message "$1"
            ;;
        "remove-id")
            remove_sender_id_from_message "$1"
            ;;
        "validate")
            if validate_sender_id "$1"; then
                echo "✓ 有效的发送者标识: $1"
                return 0
            else
                echo "✗ 无效的发送者标识: $1"
                return 1
            fi
            ;;
        "parse")
            parse_sender_id "$1" "$2"
            ;;
        "track")
            record_sender_tracking "$1" "$2" "$3"
            ;;
        "stats")
            get_sender_statistics "$1"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo "错误: 未知命令 '$command'"
            show_help
            exit 1
            ;;
    esac
}

# 如果直接执行脚本，调用主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
