#!/bin/bash

# cliExtra 增量状态更新管理器
# 实现增量更新而非全量扫描，提升性能

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 增量更新配置
INCREMENTAL_CACHE_DIR="$CLIEXTRA_HOME/.incremental_cache"
CHANGE_LOG_FILE="$INCREMENTAL_CACHE_DIR/changes.log"
LAST_SCAN_FILE="$INCREMENTAL_CACHE_DIR/last_scan"
MAX_CHANGE_LOG_SIZE=10000  # 最大变更日志条目数

# 初始化增量缓存目录
init_incremental_cache() {
    mkdir -p "$INCREMENTAL_CACHE_DIR"
    
    if [[ ! -f "$CHANGE_LOG_FILE" ]]; then
        touch "$CHANGE_LOG_FILE"
    fi
    
    if [[ ! -f "$LAST_SCAN_FILE" ]]; then
        echo "0" > "$LAST_SCAN_FILE"
    fi
}

# 记录变更事件
log_change_event() {
    local event_type="$1"  # CREATE, UPDATE, DELETE
    local instance_id="$2"
    local namespace="$3"
    local timestamp=$(date +%s)
    local details="$4"
    
    init_incremental_cache
    
    # 记录变更
    echo "$timestamp:$event_type:$namespace:$instance_id:$details" >> "$CHANGE_LOG_FILE"
    
    # 清理过大的日志文件
    local line_count=$(wc -l < "$CHANGE_LOG_FILE" 2>/dev/null || echo "0")
    if [[ $line_count -gt $MAX_CHANGE_LOG_SIZE ]]; then
        tail -n $((MAX_CHANGE_LOG_SIZE / 2)) "$CHANGE_LOG_FILE" > "$CHANGE_LOG_FILE.tmp"
        mv "$CHANGE_LOG_FILE.tmp" "$CHANGE_LOG_FILE"
    fi
}

# 获取自上次扫描以来的变更
get_changes_since_last_scan() {
    local last_scan_time="$1"
    
    if [[ ! -f "$CHANGE_LOG_FILE" ]]; then
        return 0
    fi
    
    # 获取指定时间之后的变更
    awk -F: -v since="$last_scan_time" '$1 > since {print}' "$CHANGE_LOG_FILE"
}

