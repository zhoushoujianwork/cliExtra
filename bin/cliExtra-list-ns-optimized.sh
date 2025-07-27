#!/bin/bash

# cliExtra 优化namespace过滤的实例列表脚本
# 专门优化namespace过滤性能，避免不必要的目录扫描

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"
source "$SCRIPT_DIR/cliExtra-namespace-filter.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra list [instance_id] [options]"
    echo ""
    echo "参数:"
    echo "  instance_id   显示指定实例的详细信息"
    echo ""
    echo "选项:"
    echo "  -o, --output <format>     输出格式：table（默认）或 json"
    echo "  -n, --namespace <n>       只显示指定 namespace 中的实例 (优化版)"
    echo "  --names-only              只输出实例名称（便于脚本解析）"
    echo "  -A, --all                 显示所有 namespace 中的实例"
    echo ""
    echo "性能优化特性:"
    echo "  ✅ 智能namespace过滤 - 只扫描目标namespace目录"
    echo "  ✅ 批量状态读取 - 减少文件I/O操作"
    echo "  ✅ tmux会话缓存 - 避免重复调用tmux命令"
    echo "  ✅ 并行处理 - 多namespace并行获取数据"
    echo ""
    echo "示例:"
    echo "  cliExtra list                         # 只显示 default namespace (快速)"
    echo "  cliExtra list -n frontend             # 只显示 frontend namespace (优化)"
    echo "  cliExtra list -A                      # 显示所有 namespace (并行处理)"
    echo "  cliExtra list -n backend -o json      # JSON格式显示backend namespace"
}

# 解析参数
JSON_OUTPUT=false
TARGET_INSTANCE=""
FILTER_NAMESPACE=""
NAMES_ONLY=false
SHOW_ALL_NAMESPACES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            if [[ -z "$2" ]]; then
                echo "错误: -o|--output 参数需要指定输出格式"
                echo ""
                show_help
                exit 1
            fi
            if [[ "$2" != "table" && "$2" != "json" ]]; then
                echo "错误: 输出格式只能是 table 或 json"
                echo ""
                show_help
                exit 1
            fi
            JSON_OUTPUT=true
            shift 2
            ;;
        -n|--namespace)
            if [[ -z "$2" ]]; then
                echo "错误: -n|--namespace 参数需要指定 namespace 名称"
                echo ""
                show_help
                exit 1
            fi
            FILTER_NAMESPACE="$2"
            shift 2
            ;;
        -A|--all)
            SHOW_ALL_NAMESPACES=true
            shift
            ;;
        --names-only)
            NAMES_ONLY=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "错误: 未知选项 '$1'"
            echo ""
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$TARGET_INSTANCE" ]]; then
                TARGET_INSTANCE="$1"
            else
                echo "错误: 多余的参数 '$1'"
                echo ""
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# 优化的实例详情获取
get_instance_details_optimized() {
    local instance_id="$1"
    
    # 快速查找实例
    local instance_dir=$(find_instance_info_dir "$instance_id")
    if [[ $? -ne 0 || -z "$instance_dir" ]]; then
        echo "错误: 找不到实例 $instance_id" >&2
        return 1
    fi
    
    # 从路径提取namespace
    local namespace=$(echo "$instance_dir" | sed -E 's|.*/namespaces/([^/]+)/instances/.*|\1|')
    
    # 获取基本信息
    local project_dir=""
    local role=""
    
    if [[ -f "$instance_dir/project_path" ]]; then
        project_dir=$(cat "$instance_dir/project_path" 2>/dev/null)
    fi
    
    if [[ -f "$instance_dir/info" ]]; then
        role=$(grep "^ROLE=" "$instance_dir/info" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
    fi
    
    # 检查会话状态
    local status="stopped"
    local session_name="q_instance_$instance_id"
    
    if timeout 3 tmux has-session -t "$session_name" 2>/dev/null; then
        local status_code=$(read_status_file "$instance_id" "$namespace")
        case "$status_code" in
            "0") status="idle" ;;
            "1") status="busy" ;;
            *) status="idle" ;;
        esac
    fi
    
    # 输出结果
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        printf '{"id":"%s","status":"%s","session":"%s","namespace":"%s","role":"%s","project_path":"%s"}\n' \
               "$instance_id" "$status" "$session_name" "$namespace" "$role" "$project_dir"
    else
        echo "=== 实例详细信息 ==="
        echo "实例ID: $instance_id"
        echo "状态: $status"
        echo "会话名称: $session_name"
        echo "命名空间: $namespace"
        echo "角色: ${role:-无}"
        echo "项目路径: ${project_dir:-无}"
    fi
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
        printf "%-30s %-15s %-15s %-15s %-15s\n" \
               "$instance_id" "$namespace" "$status" "$session_name" "${role:-}"
    done
}

# 优化的名称输出
output_names_optimized() {
    local instance_data=("$@")
    
    for data in "${instance_data[@]}"; do
        if [[ -z "$data" ]]; then
            continue
        fi
        
        IFS=':' read -r instance_id _ _ _ _ <<< "$data"
        echo "$instance_id"
    done
}

