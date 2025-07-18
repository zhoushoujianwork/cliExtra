#!/bin/bash

# 持续运行的q CLI实例管理脚本
# 支持会话保持和上下文管理

FIFO_DIR="/tmp/q_chat_persistent"
LOG_FILE="/tmp/persistent_q_chat.log"
SESSIONS_DIR="/tmp/q_chat_sessions"

# 创建必要的目录
mkdir -p "$FIFO_DIR"
mkdir -p "$SESSIONS_DIR"

echo "=== 持续运行q CLI实例管理系统 ==="
echo "FIFO目录: $FIFO_DIR"
echo "会话目录: $SESSIONS_DIR"
echo "日志文件: $LOG_FILE"

# 启动持续运行的q CLI实例
start_persistent_instance() {
    local instance_id="$1"
    local session_dir="$SESSIONS_DIR/instance_$instance_id"
    local fifo_path="$FIFO_DIR/q_instance_$instance_id"
    local output_log="$session_dir/output.log"
    local input_log="$session_dir/input.log"
    
    echo "$(date): 启动持续运行实例 $instance_id" >> "$LOG_FILE"
    
    # 创建会话目录
    mkdir -p "$session_dir"
    
    # 创建FIFO
    mkfifo "$fifo_path" 2>/dev/null
    
    # 创建日志文件
    touch "$output_log" "$input_log"
    
    echo "启动持续运行q CLI实例 $instance_id"
    echo "会话目录: $session_dir"
    echo "FIFO: $fifo_path"
    echo "输出日志: $output_log"
    echo "输入日志: $input_log"
    
    # 切换到会话目录
    cd "$session_dir"
    
    # 启动持续运行的q CLI实例
    while true; do
        if [ -p "$fifo_path" ]; then
            if read -r input < "$fifo_path" 2>/dev/null; then
                # 记录输入到日志
                echo "$(date '+%Y-%m-%d %H:%M:%S') [INPUT]: $input" >> "$input_log"
                echo "$(date): 实例 $instance_id 收到: $input" >> "$LOG_FILE"
                
                # 执行q命令并记录输出
                echo "$input" | q chat --no-interactive --trust-all-tools --resume 2>&1 | while IFS= read -r line; do
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [OUTPUT]: $line" >> "$output_log"
                    echo "$line"
                done
                
                # 等待一下确保处理完成
                sleep 0.5
            fi
        else
            sleep 1
        fi
    done
}

# 发送消息到指定实例
send_to_instance() {
    local instance_id="$1"
    local message="$2"
    local fifo_path="$FIFO_DIR/q_instance_$instance_id"
    
    if [ -p "$fifo_path" ]; then
        echo "$message" > "$fifo_path"
        echo "$(date): 发送到实例 $instance_id: $message" >> "$LOG_FILE"
        echo "✓ 消息已发送到实例 $instance_id: $message"
    else
        echo "✗ 实例 $instance_id 的FIFO不存在，请先启动实例"
    fi
}

# 启动后台实例
start_background_instance() {
    local instance_id="$1"
    
    # 检查实例是否已经在运行
    if [ -p "$FIFO_DIR/q_instance_$instance_id" ]; then
        echo "实例 $instance_id 已经在运行"
        return
    fi
    
    echo "启动后台实例 $instance_id..."
    start_persistent_instance "$instance_id" &
    
    # 保存进程ID
    echo $! > "$FIFO_DIR/pid_$instance_id"
    echo "$(date): 实例 $instance_id 进程ID: $!" >> "$LOG_FILE"
    
    # 等待一下确保实例启动
    sleep 2
    echo "✓ 实例 $instance_id 已在后台启动"
}

# 停止实例
stop_instance() {
    local instance_id="$1"
    local pid_file="$FIFO_DIR/pid_$instance_id"
    local fifo_path="$FIFO_DIR/q_instance_$instance_id"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        kill "$pid" 2>/dev/null
        rm -f "$pid_file"
        echo "$(date): 停止实例 $instance_id (PID: $pid)" >> "$LOG_FILE"
        echo "✓ 实例 $instance_id 已停止"
    fi
    
    rm -f "$fifo_path"
}

# 列出所有实例
list_instances() {
    echo "当前活跃的q CLI实例:"
    for fifo in "$FIFO_DIR"/q_instance_*; do
        if [ -p "$fifo" ]; then
            instance_id=$(basename "$fifo" | sed 's/q_instance_//')
            pid_file="$FIFO_DIR/pid_$instance_id"
            if [ -f "$pid_file" ]; then
                pid=$(cat "$pid_file")
                echo "  实例 $instance_id: PID=$pid, FIFO=$fifo"
            else
                echo "  实例 $instance_id: FIFO=$fifo (无PID文件)"
            fi
        fi
    done
}