# 构建增量状态快照
build_incremental_snapshot() {
    local namespace="${1:-default}"
    local force_full_scan="${2:-false}"
    
    init_incremental_cache
    
    local snapshot_file="$INCREMENTAL_CACHE_DIR/snapshot_${namespace}.json"
    local last_scan_time=$(cat "$LAST_SCAN_FILE" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    
    # 检查是否需要全量扫描
    local need_full_scan="$force_full_scan"
    
    if [[ ! -f "$snapshot_file" ]]; then
        need_full_scan="true"
    fi
    
    # 检查目录修改时间
    local ns_dir="$CLIEXTRA_HOME/namespaces/$namespace"
    if [[ -d "$ns_dir" ]]; then
        local instances_mtime=$(stat -f "%m" "$ns_dir/instances" 2>/dev/null || echo "0")
        local status_mtime=$(stat -f "%m" "$ns_dir/status" 2>/dev/null || echo "0")
        
        if [[ $instances_mtime -gt $last_scan_time || $status_mtime -gt $last_scan_time ]]; then
            need_full_scan="true"
        fi
    fi
    
    if [[ "$need_full_scan" == "true" ]]; then
        # 全量扫描
        build_full_snapshot "$namespace" "$snapshot_file"
    else
        # 增量更新
        apply_incremental_changes "$namespace" "$snapshot_file" "$last_scan_time"
    fi
    
    # 更新扫描时间
    echo "$current_time" > "$LAST_SCAN_FILE"
    
    # 返回快照文件路径
    echo "$snapshot_file"
}

# 构建全量快照
build_full_snapshot() {
    local namespace="$1"
    local snapshot_file="$2"
    
    local ns_dir="$CLIEXTRA_HOME/namespaces/$namespace"
    
    if [[ ! -d "$ns_dir" ]]; then
        echo "{}" > "$snapshot_file"
        return 0
    fi
    
    # 获取所有活跃的tmux会话
    local active_sessions=""
    if active_sessions=$(timeout 5 tmux list-sessions -F "#{session_name}" 2>/dev/null); then
        active_sessions=$(echo "$active_sessions" | grep "^q_instance_" | sed 's/q_instance_//' | sort)
    fi
    
    # 构建JSON快照
    echo "{" > "$snapshot_file"
    echo "  \"namespace\": \"$namespace\"," >> "$snapshot_file"
    echo "  \"timestamp\": $(date +%s)," >> "$snapshot_file"
    echo "  \"instances\": {" >> "$snapshot_file"
    
    local first_instance=true
    local instances_dir="$ns_dir/instances"
    
    if [[ -d "$instances_dir" ]]; then
        # 批量处理实例
        while IFS= read -r -d '' instance_dir; do
            local instance_id=$(basename "$instance_dir" | sed 's/instance_//')
            
            if [[ -z "$instance_id" ]]; then
                continue
            fi
            
            # 检查tmux会话状态
            local is_active="false"
            if echo "$active_sessions" | grep -q "^${instance_id}$"; then
                is_active="true"
            fi
            
            # 获取状态
            local status="0"
            local status_file="$ns_dir/status/${instance_id}.status"
            if [[ -f "$status_file" ]]; then
                status=$(cat "$status_file" 2>/dev/null | tr -d '\n\r\t ' || echo "0")
            fi
            
            # 获取角色信息
            local role=""
            local info_file="$instance_dir/info"
            if [[ -f "$info_file" ]]; then
                role=$(grep "^ROLE=" "$info_file" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
            fi
            
            # 获取项目路径
            local project_path=""
            local project_file="$instance_dir/project_path"
            if [[ -f "$project_file" ]]; then
                project_path=$(cat "$project_file" 2>/dev/null || echo "")
            fi
            
            # 添加到JSON
            if [[ "$first_instance" == "true" ]]; then
                first_instance=false
            else
                echo "," >> "$snapshot_file"
            fi
            
            echo -n "    \"$instance_id\": {" >> "$snapshot_file"
            echo -n "\"active\": $is_active" >> "$snapshot_file"
            echo -n ", \"status\": \"$status\"" >> "$snapshot_file"
            echo -n ", \"role\": \"$role\"" >> "$snapshot_file"
            echo -n ", \"project_path\": \"$project_path\"" >> "$snapshot_file"
            echo -n ", \"last_updated\": $(date +%s)" >> "$snapshot_file"
            echo -n "}" >> "$snapshot_file"
            
        done < <(find "$instances_dir" -mindepth 1 -maxdepth 1 -type d -name "instance_*" -print0 2>/dev/null)
    fi
    
    echo "" >> "$snapshot_file"
    echo "  }" >> "$snapshot_file"
    echo "}" >> "$snapshot_file"
}

# 应用增量变更
apply_incremental_changes() {
    local namespace="$1"
    local snapshot_file="$2"
    local last_scan_time="$3"
    
    # 获取变更列表
    local changes=$(get_changes_since_last_scan "$last_scan_time")
    
    if [[ -z "$changes" ]]; then
        # 没有变更，直接返回
        return 0
    fi
    
    # 读取现有快照
    if [[ ! -f "$snapshot_file" ]]; then
        build_full_snapshot "$namespace" "$snapshot_file"
        return 0
    fi
    
    # 创建临时文件
    local temp_file="$snapshot_file.tmp"
    cp "$snapshot_file" "$temp_file"
    
    # 应用每个变更
    while IFS=':' read -r timestamp event_type change_namespace instance_id details; do
        if [[ "$change_namespace" != "$namespace" ]]; then
            continue
        fi
        
        case "$event_type" in
            "CREATE"|"UPDATE")
                update_instance_in_snapshot "$temp_file" "$instance_id"
                ;;
            "DELETE")
                remove_instance_from_snapshot "$temp_file" "$instance_id"
                ;;
        esac
    done <<< "$changes"
    
    # 更新时间戳
    local current_time=$(date +%s)
    sed -i.bak "s/\"timestamp\": [0-9]*/\"timestamp\": $current_time/" "$temp_file"
    rm -f "$temp_file.bak"
    
    # 替换原文件
    mv "$temp_file" "$snapshot_file"
}

