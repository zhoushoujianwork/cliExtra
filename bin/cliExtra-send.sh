#!/bin/bash

# cliExtra 消息发送脚本

# 加载公共函数、配置和状态管理器
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"
source "$SCRIPT_DIR/cliExtra-sender-id.sh"
source "$SCRIPT_DIR/cliExtra-dag-hooks.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra send <instance_id> <message> [options]"
    echo ""
    echo "参数:"
    echo "  instance_id   目标实例ID"
    echo "  message       要发送的消息内容"
    echo ""
    echo "选项:"
    echo "  --force       强制发送，忽略实例状态检查"
    echo "  --wait-idle   等待实例变为空闲状态后发送"
    echo "  --sender-id   添加发送者标识到消息（默认启用）"
    echo "  --no-sender-id 不添加发送者标识到消息"
    echo ""
    echo "状态检查说明:"
    echo "  默认只向 idle (空闲) 状态的实例发送消息"
    echo "  非空闲状态的实例会被跳过，避免打断工作"
    echo "  使用 --force 可以强制发送到任何状态的实例"
    echo ""
    echo "发送者标识说明:"
    echo "  默认情况下，消息会自动添加发送者标识，格式为："
    echo "  [发送者: namespace:instance_id] 原始消息内容"
    echo "  "
    echo "  这有助于："
    echo "  - DAG 流程追踪和状态更新"
    echo "  - 协作上下文识别"
    echo "  - 消息来源追踪和审计"
    echo ""
    echo "示例:"
    echo "  cliExtra send backend-api \"API开发完成，请进行前端集成\""
    echo "  cliExtra send frontend-dev \"请更新用户界面组件\" --force"
    echo "  cliExtra send backend-api \"重要通知\" --wait-idle"
    echo "  cliExtra send test-instance \"调试消息\" --no-sender-id"
}

# 检查实例状态是否可以接收消息
check_instance_status() {
    local instance_id="$1"
    local force_send="${2:-false}"
    
    # 如果是强制发送，直接返回成功
    if [[ "$force_send" == "true" ]]; then
        return 0
    fi
    
    # 获取实例的namespace
    local namespace=$(get_instance_namespace "$instance_id")
    if [[ -z "$namespace" ]]; then
        namespace="$CLIEXTRA_DEFAULT_NS"
    fi
    
    # 读取简化状态值
    local status_value=$(read_status_file "$instance_id" "$namespace")
    
    # 检查状态：0=idle 可以发送，1=busy 不能发送
    if [[ "$status_value" == "0" ]]; then
        return 0  # 可以发送
    else
        # 显示状态信息
        local status_name=$(status_to_name "$status_value")
        local status_desc=""
        case "$status_name" in
            "busy") status_desc="忙碌" ;;
            *) status_desc="$status_name" ;;
        esac
        
        echo "实例 $instance_id 当前状态为 $status_desc，无法发送消息"
        echo "提示: 使用 --force 参数可以强制发送"
        return 1  # 不能发送
    fi
}

# 等待实例变为空闲状态
wait_for_idle() {
    local instance_id="$1"
    local max_wait="${2:-300}"  # 默认最多等待5分钟
    local check_interval=5      # 每5秒检查一次
    local waited=0
    
    echo "等待实例 $instance_id 变为空闲状态..."
    
    while [[ $waited -lt $max_wait ]]; do
        if check_instance_status "$instance_id" "false" >/dev/null 2>&1; then
            echo "✓ 实例 $instance_id 现在是空闲状态"
            return 0
        fi
        
        sleep $check_interval
        waited=$((waited + check_interval))
        
        # 显示等待进度
        if [[ $((waited % 30)) -eq 0 ]]; then
            echo "已等待 ${waited}s，继续等待实例空闲..."
        fi
    done
    
    echo "等待超时 (${max_wait}s)，实例 $instance_id 仍未空闲"
    return 1
}

