#!/bin/bash

# cliExtra 轻量级namespace过滤优化
# 专注于核心优化，减少不必要的开销

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"

# 轻量级namespace检查
namespace_exists_fast() {
    local namespace="$1"
    [[ -d "$CLIEXTRA_HOME/namespaces/$namespace/instances" ]]
}

# 直接获取指定namespace的实例（避免全量扫描）
get_single_namespace_instances() {
    local namespace="$1"
    
    local ns_dir="$CLIEXTRA_HOME/namespaces/$namespace"
    local instances_dir="$ns_dir/instances"
    
    if [[ ! -d "$instances_dir" ]]; then
        return 0
    fi
    
    # 批量获取tmux会话（一次性调用）
    local active_sessions=""
    if active_sessions=$(timeout 3 tmux list-sessions -F "#{session_name}" 2>/dev/null); then
        active_sessions=$(echo "$active_sessions" | grep "^q_instance_" | sed 's/q_instance_//' | sort)
    fi
    
    # 批量读取状态文件
    local status_dir="$ns_dir/status"
    local status_data=""
    
    if [[ -d "$status_dir" ]]; then
        # 使用简单的批量读取
        for status_file in "$status_dir"/*.status; do
            if [[ -f "$status_file" ]]; then
                local instance_id=$(basename "$status_file" .status)
                local status_value=$(cat "$status_file" 2>/dev/null || echo "0")
                status_data="$status_data$instance_id:$status_value "
            fi
        done
    fi
    
    # 处理实例目录
    for instance_dir in "$instances_dir"/instance_*; do
        if [[ -d "$instance_dir" ]]; then
            local instance_id=$(basename "$instance_dir" | sed 's/instance_//')
            
            if [[ -z "$instance_id" ]]; then
                continue
            fi
            
            # 检查会话状态
            local status="stopped"
            if echo "$active_sessions" | grep -q "^${instance_id}$"; then
                # 从状态数据中获取状态
                local status_code="0"
                if [[ "$status_data" == *"$instance_id:"* ]]; then
                    status_code=$(echo "$status_data" | grep -o "${instance_id}:[01]" | cut -d: -f2)
                fi
                
                case "$status_code" in
                    "0") status="idle" ;;
                    "1") status="busy" ;;
                    *) status="idle" ;;
                esac
            fi
            
            # 获取角色信息（可选）
            local role=""
            if [[ -f "$instance_dir/info" ]]; then
                role=$(grep "^ROLE=" "$instance_dir/info" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
            fi
            
            echo "$instance_id:$status:q_instance_$instance_id:$namespace:$role"
        fi
    done
}

# 优化的多namespace获取
get_multiple_namespaces_instances() {
    local namespaces=("$@")
    
    # 批量获取tmux会话（全局一次性调用）
    local active_sessions=""
    if active_sessions=$(timeout 5 tmux list-sessions -F "#{session_name}" 2>/dev/null); then
        active_sessions=$(echo "$active_sessions" | grep "^q_instance_" | sed 's/q_instance_//' | sort)
    fi
    
    # 处理每个namespace
    for namespace in "${namespaces[@]}"; do
        local ns_dir="$CLIEXTRA_HOME/namespaces/$namespace"
        local instances_dir="$ns_dir/instances"
        
        if [[ ! -d "$instances_dir" ]]; then
            continue
        fi
        
        # 批量读取该namespace的状态文件
        local status_dir="$ns_dir/status"
        local status_data=""
        
        if [[ -d "$status_dir" ]]; then
            for status_file in "$status_dir"/*.status; do
                if [[ -f "$status_file" ]]; then
                    local instance_id=$(basename "$status_file" .status)
                    local status_value=$(cat "$status_file" 2>/dev/null || echo "0")
                    status_data="$status_data$instance_id:$status_value "
                fi
            done
        fi
        
        # 处理实例
        for instance_dir in "$instances_dir"/instance_*; do
            if [[ -d "$instance_dir" ]]; then
                local instance_id=$(basename "$instance_dir" | sed 's/instance_//')
                
                if [[ -z "$instance_id" ]]; then
                    continue
                fi
                
                # 检查会话状态
                local status="stopped"
                if echo "$active_sessions" | grep -q "^${instance_id}$"; then
                    local status_code="0"
                    if [[ "$status_data" == *"$instance_id:"* ]]; then
                        status_code=$(echo "$status_data" | grep -o "${instance_id}:[01]" | cut -d: -f2)
                    fi
                    
                    case "$status_code" in
                        "0") status="idle" ;;
                        "1") status="busy" ;;
                        *) status="idle" ;;
                    esac
                fi
                
                # 获取角色信息
                local role=""
                if [[ -f "$instance_dir/info" ]]; then
                    role=$(grep "^ROLE=" "$instance_dir/info" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
                fi
                
                echo "$instance_id:$status:q_instance_$instance_id:$namespace:$role"
            fi
        done
    done
}

# 轻量级实例获取主函数
get_instances_lightweight() {
    local filter_namespace="$1"
    local show_all="$2"
    
    if [[ -n "$filter_namespace" ]]; then
        # 指定namespace：直接检查并获取
        if namespace_exists_fast "$filter_namespace"; then
            get_single_namespace_instances "$filter_namespace"
        else
            echo "错误: namespace '$filter_namespace' 不存在或没有实例" >&2
            return 1
        fi
    elif [[ "$show_all" == "true" ]]; then
        # 显示所有：获取所有有效namespace
        local available_namespaces=()
        
        if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
            for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
                if [[ -d "$ns_dir/instances" ]]; then
                    available_namespaces+=($(basename "$ns_dir"))
                fi
            done
        fi
        
        if [[ ${#available_namespaces[@]} -gt 0 ]]; then
            get_multiple_namespaces_instances "${available_namespaces[@]}"
        fi
    else
        # 默认：只显示default namespace
        if namespace_exists_fast "default"; then
            get_single_namespace_instances "default"
        fi
    fi
}

# 简化的输出函数
output_simple() {
    local format="$1"
    local names_only="$2"
    shift 2
    local instance_data=("$@")
    
    if [[ ${#instance_data[@]} -eq 0 ]]; then
        if [[ "$format" == "json" ]]; then
            echo "[]"
        fi
        return 0
    fi
    
    case "$format" in
        "json")
            echo "["
            local first=true
            for data in "${instance_data[@]}"; do
                if [[ -z "$data" ]]; then continue; fi
                IFS=':' read -r instance_id status session_name namespace role <<< "$data"
                
                if [[ "$first" == "true" ]]; then first=false; else echo ","; fi
                printf '  {"id":"%s","status":"%s","session":"%s","namespace":"%s"' \
                       "$instance_id" "$status" "$session_name" "$namespace"
                if [[ -n "$role" ]]; then printf ',"role":"%s"' "$role"; fi
                printf '}'
            done
            echo ""
            echo "]"
            ;;
        "names")
            for data in "${instance_data[@]}"; do
                if [[ -z "$data" ]]; then continue; fi
                IFS=':' read -r instance_id _ _ _ _ <<< "$data"
                echo "$instance_id"
            done
            ;;
        *)
            if [[ ${#instance_data[@]} -gt 0 ]]; then
                printf "%-30s %-15s %-15s %-15s %-15s\n" "NAME" "NAMESPACE" "STATUS" "SESSION" "ROLE"
                printf "%s\n" "$(printf '%.0s-' {1..90})"
                for data in "${instance_data[@]}"; do
                    if [[ -z "$data" ]]; then continue; fi
                    IFS=':' read -r instance_id status session_name namespace role <<< "$data"
                    printf "%-30s %-15s %-15s %-15s %-15s\n" \
                           "$instance_id" "$namespace" "$status" "$session_name" "${role:-}"
                done
            fi
            ;;
    esac
}

# 主要的轻量级list函数
list_instances_lightweight() {
    local filter_namespace="$1"
    local show_all="$2"
    local json_output="$3"
    local names_only="$4"
    
    local start_time=$(date +%s.%N)
    
    # 获取实例数据
    local instances_data
    instances_data=$(get_instances_lightweight "$filter_namespace" "$show_all")
    
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # 转换为数组
    local instance_array=()
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            instance_array+=("$line")
        fi
    done <<< "$instances_data"
    
    # 确定输出格式
    local output_format="table"
    if [[ "$json_output" == "true" ]]; then
        output_format="json"
    elif [[ "$names_only" == "true" ]]; then
        output_format="names"
    fi
    
    # 输出结果
    output_simple "$output_format" "$names_only" "${instance_array[@]}"
    
    # 性能报告
    if [[ "${CLIEXTRA_DEBUG:-false}" == "true" ]]; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
        echo "执行时间: ${duration}s (轻量级优化)" >&2
        echo "实例数量: ${#instance_array[@]}" >&2
    fi
}

# 性能基准测试
benchmark_lightweight() {
    echo "轻量级namespace过滤性能基准测试"
    echo ""
    
    local test_cases=(
        "default:false:默认namespace"
        "q_cli:false:指定namespace"
        ":true:所有namespace"
    )
    
    for test_case in "${test_cases[@]}"; do
        IFS=':' read -r filter_ns show_all description <<< "$test_case"
        
        echo "测试场景: $description"
        
        # 原始方法（模拟）
        echo -n "  原始方法: "
        local start_time=$(date +%s.%N)
        
        # 模拟原始的全量扫描
        local count=0
        if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
            for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
                if [[ -d "$ns_dir/instances" ]]; then
                    local namespace=$(basename "$ns_dir")
                    
                    # 应用过滤逻辑
                    local should_process=false
                    if [[ -n "$filter_ns" && "$namespace" == "$filter_ns" ]]; then
                        should_process=true
                    elif [[ -z "$filter_ns" && "$show_all" == "true" ]]; then
                        should_process=true
                    elif [[ -z "$filter_ns" && "$show_all" == "false" && "$namespace" == "default" ]]; then
                        should_process=true
                    fi
                    
                    if [[ "$should_process" == "true" ]]; then
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
        
        # 轻量级方法
        echo -n "  轻量级方法: "
        start_time=$(date +%s.%N)
        
        local lightweight_result=$(list_instances_lightweight "$filter_ns" "$show_all" false false 2>/dev/null)
        local lightweight_count=$(echo "$lightweight_result" | grep -c "^" 2>/dev/null || echo "0")
        
        end_time=$(date +%s.%N)
        local lightweight_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
        echo "${lightweight_time}s (找到 $lightweight_count 个实例)"
        
        # 计算性能提升
        if command -v bc >/dev/null 2>&1 && [[ "$original_time" != "N/A" && "$lightweight_time" != "N/A" ]]; then
            local improvement=$(echo "scale=1; ($original_time - $lightweight_time) / $original_time * 100" | bc 2>/dev/null || echo "N/A")
            echo "  性能提升: ${improvement}%"
        fi
        
        echo ""
    done
}

# 主函数
main() {
    case "${1:-}" in
        "test")
            echo "测试轻量级namespace过滤..."
            CLIEXTRA_DEBUG=true list_instances_lightweight "" false false false
            ;;
        "benchmark")
            benchmark_lightweight
            ;;
        "filter")
            list_instances_lightweight "$2" "$3" "$4" "$5"
            ;;
        *)
            echo "cliExtra 轻量级namespace过滤优化"
            echo ""
            echo "用法: $0 <命令> [参数]"
            echo ""
            echo "命令:"
            echo "  test                          - 测试运行"
            echo "  benchmark                     - 性能基准测试"
            echo "  filter <ns> <all> <json> <names> - 过滤实例"
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
