#!/bin/bash

# cliExtra 快速实例列表脚本
# 专注于核心性能优化，兼容性更好

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"

# 性能配置
CACHE_TTL=3
TIMEOUT_SECONDS=5
CACHE_DIR="/tmp/cliextra_cache_$$"

# 初始化缓存目录
init_cache() {
    mkdir -p "$CACHE_DIR"
}

# 清理缓存
cleanup_cache() {
    rm -rf "$CACHE_DIR"
}

# 信号处理
trap cleanup_cache EXIT INT TERM

# 带超时的命令执行
execute_with_timeout() {
    local timeout="$1"
    shift
    
    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout" "$@"
    else
        # 备用方案
        "$@" &
        local pid=$!
        
        (
            sleep "$timeout"
            if kill -0 "$pid" 2>/dev/null; then
                kill -TERM "$pid" 2>/dev/null
                sleep 1
                kill -KILL "$pid" 2>/dev/null
            fi
        ) &
        local timeout_pid=$!
        
        wait "$pid" 2>/dev/null
        local exit_code=$?
        
        kill "$timeout_pid" 2>/dev/null
        return $exit_code
    fi
}

# 快速获取tmux会话
get_tmux_sessions_fast() {
    local cache_file="$CACHE_DIR/tmux_sessions"
    local current_time=$(date +%s)
    
    # 检查缓存
    if [[ -f "$cache_file" ]]; then
        local cache_time=$(stat -f "%m" "$cache_file" 2>/dev/null || echo "0")
        local cache_age=$((current_time - cache_time))
        
        if [[ $cache_age -lt $CACHE_TTL ]]; then
            cat "$cache_file" 2>/dev/null
            return 0
        fi
    fi
    
    # 获取新数据
    local sessions=""
    if sessions=$(execute_with_timeout $TIMEOUT_SECONDS tmux list-sessions -F "#{session_name}" 2>/dev/null); then
        echo "$sessions" | grep "^q_instance_" | sed 's/q_instance_//' | sort > "$cache_file"
        cat "$cache_file"
    else
        touch "$cache_file"  # 创建空缓存
        echo ""
    fi
}

# 批量读取状态文件
batch_read_status_files() {
    local namespace="$1"
    local cache_file="$CACHE_DIR/status_${namespace}"
    local current_time=$(date +%s)
    
    # 检查缓存
    if [[ -f "$cache_file" ]]; then
        local cache_time=$(stat -f "%m" "$cache_file" 2>/dev/null || echo "0")
        local cache_age=$((current_time - cache_time))
        
        if [[ $cache_age -lt $CACHE_TTL ]]; then
            cat "$cache_file" 2>/dev/null
            return 0
        fi
    fi
    
    # 获取新数据
    local status_dir=$(get_instance_status_dir "$namespace")
    
    if [[ -d "$status_dir" ]]; then
        # 使用find批量读取
        find "$status_dir" -name "*.status" -exec sh -c '
            for file; do
                instance_id=$(basename "$file" .status)
                status=$(cat "$file" 2>/dev/null || echo "0")
                echo "$instance_id:$status"
            done
        ' _ {} + > "$cache_file" 2>/dev/null
    else
        touch "$cache_file"
    fi
    
    cat "$cache_file" 2>/dev/null
}

# 快速获取实例列表
get_instances_fast() {
    local show_all="$1"
    local filter_namespace="$2"
    
    init_cache
    
    # 确定要扫描的namespace
    local namespaces_to_scan=""
    if [[ -n "$filter_namespace" ]]; then
        namespaces_to_scan="$filter_namespace"
    elif [[ "$show_all" == "true" ]]; then
        if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
            namespaces_to_scan=$(find "$CLIEXTRA_HOME/namespaces" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort)
        fi
    else
        namespaces_to_scan="default"
    fi
    
    # 获取活跃会话
    local active_sessions=$(get_tmux_sessions_fast)
    
    # 处理每个namespace
    for namespace in $namespaces_to_scan; do
        local ns_dir="$CLIEXTRA_HOME/namespaces/$namespace"
        
        if [[ ! -d "$ns_dir" ]]; then
            continue
        fi
        
        # 获取状态数据
        local status_data=$(batch_read_status_files "$namespace")
        
        # 创建状态映射文件
        local status_map_file="$CACHE_DIR/status_map_${namespace}"
        echo "$status_data" > "$status_map_file"
        
        # 扫描实例目录
        local instances_dir="$ns_dir/instances"
        if [[ -d "$instances_dir" ]]; then
            find "$instances_dir" -mindepth 1 -maxdepth 1 -type d -name "instance_*" | while read -r instance_dir; do
                local instance_id=$(basename "$instance_dir" | sed 's/instance_//')
                
                if [[ -z "$instance_id" ]]; then
                    continue
                fi
                
                # 检查会话状态
                local status="stopped"
                if echo "$active_sessions" | grep -q "^${instance_id}$"; then
                    local status_code=$(grep "^${instance_id}:" "$status_map_file" 2>/dev/null | cut -d: -f2)
                    status_code="${status_code:-0}"
                    
                    case "$status_code" in
                        "0") status="idle" ;;
                        "1") status="busy" ;;
                        *) status="idle" ;;
                    esac
                fi
                
                # 获取角色信息
                local role=""
                local info_file="$instance_dir/info"
                if [[ -f "$info_file" ]]; then
                    role=$(grep "^ROLE=" "$info_file" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
                fi
                
                echo "$instance_id:$status:q_instance_$instance_id:$namespace:$role"
            done
        fi
    done
}

