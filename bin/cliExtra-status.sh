#!/bin/bash

# cliExtra 实例状态管理命令
# 实现类似 PID 文件的实例状态标记系统

# 加载配置、公共函数和状态管理器
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"

# 检查实例是否存活
is_instance_alive() {
    local instance_id="$1"
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    
    local status_file=$(get_instance_status_file "$instance_id" "$namespace")
    
    # 检查tmux会话是否存在
    local session_name="q_instance_$instance_id"
    if tmux has-session -t "$session_name" 2>/dev/null; then
        return 0
    else
        # 会话不存在，清理状态文件
        remove_status_file "$instance_id" "$namespace"
        return 1
    fi
}

# 安全读取状态值
safe_read_status() {
    local instance_id="$1"
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    
    local status_file=$(get_instance_status_file "$instance_id" "$namespace")
    
    if [[ ! -f "$status_file" ]]; then
        echo "0"  # 默认空闲
        return 0
    fi
    
    local status=$(cat "$status_file" 2>/dev/null | tr -d '\n\r\t ')
    
    # 验证状态值
    if [[ "$status" == "0" || "$status" == "1" ]]; then
        echo "$status"
    else
        echo "0"  # 无效状态默认为空闲
    fi
}

# 验证和修复状态文件
validate_and_fix_status_file() {
    local status_file="$1"
    
    if [[ ! -f "$status_file" ]]; then
        return 1
    fi
    
    # 尝试用jq验证JSON格式
    if command -v jq >/dev/null 2>&1; then
        if ! jq empty "$status_file" >/dev/null 2>&1; then
            echo "警告: 状态文件格式错误，尝试修复: $status_file" >&2
            
            # 尝试从文件名提取实例ID
            local filename=$(basename "$status_file")
            local instance_id="${filename%.status}"
            
            # 创建默认状态文件
            local temp_file="${status_file}.fix.$$"
            cat > "$temp_file" << 'EOF'
{
  "status": "idle",
  "timestamp": "2025-07-24T00:00:00Z",
  "task": "状态文件已修复",
  "pid": "",
  "last_activity": "2025-07-24T00:00:00Z",
  "instance_id": "unknown",
  "namespace": "default"
}
EOF
            
            # 更新实例ID
            if command -v jq >/dev/null 2>&1; then
                jq --arg id "$instance_id" '.instance_id = $id' "$temp_file" > "${temp_file}.new" && mv "${temp_file}.new" "$temp_file"
            fi
            
            # 替换损坏的文件
            if mv "$temp_file" "$status_file"; then
                echo "✓ 状态文件已修复: $status_file" >&2
                return 0
            else
                rm -f "$temp_file"
                return 1
            fi
        fi
    fi
    
    return 0
}

# 安全读取状态文件信息
safe_read_status_info() {
    local status_file="$1"
    local field="$2"
    local default_value="${3:-}"
    
    if [[ ! -f "$status_file" ]]; then
        echo "$default_value"
        return 1
    fi
    
    # 验证并修复状态文件
    validate_and_fix_status_file "$status_file"
    
    if command -v jq >/dev/null 2>&1; then
        local value=$(jq -r ".$field // \"$default_value\"" "$status_file" 2>/dev/null)
        if [[ "$value" == "null" || -z "$value" ]]; then
            echo "$default_value"
        else
            echo "$value"
        fi
    else
        echo "$default_value"
    fi
}

