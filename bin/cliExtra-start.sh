#!/bin/bash

# cliExtra 启动脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 恢复已停止的实例
resume_instance() {
    local instance_id="$1"
    
    echo "尝试恢复实例: $instance_id"
    
    # 查找实例信息
    local instance_dir=$(find_instance_info_dir "$instance_id")
    if [ -z "$instance_dir" ]; then
        echo "错误: 未找到实例 $instance_id"
        return 1
    fi
    
    # 检查实例状态
    local session_name="q_instance_$instance_id"
    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo "实例 $instance_id 已在运行中"
        echo "接管会话: tmux attach-session -t $session_name"
        return 0
    fi
    
    # 读取实例信息
    local info_file="$instance_dir/info"
    if [ ! -f "$info_file" ]; then
        echo "错误: 实例信息文件不存在: $info_file"
        return 1
    fi
    
    # 解析实例信息
    local project_path=$(grep "^PROJECT_DIR=" "$info_file" | cut -d'=' -f2- | tr -d '"')
    local namespace=$(grep "^NAMESPACE=" "$info_file" | cut -d'=' -f2- | tr -d '"')
    
    if [ ! -d "$project_path" ]; then
        echo "错误: 项目目录不存在: $project_path"
        return 1
    fi
    
    echo "恢复实例配置:"
    echo "  实例ID: $instance_id"
    echo "  项目目录: $project_path"
    echo "  Namespace: $namespace"
    
    # 读取历史对话记录
    local conversation_file="$CLIEXTRA_NAMESPACES_DIR/$namespace/conversations/instance_$instance_id.json"
    local context_messages=""
    
    if [ -f "$conversation_file" ]; then
        echo "读取历史对话记录..."
        # 提取用户消息和广播消息作为上下文
        local recent_messages=$(jq -r '.conversations[]? | select(.type == "message" or .type == "broadcast") | "[\(.timestamp)] \(if .type == "message" then "用户" else "广播" end): \(.message)"' "$conversation_file" 2>/dev/null || echo "")
        
        if [ -n "$recent_messages" ]; then
            # 构建上下文消息
            context_messages="根据我们之前的对话记录，请继续我们的讨论：

=== 历史对话记录 ===
$recent_messages

=== 继续对话 ===
请基于以上历史记录继续我们的对话。"
            echo "找到 $(echo "$recent_messages" | wc -l) 条历史消息"
        else
            echo "未找到有效的历史消息"
        fi
    else
        echo "未找到对话记录文件: $conversation_file"
    fi
    
    # 重新启动实例
    echo "重新启动 tmux 会话..."
    
    # 创建新的 tmux 会话
    local tmux_log_file="$CLIEXTRA_NAMESPACES_DIR/$namespace/logs/instance_${instance_id}_tmux.log"
    
    tmux new-session -d -s "$session_name" -c "$project_path"
    
    # 如果有历史上下文，发送给 Q
    if [ -n "$context_messages" ]; then
        echo "载入历史上下文..."
        tmux send-keys -t "$session_name" "q chat" Enter
        sleep 3
        
        # 直接发送完整的上下文消息
        tmux send-keys -t "$session_name" "$context_messages" Enter
        
        echo "历史上下文已载入"
    else
        # 直接启动 q chat
        tmux send-keys -t "$session_name" "q chat" Enter
    fi
    
    # 启用日志记录
    tmux pipe-pane -t "$session_name" -o "cat >> '$tmux_log_file'"
    
    echo "✓ 实例 $instance_id 已恢复"
    echo "接管会话: tmux attach-session -t $session_name"
    echo "分离会话: 在会话中按 Ctrl+B, D"
    
    return 0
}

