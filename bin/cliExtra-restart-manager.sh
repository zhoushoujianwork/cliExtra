#!/bin/bash

# cliExtra 重启管理器 - 类似 k8s pod 的重启机制
# 记录重启次数、失败原因和状态历史

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"

# 重启记录文件结构
# ~/Library/Application Support/cliExtra/namespaces/<namespace>/restart/<instance_id>.restart

# 重启状态定义
RESTART_POLICY_ALWAYS="Always"
RESTART_POLICY_ON_FAILURE="OnFailure"
RESTART_POLICY_NEVER="Never"

# 失败原因定义
FAILURE_REASON_TMUX_DIED="TmuxSessionDied"
FAILURE_REASON_Q_CRASHED="QChatCrashed"
FAILURE_REASON_SYSTEM_ERROR="SystemError"
FAILURE_REASON_USER_KILLED="UserKilled"
FAILURE_REASON_TIMEOUT="Timeout"
FAILURE_REASON_UNKNOWN="Unknown"

# 重启延迟配置（秒）
RESTART_DELAY_BASE=5
RESTART_DELAY_MAX=300
RESTART_BACKOFF_MULTIPLIER=2

# 日志函数
log_restart() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [RESTART-$level] $message" >> "$CLIEXTRA_HOME/engine.log"
}

# 获取重启记录文件路径
get_restart_record_file() {
    local instance_id="$1"
    local namespace="$2"
    
    if [[ -z "$namespace" ]]; then
        namespace="$CLIEXTRA_DEFAULT_NS"
    fi
    
    local restart_dir="$CLIEXTRA_HOME/namespaces/$namespace/restart"
    mkdir -p "$restart_dir"
    echo "$restart_dir/${instance_id}.restart"
}

# 初始化重启记录
init_restart_record() {
    local instance_id="$1"
    local namespace="$2"
    local restart_policy="${3:-$RESTART_POLICY_ALWAYS}"
    
    local record_file=$(get_restart_record_file "$instance_id" "$namespace")
    
    # 创建初始记录
    cat > "$record_file" << EOF
{
    "instance_id": "$instance_id",
    "namespace": "$namespace",
    "restart_policy": "$restart_policy",
    "restart_count": 0,
    "last_restart_time": null,
    "last_failure_reason": null,
    "last_failure_time": null,
    "created_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "restart_history": []
}
EOF
    
    log_restart "INFO" "Initialized restart record for $instance_id (policy: $restart_policy)"
}

# 读取重启记录
read_restart_record() {
    local instance_id="$1"
    local namespace="$2"
    
    local record_file=$(get_restart_record_file "$instance_id" "$namespace")
    
    if [[ -f "$record_file" ]]; then
        cat "$record_file"
    else
        # 返回默认记录
        echo '{
            "instance_id": "'$instance_id'",
            "namespace": "'$namespace'",
            "restart_policy": "'$RESTART_POLICY_ALWAYS'",
            "restart_count": 0,
            "last_restart_time": null,
            "last_failure_reason": null,
            "last_failure_time": null,
            "created_time": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
            "restart_history": []
        }'
    fi
}

