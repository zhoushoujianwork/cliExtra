#!/bin/bash

# cliExtra-workflow-adapter.sh - 适配现有命令到新workflow系统

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 检查是否使用新版workflow
use_new_workflow() {
    local ns_name="${1:-$(get_current_namespace)}"
    local workflow_file="$(get_namespace_dir "$ns_name")/workflow.json"
    [[ -f "$workflow_file" ]]
}

# 适配器主函数
workflow_adapter() {
    local command="$1"
    shift
    
    case "$command" in
        "show"|"list"|"status"|"init"|"validate"|"dag")
            # 使用新版workflow脚本
            "$SCRIPT_DIR/cliExtra-workflow-v2.sh" "$command" "$@"
            ;;
        *)
            # 回退到旧版workflow脚本
            "$SCRIPT_DIR/cliExtra-workflow.sh" "$command" "$@"
            ;;
    esac
}

# 执行适配
workflow_adapter "$@"
