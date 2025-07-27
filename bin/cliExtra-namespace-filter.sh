#!/bin/bash

# cliExtra Namespace 过滤优化器
# 专门优化namespace过滤机制，避免不必要的目录扫描

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"

# 性能配置
NAMESPACE_CACHE_TTL=5  # namespace缓存时间
BATCH_STATUS_READ=true  # 启用批量状态读取

# 缓存目录
CACHE_DIR="/tmp/cliextra_ns_cache_$$"

# 初始化缓存
init_namespace_cache() {
    mkdir -p "$CACHE_DIR"
}

# 清理缓存
cleanup_namespace_cache() {
    rm -rf "$CACHE_DIR"
}

# 信号处理
trap cleanup_namespace_cache EXIT INT TERM

# 快速检查namespace是否存在
namespace_exists() {
    local namespace="$1"
    local ns_dir="$CLIEXTRA_HOME/namespaces/$namespace"
    
    [[ -d "$ns_dir" && -d "$ns_dir/instances" ]]
}

# 获取可用的namespace列表（缓存版本）
get_available_namespaces() {
    init_namespace_cache  # 确保缓存目录存在
    
    local cache_file="$CACHE_DIR/namespaces_list"
    local current_time=$(date +%s)
    
    # 检查缓存
    if [[ -f "$cache_file" ]]; then
        local cache_time=$(stat -f "%m" "$cache_file" 2>/dev/null || echo "0")
        local cache_age=$((current_time - cache_time))
        
        if [[ $cache_age -lt $NAMESPACE_CACHE_TTL ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    
    # 重新扫描namespace
    local namespaces=""
    if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
        # 只获取有实例目录的namespace
        for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
            if [[ -d "$ns_dir/instances" ]]; then
                local ns_name=$(basename "$ns_dir")
                namespaces="$namespaces$ns_name "
            fi
        done
    fi
    
    # 更新缓存
    echo "$namespaces" | tr ' ' '\n' | grep -v '^$' > "$cache_file"
    cat "$cache_file"
}

# 智能namespace过滤器
filter_namespaces_smart() {
    local filter_namespace="$1"
    local show_all="$2"
    
    init_namespace_cache
    
    local target_namespaces=()
    
    if [[ -n "$filter_namespace" ]]; then
        # 指定namespace：直接检查是否存在
        if namespace_exists "$filter_namespace"; then
            target_namespaces=("$filter_namespace")
        else
            echo "错误: namespace '$filter_namespace' 不存在或没有实例" >&2
            return 1
        fi
    elif [[ "$show_all" == "true" ]]; then
        # 显示所有：获取可用namespace列表
        while IFS= read -r ns; do
            if [[ -n "$ns" ]]; then
                target_namespaces+=("$ns")
            fi
        done < <(get_available_namespaces)
    else
        # 默认：只显示default namespace
        if namespace_exists "default"; then
            target_namespaces=("default")
        fi
    fi
    
    # 输出目标namespace列表
    printf '%s\n' "${target_namespaces[@]}"
}

# 批量获取tmux会话状态
get_tmux_sessions_batch() {
    local cache_file="$CACHE_DIR/tmux_sessions"
    local current_time=$(date +%s)
    
    # 检查缓存
    if [[ -f "$cache_file" ]]; then
        local cache_time=$(stat -f "%m" "$cache_file" 2>/dev/null || echo "0")
        local cache_age=$((current_time - cache_time))
        
        if [[ $cache_age -lt 2 ]]; then  # tmux会话缓存时间较短
            cat "$cache_file"
            return 0
        fi
    fi
    
    # 获取所有q_instance会话
    local sessions=""
    if sessions=$(timeout 5 tmux list-sessions -F "#{session_name}" 2>/dev/null); then
        echo "$sessions" | grep "^q_instance_" | sed 's/q_instance_//' | sort > "$cache_file"
    else
        touch "$cache_file"  # 创建空缓存
    fi
    
    cat "$cache_file"
}

# 批量读取namespace的状态文件
batch_read_namespace_status() {
    local namespace="$1"
    local cache_file="$CACHE_DIR/status_${namespace}"
    local current_time=$(date +%s)
    
    # 检查缓存
    if [[ -f "$cache_file" ]]; then
        local cache_time=$(stat -f "%m" "$cache_file" 2>/dev/null || echo "0")
        local cache_age=$((current_time - cache_time))
        
        if [[ $cache_age -lt 3 ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    
    # 批量读取状态文件
    local status_dir="$CLIEXTRA_HOME/namespaces/$namespace/status"
    
    if [[ -d "$status_dir" ]]; then
        # 使用find和xargs批量处理
        find "$status_dir" -name "*.status" -print0 2>/dev/null | \
        xargs -0 -I {} sh -c '
            instance_id=$(basename "{}" .status)
            status=$(cat "{}" 2>/dev/null || echo "0")
            echo "$instance_id:$status"
        ' > "$cache_file" 2>/dev/null
    else
        touch "$cache_file"
    fi
    
    cat "$cache_file"
}

# 优化的单namespace实例获取
get_namespace_instances_optimized() {
    local namespace="$1"
    local active_sessions="$2"  # 预先获取的活跃会话列表
    
    local ns_dir="$CLIEXTRA_HOME/namespaces/$namespace"
    local instances_dir="$ns_dir/instances"
    
    if [[ ! -d "$instances_dir" ]]; then
        return 0
    fi
    
    # 批量获取状态数据
    local status_data=$(batch_read_namespace_status "$namespace")
    
    # 创建状态映射
    local status_map_file="$CACHE_DIR/status_map_${namespace}"
    echo "$status_data" > "$status_map_file"
    
    # 批量处理实例目录
    find "$instances_dir" -mindepth 1 -maxdepth 1 -type d -name "instance_*" -print0 2>/dev/null | \
    while IFS= read -r -d '' instance_dir; do
        local instance_id=$(basename "$instance_dir" | sed 's/instance_//')
        
        if [[ -z "$instance_id" ]]; then
            continue
        fi
        
        # 检查会话状态
        local status="stopped"
        if echo "$active_sessions" | grep -q "^${instance_id}$"; then
            # 从状态映射中获取状态
            local status_code=$(grep "^${instance_id}:" "$status_map_file" 2>/dev/null | cut -d: -f2)
            status_code="${status_code:-0}"
            
            case "$status_code" in
                "0") status="idle" ;;
                "1") status="busy" ;;
                *) status="idle" ;;
            esac
        fi
        
        # 获取角色信息（如果需要）
        local role=""
        if [[ -f "$instance_dir/info" ]]; then
            role=$(grep "^ROLE=" "$instance_dir/info" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
        fi
        
        echo "$instance_id:$status:q_instance_$instance_id:$namespace:$role"
    done
}

# 主要的优化过滤函数
get_instances_with_namespace_filter() {
    local filter_namespace="$1"
    local show_all="$2"
    
    init_namespace_cache
    
    # 获取目标namespace列表
    local target_namespaces
    if ! target_namespaces=($(filter_namespaces_smart "$filter_namespace" "$show_all")); then
        return 1
    fi
    
    if [[ ${#target_namespaces[@]} -eq 0 ]]; then
        return 0
    fi
    
    # 批量获取tmux会话（一次性获取）
    local active_sessions=$(get_tmux_sessions_batch)
    
    # 并行处理多个namespace（如果有多个）
    if [[ ${#target_namespaces[@]} -gt 1 ]]; then
        # 多namespace并行处理
        local temp_files=()
        local pids=()
        
        for namespace in "${target_namespaces[@]}"; do
            local temp_file="$CACHE_DIR/ns_result_${namespace}"
            temp_files+=("$temp_file")
            
            # 后台处理每个namespace
            (
                get_namespace_instances_optimized "$namespace" "$active_sessions" > "$temp_file"
            ) &
            pids+=($!)
        done
        
        # 等待所有后台进程完成
        for pid in "${pids[@]}"; do
            wait "$pid"
        done
        
        # 合并结果
        for temp_file in "${temp_files[@]}"; do
            if [[ -f "$temp_file" ]]; then
                cat "$temp_file"
            fi
        done
    else
        # 单namespace直接处理
        get_namespace_instances_optimized "${target_namespaces[0]}" "$active_sessions"
    fi
}

# 性能基准测试
benchmark_namespace_filter() {
    local test_namespace="${1:-default}"
    
    echo "Namespace过滤性能基准测试"
    echo "测试namespace: $test_namespace"
    echo ""
    
    # 清理缓存
    cleanup_namespace_cache
    init_namespace_cache
    
    # 测试原始方法
    echo -n "原始方法: "
    local start_time=$(date +%s.%N)
    
    # 模拟原始的全量扫描
    local count=0
    if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
        for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
            if [[ -d "$ns_dir/instances" ]]; then
                local namespace=$(basename "$ns_dir")
                if [[ "$namespace" == "$test_namespace" ]]; then
                    for instance_dir in "$ns_dir/instances"/instance_*; do
                        if [[ -d "$instance_dir" ]]; then
                            count=$((count + 1))
                        fi
                    done
                fi
            fi
        done
    fi
    
    local end_time=$(date +%s.%N)
    local original_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    echo "${original_time}s (找到 $count 个实例)"
    
    # 测试优化方法
    echo -n "优化方法: "
    start_time=$(date +%s.%N)
    
    local optimized_result=$(get_instances_with_namespace_filter "$test_namespace" false)
    local optimized_count=$(echo "$optimized_result" | grep -c "^" 2>/dev/null || echo "0")
    
    end_time=$(date +%s.%N)
    local optimized_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    echo "${optimized_time}s (找到 $optimized_count 个实例)"
    
    # 计算性能提升
    if command -v bc >/dev/null 2>&1 && [[ "$original_time" != "N/A" && "$optimized_time" != "N/A" ]]; then
        local improvement=$(echo "scale=1; ($original_time - $optimized_time) / $original_time * 100" | bc 2>/dev/null || echo "N/A")
        echo ""
        echo "性能提升: ${improvement}%"
    fi
    
    # 测试缓存效果
    echo ""
    echo -n "缓存命中测试: "
    start_time=$(date +%s.%N)
    get_instances_with_namespace_filter "$test_namespace" false >/dev/null
    end_time=$(date +%s.%N)
    local cached_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    echo "${cached_time}s"
    
    if command -v bc >/dev/null 2>&1 && [[ "$optimized_time" != "N/A" && "$cached_time" != "N/A" ]]; then
        local cache_improvement=$(echo "scale=1; ($optimized_time - $cached_time) / $optimized_time * 100" | bc 2>/dev/null || echo "N/A")
        echo "缓存性能提升: ${cache_improvement}%"
    fi
}

# 缓存统计
show_cache_stats() {
    if [[ -d "$CACHE_DIR" ]]; then
        echo "Namespace过滤缓存统计:"
        echo "  缓存目录: $CACHE_DIR"
        echo "  缓存文件数: $(find "$CACHE_DIR" -type f | wc -l)"
        
        echo "  缓存文件详情:"
        find "$CACHE_DIR" -type f -exec sh -c '
            for file; do
                name=$(basename "$file")
                size=$(wc -c < "$file" 2>/dev/null || echo "0")
                lines=$(wc -l < "$file" 2>/dev/null || echo "0")
                age=$(($(date +%s) - $(stat -f "%m" "$file" 2>/dev/null || echo "0")))
                echo "    $name: ${size}字节, ${lines}行, ${age}秒前"
            done
        ' _ {} +
    else
        echo "缓存目录不存在"
    fi
}

# 验证过滤结果的正确性
validate_filter_results() {
    local filter_namespace="$1"
    local show_all="$2"
    
    echo "验证namespace过滤结果..."
    
    # 获取优化结果
    local optimized_result=$(get_instances_with_namespace_filter "$filter_namespace" "$show_all")
    
    # 分析结果
    local total_instances=0
    local namespaces_found=()
    
    while IFS=':' read -r instance_id status session_name namespace role; do
        if [[ -n "$instance_id" ]]; then
            total_instances=$((total_instances + 1))
            
            # 收集namespace
            if [[ ! " ${namespaces_found[*]} " =~ " ${namespace} " ]]; then
                namespaces_found+=("$namespace")
            fi
            
            # 验证过滤逻辑
            if [[ -n "$filter_namespace" && "$namespace" != "$filter_namespace" ]]; then
                echo "错误: 发现不匹配的namespace: $namespace (期望: $filter_namespace)"
                return 1
            fi
            
            if [[ -z "$filter_namespace" && "$show_all" != "true" && "$namespace" != "default" ]]; then
                echo "错误: 默认模式下发现非default namespace: $namespace"
                return 1
            fi
        fi
    done <<< "$optimized_result"
    
    echo "验证结果:"
    echo "  总实例数: $total_instances"
    echo "  涉及namespace: ${namespaces_found[*]}"
    echo "  过滤条件: ${filter_namespace:-默认(default)}"
    echo "  显示所有: $show_all"
    
    if [[ -n "$filter_namespace" ]]; then
        if [[ ${#namespaces_found[@]} -eq 1 && "${namespaces_found[0]}" == "$filter_namespace" ]]; then
            echo "  ✅ 过滤结果正确"
        else
            echo "  ❌ 过滤结果错误"
            return 1
        fi
    elif [[ "$show_all" == "true" ]]; then
        echo "  ✅ 显示所有namespace"
    else
        if [[ ${#namespaces_found[@]} -eq 1 && "${namespaces_found[0]}" == "default" ]] || [[ ${#namespaces_found[@]} -eq 0 ]]; then
            echo "  ✅ 默认过滤结果正确"
        else
            echo "  ❌ 默认过滤结果错误"
            return 1
        fi
    fi
    
    return 0
}

# 主函数
main() {
    case "${1:-}" in
        "filter")
            get_instances_with_namespace_filter "$2" "$3"
            ;;
        "benchmark")
            benchmark_namespace_filter "$2"
            ;;
        "validate")
            validate_filter_results "$2" "$3"
            ;;
        "cache-stats")
            show_cache_stats
            ;;
        "clear-cache")
            cleanup_namespace_cache
            echo "缓存已清理"
            ;;
        "namespaces")
            get_available_namespaces
            ;;
        *)
            echo "cliExtra Namespace 过滤优化器"
            echo ""
            echo "用法: $0 <命令> [参数]"
            echo ""
            echo "命令:"
            echo "  filter <ns> <all>     - 获取过滤后的实例列表"
            echo "  benchmark [ns]        - 性能基准测试"
            echo "  validate <ns> <all>   - 验证过滤结果"
            echo "  cache-stats           - 显示缓存统计"
            echo "  clear-cache           - 清理缓存"
            echo "  namespaces            - 列出可用namespace"
            echo ""
            echo "示例:"
            echo "  $0 filter frontend false"
            echo "  $0 benchmark default"
            echo "  $0 validate '' true"
            ;;
    esac
}

# 如果直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
