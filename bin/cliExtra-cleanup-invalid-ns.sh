#!/bin/bash

# cliExtra 清理无效 namespace 脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra cleanup-invalid-ns [options]"
    echo ""
    echo "功能: 清理包含无效字符的 namespace 目录"
    echo ""
    echo "选项:"
    echo "  --dry-run    只显示将要清理的目录，不实际删除"
    echo "  --force      强制删除，不需要确认"
    echo "  --help       显示此帮助信息"
    echo ""
    echo "有效的 namespace 名称规则:"
    echo "  - 只能包含英文字母、数字、下划线(_)和连字符(-)"
    echo "  - 长度不超过 32 个字符"
    echo "  - 不能包含中文、空格或其他特殊字符"
    echo ""
    echo "示例:"
    echo "  cliExtra cleanup-invalid-ns --dry-run    # 预览模式"
    echo "  cliExtra cleanup-invalid-ns --force      # 强制清理"
}

# 检查 namespace 名称是否有效
is_valid_namespace_name() {
    local ns_name="$1"
    
    # 检查长度
    if [[ ${#ns_name} -gt 32 ]]; then
        return 1
    fi
    
    # 检查字符
    if [[ ! "$ns_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    
    return 0
}

# 查找无效的 namespace 目录
find_invalid_namespaces() {
    local invalid_namespaces=()
    
    if [[ ! -d "$CLIEXTRA_NAMESPACES_DIR" ]]; then
        echo "namespace 目录不存在: $CLIEXTRA_NAMESPACES_DIR"
        return 0
    fi
    
    for ns_dir in "$CLIEXTRA_NAMESPACES_DIR"/*; do
        if [[ -d "$ns_dir" ]]; then
            local ns_name=$(basename "$ns_dir")
            
            # 跳过隐藏目录
            if [[ "$ns_name" == .* ]]; then
                continue
            fi
            
            # 检查是否为有效的 namespace 名称
            if ! is_valid_namespace_name "$ns_name"; then
                invalid_namespaces+=("$ns_name")
            fi
        fi
    done
    
    printf '%s\n' "${invalid_namespaces[@]}"
}

# 清理无效的 namespace
cleanup_invalid_namespaces() {
    local dry_run="$1"
    local force="$2"
    
    local invalid_namespaces=($(find_invalid_namespaces))
    
    if [[ ${#invalid_namespaces[@]} -eq 0 ]]; then
        echo "✓ 没有发现无效的 namespace 目录"
        return 0
    fi
    
    echo "发现 ${#invalid_namespaces[@]} 个无效的 namespace:"
    echo ""
    
    for ns_name in "${invalid_namespaces[@]}"; do
        local ns_dir="$CLIEXTRA_NAMESPACES_DIR/$ns_name"
        local reason=""
        
        # 分析无效原因
        if [[ ${#ns_name} -gt 32 ]]; then
            reason="名称过长 (${#ns_name} > 32)"
        elif [[ "$ns_name" =~ [^a-zA-Z0-9_-] ]]; then
            reason="包含无效字符"
        else
            reason="未知原因"
        fi
        
        echo "  ❌ '$ns_name' - $reason"
        echo "     路径: $ns_dir"
        
        # 检查是否有实例在运行
        local instances_count=0
        if [[ -d "$ns_dir/instances" ]]; then
            instances_count=$(find "$ns_dir/instances" -name "instance_*" -type d 2>/dev/null | wc -l)
        fi
        
        if [[ $instances_count -gt 0 ]]; then
            echo "     ⚠️  包含 $instances_count 个实例目录"
        fi
        
        echo ""
    done
    
    if [[ "$dry_run" == "true" ]]; then
        echo "=== 预览模式 - 不会实际删除 ==="
        echo "使用 --force 参数执行实际清理"
        return 0
    fi
    
    # 确认删除
    if [[ "$force" != "true" ]]; then
        echo "确认要删除这些无效的 namespace 目录吗？"
        echo "这将删除所有相关的实例数据、日志和对话记录。"
        echo ""
        read -p "输入 'yes' 确认删除: " confirm
        
        if [[ "$confirm" != "yes" ]]; then
            echo "取消清理操作"
            return 0
        fi
    fi
    
    # 执行清理
    echo ""
    echo "=== 开始清理 ==="
    local success_count=0
    local failed_count=0
    
    for ns_name in "${invalid_namespaces[@]}"; do
        local ns_dir="$CLIEXTRA_NAMESPACES_DIR/$ns_name"
        
        echo "正在删除: '$ns_name'"
        
        if rm -rf "$ns_dir" 2>/dev/null; then
            echo "✓ 已删除: $ns_dir"
            success_count=$((success_count + 1))
        else
            echo "❌ 删除失败: $ns_dir"
            failed_count=$((failed_count + 1))
        fi
    done
    
    echo ""
    echo "=== 清理完成 ==="
    echo "成功删除: $success_count 个"
    echo "删除失败: $failed_count 个"
    
    if [[ $success_count -gt 0 ]]; then
        echo ""
        echo "建议运行以下命令检查系统状态:"
        echo "  qq ns show"
        echo "  qq list -A"
    fi
}

# 解析参数
DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 执行清理
cleanup_invalid_namespaces "$DRY_RUN" "$FORCE"