# 更新重启记录
update_restart_record() {
    local instance_id="$1"
    local namespace="$2"
    local failure_reason="$3"
    local restart_success="$4"
    
    local record_file=$(get_restart_record_file "$instance_id" "$namespace")
    local current_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # 读取当前记录
    local current_record
    if [[ -f "$record_file" ]]; then
        current_record=$(cat "$record_file")
    else
        init_restart_record "$instance_id" "$namespace"
        current_record=$(cat "$record_file")
    fi
    
    # 使用 jq 更新记录（如果可用）
    if command -v jq >/dev/null 2>&1; then
        local new_record
        new_record=$(echo "$current_record" | jq \
            --arg failure_reason "$failure_reason" \
            --arg current_time "$current_time" \
            --arg restart_success "$restart_success" \
            '
            .restart_count += 1 |
            .last_failure_reason = $failure_reason |
            .last_failure_time = $current_time |
            if $restart_success == "true" then
                .last_restart_time = $current_time
            else
                .
            end |
            .restart_history += [{
                "restart_count": .restart_count,
                "failure_reason": $failure_reason,
                "failure_time": $current_time,
                "restart_success": ($restart_success == "true"),
                "restart_time": (if $restart_success == "true" then $current_time else null end)
            }]
            ')
        
        echo "$new_record" > "$record_file"
    else
        # 简单的文本处理方式
        local restart_count
        restart_count=$(echo "$current_record" | grep '"restart_count"' | sed 's/.*: *\([0-9]*\).*/\1/')
        restart_count=$((restart_count + 1))
        
        # 重新生成记录（简化版）
        cat > "$record_file" << EOF
{
    "instance_id": "$instance_id",
    "namespace": "$namespace",
    "restart_policy": "$RESTART_POLICY_ALWAYS",
    "restart_count": $restart_count,
    "last_restart_time": $(if [[ "$restart_success" == "true" ]]; then echo "\"$current_time\""; else echo "null"; fi),
    "last_failure_reason": "$failure_reason",
    "last_failure_time": "$current_time",
    "created_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "restart_history": []
}
EOF
    fi
    
    log_restart "INFO" "Updated restart record for $instance_id (count: $restart_count, reason: $failure_reason, success: $restart_success)"
}

# 检测实例失败原因
detect_failure_reason() {
    local instance_id="$1"
    local namespace="$2"
    
    local session_name="q_instance_$instance_id"
    
    # 检查 tmux 会话是否存在
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "$FAILURE_REASON_TMUX_DIED"
        return
    fi
    
    # 检查 tmux 日志中的错误信息
    local tmux_log_file="$CLIEXTRA_HOME/namespaces/$namespace/instances/instance_$instance_id/tmux.log"
    
    if [[ -f "$tmux_log_file" ]]; then
        local recent_logs
        recent_logs=$(tail -n 20 "$tmux_log_file" 2>/dev/null || echo "")
        
        # 检查常见的错误模式
        if echo "$recent_logs" | grep -qi "error\|exception\|crash\|fatal"; then
            echo "$FAILURE_REASON_Q_CRASHED"
            return
        fi
        
        if echo "$recent_logs" | grep -qi "killed\|terminated"; then
            echo "$FAILURE_REASON_USER_KILLED"
            return
        fi
        
        if echo "$recent_logs" | grep -qi "timeout"; then
            echo "$FAILURE_REASON_TIMEOUT"
            return
        fi
    fi
    
    # 检查系统资源
    local memory_usage
    memory_usage=$(ps -o pid,pmem,comm -p $$ 2>/dev/null | tail -n 1 | awk '{print $2}')
    
    if [[ -n "$memory_usage" ]] && (( $(echo "$memory_usage > 80" | bc -l 2>/dev/null || echo "0") )); then
        echo "$FAILURE_REASON_SYSTEM_ERROR"
        return
    fi
    
    echo "$FAILURE_REASON_UNKNOWN"
}

# 计算重启延迟
calculate_restart_delay() {
    local restart_count="$1"
    
    if [[ "$restart_count" -le 1 ]]; then
        echo "$RESTART_DELAY_BASE"
        return
    fi
    
    # 指数退避算法
    local delay=$RESTART_DELAY_BASE
    for ((i=1; i<restart_count; i++)); do
        delay=$((delay * RESTART_BACKOFF_MULTIPLIER))
        if [[ $delay -gt $RESTART_DELAY_MAX ]]; then
            delay=$RESTART_DELAY_MAX
            break
        fi
    done
    
    echo "$delay"
}

# 检查是否应该重启
should_restart() {
    local instance_id="$1"
    local namespace="$2"
    local failure_reason="$3"
    
    local record=$(read_restart_record "$instance_id" "$namespace")
    local restart_policy
    local restart_count
    
    if command -v jq >/dev/null 2>&1; then
        restart_policy=$(echo "$record" | jq -r '.restart_policy')
        restart_count=$(echo "$record" | jq -r '.restart_count')
    else
        restart_policy=$(echo "$record" | grep '"restart_policy"' | cut -d'"' -f4)
        restart_count=$(echo "$record" | grep '"restart_count"' | sed 's/.*: *\([0-9]*\).*/\1/')
    fi
    
    # 检查重启策略
    case "$restart_policy" in
        "$RESTART_POLICY_NEVER")
            log_restart "INFO" "Instance $instance_id restart policy is Never, skipping restart"
            return 1
            ;;
        "$RESTART_POLICY_ON_FAILURE")
            if [[ "$failure_reason" == "$FAILURE_REASON_USER_KILLED" ]]; then
                log_restart "INFO" "Instance $instance_id was killed by user, skipping restart (OnFailure policy)"
                return 1
            fi
            ;;
        "$RESTART_POLICY_ALWAYS")
            # 总是重启，但有次数限制
            ;;
    esac
    
    # 检查重启次数限制（防止无限重启）
    local max_restarts=10
    if [[ "$restart_count" -ge "$max_restarts" ]]; then
        log_restart "WARN" "Instance $instance_id has reached maximum restart limit ($max_restarts), stopping auto-restart"
        return 1
    fi
    
    return 0
}

