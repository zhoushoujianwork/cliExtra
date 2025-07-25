#!/bin/bash

# cliExtra DAG 钩子函数
# 用于在消息发送时检测和更新 DAG 状态

# 加载依赖
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"

# DAG 配置
DAG_DIR_SUFFIX="dags"

# 获取 namespace 的 DAG 目录
get_dag_dir() {
    local namespace="${1:-$CLIEXTRA_DEFAULT_NS}"
    echo "$CLIEXTRA_HOME/namespaces/$namespace/$DAG_DIR_SUFFIX"
}

# 查找活跃的 DAG 实例
find_active_dag_instances() {
    local namespace="${1:-}"
    local dag_instances=()
    
    if [[ -n "$namespace" ]]; then
        # 只查找指定 namespace
        local dag_dir=$(get_dag_dir "$namespace")
        if [[ -d "$dag_dir" ]]; then
            while IFS= read -r -d '' dag_file; do
                local status=$(jq -r '.status' "$dag_file" 2>/dev/null)
                if [[ "$status" == "running" ]]; then
                    dag_instances+=("$dag_file")
                fi
            done < <(find "$dag_dir" -name "dag_*.json" -print0 2>/dev/null)
        fi
    else
        # 查找所有 namespace
        if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
            while IFS= read -r -d '' ns_dir; do
                local dag_dir="$ns_dir/$DAG_DIR_SUFFIX"
                if [[ -d "$dag_dir" ]]; then
                    while IFS= read -r -d '' dag_file; do
                        local status=$(jq -r '.status' "$dag_file" 2>/dev/null)
                        if [[ "$status" == "running" ]]; then
                            dag_instances+=("$dag_file")
                        fi
                    done < <(find "$dag_dir" -name "dag_*.json" -print0 2>/dev/null)
                fi
            done < <(find "$CLIEXTRA_HOME/namespaces" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
        fi
    fi
    
    printf '%s\n' "${dag_instances[@]}"
}

# 检测消息是否为任务完成消息
is_completion_message() {
    local message="$1"
    
    # 完成关键词模式
    local completion_patterns=(
        "完成"
        "完结"
        "finished"
        "done"
        "ready"
        "已完成"
        "开发完成"
        "测试完成"
        "部署完成"
        "实现完成"
        "集成完成"
        "可以开始"
        "请开始"
        "交付"
        "delivery"
        "deliverable"
        "提交"
    )
    
    for pattern in "${completion_patterns[@]}"; do
        if echo "$message" | grep -qi "$pattern"; then
            return 0
        fi
    done
    
    return 1
}

# 检测消息是否为工作流启动消息
is_workflow_start_message() {
    local message="$1"
    local sender="$2"
    
    # 允许 system:admin 或包含 "user" 的发送者启动工作流（用于测试）
    if [[ "$sender" != "system:admin" && "$sender" != *"user"* ]]; then
        return 1
    fi
    
    # 启动关键词模式
    local start_patterns=(
        "开始.*协作"
        "启动.*流程"
        "start.*workflow"
        "开始.*开发"
        "启动.*项目"
        "三角色协作"
        "后端.*前端.*运维"
    )
    
    for pattern in "${start_patterns[@]}"; do
        if echo "$message" | grep -qiE "$pattern"; then
            return 0
        fi
    done
    
    return 1
}

# 从消息中提取工作流名称
extract_workflow_name() {
    local message="$1"
    
    # 简单的工作流名称匹配
    if echo "$message" | grep -qi "三角色\|3.*角色"; then
        echo "simple-3roles-workflow"
        return 0
    fi
    
    # 默认工作流
    echo "simple-3roles-workflow"
    return 0
}

# 根据实例角色和名称匹配 DAG 节点
match_dag_node_by_instance() {
    local instance_id="$1"
    local namespace="$2"
    local workflow_file="$3"
    
    # 获取实例角色
    local role=$(get_instance_role "$instance_id" "$namespace")
    
    if [[ -z "$role" ]]; then
        # 如果没有角色，尝试从实例名称推断
        case "$instance_id" in
            *backend*) role="backend" ;;
            *frontend*) role="frontend" ;;
            *devops*) role="devops" ;;
            *) return 1 ;;
        esac
    fi
    
    # 从工作流文件中查找对应的节点
    if [[ -f "$workflow_file" ]]; then
        local nodes=$(jq -r ".nodes | to_entries[] | select(.value.owner == \"$role\") | .key" "$workflow_file" 2>/dev/null)
        if [[ -n "$nodes" ]]; then
            echo "$nodes" | head -1  # 返回第一个匹配的节点
            return 0
        fi
    fi
    
    return 1
}

