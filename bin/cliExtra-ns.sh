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

# 获取namespace配置目录
get_ns_config_dir() {
    local config_dir="$CLIEXTRA_HOME/namespaces"
    mkdir -p "$config_dir"
    echo "$config_dir"
}

# 创建namespace
create_namespace() {
    local ns_name="$1"
    
    if [[ -z "$ns_name" ]]; then
        echo "错误: 请指定namespace名称"
        return 1
    fi
    
    # 验证namespace名称
    if [[ ! "$ns_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "错误: namespace名称只能包含字母、数字、下划线和连字符"
        return 1
    fi
    
    local ns_config_dir=$(get_ns_config_dir)
    local ns_file="$ns_config_dir/$ns_name.conf"
    
    if [[ -f "$ns_file" ]]; then
        echo "namespace '$ns_name' 已存在"
        return 1
    fi
    
    # 创建namespace配置文件
    cat > "$ns_file" << EOF
# Namespace配置文件
NAMESPACE_NAME="$ns_name"
CREATED_AT="$(date)"
DESCRIPTION=""
EOF
    
    echo "✓ namespace '$ns_name' 创建成功"
}

# 删除namespace
delete_namespace() {
    local ns_name="$1"
    local force_delete="$2"
    
    if [[ -z "$ns_name" ]]; then
        echo "错误: 请指定namespace名称"
        return 1
    fi
    
    local ns_config_dir=$(get_ns_config_dir)
    local ns_file="$ns_config_dir/$ns_name.conf"
    
    if [[ ! -f "$ns_file" ]]; then
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
            "$SCRIPT_DIR/cliExtra-stop.sh" "$instance_id"
        done
    fi
    
    # 删除namespace配置文件
    rm -f "$ns_file"
    echo "✓ namespace '$ns_name' 删除成功"
}

# 获取指定namespace中的实例
get_instances_in_namespace() {
    local ns_name="$1"
    local instances=""
    
    # 遍历所有tmux会话，查找属于指定namespace的实例
    while IFS= read -r session_line; do
        if [[ "$session_line" == q_instance_* ]]; then
            local session_info=$(echo "$session_line" | cut -d: -f1)
            local instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            
            # 检查实例的namespace
            local instance_ns=$(get_instance_namespace "$instance_id")
            if [[ "$instance_ns" == "$ns_name" ]]; then
                instances="$instances $instance_id"
            fi
        fi
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    echo "$instances"
}

# 获取实例的namespace
get_instance_namespace() {
    local instance_id="$1"
    
    # 查找实例的项目目录
    local project_dir=$(find_instance_project "$instance_id")
    if [[ $? -eq 0 ]]; then
        local instance_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
        local ns_file="$instance_dir/namespace"
        
        if [[ -f "$ns_file" ]]; then
            cat "$ns_file"
        else
            echo "default"
        fi
    else
        echo "default"
    fi
}

# 显示所有namespace
show_all_namespaces() {
    local json_output="$1"
    local ns_config_dir=$(get_ns_config_dir)
    
    if [[ "$json_output" == "--json" ]]; then
        echo "{"
        echo "  \"namespaces\": ["
        
        local first=true
        for ns_file in "$ns_config_dir"/*.conf; do
            if [[ -f "$ns_file" ]]; then
                local ns_name=$(basename "$ns_file" .conf)
                local instances_in_ns=$(get_instances_in_namespace "$ns_name")
                local instance_count=$(echo "$instances_in_ns" | wc -w)
                
                if [[ "$first" == true ]]; then
                    first=false
                else
                    echo ","
                fi
                
                echo -n "    {"
                echo -n "\"name\": \"$ns_name\", "
                echo -n "\"instance_count\": $instance_count, "
                echo -n "\"instances\": [$(echo "$instances_in_ns" | sed 's/ /", "/g' | sed 's/^/"/;s/$/"/')]"
                echo -n "}"
            fi
        done
        
        echo ""
        echo "  ]"
        echo "}"
    else
        echo "=== Namespaces ==="
        printf "%-15s %-10s %s\n" "NAME" "INSTANCES" "INSTANCE_IDS"
        printf "%-15s %-10s %s\n" "----" "---------" "------------"
        
        for ns_file in "$ns_config_dir"/*.conf; do
            if [[ -f "$ns_file" ]]; then
                local ns_name=$(basename "$ns_file" .conf)
                local instances_in_ns=$(get_instances_in_namespace "$ns_name")
                local instance_count=$(echo "$instances_in_ns" | wc -w)
                
                printf "%-15s %-10s %s\n" "$ns_name" "$instance_count" "$instances_in_ns"
            fi
        done
        
        # 显示default namespace
        local default_instances=$(get_instances_in_namespace "default")
        local default_count=$(echo "$default_instances" | wc -w)
        printf "%-15s %-10s %s\n" "default" "$default_count" "$default_instances"
    fi
}

# 显示指定namespace详情
show_namespace_details() {
    local ns_name="$1"
    local json_output="$2"
    
    local ns_config_dir=$(get_ns_config_dir)
    local ns_file="$ns_config_dir/$ns_name.conf"
    
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
