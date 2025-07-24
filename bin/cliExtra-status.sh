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
    
    if [[ ! -f "$status_file" ]]; then
        return 1
    fi
    
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
    
    local status_content=$(read_status_file "$instance_id" "$namespace")
    if [[ $? -ne 0 ]]; then
        if [[ "$output_format" == "json" ]]; then
            echo "{\"error\": \"无法读取状态文件\", \"instance_id\": \"$instance_id\", \"namespace\": \"$namespace\"}"
        else
            echo "错误: 无法读取实例 $instance_id 的状态文件"
        fi
        return 1
    fi
    
    if [[ "$output_format" == "json" ]]; then
        echo "$status_content"
    else
        # 表格格式显示
        if command -v jq >/dev/null 2>&1; then
            local status=$(echo "$status_content" | jq -r '.status // "unknown"')
            local timestamp=$(echo "$status_content" | jq -r '.timestamp // ""')
            local task=$(echo "$status_content" | jq -r '.task // ""')
            local pid=$(echo "$status_content" | jq -r '.pid // ""')
            local last_activity=$(echo "$status_content" | jq -r '.last_activity // ""')
            
            echo "实例: $instance_id (namespace: $namespace)"
            echo "状态: $status"
            echo "创建时间: $timestamp"
            echo "最后活动: $last_activity"
            if [[ -n "$task" && "$task" != "null" ]]; then
                echo "当前任务: $task"
            fi
            if [[ -n "$pid" && "$pid" != "null" ]]; then
                echo "进程ID: $pid"
            fi
            
            # 显示tmux会话状态
            local session_name="q_instance_$instance_id"
            if tmux has-session -t "$session_name" 2>/dev/null; then
                local client_count=$(tmux list-clients -t "$session_name" 2>/dev/null | wc -l)
                if [[ $client_count -gt 0 ]]; then
                    echo "会话状态: Attached ($client_count 个客户端)"
                else
                    echo "会话状态: Detached"
                fi
            fi
        else
            echo "警告: 需要安装 jq 来解析状态信息" >&2
            echo "原始状态内容:"
            echo "$status_content"
        fi
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
                    if command -v jq >/dev/null 2>&1; then
                        local status_content=$(cat "$status_file")
                        local status=$(echo "$status_content" | jq -r '.status // "unknown"')
                        local task=$(echo "$status_content" | jq -r '.task // ""')
                        local last_activity=$(echo "$status_content" | jq -r '.last_activity // ""')
                        
                        # 格式化时间显示
                        local formatted_time=""
                        if [[ -n "$last_activity" && "$last_activity" != "null" ]]; then
                            formatted_time=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_activity" "+%m-%d %H:%M" 2>/dev/null || echo "$last_activity")
                        fi
                        
                        # 截断任务描述
                        local short_task=""
                        if [[ -n "$task" && "$task" != "null" ]]; then
                            if [[ ${#task} -gt 20 ]]; then
                                short_task="${task:0:17}..."
                            else
                                short_task="$task"
                            fi
                        fi
                        
                        printf "%-30s %-15s %-10s %-20s %s\n" "$instance_id" "$file_namespace" "$status" "$formatted_time" "$short_task"
                    else
                        printf "%-30s %-15s %-10s %-20s %s\n" "$instance_id" "$file_namespace" "unknown" "" "需要jq解析"
                    fi
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
    local status="$2"
    local task="$3"
    local namespace="$4"
    
    # 验证状态值
    if ! validate_status "$status"; then
        return 1
    fi
    
    # 检查实例是否存在
    if ! is_instance_alive "$instance_id" "$namespace"; then
        echo "错误: 实例 $instance_id 不存在或已停止 (namespace: $namespace)" >&2
        return 1
    fi
    
    # 更新状态文件
    if update_status_file "$instance_id" "$status" "$task" "$namespace"; then
        echo "✓ 实例 $instance_id 状态已更新为: $status"
        if [[ -n "$task" ]]; then
            echo "  任务描述: $task"
        fi
        return 0
    else
        echo "错误: 无法更新实例 $instance_id 的状态" >&2
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
            set_instance_status "$instance_id" "$set_status" "$task" "$namespace"
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
