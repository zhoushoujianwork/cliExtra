#!/bin/bash

# cliExtra 清理脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra clean <instance_id|all> [options]"
    echo ""
    echo "参数:"
    echo "  instance_id       清理指定实例"
    echo "  all              清理所有实例"
    echo ""
    echo "选项:"
    echo "  --namespace <ns>  只清理指定namespace中的实例（仅与all一起使用）"
    echo "  -A, --all-ns      清理所有namespace中的实例（仅与all一起使用）"
    echo "  --dry-run        预览模式，显示将要清理的实例但不实际执行"
    echo ""
    echo "默认行为（仅对 'clean all'）:"
    echo "  默认只清理 'default' namespace 中的实例"
    echo "  使用 -A/--all-ns 清理所有 namespace 的实例"
    echo "  使用 --namespace 清理指定 namespace 的实例"
    echo ""
    echo "示例:"
    echo "  cliExtra clean myproject              # 清理指定实例"
    echo "  cliExtra clean all                    # 清理 default namespace 中的所有实例"
    echo "  cliExtra clean all -A                 # 清理所有 namespace 中的实例"
    echo "  cliExtra clean all --all-ns           # 清理所有 namespace 中的实例"
    echo "  cliExtra clean all --namespace frontend  # 清理frontend namespace中的所有实例"
    echo "  cliExtra clean all --dry-run          # 预览将要清理的 default namespace 实例"
    echo "  cliExtra clean all -A --dry-run       # 预览将要清理的所有 namespace 实例"
}

