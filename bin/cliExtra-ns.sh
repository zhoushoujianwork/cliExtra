#!/bin/bash

# cliExtra namespace管理脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra ns <command> [options]"
    echo ""
    echo "命令:"
    echo "  show [namespace]     显示所有namespace或指定namespace的详情"
    echo "  create <namespace>   创建新的namespace"
    echo "  delete <namespace>   删除namespace (需要--force如果有实例)"
    echo "  list                 列出所有namespace"
    echo ""
    echo "选项:"
    echo "  --force             强制删除namespace（即使有实例）"
    echo "  -o, --output <format>  输出格式：table（默认）或 json"
    echo ""
    echo "示例:"
    echo "  cliExtra ns show                    # 显示所有namespace"
    echo "  cliExtra ns show frontend           # 显示frontend namespace详情"
    echo "  cliExtra ns create frontend         # 创建frontend namespace"
    echo "  cliExtra ns delete frontend         # 删除frontend namespace"
    echo "  cliExtra ns delete frontend --force # 强制删除frontend namespace"
}

# 创建namespace
create_namespace() {
    local ns_name="$1"
    
    if [[ -z "$ns_name" ]]; then
        echo "错误: 请指定namespace名称"
        return 1
    fi
    
    # 验证namespace名称
    if ! validate_namespace_name "$ns_name"; then
        echo "错误: namespace名称只能包含字母、数字、下划线和连字符"
        return 1
    fi
    
    # 检查是否为保留名称
    if is_reserved_namespace "$ns_name"; then
        echo "错误: '$ns_name' 是保留名称，不能用作namespace"
        return 1
    fi
    
    local ns_file="$(get_ns_config_file "$ns_name")"
    local ns_dir="$(get_namespace_dir "$ns_name")"
    
    if namespace_exists "$ns_name"; then
        echo "namespace '$ns_name' 已存在"
        return 1
    fi
    
    echo "正在创建namespace '$ns_name'..."
    
    # 创建namespace目录结构
    local dirs_to_create=(
        "$ns_dir"
        "$ns_dir/$CLIEXTRA_INSTANCES_SUBDIR"
        "$ns_dir/$CLIEXTRA_LOGS_SUBDIR"
        "$ns_dir/$CLIEXTRA_CONVERSATIONS_SUBDIR"
    )
    
    for dir in "${dirs_to_create[@]}"; do
        if safe_mkdir "$dir"; then
            echo "✓ 创建目录: $dir"
        else
            echo "❌ 创建目录失败: $dir"
            return 1
        fi
    done
    
    # 确保配置目录存在
    safe_mkdir "$(get_ns_config_dir)"
    
    # 创建namespace配置文件
    cat > "$ns_file" << EOF
# Namespace配置文件
NAMESPACE_NAME="$ns_name"
CREATED_AT="$(date)"
DESCRIPTION=""
EOF
    
    if [[ $? -eq 0 ]]; then
        echo "✓ 创建配置文件: $ns_file"
    else
        echo "❌ 创建配置文件失败: $ns_file"
        return 1
    fi
    
    # 创建namespace缓存文件
    local cache_file="$ns_dir/namespace_cache.json"
    cat > "$cache_file" << EOF
{
  "namespace": "$ns_name",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "instances": [],
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    if [[ $? -eq 0 ]]; then
        echo "✓ 创建缓存文件: $cache_file"
    fi
    
    echo ""
    echo "✓ namespace '$ns_name' 创建成功"
    echo ""
    echo "创建摘要:"
    echo "  - Namespace: $ns_name"
    echo "  - 目录位置: $ns_dir"
    echo "  - 配置文件: $ns_file"
    echo "  - 子目录: instances, logs, conversations"
}

# 删除namespace
delete_namespace() {
    local ns_name="$1"
    local force_delete="$2"
    
    if [[ -z "$ns_name" ]]; then
        echo "错误: 请指定namespace名称"
        return 1
    fi
    
    # 检查是否为默认namespace
    if [[ "$ns_name" == "$CLIEXTRA_DEFAULT_NS" ]]; then
        echo "错误: 不能删除默认namespace '$CLIEXTRA_DEFAULT_NS'"
        return 1
    fi
    
    local ns_file="$(get_ns_config_file "$ns_name")"
    local ns_dir="$(get_namespace_dir "$ns_name")"
    
    if ! namespace_exists "$ns_name"; then
        echo "错误: namespace '$ns_name' 不存在"
        return 1
    fi
    
    # 检查是否有实例在使用此namespace
    local instances_in_ns=$(get_instances_in_namespace "$ns_name")
    local instance_count=$(echo "$instances_in_ns" | wc -w)
    
    if [[ $instance_count -gt 0 && "$force_delete" != "--force" ]]; then
        echo "错误: namespace '$ns_name' 中还有 $instance_count 个实例"
        echo "实例列表: $instances_in_ns"
        echo "使用 --force 参数强制删除"
        return 1
    fi
    
    # 如果强制删除，先停止所有实例
    if [[ "$force_delete" == "--force" && $instance_count -gt 0 ]]; then
        echo "强制删除模式: 正在停止namespace中的所有实例..."
        for instance_id in $instances_in_ns; do
            echo "停止实例: $instance_id"
            "$SCRIPT_DIR/cliExtra-stop.sh" "$instance_id" 2>/dev/null || true
        done
        
        # 等待实例完全停止
        sleep 2
    fi
    
    echo "正在删除namespace '$ns_name'..."
    
    # 删除namespace配置文件
    if [[ -f "$ns_file" ]]; then
        if safe_remove "$ns_file"; then
            echo "✓ 删除配置文件: $ns_file"
        else
            echo "❌ 删除配置文件失败: $ns_file"
        fi
    fi
    
    # 删除namespace目录及其所有内容
    if [[ -d "$ns_dir" ]]; then
        echo "正在删除namespace目录: $ns_dir"
        
        # 显示将要删除的内容
        if [[ "$force_delete" == "--force" ]]; then
            echo "删除的内容包括:"
            echo "  - 实例目录: $ns_dir/$CLIEXTRA_INSTANCES_SUBDIR"
            echo "  - 日志目录: $ns_dir/$CLIEXTRA_LOGS_SUBDIR"
            echo "  - 对话目录: $ns_dir/$CLIEXTRA_CONVERSATIONS_SUBDIR"
            echo "  - 缓存文件: $ns_dir/namespace_cache.json"
        fi
        
        # 删除整个namespace目录
        if safe_remove "$ns_dir"; then
            echo "✓ 删除namespace目录: $ns_dir"
        else
            echo "❌ 删除namespace目录失败: $ns_dir"
            return 1
        fi
    fi
    
    # 清理可能存在的旧结构（向后兼容）
    local old_ns_dirs=(
        "$HOME/.cliExtra/namespaces/$ns_name"
        "$(pwd)/.cliExtra/namespaces/$ns_name"
    )
    
    for old_dir in "${old_ns_dirs[@]}"; do
        if [[ -d "$old_dir" ]]; then
            echo "清理旧结构目录: $old_dir"
            safe_remove "$old_dir" 2>/dev/null || true
        fi
    done
    
    echo "✓ namespace '$ns_name' 完全删除成功"
    
    # 显示删除摘要
    echo ""
    echo "删除摘要:"
    echo "  - Namespace: $ns_name"
    echo "  - 停止的实例: $instance_count"
    echo "  - 删除的目录: $ns_dir"
    echo "  - 删除的配置: $ns_file"
}

# 获取指定namespace中的实例
get_instances_in_namespace() {
    local ns_name="$1"
    local instances=""
    
    # 方法1: 从namespace目录结构中直接获取实例
    local ns_dir="$(get_namespace_dir "$ns_name")"
    local instances_dir="$ns_dir/$CLIEXTRA_INSTANCES_SUBDIR"
    
    if [[ -d "$instances_dir" ]]; then
        for instance_dir in "$instances_dir"/instance_*; do
            if [[ -d "$instance_dir" ]]; then
                local instance_id=$(basename "$instance_dir" | sed 's/^instance_//')
                # 检查tmux会话是否存在
                if tmux has-session -t "q_instance_$instance_id" 2>/dev/null; then
                    instances="$instances $instance_id"
                fi
            fi
        done
    fi
    
    # 方法2: 遍历所有tmux会话，查找属于指定namespace的实例（向后兼容）
    while IFS= read -r session_line; do
        if [[ "$session_line" == q_instance_* ]]; then
            local session_info=$(echo "$session_line" | cut -d: -f1)
            local instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            
            # 检查实例的namespace
            local instance_ns=$(get_instance_namespace "$instance_id")
            if [[ "$instance_ns" == "$ns_name" ]]; then
                # 检查是否已经在列表中
                if [[ ! " $instances " =~ " $instance_id " ]]; then
                    instances="$instances $instance_id"
                fi
            fi
        fi
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null || true)
    
    # 清理并输出结果
    echo "$instances" | xargs
}