# 生成与目录相关的实例ID
generate_instance_id() {
    local project_path="$1"
    local target_dir=""
    
    # 确定目标目录
    if [ -z "$project_path" ]; then
        target_dir=$(pwd)
    elif [[ "$project_path" == http*://* ]]; then
        # Git URL 处理
        local repo_name=$(basename "$project_path" .git)
        target_dir="$repo_name"
    else
        # 本地路径处理
        target_dir=$(basename "$(realpath "$project_path")")
    fi
    
    # 获取目录名并清理特殊字符
    local dir_name=$(basename "$target_dir" | sed 's/[^a-zA-Z0-9_-]/_/g' | tr '[:upper:]' '[:lower:]')
    
    # 如果目录名为空或只有特殊字符，使用默认名称
    if [ -z "$dir_name" ] || [ "$dir_name" = "_" ]; then
        dir_name="project"
    fi
    
    # 生成带目录名的实例ID
    local timestamp=$(date +%s)
    local random_suffix=$(shuf -i 1000-9999 -n 1 2>/dev/null || echo $RANDOM)
    echo "${dir_name}_${timestamp}_${random_suffix}"
}

# 解析命令行参数
parse_start_args() {
    local instance_name=""
    local project_path=""
    local role=""
    local namespace="default"
    local context_instance=""
    local force="false"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name)
                if [[ -z "$2" ]]; then
                    echo "错误: --name 参数需要指定实例名称"
                    return 1
                fi
                instance_name="$2"
                shift 2
                ;;
            --role)
                if [[ -z "$2" ]]; then
                    echo "错误: --role 参数需要指定角色名称"
                    return 1
                fi
                role="$2"
                shift 2
                ;;
            --namespace|--ns)
                if [[ -z "$2" ]]; then
                    echo "错误: --namespace 参数需要指定 namespace 名称"
                    return 1
                fi
                namespace="$2"
                shift 2
                ;;
            --context)
                if [[ -z "$2" ]]; then
                    echo "错误: --context 参数需要指定实例名称"
                    return 1
                fi
                context_instance="$2"
                shift 2
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            *)
                # 检查是否是以 - 开头的无效选项
                if [[ "$1" == -* ]]; then
                    echo "错误: 未知选项 '$1'"
                    echo ""
                    echo "用法: cliExtra start [path] [选项]"
                    echo ""
                    echo "选项:"
                    echo "  --name <name>         指定实例名称"
                    echo "  --role <role>         应用角色预设"
                    echo "  --namespace <ns>      指定 namespace"
                    echo "  --ns <ns>             指定 namespace（简写）"
                    echo "  --context <instance>  从指定实例加载历史上下文"
                    echo "  -f, --force           强制启动（重启已存在的实例）"
                    echo ""
                    echo "示例:"
                    echo "  cliExtra start                        # 在当前目录启动"
                    echo "  cliExtra start --name myproject       # 指定实例名"
                    echo "  cliExtra start --role frontend        # 应用前端角色"
                    echo "  cliExtra start --ns q_cli             # 指定 namespace"
                    echo "  cliExtra start -f                     # 强制启动"
                    return 1
                fi
                
                if [ -z "$project_path" ]; then
                    project_path="$1"
                else
                    echo "错误: 多余的参数 '$1'"
                    echo ""
                    echo "用法: cliExtra start [path] [选项]"
                    return 1
                fi
                shift
                ;;
        esac
    done
    
    # 如果指定了 --context 但没有指定 --name，则恢复指定的实例
    if [ -n "$context_instance" ] && [ -z "$instance_name" ]; then
        echo "RESUME|$context_instance"
        return 0
    fi
    
    # 如果同时指定了 --name 和 --context，则创建新实例并加载上下文
    # 这种情况下，context_instance 会在后续的 start_instance 函数中使用
    
    # 如果没有指定实例名字，生成一个
    if [ -z "$instance_name" ]; then
        instance_name=$(generate_instance_id "$project_path")
        echo "自动生成实例ID: $instance_name" >&2
    fi
    
    echo "$instance_name|$project_path|$role|$namespace|$context_instance|$force"
}