# 在快照中更新实例信息
update_instance_in_snapshot() {
    local snapshot_file="$1"
    local instance_id="$2"
    
    # 获取最新的实例信息
    local namespace=$(jq -r '.namespace' "$snapshot_file" 2>/dev/null || echo "default")
    local ns_dir="$CLIEXTRA_HOME/namespaces/$namespace"
    local instance_dir="$ns_dir/instances/instance_$instance_id"
    
    if [[ ! -d "$instance_dir" ]]; then
        remove_instance_from_snapshot "$snapshot_file" "$instance_id"
        return 0
    fi
    
    # 检查tmux会话状态
    local is_active="false"
    if tmux has-session -t "q_instance_$instance_id" 2>/dev/null; then
        is_active="true"
    fi
    
    # 获取状态
    local status="0"
    local status_file="$ns_dir/status/${instance_id}.status"
    if [[ -f "$status_file" ]]; then
        status=$(cat "$status_file" 2>/dev/null | tr -d '\n\r\t ' || echo "0")
    fi
    
    # 获取角色信息
    local role=""
    local info_file="$instance_dir/info"
    if [[ -f "$info_file" ]]; then
        role=$(grep "^ROLE=" "$info_file" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
    fi
    
    # 获取项目路径
    local project_path=""
    local project_file="$instance_dir/project_path"
    if [[ -f "$project_file" ]]; then
        project_path=$(cat "$project_file" 2>/dev/null || echo "")
    fi
    
    # 使用jq更新JSON（如果可用）
    if command -v jq >/dev/null 2>&1; then
        local temp_file="$snapshot_file.tmp"
        jq --arg id "$instance_id" \
           --argjson active "$is_active" \
           --arg status "$status" \
           --arg role "$role" \
           --arg project_path "$project_path" \
           --argjson timestamp "$(date +%s)" \
           '.instances[$id] = {
               "active": $active,
               "status": $status,
               "role": $role,
               "project_path": $project_path,
               "last_updated": $timestamp
           }' "$snapshot_file" > "$temp_file"
        mv "$temp_file" "$snapshot_file"
    else
        # 备用方案：重新构建快照
        build_full_snapshot "$namespace" "$snapshot_file"
    fi
}

# 从快照中移除实例
remove_instance_from_snapshot() {
    local snapshot_file="$1"
    local instance_id="$2"
    
    if command -v jq >/dev/null 2>&1; then
        local temp_file="$snapshot_file.tmp"
        jq --arg id "$instance_id" 'del(.instances[$id])' "$snapshot_file" > "$temp_file"
        mv "$temp_file" "$snapshot_file"
    else
        # 备用方案：重新构建快照
        local namespace=$(grep '"namespace"' "$snapshot_file" | cut -d'"' -f4)
        build_full_snapshot "$namespace" "$snapshot_file"
    fi
}

# 获取快照数据
get_snapshot_data() {
    local namespace="${1:-default}"
    local force_refresh="${2:-false}"
    
    local snapshot_file=$(build_incremental_snapshot "$namespace" "$force_refresh")
    
    if [[ -f "$snapshot_file" ]]; then
        cat "$snapshot_file"
    else
        echo "{}"
    fi
}

# 快照统计信息
snapshot_stats() {
    local namespace="${1:-default}"
    local snapshot_file="$INCREMENTAL_CACHE_DIR/snapshot_${namespace}.json"
    
    if [[ ! -f "$snapshot_file" ]]; then
        echo "快照文件不存在: $snapshot_file"
        return 1
    fi
    
    echo "快照统计信息 ($namespace):"
    
    if command -v jq >/dev/null 2>&1; then
        local total_instances=$(jq '.instances | length' "$snapshot_file")
        local active_instances=$(jq '[.instances[] | select(.active == true)] | length' "$snapshot_file")
        local busy_instances=$(jq '[.instances[] | select(.status == "1")] | length' "$snapshot_file")
        local timestamp=$(jq -r '.timestamp' "$snapshot_file")
        local readable_time=$(date -r "$timestamp" 2>/dev/null || echo "unknown")
        
        echo "  总实例数: $total_instances"
        echo "  活跃实例数: $active_instances"
        echo "  忙碌实例数: $busy_instances"
        echo "  快照时间: $readable_time"
    else
        local file_size=$(wc -c < "$snapshot_file" 2>/dev/null || echo "0")
        echo "  快照文件大小: ${file_size} bytes"
    fi
    
    # 变更日志统计
    if [[ -f "$CHANGE_LOG_FILE" ]]; then
        local change_count=$(wc -l < "$CHANGE_LOG_FILE" 2>/dev/null || echo "0")
        echo "  变更日志条目: $change_count"
    fi
}

