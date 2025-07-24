#!/bin/bash

# cliExtra 实例状态管理核心函数库
# 实现类似 PID 文件的实例状态标记系统

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 状态值定义
readonly STATUS_IDLE="idle"
readonly STATUS_BUSY="busy"
readonly STATUS_WAITING="waiting"
readonly STATUS_ERROR="error"

# 获取状态文件路径
get_status_file_path() {
    local instance_id="$1"
    local namespace="${2:-default}"
    
    if [[ -z "$instance_id" ]]; then
        echo "错误: 实例ID不能为空" >&2
        return 1
    fi
    
    local status_dir="$CLIEXTRA_HOME/namespaces/$namespace/status"
    echo "$status_dir/${instance_id}.status"
}

# 确保状态目录存在
ensure_status_directory() {
    local namespace="${1:-default}"
    local status_dir="$CLIEXTRA_HOME/namespaces/$namespace/status"
    
    if [[ ! -d "$status_dir" ]]; then
        mkdir -p "$status_dir"
        if [[ $? -ne 0 ]]; then
            echo "错误: 无法创建状态目录 $status_dir" >&2
            return 1
        fi
    fi
    
    return 0
}

# 获取当前时间戳 (ISO 8601 格式)
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# 获取进程PID (tmux会话的PID)
get_instance_pid() {
    local instance_id="$1"
    local session_name="q_instance_$instance_id"
    
    if tmux has-session -t "$session_name" 2>/dev/null; then
        # 获取tmux会话的主进程PID
        tmux display-message -t "$session_name" -p "#{pid}" 2>/dev/null
    else
        echo ""
    fi
}

# 创建状态文件 (原子操作)
create_status_file() {
    local instance_id="$1"
    local status="$2"
    local task="${3:-}"
    local namespace="${4:-default}"
    
    if [[ -z "$instance_id" || -z "$status" ]]; then
        echo "错误: 实例ID和状态不能为空" >&2
        return 1
    fi
    
    # 确保状态目录存在
    ensure_status_directory "$namespace"
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local status_file=$(get_status_file_path "$instance_id" "$namespace")
    local temp_file="${status_file}.tmp.$$"
    local timestamp=$(get_timestamp)
    local pid=$(get_instance_pid "$instance_id")
    
    # 创建状态JSON
    cat > "$temp_file" << EOF
{
  "status": "$status",
  "timestamp": "$timestamp",
  "task": "$task",
  "pid": "$pid",
  "last_activity": "$timestamp",
  "instance_id": "$instance_id",
  "namespace": "$namespace"
}
EOF
    
    if [[ $? -eq 0 ]]; then
        # 原子操作：重命名临时文件
        mv "$temp_file" "$status_file"
        if [[ $? -eq 0 ]]; then
            return 0
        else
            echo "错误: 无法创建状态文件 $status_file" >&2
            rm -f "$temp_file"
            return 1
        fi
    else
        echo "错误: 无法写入临时状态文件" >&2
        rm -f "$temp_file"
        return 1
    fi
}

# 更新状态文件
update_status_file() {
    local instance_id="$1"
    local status="$2"
    local task="${3:-}"
    local namespace="${4:-default}"
    
    if [[ -z "$instance_id" || -z "$status" ]]; then
        echo "错误: 实例ID和状态不能为空" >&2
        return 1
    fi
    
    local status_file=$(get_status_file_path "$instance_id" "$namespace")
    
    # 检查状态文件是否存在
    if [[ ! -f "$status_file" ]]; then
        echo "警告: 状态文件不存在，创建新文件" >&2
        create_status_file "$instance_id" "$status" "$task" "$namespace"
        return $?
    fi
    
    local temp_file="${status_file}.tmp.$$"
    local timestamp=$(get_timestamp)
    local pid=$(get_instance_pid "$instance_id")
    
    # 读取现有状态文件，保留部分信息
    local original_timestamp=""
    if command -v jq >/dev/null 2>&1; then
        original_timestamp=$(jq -r '.timestamp // ""' "$status_file" 2>/dev/null)
    fi
    
    # 如果无法读取原始时间戳，使用当前时间
    if [[ -z "$original_timestamp" || "$original_timestamp" == "null" ]]; then
        original_timestamp="$timestamp"
    fi
    
    # 更新状态JSON
    cat > "$temp_file" << EOF
{
  "status": "$status",
  "timestamp": "$original_timestamp",
  "task": "$task",
  "pid": "$pid",
  "last_activity": "$timestamp",
  "instance_id": "$instance_id",
  "namespace": "$namespace"
}
EOF
    
    if [[ $? -eq 0 ]]; then
        # 原子操作：重命名临时文件
        mv "$temp_file" "$status_file"
        if [[ $? -eq 0 ]]; then
            return 0
        else
            echo "错误: 无法更新状态文件 $status_file" >&2
            rm -f "$temp_file"
            return 1
        fi
    else
        echo "错误: 无法写入临时状态文件" >&2
        rm -f "$temp_file"
        return 1
    fi
}

