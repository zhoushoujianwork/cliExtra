#!/bin/bash

# cliExtra 优化版实例列表脚本
# 性能优化：缓存、批量操作、超时控制

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"

# 性能配置
CACHE_TTL=5  # 缓存生存时间（秒）
TIMEOUT_SECONDS=10  # 命令超时时间
BATCH_SIZE=50  # 批量处理大小

# 缓存变量
declare -A INSTANCE_CACHE
declare -A CACHE_TIMESTAMP
declare -A TMUX_SESSION_CACHE

# 超时控制函数
with_timeout() {
    local timeout="$1"
    shift
    
    # 使用timeout命令（如果可用）
    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout" "$@"
        return $?
    fi
    
    # 备用方案：使用后台进程和kill
    local pid
    "$@" &
    pid=$!
    
    # 启动超时监控
    (
        sleep "$timeout"
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null
            sleep 1
            kill -KILL "$pid" 2>/dev/null
        fi
    ) &
    local timeout_pid=$!
    
    # 等待主进程完成
    wait "$pid"
    local exit_code=$?
    
    # 清理超时监控
    kill "$timeout_pid" 2>/dev/null
    
    return $exit_code
}

# 批量获取tmux会话状态
get_tmux_sessions_batch() {
    local cache_key="tmux_sessions"
    local current_time=$(date +%s)
    
    # 检查缓存
    if [[ -n "${TMUX_SESSION_CACHE[$cache_key]}" && -n "${CACHE_TIMESTAMP[$cache_key]}" ]]; then
        local cache_age=$((current_time - CACHE_TIMESTAMP[$cache_key]))
        if [[ $cache_age -lt $CACHE_TTL ]]; then
            echo "${TMUX_SESSION_CACHE[$cache_key]}"
            return 0
        fi
    fi
    
    # 批量获取所有tmux会话
    local sessions=""
    if sessions=$(with_timeout $TIMEOUT_SECONDS tmux list-sessions -F "#{session_name}" 2>/dev/null); then
        # 过滤出q_instance_开头的会话
        local q_sessions=$(echo "$sessions" | grep "^q_instance_" | sed 's/q_instance_//' | tr '\n' ' ')
        
        # 更新缓存
        TMUX_SESSION_CACHE[$cache_key]="$q_sessions"
        CACHE_TIMESTAMP[$cache_key]=$current_time
        
        echo "$q_sessions"
    else
        echo ""
    fi
}

# 批量读取状态文件
batch_read_status_files() {
    local namespace="$1"
    local status_dir=$(get_instance_status_dir "$namespace")
    
    if [[ ! -d "$status_dir" ]]; then
        return 0
    fi
    
    # 使用find和xargs批量读取，避免逐个文件操作
    local status_data=""
    if [[ -n "$(find "$status_dir" -name "*.status" -print -quit 2>/dev/null)" ]]; then
        status_data=$(find "$status_dir" -name "*.status" -exec basename {} .status \; -exec cat {} \; 2>/dev/null | paste - -)
    fi
    
    echo "$status_data"
}

