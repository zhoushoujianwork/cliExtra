#!/bin/bash

# cliExtra 实例状态管理核心函数库 - 跨平台版本
# 基于 cliExtra-config.sh 的跨平台配置实现

# 加载配置和公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 状态值定义
readonly STATUS_IDLE="idle"
readonly STATUS_BUSY="busy"
readonly STATUS_WAITING="waiting"
readonly STATUS_ERROR="error"

# 获取当前时间戳 (ISO 8601 格式)
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# 获取进程PID (tmux会话的PID)
get_instance_pid() {
    local instance_id="$1"
    local session_name="q_instance_$instance_id"
    
    if tmux has-session -t "$session_name" 2>/dev/null; then
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
    local namespace="${4:-$CLIEXTRA_DEFAULT_NS}"
    
    if [[ -z "$instance_id" || -z "$status" ]]; then
        echo "错误: 实例ID和状态不能为空" >&2
        return 1
    fi
    
    # 使用配置函数获取状态文件路径
    local status_file=$(get_instance_status_file "$instance_id" "$namespace")
    local status_dir=$(get_instance_status_dir "$namespace")
    
    # 确保状态目录存在
    if [[ ! -d "$status_dir" ]]; then
        mkdir -p "$status_dir"
        if [[ $? -ne 0 ]]; then
            echo "错误: 无法创建状态目录 $status_dir" >&2
            return 1
        fi
    fi
    
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
    local namespace="${4:-$CLIEXTRA_DEFAULT_NS}"
    
    if [[ -z "$instance_id" || -z "$status" ]]; then
        echo "错误: 实例ID和状态不能为空" >&2
        return 1
    fi
    
    local status_file=$(get_instance_status_file "$instance_id" "$namespace")
    
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
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    
    if [[ -z "$instance_id" ]]; then
        echo "错误: 实例ID不能为空" >&2
        return 1
    fi
    
    local status_file=$(get_instance_status_file "$instance_id" "$namespace")
    
    if [[ ! -f "$status_file" ]]; then
        echo "错误: 状态文件不存在 $status_file" >&2
        return 1
    fi
    
    cat "$status_file"
}

# 删除状态文件
remove_status_file() {
    local instance_id="$1"
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    
    if [[ -z "$instance_id" ]]; then
        echo "错误: 实例ID不能为空" >&2
        return 1
    fi
    
    local status_file=$(get_instance_status_file "$instance_id" "$namespace")
    
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

# 消息接收时自动设置实例状态为 busy
auto_set_busy_on_message() {
    local instance_id="$1"
    local message="$2"
    local namespace="${3:-$CLIEXTRA_DEFAULT_NS}"
    
    if [[ -z "$instance_id" || -z "$message" ]]; then
        echo "错误: 实例ID和消息内容不能为空" >&2
        return 1
    fi
    
    # 截取消息前50个字符作为任务描述
    local task_desc="处理消息: "
    if [[ ${#message} -gt 50 ]]; then
        task_desc="${task_desc}${message:0:50}..."
    else
        task_desc="${task_desc}${message}"
    fi
    
    # 更新状态为 busy
    update_status_file "$instance_id" "$STATUS_BUSY" "$task_desc" "$namespace"
    
    if [[ $? -eq 0 ]]; then
        return 0
    else
        echo "警告: 无法更新实例 $instance_id 的状态" >&2
        return 1
    fi
}

# 批量设置多个实例状态为 busy（用于广播）
auto_set_busy_on_broadcast() {
    local message="$1"
    shift
    local instances=("$@")
    
    if [[ -z "$message" ]]; then
        echo "错误: 消息内容不能为空" >&2
        return 1
    fi
    
    if [[ ${#instances[@]} -eq 0 ]]; then
        echo "错误: 实例列表不能为空" >&2
        return 1
    fi
    
    # 截取消息前50个字符作为任务描述
    local task_desc="处理广播: "
    if [[ ${#message} -gt 50 ]]; then
        task_desc="${task_desc}${message:0:50}..."
    else
        task_desc="${task_desc}${message}"
    fi
    
    local success_count=0
    local total_count=${#instances[@]}
    
    for instance_id in "${instances[@]}"; do
        # 获取实例的namespace
        local namespace=$(get_instance_namespace "$instance_id")
        if [[ -z "$namespace" ]]; then
            namespace="$CLIEXTRA_DEFAULT_NS"
        fi
        
        # 更新状态为 busy
        if update_status_file "$instance_id" "$STATUS_BUSY" "$task_desc" "$namespace"; then
            success_count=$((success_count + 1))
        else
            echo "警告: 无法更新实例 $instance_id 的状态" >&2
        fi
    done
    
    if [[ $success_count -gt 0 ]]; then
        echo "✓ 已将 $success_count/$total_count 个实例状态设置为忙碌"
        return 0
    else
        echo "错误: 无法更新任何实例的状态" >&2
        return 1
    fi
}
