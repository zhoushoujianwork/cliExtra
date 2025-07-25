#!/bin/bash

# cliExtra DAG 状态报告
# 显示 DAG 监控的详细状态信息

# 加载依赖
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra dag-status [options]"
    echo ""
    echo "选项:"
    echo "  --summary, -s     显示简要统计信息"
    echo "  --detailed, -d    显示详细状态信息"
    echo "  --timeout, -t     显示超时检测信息"
    echo "  --json, -j        JSON 格式输出"
    echo "  --help, -h        显示此帮助信息"
    echo ""
    echo "功能说明:"
    echo "  显示 DAG 监控系统的运行状态和统计信息"
}

# 获取 DAG 统计信息
get_dag_statistics() {
    local total_dags=0
    local running_dags=0
    local completed_dags=0
    local failed_dags=0
    local timeout_dags=0
    
    if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
        while IFS= read -r -d '' ns_dir; do
            local dag_dir="$ns_dir/dags"
            if [[ -d "$dag_dir" ]]; then
                while IFS= read -r -d '' dag_file; do
                    if [[ -f "$dag_file" ]]; then
                        total_dags=$((total_dags + 1))
                        local status=$(jq -r '.status' "$dag_file" 2>/dev/null)
                        local failure_type=$(jq -r '.failure_reason.type // empty' "$dag_file" 2>/dev/null)
                        
                        case "$status" in
                            "running")
                                running_dags=$((running_dags + 1))
                                ;;
                            "completed")
                                completed_dags=$((completed_dags + 1))
                                ;;
                            "failed")
                                failed_dags=$((failed_dags + 1))
                                if [[ "$failure_type" == "instance_timeout" || "$failure_type" == "node_timeout" ]]; then
                                    timeout_dags=$((timeout_dags + 1))
                                fi
                                ;;
                        esac
                    fi
                done < <(find "$dag_dir" -name "dag_*.json" -print0 2>/dev/null)
            fi
        done < <(find "$CLIEXTRA_HOME/namespaces" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    fi
    
    echo "$total_dags $running_dags $completed_dags $failed_dags $timeout_dags"
}

# 显示简要统计信息
show_summary() {
    local stats=($(get_dag_statistics))
    local total_dags=${stats[0]}
    local running_dags=${stats[1]}
    local completed_dags=${stats[2]}
    local failed_dags=${stats[3]}
    local timeout_dags=${stats[4]}
    
    echo "=== DAG 监控状态摘要 ==="
    echo ""
    echo "总 DAG 实例数: $total_dags"
    echo "  运行中: $running_dags"
    echo "  已完成: $completed_dags"
    echo "  失败: $failed_dags"
    echo "  超时失败: $timeout_dags"
    echo ""
    
    # 检查守护进程状态
    local daemon_pid_file="$CLIEXTRA_HOME/engine.pid"
    if [[ -f "$daemon_pid_file" ]]; then
        local daemon_pid=$(cat "$daemon_pid_file")
        if kill -0 "$daemon_pid" 2>/dev/null; then
            echo "守护进程状态: ✅ 运行中 (PID: $daemon_pid)"
        else
            echo "守护进程状态: ❌ 未运行"
        fi
    else
        echo "守护进程状态: ❌ 未启动"
    fi
}

# 显示详细状态信息
show_detailed() {
    echo "=== DAG 监控详细状态 ==="
    echo ""
    
    # 显示所有 namespace 的 DAG 信息
    if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
        while IFS= read -r -d '' ns_dir; do
            local namespace=$(basename "$ns_dir")
            local dag_dir="$ns_dir/dags"
            
            if [[ -d "$dag_dir" ]]; then
                local dag_count=$(find "$dag_dir" -name "dag_*.json" 2>/dev/null | wc -l)
                if [[ $dag_count -gt 0 ]]; then
                    echo "Namespace: $namespace ($dag_count DAGs)"
                    echo "----------------------------------------"
                    
                    while IFS= read -r -d '' dag_file; do
                        if [[ -f "$dag_file" ]]; then
                            local dag_id=$(jq -r '.dag_instance_id' "$dag_file" 2>/dev/null)
                            local status=$(jq -r '.status' "$dag_file" 2>/dev/null)
                            local created_at=$(jq -r '.created_at' "$dag_file" 2>/dev/null)
                            local workflow_name=$(jq -r '.workflow_name' "$dag_file" 2>/dev/null)
                            
                            # 计算运行时间
                            local created_timestamp=$(date -d "$created_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${created_at%+*}" +%s 2>/dev/null)
                            local current_timestamp=$(date +%s)
                            local runtime=$((current_timestamp - created_timestamp))
                            local runtime_str=$(format_duration $runtime)
                            
                            # 状态图标
                            local status_icon=""
                            case "$status" in
                                "running") status_icon="🔄" ;;
                                "completed") status_icon="✅" ;;
                                "failed") status_icon="❌" ;;
                                *) status_icon="❓" ;;
                            esac
                            
                            echo "  $status_icon $dag_id"
                            echo "    工作流: $workflow_name"
                            echo "    状态: $status"
                            echo "    运行时间: $runtime_str"
                            
                            # 显示失败原因
                            if [[ "$status" == "failed" ]]; then
                                local failure_message=$(jq -r '.failure_reason.message // empty' "$dag_file" 2>/dev/null)
                                if [[ -n "$failure_message" ]]; then
                                    echo "    失败原因: $failure_message"
                                fi
                            fi
                            
                            echo ""
                        fi
                    done < <(find "$dag_dir" -name "dag_*.json" -print0 2>/dev/null)
                fi
            fi
        done < <(find "$CLIEXTRA_HOME/namespaces" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    fi
}

