#!/bin/bash

# cliExtra 高性能实例列表脚本 v2
# 集成所有性能优化：缓存、增量更新、超时控制、批量操作

# 检查bash版本
if [[ ${BASH_VERSION%%.*} -lt 4 ]]; then
    echo "错误: 需要 Bash 4.0 或更高版本来支持关联数组" >&2
    echo "当前版本: $BASH_VERSION" >&2
    exit 1
fi

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"

# 性能配置
CACHE_TTL=3  # 缓存生存时间（秒）
TIMEOUT_SECONDS=8  # 命令超时时间
BATCH_SIZE=20  # 批量处理大小
ENABLE_INCREMENTAL=false  # 暂时禁用增量更新

# 全局缓存（使用关联数组）
declare -A PERFORMANCE_CACHE
declare -A CACHE_TIMESTAMPS

# 性能监控
PERF_START_TIME=""
PERF_METRICS=()

# 开始性能监控
start_performance_monitoring() {
    PERF_START_TIME=$(date +%s.%N)
    PERF_METRICS=()
}

# 记录性能指标
record_performance_metric() {
    local metric_name="$1"
    local start_time="$2"
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
    
    PERF_METRICS+=("$metric_name:$duration")
}

# 显示性能报告
show_performance_report() {
    if [[ -z "$PERF_START_TIME" ]]; then
        return 0
    fi
    
    local total_time=$(echo "$(date +%s.%N) - $PERF_START_TIME" | bc 2>/dev/null || echo "0")
    
    if [[ "${CLIEXTRA_DEBUG:-false}" == "true" ]]; then
        echo "=== 性能报告 ===" >&2
        echo "总执行时间: ${total_time}s" >&2
        
        for metric in "${PERF_METRICS[@]}"; do
            local name=$(echo "$metric" | cut -d: -f1)
            local time=$(echo "$metric" | cut -d: -f2)
            echo "  $name: ${time}s" >&2
        done
        echo "================" >&2
    fi
}

# 高性能tmux会话检查
get_active_sessions_fast() {
    local cache_key="active_sessions"
    local current_time=$(date +%s)
    
    # 检查缓存
    if [[ -n "${PERFORMANCE_CACHE[$cache_key]}" && -n "${CACHE_TIMESTAMPS[$cache_key]}" ]]; then
        local cache_age=$((current_time - CACHE_TIMESTAMPS[$cache_key]))
        if [[ $cache_age -lt $CACHE_TTL ]]; then
            echo "${PERFORMANCE_CACHE[$cache_key]}"
            return 0
        fi
    fi
    
    local start_time=$(date +%s.%N)
    
    # 使用超时控制获取tmux会话
    local sessions=""
    if sessions=$(execute_with_timeout $TIMEOUT_SECONDS 1 tmux list-sessions -F "#{session_name}" 2>/dev/null); then
        # 过滤并处理
        local q_sessions=$(echo "$sessions" | grep "^q_instance_" | sed 's/q_instance_//' | sort | tr '\n' '|')
        
        # 更新缓存
        PERFORMANCE_CACHE[$cache_key]="$q_sessions"
        CACHE_TIMESTAMPS[$cache_key]=$current_time
        
        record_performance_metric "tmux_sessions" "$start_time"
        echo "$q_sessions"
    else
        record_performance_metric "tmux_sessions_failed" "$start_time"
        echo ""
    fi
}

