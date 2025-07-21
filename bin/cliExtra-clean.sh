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
    echo "  --dry-run        预览模式，显示将要清理的实例但不实际执行"
    echo ""
    echo "示例:"
    echo "  cliExtra clean myproject              # 清理指定实例"
    echo "  cliExtra clean all                    # 清理所有实例"
    echo "  cliExtra clean all --namespace frontend  # 清理frontend namespace中的所有实例"
    echo "  cliExtra clean all --dry-run          # 预览将要清理的所有实例"
    echo "  cliExtra clean all --namespace backend --dry-run  # 预览backend namespace中的实例"
}

# 获取实例的namespace
get_instance_namespace() {
    local instance_id="$1"
    
    # 查找实例所在的项目目录
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
    
    # 查找并清理项目目录中的实例文件
    local project_dir=$(find_instance_project "$instance_id")
    if [ $? -eq 0 ]; then
        local instance_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
        local log_file="$project_dir/.cliExtra/logs/instance_$instance_id.log"
        
        # 删除实例目录
        if [ -d "$instance_dir" ]; then
            rm -rf "$instance_dir"
            echo "✓ 实例目录已删除: $instance_dir"
        fi
        
        # 删除日志文件
        if [ -f "$log_file" ]; then
            rm -f "$log_file"
            echo "✓ 日志文件已删除: $log_file"
        fi
        
        echo "✓ 实例 $instance_id 已完全清理"
    else
        echo "⚠ 未找到实例 $instance_id 的项目目录"
        echo "✓ 实例 $instance_id 已停止"
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
    
    echo "清理所有tmux q CLI实例..."
    
    local instances_to_clean=()
    local cleaned=false
    
    while IFS= read -r session_line; do
        if [[ "$session_line" == q_instance_* ]]; then
            session_info=$(echo "$session_line" | cut -d: -f1)
            instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            instances_to_clean+=("$instance_id")
            cleaned=true
        fi
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    if [[ "$dry_run" == "true" ]]; then
        if [ "$cleaned" = true ]; then
            echo "=== 预览模式 - 将要清理的所有实例 ==="
            for instance_id in "${instances_to_clean[@]}"; do
                local namespace=$(get_instance_namespace "$instance_id")
                echo "  → $instance_id (namespace: $namespace)"
            done
            echo "总计: ${#instances_to_clean[@]} 个实例"
        else
            echo "没有需要清理的实例"
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
        echo "✓ 所有实例已清理完成"
    else
        echo "没有需要清理的实例"
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
        clean_namespace_instances "$TARGET_NAMESPACE" "$DRY_RUN"
    else
        clean_all_tmux "$DRY_RUN"
    fi
else
    if [[ -n "$TARGET_NAMESPACE" ]]; then
        echo "错误: --namespace 选项只能与 'all' 一起使用"
        show_help
        exit 1
    fi
    clean_single_instance "$TARGET" "$DRY_RUN"
fi 