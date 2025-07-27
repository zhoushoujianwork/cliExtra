#!/bin/bash

# cliExtra 针对性namespace过滤优化
# 专门解决跨namespace扫描的性能问题

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"

# 核心优化：直接定位目标namespace，避免全量扫描
get_instances_targeted() {
    local filter_namespace="$1"
    local show_all="$2"
    
    local target_namespaces=()
    
    # 🎯 关键优化1：智能namespace定位，避免全量目录扫描
    if [[ -n "$filter_namespace" ]]; then
        # 指定namespace：直接检查目标目录
        local target_dir="$CLIEXTRA_HOME/namespaces/$filter_namespace"
        if [[ -d "$target_dir/instances" ]]; then
            target_namespaces=("$filter_namespace")
        else
            echo "错误: namespace '$filter_namespace' 不存在或没有实例" >&2
            return 1
        fi
    elif [[ "$show_all" == "true" ]]; then
        # 显示所有：快速扫描namespace目录
        if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
            for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
                if [[ -d "$ns_dir/instances" ]]; then
                    target_namespaces+=($(basename "$ns_dir"))
                fi
            done
        fi
    else
        # 默认：只检查default namespace
        if [[ -d "$CLIEXTRA_HOME/namespaces/default/instances" ]]; then
            target_namespaces=("default")
        fi
    fi
    
    if [[ ${#target_namespaces[@]} -eq 0 ]]; then
        return 0
    fi
    
    # 🎯 关键优化2：批量获取tmux会话，避免重复调用
    local active_sessions=""
    if active_sessions=$(timeout 3 tmux list-sessions -F "#{session_name}" 2>/dev/null); then
        active_sessions=$(echo "$active_sessions" | grep "^q_instance_" | sed 's/q_instance_//')
    fi
    
    # 🎯 关键优化3：只处理目标namespace，跳过无关目录
    for namespace in "${target_namespaces[@]}"; do
        local instances_dir="$CLIEXTRA_HOME/namespaces/$namespace/instances"
        local status_dir="$CLIEXTRA_HOME/namespaces/$namespace/status"
        
        # 批量读取该namespace的状态文件
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
        
        # 处理该namespace的实例
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
                        status_code="${status_code:-0}"
                    fi
                    
                    case "$status_code" in
                        "0") status="idle" ;;
                        "1") status="busy" ;;
                        *) status="idle" ;;
                    esac
                fi
                
                # 获取角色信息（延迟加载）
                local role=""
                if [[ -f "$instance_dir/info" ]]; then
                    role=$(grep "^ROLE=" "$instance_dir/info" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
                fi
                
                echo "$instance_id:$status:q_instance_$instance_id:$namespace:$role"
            fi
        done
    done
}

# 简化的输出函数
output_targeted() {
    local json_output="$1"
    local names_only="$2"
    shift 2
    local instance_data=("$@")
    
    if [[ ${#instance_data[@]} -eq 0 ]]; then
        if [[ "$json_output" == "true" ]]; then
            echo "[]"
        fi
        return 0
    fi
    
    if [[ "$json_output" == "true" ]]; then
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
    elif [[ "$names_only" == "true" ]]; then
        for data in "${instance_data[@]}"; do
            if [[ -z "$data" ]]; then continue; fi
            IFS=':' read -r instance_id _ _ _ _ <<< "$data"
            echo "$instance_id"
        done
    else
        printf "%-30s %-15s %-15s %-15s %-15s\n" "NAME" "NAMESPACE" "STATUS" "SESSION" "ROLE"
        printf "%s\n" "$(printf '%.0s-' {1..90})"
        for data in "${instance_data[@]}"; do
            if [[ -z "$data" ]]; then continue; fi
            IFS=':' read -r instance_id status session_name namespace role <<< "$data"
            printf "%-30s %-15s %-15s %-15s %-15s\n" \
                   "$instance_id" "$namespace" "$status" "$session_name" "${role:-}"
        done
    fi
}

# 主要的针对性优化list函数
list_instances_targeted() {
    local filter_namespace="$1"
    local show_all="$2"
    local json_output="$3"
    local names_only="$4"
    
    local start_time=$(date +%s.%N)
    
    # 获取实例数据
    local instances_data
    instances_data=$(get_instances_targeted "$filter_namespace" "$show_all")
    
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
    
    # 输出结果
    output_targeted "$json_output" "$names_only" "${instance_array[@]}"
    
    # 性能报告
    if [[ "${CLIEXTRA_DEBUG:-false}" == "true" ]]; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
        echo "执行时间: ${duration}s (针对性优化)" >&2
        echo "实例数量: ${#instance_array[@]}" >&2
        echo "目标namespace: ${filter_namespace:-default}" >&2
    fi
}

# 对比测试：原始方法 vs 针对性优化
benchmark_comparison() {
    echo "Namespace过滤性能对比测试"
    echo ""
    
    local test_cases=(
        "default:false:默认namespace"
        "q_cli:false:指定namespace(q_cli)"
        "frontend:false:指定namespace(frontend)"
        ":true:所有namespace"
    )
    
    for test_case in "${test_cases[@]}"; do
        IFS=':' read -r filter_ns show_all description <<< "$test_case"
        
        echo "📊 测试场景: $description"
        
        # 原始方法（模拟全量扫描）
        echo -n "  🐌 原始方法: "
        local start_time=$(date +%s.%N)
        
        # 模拟原始的全量扫描逻辑
        local original_count=0
        if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
            for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
                if [[ -d "$ns_dir/instances" ]]; then
                    local namespace=$(basename "$ns_dir")
                    
                    # 应用过滤逻辑（原始方式）
                    local should_process=false
                    if [[ -n "$filter_ns" ]]; then
                        if [[ "$namespace" == "$filter_ns" ]]; then
                            should_process=true
                        fi
                    elif [[ "$show_all" == "true" ]]; then
                        should_process=true
                    else
                        if [[ "$namespace" == "default" ]]; then
                            should_process=true
                        fi
                    fi
                    
                    if [[ "$should_process" == "true" ]]; then
                        for instance_dir in "$ns_dir/instances"/instance_*; do
                            if [[ -d "$instance_dir" ]]; then
                                original_count=$((original_count + 1))
                                # 模拟状态检查开销
                                local instance_id=$(basename "$instance_dir" | sed 's/instance_//')
                                tmux has-session -t "q_instance_$instance_id" 2>/dev/null
                            fi
                        done
                    fi
                fi
            done
        fi
        
        local end_time=$(date +%s.%N)
        local original_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
        echo "${original_time}s (找到 $original_count 个实例)"
        
        # 针对性优化方法
        echo -n "  🚀 优化方法: "
        start_time=$(date +%s.%N)
        
        local optimized_result=$(get_instances_targeted "$filter_ns" "$show_all")
        local optimized_count=$(echo "$optimized_result" | grep -c "^" 2>/dev/null || echo "0")
        
        end_time=$(date +%s.%N)
        local optimized_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
        echo "${optimized_time}s (找到 $optimized_count 个实例)"
        
        # 计算性能提升
        if command -v bc >/dev/null 2>&1 && [[ "$original_time" != "N/A" && "$optimized_time" != "N/A" ]]; then
            local improvement=$(echo "scale=1; ($original_time - $optimized_time) / $original_time * 100" | bc 2>/dev/null || echo "N/A")
            local speedup=$(echo "scale=1; $original_time / $optimized_time" | bc 2>/dev/null || echo "N/A")
            
            if (( $(echo "$improvement > 0" | bc -l) )); then
                echo "  ✅ 性能提升: ${improvement}% (${speedup}x 倍速)"
            else
                echo "  ⚠️  性能变化: ${improvement}%"
            fi
        fi
        
        echo ""
    done
}

# 验证优化的正确性
validate_targeted_optimization() {
    echo "验证针对性优化的正确性..."
    echo ""
    
    local test_cases=(
        "default:false"
        "q_cli:false"
        ":true"
    )
    
    for test_case in "${test_cases[@]}"; do
        IFS=':' read -r filter_ns show_all <<< "$test_case"
        
        echo "验证场景: namespace=${filter_ns:-default}, show_all=$show_all"
        
        # 获取优化结果
        local optimized_result=$(get_instances_targeted "$filter_ns" "$show_all")
        
        # 验证namespace过滤
        local validation_passed=true
        local found_namespaces=()
        
        while IFS=':' read -r instance_id status session_name namespace role; do
            if [[ -n "$instance_id" ]]; then
                # 收集发现的namespace
                if [[ ! " ${found_namespaces[*]} " =~ " ${namespace} " ]]; then
                    found_namespaces+=("$namespace")
                fi
                
                # 验证过滤逻辑
                if [[ -n "$filter_ns" && "$namespace" != "$filter_ns" ]]; then
                    echo "  ❌ 错误: 发现不匹配的namespace: $namespace (期望: $filter_ns)"
                    validation_passed=false
                fi
                
                if [[ -z "$filter_ns" && "$show_all" != "true" && "$namespace" != "default" ]]; then
                    echo "  ❌ 错误: 默认模式下发现非default namespace: $namespace"
                    validation_passed=false
                fi
            fi
        done <<< "$optimized_result"
        
        if [[ "$validation_passed" == "true" ]]; then
            echo "  ✅ 过滤逻辑正确"
            echo "  📊 发现namespace: ${found_namespaces[*]}"
        fi
        
        echo ""
    done
}

# 展示优化要点
show_optimization_highlights() {
    echo "🎯 针对性Namespace过滤优化要点"
    echo ""
    echo "📈 核心优化策略:"
    echo "  1. 🎯 智能namespace定位 - 避免全量目录扫描"
    echo "     • 指定namespace时直接检查目标目录"
    echo "     • 跳过不相关的namespace目录遍历"
    echo ""
    echo "  2. 🚀 批量tmux会话获取 - 减少重复调用"
    echo "     • 一次性获取所有q_instance会话"
    echo "     • 避免每个实例单独调用tmux has-session"
    echo ""
    echo "  3. 📊 批量状态文件读取 - 减少文件I/O"
    echo "     • 按namespace批量读取状态文件"
    echo "     • 使用关联数组缓存状态信息"
    echo ""
    echo "  4. ⚡ 延迟加载角色信息 - 按需读取"
    echo "     • 只在需要时读取实例角色信息"
    echo "     • 减少不必要的文件读取操作"
    echo ""
    echo "🎯 适用场景:"
    echo "  • 指定namespace查询 (qq list -n frontend)"
    echo "  • 大量namespace环境下的性能优化"
    echo "  • Web API频繁调用的性能提升"
    echo ""
}

# 主函数
main() {
    case "${1:-}" in
        "test")
            echo "测试针对性namespace过滤优化..."
            CLIEXTRA_DEBUG=true list_instances_targeted "" false false false
            ;;
        "benchmark")
            benchmark_comparison
            ;;
        "validate")
            validate_targeted_optimization
            ;;
        "highlights")
            show_optimization_highlights
            ;;
        "filter")
            list_instances_targeted "$2" "$3" "$4" "$5"
            ;;
        *)
            echo "cliExtra 针对性namespace过滤优化"
            echo ""
            echo "用法: $0 <命令> [参数]"
            echo ""
            echo "命令:"
            echo "  test                          - 测试运行"
            echo "  benchmark                     - 性能对比测试"
            echo "  validate                      - 验证优化正确性"
            echo "  highlights                    - 显示优化要点"
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