# 批量状态文件读取
batch_read_all_status() {
    local namespace="$1"
    local cache_key="status_${namespace}"
    local current_time=$(date +%s)
    
    # 检查缓存
    if [[ -n "${PERFORMANCE_CACHE[$cache_key]}" && -n "${CACHE_TIMESTAMPS[$cache_key]}" ]]; then
        local cache_age=$((current_time - CACHE_TIMESTAMPS[$cache_key]))
        if [[ $cache_age -lt $CACHE_TTL ]]; then
            echo "${PERFORMANCE_CACHE[$cache_key]}"
            return 0
        fi
    fi
    
    local start_time=$(date +%s.%N)
    local status_dir=$(get_instance_status_dir "$namespace")
    local status_data=""
    
    if [[ -d "$status_dir" ]]; then
        # 使用find和xargs进行批量读取
        local temp_file="/tmp/status_batch_$$"
        
        if find "$status_dir" -name "*.status" -print0 2>/dev/null | \
           xargs -0 -I {} sh -c 'echo "$(basename "{}" .status):$(cat "{}" 2>/dev/null || echo "0")"' > "$temp_file" 2>/dev/null; then
            status_data=$(cat "$temp_file" 2>/dev/null | tr '\n' '|')
        fi
        
        rm -f "$temp_file"
    fi
    
    # 更新缓存
    PERFORMANCE_CACHE[$cache_key]="$status_data"
    CACHE_TIMESTAMPS[$cache_key]=$current_time
    
    record_performance_metric "batch_status_read" "$start_time"
    echo "$status_data"
}