# 主要的优化list函数
list_instances_optimized() {
    local start_time=$(date +%s.%N)
    
    # 如果指定了特定实例，直接获取详情
    if [[ -n "$TARGET_INSTANCE" ]]; then
        get_instance_details_optimized "$TARGET_INSTANCE"
        return $?
    fi
    
    # 使用优化的namespace过滤器获取实例
    local instances_data
    instances_data=$(get_instances_with_namespace_filter "$FILTER_NAMESPACE" "$SHOW_ALL_NAMESPACES")
    
    if [[ -z "$instances_data" ]]; then
        if [[ "$JSON_OUTPUT" == "true" ]]; then
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
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        output_json_optimized "${instance_array[@]}"
    elif [[ "$NAMES_ONLY" == "true" ]]; then
        output_names_optimized "${instance_array[@]}"
    else
        output_table_optimized "${instance_array[@]}"
    fi
    
    # 性能报告
    if [[ "${CLIEXTRA_DEBUG:-false}" == "true" ]]; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
        echo "执行时间: ${duration}s (优化版)" >&2
        echo "实例数量: ${#instance_array[@]}" >&2
        
        if [[ -n "$FILTER_NAMESPACE" ]]; then
            echo "过滤namespace: $FILTER_NAMESPACE" >&2
        elif [[ "$SHOW_ALL_NAMESPACES" == "true" ]]; then
            echo "显示模式: 所有namespace" >&2
        else
            echo "显示模式: 默认namespace" >&2
        fi
    fi
}

# 性能基准测试
benchmark_optimized_list() {
    echo "优化版list命令性能基准测试"
    echo ""
    
    # 测试不同的namespace过滤场景
    local test_cases=(
        "default:false:默认namespace"
        "frontend:false:指定namespace"
        ":true:所有namespace"
    )
    
    for test_case in "${test_cases[@]}"; do
        IFS=':' read -r filter_ns show_all description <<< "$test_case"
        
        echo "测试场景: $description"
        
        # 清理缓存
        cleanup_namespace_cache
        
        # 冷缓存测试
        echo -n "  冷缓存: "
        local start_time=$(date +%s.%N)
        
        FILTER_NAMESPACE="$filter_ns"
        SHOW_ALL_NAMESPACES="$show_all"
        JSON_OUTPUT=false
        NAMES_ONLY=false
        TARGET_INSTANCE=""
        
        list_instances_optimized >/dev/null 2>&1
        
        local end_time=$(date +%s.%N)
        local cold_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
        echo "${cold_time}s"
        
        # 热缓存测试
        echo -n "  热缓存: "
        start_time=$(date +%s.%N)
        list_instances_optimized >/dev/null 2>&1
        end_time=$(date +%s.%N)
        local hot_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
        echo "${hot_time}s"
        
        # 计算缓存效果
        if command -v bc >/dev/null 2>&1 && [[ "$cold_time" != "N/A" && "$hot_time" != "N/A" ]]; then
            local cache_improvement=$(echo "scale=1; ($cold_time - $hot_time) / $cold_time * 100" | bc 2>/dev/null || echo "N/A")
            echo "  缓存提升: ${cache_improvement}%"
        fi
        
        echo ""
    done
}

# 验证优化效果
validate_optimization() {
    echo "验证namespace过滤优化效果..."
    echo ""
    
    # 获取可用的namespace
    local available_namespaces=($(get_available_namespaces))
    echo "可用namespace: ${available_namespaces[*]}"
    echo ""
    
    # 测试每个namespace的过滤
    for namespace in "${available_namespaces[@]}"; do
        echo "验证namespace: $namespace"
        
        # 使用优化版本获取结果
        local optimized_result=$(get_instances_with_namespace_filter "$namespace" false)
        local optimized_count=$(echo "$optimized_result" | grep -c "^" 2>/dev/null || echo "0")
        
        echo "  优化版本找到: $optimized_count 个实例"
        
        # 验证所有实例都属于正确的namespace
        local validation_passed=true
        while IFS=':' read -r instance_id status session_name ns role; do
            if [[ -n "$instance_id" && "$ns" != "$namespace" ]]; then
                echo "  ❌ 错误: 实例 $instance_id 属于 $ns，不是 $namespace"
                validation_passed=false
            fi
        done <<< "$optimized_result"
        
        if [[ "$validation_passed" == "true" ]]; then
            echo "  ✅ 过滤结果正确"
        fi
        
        echo ""
    done
}

# 主函数
main() {
    case "${1:-list}" in
        "list")
            shift
            # 重新解析参数
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -o|--output)
                        JSON_OUTPUT=true
                        shift 2
                        ;;
                    -n|--namespace)
                        FILTER_NAMESPACE="$2"
                        shift 2
                        ;;
                    -A|--all)
                        SHOW_ALL_NAMESPACES=true
                        shift
                        ;;
                    --names-only)
                        NAMES_ONLY=true
                        shift
                        ;;
                    *)
                        TARGET_INSTANCE="$1"
                        shift
                        ;;
                esac
            done
            list_instances_optimized
            ;;
        "benchmark")
            benchmark_optimized_list
            ;;
        "validate")
            validate_optimization
            ;;
        "help")
            show_help
            ;;
        *)
            echo "cliExtra 优化namespace过滤的实例列表脚本"
            echo ""
            echo "用法: $0 [命令]"
            echo ""
            echo "命令:"
            echo "  list [选项]    - 列出实例 (默认)"
            echo "  benchmark      - 性能基准测试"
            echo "  validate       - 验证优化效果"
            echo "  help           - 显示帮助"
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
