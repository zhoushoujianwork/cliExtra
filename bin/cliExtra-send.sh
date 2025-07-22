#!/bin/bash

# cliExtra 消息发送脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra send <instance_id> <message>"
    echo ""
    echo "参数:"
    echo "  instance_id   目标实例ID"
    echo "  message       要发送的消息内容"
    echo ""
    echo "示例:"
    echo "  cliExtra send backend-api \"API开发完成，请进行前端集成\""
    echo "  cliExtra send frontend-dev \"请更新用户界面组件\""
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
    local session_name="q_instance_$instance_id"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # 检查实例是否运行
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "错误: 实例 $instance_id 未运行"
        return 1
    fi
    
    # 发送消息到tmux会话
    tmux send-keys -t "$session_name" "$message" Enter
    
    echo "✓ 消息已发送到实例 $instance_id: $message"
    
    # 记录对话
    record_conversation "$instance_id" "$message" "external" "$timestamp"
    
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

INSTANCE_ID="$1"
MESSAGE="$2"

# 检查参数
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

# 发送消息
send_message_to_instance "$INSTANCE_ID" "$MESSAGE"
