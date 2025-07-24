#!/bin/bash

# cliExtra 实例状态管理核心函数库 - 简化版本
# 使用简单的数字状态：0=idle, 1=busy

# 加载配置和公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 状态值定义
readonly STATUS_IDLE=0
readonly STATUS_BUSY=1

# 状态值到名称的映射
status_to_name() {
    local status="$1"
    case "$status" in
        "0") echo "idle" ;;
        "1") echo "busy" ;;
        *) echo "unknown" ;;
    esac
}

# 状态名称到值的映射
name_to_status() {
    local name="$1"
    case "$name" in
        "idle") echo "0" ;;
        "busy") echo "1" ;;
        *) echo "-1" ;;  # 无效状态
    esac
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
        tmux display-message -t "$session_name" -p "#{pid}" 2>/dev/null
    else
        echo ""
    fi
}

# 创建状态文件 (原子操作)
create_status_file() {
    local instance_id="$1"
    local status="$2"
    local namespace="${3:-$CLIEXTRA_DEFAULT_NS}"
    
    if [[ -z "$instance_id" || -z "$status" ]]; then
        echo "错误: 实例ID和状态不能为空" >&2
        return 1
    fi
    
    # 验证 namespace 名称格式
    if [[ ! "$namespace" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "错误: 无效的 namespace 名称 '$namespace'。只能包含字母、数字、下划线和连字符" >&2
        echo "使用默认 namespace: $CLIEXTRA_DEFAULT_NS" >&2
        namespace="$CLIEXTRA_DEFAULT_NS"
    fi
    
    # 验证 namespace 名称长度
    if [[ ${#namespace} -gt 32 ]]; then
        echo "错误: namespace 名称过长 (${#namespace} > 32)。使用默认 namespace: $CLIEXTRA_DEFAULT_NS" >&2
        namespace="$CLIEXTRA_DEFAULT_NS"
    fi
    
    # 验证状态值
    if [[ "$status" != "0" && "$status" != "1" ]]; then
        echo "错误: 无效的状态值 '$status'。有效值: 0 (idle), 1 (busy)" >&2
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
    
    # 原子操作：写入状态值
    local temp_file="${status_file}.tmp.$$"
    echo "$status" > "$temp_file"
    
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
    local namespace="${3:-$CLIEXTRA_DEFAULT_NS}"
    
    # 直接调用创建函数，因为逻辑相同
    create_status_file "$instance_id" "$status" "$namespace"
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
        echo "0"  # 默认为空闲状态
        return 0
    fi
    
    local status=$(cat "$status_file" 2>/dev/null | tr -d '\n\r\t ')
    
    # 验证状态值
    if [[ "$status" == "0" || "$status" == "1" ]]; then
        echo "$status"
        return 0
    else
        echo "0"  # 无效状态默认为空闲
        return 0
    fi
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
        "0"|"1")
            return 0
            ;;
        *)
            echo "错误: 无效的状态值 '$status'。有效值: 0 (idle), 1 (busy)" >&2
            return 1
            ;;
    esac
}

# 消息接收时自动设置实例状态为 busy
auto_set_busy_on_message() {
    local instance_id="$1"
    local message="$2"  # 消息内容（暂时不使用，为了兼容调用）
    local namespace="${3:-$CLIEXTRA_DEFAULT_NS}"
    
    if [[ -z "$instance_id" ]]; then
        echo "错误: 实例ID不能为空" >&2
        return 1
    fi
    
    # 更新状态为 busy (1)
    update_status_file "$instance_id" "$STATUS_BUSY" "$namespace"
    
    if [[ $? -eq 0 ]]; then
        return 0
    else
        echo "警告: 无法更新实例 $instance_id 的状态" >&2
        return 1
    fi
}

# 批量设置多个实例状态为 busy（用于广播）
auto_set_busy_on_broadcast() {
    shift  # 跳过消息参数，只处理实例列表
    local instances=("$@")
    
    if [[ ${#instances[@]} -eq 0 ]]; then
        echo "错误: 实例列表不能为空" >&2
        return 1
    fi
    
    local success_count=0
    local total_count=${#instances[@]}
    
    for instance_id in "${instances[@]}"; do
        # 获取实例的namespace
        local namespace=$(get_instance_namespace "$instance_id")
        if [[ -z "$namespace" ]]; then
            namespace="$CLIEXTRA_DEFAULT_NS"
        fi
        
        # 更新状态为 busy (1)
        if update_status_file "$instance_id" "$STATUS_BUSY" "$namespace"; then
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
