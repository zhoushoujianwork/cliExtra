#!/bin/bash

# cliExtra-workflow-engine.sh - Workflow 执行引擎

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 获取workflow配置
get_workflow_config() {
    local ns_name="${1:-$(get_current_namespace)}"
    local workflow_file="$(get_namespace_dir "$ns_name")/workflow.json"
    
    if [[ -f "$workflow_file" ]]; then
        cat "$workflow_file"
    else
        echo "错误: 未找到workflow配置文件: $workflow_file" >&2
        return 1
    fi
}

# 查找角色对应的实例
find_role_instance() {
    local role="$1"
    local workflow_config="$2"
    
    # 从配置中获取实例匹配模式
    local pattern=$(echo "$workflow_config" | jq -r ".roles.$role.instance_pattern // \"*$role*\"")
    
    # 查找匹配的实例
    local instances=$(qq list 2>/dev/null | grep -i "$role" | head -1)
    
    if [[ -n "$instances" ]]; then
        echo "$instances"
    else
        echo "警告: 未找到角色 '$role' 对应的实例" >&2
        return 1
    fi
}

# 发送任务完成通知
send_completion_notification() {
    local task_id="$1"
    local ns_name="$2"
    local deliverables="$3"
    
    local workflow_config=$(get_workflow_config "$ns_name")
    
    # 获取任务配置
    local task_config=$(echo "$workflow_config" | jq -r ".nodes.$task_id")
    local trigger_config=$(echo "$task_config" | jq -r ".completion_trigger")
    
    if [[ "$trigger_config" != "null" ]]; then
        local target_role=$(echo "$trigger_config" | jq -r ".target")
        local message_template=$(echo "$trigger_config" | jq -r ".message_template")
        local auto_send=$(echo "$trigger_config" | jq -r ".auto_send")
        
        # 查找目标实例
        local target_instance=$(find_role_instance "$target_role" "$workflow_config")
        
        if [[ -n "$target_instance" ]]; then
            # 替换消息模板中的变量
            local message="$message_template"
            message="${message//\{deliverables\}/$deliverables}"
            message="${message//\{task_id\}/$task_id}"
            
            echo "📤 发送通知给 $target_role ($target_instance):"
            echo "$message"
            echo ""
            
            if [[ "$auto_send" == "true" ]]; then
                # 实际发送命令
                echo "执行命令: qq send $target_instance \"$message\""
                # qq send "$target_instance" "$message"
            else
                echo "建议执行: qq send $target_instance \"$message\""
            fi
        fi
    fi
}

# 显示当前任务状态
show_task_status() {
    local ns_name="${1:-$(get_current_namespace)}"
    local workflow_config=$(get_workflow_config "$ns_name")
    
    echo "=== 当前工作流状态 ==="
    echo "Namespace: $ns_name"
    echo ""
    
    # 显示所有角色和对应实例
    echo "👥 角色实例映射:"
    local roles=$(echo "$workflow_config" | jq -r '.roles | keys[]')
    while IFS= read -r role; do
        local instance=$(find_role_instance "$role" "$workflow_config" 2>/dev/null)
        if [[ -n "$instance" ]]; then
            echo "  ✅ $role: $instance"
        else
            echo "  ❌ $role: 未找到实例"
        fi
    done <<< "$roles"
    
    echo ""
    echo "📋 任务节点:"
    local tasks=$(echo "$workflow_config" | jq -r '.nodes | to_entries[] | select(.value.type == "task") | "\(.key): \(.value.title) (\(.value.owner))"')
    echo "$tasks"
}

# 完成任务
complete_task() {
    local task_id="$1"
    local ns_name="${2:-$(get_current_namespace)}"
    local deliverables="$3"
    
    echo "✅ 完成任务: $task_id"
    echo "📦 交付物: $deliverables"
    echo ""
    
    # 发送完成通知
    send_completion_notification "$task_id" "$ns_name" "$deliverables"
}

# 主命令处理
case "${1:-help}" in
    "status")
        show_task_status "${2}"
        ;;
    "complete")
        if [[ -z "$2" ]]; then
            echo "用法: workflow-engine complete <task_id> [namespace] [deliverables]"
            exit 1
        fi
        complete_task "$2" "$3" "$4"
        ;;
    "help"|"")
        echo "cliExtra Workflow Engine 用法:"
        echo "  workflow-engine status [namespace]                    - 显示工作流状态"
        echo "  workflow-engine complete <task_id> [ns] [deliverables] - 完成任务并触发通知"
        echo ""
        echo "示例:"
        echo "  workflow-engine status simple_dev"
        echo "  workflow-engine complete backend_dev simple_dev 'API接口,接口文档'"
        ;;
    *)
        echo "未知命令: $1"
        echo "使用 'workflow-engine help' 查看帮助"
        ;;
esac
