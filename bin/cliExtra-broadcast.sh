#!/bin/bash

# cliExtra 广播消息脚本

# 加载公共函数、配置和状态管理器
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"
source "$SCRIPT_DIR/cliExtra-sender-id.sh"
source "$SCRIPT_DIR/cliExtra-dag-hooks.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra broadcast <message> [options]"
    echo ""
    echo "参数:"
    echo "  message       要广播的消息内容"
    echo ""
    echo "选项:"
    echo "  --namespace <ns>    只广播给指定namespace的实例"
    echo "  -A, --all           广播给所有namespace的实例"
    echo "  --exclude <id>      排除指定的实例ID"
    echo "  --force             强制发送，忽略实例状态检查"
    echo "  --dry-run          只显示会发送给哪些实例，不实际发送"
    echo "  --sender-id         添加发送者标识到消息（默认启用）"
    echo "  --no-sender-id      不添加发送者标识到消息"
    echo ""
    echo "状态检查说明:"
    echo "  默认只向 idle (空闲) 状态的实例广播消息"
    echo "  非空闲状态的实例会被跳过，避免打断工作"
    echo "  使用 --force 可以强制广播到所有实例"
    echo ""
    echo "发送者标识说明:"
    echo "  默认情况下，广播消息会自动添加发送者标识，格式为："
    echo "  [发送者: namespace:instance_id] 原始消息内容"
    echo "  这有助于接收方识别消息来源和协作上下文"
    echo ""
    echo "默认行为:"
    echo "  默认只广播给 'default' namespace 中的实例"
    echo "  使用 -A/--all 广播给所有 namespace 的实例"
    echo "  使用 --namespace 广播给指定 namespace 的实例"
    echo ""
    echo "示例:"
    echo "  cliExtra broadcast \"系统维护通知\"                    # 广播给 default namespace 的空闲实例"
    echo "  cliExtra broadcast \"系统更新\" -A                    # 广播给所有 namespace 的空闲实例"
    echo "  cliExtra broadcast \"紧急通知\" --force               # 强制广播给所有实例"
    echo "  cliExtra broadcast \"前端更新\" --namespace frontend   # 只广播给frontend namespace"
    echo "  cliExtra broadcast \"测试完成\" --exclude self        # 排除当前实例"
    echo "  cliExtra broadcast \"部署通知\" --dry-run             # 预览模式"
}

# 检查实例状态是否可以接收广播消息
check_broadcast_instance_status() {
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
    
    # 获取状态文件路径
    local status_file=$(get_instance_status_file "$instance_id" "$namespace")
    
    # 如果状态文件不存在，假设实例是空闲的
    if [[ ! -f "$status_file" ]]; then
        return 0  # 可以发送
    fi
    
    # 读取状态
    if command -v jq >/dev/null 2>&1; then
        local status=$(jq -r '.status // "idle"' "$status_file" 2>/dev/null)
        
        # 检查状态
        if [[ "$status" == "idle" ]]; then
            return 0  # 可以发送
        else
            return 1  # 不能发送
        fi
    else
        # 没有jq，假设可以发送
        return 0
    fi
}

# 记录广播消息到namespace缓存
record_broadcast_to_cache() {
    local project_dir="$1"
    local namespace="$2"
    local message="$3"
    local timestamp="$4"
    local target_instances="$5"
    
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
    
    # 使用jq记录广播消息
    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        jq --arg timestamp "$timestamp" \
           --arg message "$message" \
           --arg targets "$target_instances" \
           '.message_history += [{
               "timestamp": $timestamp,
               "type": "broadcast",
               "message": $message,
               "targets": ($targets | split(" "))
           }]' "$cache_file" > "$temp_file" && mv "$temp_file" "$cache_file"
    fi
}