# 记录对话到实例对话文件
record_conversation() {
    local instance_id="$1"
    local message="$2"
    local sender="$3"
    local timestamp="$4"
    
    # 从工作目录查找实例信息
    local instance_dir=$(find_instance_info_dir "$instance_id")
    local conversation_file=""
    local namespace="default"
    
    if [[ $? -eq 0 && -n "$instance_dir" ]]; then
        # 从工作目录结构获取对话文件
        local ns_dir=$(dirname "$(dirname "$instance_dir")")
        conversation_file="$ns_dir/conversations/instance_$instance_id.json"
        namespace=$(basename "$ns_dir")
    else
        # 向后兼容：查找实例所在的项目目录
        local project_dir=$(find_instance_project "$instance_id")
        if [[ $? -ne 0 ]]; then
            echo "警告: 无法找到实例 $instance_id，跳过对话记录"
            return 1
        fi
        
        # 获取实例namespace
        namespace=$(get_instance_namespace_from_project "$project_dir" "$instance_id")
        conversation_file="$(get_instance_conversation_dir "$namespace")/instance_$instance_id.json"
    fi
    
    # 确保对话文件存在
    if [[ ! -f "$conversation_file" ]]; then
        mkdir -p "$(dirname "$conversation_file")"
        cat > "$conversation_file" << EOF
{
  "instance_id": "$instance_id",
  "namespace": "$namespace",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "conversations": []
}
EOF
    fi
    
    # 使用jq添加对话记录
    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        jq --arg timestamp "$timestamp" \
           --arg sender "$sender" \
           --arg message "$message" \
           --arg type "message" \
           '.conversations += [{
               "timestamp": $timestamp,
               "type": $type,
               "sender": $sender,
               "message": $message
           }]' "$conversation_file" > "$temp_file" && mv "$temp_file" "$conversation_file"
        
        echo "✓ 对话已记录到: $conversation_file"
    else
        echo "警告: jq未安装，无法记录对话"
    fi
}

# 更新namespace缓存文件
update_namespace_cache_file() {
    local cache_file="$1"
    local instance_id="$2"
    local action="$3"
    local timestamp="$4"
    local message="$5"
    
    # 使用jq更新缓存文件
    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        jq --arg instance_id "$instance_id" \
           --arg action "$action" \
           --arg timestamp "$timestamp" \
           --arg message "$message" \
           '.instances[$instance_id] = {
               "last_action": $action,
               "last_update": $timestamp,
               "status": (if $action == "started" then "running" elif $action == "stopped" then "stopped" else "unknown" end)
           } |
           if $message != "" then
               .message_history += [{
                   "timestamp": $timestamp,
                   "instance_id": $instance_id,
                   "action": $action,
                   "message": $message
               }]
           else . end' "$cache_file" > "$temp_file" && mv "$temp_file" "$cache_file"
    else
        echo "警告: jq未安装，无法更新namespace缓存"
    fi
}

# 更新namespace缓存
update_namespace_cache() {
    local project_dir="$1"
    local namespace="$2"
    local instance_id="$3"
    local action="$4"
    local timestamp="$5"
    local message="$6"
    
    local cache_file="$(get_namespace_dir "$namespace")/namespace_cache.json"
    
    # 确保缓存文件存在
    if [[ ! -f "$cache_file" ]]; then
        mkdir -p "$(dirname "$cache_file")"
        cat > "$cache_file" << EOF
{
  "namespace": "$namespace",
  "project_dir": "$project_dir",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "instances": {},
  "message_history": []
}
EOF
    fi
    
    # 使用jq更新缓存
    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        jq --arg instance_id "$instance_id" \
           --arg action "$action" \
           --arg timestamp "$timestamp" \
           --arg message "$message" \
           '.instances[$instance_id].last_message_received = $timestamp |
           .message_history += [{
               "timestamp": $timestamp,
               "instance_id": $instance_id,
               "action": $action,
               "message": $message
           }]' "$cache_file" > "$temp_file" && mv "$temp_file" "$cache_file"
    fi
}

