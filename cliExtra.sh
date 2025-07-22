#!/bin/bash

# cliExtra - 主控制脚本
# 基于tmux的q CLI实例管理系统

# 获取脚本的实际目录（处理软链接）
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
SCRIPT_NAME="cliExtra"

# 显示帮助
show_help() {
    echo ""
    echo "=== cliExtra - 基于tmux的q CLI实例管理系统 ==="
    echo "用法:"
    echo "  $0 config                    - 配置全局设置"
    echo "  $0 start [path] [--name <name>] - 启动实例"
  $0 resume <instance_id>      - 恢复已停止的实例，载入历史上下文    echo "  $0 send <instance_id> <msg>  - 发送消息到指定实例"
    echo "  $0 attach <instance_id>      - 接管指定实例终端"
    echo "  $0 replay <type> <target>    - 回放对话记录"
    echo "  $0 stop <instance_id|all>    - 停止指定实例或所有实例"
    echo "  $0 list [instance_id] [-o json] - 列出所有实例或显示指定实例详情"
    echo "  $0 status <instance_id>      - 显示实例状态"
    echo "  $0 logs <instance_id> [lines] - 查看实例日志"
    echo "  $0 monitor <instance_id>     - 实时监控实例输出"
    echo "  $0 clean <instance_id|all>   - 清理实例（支持--namespace）"
    echo "  $0 clean-all                 - 清理所有实例"
    echo "  $0 stop-all                  - 停止所有运行中的实例"
    echo "  $0 role <command>            - 角色预设管理"
    echo "  $0 ns <command>              - namespace管理"
    echo "  $0 set-ns <id> <namespace>   - 修改实例的namespace"
    echo "  $0 broadcast <message>       - 广播消息到实例"
    echo "  $0 tools <command>           - 工具管理"
    echo "  $0 replay <command>          - 对话回放"
    echo "  $0 help                      - 显示此帮助"
    echo ""
    echo "启动示例:"
    echo "  $0 start                     # 在当前目录启动，自动生成实例ID (如: cliExtra_myproject_1234567890_1234)"
    echo "  $0 start ../                 # 在上级目录启动，自动生成实例ID (如: cliExtra_parentdir_1234567890_5678)"
    echo "  $0 start /path/to/project    # 在指定目录启动，自动生成实例ID (如: cliExtra_project_1234567890_9012)"
    echo "  $0 start https://github.com/user/repo.git  # 克隆并启动，自动生成实例ID (如: cliExtra_repo_1234567890_3456)"
    echo "  $0 start --name myproject    # 在当前目录启动，指定实例名为myproject"
    echo "  $0 start ../ --name test     # 在上级目录启动，指定实例名为test"
    echo "  $0 start --role frontend     # 在当前目录启动并应用前端工程师角色"
    echo "  $0 start --name backend --role backend  # 启动并应用后端工程师角色"
    echo "  $0 start --namespace frontend           # 在frontend namespace中启动实例"
    echo "  $0 start --name api --ns backend        # 在backend namespace中启动名为api的实例"
    echo "  $0 start --context old-instance         # 恢复已停止的实例，载入历史上下文"
    echo ""
    echo "其他示例:"
    echo "  $0 send myproject '你好，Q!'  # 发送消息到实例myproject"
    echo "  $0 resume myproject          # 恢复已停止的实例myproject，载入历史上下文"
    echo "  $0 attach myproject          # 接管实例myproject终端"
    echo "  $0 stop myproject            # 停止实例myproject"
    echo "  $0 clean myproject           # 清理实例myproject"
    echo "  $0 clean all --namespace frontend  # 清理frontend namespace中的所有实例"
    echo "  $0 logs myproject 20         # 查看实例myproject最近20行日志"
    echo "  $0 monitor myproject         # 实时监控实例myproject"
    echo "  $0 role list                 # 列出所有可用角色"
    echo "  $0 role apply frontend       # 应用前端工程师角色到当前项目"
    echo "  $0 ns create frontend        # 创建frontend namespace"
    echo "  $0 ns show                   # 显示所有namespace"
    echo "  $0 set-ns myinstance backend # 将实例移动到backend namespace"
    echo "  $0 broadcast \"系统维护通知\"   # 广播消息到所有实例"
    echo "  $0 tools add git             # 添加git工具到当前项目"
    echo "  $0 replay instance backend-api  # 回放backend-api实例的对话"
    echo ""
    echo "tmux操作:"
    echo "  接管会话: tmux attach-session -t q_instance_<id>"
    echo "  分离会话: 在会话中按 Ctrl+B, D"
    echo "  查看所有: tmux list-sessions"
    echo ""
    echo "特点:"
    echo "  - 支持自动生成与目录相关的实例ID"
    echo "  - 支持本地目录和Git仓库初始化"
    echo "  - 工作目录统一管理，项目目录保持干净"
    echo "  - 用户可随时接管终端进行交互"
    echo "  - 程序可发送消息到实例"
    echo "  - 支持会话保持和上下文管理"
    echo "  - 自动日志记录"
    echo "  - 角色预设管理（前端、后端、测试、代码审查、运维）"
    echo "  - Namespace管理和跨项目协作"
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
    "resume")
        if [ -z "$2" ]; then
            echo "用法: $0 resume <instance_id>"
            exit 1
        fi
        "$SCRIPT_DIR/bin/cliExtra-start.sh" --context "${@:2}"
        ;;
    "send")
        "$SCRIPT_DIR/bin/cliExtra-send.sh" "${@:2}"
        ;;
    "attach")
        "$SCRIPT_DIR/bin/cliExtra-attach.sh" "${@:2}"
        ;;
    "monitor")
        "$SCRIPT_DIR/bin/cliExtra-monitor.sh" "${@:2}"
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
    "replay")
        "$SCRIPT_DIR/bin/cliExtra-replay.sh" "${@:2}"
        ;;
    "clean")
        "$SCRIPT_DIR/bin/cliExtra-clean.sh" "${@:2}"
        ;;
    "clean-all")
        "$SCRIPT_DIR/bin/cliExtra-clean.sh" "all"
        ;;
    "stop-all")
        "$SCRIPT_DIR/bin/cliExtra-stop.sh" "all"
        ;;
    "role")
        "$SCRIPT_DIR/bin/cliExtra-role.sh" "${@:2}"
        ;;
    "ns")
        "$SCRIPT_DIR/bin/cliExtra-ns.sh" "${@:2}"
        ;;
    "set-ns")
        "$SCRIPT_DIR/bin/cliExtra-set-ns.sh" "${@:2}"
        ;;
    "broadcast")
        "$SCRIPT_DIR/bin/cliExtra-broadcast.sh" "${@:2}"
        ;;
    "tools")
        "$SCRIPT_DIR/bin/cliExtra-tools.sh" "${@:2}"
        ;;
    "replay")
        "$SCRIPT_DIR/bin/cliExtra-replay.sh" "${@:2}"
        ;;
    "help"|"")
        show_help
        ;;
    *)
        echo "未知命令: $1"
        show_help
        ;;
esac 
