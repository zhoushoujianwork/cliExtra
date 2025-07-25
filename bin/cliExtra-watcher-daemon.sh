#!/bin/bash

# cliExtra Watcher Daemon - 监控 agent tmux 终端输出的守护进程
# 自动检测用户输入等待符并更新 agent 状态

# 加载配置和公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"

# 守护进程配置
DAEMON_NAME="cliExtra-watcher"
DAEMON_PID_FILE="$CLIEXTRA_HOME/watcher.pid"
DAEMON_LOG_FILE="$CLIEXTRA_HOME/watcher.log"
DAEMON_CONFIG_FILE="$CLIEXTRA_HOME/watcher.conf"

# 监控配置
MONITOR_INTERVAL=2  # 监控间隔（秒）
LOG_TAIL_LINES=5    # 检查日志的行数
IDLE_TIMEOUT=30     # 空闲超时时间（秒）

# 用户输入等待符模式（支持多种格式）
WAITING_PATTERNS=(
    "> "                           # 基本提示符
    "\\[38;5;13m> \\[39m"          # 带颜色的提示符 (你提到的格式)
    "\\[38;5;13m>\\[39m"           # 紧凑格式
    "\\[[0-9;]+m> \\[[0-9;]*m"     # 通用颜色提示符
    "\\[[0-9;]+m>\\[[0-9;]*m"      # 紧凑通用格式
    "\\[.*m> \\[.*m"               # 最宽泛的颜色匹配
    "\\[.*m>\\[.*m"                # 紧凑最宽泛格式
    "\\e\\[[0-9;]*m> \\e\\[[0-9;]*m"  # ANSI 转义序列格式
    "\\033\\[[0-9;]*m> \\033\\[[0-9;]*m"  # 八进制转义序列
    "$ "                           # Shell 提示符
    "# "                           # Root 提示符
    "? "                           # 问题提示符
    "Enter"                        # 等待回车
    "Press"                        # 等待按键
    "Continue"                     # 等待继续
    "Y/n"                          # 确认提示
    "y/N"                          # 确认提示
    "\\(y/n\\)"                    # 括号确认提示
    "\\[Y/n\\]"                    # 方括号确认提示
    "Please enter"                 # 请输入
    "Input:"                       # 输入提示
    "Choice:"                      # 选择提示
    "Select:"                      # 选择提示
)

# 忙碌状态模式
BUSY_PATTERNS=(
    "Processing"
    "Loading"
    "Analyzing"
    "Generating"
    "Compiling"
    "Building"
    "Installing"
    "Downloading"
    "Uploading"
    "Executing"
    "Running"
    "Working"
    "Please wait"
    "..."
)

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

# 获取 tmux 会话的最新输出
get_session_output() {
    local session_name="$1"
    local lines="${2:-$LOG_TAIL_LINES}"
    
    # 使用 tmux capture-pane 获取最新输出
    tmux capture-pane -t "$session_name" -p -S "-$lines" 2>/dev/null || echo ""
}

# 检查输出是否匹配等待模式
matches_waiting_pattern() {
    local output="$1"
    
    for pattern in "${WAITING_PATTERNS[@]}"; do
        if echo "$output" | grep -qE "$pattern"; then
            return 0
        fi
    done
    return 1
}

# 检查输出是否匹配忙碌模式
matches_busy_pattern() {
    local output="$1"
    
    for pattern in "${BUSY_PATTERNS[@]}"; do
        if echo "$output" | grep -qiE "$pattern"; then
            return 0
        fi
    done
    return 1
}

# 分析 agent 状态
analyze_agent_status() {
    local instance_id="$1"
    local session_name="q_instance_$instance_id"
    
    # 获取最新输出
    local output=$(get_session_output "$session_name")
    
    if [[ -z "$output" ]]; then
        log_message "DEBUG" "No output from $instance_id"
        return 2  # 无法确定状态
    fi
    
    # 检查是否在等待用户输入
    if matches_waiting_pattern "$output"; then
        log_message "DEBUG" "Agent $instance_id is waiting for input"
        return 0  # 空闲状态
    fi
    
    # 检查是否在忙碌处理
    if matches_busy_pattern "$output"; then
        log_message "DEBUG" "Agent $instance_id is busy"
        return 1  # 忙碌状态
    fi
    
    # 检查最后一行是否为空或只有提示符
    local last_line=$(echo "$output" | tail -n 1 | xargs)
    if [[ -z "$last_line" ]] || [[ "$last_line" == ">" ]] || [[ "$last_line" == "$" ]] || [[ "$last_line" == "#" ]]; then
        log_message "DEBUG" "Agent $instance_id appears idle (empty/prompt line)"
        return 0  # 空闲状态
    fi
    
    log_message "DEBUG" "Agent $instance_id status unclear, keeping current state"
    return 2  # 无法确定，保持当前状态
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
            local status_name=$(status_to_name "$new_status")
            log_message "INFO" "Updated agent $instance_id status: $current_status -> $new_status ($status_name)"
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
    
    while true; do
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
    echo "  - 自动监控所有 agent 的 tmux 终端输出"
    echo "  - 检测用户输入等待符（如 '> '）判断空闲状态"
    echo "  - 检测忙碌关键词判断工作状态"
    echo "  - 自动更新 agent 状态文件（0=idle, 1=busy）"
    echo ""
    echo "配置:"
    echo "  监控间隔: ${MONITOR_INTERVAL}s"
    echo "  日志文件: $DAEMON_LOG_FILE"
    echo "  PID文件: $DAEMON_PID_FILE"
    echo ""
    echo "示例:"
    echo "  $0 start    # 启动监控"
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