# 快速JSON输出
output_json_fast() {
    echo "["
    local first=true
    
    while IFS=':' read -r instance_id status session_name namespace role; do
        if [[ -z "$instance_id" ]]; then
            continue
        fi
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        
        printf '  {"id":"%s","status":"%s","session":"%s","namespace":"%s"' \
               "$instance_id" "$status" "$session_name" "$namespace"
        
        if [[ -n "$role" ]]; then
            printf ',"role":"%s"' "$role"
        fi
        
        printf '}'
    done
    
    echo ""
    echo "]"
}

# 快速表格输出
output_table_fast() {
    local has_data=false
    
    # 先检查是否有数据
    while IFS=':' read -r instance_id status session_name namespace role; do
        if [[ -n "$instance_id" ]]; then
            if [[ "$has_data" == "false" ]]; then
                printf "%-30s %-15s %-15s %-15s %-15s\n" "NAME" "NAMESPACE" "STATUS" "SESSION" "ROLE"
                printf "%s\n" "$(printf '%.0s-' {1..90})"
                has_data=true
            fi
            
            printf "%-30s %-15s %-15s %-15s %-15s\n" \
                   "$instance_id" "$namespace" "$status" "$session_name" "${role:-}"
        fi
    done
}

# 快速名称输出
output_names_fast() {
    while IFS=':' read -r instance_id status session_name namespace role; do
        if [[ -n "$instance_id" ]]; then
            echo "$instance_id"
        fi
    done
}

# 主要的快速list函数
list_instances_fast() {
    local show_all="$1"
    local filter_namespace="$2"
    local json_output="$3"
    local names_only="$4"
    
    local start_time=$(date +%s.%N)
    
    # 获取实例数据
    local instances_data
    instances_data=$(get_instances_fast "$show_all" "$filter_namespace")
    
    if [[ -z "$instances_data" ]]; then
        if [[ "$json_output" == "true" ]]; then
            echo "[]"
        fi
        return 0
    fi
    
    # 输出结果
    if [[ "$json_output" == "true" ]]; then
        echo "$instances_data" | output_json_fast
    elif [[ "$names_only" == "true" ]]; then
        echo "$instances_data" | output_names_fast
    else
        echo "$instances_data" | output_table_fast
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    
    if [[ "${CLIEXTRA_DEBUG:-false}" == "true" ]]; then
        echo "执行时间: ${duration}s" >&2
    fi
}

# 性能基准测试
benchmark_fast() {
    echo "快速版本性能基准测试"
    echo ""
    
    # 清理缓存
    cleanup_cache
    init_cache
    
    # 测试冷缓存
    echo -n "冷缓存测试: "
    local start_time=$(date +%s.%N)
    list_instances_fast false "" false false >/dev/null 2>&1
    local end_time=$(date +%s.%N)
    local cold_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    echo "${cold_time}s"
    
    # 测试热缓存
    echo -n "热缓存测试: "
    start_time=$(date +%s.%N)
    list_instances_fast false "" false false >/dev/null 2>&1
    end_time=$(date +%s.%N)
    local hot_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    echo "${hot_time}s"
    
    # 测试原始版本
    echo -n "原始版本测试: "
    start_time=$(date +%s.%N)
    "$SCRIPT_DIR/../cliExtra.sh" list >/dev/null 2>&1
    end_time=$(date +%s.%N)
    local original_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    echo "${original_time}s"
    
    # 计算性能提升
    if command -v bc >/dev/null 2>&1 && [[ "$original_time" != "N/A" && "$hot_time" != "N/A" ]]; then
        local improvement=$(echo "scale=1; ($original_time - $hot_time) / $original_time * 100" | bc 2>/dev/null || echo "N/A")
        echo ""
        echo "性能提升: ${improvement}%"
    fi
}

# 缓存统计
cache_stats() {
    if [[ -d "$CACHE_DIR" ]]; then
        echo "缓存统计:"
        echo "  缓存目录: $CACHE_DIR"
        echo "  缓存文件数: $(find "$CACHE_DIR" -type f | wc -l)"
        echo "  缓存总大小: $(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)"
        echo "  缓存TTL: ${CACHE_TTL}s"
        
        echo "  缓存文件:"
        find "$CACHE_DIR" -type f -exec sh -c '
            for file; do
                name=$(basename "$file")
                size=$(wc -c < "$file" 2>/dev/null || echo "0")
                age=$(($(date +%s) - $(stat -f "%m" "$file" 2>/dev/null || echo "0")))
                echo "    $name: ${size} bytes (${age}s ago)"
            done
        ' _ {} +
    else
        echo "缓存目录不存在"
    fi
}

# 主函数
main() {
    case "${1:-}" in
        "benchmark")
            benchmark_fast
            ;;
        "cache-stats")
            cache_stats
            ;;
        "test")
            echo "测试快速版本..."
            CLIEXTRA_DEBUG=true list_instances_fast false "" false false
            ;;
        "clear-cache")
            cleanup_cache
            echo "缓存已清理"
            ;;
        *)
            echo "cliExtra 快速实例列表脚本"
            echo ""
            echo "用法: $0 [命令]"
            echo ""
            echo "命令:"
            echo "  benchmark   - 性能基准测试"
            echo "  cache-stats - 缓存统计信息"
            echo "  test        - 测试运行"
            echo "  clear-cache - 清理缓存"
            echo ""
            echo "环境变量:"
            echo "  CLIEXTRA_DEBUG=true - 启用调试模式"
            ;;
    esac
}

# 如果直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