# 获取实例的namespace
get_instance_namespace() {
    local instance_id="$1"
    
    # 方法1: 从新的namespace目录结构中查找
    if [[ -d "$CLIEXTRA_NAMESPACES_DIR" ]]; then
        for ns_dir in "$CLIEXTRA_NAMESPACES_DIR"/*; do
            if [[ -d "$ns_dir" ]]; then
                local ns_name=$(basename "$ns_dir")
                local instance_dir="$ns_dir/$CLIEXTRA_INSTANCES_SUBDIR/instance_$instance_id"
                if [[ -d "$instance_dir" ]]; then
                    echo "$ns_name"
                    return 0
                fi
            fi
        done
    fi
    
    # 方法2: 从项目目录中查找（向后兼容）
    local project_dir=$(find_instance_project "$instance_id")
    if [[ $? -eq 0 ]]; then
        local instance_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
        local ns_file="$instance_dir/namespace"
        
        if [[ -f "$ns_file" ]]; then
            cat "$ns_file"
            return 0
        fi
    fi
    
    # 默认返回default namespace
    echo "default"
}

# 获取所有存在的namespace
get_all_namespaces() {
    local namespaces=()
    local ns_config_dir="$(get_ns_config_dir)"
    
    # 从配置文件中获取namespace
    if [[ -d "$ns_config_dir" ]]; then
        for ns_file in "$ns_config_dir"/*.conf; do
            if [[ -f "$ns_file" ]]; then
                local ns_name=$(basename "$ns_file" .conf)
                namespaces+=("$ns_name")
            fi
        done
    fi
    
    # 从namespace目录中获取namespace
    if [[ -d "$CLIEXTRA_NAMESPACES_DIR" ]]; then
        for ns_dir in "$CLIEXTRA_NAMESPACES_DIR"/*; do
            if [[ -d "$ns_dir" ]]; then
                local ns_name=$(basename "$ns_dir")
                # 检查是否已经在列表中
                local found=false
                for existing_ns in "${namespaces[@]}"; do
                    if [[ "$existing_ns" == "$ns_name" ]]; then
                        found=true
                        break
                    fi
                done
                if [[ "$found" == false ]]; then
                    namespaces+=("$ns_name")
                fi
            fi
        done
    fi
    
    # 确保default namespace总是存在
    local has_default=false
    for ns in "${namespaces[@]}"; do
        if [[ "$ns" == "default" ]]; then
            has_default=true
            break
        fi
    done
    if [[ "$has_default" == false ]]; then
        namespaces+=("default")
    fi
    
    # 排序并输出
    printf '%s\n' "${namespaces[@]}" | sort
}

# 显示所有namespace
show_all_namespaces() {
    local json_output="$1"
    local namespaces=($(get_all_namespaces))
    
    if [[ "$json_output" == "--json" ]]; then
        echo "{"
        echo "  \"namespaces\": ["
        
        local first=true
        for ns_name in "${namespaces[@]}"; do
            local instances_in_ns=$(get_instances_in_namespace "$ns_name")
            local instance_count=0
            local instances_array=""
            
            # 正确计算实例数量和构建数组
            if [[ -n "$instances_in_ns" && "$instances_in_ns" != " " ]]; then
                # 移除前后空格并分割
                instances_in_ns=$(echo "$instances_in_ns" | xargs)
                if [[ -n "$instances_in_ns" ]]; then
                    instance_count=$(echo "$instances_in_ns" | wc -w)
                    # 构建JSON数组 - 修复格式
                    instances_array=""
                    local first_instance=true
                    for instance in $instances_in_ns; do
                        if [[ "$first_instance" == true ]]; then
                            first_instance=false
                            instances_array="\"$instance\""
                        else
                            instances_array="$instances_array, \"$instance\""
                        fi
                    done
                fi
            fi
            
            if [[ "$first" == true ]]; then
                first=false
            else
                echo ","
            fi
            
            echo -n "    {"
            echo -n "\"name\": \"$ns_name\", "
            echo -n "\"instance_count\": $instance_count, "
            echo -n "\"instances\": [$instances_array]"
            echo -n "}"
        done
        
        echo ""
        echo "  ]"
        echo "}"
    else
        echo "=== Namespaces ==="
        printf "%-15s %-10s %s\n" "NAME" "INSTANCES" "INSTANCE_IDS"
        printf "%-15s %-10s %s\n" "----" "---------" "------------"
        
        for ns_name in "${namespaces[@]}"; do
            local instances_in_ns=$(get_instances_in_namespace "$ns_name")
            local instance_count=0
            
            # 正确计算实例数量
            if [[ -n "$instances_in_ns" && "$instances_in_ns" != " " ]]; then
                instances_in_ns=$(echo "$instances_in_ns" | xargs)
                if [[ -n "$instances_in_ns" ]]; then
                    instance_count=$(echo "$instances_in_ns" | wc -w)
                fi
            fi
            
            printf "%-15s %-10s %s\n" "$ns_name" "$instance_count" "$instances_in_ns"
        done
    fi
}

# 显示指定namespace详情
show_namespace_details() {
    local ns_name="$1"
    local json_output="$2"
    
    local ns_config_dir="$(get_ns_config_dir)"
    local ns_file="$(get_ns_config_file "$ns_name")"
    
    if [[ "$ns_name" != "default" && ! -f "$ns_file" ]]; then
        echo "错误: namespace '$ns_name' 不存在"
        return 1
    fi
    
    local instances_in_ns=$(get_instances_in_namespace "$ns_name")
    local instance_count=$(echo "$instances_in_ns" | wc -w)
    
    if [[ "$json_output" == "--json" ]]; then
        echo "{"
        echo "  \"namespace\": {"
        echo "    \"name\": \"$ns_name\","
        echo "    \"instance_count\": $instance_count,"
        echo "    \"instances\": ["
        
        local first=true
        for instance_id in $instances_in_ns; do
            if [[ "$first" == true ]]; then
                first=false
            else
                echo ","
            fi
            echo -n "      \"$instance_id\""
        done
        
        echo ""
        echo "    ]"
        echo "  }"
        echo "}"
    else
        echo "=== Namespace: $ns_name ==="
        echo "实例数量: $instance_count"
        echo "实例列表:"
        
        if [[ $instance_count -gt 0 ]]; then
            for instance_id in $instances_in_ns; do
                local session_name="q_instance_$instance_id"
                local status="Not Running"
                
                if tmux has-session -t "$session_name" 2>/dev/null; then
                    local client_count=$(tmux list-clients -t "$session_name" 2>/dev/null | wc -l)
                    if [[ $client_count -gt 0 ]]; then
                        status="Attached"
                    else
                        status="Detached"
                    fi
                fi
                
                echo "  - $instance_id ($status)"
            done
        else
            echo "  (无实例)"
        fi
    fi
}

# 解析参数
parse_ns_args() {
    local command=""
    local target=""
    local output_format="table"
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            show|list|create|delete)
                command="$1"
                shift
                ;;
            -o|--output)
                output_format="$2"
                shift 2
                ;;
            --json)
                # 向后兼容
                output_format="json"
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                if [[ -z "$target" ]]; then
                    target="$1"
                fi
                shift
                ;;
        esac
    done
    
    echo "$command|$target|$output_format|$force"
}

# 主逻辑
args_result=$(parse_ns_args "$@")
IFS='|' read -r command target output_format force <<< "$args_result"

case "$command" in
    "show"|"list")
        if [[ -n "$target" ]]; then
            # 显示指定namespace
            if [[ "$output_format" == "json" ]]; then
                show_namespace_details "$target" "--json"
            else
                show_namespace_details "$target"
            fi
        else
            # 显示所有namespace
            if [[ "$output_format" == "json" ]]; then
                show_all_namespaces "--json"
            else
                show_all_namespaces
            fi
        fi
        ;;
    "create")
        create_namespace "$target"
        ;;
    "delete")
        if [[ "$force" == "true" ]]; then
            delete_namespace "$target" "--force"
        else
            delete_namespace "$target"
        fi
        ;;
    "help"|"")
        show_help
        ;;
    *)
        echo "未知命令: $command"
        show_help
        ;;
esac
