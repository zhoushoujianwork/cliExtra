#!/bin/bash

# cliExtra-workflow-v2.sh - 新版 Workflow DAG 管理脚本

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_workflow_help() {
    echo "cliExtra workflow 命令用法:"
    echo ""
    echo "基础管理:"
    echo "  workflow show [namespace]           - 显示workflow配置"
    echo "  workflow list                       - 列出所有namespace的workflow"
    echo "  workflow status [namespace]         - 显示workflow执行状态"
    echo "  workflow init [namespace]           - 初始化workflow配置"
    echo "  workflow validate [namespace]       - 验证workflow配置"
    echo ""
    echo "DAG 操作:"
    echo "  workflow dag show [namespace]       - 显示DAG结构"
    echo "  workflow dag export [namespace] [format] - 导出DAG (json/yaml/dot)"
    echo "  workflow dag import [namespace] [file]   - 导入DAG配置"
    echo "  workflow dag validate [namespace]   - 验证DAG结构"
    echo ""
    echo "执行控制:"
    echo "  workflow start [namespace] [node]   - 启动workflow执行"
    echo "  workflow complete <task_id>         - 完成指定任务"
    echo "  workflow block <task_id> [reason]   - 阻塞指定任务"
    echo "  workflow resume <task_id>           - 恢复被阻塞的任务"
    echo ""
    echo "任务管理:"
    echo "  workflow task list [namespace]      - 列出所有任务"
    echo "  workflow task show <task_id>        - 显示任务详情"
    echo "  workflow task assign <task_id> <role> - 分配任务给角色"
    echo "  workflow task progress <task_id> <percent> - 更新任务进度"
    echo ""
    echo "协作功能:"
    echo "  workflow notify <task_id> <message> - 发送任务通知"
    echo "  workflow escalate <task_id>         - 升级任务"
    echo "  workflow dependencies <task_id>     - 查看任务依赖"
    echo ""
    echo "示例:"
    echo "  qq workflow init development"
    echo "  qq workflow start development"
    echo "  qq workflow complete api_design"
    echo "  qq workflow dag show development"
}

# 获取workflow文件路径
get_workflow_file() {
    local ns_name="${1:-$(get_current_namespace)}"
    local ns_dir="$(get_namespace_dir "$ns_name")"
    echo "$ns_dir/workflow.json"
}

# 获取workflow状态文件路径
get_workflow_state_file() {
    local ns_name="${1:-$(get_current_namespace)}"
    local ns_dir="$(get_namespace_dir "$ns_name")"
    echo "$ns_dir/workflow_state.json"
}