# 读取状态文件
read_status_file() {
    local instance_id="$1"
    local namespace="${2:-default}"
    
    if [[ -z "$instance_id" ]]; then
        echo "错误: 实例ID不能为空" >&2
        return 1
    fi
    
    local status_file=$(get_status_file_path "$instance_id" "$namespace")
    
    if [[ ! -f "$status_file" ]]; then
        echo "错误: 状态文件不存在 $status_file" >&2
        return 1
    fi
    
    cat "$status_file"
}

# 删除状态文件
remove_status_file() {
    local instance_id="$1"
    local namespace="${2:-default}"
    
    if [[ -z "$instance_id" ]]; then
        echo "错误: 实例ID不能为空" >&2
        return 1
    fi
    
    local status_file=$(get_status_file_path "$instance_id" "$namespace")
    
    if [[ -f "$status_file" ]]; then
        rm -f "$status_file"
        if [[ $? -eq 0 ]]; then
            return 0
        else
            echo "错误: 无法删除状态文件 $status_file" >&2
            return 1
        fi
    fi
    
    return 0
}

# 检查实例是否存活
is_instance_alive() {
    local instance_id="$1"
    local namespace="${2:-default}"
    
    local status_file=$(get_status_file_path "$instance_id" "$namespace")
    
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
        local status_dir="$CLIEXTRA_HOME/namespaces/$namespace/status"
        if [[ -d "$status_dir" ]]; then
            for status_file in "$status_dir"/*.status; do
                if [[ -f "$status_file" ]]; then
                    status_files+=("$status_file")
                fi
            done
        fi
    elif [[ "$show_all_namespaces" == "true" ]]; then
        # 所有namespace
        for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
            if [[ -d "$ns_dir/status" ]]; then
                for status_file in "$ns_dir/status"/*.status; do
                    if [[ -f "$status_file" ]]; then
                        status_files+=("$status_file")
                    fi
                done
            fi
        done
    else
        # 默认只显示default namespace
        local status_dir="$CLIEXTRA_HOME/namespaces/default/status"
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

# 检查状态文件是否过期 (超过指定时间无活动)
is_status_expired() {
    local status_file="$1"
    local timeout_minutes="${2:-30}"  # 默认30分钟超时
    
    if [[ ! -f "$status_file" ]]; then
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "警告: 需要安装 jq 来检查状态过期" >&2
        return 1
    fi
    
    local last_activity=$(jq -r '.last_activity // ""' "$status_file" 2>/dev/null)
    if [[ -z "$last_activity" || "$last_activity" == "null" ]]; then
        return 1
    fi
    
    # 计算时间差 (需要 date 命令支持)
    local last_timestamp=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_activity" "+%s" 2>/dev/null)
    local current_timestamp=$(date "+%s")
    
    if [[ -n "$last_timestamp" && -n "$current_timestamp" ]]; then
        local diff_seconds=$((current_timestamp - last_timestamp))
        local timeout_seconds=$((timeout_minutes * 60))
        
        if [[ $diff_seconds -gt $timeout_seconds ]]; then
            return 0  # 已过期
        fi
    fi
    
    return 1  # 未过期
}

# 清理过期的状态文件
cleanup_expired_status() {
    local namespace="${1:-}"
    local show_all_namespaces="${2:-false}"
    local timeout_minutes="${3:-30}"
    
    local cleaned_count=0
    
    while IFS= read -r status_file; do
        if [[ -n "$status_file" ]]; then
            if is_status_expired "$status_file" "$timeout_minutes"; then
                local instance_id=$(basename "$status_file" .status)
                local file_namespace=$(basename "$(dirname "$(dirname "$status_file")")")
                
                echo "清理过期状态文件: $instance_id (namespace: $file_namespace)"
                rm -f "$status_file"
                ((cleaned_count++))
            fi
        fi
    done < <(get_all_status_files "$namespace" "$show_all_namespaces")
    
    if [[ $cleaned_count -gt 0 ]]; then
        echo "已清理 $cleaned_count 个过期状态文件"
    fi
    
    return 0
}

# 验证状态值是否有效
validate_status() {
    local status="$1"
    
    case "$status" in
        "$STATUS_IDLE"|"$STATUS_BUSY"|"$STATUS_WAITING"|"$STATUS_ERROR")
            return 0
            ;;
        *)
            echo "错误: 无效的状态值 '$status'。有效值: $STATUS_IDLE, $STATUS_BUSY, $STATUS_WAITING, $STATUS_ERROR" >&2
            return 1
            ;;
    esac
}