# 获取实例的namespace
get_instance_namespace() {
    local instance_id="$1"
    
    # 从工作目录的namespace结构中查找实例
    if [ -d "$CLIEXTRA_HOME/namespaces" ]; then
        for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
            local instance_dir="$ns_dir/instances/instance_$instance_id"
            if [[ -d "$instance_dir" ]]; then
                basename "$ns_dir"
                return 0
            fi
        done
    fi
    
    # 向后兼容：查找实例所在的项目目录
    local project_dir=$(find_instance_project "$instance_id")
    if [[ $? -eq 0 ]]; then
        # 尝试新的namespace结构
        if [ -d "$project_dir/.cliExtra/namespaces" ]; then
            for ns_dir in "$project_dir/.cliExtra/namespaces"/*; do
                if [ -d "$ns_dir/instances/instance_$instance_id" ]; then
                    basename "$ns_dir"
                    return 0
                fi
            done
        fi
        
        # 回退到旧结构
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

# 停止tmux实例
stop_tmux_instance() {
    local instance_id="$1"
    local session_name="q_instance_$instance_id"
    
    if tmux has-session -t "$session_name" 2>/dev/null; then
        # 发送退出命令
        tmux send-keys -t "$session_name" "exit" Enter
        sleep 1
        
        # 如果还在运行，强制终止
        if tmux has-session -t "$session_name" 2>/dev/null; then
            tmux kill-session -t "$session_name"
        fi
        
        echo "✓ 实例 $instance_id 已停止"
    else
        echo "实例 $instance_id 未运行"
    fi
}

# 清理单个实例
clean_single_instance() {
    local instance_id="$1"
    local dry_run="$2"
    local session_name="q_instance_$instance_id"
    
    if [[ "$dry_run" == "true" ]]; then
        echo "预览: 将清理实例 $instance_id"
        local namespace=$(get_instance_namespace "$instance_id")
        echo "  - 实例ID: $instance_id"
        echo "  - Namespace: $namespace"
        echo "  - 会话: $session_name"
        return 0
    fi
    
    echo "清理实例 $instance_id..."
    
    # 停止实例
    stop_tmux_instance "$instance_id"
    
    # 从工作目录清理实例文件
    local instance_dir=$(find_instance_info_dir "$instance_id")
    if [[ $? -eq 0 && -n "$instance_dir" ]]; then
        # 获取namespace目录
        local ns_dir=$(dirname "$(dirname "$instance_dir")")
        local tmux_log_file="$ns_dir/logs/instance_${instance_id}_tmux.log"
        local conversation_file="$ns_dir/conversations/instance_$instance_id.json"
        
        # 删除实例目录
        if [ -d "$instance_dir" ]; then
            rm -rf "$instance_dir"
            echo "✓ 删除实例目录: $instance_dir"
        fi
        
        # 删除tmux日志文件
        if [ -f "$tmux_log_file" ]; then
            rm -f "$tmux_log_file"
            echo "✓ 删除Tmux日志: $tmux_log_file"
        fi
        
        # 删除对话记录文件
        if [ -f "$conversation_file" ]; then
            rm -f "$conversation_file"
            echo "✓ 删除对话记录: $conversation_file"
        fi
        
        # 删除状态文件
        if [ -f "$SCRIPT_DIR/cliExtra-status-manager.sh" ]; then
            source "$SCRIPT_DIR/cliExtra-status-manager.sh"
            local namespace=$(get_instance_namespace "$instance_id")
            if [ -z "$namespace" ]; then
                namespace="default"
            fi
            if remove_status_file "$instance_id" "$namespace"; then
                echo "✓ 删除状态文件"
            fi
            
            # 清理重启记录
            if [ -f "$SCRIPT_DIR/cliExtra-restart-manager.sh" ]; then
                source "$SCRIPT_DIR/cliExtra-restart-manager.sh"
                local record_file=$(get_restart_record_file "$instance_id" "$namespace")
                if [[ -f "$record_file" ]]; then
                    rm -f "$record_file"
                    echo "✓ 删除重启记录"
                fi
            fi
        fi
        
        echo "✓ 实例 $instance_id 清理完成"
    else
        # 向后兼容：查找并清理项目目录中的实例文件
        local project_dir=$(find_instance_project "$instance_id")
        if [ $? -eq 0 ]; then
            # 尝试新的namespace结构
            local cleaned=false
            if [ -d "$project_dir/.cliExtra/namespaces" ]; then
                for ns_dir in "$project_dir/.cliExtra/namespaces"/*; do
                    local old_instance_dir="$ns_dir/instances/instance_$instance_id"
                    if [ -d "$old_instance_dir" ]; then
                        local old_log_file="$ns_dir/logs/instance_$instance_id.log"
                        local old_conversation_file="$ns_dir/conversations/instance_$instance_id.json"
                        
                        rm -rf "$old_instance_dir"
                        [ -f "$old_log_file" ] && rm -f "$old_log_file"
                        [ -f "$old_conversation_file" ] && rm -f "$old_conversation_file"
                        
                        echo "✓ 清理旧结构实例文件"
                        cleaned=true
                        break
                    fi
                done
            fi
            
            # 回退到最旧的结构
            if [ "$cleaned" = false ]; then
                local old_instance_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
                local old_tmux_log_file="$project_dir/.cliExtra/logs/instance_${instance_id}_tmux.log"
                
                # 删除实例目录
                if [ -d "$old_instance_dir" ]; then
                    rm -rf "$old_instance_dir"
                    echo "✓ 删除实例目录: $old_instance_dir"
                fi
                
                # 删除tmux日志文件
                if [ -f "$old_tmux_log_file" ]; then
                    rm -f "$old_tmux_log_file"
                    echo "✓ 删除Tmux日志: $old_tmux_log_file"
                fi
            fi
            
            echo "✓ 实例 $instance_id 清理完成"
        else
            echo "⚠ 未找到实例 $instance_id 的文件，但tmux会话已停止"
        fi
    fi
}

# 清理指定namespace中的实例
clean_namespace_instances() {
    local target_namespace="$1"
    local dry_run="$2"
    
    echo "清理namespace '$target_namespace' 中的实例..."
    
    local instances_to_clean=()
    local cleaned=false
    
    # 获取所有tmux会话
    while IFS= read -r session_line; do
        if [[ "$session_line" == q_instance_* ]]; then
            session_info=$(echo "$session_line" | cut -d: -f1)
            instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            
            # 检查实例的namespace
            local instance_ns=$(get_instance_namespace "$instance_id")
            if [[ "$instance_ns" == "$target_namespace" ]]; then
                instances_to_clean+=("$instance_id")
                cleaned=true
            fi
        fi
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    if [[ "$dry_run" == "true" ]]; then
        if [ "$cleaned" = true ]; then
            echo "=== 预览模式 - 将要清理的实例 ==="
            for instance_id in "${instances_to_clean[@]}"; do
                echo "  → $instance_id (namespace: $target_namespace)"
            done
            echo "总计: ${#instances_to_clean[@]} 个实例"
        else
            echo "namespace '$target_namespace' 中没有需要清理的实例"
        fi
        return 0
    fi
    
    if [ "$cleaned" = true ]; then
        echo "找到 ${#instances_to_clean[@]} 个实例需要清理"
        for instance_id in "${instances_to_clean[@]}"; do
            echo ""
            clean_single_instance "$instance_id" "false"
        done
        echo ""
        echo "✓ namespace '$target_namespace' 中的所有实例已清理完成"
    else
        echo "namespace '$target_namespace' 中没有需要清理的实例"
    fi
}

# 清理所有tmux实例
clean_all_tmux() {
    local dry_run="$1"
    
    echo "清理所有实例..."
    
    local running_instances=()
    local stopped_instances=()
    local all_instances=()
    
    # 1. 从运行中的 tmux 会话获取实例
    while IFS= read -r session_line; do
        if [[ "$session_line" == q_instance_* ]]; then
            session_info=$(echo "$session_line" | cut -d: -f1)
            instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            running_instances+=("$instance_id")
            all_instances+=("$instance_id")
        fi
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    # 2. 从工作目录的namespace结构中获取所有实例（包括已停止的）
    if [ -d "$CLIEXTRA_HOME/namespaces" ]; then
        for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
            if [ -d "$ns_dir/instances" ]; then
                for instance_dir in "$ns_dir/instances"/instance_*; do
                    if [ -d "$instance_dir" ]; then
                        local instance_id=$(basename "$instance_dir" | sed 's/instance_//')
                        
                        # 检查是否已经在列表中
                        local found=false
                        for existing_instance in "${all_instances[@]}"; do
                            if [ "$existing_instance" = "$instance_id" ]; then
                                found=true
                                break
                            fi
                        done
                        
                        # 如果不在列表中，添加到停止实例列表
                        if [ "$found" = false ]; then
                            stopped_instances+=("$instance_id")
                            all_instances+=("$instance_id")
                        fi
                    fi
                done
            fi
        done
    fi
    
    # 3. 向后兼容：从项目目录中查找实例
    local search_dirs=("$HOME" "/Users" "/home")
    for search_dir in "${search_dirs[@]}"; do
        if [[ -d "$search_dir" ]]; then
            while IFS= read -r -d '' cliextra_dir; do
                local instances_dir="$cliextra_dir/instances"
                if [[ -d "$instances_dir" ]]; then
                    for instance_dir in "$instances_dir"/instance_*; do
                        if [[ -d "$instance_dir" ]]; then
                            local instance_id=$(basename "$instance_dir" | sed 's/instance_//')
                            
                            # 检查是否已经在列表中
                            local found=false
                            for existing_instance in "${all_instances[@]}"; do
                                if [ "$existing_instance" = "$instance_id" ]; then
                                    found=true
                                    break
                                fi
                            done
                            
                            # 如果不在列表中，添加到停止实例列表
                            if [ "$found" = false ]; then
                                stopped_instances+=("$instance_id")
                                all_instances+=("$instance_id")
                            fi
                        fi
                    done
                fi
            done < <(find "$search_dir" -name ".cliExtra" -type d -maxdepth 5 -print0 2>/dev/null)
        fi
    done
    
    # 检查是否有运行中的实例
    if [ ${#running_instances[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  发现 ${#running_instances[@]} 个运行中的实例："
        for instance_id in "${running_instances[@]}"; do
            local namespace=$(get_instance_namespace "$instance_id")
            echo "  → $instance_id (namespace: $namespace)"
        done
        echo ""
        echo "为了安全起见，请先停止所有运行中的实例，然后再进行清理："
        echo ""
        echo "  # 预览将要停止的实例"
        echo "  cliExtra stop all --dry-run"
        echo ""
        echo "  # 停止所有运行中的实例"
        echo "  cliExtra stop-all"
        echo ""
        echo "  # 然后清理所有实例"
        echo "  cliExtra clean-all"
        echo ""
        echo "或者使用组合命令："
        echo "  cliExtra stop-all && cliExtra clean-all"
        echo ""
        return 1
    fi
    
    # 如果没有运行中的实例，继续清理已停止的实例
    if [[ "$dry_run" == "true" ]]; then
        if [ ${#stopped_instances[@]} -gt 0 ]; then
            echo "=== 预览模式 - 将要清理的已停止实例 ==="
            for instance_id in "${stopped_instances[@]}"; do
                local namespace=$(get_instance_namespace "$instance_id")
                echo "  → $instance_id (namespace: $namespace, status: Not Running)"
            done
            echo "总计: ${#stopped_instances[@]} 个已停止的实例"
        else
            echo "没有需要清理的实例"
        fi
        return 0
    fi
    
    if [ ${#stopped_instances[@]} -gt 0 ]; then
        echo "找到 ${#stopped_instances[@]} 个已停止的实例需要清理"
        for instance_id in "${stopped_instances[@]}"; do
            echo ""
            clean_single_instance "$instance_id" "false"
        done
        echo ""
        echo "✓ 所有已停止的实例已清理完成"
    else
        echo "没有需要清理的实例"
    fi
}

# 解析参数
TARGET=""
TARGET_NAMESPACE=""
DRY_RUN=false
SHOW_ALL_NAMESPACES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            TARGET_NAMESPACE="$2"
            shift 2
            ;;
        -A|--all-ns)
            SHOW_ALL_NAMESPACES=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        all)
            TARGET="all"
            shift
            ;;
        -*)
            echo "未知选项: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$TARGET" ]]; then
                TARGET="$1"
            else
                echo "多余的参数: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# 主逻辑
if [[ -z "$TARGET" ]]; then
    echo "错误: 请指定要清理的实例ID或使用 'all'"
    show_help
    exit 1
elif [[ "$TARGET" == "all" ]]; then
    if [[ -n "$TARGET_NAMESPACE" ]]; then
        # 如果指定了具体的 namespace
        clean_namespace_instances "$TARGET_NAMESPACE" "$DRY_RUN"
    elif [[ "$SHOW_ALL_NAMESPACES" == "true" ]]; then
        # 如果指定了 -A/--all-ns，清理所有 namespace
        clean_all_tmux "$DRY_RUN"
    else
        # 默认只清理 default namespace
        clean_namespace_instances "default" "$DRY_RUN"
    fi
else
    if [[ -n "$TARGET_NAMESPACE" || "$SHOW_ALL_NAMESPACES" == "true" ]]; then
        echo "错误: --namespace 和 -A/--all-ns 选项只能与 'all' 一起使用"
        show_help
        exit 1
    fi
    clean_single_instance "$TARGET" "$DRY_RUN"
fi 