# 记录广播消息到各个实例的对话文件
record_broadcast_to_conversations() {
    local instances="$1"
    local message="$2"
    local timestamp="$3"
    
    for instance_id in $instances; do
        # 使用与 send 命令相同的逻辑查找实例信息
        local instance_dir=$(find_instance_info_dir "$instance_id")
        local conversation_file=""
        local namespace="default"
        local project_dir=""
        
        if [[ $? -eq 0 && -n "$instance_dir" ]]; then
            # 从工作目录结构获取对话文件
            local ns_dir=$(dirname "$(dirname "$instance_dir")")
            conversation_file="$ns_dir/conversations/instance_$instance_id.json"
            namespace=$(basename "$ns_dir")
            
            # 获取项目目录
            if [[ -f "$instance_dir/project_path" ]]; then
                project_dir=$(cat "$instance_dir/project_path")
            elif [[ -f "$instance_dir/info" ]]; then
                source "$instance_dir/info"
                project_dir="$PROJECT_DIR"
            fi
        else
            # 向后兼容：查找实例所在的项目目录
            project_dir=$(find_instance_project "$instance_id")
            if [[ $? -ne 0 ]]; then
                echo "警告: 无法找到实例 $instance_id 的项目目录"
                continue
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
  "project_dir": "$project_dir",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "conversations": []
}
EOF
        fi
        
        # 使用jq添加广播记录
        if command -v jq >/dev/null 2>&1; then
            local temp_file=$(mktemp)
            jq --arg timestamp "$timestamp" \
               --arg message "$message" \
               --arg type "broadcast" \
               '.conversations += [{
                   "timestamp": $timestamp,
                   "type": $type,
                   "sender": "broadcast",
                   "message": $message
               }]' "$conversation_file" > "$temp_file" && mv "$temp_file" "$conversation_file"
            
            echo "  ✓ 对话已记录到: $conversation_file"
        else
            echo "  警告: jq未安装，无法记录对话到实例 $instance_id"
        fi
    done
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
    
    # 使用公共函数获取实例的namespace
    find_instance_namespace "$instance_id"
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
    local force_send="${5:-false}"
    local add_sender_id="${6:-true}"
    
    if [[ -z "$message" ]]; then
        echo "错误: 请指定要广播的消息"
        show_help
        return 1
    fi
    
    # 添加发送者标识（如果启用）
    local final_message="$message"
    if [[ "$add_sender_id" == "true" ]]; then
        final_message=$(add_sender_id_to_message "$message")
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
        # 如果指定了具体的 namespace
        target_instances=$(get_namespace_instances "$target_namespace")
        echo "广播目标: namespace '$target_namespace'"
    elif [[ "$SHOW_ALL_NAMESPACES" == "true" ]]; then
        # 如果指定了 -A/--all，广播给所有 namespace
        target_instances=$(get_all_instances)
        echo "广播目标: 所有 namespace 的实例"
    else
        # 默认只广播给 default namespace
        target_instances=$(get_namespace_instances "default")
        echo "广播目标: default namespace"
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
    local skipped_count=0
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local successful_instances=""
    local skipped_instances=""
    
    for instance in $filtered_instances; do
        total_count=$((total_count + 1))
        local session_name="q_instance_$instance"
        
        if tmux has-session -t "$session_name" 2>/dev/null; then
            # 检查实例状态
            if check_broadcast_instance_status "$instance" "$force_send"; then
                # 发送消息到tmux会话
                tmux send-keys -t "$session_name" "$final_message" Enter
                echo "✓ 已发送到实例: $instance"
                success_count=$((success_count + 1))
                successful_instances="$successful_instances $instance"
                
                # 记录发送者追踪信息（如果启用）
                if [[ "$add_sender_id" == "true" ]]; then
                    local sender_info=$(get_sender_info)
                    local instance_namespace=$(get_instance_namespace "$instance")
                    if [[ -z "$instance_namespace" ]]; then
                        instance_namespace="$CLIEXTRA_DEFAULT_NS"
                    fi
                    local receiver_info="$instance_namespace:$instance"
                    record_sender_tracking "$sender_info" "$receiver_info" "$message"
                fi
            else
                echo "⏸ 跳过忙碌实例: $instance"
                skipped_count=$((skipped_count + 1))
                skipped_instances="$skipped_instances $instance"
            fi
        else
            echo "✗ 实例未运行: $instance"
        fi
    done
    
    # 记录广播消息到对话文件
    if [[ -n "$successful_instances" ]]; then
        echo "✓ 记录广播消息到对话文件..."
        record_broadcast_to_conversations "$successful_instances" "$message" "$timestamp"
        
        # DAG 钩子：检测工作流启动消息
        local sender_info=$(get_sender_info)
        echo "🔍 发送者信息: $sender_info"
        dag_broadcast_hook "$sender_info" "$message" "$target_namespace"
        
        # 自动设置接收实例状态为 busy
        if [[ "$dry_run" != "true" ]]; then
            echo "✓ 自动更新接收实例状态..."
            local instances_array=($successful_instances)
            auto_set_busy_on_broadcast "$message" "${instances_array[@]}"
        fi
        
        # 按namespace分组记录到缓存
        local namespace_cache=""
        for instance in $successful_instances; do
            local project_dir=$(find_instance_project "$instance")
            if [[ $? -eq 0 ]]; then
                local ns=$(get_instance_namespace_from_project "$project_dir" "$instance")
                local key="$project_dir:$ns"
                
                # 检查是否已经处理过这个namespace
                if [[ "$namespace_cache" != *"$key"* ]]; then
                    # 收集这个namespace中的所有实例
                    local instances_in_ns=""
                    for check_instance in $successful_instances; do
                        local check_project_dir=$(find_instance_project "$check_instance")
                        if [[ "$check_project_dir" == "$project_dir" ]]; then
                            local check_ns=$(get_instance_namespace_from_project "$project_dir" "$check_instance")
                            if [[ "$check_ns" == "$ns" ]]; then
                                instances_in_ns="$instances_in_ns $check_instance"
                            fi
                        fi
                    done
                    
                    # 记录到缓存
                    record_broadcast_to_cache "$project_dir" "$ns" "$message" "$timestamp" "$instances_in_ns"
                    namespace_cache="$namespace_cache $key"
                fi
            fi
        done
    fi
    
    echo ""
    echo "=== 广播完成 ==="
    echo "成功发送: $success_count/$total_count"
    
    if [[ $skipped_count -gt 0 ]]; then
        echo "跳过忙碌实例: $skipped_count 个"
        if [[ -n "$skipped_instances" ]]; then
            echo "跳过的实例:$skipped_instances"
        fi
        if [[ "$force_send" != "true" ]]; then
            echo "提示: 使用 --force 参数可以强制发送到所有实例"
        fi
    fi
}

# 解析参数
MESSAGE=""
TARGET_NAMESPACE=""
EXCLUDE_INSTANCE=""
DRY_RUN=false
FORCE_SEND=false
SHOW_ALL_NAMESPACES=false
ADD_SENDER_ID=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            TARGET_NAMESPACE="$2"
            shift 2
            ;;
        -A|--all)
            SHOW_ALL_NAMESPACES=true
            shift
            ;;
        --exclude)
            EXCLUDE_INSTANCE="$2"
            shift 2
            ;;
        --no-sender-id)
            ADD_SENDER_ID=false
            shift
            ;;
        --sender-id)
            ADD_SENDER_ID=true
            shift
            ;;
        --force)
            FORCE_SEND=true
            shift
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
broadcast_message "$MESSAGE" "$TARGET_NAMESPACE" "$EXCLUDE_INSTANCE" "$DRY_RUN" "$FORCE_SEND" "$ADD_SENDER_ID"
