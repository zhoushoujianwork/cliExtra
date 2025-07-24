#!/bin/bash

# cliExtra 停止实例脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra stop <instance_id|all> [options]"
    echo ""
    echo "参数:"
    echo "  instance_id       停止指定实例"
    echo "  all              停止所有运行中的实例"
    echo ""
    echo "选项:"
    echo "  --namespace <ns>  只停止指定namespace中的实例（仅与all一起使用）"
    echo "  --dry-run        预览模式，显示将要停止的实例但不实际执行"
    echo ""
    echo "示例:"
    echo "  cliExtra stop myproject              # 停止指定实例"
    echo "  cliExtra stop all                    # 停止所有运行中的实例"
    echo "  cliExtra stop all --namespace frontend  # 停止frontend namespace中的所有运行实例"
    echo "  cliExtra stop all --dry-run          # 预览将要停止的所有实例"
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
        
        # 回退到旧的结构
        local old_instance_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
        if [[ -d "$old_instance_dir" ]]; then
            local ns_file="$old_instance_dir/namespace"
            if [[ -f "$ns_file" ]]; then
                cat "$ns_file"
            else
                echo "default"
            fi
            return 0
        fi
    fi
    
    echo "default"
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
        
        # 清理实例状态文件
        if [ -f "$SCRIPT_DIR/cliExtra-status-manager.sh" ]; then
            source "$SCRIPT_DIR/cliExtra-status-manager.sh"
            local namespace=$(get_instance_namespace "$instance_id")
            if [ -z "$namespace" ]; then
                namespace="default"
            fi
            if remove_status_file "$instance_id" "$namespace"; then
                echo "✓ 状态文件已清理"
            fi
        fi
        
        echo "✓ 实例 $instance_id 已停止"
    else
        echo "实例 $instance_id 未运行"
    fi
}

# 停止指定namespace中的所有运行实例
stop_namespace_instances() {
    local target_namespace="$1"
    local dry_run="$2"
    
    echo "停止namespace '$target_namespace' 中的所有运行实例..."
    
    local instances_to_stop=()
    local stopped=false
    
    # 获取所有运行中的实例
    while IFS= read -r session_line; do
        if [[ "$session_line" == q_instance_* ]]; then
            session_info=$(echo "$session_line" | cut -d: -f1)
            instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            
            # 检查namespace
            local namespace=$(get_instance_namespace "$instance_id")
            if [[ "$namespace" == "$target_namespace" ]]; then
                instances_to_stop+=("$instance_id")
                stopped=true
            fi
        fi
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    if [[ "$dry_run" == "true" ]]; then
        if [ "$stopped" = true ]; then
            echo "=== 预览模式 - 将要停止的实例 ==="
            for instance_id in "${instances_to_stop[@]}"; do
                echo "  → $instance_id (namespace: $target_namespace)"
            done
            echo "总计: ${#instances_to_stop[@]} 个运行中的实例"
        else
            echo "namespace '$target_namespace' 中没有运行中的实例"
        fi
        return 0
    fi
    
    if [ "$stopped" = true ]; then
        echo "找到 ${#instances_to_stop[@]} 个运行中的实例需要停止"
        for instance_id in "${instances_to_stop[@]}"; do
            stop_tmux_instance "$instance_id"
        done
        echo ""
        echo "✓ namespace '$target_namespace' 中的所有实例已停止"
    else
        echo "namespace '$target_namespace' 中没有运行中的实例"
    fi
}

# 停止所有运行中的实例
stop_all_instances() {
    local dry_run="$1"
    
    echo "停止所有运行中的实例..."
    
    local instances_to_stop=()
    local stopped=false
    
    while IFS= read -r session_line; do
        if [[ "$session_line" == q_instance_* ]]; then
            session_info=$(echo "$session_line" | cut -d: -f1)
            instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            instances_to_stop+=("$instance_id")
            stopped=true
        fi
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    if [[ "$dry_run" == "true" ]]; then
        if [ "$stopped" = true ]; then
            echo "=== 预览模式 - 将要停止的所有运行实例 ==="
            for instance_id in "${instances_to_stop[@]}"; do
                local namespace=$(get_instance_namespace "$instance_id")
                echo "  → $instance_id (namespace: $namespace)"
            done
            echo "总计: ${#instances_to_stop[@]} 个运行中的实例"
        else
            echo "没有运行中的实例"
        fi
        return 0
    fi
    
    if [ "$stopped" = true ]; then
        echo "找到 ${#instances_to_stop[@]} 个运行中的实例需要停止"
        for instance_id in "${instances_to_stop[@]}"; do
            stop_tmux_instance "$instance_id"
        done
        echo ""
        echo "✓ 所有运行中的实例已停止"
    else
        echo "没有运行中的实例"
    fi
}

# 解析参数
TARGET=""
TARGET_NAMESPACE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            TARGET_NAMESPACE="$2"
            shift 2
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
            fi
            shift
            ;;
    esac
done

# 主逻辑
if [[ -z "$TARGET" ]]; then
    echo "错误: 请指定要停止的实例ID或使用 'all'"
    show_help
    exit 1
elif [[ "$TARGET" == "all" ]]; then
    if [[ -n "$TARGET_NAMESPACE" ]]; then
        stop_namespace_instances "$TARGET_NAMESPACE" "$DRY_RUN"
    else
        stop_all_instances "$DRY_RUN"
    fi
else
    if [[ -n "$TARGET_NAMESPACE" ]]; then
        echo "错误: --namespace 选项只能与 'all' 一起使用"
        show_help
        exit 1
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "错误: --dry-run 选项只能与 'all' 一起使用"
        show_help
        exit 1
    fi
    stop_tmux_instance "$TARGET"
fi 