#!/bin/bash

# cliExtra DAG 工作流管理脚本

# 加载配置、公共函数和状态管理器
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"

# DAG 配置
DAG_DIR_SUFFIX="dags"
DAG_MODEL_DIR="$(dirname "$SCRIPT_DIR")/dag_model"

# 获取 namespace 的 DAG 目录
get_dag_dir() {
    local namespace="${1:-$CLIEXTRA_DEFAULT_NS}"
    echo "$CLIEXTRA_HOME/namespaces/$namespace/$DAG_DIR_SUFFIX"
}

# 获取 DAG 实例文件路径
get_dag_instance_file() {
    local dag_id="$1"
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    local dag_dir=$(get_dag_dir "$namespace")
    echo "$dag_dir/${dag_id}.json"
}

# 创建 DAG 实例
create_dag_instance() {
    local workflow_name="$1"
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    local trigger_message="${3:-手动启动}"
    local trigger_sender="${4:-system:admin}"
    
    # 生成 DAG 实例 ID
    local timestamp=$(date +%s)
    local random=$((RANDOM % 90000 + 10000))  # 生成 10000-99999 的随机数
    local dag_id="dag_${workflow_name}_${timestamp}_${random}"
    
    # 确保 DAG 目录存在
    local dag_dir=$(get_dag_dir "$namespace")
    mkdir -p "$dag_dir"
    
    # 查找工作流定义文件
    local workflow_file="$DAG_MODEL_DIR/${workflow_name}.json"
    if [[ ! -f "$workflow_file" ]]; then
        echo "错误: 工作流定义文件不存在: $workflow_file" >&2
        return 1
    fi
    
    # 创建 DAG 实例状态文件
    local dag_instance_file=$(get_dag_instance_file "$dag_id" "$namespace")
    
    cat > "$dag_instance_file" << EOF
{
  "dag_instance_id": "$dag_id",
  "workflow_name": "$workflow_name",
  "workflow_file": "$workflow_file",
  "namespace": "$namespace",
  "status": "running",
  "created_at": "$(date -Iseconds)",
  "trigger": {
    "sender": "$trigger_sender",
    "message": "$trigger_message",
    "timestamp": "$(date -Iseconds)"
  },
  "current_nodes": ["start"],
  "completed_nodes": [],
  "blocked_nodes": [],
  "failed_nodes": [],
  "node_execution_history": [
    {
      "node_id": "start",
      "status": "completed",
      "started_at": "$(date -Iseconds)",
      "completed_at": "$(date -Iseconds)",
      "trigger": {
        "sender": "$trigger_sender",
        "message": "$trigger_message"
      }
    }
  ],
  "message_tracking": [
    {
      "timestamp": "$(date -Iseconds)",
      "sender": "$trigger_sender",
      "action": "start_workflow",
      "message": "$trigger_message",
      "dag_context": {
        "workflow": "$workflow_name",
        "namespace": "$namespace"
      }
    }
  ],
  "collaboration_context": {
    "active_roles": [],
    "role_assignments": {},
    "pending_tasks": []
  }
}
EOF
    
    if [[ $? -eq 0 ]]; then
        echo "✓ DAG 实例创建成功: $dag_id"
        echo "  工作流: $workflow_name"
        echo "  命名空间: $namespace"
        echo "  状态文件: $dag_instance_file"
        echo "$dag_id"  # 返回 DAG ID 供调用者使用
        return 0
    else
        echo "❌ DAG 实例创建失败" >&2
        return 1
    fi
}