# 获取所有状态文件
get_all_status_files() {
    local namespace="${1:-}"
    local show_all_namespaces="${2:-false}"
    
    local status_files=()
    
    if [[ -n "$namespace" ]]; then
        # 指定namespace
        local status_dir=$(get_instance_status_dir "$namespace")
        if [[ -d "$status_dir" ]]; then
            for status_file in "$status_dir"/*.status; do
                if [[ -f "$status_file" ]]; then
                    status_files+=("$status_file")
                fi
            done
        fi
    elif [[ "$show_all_namespaces" == "true" ]]; then
        # 所有namespace
        for ns_dir in "$CLIEXTRA_NAMESPACES_DIR"/*; do
            if [[ -d "$ns_dir/$CLIEXTRA_STATUS_SUBDIR" ]]; then
                for status_file in "$ns_dir/$CLIEXTRA_STATUS_SUBDIR"/*.status; do
                    if [[ -f "$status_file" ]]; then
                        status_files+=("$status_file")
                    fi
                done
            fi
        done
    else
        # 默认只显示default namespace
        local status_dir=$(get_instance_status_dir "$CLIEXTRA_DEFAULT_NS")
        if [[ -d "$status_dir" ]]; then
            for status_file in "$status_dir"/*.status; do
                if [[ -f "$status_file" ]]; then
                    status_files+=("$status_file")
                fi
            done
        fi
    fi
    
    printf '%s\n' "${status_files[@]}"
}

# 显示帮助信息
show_help() {
    echo "用法: cliExtra status [instance_id] [options]"
    echo ""
    echo "参数:"
    echo "  instance_id   查看指定实例的状态"
    echo ""
    echo "选项:"
    echo "  --set <status>        设置实例状态 (idle|busy|waiting|error)"
    echo "  --task <description>  设置任务描述 (与 --set 一起使用)"
    echo "  --all                 显示所有 namespace 的实例状态"
    echo "  -A                    显示所有 namespace 的实例状态 (同 --all)"
    echo "  -n, --namespace <ns>  只显示指定 namespace 的实例状态"
    echo "  -o, --output <format> 输出格式: table (默认) 或 json"
    echo "  --cleanup             清理过期的状态文件 (默认30分钟)"
    echo "  --timeout <minutes>   设置过期时间 (与 --cleanup 一起使用)"
    echo ""
    echo "状态值说明:"
    echo "  idle     - 空闲，可接收新任务"
    echo "  busy     - 忙碌，正在处理任务"
    echo "  waiting  - 等待用户输入或外部响应"
    echo "  error    - 错误状态，需要人工干预"
    echo ""
    echo "默认行为:"
    echo "  默认只显示 'default' namespace 中的实例状态"
    echo "  使用 -A/--all 显示所有 namespace 的实例状态"
    echo "  使用 -n/--namespace 显示指定 namespace 的实例状态"
    echo ""
    echo "示例:"
    echo "  cliExtra status                           # 显示 default namespace 所有实例状态"
    echo "  cliExtra status myinstance                # 查看指定实例状态"
    echo "  cliExtra status myinstance --set busy     # 设置实例为忙碌状态"
    echo "  cliExtra status myinstance --set busy --task \"处理用户请求\""
    echo "  cliExtra status --all                     # 显示所有 namespace 实例状态"
    echo "  cliExtra status -A -o json                # JSON格式显示所有实例状态"
    echo "  cliExtra status -n frontend               # 显示 frontend namespace 实例状态"
    echo "  cliExtra status --cleanup                 # 清理过期状态文件"
    echo "  cliExtra status --cleanup --timeout 60   # 清理60分钟无活动的状态文件"
}

# 格式化显示单个实例状态
show_instance_status() {
    local instance_id="$1"
    local namespace="$2"
    local output_format="${3:-table}"
    
    if ! is_instance_alive "$instance_id" "$namespace"; then
        if [[ "$output_format" == "json" ]]; then
            echo "{\"error\": \"实例不存在或已停止\", \"instance_id\": \"$instance_id\", \"namespace\": \"$namespace\"}"
        else
            echo "错误: 实例 $instance_id 不存在或已停止 (namespace: $namespace)"
        fi
        return 1
    fi
    
    # 读取简化状态值
    local status_value=$(safe_read_status "$instance_id" "$namespace")
    local status_name=$(status_to_name "$status_value")
    
    # 获取状态文件信息
    local status_file=$(get_instance_status_file "$instance_id" "$namespace")
    local last_activity=""
    if [[ -f "$status_file" ]]; then
        last_activity=$(date -r "$status_file" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "")
    fi
    
    # 获取会话状态
    local session_name="q_instance_$instance_id"
    local session_status="Unknown"
    if tmux has-session -t "$session_name" 2>/dev/null; then
        session_status=$(tmux display-message -t "$session_name" -p "#{session_attached}" 2>/dev/null)
        if [[ "$session_status" == "1" ]]; then
            session_status="Attached"
        else
            session_status="Detached"
        fi
    fi
    
    if [[ "$output_format" == "json" ]]; then
        echo "{\"instance_id\": \"$instance_id\", \"namespace\": \"$namespace\", \"status\": \"$status_name\", \"last_activity\": \"$last_activity\", \"session_status\": \"$session_status\"}"
    else
        # 表格格式显示
        echo "实例: $instance_id (namespace: $namespace)"
        echo "状态: $status_name"
        echo "最后活动: $last_activity"
        echo "会话状态: $session_status"
    fi
}

# 显示所有实例状态
show_all_status() {
    local namespace="$1"
    local show_all_namespaces="$2"
    local output_format="${3:-table}"
    
    local status_files=()
    while IFS= read -r status_file; do
        if [[ -n "$status_file" ]]; then
            status_files+=("$status_file")
        fi
    done < <(get_all_status_files "$namespace" "$show_all_namespaces")
    
    if [[ ${#status_files[@]} -eq 0 ]]; then
        if [[ "$output_format" == "json" ]]; then
            echo "[]"
        else
            if [[ "$show_all_namespaces" == "true" ]]; then
                echo "没有找到任何实例状态文件"
            elif [[ -n "$namespace" ]]; then
                echo "没有找到 namespace '$namespace' 中的实例状态文件"
            else
                echo "没有找到 default namespace 中的实例状态文件"
            fi
        fi
        return 0
    fi
    
    if [[ "$output_format" == "json" ]]; then
        echo "["
        local first=true
        for status_file in "${status_files[@]}"; do
            if [[ -f "$status_file" ]]; then
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo ","
                fi
                cat "$status_file"
            fi
        done
        echo "]"
    else
        # 表格格式显示
        printf "%-30s %-15s %-10s %-20s %s\n" "INSTANCE" "NAMESPACE" "STATUS" "LAST_ACTIVITY" "TASK"
        printf "%-30s %-15s %-10s %-20s %s\n" "$(printf '%*s' 30 '' | tr ' ' '-')" "$(printf '%*s' 15 '' | tr ' ' '-')" "$(printf '%*s' 10 '' | tr ' ' '-')" "$(printf '%*s' 20 '' | tr ' ' '-')" "$(printf '%*s' 20 '' | tr ' ' '-')"
        
        for status_file in "${status_files[@]}"; do
            if [[ -f "$status_file" ]]; then
                local instance_id=$(basename "$status_file" .status)
                local file_namespace=$(basename "$(dirname "$(dirname "$status_file")")")
                
                # 检查实例是否还存活
                if is_instance_alive "$instance_id" "$file_namespace"; then
                    # 使用安全读取状态的方法，而不是期望JSON格式
                    local status_value=$(safe_read_status "$instance_id" "$file_namespace")
                    local status=$(status_to_name "$status_value")
                    local task=""  # 简化版本不支持任务描述
                    local last_activity=""
                    
                    # 获取文件最后修改时间作为活动时间
                    if [[ -f "$status_file" ]]; then
                        last_activity=$(date -r "$status_file" "+%m-%d %H:%M" 2>/dev/null || echo "")
                    fi
                    
                    printf "%-30s %-15s %-10s %-20s %s\n" "$instance_id" "$file_namespace" "$status" "$last_activity" "$task"
                else
                    # 实例不存活，显示为灰色或标记
                    printf "%-30s %-15s %-10s %-20s %s\n" "$instance_id" "$file_namespace" "stopped" "" "实例已停止"
                fi
            fi
        done
    fi
}

# 设置实例状态
set_instance_status() {
    local instance_id="$1"
    local status_name="$2"
    local namespace="$3"
    
    if [[ -z "$instance_id" || -z "$status_name" ]]; then
        echo "错误: 实例ID和状态不能为空"
        return 1
    fi
    
    # 转换状态名称为数字
    local status_value=$(name_to_status "$status_name")
    if [[ "$status_value" == "-1" ]]; then
        echo "错误: 无效的状态名称 '$status_name'。有效值: idle, busy"
        return 1
    fi
    
    # 更新状态文件
    if update_status_file "$instance_id" "$status_value" "$namespace"; then
        local status_display=$(status_to_name "$status_value")
        echo "✓ 实例 $instance_id 状态已更新为: $status_display"
        return 0
    else
        echo "错误: 无法更新实例状态"
        return 1
    fi
}

# 主函数
main() {
    local instance_id=""
    local set_status=""
    local task=""
    local namespace=""
    local show_all_namespaces=false
    local output_format="table"
    local cleanup_mode=false
    local timeout_minutes=30
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --set)
                if [[ -z "$2" ]]; then
                    echo "错误: --set 参数需要指定状态值" >&2
                    show_help
                    exit 1
                fi
                set_status="$2"
                shift 2
                ;;
            --task)
                if [[ -z "$2" ]]; then
                    echo "错误: --task 参数需要指定任务描述" >&2
                    show_help
                    exit 1
                fi
                task="$2"
                shift 2
                ;;
            -A|--all)
                show_all_namespaces=true
                shift
                ;;
            -n|--namespace)
                if [[ -z "$2" ]]; then
                    echo "错误: -n|--namespace 参数需要指定 namespace 名称" >&2
                    show_help
                    exit 1
                fi
                namespace="$2"
                shift 2
                ;;
            -o|--output)
                if [[ -z "$2" ]]; then
                    echo "错误: -o|--output 参数需要指定格式" >&2
                    show_help
                    exit 1
                fi
                if [[ "$2" != "table" && "$2" != "json" ]]; then
                    echo "错误: 不支持的输出格式 '$2'，支持的格式: table, json" >&2
                    show_help
                    exit 1
                fi
                output_format="$2"
                shift 2
                ;;
            --cleanup)
                cleanup_mode=true
                shift
                ;;
            --timeout)
                if [[ -z "$2" ]]; then
                    echo "错误: --timeout 参数需要指定分钟数" >&2
                    show_help
                    exit 1
                fi
                if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    echo "错误: --timeout 参数必须是数字" >&2
                    show_help
                    exit 1
                fi
                timeout_minutes="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                echo "错误: 未知选项 $1" >&2
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$instance_id" ]]; then
                    instance_id="$1"
                else
                    echo "错误: 多余的参数 $1" >&2
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # 处理清理模式
    if [[ "$cleanup_mode" == "true" ]]; then
        echo "清理过期状态文件 (超时: ${timeout_minutes} 分钟)..."
        cleanup_expired_status "$namespace" "$show_all_namespaces" "$timeout_minutes"
        return $?
    fi
    
    # 如果指定了实例ID
    if [[ -n "$instance_id" ]]; then
        # 获取实例的namespace
        if [[ -z "$namespace" ]]; then
            namespace=$(get_instance_namespace "$instance_id")
            if [[ -z "$namespace" ]]; then
                namespace="default"
            fi
        fi
        
        if [[ -n "$set_status" ]]; then
            # 设置状态模式
            set_instance_status "$instance_id" "$set_status" "$namespace"
        else
            # 查看单个实例状态
            show_instance_status "$instance_id" "$namespace" "$output_format"
        fi
    else
        # 显示所有实例状态
        if [[ -n "$set_status" ]]; then
            echo "错误: --set 选项需要指定实例ID" >&2
            show_help
            exit 1
        fi
        
        show_all_status "$namespace" "$show_all_namespaces" "$output_format"
    fi
}

# 处理命令行参数
case "${1:-}" in
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        main "$@"
        ;;
esac