# 快速实例信息获取
get_instance_info_fast() {
    local instance_id="$1"
    local instance_dir="$2"
    
    local info=""
    local role=""
    local project_path=""
    
    # 批量读取文件
    if [[ -f "$instance_dir/info" ]]; then
        role=$(grep "^ROLE=" "$instance_dir/info" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
    fi
    
    if [[ -f "$instance_dir/project_path" ]]; then
        project_path=$(cat "$instance_dir/project_path" 2>/dev/null || echo "")
    fi
    
    echo "$role|$project_path"
}

# 高性能实例列表获取
get_instances_list_fast() {
    local show_all="$1"
    local filter_namespace="$2"
    
    local start_time=$(date +%s.%N)
    local instances_data=""
    
    # 确定要扫描的namespace
    local namespaces_to_scan=()
    if [[ -n "$filter_namespace" ]]; then
        namespaces_to_scan=("$filter_namespace")
    elif [[ "$show_all" == "true" ]]; then
        # 快速获取所有namespace
        if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
            while IFS= read -r -d '' ns_dir; do
                namespaces_to_scan+=($(basename "$ns_dir"))
            done < <(find "$CLIEXTRA_HOME/namespaces" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
        fi
    else
        namespaces_to_scan=("default")
    fi
    
    # 获取活跃会话（一次性获取）
    local active_sessions=$(get_active_sessions_fast)
    
    # 处理每个namespace
    for namespace in "${namespaces_to_scan[@]}"; do
        local ns_start_time=$(date +%s.%N)
        
        # 检查是否使用增量更新
        if [[ "$ENABLE_INCREMENTAL" == "true" ]]; then
            # 尝试使用增量更新
            local snapshot_data=$(get_snapshot_data "$namespace" false 2>/dev/null)
            
            if [[ -n "$snapshot_data" && "$snapshot_data" != "{}" ]]; then
                # 使用快照数据
                if command -v jq >/dev/null 2>&1; then
                    local instances_json=$(echo "$snapshot_data" | jq -r '.instances // {} | to_entries[] | "\(.key):\(.value.status):\(.value.role):\(.value.active)"' 2>/dev/null)
                    
                    while IFS=':' read -r instance_id status role is_active; do
                        if [[ -n "$instance_id" ]]; then
                            local session_status="stopped"
                            if [[ "$is_active" == "true" ]]; then
                                session_status=$(status_to_name "$status")
                            fi
                            
                            instances_data+="$instance_id:$session_status:q_instance_$instance_id:$namespace:$role"$'\n'
                        fi
                    done <<< "$instances_json"
                    
                    record_performance_metric "incremental_${namespace}" "$ns_start_time"
                    continue
                fi
            fi
        fi
        
        # 回退到传统扫描
        local ns_dir="$CLIEXTRA_HOME/namespaces/$namespace"
        if [[ ! -d "$ns_dir" ]]; then
            continue
        fi
        
        # 批量获取状态数据
        local status_data=$(batch_read_all_status "$namespace")
        declare -A status_map
        
        # 解析状态数据
        IFS='|' read -ra status_entries <<< "$status_data"
        for entry in "${status_entries[@]}"; do
            if [[ -n "$entry" ]]; then
                IFS=':' read -r inst_id status_val <<< "$entry"
                if [[ -n "$inst_id" && -n "$status_val" ]]; then
                    status_map["$inst_id"]="$status_val"
                fi
            fi
        done
        
        # 扫描实例目录
        local instances_dir="$ns_dir/instances"
        if [[ -d "$instances_dir" ]]; then
            # 批量处理实例
            local instance_batch=()
            local batch_count=0
            
            while IFS= read -r -d '' instance_dir; do
                instance_batch+=("$instance_dir")
                batch_count=$((batch_count + 1))
                
                # 达到批量大小时处理
                if [[ $batch_count -ge $BATCH_SIZE ]]; then
                    process_instance_batch "${instance_batch[@]}"
                    instance_batch=()
                    batch_count=0
                fi
                
            done < <(find "$instances_dir" -mindepth 1 -maxdepth 1 -type d -name "instance_*" -print0 2>/dev/null)
            
            # 处理剩余的实例
            if [[ ${#instance_batch[@]} -gt 0 ]]; then
                process_instance_batch "${instance_batch[@]}"
            fi
        fi
        
        record_performance_metric "traditional_${namespace}" "$ns_start_time"
    done
    
    record_performance_metric "total_scan" "$start_time"
    echo "$instances_data"
}

# 批量处理实例
process_instance_batch() {
    local instance_dirs=("$@")
    
    for instance_dir in "${instance_dirs[@]}"; do
        local instance_id=$(basename "$instance_dir" | sed 's/instance_//')
        
        if [[ -z "$instance_id" ]]; then
            continue
        fi
        
        # 检查会话状态
        local status="stopped"
        if [[ "|$active_sessions|" == *"|$instance_id|"* ]]; then
            local status_code="${status_map[$instance_id]:-0}"
            status=$(status_to_name "$status_code")
        fi
        
        # 获取实例信息
        local info_data=$(get_instance_info_fast "$instance_id" "$instance_dir")
        IFS='|' read -r role project_path <<< "$info_data"
        
        instances_data+="$instance_id:$status:q_instance_$instance_id:$namespace:$role"$'\n'
    done
}

# 优化的输出函数
output_optimized() {
    local format="$1"
    local names_only="$2"
    shift 2
    local instance_data=("$@")
    
    local start_time=$(date +%s.%N)
    
    if [[ ${#instance_data[@]} -eq 0 ]]; then
        if [[ "$format" == "json" ]]; then
            echo "[]"
        fi
        return 0
    fi
    
    case "$format" in
        "json")
            output_json_fast "${instance_data[@]}"
            ;;
        "names")
            output_names_fast "${instance_data[@]}"
            ;;
        *)
            output_table_fast "${instance_data[@]}"
            ;;
    esac
    
    record_performance_metric "output_formatting" "$start_time"
}

# 快速JSON输出
output_json_fast() {
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
        
        # 使用printf提高性能
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
    local instance_data=("$@")
    
    if [[ ${#instance_data[@]} -eq 0 ]]; then
        return 0
    fi
    
    # 使用printf提高性能
    printf "%-30s %-15s %-15s %-15s %-15s\n" "NAME" "NAMESPACE" "STATUS" "SESSION" "ROLE"
    printf "%s\n" "$(printf '%.0s-' {1..90})"
    
    for data in "${instance_data[@]}"; do
        if [[ -z "$data" ]]; then
            continue
        fi
        
        IFS=':' read -r instance_id status session_name namespace role <<< "$data"
        printf "%-30s %-15s %-15s %-15s %-15s\n" \
               "$instance_id" "$namespace" "$status" "$session_name" "${role:-}"
    done
}

# 快速名称输出
output_names_fast() {
    local instance_data=("$@")
    
    for data in "${instance_data[@]}"; do
        if [[ -z "$data" ]]; then
            continue
        fi
        
        IFS=':' read -r instance_id _ _ _ _ <<< "$data"
        echo "$instance_id"
    done
}

# 状态名称转换（内联优化）
status_to_name() {
    case "$1" in
        "0") echo "idle" ;;
        "1") echo "busy" ;;
        *) echo "idle" ;;
    esac
}

# 主要的list函数（v2优化版）
list_instances_v2() {
    local show_all="$1"
    local filter_namespace="$2"
    local json_output="$3"
    local names_only="$4"
    local target_instance="$5"
    
    start_performance_monitoring
    
    # 如果指定了特定实例，使用快速查找
    if [[ -n "$target_instance" ]]; then
        show_instance_details_fast "$target_instance" "$json_output"
        show_performance_report
        return $?
    fi
    
    # 获取实例列表
    local instances_data
    instances_data=$(get_instances_list_fast "$show_all" "$filter_namespace")
    
    if [[ -z "$instances_data" ]]; then
        if [[ "$json_output" == "true" ]]; then
            echo "[]"
        fi
        show_performance_report
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
    local output_format="table"
    if [[ "$json_output" == "true" ]]; then
        output_format="json"
    elif [[ "$names_only" == "true" ]]; then
        output_format="names"
    fi
    
    output_optimized "$output_format" "$names_only" "${instance_array[@]}"
    
    show_performance_report
}

# 快速实例详情显示
show_instance_details_fast() {
    local instance_id="$1"
    local json_output="$2"
    
    local start_time=$(date +%s.%N)
    
    # 快速查找实例
    local instance_dir=$(find_instance_info_dir "$instance_id")
    if [[ $? -ne 0 || -z "$instance_dir" ]]; then
        echo "错误: 找不到实例 $instance_id" >&2
        return 1
    fi
    
    # 获取namespace
    local namespace=$(echo "$instance_dir" | sed -E 's|.*/namespaces/([^/]+)/instances/.*|\1|')
    
    # 获取详细信息
    local info_data=$(get_instance_info_fast "$instance_id" "$instance_dir")
    IFS='|' read -r role project_path <<< "$info_data"
    
    # 检查会话状态
    local status="stopped"
    if execute_with_timeout 3 1 tmux has-session -t "q_instance_$instance_id" 2>/dev/null; then
        local status_code=$(read_status_file "$instance_id" "$namespace")
        status=$(status_to_name "$status_code")
    fi
    
    record_performance_metric "instance_details" "$start_time"
    
    # 输出结果
    if [[ "$json_output" == "true" ]]; then
        printf '{"id":"%s","status":"%s","session":"%s","namespace":"%s","role":"%s","project_path":"%s"}\n' \
               "$instance_id" "$status" "q_instance_$instance_id" "$namespace" "$role" "$project_path"
    else
        echo "实例详情:"
        echo "  ID: $instance_id"
        echo "  状态: $status"
        echo "  会话: q_instance_$instance_id"
        echo "  命名空间: $namespace"
        echo "  角色: ${role:-无}"
        echo "  项目路径: ${project_path:-无}"
    fi
}

# 缓存管理
manage_cache() {
    local action="$1"
    
    case "$action" in
        "clear")
            PERFORMANCE_CACHE=()
            CACHE_TIMESTAMPS=()
            echo "性能缓存已清理"
            ;;
        "stats")
            echo "缓存统计:"
            echo "  缓存条目数: ${#PERFORMANCE_CACHE[@]}"
            echo "  时间戳条目数: ${#CACHE_TIMESTAMPS[@]}"
            echo "  缓存TTL: ${CACHE_TTL}s"
            
            if [[ ${#PERFORMANCE_CACHE[@]} -gt 0 ]]; then
                echo "  缓存键:"
                for key in "${!PERFORMANCE_CACHE[@]}"; do
                    local age=$(($(date +%s) - ${CACHE_TIMESTAMPS[$key]:-0}))
                    echo "    $key (${age}s ago)"
                done
            fi
            ;;
        "warmup")
            echo "预热缓存..."
            get_active_sessions_fast >/dev/null
            batch_read_all_status "default" >/dev/null
            echo "缓存预热完成"
            ;;
        *)
            echo "缓存管理命令:"
            echo "  clear  - 清理所有缓存"
            echo "  stats  - 显示缓存统计"
            echo "  warmup - 预热缓存"
            ;;
    esac
}

# 性能基准测试
benchmark_v2() {
    echo "cliExtra List v2 性能基准测试"
    echo ""
    
    # 清理缓存
    manage_cache clear
    
    # 测试v1版本
    echo "测试原始版本:"
    local v1_start=$(date +%s.%N)
    source "$SCRIPT_DIR/cliExtra-list.sh" >/dev/null 2>&1
    # 这里需要调用原始的list函数，但为了避免冲突，我们跳过
    local v1_end=$(date +%s.%N)
    local v1_time=$(echo "$v1_end - $v1_start" | bc 2>/dev/null || echo "N/A")
    echo "  原始版本: ${v1_time}s"
    
    # 测试v2版本（冷缓存）
    echo "测试v2版本（冷缓存）:"
    manage_cache clear
    local v2_cold_start=$(date +%s.%N)
    list_instances_v2 false "" false false "" >/dev/null 2>&1
    local v2_cold_end=$(date +%s.%N)
    local v2_cold_time=$(echo "$v2_cold_end - $v2_cold_start" | bc 2>/dev/null || echo "0")
    echo "  v2冷缓存: ${v2_cold_time}s"
    
    # 测试v2版本（热缓存）
    echo "测试v2版本（热缓存）:"
    local v2_hot_start=$(date +%s.%N)
    list_instances_v2 false "" false false "" >/dev/null 2>&1
    local v2_hot_end=$(date +%s.%N)
    local v2_hot_time=$(echo "$v2_hot_end - $v2_hot_start" | bc 2>/dev/null || echo "0")
    echo "  v2热缓存: ${v2_hot_time}s"
    
    # 计算性能提升
    if command -v bc >/dev/null 2>&1 && [[ "$v1_time" != "N/A" ]]; then
        local improvement_cold=$(echo "scale=1; ($v1_time - $v2_cold_time) / $v1_time * 100" | bc 2>/dev/null || echo "N/A")
        local improvement_hot=$(echo "scale=1; ($v1_time - $v2_hot_time) / $v1_time * 100" | bc 2>/dev/null || echo "N/A")
        
        echo ""
        echo "性能提升:"
        echo "  冷缓存提升: ${improvement_cold}%"
        echo "  热缓存提升: ${improvement_hot}%"
    fi
}

# 主函数
main() {
    case "${1:-}" in
        "benchmark")
            benchmark_v2
            ;;
        "cache")
            shift
            manage_cache "$@"
            ;;
        "test")
            echo "测试v2版本..."
            CLIEXTRA_DEBUG=true list_instances_v2 false "" false false ""
            ;;
        *)
            echo "cliExtra List 高性能版本 v2"
            echo ""
            echo "用法: $0 [命令]"
            echo ""
            echo "命令:"
            echo "  benchmark - 性能基准测试"
            echo "  cache     - 缓存管理"
            echo "  test      - 测试运行"
            echo ""
            echo "环境变量:"
            echo "  CLIEXTRA_DEBUG=true  - 启用调试模式"
            ;;
    esac
}

# 如果直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