# 执行实例重启
restart_instance() {
    local instance_id="$1"
    local namespace="$2"
    local failure_reason="$3"
    
    log_restart "INFO" "Attempting to restart instance $instance_id (reason: $failure_reason)"
    
    # 检查是否应该重启
    if ! should_restart "$instance_id" "$namespace" "$failure_reason"; then
        return 1
    fi
    
    # 获取重启记录
    local record=$(read_restart_record "$instance_id" "$namespace")
    local restart_count
    
    if command -v jq >/dev/null 2>&1; then
        restart_count=$(echo "$record" | jq -r '.restart_count')
    else
        restart_count=$(echo "$record" | grep '"restart_count"' | sed 's/.*: *\([0-9]*\).*/\1/')
    fi
    
    # 计算重启延迟
    local delay=$(calculate_restart_delay "$restart_count")
    
    log_restart "INFO" "Waiting ${delay}s before restarting $instance_id (attempt #$((restart_count + 1)))"
    sleep "$delay"
    
    # 获取实例信息
    local instance_info_file="$CLIEXTRA_HOME/namespaces/$namespace/instances/instance_$instance_id/info"
    
    if [[ ! -f "$instance_info_file" ]]; then
        log_restart "ERROR" "Instance info file not found for $instance_id"
        update_restart_record "$instance_id" "$namespace" "$failure_reason" "false"
        return 1
    fi
    
    # 读取实例配置
    local project_dir role
    project_dir=$(grep "^PROJECT_DIR=" "$instance_info_file" | cut -d'=' -f2- | tr -d '"')
    role=$(grep "^ROLE=" "$instance_info_file" | cut -d'=' -f2- | tr -d '"')
    
    # 检查项目目录
    if [[ -z "$project_dir" || ! -d "$project_dir" ]]; then
        log_restart "ERROR" "Invalid project directory for $instance_id: $project_dir"
        update_restart_record "$instance_id" "$namespace" "$failure_reason" "false"
        return 1
    fi
    
    # 对于 system 实例，使用特殊的重启逻辑
    if [[ "$instance_id" == *"_system" ]]; then
        log_restart "INFO" "Restarting system instance: $instance_id"
        
        # System 实例使用 namespace 目录作为工作目录，并指定 system-coordinator 角色
        local start_args=("$project_dir" "--name" "$instance_id" "--namespace" "$namespace" "--role" "system-coordinator")
        
        # 获取主脚本路径
        local main_script
        main_script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/cliExtra.sh"
        
        # 执行重启
        if "$main_script" start "${start_args[@]}" >/dev/null 2>&1; then
            log_restart "INFO" "Successfully restarted system instance $instance_id"
            update_restart_record "$instance_id" "$namespace" "$failure_reason" "true"
            return 0
        else
            log_restart "ERROR" "Failed to restart system instance $instance_id"
            update_restart_record "$instance_id" "$namespace" "$failure_reason" "false"
            return 1
        fi
    fi
    
    # 构建启动命令
    local start_args=("$project_dir" "--name" "$instance_id" "--namespace" "$namespace")
    
    if [[ -n "$role" && "$role" != "null" && "$role" != "" ]]; then
        start_args+=("--role" "$role")
    fi
    
    # 获取主脚本路径
    local main_script
    main_script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/cliExtra.sh"
    
    # 执行重启
    if "$main_script" start "${start_args[@]}" >/dev/null 2>&1; then
        log_restart "INFO" "Successfully restarted instance $instance_id"
        update_restart_record "$instance_id" "$namespace" "$failure_reason" "true"
        return 0
    else
        log_restart "ERROR" "Failed to restart instance $instance_id"
        update_restart_record "$instance_id" "$namespace" "$failure_reason" "false"
        return 1
    fi
}

