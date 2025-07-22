#!/bin/bash

# cliExtra-workflow.sh - Workflow 管理脚本

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_workflow_help() {
    echo "cliExtra workflow 命令用法:"
    echo "  workflow show [namespace]     - 显示workflow配置"
    echo "  workflow init [namespace]     - 初始化workflow配置"
    echo "  workflow validate [namespace] - 验证workflow配置"
    echo "  workflow list                 - 列出所有namespace的workflow"
    echo ""
    echo "示例:"
    echo "  cliExtra workflow show q_cli"
    echo "  cliExtra workflow init"
    echo "  cliExtra workflow validate default"
}

# 获取namespace的workflow文件路径
get_workflow_file() {
    local ns_name="${1:-$(get_current_namespace)}"
    local ns_dir="$(get_namespace_dir "$ns_name")"
    echo "$ns_dir/workflow.yaml"
}

# 列出所有namespace的workflow
list_workflows() {
    echo "=== All Namespace Workflows ==="
    local namespaces_dir="$CLIEXTRA_NAMESPACES_DIR"
    
    if [[ -d "$namespaces_dir" ]]; then
        for ns_dir in "$namespaces_dir"/*; do
            if [[ -d "$ns_dir" ]]; then
                local ns_name="$(basename "$ns_dir")"
                local workflow_file="$ns_dir/workflow.yaml"
                
                if [[ -f "$workflow_file" ]]; then
                    echo "✅ $ns_name - workflow.yaml exists"
                else
                    echo "❌ $ns_name - no workflow.yaml"
                fi
            fi
        done
    else
        echo "未找到 namespaces 目录: $namespaces_dir"
    fi
}

# 显示workflow帮助信息
show_workflow_info() {
    echo "=== cliExtra Workflow 系统说明 ==="
    echo ""
    echo "Workflow 功能用于管理 namespace 级别的协作流程配置："
    echo ""
    echo "📋 配置内容："
    echo "  - 项目信息和描述"
    echo "  - 角色定义和职责"
    echo "  - 协作关系和触发条件"
    echo "  - 开发流程和步骤"
    echo "  - 通知模板和自动化规则"
    echo ""
    echo "🎯 主要价值："
    echo "  - 标准化团队协作流程"
    echo "  - 自动化协作通知"
    echo "  - 提高开发效率"
    echo "  - 支持 AI 智能协作"
    echo ""
    echo "📁 配置文件位置："
    echo "  ~/Library/Application Support/cliExtra/namespaces/<namespace>/workflow.yaml"
    echo ""
}

# 显示workflow配置
show_workflow() {
    local ns_name="${1:-$(get_current_namespace)}"
    local workflow_file="$(get_workflow_file "$ns_name")"
    
    if [[ -f "$workflow_file" ]]; then
        echo "=== Namespace: $ns_name Workflow ==="
        cat "$workflow_file"
    else
        echo "未找到 namespace '$ns_name' 的 workflow 配置文件"
        echo "文件路径: $workflow_file"
        echo "使用 'cliExtra workflow init $ns_name' 创建配置"
    fi
}

# 主命令处理
case "${1:-help}" in
    "show")
        show_workflow "${2}"
        ;;
    "list")
        list_workflows
        ;;
    "info")
        show_workflow_info
        ;;
    "init")
        echo "workflow init 功能开发中..."
        ;;
    "validate")
        echo "workflow validate 功能开发中..."
        ;;
    "help"|"")
        show_workflow_help
        ;;
    *)
        echo "未知的 workflow 命令: $1"
        show_workflow_help
        ;;
esac