# 批量获取实例信息
get_instances_batch() {
    local namespace="$1"
    local show_all="$2"
    local filter_namespace="$3"
    
    local cache_key="instances_${namespace}_${show_all}_${filter_namespace}"
    local current_time=$(date +%s)
    
    # 检查缓存
    if [[ -n "${INSTANCE_CACHE[$cache_key]}" && -n "${CACHE_TIMESTAMP[$cache_key]}" ]]; then
        local cache_age=$((current_time - CACHE_TIMESTAMP[$cache_key]))
        if [[ $cache_age -lt $CACHE_TTL ]]; then
            echo "${INSTANCE_CACHE[$cache_key]}"
            return 0
        fi
    fi
    
    local instances_data=""
    local namespaces_to_check=()
    
    # 确定要检查的namespace
    if [[ -n "$filter_namespace" ]]; then
        namespaces_to_check=("$filter_namespace")
    elif [[ "$show_all" == "true" ]]; then
        # 获取所有namespace
        if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
            while IFS= read -r -d '' ns_dir; do
                namespaces_to_check+=($(basename "$ns_dir"))
            done < <(find "$CLIEXTRA_HOME/namespaces" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
        fi
    else
        namespaces_to_check=("default")
    fi
    
    # 批量获取tmux会话
    local active_sessions=$(get_tmux_sessions_batch)
    
    # 处理每个namespace
    for ns in "${namespaces_to_check[@]}"; do
        local ns_dir="$CLIEXTRA_HOME/namespaces/$ns"
        
        if [[ ! -d "$ns_dir" ]]; then
            continue
        fi
        
        # 批量读取状态文件
        local status_data=$(batch_read_status_files "$ns")
        declare -A status_map
        
        # 解析状态数据
        while IFS=$'\t' read -r instance_id status_value; do
            if [[ -n "$instance_id" && -n "$status_value" ]]; then
                status_map["$instance_id"]="$status_value"
            fi
        done <<< "$status_data"
        
        # 扫描实例目录
        local instances_dir="$ns_dir/instances"
        if [[ -d "$instances_dir" ]]; then
            # 使用find批量获取实例目录
            while IFS= read -r -d '' instance_dir; do
                local instance_id=$(basename "$instance_dir" | sed 's/instance_//')
                
                if [[ -z "$instance_id" ]]; then
                    continue
                fi
                
                # 检查tmux会话状态
                local status="stopped"
                if [[ " $active_sessions " == *" $instance_id "* ]]; then
                    # 从状态映射中获取状态
                    local status_code="${status_map[$instance_id]:-0}"
                    status=$(status_to_name "$status_code")
                fi
                
                # 获取角色信息（如果存在）
                local role=""
                local info_file="$instance_dir/info"
                if [[ -f "$info_file" ]]; then
                    role=$(grep "^ROLE=" "$info_file" 2>/dev/null | cut -d= -f2 | tr -d '"')
                fi
                
                instances_data+="$instance_id:$status:q_instance_$instance_id:$ns:$role"$'\n'
                
            done < <(find "$instances_dir" -mindepth 1 -maxdepth 1 -type d -name "instance_*" -print0 2>/dev/null)
        fi
    done
    
    # 更新缓存
    INSTANCE_CACHE[$cache_key]="$instances_data"
    CACHE_TIMESTAMP[$cache_key]=$current_time
    
    echo "$instances_data"
}

# 增量更新检测
check_incremental_update() {
    local namespace="$1"
    local last_check_file="$CLIEXTRA_HOME/.cache/last_check_${namespace}"
    
    # 创建缓存目录
    mkdir -p "$CLIEXTRA_HOME/.cache"
    
    local current_time=$(date +%s)
    local last_check=0
    
    if [[ -f "$last_check_file" ]]; then
        last_check=$(cat "$last_check_file" 2>/dev/null || echo "0")
    fi
    
    # 检查是否需要全量更新
    local need_full_update=false
    
    # 检查实例目录的修改时间
    local ns_dir="$CLIEXTRA_HOME/namespaces/$namespace"
    if [[ -d "$ns_dir/instances" ]]; then
        local instances_mtime=$(stat -f "%m" "$ns_dir/instances" 2>/dev/null || echo "0")
        if [[ $instances_mtime -gt $last_check ]]; then
            need_full_update=true
        fi
    fi
    
    # 检查状态目录的修改时间
    if [[ -d "$ns_dir/status" ]]; then
        local status_mtime=$(stat -f "%m" "$ns_dir/status" 2>/dev/null || echo "0")
        if [[ $status_mtime -gt $last_check ]]; then
            need_full_update=true
        fi
    fi
    
    # 更新检查时间
    echo "$current_time" > "$last_check_file"
    
    echo "$need_full_update"
}

# 优化的状态名称转换
status_to_name() {
    case "$1" in
        "0") echo "idle" ;;
        "1") echo "busy" ;;
        *) echo "idle" ;;
    esac
}

# 优化的JSON输出
output_json_optimized() {
    local instance_data=("$@")
    
    echo "["
    local first=true
    
    for data in "${instance_data[@]}"; do
        if [[ -z "$data" ]]; then
            continue
        fi
        
        IFS=':' read -r instance_id status session_name namespace role <<< "$data"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        
        echo -n "  {"
        echo -n "\"id\":\"$instance_id\""
        echo -n ",\"status\":\"$status\""
        echo -n ",\"session\":\"$session_name\""
        echo -n ",\"namespace\":\"$namespace\""
        if [[ -n "$role" ]]; then
            echo -n ",\"role\":\"$role\""
        fi
        echo -n "}"
    done
    
    echo ""
    echo "]"
}

