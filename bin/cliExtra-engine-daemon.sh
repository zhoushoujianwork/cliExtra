#!/bin/bash

# cliExtra Watcher Daemon - 监控 agent tmux 终端输出的守护进程
# 自动检测用户输入等待符并更新 agent 状态

# 加载配置和公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"
source "$SCRIPT_DIR/cliExtra-status-engine.sh"
source "$SCRIPT_DIR/cliExtra-dag-monitor.sh"
source "$SCRIPT_DIR/cliExtra-restart-manager.sh"

# 守护进程配置
DAEMON_NAME="cliExtra-engine"
DAEMON_PID_FILE="$CLIEXTRA_HOME/engine.pid"
DAEMON_LOG_FILE="$CLIEXTRA_HOME/engine.log"
DAEMON_CONFIG_FILE="$CLIEXTRA_HOME/engine.conf"

# 监控配置 - 基于时间戳检测
MONITOR_INTERVAL=3  # 监控间隔（秒）
DEFAULT_IDLE_THRESHOLD=5    # 默认空闲阈值（秒）
SYSTEM_CHECK_INTERVAL=60    # system agent 检查间隔（秒）

# DAG 监控配置
DAG_MONITOR_INTERVAL=10       # DAG 监控间隔（秒）
DAG_NODE_TIMEOUT=1800         # 节点执行超时时间（30分钟）
DAG_INSTANCE_TIMEOUT=7200     # DAG 实例总超时时间（2小时）
DAG_CLEANUP_INTERVAL=3600     # 清理间隔（1小时）

# 自动重启配置
AUTO_RESTART_ENABLED=true     # 启用自动重启
RESTART_CHECK_INTERVAL=30     # 重启检查间隔（秒）
RESTART_CLEANUP_INTERVAL=1800 # 重启记录清理间隔（30分钟）

# 日志函数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$DAEMON_LOG_FILE"
    
    # 如果不是守护进程模式，也输出到控制台
    if [[ "$DAEMON_MODE" != "true" ]]; then
        echo "[$timestamp] [$level] $message"
    fi
}

# 检查守护进程是否运行
is_daemon_running() {
    if [[ -f "$DAEMON_PID_FILE" ]]; then
        local pid=$(cat "$DAEMON_PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            # PID 文件存在但进程不存在，清理
            rm -f "$DAEMON_PID_FILE"
            return 1
        fi
    fi
    return 1
}

# 获取所有活跃的 agent 实例
get_active_agents() {
    local agents=()
    
    # 遍历所有 tmux 会话
    while IFS= read -r session_line; do
        if [[ "$session_line" =~ ^q_instance_(.+)$ ]]; then
            local instance_id="${BASH_REMATCH[1]}"
            agents+=("$instance_id")
        fi
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null || true)
    
    printf '%s\n' "${agents[@]}"
}

# 获取 agent 的空闲阈值配置
get_agent_threshold() {
    local instance_id="$1"
    local namespace=$(get_instance_namespace "$instance_id")
    
    if [[ -z "$namespace" ]]; then
        namespace="$CLIEXTRA_DEFAULT_NS"
    fi
    
    # 获取 namespace 特定的阈值配置
    local threshold=$(get_threshold_for_namespace "$namespace")
    echo "$threshold"
}

# 基于时间戳分析 agent 状态
analyze_agent_status() {
    local instance_id="$1"
    local namespace=$(get_instance_namespace "$instance_id")
    
    if [[ -z "$namespace" ]]; then
        namespace="$CLIEXTRA_DEFAULT_NS"
    fi
    
    # 获取阈值配置
    local threshold=$(get_agent_threshold "$instance_id")
    
    # 使用新的时间戳检测引擎
    local status=$(detect_instance_status_by_timestamp "$instance_id" "$namespace" "$threshold")
    
    case "$status" in
        "idle")
            log_message "DEBUG" "Agent $instance_id is idle (threshold: ${threshold}s)"
            return 0  # 空闲状态
            ;;
        "busy")
            log_message "DEBUG" "Agent $instance_id is busy (threshold: ${threshold}s)"
            return 1  # 忙碌状态
            ;;
        "unknown")
            log_message "DEBUG" "Agent $instance_id status unknown"
            return 2  # 无法确定状态
            ;;
        *)
            log_message "WARN" "Agent $instance_id returned unexpected status: $status"
            return 2  # 无法确定状态
            ;;
    esac
}