# 检查实例是否需要重启
check_instance_for_restart() {
    local instance_id="$1"
    
    # 获取实例的 namespace
    local namespace=$(get_instance_namespace "$instance_id")
    if [[ -z "$namespace" ]]; then
        namespace="$CLIEXTRA_DEFAULT_NS"
    fi
    
    local session_name="q_instance_$instance_id"
    
    # 检查 tmux 会话是否存在
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        log_restart "WARN" "Instance $instance_id tmux session not found, attempting restart"
        
        local failure_reason=$(detect_failure_reason "$instance_id" "$namespace")
        restart_instance "$instance_id" "$namespace" "$failure_reason"
        return $?
    fi
    
    # 检查实例是否响应（可以通过状态文件的更新时间判断）
    local status_file="$CLIEXTRA_HOME/namespaces/$namespace/status/${instance_id}.status"
    
    if [[ -f "$status_file" ]]; then
        local last_update
        if [[ "$OSTYPE" == "darwin"* ]]; then
            last_update=$(stat -f %m "$status_file" 2>/dev/null || echo "0")
        else
            last_update=$(stat -c %Y "$status_file" 2>/dev/null || echo "0")
        fi
        
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_update))
        
        # 如果状态文件超过 5 分钟没有更新，可能实例已经挂掉
        if [[ $time_diff -gt 300 ]]; then
            log_restart "WARN" "Instance $instance_id appears unresponsive (last update: ${time_diff}s ago)"
            
            # 进一步检查 tmux 会话是否真的在运行
            local pane_content
            pane_content=$(tmux capture-pane -t "$session_name" -p 2>/dev/null || echo "")
            
            if [[ -z "$pane_content" ]] || echo "$pane_content" | grep -q "session not found\|no such session"; then
                local failure_reason=$(detect_failure_reason "$instance_id" "$namespace")
                restart_instance "$instance_id" "$namespace" "$failure_reason"
                return $?
            fi
        fi
    fi
    
    return 0
}