# 清理增量缓存
cleanup_incremental_cache() {
    local max_age_days="${1:-7}"
    
    if [[ -d "$INCREMENTAL_CACHE_DIR" ]]; then
        echo "清理 ${max_age_days} 天前的增量缓存..."
        
        # 清理旧的快照文件
        find "$INCREMENTAL_CACHE_DIR" -name "snapshot_*.json" -mtime +$max_age_days -delete 2>/dev/null
        
        # 清理变更日志
        if [[ -f "$CHANGE_LOG_FILE" ]]; then
            local cutoff_time=$(($(date +%s) - max_age_days * 86400))
            awk -F: -v cutoff="$cutoff_time" '$1 > cutoff {print}' "$CHANGE_LOG_FILE" > "$CHANGE_LOG_FILE.tmp"
            mv "$CHANGE_LOG_FILE.tmp" "$CHANGE_LOG_FILE"
        fi
        
        echo "清理完成"
    fi
}

# 性能基准测试
benchmark_incremental() {
    local namespace="${1:-default}"
    
    echo "增量更新性能基准测试 ($namespace):"
    
    # 测试全量扫描
    echo -n "  全量扫描: "
    local start_time=$(date +%s.%N)
    build_incremental_snapshot "$namespace" "true" >/dev/null
    local end_time=$(date +%s.%N)
    local full_scan_time=$(echo "$end_time - $start_time" | bc)
    echo "${full_scan_time}s"
    
    # 模拟一些变更
    log_change_event "UPDATE" "test_instance" "$namespace" "benchmark_test"
    
    # 测试增量更新
    echo -n "  增量更新: "
    start_time=$(date +%s.%N)
    build_incremental_snapshot "$namespace" "false" >/dev/null
    end_time=$(date +%s.%N)
    local incremental_time=$(echo "$end_time - $start_time" | bc)
    echo "${incremental_time}s"
    
    # 计算性能提升
    if command -v bc >/dev/null 2>&1; then
        local improvement=$(echo "scale=1; ($full_scan_time - $incremental_time) / $full_scan_time * 100" | bc)
        echo "  性能提升: ${improvement}%"
    fi
}

# 主函数
main() {
    case "${1:-}" in
        "init")
            init_incremental_cache
            echo "增量缓存已初始化"
            ;;
        "snapshot")
            get_snapshot_data "${2:-default}" "${3:-false}"
            ;;
        "stats")
            snapshot_stats "${2:-default}"
            ;;
        "cleanup")
            cleanup_incremental_cache "${2:-7}"
            ;;
        "benchmark")
            benchmark_incremental "${2:-default}"
            ;;
        "log-change")
            log_change_event "$2" "$3" "$4" "$5"
            echo "变更已记录"
            ;;
        *)
            echo "cliExtra 增量状态更新管理器"
            echo ""
            echo "用法: $0 <命令> [参数]"
            echo ""
            echo "命令:"
            echo "  init                    - 初始化增量缓存"
            echo "  snapshot [namespace]    - 获取快照数据"
            echo "  stats [namespace]       - 显示快照统计"
            echo "  cleanup [days]          - 清理旧缓存（默认7天）"
            echo "  benchmark [namespace]   - 性能基准测试"
            echo "  log-change <type> <id> <ns> [details] - 记录变更事件"
            echo ""
            echo "示例:"
            echo "  $0 snapshot default"
            echo "  $0 stats frontend"
            echo "  $0 benchmark"
            ;;
    esac
}

# 如果直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