# 更新 agent 状态
update_agent_status() {
    local instance_id="$1"
    local new_status="$2"  # 0=idle, 1=busy
    
    # 获取 agent 的 namespace
    local namespace=$(get_instance_namespace "$instance_id")
    if [[ -z "$namespace" ]]; then
        namespace="$CLIEXTRA_DEFAULT_NS"
    fi
    
    # 读取当前状态
    local current_status=$(read_status_file "$instance_id" "$namespace")
    
    # 如果状态发生变化，更新状态文件
    if [[ "$current_status" != "$new_status" ]]; then
        if update_status_file "$instance_id" "$new_status" "$namespace"; then
            local old_status_name=$(status_to_name "$current_status")
            local new_status_name=$(status_to_name "$new_status")
            local change_timestamp=$(date +%s)
            
            log_message "INFO" "Updated agent $instance_id status: $current_status -> $new_status ($new_status_name)"
            
            # 调用状态变化钩子函数（如果存在）
            if declare -f status_change_hook > /dev/null 2>&1; then
                status_change_hook "$instance_id" "$namespace" "$old_status_name" "$new_status_name" "$change_timestamp"
            fi
        else
            log_message "ERROR" "Failed to update agent $instance_id status"
        fi
    fi
}

# 监控单个 agent
monitor_agent() {
    local instance_id="$1"
    
    # 检查 tmux 会话是否存在
    local session_name="q_instance_$instance_id"
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        log_message "WARN" "Agent $instance_id session not found, removing from monitoring"
        return 1
    fi
    
    # 分析状态
    analyze_agent_status "$instance_id"
    local status_result=$?
    
    case $status_result in
        0)  # 空闲
            update_agent_status "$instance_id" "0"
            ;;
        1)  # 忙碌
            update_agent_status "$instance_id" "1"
            ;;
        2)  # 无法确定，保持当前状态
            log_message "DEBUG" "Agent $instance_id status unchanged"
            ;;
    esac
}

