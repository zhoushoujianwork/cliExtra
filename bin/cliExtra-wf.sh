#!/bin/bash

# cliExtra Watcher (wf) 命令 - 监控守护进程管理

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra wf <command> [options]"
    echo ""
    echo "命令:"
    echo "  start     启动 agent 监控守护进程"
    echo "  stop      停止 agent 监控守护进程"
    echo "  status    显示监控守护进程状态"
    echo "  restart   重启监控守护进程"
    echo "  logs      查看监控日志"
    echo ""
    echo "功能说明:"
    echo "  监控守护进程会自动："
    echo "  - 监控所有 agent 的 tmux 终端输出"
    echo "  - 检测用户输入等待符（如 '> '）判断空闲状态"
    echo "  - 检测忙碌关键词判断工作状态"
    echo "  - 自动更新 agent 状态文件（0=idle, 1=busy）"
    echo ""
    echo "等待符检测模式:"
    echo "  - '> '                    # 基本提示符"
    echo "  - '\\[38;5;13m> \\[39m'   # 带颜色的提示符"
    echo "  - 'Enter', 'Press', 'Y/n' # 各种等待提示"
    echo ""
    echo "忙碌状态检测:"
    echo "  - 'Processing', 'Loading', 'Analyzing'"
    echo "  - 'Generating', 'Building', 'Working'"
    echo "  - 'Please wait', '...' 等"
    echo ""
    echo "示例:"
    echo "  cliExtra wf start    # 启动监控"
    echo "  cliExtra wf status   # 查看状态"
    echo "  cliExtra wf logs     # 查看日志"
    echo "  cliExtra wf stop     # 停止监控"
}

# 查看监控日志
show_logs() {
    local lines="${1:-20}"
    local log_file="$CLIEXTRA_HOME/watcher.log"
    
    if [[ ! -f "$log_file" ]]; then
        echo "监控日志文件不存在: $log_file"
        echo "请先启动监控守护进程: qq wf start"
        return 1
    fi
    
    echo "=== Watcher Daemon Logs (最近 $lines 行) ==="
    echo "日志文件: $log_file"
    echo ""
    
    tail -n "$lines" "$log_file"
}

# 主逻辑
DAEMON_SCRIPT="$SCRIPT_DIR/cliExtra-watcher-daemon.sh"

case "${1:-}" in
    start)
        "$DAEMON_SCRIPT" start
        ;;
    stop)
        "$DAEMON_SCRIPT" stop
        ;;
    status)
        "$DAEMON_SCRIPT" status
        ;;
    restart)
        "$DAEMON_SCRIPT" restart
        ;;
    logs)
        show_logs "${2:-20}"
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