# 清理重启记录
cleanup_restart_records() {
    local namespace="$1"
    
    if [[ -z "$namespace" ]]; then
        # 清理所有 namespace
        for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
            if [[ -d "$ns_dir/restart" ]]; then
                local ns_name=$(basename "$ns_dir")
                cleanup_restart_records "$ns_name"
            fi
        done
        return
    fi
    
    local restart_dir="$CLIEXTRA_HOME/namespaces/$namespace/restart"
    
    if [[ ! -d "$restart_dir" ]]; then
        return
    fi
    
    # 清理不存在实例的重启记录
    for record_file in "$restart_dir"/*.restart; do
        if [[ ! -f "$record_file" ]]; then
            continue
        fi
        
        local instance_id
        instance_id=$(basename "$record_file" .restart)
        
        # 检查实例是否还存在
        local instance_dir="$CLIEXTRA_HOME/namespaces/$namespace/instances/instance_$instance_id"
        
        if [[ ! -d "$instance_dir" ]]; then
            log_restart "INFO" "Cleaning up restart record for removed instance: $instance_id"
            rm -f "$record_file"
        fi
    done
}

# 显示重启统计
show_restart_stats() {
    local namespace="$1"
    local instance_id="$2"
    
    if [[ -n "$instance_id" ]]; then
        # 显示单个实例的重启记录
        local record=$(read_restart_record "$instance_id" "$namespace")
        
        if command -v jq >/dev/null 2>&1; then
            echo "=== 实例重启记录: $instance_id ==="
            echo "$record" | jq -r '
                "实例ID: " + .instance_id,
                "Namespace: " + .namespace,
                "重启策略: " + .restart_policy,
                "重启次数: " + (.restart_count | tostring),
                "最后重启: " + (.last_restart_time // "从未重启"),
                "最后失败: " + (.last_failure_reason // "无") + " (" + (.last_failure_time // "无") + ")",
                "创建时间: " + .created_time
            '
            
            local history_count
            history_count=$(echo "$record" | jq '.restart_history | length')
            
            if [[ "$history_count" -gt 0 ]]; then
                echo ""
                echo "重启历史:"
                echo "$record" | jq -r '.restart_history[] | 
                    "  #" + (.restart_count | tostring) + " " + 
                    .failure_time + " " + 
                    .failure_reason + " " + 
                    (if .restart_success then "✓" else "✗" end)
                '
            fi
        else
            echo "=== 实例重启记录: $instance_id ==="
            echo "$record"
        fi
    else
        # 显示所有实例的重启统计
        echo "=== 重启统计概览 ==="
        
        local total_instances=0
        local total_restarts=0
        local failed_restarts=0
        
        # 遍历所有 namespace
        for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
            if [[ ! -d "$ns_dir/restart" ]]; then
                continue
            fi
            
            local ns_name=$(basename "$ns_dir")
            
            if [[ -n "$namespace" && "$ns_name" != "$namespace" ]]; then
                continue
            fi
            
            for record_file in "$ns_dir/restart"/*.restart; do
                if [[ ! -f "$record_file" ]]; then
                    continue
                fi
                
                local record=$(cat "$record_file")
                local restart_count
                
                if command -v jq >/dev/null 2>&1; then
                    restart_count=$(echo "$record" | jq -r '.restart_count')
                else
                    restart_count=$(echo "$record" | grep '"restart_count"' | sed 's/.*: *\([0-9]*\).*/\1/')
                fi
                
                total_instances=$((total_instances + 1))
                total_restarts=$((total_restarts + restart_count))
                
                # 统计失败的重启（简化统计）
                if [[ "$restart_count" -gt 5 ]]; then
                    failed_restarts=$((failed_restarts + 1))
                fi
            done
        done
        
        echo "总实例数: $total_instances"
        echo "总重启次数: $total_restarts"
        echo "问题实例数: $failed_restarts (重启次数 > 5)"
        
        if [[ "$total_instances" -gt 0 ]]; then
            local avg_restarts=$((total_restarts / total_instances))
            echo "平均重启次数: $avg_restarts"
        fi
    fi
}

# 导出函数供其他脚本使用
export -f init_restart_record
export -f read_restart_record
export -f update_restart_record
export -f detect_failure_reason
export -f should_restart
export -f restart_instance
export -f check_instance_for_restart
export -f cleanup_restart_records
export -f show_restart_stats