# 主监控循环
monitor_loop() {
    log_message "INFO" "Watcher daemon started (PID: $$)"
    
    local cycle_count=0
    local dag_monitor_cycle=0
    local system_check_cycle=0
    local cleanup_cycle=0
    local restart_check_cycle=0
    local restart_cleanup_cycle=0
    
    # 计算监控周期
    local dag_monitor_interval=$((DAG_MONITOR_INTERVAL / MONITOR_INTERVAL))
    local system_check_interval_cycles=$((SYSTEM_CHECK_INTERVAL / MONITOR_INTERVAL))
    local cleanup_interval_cycles=$((DAG_CLEANUP_INTERVAL / MONITOR_INTERVAL))
    local restart_check_interval_cycles=$((RESTART_CHECK_INTERVAL / MONITOR_INTERVAL))
    local restart_cleanup_interval_cycles=$((RESTART_CLEANUP_INTERVAL / MONITOR_INTERVAL))
    
    while true; do
        cycle_count=$((cycle_count + 1))
        
        # 获取活跃的 agent 列表
        local agents=($(get_active_agents))
        
        if [[ ${#agents[@]} -eq 0 ]]; then
            log_message "DEBUG" "No active agents found"
        else
            log_message "DEBUG" "Monitoring ${#agents[@]} agents: ${agents[*]}"
            
            # 监控每个 agent
            for agent in "${agents[@]}"; do
                monitor_agent "$agent"
            done
        fi
        
        # 自动重启检查（每 30 秒执行一次）
        if [[ "$AUTO_RESTART_ENABLED" == "true" && $((cycle_count % restart_check_interval_cycles)) -eq 0 ]]; then
            log_message "DEBUG" "Running auto-restart check cycle"
            
            # 检查所有已知实例是否需要重启
            for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
                if [[ ! -d "$ns_dir/instances" ]]; then
                    continue
                fi
                
                for instance_dir in "$ns_dir/instances"/instance_*; do
                    if [[ ! -d "$instance_dir" ]]; then
                        continue
                    fi
                    
                    local instance_id
                    instance_id=$(basename "$instance_dir" | sed 's/^instance_//')
                    
                    if [[ -n "$instance_id" ]]; then
                        check_instance_for_restart "$instance_id"
                    fi
                done
            done
        fi
        
        # DAG 监控（每 30 秒执行一次）
        if [[ $((cycle_count % dag_monitor_interval)) -eq 0 ]]; then
            log_message "DEBUG" "Running DAG monitoring cycle"
            monitor_dags
        fi
        
        # System agent 检查（每 60 秒执行一次）
        if [[ $((cycle_count % system_check_interval_cycles)) -eq 0 ]]; then
            log_message "DEBUG" "Running system agent check cycle"
            check_and_fix_system_agents
        fi
        
        # DAG 清理（每 1 小时执行一次）
        if [[ $((cycle_count % cleanup_interval_cycles)) -eq 0 ]]; then
            log_message "DEBUG" "Running DAG cleanup cycle"
            cleanup_expired_dags
        fi
        
        # 重启记录清理（每 30 分钟执行一次）
        if [[ $((cycle_count % restart_cleanup_interval_cycles)) -eq 0 ]]; then
            log_message "DEBUG" "Running restart records cleanup cycle"
            cleanup_restart_records
        fi
        
        # 等待下一次检查
        sleep "$MONITOR_INTERVAL"
    done
}

# 启动守护进程
start_daemon() {
    if is_daemon_running; then
        echo "Watcher daemon is already running (PID: $(cat "$DAEMON_PID_FILE"))"
        return 1
    fi
    
    echo "Starting watcher daemon..."
    
    # 确保日志目录存在
    mkdir -p "$(dirname "$DAEMON_LOG_FILE")"
    
    # 启动守护进程
    DAEMON_MODE=true nohup "$0" --daemon > /dev/null 2>&1 &
    local daemon_pid=$!
    
    # 保存 PID
    echo "$daemon_pid" > "$DAEMON_PID_FILE"
    
    # 等待一下确保启动成功
    sleep 2
    
    if is_daemon_running; then
        echo "✓ Watcher daemon started successfully (PID: $daemon_pid)"
        echo "  Log file: $DAEMON_LOG_FILE"
        echo "  PID file: $DAEMON_PID_FILE"
        return 0
    else
        echo "❌ Failed to start watcher daemon"
        return 1
    fi
}

# 停止守护进程
stop_daemon() {
    if ! is_daemon_running; then
        echo "Watcher daemon is not running"
        return 1
    fi
    
    local pid=$(cat "$DAEMON_PID_FILE")
    echo "Stopping watcher daemon (PID: $pid)..."
    
    # 发送 TERM 信号
    if kill "$pid" 2>/dev/null; then
        # 等待进程结束
        local count=0
        while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
            sleep 1
            count=$((count + 1))
        done
        
        # 如果还没结束，强制杀死
        if kill -0 "$pid" 2>/dev/null; then
            echo "Force killing daemon..."
            kill -9 "$pid" 2>/dev/null
        fi
        
        # 清理 PID 文件
        rm -f "$DAEMON_PID_FILE"
        echo "✓ Watcher daemon stopped"
        return 0
    else
        echo "❌ Failed to stop watcher daemon"
        return 1
    fi
}

# 显示守护进程状态
show_daemon_status() {
    if is_daemon_running; then
        local pid=$(cat "$DAEMON_PID_FILE")
        echo "✓ Watcher daemon is running (PID: $pid)"
        
        # 显示监控的 agent 数量
        local agents=($(get_active_agents))
        echo "  Monitoring ${#agents[@]} agents: ${agents[*]}"
        
        # 显示日志文件信息
        if [[ -f "$DAEMON_LOG_FILE" ]]; then
            local log_size=$(wc -l < "$DAEMON_LOG_FILE" 2>/dev/null || echo "0")
            echo "  Log entries: $log_size"
            echo "  Log file: $DAEMON_LOG_FILE"
        fi
        
        # 显示最近的日志
        echo ""
        echo "Recent log entries:"
        tail -n 5 "$DAEMON_LOG_FILE" 2>/dev/null || echo "  (no log entries)"
        
    else
        echo "❌ Watcher daemon is not running"
        return 1
    fi
}

# 显示帮助
show_help() {
    echo "用法: $0 <command> [options]"
    echo ""
    echo "命令:"
    echo "  start     启动监控守护进程"
    echo "  stop      停止监控守护进程"
    echo "  status    显示守护进程状态"
    echo "  restart   重启监控守护进程"
    echo "  --daemon  守护进程模式（内部使用）"
    echo ""
    echo "功能:"
    echo "  - 基于文件时间戳的高效状态检测"
    echo "  - 监控 tmux.log 文件修改时间判断 agent 活跃度"
    echo "  - 自动更新 agent 状态文件（0=idle, 1=busy）"
    echo "  - 支持按 namespace 配置不同的空闲阈值"
    echo "  - 跨平台兼容（macOS/Linux）"
    echo "  - 🔄 自动重启功能（类似 k8s pod）"
    echo "  - 📊 重启次数和失败原因记录"
    echo "  - 🛡️ 指数退避重启策略"
    echo ""
    echo "检测原理:"
    echo "  - 空闲检测: tmux.log 文件超过阈值时间未更新"
    echo "  - 忙碌检测: tmux.log 文件在阈值时间内有更新"
    echo "  - 默认阈值: ${DEFAULT_IDLE_THRESHOLD}秒"
    echo ""
    echo "自动重启功能:"
    echo "  - 检测 tmux 会话异常退出"
    echo "  - 记录失败原因和重启次数"
    echo "  - 指数退避重启延迟（5s -> 10s -> 20s -> ... -> 300s）"
    echo "  - 最大重启次数限制（10次）"
    echo "  - 支持重启策略：Always, OnFailure, Never"
    echo ""
    echo "配置:"
    echo "  监控间隔: ${MONITOR_INTERVAL}s"
    echo "  默认阈值: ${DEFAULT_IDLE_THRESHOLD}s"
    echo "  重启检查: ${RESTART_CHECK_INTERVAL}s"
    echo "  自动重启: ${AUTO_RESTART_ENABLED}"
    echo "  日志文件: $DAEMON_LOG_FILE"
    echo "  PID文件: $DAEMON_PID_FILE"
    echo ""
    echo "示例:"
    echo "  $0 start    # 启动监控（包含自动重启）"
    echo "  $0 status   # 查看状态"
    echo "  $0 stop     # 停止监控"
}

# 信号处理
cleanup() {
    log_message "INFO" "Watcher daemon shutting down..."
    rm -f "$DAEMON_PID_FILE"
    exit 0
}

# 设置信号处理
trap cleanup TERM INT

# 主逻辑
case "${1:-}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    status)
        show_daemon_status
        ;;
    restart)
        stop_daemon
        sleep 2
        start_daemon
        ;;
    --daemon)
        # 守护进程模式
        monitor_loop
        ;;
    --help|-h|help)
        show_help
        ;;
    *)
        echo "错误: 未知命令 '${1:-}'"
        echo ""
        show_help
        exit 1
        ;;
esac