# 优化的表格输出
output_table_optimized() {
    local instance_data=("$@")
    
    if [[ ${#instance_data[@]} -eq 0 ]]; then
        return 0
    fi
    
    # 表头
    printf "%-30s %-15s %-15s %-15s %-15s\n" "NAME" "NAMESPACE" "STATUS" "SESSION" "ROLE"
    printf "%s\n" "$(printf '%.0s-' {1..90})"
    
    # 数据行
    for data in "${instance_data[@]}"; do
        if [[ -z "$data" ]]; then
            continue
        fi
        
        IFS=':' read -r instance_id status session_name namespace role <<< "$data"
        printf "%-30s %-15s %-15s %-15s %-15s\n" "$instance_id" "$namespace" "$status" "$session_name" "${role:-}"
    done
}

# 主要的list函数（优化版）
list_instances_optimized() {
    local show_all="$1"
    local filter_namespace="$2"
    local json_output="$3"
    local names_only="$4"
    
    # 获取实例数据
    local instances_data
    instances_data=$(get_instances_batch "" "$show_all" "$filter_namespace")
    
    if [[ -z "$instances_data" ]]; then
        if [[ "$json_output" == "true" ]]; then
            echo "[]"
        fi
        return 0
    fi
    
    # 转换为数组
    local instance_array=()
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            instance_array+=("$line")
        fi
    done <<< "$instances_data"
    
    # 输出结果
    if [[ "$json_output" == "true" ]]; then
        output_json_optimized "${instance_array[@]}"
    elif [[ "$names_only" == "true" ]]; then
        for data in "${instance_array[@]}"; do
            IFS=':' read -r instance_id _ _ _ _ <<< "$data"
            echo "$instance_id"
        done
    else
        output_table_optimized "${instance_array[@]}"
    fi
}

# 清理缓存
clear_cache() {
    INSTANCE_CACHE=()
    CACHE_TIMESTAMP=()
    TMUX_SESSION_CACHE=()
    
    # 清理文件缓存
    if [[ -d "$CLIEXTRA_HOME/.cache" ]]; then
        find "$CLIEXTRA_HOME/.cache" -name "last_check_*" -mtime +1 -delete 2>/dev/null
    fi
}

# 缓存统计
cache_stats() {
    echo "缓存统计:"
    echo "  实例缓存条目: ${#INSTANCE_CACHE[@]}"
    echo "  时间戳缓存条目: ${#CACHE_TIMESTAMP[@]}"
    echo "  Tmux会话缓存条目: ${#TMUX_SESSION_CACHE[@]}"
    echo "  缓存TTL: ${CACHE_TTL}秒"
    echo "  超时设置: ${TIMEOUT_SECONDS}秒"
}

# 性能基准测试
benchmark_performance() {
    echo "性能基准测试:"
    
    # 清理缓存
    clear_cache
    
    # 测试原始方法
    echo -n "  原始方法: "
    local start_time=$(date +%s.%N)
    source "$SCRIPT_DIR/cliExtra-list.sh"
    list_instances false "" false false >/dev/null 2>&1
    local end_time=$(date +%s.%N)
    local original_time=$(echo "$end_time - $start_time" | bc)
    echo "${original_time}s"
    
    # 测试优化方法（冷缓存）
    echo -n "  优化方法（冷缓存）: "
    clear_cache
    start_time=$(date +%s.%N)
    list_instances_optimized false "" false false >/dev/null 2>&1
    end_time=$(date +%s.%N)
    local optimized_cold_time=$(echo "$end_time - $start_time" | bc)
    echo "${optimized_cold_time}s"
    
    # 测试优化方法（热缓存）
    echo -n "  优化方法（热缓存）: "
    start_time=$(date +%s.%N)
    list_instances_optimized false "" false false >/dev/null 2>&1
    end_time=$(date +%s.%N)
    local optimized_hot_time=$(echo "$end_time - $start_time" | bc)
    echo "${optimized_hot_time}s"
    
    # 计算性能提升
    if command -v bc >/dev/null 2>&1; then
        local improvement_cold=$(echo "scale=1; ($original_time - $optimized_cold_time) / $original_time * 100" | bc)
        local improvement_hot=$(echo "scale=1; ($original_time - $optimized_hot_time) / $original_time * 100" | bc)
        
        echo "  性能提升（冷缓存）: ${improvement_cold}%"
        echo "  性能提升（热缓存）: ${improvement_hot}%"
    fi
}

# 如果直接运行此脚本，执行基准测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "cliExtra List 性能优化版本"
    echo ""
    
    case "${1:-}" in
        "benchmark")
            benchmark_performance
            ;;
        "cache-stats")
            cache_stats
            ;;
        "clear-cache")
            clear_cache
            echo "缓存已清理"
            ;;
        *)
            echo "用法: $0 [benchmark|cache-stats|clear-cache]"
            echo ""
            echo "命令:"
            echo "  benchmark    - 运行性能基准测试"
            echo "  cache-stats  - 显示缓存统计信息"
            echo "  clear-cache  - 清理所有缓存"
            ;;
    esac
fi