# 初始化workflow配置
init_workflow() {
    local ns_name="${1:-$(get_current_namespace)}"
    local workflow_file="$(get_workflow_file "$ns_name")"
    local state_file="$(get_workflow_state_file "$ns_name")"
    
    # 确保目录存在
    mkdir -p "$(dirname "$workflow_file")"
    
    if [[ -f "$workflow_file" ]]; then
        echo "Workflow 配置已存在: $workflow_file"
        read -p "是否覆盖现有配置? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "取消初始化"
            return 1
        fi
    fi
    
    # 创建默认workflow配置
    cat > "$workflow_file" << 'EOF'
{
  "version": "2.0",
  "metadata": {
    "name": "默认开发流程",
    "description": "基础开发协作工作流",
    "namespace": "default",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "roles": {
    "developer": {
      "name": "开发工程师",
      "description": "负责功能开发和实现",
      "tools": ["git", "editor"],
      "responsibilities": ["代码开发", "单元测试", "文档编写"]
    }
  },
  "nodes": {
    "start": {
      "id": "start",
      "type": "start",
      "title": "项目开始",
      "description": "项目启动节点"
    },
    "development": {
      "id": "development",
      "type": "task",
      "title": "功能开发",
      "description": "实现项目功能",
      "owner": "developer",
      "estimated_time": "8h",
      "deliverables": ["功能代码", "单元测试"],
      "dependencies": []
    },
    "end": {
      "id": "end",
      "type": "end",
      "title": "项目完成",
      "description": "项目交付完成"
    }
  },
  "edges": [
    {"from": "start", "to": "development"},
    {"from": "development", "to": "end"}
  ],
  "collaboration_rules": {
    "auto_notify": {
      "task_complete": {
        "enabled": true,
        "template": "任务完成通知：{task_title} 已完成，交付物：{deliverables}"
      }
    }
  }
}
EOF
    
    # 替换时间戳
    sed -i '' "s/\$(date -u +%Y-%m-%dT%H:%M:%SZ)/$(date -u +%Y-%m-%dT%H:%M:%SZ)/g" "$workflow_file"
    
    # 创建初始状态文件
    cat > "$state_file" << EOF
{
  "current_nodes": ["start"],
  "completed_nodes": [],
  "active_tasks": {},
  "task_history": [],
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    echo "✅ Workflow 配置已初始化: $workflow_file"
    echo "✅ Workflow 状态已初始化: $state_file"
}

# 显示workflow配置
show_workflow() {
    local ns_name="${1:-$(get_current_namespace)}"
    local workflow_file="$(get_workflow_file "$ns_name")"
    
    if [[ -f "$workflow_file" ]]; then
        echo "=== Namespace: $ns_name Workflow ==="
        if command -v jq >/dev/null 2>&1; then
            jq '.' "$workflow_file"
        else
            cat "$workflow_file"
        fi
    else
        echo "❌ 未找到 namespace '$ns_name' 的 workflow 配置文件"
        echo "文件路径: $workflow_file"
        echo "使用 'qq workflow init $ns_name' 创建配置"
    fi
}

# 显示workflow状态
show_workflow_status() {
    local ns_name="${1:-$(get_current_namespace)}"
    local state_file="$(get_workflow_state_file "$ns_name")"
    
    if [[ -f "$state_file" ]]; then
        echo "=== Namespace: $ns_name Workflow Status ==="
        if command -v jq >/dev/null 2>&1; then
            jq '.' "$state_file"
        else
            cat "$state_file"
        fi
    else
        echo "❌ 未找到 namespace '$ns_name' 的 workflow 状态文件"
        echo "使用 'qq workflow start $ns_name' 启动workflow"
    fi
}

# 显示DAG结构
show_dag() {
    local ns_name="${1:-$(get_current_namespace)}"
    local workflow_file="$(get_workflow_file "$ns_name")"
    
    if [[ ! -f "$workflow_file" ]]; then
        echo "❌ 未找到 workflow 配置文件: $workflow_file"
        return 1
    fi
    
    echo "=== Namespace: $ns_name DAG Structure ==="
    
    if command -v jq >/dev/null 2>&1; then
        echo "📋 节点列表:"
        jq -r '.nodes | to_entries[] | "  \(.key): \(.value.title) (\(.value.type))"' "$workflow_file"
        
        echo ""
        echo "🔗 边连接:"
        jq -r '.edges[] | "  \(.from) -> \(.to)"' "$workflow_file"
        
        echo ""
        echo "👥 角色分配:"
        jq -r '.nodes | to_entries[] | select(.value.owner) | "  \(.key): \(.value.owner)"' "$workflow_file"
    else
        echo "需要安装 jq 来显示结构化信息"
        echo "原始配置:"
        cat "$workflow_file"
    fi
}

# 列出所有workflow
list_workflows() {
    echo "=== All Namespace Workflows ==="
    local namespaces_dir="$CLIEXTRA_NAMESPACES_DIR"
    
    if [[ -d "$namespaces_dir" ]]; then
        for ns_dir in "$namespaces_dir"/*; do
            if [[ -d "$ns_dir" ]]; then
                local ns_name="$(basename "$ns_dir")"
                local workflow_file="$ns_dir/workflow.json"
                local state_file="$ns_dir/workflow_state.json"
                
                if [[ -f "$workflow_file" ]]; then
                    local status="❌ 未启动"
                    if [[ -f "$state_file" ]]; then
                        status="✅ 已启动"
                    fi
                    echo "📁 $ns_name - workflow.json exists ($status)"
                else
                    echo "❌ $ns_name - no workflow.json"
                fi
            fi
        done
    else
        echo "未找到 namespaces 目录: $namespaces_dir"
    fi
}

# 验证workflow配置
validate_workflow() {
    local ns_name="${1:-$(get_current_namespace)}"
    local workflow_file="$(get_workflow_file "$ns_name")"
    
    if [[ ! -f "$workflow_file" ]]; then
        echo "❌ 未找到 workflow 配置文件: $workflow_file"
        return 1
    fi
    
    echo "🔍 验证 workflow 配置: $ns_name"
    
    # 检查JSON格式
    if command -v jq >/dev/null 2>&1; then
        if ! jq '.' "$workflow_file" >/dev/null 2>&1; then
            echo "❌ JSON 格式错误"
            return 1
        fi
        echo "✅ JSON 格式正确"
        
        # 检查必需字段
        local required_fields=("version" "metadata" "nodes" "edges")
        for field in "${required_fields[@]}"; do
            if jq -e ".$field" "$workflow_file" >/dev/null 2>&1; then
                echo "✅ 必需字段 '$field' 存在"
            else
                echo "❌ 缺少必需字段 '$field'"
                return 1
            fi
        done
        
        # 检查DAG结构
        echo "🔍 检查DAG结构..."
        # TODO: 实现循环检测等高级验证
        echo "✅ 基础验证通过"
        
    else
        echo "⚠️  需要安装 jq 进行详细验证"
        echo "✅ 文件存在且可读"
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
    "status")
        show_workflow_status "${2}"
        ;;
    "init")
        init_workflow "${2}"
        ;;
    "validate")
        validate_workflow "${2}"
        ;;
    "dag")
        case "${2:-help}" in
            "show")
                show_dag "${3}"
                ;;
            "export")
                echo "DAG export 功能开发中..."
                ;;
            "import")
                echo "DAG import 功能开发中..."
                ;;
            "validate")
                validate_workflow "${3}"
                ;;
            *)
                echo "DAG 子命令: show, export, import, validate"
                ;;
        esac
        ;;
    "start")
        echo "workflow start 功能开发中..."
        ;;
    "complete")
        echo "workflow complete 功能开发中..."
        ;;
    "task")
        echo "workflow task 功能开发中..."
        ;;
    "notify")
        echo "workflow notify 功能开发中..."
        ;;
    "help"|"")
        show_workflow_help
        ;;
    *)
        echo "未知的 workflow 命令: $1"
        show_workflow_help
        ;;
esac
