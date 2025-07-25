#!/bin/bash

# cliExtra DAG 监控模块
# 用于守护进程中监控 DAG 实例的状态和超时

# 加载依赖
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-dag-hooks.sh"

# DAG 监控配置
DAG_MONITOR_INTERVAL=10       # DAG 监控间隔（秒）- 调整为更频繁
DAG_NODE_TIMEOUT=1800         # 节点执行超时时间（30分钟）
DAG_INSTANCE_TIMEOUT=7200     # DAG 实例总超时时间（2小时）
DAG_CLEANUP_INTERVAL=3600     # 清理间隔（1小时）

# 日志函数
dag_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [DAG-$level] $message"
}

# 获取所有活跃的 DAG 实例
get_active_dag_instances() {
    local dag_instances=()
    
    if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
        while IFS= read -r -d '' ns_dir; do
            local dag_dir="$ns_dir/dags"
            if [[ -d "$dag_dir" ]]; then
                while IFS= read -r -d '' dag_file; do
                    if [[ -f "$dag_file" ]]; then
                        local status=$(jq -r '.status' "$dag_file" 2>/dev/null)
                        if [[ "$status" == "running" ]]; then
                            dag_instances+=("$dag_file")
                        fi
                    fi
                done < <(find "$dag_dir" -name "dag_*.json" -print0 2>/dev/null)
            fi
        done < <(find "$CLIEXTRA_HOME/namespaces" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    fi
    
    # 使用 printf 而不是 echo 来避免路径分割问题
    for instance in "${dag_instances[@]}"; do
        echo "$instance"
    done
}

# 检查 DAG 实例超时
check_dag_instance_timeout() {
    local dag_file="$1"
    local dag_id=$(jq -r '.dag_instance_id' "$dag_file" 2>/dev/null)
    local created_at=$(jq -r '.created_at' "$dag_file" 2>/dev/null)
    
    if [[ -z "$dag_id" || -z "$created_at" ]]; then
        dag_log "WARN" "无法读取 DAG 实例信息: $dag_file"
        return 1
    fi
    
    # 计算运行时间
    local created_timestamp=$(date -d "$created_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${created_at%+*}" +%s 2>/dev/null)
    local current_timestamp=$(date +%s)
    local runtime=$((current_timestamp - created_timestamp))
    
    if [[ $runtime -gt $DAG_INSTANCE_TIMEOUT ]]; then
        dag_log "WARN" "DAG 实例超时: $dag_id (运行时间: ${runtime}s)"
        
        # 标记为超时失败
        mark_dag_as_failed "$dag_file" "instance_timeout" "DAG 实例执行超时 (${runtime}s)"
        return 0
    fi
    
    return 1
}

# 检查 DAG 节点超时
check_dag_node_timeout() {
    local dag_file="$1"
    local dag_id=$(jq -r '.dag_instance_id' "$dag_file" 2>/dev/null)
    local current_nodes=$(jq -r '.current_nodes[]?' "$dag_file" 2>/dev/null)
    
    if [[ -z "$current_nodes" ]]; then
        return 0  # 没有当前节点，不需要检查
    fi
    
    # 检查每个当前节点的执行时间
    echo "$current_nodes" | while read -r node_id; do
        if [[ -n "$node_id" ]]; then
            # 查找节点最后一次状态更新时间
            local last_update=$(jq -r --arg node "$node_id" '
                .node_execution_history[] | 
                select(.node_id == $node) | 
                .started_at' "$dag_file" 2>/dev/null | tail -1)
            
            if [[ -n "$last_update" && "$last_update" != "null" ]]; then
                local update_timestamp=$(date -d "$last_update" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${last_update%+*}" +%s 2>/dev/null)
                local current_timestamp=$(date +%s)
                local node_runtime=$((current_timestamp - update_timestamp))
                
                if [[ $node_runtime -gt $DAG_NODE_TIMEOUT ]]; then
                    dag_log "WARN" "DAG 节点超时: $dag_id -> $node_id (运行时间: ${node_runtime}s)"
                    
                    # 标记节点为超时失败
                    mark_node_as_failed "$dag_file" "$node_id" "node_timeout" "节点执行超时 (${node_runtime}s)"
                fi
            fi
        fi
    done
}

# 标记 DAG 为失败状态
mark_dag_as_failed() {
    local dag_file="$1"
    local failure_type="$2"
    local failure_message="$3"
    
    local temp_file=$(mktemp)
    jq --arg status "failed" \
       --arg failure_type "$failure_type" \
       --arg failure_message "$failure_message" \
       --arg timestamp "$(date -Iseconds)" \
       '.status = $status |
        .failed_at = $timestamp |
        .failure_reason = {
            "type": $failure_type,
            "message": $failure_message,
            "timestamp": $timestamp
        } |
        .message_tracking += [{
            "timestamp": $timestamp,
            "sender": "system:dag-monitor",
            "action": "dag_failed",
            "message": $failure_message,
            "dag_context": {
                "failure_type": $failure_type
            }
        }]' "$dag_file" > "$temp_file"
    
    if [[ $? -eq 0 ]]; then
        mv "$temp_file" "$dag_file"
        dag_log "INFO" "DAG 已标记为失败: $(basename "$dag_file")"
    else
        rm -f "$temp_file"
        dag_log "ERROR" "无法更新 DAG 状态: $dag_file"
    fi
}

# 标记节点为失败状态
mark_node_as_failed() {
    local dag_file="$1"
    local node_id="$2"
    local failure_type="$3"
    local failure_message="$4"
    
    local temp_file=$(mktemp)
    jq --arg node_id "$node_id" \
       --arg failure_type "$failure_type" \
       --arg failure_message "$failure_message" \
       --arg timestamp "$(date -Iseconds)" \
       '# 从当前节点中移除
        .current_nodes = (.current_nodes - [$node_id]) |
        # 添加到失败节点
        .failed_nodes = (.failed_nodes + [$node_id] | unique) |
        # 添加执行历史
        .node_execution_history += [{
            "node_id": $node_id,
            "status": "failed",
            "started_at": $timestamp,
            "completed_at": $timestamp,
            "failure_reason": {
                "type": $failure_type,
                "message": $failure_message
            }
        }] |
        # 添加消息追踪
        .message_tracking += [{
            "timestamp": $timestamp,
            "sender": "system:dag-monitor",
            "action": "node_failed",
            "message": $failure_message,
            "dag_context": {
                "node_id": $node_id,
                "failure_type": $failure_type
            }
        }]' "$dag_file" > "$temp_file"
    
    if [[ $? -eq 0 ]]; then
        mv "$temp_file" "$dag_file"
        dag_log "INFO" "节点已标记为失败: $node_id"
    else
        rm -f "$temp_file"
        dag_log "ERROR" "无法更新节点状态: $dag_file -> $node_id"
    fi
}

# 检查 DAG 是否应该完成
check_dag_completion() {
    local dag_file="$1"
    local dag_id=$(jq -r '.dag_instance_id' "$dag_file" 2>/dev/null)
    local current_nodes=$(jq -r '.current_nodes[]?' "$dag_file" 2>/dev/null)
    local workflow_file=$(jq -r '.workflow_file' "$dag_file" 2>/dev/null)
    
    # 如果没有当前节点，检查是否有结束节点
    if [[ -z "$current_nodes" ]]; then
        # 检查是否所有必要节点都已完成
        local completed_nodes=$(jq -r '.completed_nodes[]?' "$dag_file" 2>/dev/null)
        local failed_nodes=$(jq -r '.failed_nodes[]?' "$dag_file" 2>/dev/null)
        
        if [[ -n "$completed_nodes" || -n "$failed_nodes" ]]; then
            # 有完成或失败的节点，但没有当前节点，可能需要完成 DAG
            local has_end_node=$(jq -r '.nodes | to_entries[] | select(.value.type == "end") | .key' "$workflow_file" 2>/dev/null)
            
            if [[ -n "$has_end_node" ]]; then
                # 检查是否到达了结束节点
                echo "$completed_nodes" | while read -r node; do
                    if [[ "$node" == "$has_end_node" ]]; then
                        dag_log "INFO" "DAG 到达结束节点，标记为完成: $dag_id"
                        mark_dag_as_completed "$dag_file"
                        return 0
                    fi
                done
            fi
        fi
    fi
}

# 标记 DAG 为完成状态
mark_dag_as_completed() {
    local dag_file="$1"
    
    local temp_file=$(mktemp)
    jq --arg status "completed" \
       --arg timestamp "$(date -Iseconds)" \
       '.status = $status |
        .completed_at = $timestamp |
        .message_tracking += [{
            "timestamp": $timestamp,
            "sender": "system:dag-monitor",
            "action": "dag_completed",
            "message": "DAG 执行完成",
            "dag_context": {
                "completion_type": "automatic"
            }
        }]' "$dag_file" > "$temp_file"
    
    if [[ $? -eq 0 ]]; then
        mv "$temp_file" "$dag_file"
        dag_log "INFO" "DAG 已标记为完成: $(basename "$dag_file")"
    else
        rm -f "$temp_file"
        dag_log "ERROR" "无法更新 DAG 完成状态: $dag_file"
    fi
}

# 清理过期的 DAG 实例
cleanup_expired_dags() {
    local cleanup_threshold=$(($(date +%s) - 86400))  # 24小时前
    
    if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
        while IFS= read -r -d '' ns_dir; do
            local dag_dir="$ns_dir/dags"
            if [[ -d "$dag_dir" ]]; then
                while IFS= read -r -d '' dag_file; do
                    local status=$(jq -r '.status' "$dag_file" 2>/dev/null)
                    local completed_at=$(jq -r '.completed_at // .failed_at' "$dag_file" 2>/dev/null)
                    
                    if [[ "$status" == "completed" || "$status" == "failed" ]] && [[ -n "$completed_at" && "$completed_at" != "null" ]]; then
                        local completion_timestamp=$(date -d "$completed_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${completed_at%+*}" +%s 2>/dev/null)
                        
                        if [[ $completion_timestamp -lt $cleanup_threshold ]]; then
                            dag_log "INFO" "清理过期 DAG 实例: $(basename "$dag_file")"
                            rm -f "$dag_file"
                        fi
                    fi
                done < <(find "$dag_dir" -name "dag_*.json" -print0 2>/dev/null)
            fi
        done < <(find "$CLIEXTRA_HOME/namespaces" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    fi
}

# 主要的 DAG 监控函数
monitor_dags() {
    local dag_instances=()
    
    # 使用 while read 来正确处理包含空格的路径
    while IFS= read -r dag_file; do
        if [[ -n "$dag_file" ]]; then
            dag_instances+=("$dag_file")
        fi
    done < <(get_active_dag_instances)
    
    if [[ ${#dag_instances[@]} -eq 0 ]]; then
        dag_log "DEBUG" "没有活跃的 DAG 实例"
        return 0
    fi
    
    dag_log "DEBUG" "监控 ${#dag_instances[@]} 个 DAG 实例"
    
    for dag_file in "${dag_instances[@]}"; do
        if [[ -f "$dag_file" ]]; then
            local dag_id=$(jq -r '.dag_instance_id' "$dag_file" 2>/dev/null)
            dag_log "DEBUG" "检查 DAG: $dag_id"
            
            # 检查实例超时
            if ! check_dag_instance_timeout "$dag_file"; then
                dag_log "DEBUG" "DAG $dag_id 未超时，继续检查节点"
                
                # 检查节点超时
                check_dag_node_timeout "$dag_file"
                
                # 检查是否应该完成
                check_dag_completion "$dag_file"
            else
                dag_log "INFO" "DAG $dag_id 已超时并标记为失败"
            fi
        else
            dag_log "WARN" "DAG 文件不存在: $dag_file"
        fi
    done
}

# 导出函数供守护进程使用
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # 被 source 时导出函数
    export -f monitor_dags
    export -f dag_log
    export -f cleanup_expired_dags
fi
