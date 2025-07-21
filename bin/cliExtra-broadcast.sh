#!/bin/bash

# cliExtra 广播消息脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra broadcast <message> [options]"
    echo ""
    echo "参数:"
    echo "  message       要广播的消息内容"
    echo ""
    echo "选项:"
    echo "  --namespace <ns>    只广播给指定namespace的实例"
    echo "  --exclude <id>      排除指定的实例ID"
    echo "  --dry-run          只显示会发送给哪些实例，不实际发送"
    echo ""
    echo "示例:"
    echo "  cliExtra broadcast \"系统维护通知\"                    # 广播给所有实例"
    echo "  cliExtra broadcast \"前端更新\" --namespace frontend   # 只广播给frontend namespace"
    echo "  cliExtra broadcast \"测试完成\" --exclude self        # 排除当前实例"
    echo "  cliExtra broadcast \"部署通知\" --dry-run             # 预览模式"
}

# 获取当前实例ID（如果在cliExtra环境中）
get_current_instance() {
    # 尝试从环境变量或tmux会话名获取
    if [[ -n "$TMUX" ]]; then
        local session_name=$(tmux display-message -p '#S')
        if [[ "$session_name" == q_instance_* ]]; then
            echo "${session_name#q_instance_}"
            return 0
        fi
    fi
    
    # 如果无法确定当前实例，返回空
    echo ""
}

# 获取指定namespace中的实例
get_namespace_instances() {
    local target_namespace="$1"
    local instances=""
    
    # 遍历所有tmux会话，查找属于指定namespace的实例
    while IFS= read -r session_line; do
        if [[ "$session_line" == q_instance_* ]]; then
            local session_info=$(echo "$session_line" | cut -d: -f1)
            local instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            
            # 检查实例的namespace
            local instance_ns=$(get_instance_namespace "$instance_id")
            if [[ "$instance_ns" == "$target_namespace" ]]; then
                instances="$instances $instance_id"
            fi
        fi
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    echo "$instances"
}

# 获取实例的namespace
get_instance_namespace() {
    local instance_id="$1"
    
    # 查找实例的项目目录
    local project_dir=$(find_instance_project "$instance_id")
    if [[ $? -eq 0 ]]; then
        local instance_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
        local ns_file="$instance_dir/namespace"
        
        if [[ -f "$ns_file" ]]; then
            cat "$ns_file"
        else
            echo "default"
        fi
    else
        echo "default"
    fi
}

# 获取所有实例
get_all_instances() {
    local instances=""
    
    while IFS= read -r session_line; do
        if [[ "$session_line" == q_instance_* ]]; then
            local session_info=$(echo "$session_line" | cut -d: -f1)
            local instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            instances="$instances $instance_id"
        fi
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    echo "$instances"
}

# 广播消息
broadcast_message() {
    local message="$1"
    local target_namespace="$2"
    local exclude_instance="$3"
    local dry_run="$4"
    
    if [[ -z "$message" ]]; then
        echo "错误: 请指定要广播的消息"
        show_help
        return 1
    fi
    
    # 获取当前实例ID
    local current_instance=$(get_current_instance)
    
    # 处理exclude参数
    if [[ "$exclude_instance" == "self" ]]; then
        exclude_instance="$current_instance"
    fi
    
    # 获取目标实例列表
    local target_instances=""
    if [[ -n "$target_namespace" ]]; then
        target_instances=$(get_namespace_instances "$target_namespace")
        echo "广播目标: namespace '$target_namespace'"
    else
        target_instances=$(get_all_instances)
        echo "广播目标: 所有实例"
    fi
    
    # 过滤排除的实例
    local filtered_instances=""
    for instance in $target_instances; do
        if [[ "$instance" != "$exclude_instance" ]]; then
            filtered_instances="$filtered_instances $instance"
        fi
    done
    
    # 检查是否有目标实例
    if [[ -z "$filtered_instances" ]]; then
        echo "没有找到符合条件的目标实例"
        return 1
    fi
    
    echo "目标实例: $filtered_instances"
    echo "消息内容: $message"
    
    if [[ "$dry_run" == "true" ]]; then
        echo ""
        echo "=== 预览模式 - 不会实际发送消息 ==="
        for instance in $filtered_instances; do
            local instance_ns=$(get_instance_namespace "$instance")
            echo "  → $instance (namespace: $instance_ns)"
        done
        return 0
    fi
    
    # 实际发送消息
    echo ""
    echo "=== 开始广播 ==="
    local success_count=0
    local total_count=0
    
    for instance in $filtered_instances; do
        total_count=$((total_count + 1))
        local session_name="q_instance_$instance"
        
        if tmux has-session -t "$session_name" 2>/dev/null; then
            # 发送消息到tmux会话
            tmux send-keys -t "$session_name" "$message" Enter
            echo "✓ 已发送到实例: $instance"
            success_count=$((success_count + 1))
        else
            echo "✗ 实例未运行: $instance"
        fi
    done
    
    echo ""
    echo "=== 广播完成 ==="
    echo "成功发送: $success_count/$total_count"
}

# 解析参数
MESSAGE=""
TARGET_NAMESPACE=""
EXCLUDE_INSTANCE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            TARGET_NAMESPACE="$2"
            shift 2
            ;;
        --exclude)
            EXCLUDE_INSTANCE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
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
            if [[ -z "$MESSAGE" ]]; then
                MESSAGE="$1"
            else
                echo "多余的参数: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# 主逻辑
broadcast_message "$MESSAGE" "$TARGET_NAMESPACE" "$EXCLUDE_INSTANCE" "$DRY_RUN"