# 显示超时检测信息
show_timeout_info() {
    echo "=== DAG 超时检测配置 ==="
    echo ""
    echo "节点执行超时: 30 分钟 (1800 秒)"
    echo "DAG 实例超时: 2 小时 (7200 秒)"
    echo "监控间隔: 10 秒"
    echo "清理间隔: 1 小时"
    echo ""
    
    echo "=== 超时 DAG 实例 ==="
    echo ""
    
    local found_timeout=false
    if [[ -d "$CLIEXTRA_HOME/namespaces" ]]; then
        while IFS= read -r -d '' ns_dir; do
            local namespace=$(basename "$ns_dir")
            local dag_dir="$ns_dir/dags"
            
            if [[ -d "$dag_dir" ]]; then
                while IFS= read -r -d '' dag_file; do
                    if [[ -f "$dag_file" ]]; then
                        local status=$(jq -r '.status' "$dag_file" 2>/dev/null)
                        local failure_type=$(jq -r '.failure_reason.type // empty' "$dag_file" 2>/dev/null)
                        
                        if [[ "$status" == "failed" && ("$failure_type" == "instance_timeout" || "$failure_type" == "node_timeout") ]]; then
                            found_timeout=true
                            local dag_id=$(jq -r '.dag_instance_id' "$dag_file" 2>/dev/null)
                            local failure_message=$(jq -r '.failure_reason.message' "$dag_file" 2>/dev/null)
                            local failed_at=$(jq -r '.failed_at' "$dag_file" 2>/dev/null)
                            
                            echo "❌ $dag_id ($namespace)"
                            echo "   类型: $failure_type"
                            echo "   原因: $failure_message"
                            echo "   时间: $failed_at"
                            echo ""
                        fi
                    fi
                done < <(find "$dag_dir" -name "dag_*.json" -print0 2>/dev/null)
            fi
        done < <(find "$CLIEXTRA_HOME/namespaces" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    fi
    
    if [[ "$found_timeout" == false ]]; then
        echo "没有发现超时的 DAG 实例"
    fi
}

# 格式化持续时间
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [[ $hours -gt 0 ]]; then
        echo "${hours}h ${minutes}m ${secs}s"
    elif [[ $minutes -gt 0 ]]; then
        echo "${minutes}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

# JSON 格式输出
show_json() {
    local stats=($(get_dag_statistics))
    local total_dags=${stats[0]}
    local running_dags=${stats[1]}
    local completed_dags=${stats[2]}
    local failed_dags=${stats[3]}
    local timeout_dags=${stats[4]}
    
    # 检查守护进程状态
    local daemon_running=false
    local daemon_pid=""
    local daemon_pid_file="$CLIEXTRA_HOME/engine.pid"
    if [[ -f "$daemon_pid_file" ]]; then
        daemon_pid=$(cat "$daemon_pid_file")
        if kill -0 "$daemon_pid" 2>/dev/null; then
            daemon_running=true
        fi
    fi
    
    cat << EOF
{
  "summary": {
    "total_dags": $total_dags,
    "running_dags": $running_dags,
    "completed_dags": $completed_dags,
    "failed_dags": $failed_dags,
    "timeout_dags": $timeout_dags
  },
  "daemon": {
    "running": $daemon_running,
    "pid": "$daemon_pid"
  },
  "config": {
    "node_timeout": 1800,
    "instance_timeout": 7200,
    "monitor_interval": 10,
    "cleanup_interval": 3600
  }
}
EOF
}

# 主逻辑
case "${1:-}" in
    --summary|-s)
        show_summary
        ;;
    --detailed|-d)
        show_detailed
        ;;
    --timeout|-t)
        show_timeout_info
        ;;
    --json|-j)
        show_json
        ;;
    --help|-h|help)
        show_help
        ;;
    "")
        show_summary
        ;;
    *)
        echo "错误: 未知选项 '${1:-}'"
        echo ""
        show_help
        exit 1
        ;;
esac