# 获取实例namespace（从项目目录）
get_instance_namespace_from_project() {
    local project_dir="$1"
    local instance_id="$2"
    
    # 首先尝试新的namespace目录结构
    for ns_dir in "$project_dir/.cliExtra/namespaces"/*; do
        if [[ -d "$ns_dir" ]]; then
            local instance_dir="$ns_dir/instances/instance_$instance_id"
            if [[ -d "$instance_dir" ]]; then
                basename "$ns_dir"
                return 0
            fi
        fi
    done
    
    # 回退到旧的结构
    local old_instance_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
    if [[ -d "$old_instance_dir" ]]; then
        local ns_file="$old_instance_dir/namespace"
        if [[ -f "$ns_file" ]]; then
            cat "$ns_file"
        else
            echo "default"
        fi
        return 0
    fi
    
    echo "default"
}

# 发送消息到实例
send_message_to_instance() {
    local instance_id="$1"
    local message="$2"
    local force_send="${3:-false}"
    local add_sender_id="${4:-true}"
    local session_name="q_instance_$instance_id"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # 检查实例是否运行
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "错误: 实例 $instance_id 未运行"
        return 1
    fi
    
    # 检查实例状态（除非强制发送）
    if ! check_instance_status "$instance_id" "$force_send"; then
        return 1
    fi
    
    # 添加发送者标识（如果启用）
    local final_message="$message"
    if [[ "$add_sender_id" == "true" ]]; then
        final_message=$(add_sender_id_to_message "$message")
    fi
    
    # 发送消息到tmux会话
    tmux send-keys -t "$session_name" "$final_message" Enter
    
    echo "✓ 消息已发送到实例 $instance_id: $message"
    
    # 记录发送者追踪信息
    if [[ "$add_sender_id" == "true" ]]; then
        local sender_info=$(get_sender_info)
        local namespace=$(get_instance_namespace "$instance_id")
        if [[ -z "$namespace" ]]; then
            namespace="$CLIEXTRA_DEFAULT_NS"
        fi
        local receiver_info="$namespace:$instance_id"
        record_sender_tracking "$sender_info" "$receiver_info" "$message"
    fi
    
    # DAG 钩子：检测任务完成消息并更新 DAG 状态
    # 检查是否禁用 DAG 钩子（避免递归调用）
    if [[ "$DISABLE_DAG_HOOKS" != "true" ]]; then
        local sender_info=$(get_sender_info)
        local sender_id=$(echo "$sender_info" | cut -d':' -f2)
        
        # 临时测试：如果设置了 SENDER_INSTANCE_ID 环境变量，使用它作为发送者
        if [[ -n "$SENDER_INSTANCE_ID" ]]; then
            sender_id="$SENDER_INSTANCE_ID"
            echo "🔍 使用测试发送者: $sender_id"
        fi
        
        local receiver_namespace=$(get_instance_namespace "$instance_id")
        if [[ -z "$receiver_namespace" ]]; then
            receiver_namespace="$CLIEXTRA_DEFAULT_NS"
        fi
        
        # 调用 DAG 钩子
        dag_send_hook "$sender_id" "$instance_id" "$message" "$receiver_namespace"
    fi
    
    # 自动设置接收实例状态为 busy
    local namespace=$(get_instance_namespace "$instance_id")
    if [[ -z "$namespace" ]]; then
        namespace="$CLIEXTRA_DEFAULT_NS"
    fi
    
    if auto_set_busy_on_message "$instance_id" "$message" "$namespace"; then
        echo "✓ 实例状态已自动设置为忙碌"
    fi
    
    # 记录对话
    record_conversation "$instance_id" "$final_message" "external" "$timestamp"
    
    # 更新namespace缓存
    local instance_dir=$(find_instance_info_dir "$instance_id")
    if [[ $? -eq 0 && -n "$instance_dir" ]]; then
        # 从工作目录结构更新缓存
        local ns_dir=$(dirname "$(dirname "$instance_dir")")
        local ns_cache_file="$ns_dir/namespace_cache.json"
        local namespace=$(basename "$ns_dir")
        
        update_namespace_cache_file "$ns_cache_file" "$instance_id" "message_received" "$timestamp" "$message"
    else
        # 向后兼容：查找项目目录并更新namespace缓存
        local project_dir=$(find_instance_project "$instance_id")
        if [[ $? -eq 0 ]]; then
            local namespace=$(get_instance_namespace_from_project "$project_dir" "$instance_id")
            update_namespace_cache "$project_dir" "$namespace" "$instance_id" "message_received" "$timestamp" "$message"
        fi
    fi
}

# 解析参数
if [[ $# -lt 2 ]]; then
    echo "错误: 参数不足"
    show_help
    exit 1
fi

# 参数解析
INSTANCE_ID=""
MESSAGE=""
FORCE_SEND=false
WAIT_IDLE=false
ADD_SENDER_ID=true

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_SEND=true
            shift
            ;;
        --wait-idle)
            WAIT_IDLE=true
            shift
            ;;
        --no-sender-id)
            ADD_SENDER_ID=false
            shift
            ;;
        --sender-id)
            ADD_SENDER_ID=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            echo "错误: 未知选项 $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$INSTANCE_ID" ]]; then
                INSTANCE_ID="$1"
            elif [[ -z "$MESSAGE" ]]; then
                MESSAGE="$1"
            else
                echo "错误: 多余的参数 $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# 检查必需参数
if [[ -z "$INSTANCE_ID" ]]; then
    echo "错误: 请指定实例ID"
    show_help
    exit 1
fi

if [[ -z "$MESSAGE" ]]; then
    echo "错误: 请指定消息内容"
    show_help
    exit 1
fi

# 如果需要等待空闲状态
if [[ "$WAIT_IDLE" == "true" ]]; then
    if ! wait_for_idle "$INSTANCE_ID"; then
        echo "错误: 实例未变为空闲状态，取消发送"
        exit 1
    fi
fi

# 发送消息
send_message_to_instance "$INSTANCE_ID" "$MESSAGE" "$FORCE_SEND" "$ADD_SENDER_ID"