# 列出 DAG 实例
list_dag_instances() {
    local namespace="${1:-}"
    local output_format="${2:-table}"
    local show_all_namespaces=false
    
    # 如果没有指定 namespace，使用默认行为
    if [[ -z "$namespace" ]]; then
        namespace="$CLIEXTRA_DEFAULT_NS"
    elif [[ "$namespace" == "--all" || "$namespace" == "-A" ]]; then
        show_all_namespaces=true
        namespace=""
    fi
    
    local dag_instances=()
    
    if [[ "$show_all_namespaces" == "true" ]]; then
        # 扫描所有 namespace
        if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
            for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
                if [[ -d "$ns_dir" ]]; then
                    local ns_name=$(basename "$ns_dir")
                    local dag_dir="$ns_dir/$DAG_DIR_SUFFIX"
                    if [[ -d "$dag_dir" ]]; then
                        for dag_file in "$dag_dir"/dag_*.json; do
                            if [[ -f "$dag_file" ]]; then
                                dag_instances+=("$dag_file:$ns_name")
                            fi
                        done
                    fi
                fi
            done
        fi
    else
        # 只扫描指定 namespace
        local dag_dir=$(get_dag_dir "$namespace")
        if [[ -d "$dag_dir" ]]; then
            for dag_file in "$dag_dir"/dag_*.json; do
                if [[ -f "$dag_file" ]]; then
                    dag_instances+=("$dag_file:$namespace")
                fi
            done
        fi
    fi
    
    if [[ ${#dag_instances[@]} -eq 0 ]]; then
        if [[ "$show_all_namespaces" == "true" ]]; then
            echo "没有找到活跃的 DAG 实例"
        else
            echo "在 namespace '$namespace' 中没有找到活跃的 DAG 实例"
        fi
        return 0
    fi
    
    if [[ "$output_format" == "json" ]]; then
        echo "{"
        echo "  \"dag_instances\": ["
        local first=true
        for instance_info in "${dag_instances[@]}"; do
            IFS=':' read -r dag_file ns_name <<< "$instance_info"
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            echo -n "    "
            cat "$dag_file" | jq -c .
        done
        echo ""
        echo "  ]"
        echo "}"
    else
        # 表格格式
        printf "%-40s %-15s %-15s %-20s %-15s\n" "DAG_ID" "NAMESPACE" "WORKFLOW" "STATUS" "CREATED"
        printf "%-40s %-15s %-15s %-20s %-15s\n" "$(printf '%*s' 40 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')" "$(printf '%*s' 20 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')"
        
        for instance_info in "${dag_instances[@]}"; do
            IFS=':' read -r dag_file ns_name <<< "$instance_info"
            
            local dag_id=$(jq -r '.dag_instance_id' "$dag_file" 2>/dev/null || echo "unknown")
            local workflow=$(jq -r '.workflow_name' "$dag_file" 2>/dev/null || echo "unknown")
            local status=$(jq -r '.status' "$dag_file" 2>/dev/null || echo "unknown")
            local created=$(jq -r '.created_at' "$dag_file" 2>/dev/null | cut -d'T' -f1 || echo "unknown")
            
            printf "%-40s %-15s %-15s %-20s %-15s\n" "$dag_id" "$ns_name" "$workflow" "$status" "$created"
        done
    fi
}

# 显示 DAG 实例详情
show_dag_instance() {
    local dag_id="$1"
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    local output_format="${3:-table}"
    
    # 如果没有指定 namespace，尝试在所有 namespace 中查找
    local dag_file=""
    if [[ "$namespace" == "auto" ]]; then
        # 自动查找
        for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
            if [[ -d "$ns_dir" ]]; then
                local ns_name=$(basename "$ns_dir")
                local candidate_file=$(get_dag_instance_file "$dag_id" "$ns_name")
                if [[ -f "$candidate_file" ]]; then
                    dag_file="$candidate_file"
                    namespace="$ns_name"
                    break
                fi
            fi
        done
    else
        dag_file=$(get_dag_instance_file "$dag_id" "$namespace")
    fi
    
    if [[ ! -f "$dag_file" ]]; then
        echo "错误: DAG 实例不存在: $dag_id (namespace: $namespace)" >&2
        return 1
    fi
    
    if [[ "$output_format" == "json" ]]; then
        cat "$dag_file" | jq .
    else
        # 表格格式显示
        echo "=== DAG 实例详情 ==="
        echo ""
        
        local dag_data=$(cat "$dag_file")
        
        echo "基本信息:"
        echo "  DAG ID: $(echo "$dag_data" | jq -r '.dag_instance_id')"
        echo "  工作流: $(echo "$dag_data" | jq -r '.workflow_name')"
        echo "  命名空间: $(echo "$dag_data" | jq -r '.namespace')"
        echo "  状态: $(echo "$dag_data" | jq -r '.status')"
        echo "  创建时间: $(echo "$dag_data" | jq -r '.created_at')"
        echo ""
        
        echo "触发信息:"
        echo "  发送者: $(echo "$dag_data" | jq -r '.trigger.sender')"
        echo "  消息: $(echo "$dag_data" | jq -r '.trigger.message')"
        echo "  时间: $(echo "$dag_data" | jq -r '.trigger.timestamp')"
        echo ""
        
        echo "节点状态:"
        echo "  当前节点: $(echo "$dag_data" | jq -r '.current_nodes | join(", ")')"
        echo "  已完成: $(echo "$dag_data" | jq -r '.completed_nodes | join(", ")')"
        echo "  被阻塞: $(echo "$dag_data" | jq -r '.blocked_nodes | join(", ")')"
        echo "  失败: $(echo "$dag_data" | jq -r '.failed_nodes | join(", ")')"
        echo ""
        
        echo "执行历史:"
        echo "$dag_data" | jq -r '.node_execution_history[] | "  [\(.started_at)] \(.node_id): \(.status)"'
        echo ""
        
        echo "消息追踪:"
        echo "$dag_data" | jq -r '.message_tracking[] | "  [\(.timestamp)] \(.sender): \(.message)"'
    fi
}

# 显示帮助
show_help() {
    echo "用法: cliExtra dag <command> [options]"
    echo ""
    echo "命令:"
    echo "  list [namespace]              列出 DAG 实例"
    echo "  show <dag_id> [namespace]     显示 DAG 实例详情"
    echo "  create <workflow> [namespace] 创建 DAG 实例"
    echo "  status [options]              显示 DAG 监控状态"
    echo "  kill <dag_id> [namespace]     终止 DAG 实例"
    echo ""
    echo "选项:"
    echo "  -o, --output <format>         输出格式: table (默认) 或 json"
    echo "  -A, --all                     显示所有 namespace 的 DAG 实例"
    echo "  -n, --namespace <ns>          指定 namespace"
    echo ""
    echo "状态命令选项:"
    echo "  --summary, -s                 显示简要统计信息 (默认)"
    echo "  --detailed, -d                显示详细状态信息"
    echo "  --timeout, -t                 显示超时检测信息"
    echo "  --json, -j                    JSON 格式输出"
    echo ""
    echo "默认行为:"
    echo "  默认只显示 'default' namespace 中的 DAG 实例"
    echo ""
    echo "示例:"
    echo "  cliExtra dag list             # 列出所有 DAG 实例"
    echo "  cliExtra dag status           # 显示监控状态摘要"
    echo "  cliExtra dag status -d        # 显示详细状态"
    echo "  cliExtra dag status -t        # 显示超时信息"
    echo "  使用 -A/--all 显示所有 namespace 的 DAG 实例"
    echo ""
    echo "示例:"
    echo "  cliExtra dag list                           # 列出默认 namespace 的 DAG"
    echo "  cliExtra dag list -A                        # 列出所有 namespace 的 DAG"
    echo "  cliExtra dag list -n simple_dev             # 列出指定 namespace 的 DAG"
    echo "  cliExtra dag show dag_simple_dev_123        # 显示 DAG 详情"
    echo "  cliExtra dag create simple-3roles-workflow  # 创建 DAG 实例"
    echo "  cliExtra dag list -o json                   # JSON 格式输出"
}

# 主逻辑
case "${1:-}" in
    "list")
        shift
        namespace=""
        output_format="table"
        
        # 解析参数
        while [[ $# -gt 0 ]]; do
            case $1 in
                -A|--all)
                    namespace="--all"
                    shift
                    ;;
                -n|--namespace)
                    namespace="$2"
                    shift 2
                    ;;
                -o|--output)
                    output_format="$2"
                    shift 2
                    ;;
                *)
                    if [[ -z "$namespace" && "$1" != "--all" && "$1" != "-A" ]]; then
                        namespace="$1"
                    fi
                    shift
                    ;;
            esac
        done
        
        list_dag_instances "$namespace" "$output_format"
        ;;
    
    "show")
        if [[ -z "$2" ]]; then
            echo "错误: 请指定 DAG ID" >&2
            show_help
            exit 1
        fi
        
        dag_id="$2"
        namespace="auto"
        output_format="table"
        
        # 解析参数
        shift 2
        while [[ $# -gt 0 ]]; do
            case $1 in
                -o|--output)
                    output_format="$2"
                    shift 2
                    ;;
                -n|--namespace)
                    namespace="$2"
                    shift 2
                    ;;
                *)
                    # 如果不是选项，可能是 namespace
                    if [[ "$namespace" == "auto" ]]; then
                        namespace="$1"
                    fi
                    shift
                    ;;
            esac
        done
        
        show_dag_instance "$dag_id" "$namespace" "$output_format"
        ;;
    
    "create")
        if [[ -z "$2" ]]; then
            echo "错误: 请指定工作流名称" >&2
            show_help
            exit 1
        fi
        
        workflow_name="$2"
        namespace="${3:-$CLIEXTRA_DEFAULT_NS}"
        trigger_message="${4:-手动启动}"
        trigger_sender="${5:-system:admin}"
        
        create_dag_instance "$workflow_name" "$namespace" "$trigger_message" "$trigger_sender"
        ;;
    
    "status")
        # 调用 DAG 状态报告脚本
        "$SCRIPT_DIR/cliExtra-dag-status.sh" "${@:2}"
        ;;
    
    "kill")
        echo "DAG 终止功能尚未实现"
        exit 1
        ;;
    
    "--help"|"-h"|"help"|"")
        show_help
        ;;
    
    *)
        echo "错误: 未知命令 '$1'" >&2
        echo ""
        show_help
        exit 1
        ;;
esac