# 项目初始化
init_project() {
    local project_path="$1"
    local target_dir=""
    
    if [ -z "$project_path" ]; then
        # 使用当前目录
        target_dir=$(pwd)
    elif [[ "$project_path" == http*://* ]]; then
        # Git URL 处理
        local repo_name=$(basename "$project_path" .git)
        target_dir="$CLIEXTRA_PROJECTS_DIR/$repo_name"
        
        if [ -d "$target_dir" ]; then
            echo "项目已存在: $target_dir"
        else
            echo "正在克隆项目: $project_path"
            mkdir -p "$CLIEXTRA_PROJECTS_DIR"
            if git clone "$project_path" "$target_dir"; then
                echo "✓ 项目克隆成功: $target_dir"
            else
                echo "✗ 项目克隆失败"
                return 1
            fi
        fi
    else
        # 本地路径处理
        if [ ! -d "$project_path" ]; then
            echo "✗ 目录不存在: $project_path"
            return 1
        fi
        target_dir=$(realpath "$project_path")
    fi
    
    # 不在项目目录创建 .cliExtra，所有实例信息都在工作目录管理
    echo "$target_dir"
}

# 更新namespace缓存
update_namespace_cache() {
    local cache_file="$1"
    local instance_id="$2"
    local action="$3"
    local timestamp="$4"
    local message="$5"
    
    # 使用jq更新缓存文件
    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        
        # 首先确保文件存在且结构正确
        if [[ ! -f "$cache_file" ]]; then
            cat > "$cache_file" << EOF
{
  "namespace": "default",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "instances": {},
  "message_history": []
}
EOF
        fi
        
        # 修复可能损坏的instances字段（如果是数组，转换为对象）
        jq 'if .instances | type == "array" then .instances = {} else . end' "$cache_file" > "$temp_file" && mv "$temp_file" "$cache_file"
        
        # 现在安全地更新缓存
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

# 安装默认工具到项目
install_default_tools() {
    local project_dir="$1"
    local tools_script="$SCRIPT_DIR/cliExtra-tools.sh"
    
    echo "安装默认工具到项目..."
    
    # 默认安装的工具列表
    local default_tools=("git")
    
    for tool in "${default_tools[@]}"; do
        echo "  安装工具: $tool"
        if "$tools_script" add "$tool" --project "$project_dir" >/dev/null 2>&1; then
            echo "  ✓ $tool 安装成功"
        else
            echo "  ⚠ $tool 安装失败或已存在"
        fi
    done
}

# 准备角色定义到项目目录
prepare_role_definitions() {
    local project_dir="$1"
    local role="$2"
    local roles_source_dir="$SCRIPT_DIR/../roles"
    local roles_target_dir="$project_dir/.cliExtra/roles"
    
    # 创建目标目录
    mkdir -p "$roles_target_dir"
    
    # 如果指定了角色，确保该角色文件存在
    if [ -n "$role" ]; then
        local role_file="${role}-engineer.md"
        local source_role_file="$roles_source_dir/$role_file"
        local target_role_file="$roles_target_dir/$role_file"
        
        # 检查项目目录是否已有该角色文件
        if [ -f "$target_role_file" ]; then
            echo "✓ 角色定义已存在: $target_role_file" >&2
        elif [ -f "$source_role_file" ]; then
            echo "复制角色定义: $role_file" >&2
            cp "$source_role_file" "$target_role_file"
            echo "✓ 角色定义已复制到: $target_role_file" >&2
        else
            echo "⚠ 警告: 未找到角色定义文件: $source_role_file" >&2
            return 1
        fi
        
        # 返回角色文件路径，用于后续作为context传入
        echo "$target_role_file"
    else
        # 如果没有指定角色，检查项目目录是否有任何角色文件
        local existing_roles=$(find "$roles_target_dir" -name "*-engineer.md" 2>/dev/null | head -1)
        if [ -n "$existing_roles" ]; then
            echo "✓ 发现现有角色定义: $(basename "$existing_roles")" >&2
            echo "$existing_roles"
        else
            echo "未指定角色且项目中无现有角色定义" >&2
            return 0
        fi
    fi
}

# 同步rules到项目目录
sync_rules_to_project() {
    local project_dir="$1"
    local rules_source_dir="$SCRIPT_DIR/../rules"
    local rules_target_dir="$project_dir/.amazonq/rules"
    
    # 创建目标目录
    mkdir -p "$rules_target_dir"
    
    # 检查源rules目录是否存在
    if [[ ! -d "$rules_source_dir" ]]; then
        echo "警告: rules源目录不存在: $rules_source_dir"
        return 1
    fi
    
    echo "同步rules到项目目录..."
    echo "源目录: $rules_source_dir"
    echo "目标目录: $rules_target_dir"
    
    # 同步所有rules文件
    if cp -r "$rules_source_dir"/* "$rules_target_dir/" 2>/dev/null; then
        echo "✓ rules同步完成"
        
        # 列出同步的文件
        echo "已同步的rules文件:"
        ls -la "$rules_target_dir" | grep -v "^total" | awk '{print "  - " $9}' | grep -v "^  - $"
    else
        echo "⚠ rules同步失败或源目录为空"
    fi
}
# 从指定实例加载历史上下文
load_context_from_instance() {
    local session_name="$1"
    local context_instance="$2"
    
    # 查找上下文实例的 namespace
    local context_instance_dir=$(find_instance_info_dir "$context_instance")
    if [ -z "$context_instance_dir" ]; then
        echo "警告: 未找到上下文实例 $context_instance"
        return 1
    fi
    
    # 获取上下文实例的 namespace
    local context_namespace=$(find_instance_namespace "$context_instance")
    if [ -z "$context_namespace" ]; then
        echo "警告: 无法确定上下文实例的 namespace"
        return 1
    fi
    
    # 读取历史对话记录
    local conversation_file="$CLIEXTRA_NAMESPACES_DIR/$context_namespace/conversations/instance_$context_instance.json"
    
    if [ -f "$conversation_file" ]; then
        echo "读取历史对话记录..."
        # 提取用户消息和广播消息作为上下文
        local recent_messages=$(jq -r '.conversations[]? | select(.type == "message" or .type == "broadcast") | "[\(.timestamp)] \(if .type == "message" then "用户" else "广播" end): \(.message)"' "$conversation_file" 2>/dev/null || echo "")
        
        if [ -n "$recent_messages" ]; then
            # 构建上下文消息
            local context_messages="根据我们之前的对话记录，请继续我们的讨论：

=== 历史对话记录 ===
$recent_messages

=== 继续对话 ===
请基于以上历史记录继续我们的对话。"
            
            echo "找到 $(echo "$recent_messages" | wc -l) 条历史消息"
            
            # 发送上下文消息到 tmux 会话
            tmux send-keys -t "$session_name" "$context_messages" Enter
            echo "历史上下文已载入"
        else
            echo "未找到有效的历史消息"
        fi
    else
        echo "未找到对话记录文件: $conversation_file"
    fi
}

start_tmux_instance() {
    local instance_id="$1"
    local project_dir="$2"
    local namespace="$3"
    local context_instance="$4"
    local force="$5"
    local role="$6"
    local session_name="q_instance_$instance_id"
    
    # 使用工作目录统一管理所有实例信息
    local ns_dir="$(get_namespace_dir "$namespace")"
    local session_dir="$(get_instance_dir "$instance_id" "$namespace")"
    local tmux_log_file="$(get_instance_log_dir "$namespace")/instance_${instance_id}_tmux.log"
    local conversation_file="$(get_instance_conversation_dir "$namespace")/instance_$instance_id.json"
    local ns_cache_file="$ns_dir/namespace_cache.json"
    
    # 创建namespace目录结构
    mkdir -p "$session_dir"
    mkdir -p "$(dirname "$tmux_log_file")"
    mkdir -p "$(dirname "$conversation_file")"
    
    echo "$(date): 启动tmux实例 $instance_id 在项目 $project_dir (namespace: $namespace)" >> "$tmux_log_file"
    
    # 初始化对话记录文件
    if [[ ! -f "$conversation_file" ]]; then
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
    
    # 初始化namespace缓存文件
    if [[ ! -f "$ns_cache_file" ]]; then
        cat > "$ns_cache_file" << EOF
{
  "namespace": "$namespace",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "instances": {},
  "message_history": []
}
EOF
    fi
    
    # 同步rules到项目目录
    sync_rules_to_project "$project_dir"
    
    # 安装默认工具
    install_default_tools "$project_dir"
    
    # 准备角色定义
    local role_file=""
    if [ -n "$role" ] || [ -z "$context_instance" ]; then
        role_file=$(prepare_role_definitions "$project_dir" "$role")
        if [ $? -ne 0 ] && [ -n "$role" ]; then
            echo "⚠ 角色定义准备失败，将不使用角色上下文"
            role_file=""
        fi
    fi
    
    # 检查实例是否已经在运行
    if tmux has-session -t "$session_name" 2>/dev/null; then
        if [ "$force" = "true" ]; then
            echo "实例 $instance_id 已经在运行，强制重启..."
            tmux kill-session -t "$session_name"
            sleep 1
        else
            echo "实例 $instance_id 已经在运行"
            echo "使用 'tmux attach-session -t $session_name' 接管会话"
            echo "或使用 -f 参数强制重启实例"
            return
        fi
    fi
    
    echo "启动tmux q CLI实例 $instance_id"
    echo "项目目录: $project_dir"
    echo "Namespace: $namespace"
    echo "会话名称: $session_name"
    echo "会话目录: $session_dir"
    echo "Tmux日志: $tmux_log_file"
    echo "对话记录: $conversation_file"
    if [ -n "$role_file" ]; then
        echo "角色定义: $role_file"
    fi
    
    # 启动tmux会话，在项目目录中运行，直接启动 q chat
    tmux new-session -d -s "$session_name" -c "$project_dir" "q chat --trust-all-tools"
    
    # 启用tmux日志记录
    tmux pipe-pane -t "$session_name" -o "cat >> '$tmux_log_file'"
    
    # 等待 Q 启动完成
    sleep 3
    
    # 如果有角色文件，发送角色定义作为初始消息
    if [ -n "$role_file" ] && [ -f "$role_file" ]; then
        echo "加载角色定义: $(basename "$role_file")"
        
        # 读取角色文件内容
        local role_content=$(cat "$role_file")
        
        # 构建角色加载消息
        local role_message="请按照以下角色定义来协助我：

$role_content

请确认你已理解并将按照以上角色定义来协助我的工作。"
        
        # 发送角色定义消息
        tmux send-keys -t "$session_name" "$role_message" Enter
        
        echo "✓ 角色定义已加载: $(basename "$role_file")"
        
        # 等待角色加载完成
        sleep 2
    fi
    
    # 如果指定了上下文实例，加载其历史对话
    if [ -n "$context_instance" ]; then
        echo "加载实例 $context_instance 的历史上下文..."
        load_context_from_instance "$session_name" "$context_instance"
    fi
    
    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo "✓ 实例 $instance_id 已启动"
        echo "接管会话: tmux attach-session -t $session_name"
        echo "分离会话: 在会话中按 Ctrl+B, D"
        
        # 保存实例信息
        cat > "$session_dir/info" << EOF
INSTANCE_ID="$instance_id"
PROJECT_DIR="$project_dir"
SESSION_NAME="$session_name"
NAMESPACE="$namespace"
ROLE="$role"
ROLE_FILE="$role_file"
STARTED_AT="$(date)"
PID="$$"
CONVERSATION_FILE="$conversation_file"
NS_CACHE_FILE="$ns_cache_file"
EOF
        
        # 保存项目路径引用
        echo "$project_dir" > "$session_dir/project_path"
        
        # 保存namespace信息（向后兼容）
        echo "$namespace" > "$session_dir/namespace"
        
        # 更新namespace缓存
        update_namespace_cache "$ns_cache_file" "$instance_id" "started" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        
    else
        echo "✗ 实例 $instance_id 启动失败"
    fi
}

# 主逻辑
# 解析启动参数
args_result=$(parse_start_args "$@")
if [ $? -ne 0 ]; then
    # parse_start_args 函数已经输出了详细的错误信息
    exit 1
fi

# 检查是否为恢复模式
if [[ "$args_result" == RESUME\|* ]]; then
    context_instance=$(echo "$args_result" | cut -d'|' -f2)
    resume_instance "$context_instance"
    exit $?
fi

# 解析结果
IFS='|' read -r instance_id project_path role namespace context_instance force <<< "$args_result"

# 初始化项目
project_dir=$(init_project "$project_path")
if [ $? -ne 0 ]; then
    echo "项目初始化失败"
    exit 1
fi

# 启动实例
start_tmux_instance "$instance_id" "$project_dir" "$namespace" "$context_instance" "$force" "$role" 