# 更新 DAG 节点状态
update_dag_node_status() {
    local dag_file="$1"
    local node_id="$2"
    local new_status="$3"
    local sender="$4"
    local message="$5"
    
    # 创建临时文件
    local temp_file=$(mktemp)
    
    # 更新 DAG 状态
    jq --arg node_id "$node_id" \
       --arg new_status "$new_status" \
       --arg sender "$sender" \
       --arg message "$message" \
       --arg timestamp "$(date -Iseconds)" \
       '
       # 更新节点状态
       .current_nodes = (.current_nodes - [$node_id]) |
       if $new_status == "completed" then
           .completed_nodes = (.completed_nodes + [$node_id] | unique)
       elif $new_status == "blocked" then
           .blocked_nodes = (.blocked_nodes + [$node_id] | unique)
       elif $new_status == "failed" then
           .failed_nodes = (.failed_nodes + [$node_id] | unique)
       else
           .current_nodes = (.current_nodes + [$node_id] | unique)
       end |
       
       # 添加执行历史
       .node_execution_history += [{
           "node_id": $node_id,
           "status": $new_status,
           "started_at": $timestamp,
           "completed_at": $timestamp,
           "trigger": {
               "sender": $sender,
               "message": $message
           }
       }] |
       
       # 添加消息追踪
       .message_tracking += [{
           "timestamp": $timestamp,
           "sender": $sender,
           "action": "node_update",
           "message": $message,
           "dag_context": {
               "node_id": $node_id,
               "status": $new_status
           }
       }]
       ' "$dag_file" > "$temp_file"
    
    if [[ $? -eq 0 ]]; then
        mv "$temp_file" "$dag_file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# 查找下一个节点并触发
trigger_next_dag_node() {
    local dag_file="$1"
    local completed_node="$2"
    
    # 读取工作流定义
    local workflow_file=$(jq -r '.workflow_file' "$dag_file")
    if [[ ! -f "$workflow_file" ]]; then
        return 1
    fi
    
    # 查找下一个节点（简化版本，实际需要根据工作流图结构）
    local next_node=""
    case "$completed_node" in
        "backend_dev")
            next_node="frontend_review"
            ;;
        "frontend_review")
            next_node="devops_deploy"
            ;;
        *)
            # 没有下一个节点
            return 0
            ;;
    esac
    
    if [[ -n "$next_node" ]]; then
        # 更新当前节点
        local temp_file=$(mktemp)
        jq --arg next_node "$next_node" \
           --arg timestamp "$(date -Iseconds)" \
           '.current_nodes = (.current_nodes + [$next_node] | unique) |
            .message_tracking += [{
                "timestamp": $timestamp,
                "sender": "system:dag",
                "action": "node_triggered",
                "message": ("自动触发下一个节点: " + $next_node),
                "dag_context": {
                    "node_id": $next_node,
                    "status": "triggered"
                }
            }]' "$dag_file" > "$temp_file"
        
        if [[ $? -eq 0 ]]; then
            mv "$temp_file" "$dag_file"
            
            # 发送任务分配消息（这里需要实现具体的消息发送逻辑）
            echo "🔄 DAG 自动触发下一个节点: $next_node"
            return 0
        else
            rm -f "$temp_file"
        fi
    fi
    
    return 1
}

# 主要的 DAG 钩子函数 - 在消息发送时调用
dag_send_hook() {
    local sender="$1"
    local receiver="$2"
    local message="$3"
    local receiver_namespace="$4"
    
    echo "🔍 DAG 发送钩子被调用: sender=$sender, receiver=$receiver"
    
    # 检查是否为工作流启动消息（广播）
    if [[ "$receiver" == "broadcast" ]] && is_workflow_start_message "$message" "$sender"; then
        echo "🚀 检测到工作流启动消息，创建 DAG 实例..."
        
        local workflow_name=$(extract_workflow_name "$message")
        local namespace="${receiver_namespace:-$CLIEXTRA_DEFAULT_NS}"
        
        # 创建 DAG 实例
        local dag_id=$("$SCRIPT_DIR/cliExtra-dag.sh" create "$workflow_name" "$namespace" "$message" "$sender" 2>/dev/null | tail -1)
        
        if [[ -n "$dag_id" ]]; then
            echo "✓ DAG 实例已创建: $dag_id"
        fi
        
        return 0
    fi
    
    # 检查是否为任务完成消息
    if [[ "$receiver" != "broadcast" ]] && is_completion_message "$message"; then
        echo "🔍 检测到任务完成消息，检查 DAG 状态..."
        echo "🔍 发送者: $sender, 接收者: $receiver"
        
        # 获取发送者的 namespace
        local sender_namespace=$(get_instance_namespace "$sender")
        if [[ -z "$sender_namespace" ]]; then
            sender_namespace="$CLIEXTRA_DEFAULT_NS"
        fi
        
        echo "🔍 发送者 namespace: $sender_namespace"
        
        # 查找活跃的 DAG 实例
        local dag_instances_output=$(find_active_dag_instances "$sender_namespace")
        local dag_instances=()
        
        # 将输出转换为数组
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                dag_instances+=("$line")
            fi
        done <<< "$dag_instances_output"
        
        echo "🔍 找到 ${#dag_instances[@]} 个活跃的 DAG 实例"
        
        for dag_file in "${dag_instances[@]}"; do
            local workflow_file=$(jq -r '.workflow_file' "$dag_file" 2>/dev/null)
            local dag_id=$(jq -r '.dag_instance_id' "$dag_file" 2>/dev/null)
            
            echo "🔍 检查 DAG: $dag_id"
            echo "🔍 工作流文件: $workflow_file"
            
            # 匹配发送者对应的 DAG 节点
            local node_id=$(match_dag_node_by_instance "$sender" "$sender_namespace" "$workflow_file")
            
            echo "🔍 匹配到的节点: $node_id"
            
            if [[ -n "$node_id" ]]; then
                echo "📝 更新 DAG 节点状态: $dag_id -> $node_id (completed)"
                
                # 更新节点状态为完成
                if update_dag_node_status "$dag_file" "$node_id" "completed" "$sender" "$message"; then
                    echo "✓ DAG 节点状态已更新"
                    
                    # 尝试触发下一个节点
                    trigger_next_dag_node "$dag_file" "$node_id"
                fi
                
                break  # 只更新第一个匹配的 DAG
            fi
        done
    fi
    
    return 0
}

# 广播钩子函数
dag_broadcast_hook() {
    local sender="$1"
    local message="$2"
    local target_namespace="$3"
    
    echo "🔍 DAG 广播钩子被调用: sender=$sender, message=$message"
    
    # 调用发送钩子，receiver 设为 "broadcast"
    dag_send_hook "$sender" "broadcast" "$message" "$target_namespace"
}
