#!/bin/bash

# cliExtra Engine (eg) 命令 - 监控守护引擎管理

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra eg <command> [options]"
    echo ""
    echo "命令:"
    echo "  start     启动 agent 监控守护引擎"
    echo "  stop      停止 agent 监控守护引擎"
    echo "  status    显示监控守护引擎状态"
    echo "  restart   重启监控守护引擎"
    echo "  logs      查看监控日志"
    echo ""
    echo "logs 命令用法:"
    echo "  qq eg logs [lines]           # 显示最近指定行数的日志（默认20行）"
    echo "  qq eg logs -f                # 实时跟踪日志（tail -f 模式）"
    echo "  qq eg logs --follow          # 实时跟踪日志"
    echo "  qq eg logs --tail            # 实时跟踪日志"
    echo "  qq eg logs -n 50             # 显示最近50行日志"
    echo "  qq eg logs --lines 100       # 显示最近100行日志"
    echo "  qq eg logs 30 -f             # 显示最近30行并开始实时跟踪"
    echo ""
    echo "功能说明:"
    echo "  监控守护引擎会自动："
    echo "  - 监控所有 agent 的 tmux 终端输出"
    echo "  - 检测用户输入等待符（如 '> '）判断空闲状态"
    echo "  - 检测忙碌关键词判断工作状态"
    echo "  - 自动更新 agent 状态文件（0=idle, 1=busy）"
    echo "  - 检查和修复各 namespace 的 system agent"
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
    echo "  cliExtra eg start    # 启动监控引擎"
    echo "  cliExtra eg status   # 查看引擎状态"
    echo "  cliExtra eg logs     # 查看日志"
    echo "  cliExtra eg stop     # 停止监控引擎"
}

# 查看监控日志
show_logs() {
    local lines="${1:-20}"
    local follow_mode="${2:-false}"
    local log_file="$CLIEXTRA_HOME/engine.log"
    
    if [[ ! -f "$log_file" ]]; then
        echo "监控日志文件不存在: $log_file"
        echo "请先启动监控守护引擎: qq eg start"
        return 1
    fi
    
    if [[ "$follow_mode" == "true" ]]; then
        echo "=== Engine Daemon Logs (实时跟踪模式) ==="
        echo "日志文件: $log_file"
        echo "按 Ctrl+C 退出跟踪模式"
        echo ""
        tail -f "$log_file"
    else
        echo "=== Engine Daemon Logs (最近 $lines 行) ==="
        echo "日志文件: $log_file"
        echo ""
        tail -n "$lines" "$log_file"
    fi
}

# 主逻辑
DAEMON_SCRIPT="$SCRIPT_DIR/cliExtra-engine-daemon.sh"

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
        # 解析参数的函数
        parse_logs_args() {
            local lines="20"
            local follow_mode="false"
            
            # 处理参数
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -f|--follow|--tail)
                        follow_mode="true"
                        ;;
                    -n|--lines)
                        if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                            lines="$2"
                            shift
                        else
                            echo "错误: -n/--lines 需要一个数字参数"
                            exit 1
                        fi
                        ;;
                    [0-9]*)
                        lines="$1"
                        ;;
                    *)
                        echo "错误: 未知参数 '$1'"
                        echo "用法: qq eg logs [lines] [-f|--follow|--tail] [-n|--lines <number>]"
                        exit 1
                        ;;
                esac
                shift
            done
            
            show_logs "$lines" "$follow_mode"
        }
        
        parse_logs_args "${@:2}"
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
