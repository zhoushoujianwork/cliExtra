#!/bin/bash

# cliExtra - 主控制脚本
# 基于Screen的q CLI实例管理系统

# 获取脚本的实际目录（处理软链接）
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
SCRIPT_NAME="cliExtra"

# 显示帮助
show_help() {
    echo ""
    echo "=== cliExtra - 基于Screen的q CLI实例管理系统 ==="
    echo "用法:"
    echo "  $0 config                    - 配置全局设置"
    echo "  $0 start [path] [--name <name>] - 启动实例"
    echo "  $0 send <instance_id> <msg>  - 发送消息到指定实例"
    echo "  $0 attach <instance_id>      - 接管指定实例终端"
    echo "  $0 stop <instance_id>        - 停止指定实例"
    echo "  $0 list                      - 列出所有实例"
    echo "  $0 status <instance_id>      - 显示实例状态"
    echo "  $0 logs <instance_id> [lines] - 查看实例日志"
    echo "  $0 monitor <instance_id>     - 实时监控实例输出"
    echo "  $0 clean <instance_id>       - 清理指定实例"
    echo "  $0 clean-all                 - 清理所有实例"
    echo "  $0 help                      - 显示此帮助"
    echo ""
    echo "启动示例:"
    echo "  $0 start                     # 在当前目录启动，自动生成实例ID"
    echo "  $0 start ../                 # 在上级目录启动，自动生成实例ID"
    echo "  $0 start /path/to/project    # 在指定目录启动，自动生成实例ID"
    echo "  $0 start https://github.com/user/repo.git  # 克隆并启动，自动生成实例ID"
    echo "  $0 start --name myproject    # 在当前目录启动，指定实例名为myproject"
    echo "  $0 start ../ --name test     # 在上级目录启动，指定实例名为test"
    echo ""
    echo "其他示例:"
    echo "  $0 send myproject '你好，Q!'  # 发送消息到实例myproject"
    echo "  $0 attach myproject          # 接管实例myproject终端"
    echo "  $0 stop myproject            # 停止实例myproject"
    echo "  $0 clean myproject           # 清理实例myproject"
    echo "  $0 logs myproject 20         # 查看实例myproject最近20行日志"
    echo "  $0 monitor myproject         # 实时监控实例myproject"
    echo ""
    echo "Screen操作:"
    echo "  接管会话: screen -r q_instance_<id>"
    echo "  分离会话: 在会话中按 Ctrl+A, D"
    echo "  查看所有: screen -list"
    echo ""
    echo "特点:"
    echo "  - 支持自动生成实例ID"
    echo "  - 支持本地目录和Git仓库初始化"
    echo "  - 项目级状态管理 (.cliExtra目录)"
    echo "  - 用户可随时接管终端进行交互"
    echo "  - 程序可发送消息到实例"
    echo "  - 支持会话保持和上下文管理"
    echo "  - 自动日志记录"
    echo ""
}

# 主逻辑
case "${1:-}" in
    "config")
        "$SCRIPT_DIR/bin/cliExtra-config.sh" "${@:2}"
        ;;
    "start")
        "$SCRIPT_DIR/bin/cliExtra-start.sh" "${@:2}"
        ;;
    "send")
        "$SCRIPT_DIR/bin/cliExtra-send.sh" "${@:2}"
        ;;
    "attach")
        "$SCRIPT_DIR/bin/cliExtra-attach.sh" "${@:2}"
        ;;
    "stop")
        "$SCRIPT_DIR/bin/cliExtra-stop.sh" "${@:2}"
        ;;
    "list")
        "$SCRIPT_DIR/bin/cliExtra-list.sh" "${@:2}"
        ;;
    "status")
        "$SCRIPT_DIR/bin/cliExtra-status.sh" "${@:2}"
        ;;
    "logs")
        "$SCRIPT_DIR/bin/cliExtra-logs.sh" "${@:2}"
        ;;
    "monitor")
        "$SCRIPT_DIR/bin/cliExtra-monitor.sh" "${@:2}"
        ;;
    "clean")
        "$SCRIPT_DIR/bin/cliExtra-clean.sh" "${@:2}"
        ;;
    "clean-all")
        "$SCRIPT_DIR/bin/cliExtra-clean.sh" "all"
        ;;
    "help"|"")
        show_help
        ;;
    *)
        echo "未知命令: $1"
        show_help
        ;;
esac 