# 监控实例输出
monitor_instance() {
    local instance_id="$1"
    local session_dir="$SESSIONS_DIR/instance_$instance_id"
    local output_log="$session_dir/output.log"
    
    if [ -f "$output_log" ]; then
        echo "监控实例 $instance_id 的输出..."
        tail -f "$output_log"
    else
        echo "实例 $instance_id 的输出日志不存在: $output_log"
    fi
}

# 查看实例日志
view_logs() {
    local instance_id="$1"
    local log_type="${2:-output}"  # output 或 input
    local lines="${3:-50}"
    local session_dir="$SESSIONS_DIR/instance_$instance_id"
    local log_file="$session_dir/${log_type}.log"
    
    if [ -f "$log_file" ]; then
        echo "=== 实例 $instance_id 的 $log_type 日志 (最近 $lines 行) ==="
        tail -n "$lines" "$log_file"
    else
        echo "日志文件不存在: $log_file"
    fi
}

# 清理所有实例
clean_all() {
    echo "清理所有实例..."
    
    # 停止所有实例
    for pid_file in "$FIFO_DIR"/pid_*; do
        if [ -f "$pid_file" ]; then
            instance_id=$(basename "$pid_file" | sed 's/pid_//')
            stop_instance "$instance_id"
        fi
    done
    
    # 清理FIFO
    rm -f "$FIFO_DIR"/q_instance_*
    rm -f "$FIFO_DIR"/pid_*
    
    echo "$(date): 清理所有实例" >> "$LOG_FILE"
    echo "✓ 所有实例已清理"
}

# 显示帮助
show_help() {
    echo ""
    echo "=== 持续运行q CLI实例管理系统 ==="
    echo "用法:"
    echo "  $0 start <instance_id>     - 启动指定实例（前台）"
    echo "  $0 start-bg <instance_id>  - 启动指定实例（后台）"
    echo "  $0 send <instance_id> <msg> - 发送消息到指定实例"
    echo "  $0 stop <instance_id>      - 停止指定实例"
    echo "  $0 list                    - 列出所有实例"
    echo "  $0 monitor <instance_id>   - 实时监控指定实例输出"
    echo "  $0 logs <instance_id> [type] [lines] - 查看实例日志"
    echo "  $0 clean-all               - 清理所有实例"
    echo "  $0 help                    - 显示此帮助"
    echo ""
    echo "示例:"
    echo "  $0 start-bg 1              # 启动后台实例1"
    echo "  $0 send 1 '你好，实例1!'     # 发送消息到实例1"
    echo "  $0 logs 1 output 20        # 查看实例1最近20行输出日志"
    echo "  $0 logs 1 input            # 查看实例1输入日志"
    echo "  $0 monitor 1               # 实时监控实例1输出"
    echo ""
    echo "会话保持:"
    echo "  使用 --resume 参数保持会话上下文"
    echo "  每个实例有独立的会话目录"
    echo ""
}

# 主逻辑
case "${1:-}" in
    "start")
        if [ -n "$2" ]; then
            start_persistent_instance "$2"
        else
            echo "用法: $0 start <instance_id>"
        fi
        ;;
    "start-bg")
        if [ -n "$2" ]; then
            start_background_instance "$2"
        else
            echo "用法: $0 start-bg <instance_id>"
        fi
        ;;
    "send")
        if [ -n "$2" ] && [ -n "$3" ]; then
            send_to_instance "$2" "$3"
        else
            echo "用法: $0 send <instance_id> <message>"
        fi
        ;;
    "stop")
        if [ -n "$2" ]; then
            stop_instance "$2"
        else
            echo "用法: $0 stop <instance_id>"
        fi
        ;;
    "list")
        list_instances
        ;;
    "monitor")
        if [ -n "$2" ]; then
            monitor_instance "$2"
        else
            echo "用法: $0 monitor <instance_id>"
        fi
        ;;
    "logs")
        if [ -n "$2" ]; then
            view_logs "$2" "$3" "$4"
        else
            echo "用法: $0 logs <instance_id> [type] [lines]"
            echo "type: output(默认) 或 input"
            echo "lines: 显示行数(默认50)"
        fi
        ;;
    "clean-all")
        clean_all
        ;;
    "help"|"")
        show_help
        ;;
    *)
        echo "未知命令: $1"
        show_help
        ;;
esac 