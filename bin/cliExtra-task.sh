#!/bin/bash

# cliExtra 任务管理脚本

# 加载配置、公共函数和状态管理器
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra task <command> [options]"
    echo ""
    echo "命令:"
    echo "  complete [instance_id]    标记任务完成，设置实例状态为空闲"
    echo "  start [instance_id]       开始新任务，设置实例状态为忙碌"
    echo "  pause [instance_id]       暂停任务，设置实例状态为等待"
    echo "  error [instance_id]       标记任务错误，设置实例状态为错误"
    echo ""
    echo "选项:"
    echo "  --task <description>      设置任务描述"
    echo "  --auto                    自动检测当前实例ID"
    echo ""
    echo "说明:"
    echo "  如果不指定 instance_id，会尝试自动检测当前实例"
    echo "  AI 实例完成任务后应该调用 'qq task complete' 来更新状态"
    echo ""
    echo "示例:"
    echo "  qq task complete                           # 当前实例任务完成"
    echo "  qq task complete backend-api               # 指定实例任务完成"
    echo "  qq task start --task \"开发新功能\"          # 开始新任务"
    echo "  qq task pause --task \"等待用户确认\"        # 暂停任务"
    echo "  qq task error --task \"遇到技术问题\"        # 标记错误"
}

# 获取当前实例ID（从tmux会话名推断）
get_current_instance_id() {
    # 检查是否在tmux会话中
    if [[ -n "$TMUX" ]]; then
        local session_name=$(tmux display-message -p '#S')
        # 检查是否是q_instance_开头的会话
        if [[ "$session_name" =~ ^q_instance_(.+)$ ]]; then
            echo "${BASH_REMATCH[1]}"
            return 0
        fi
    fi
    
    # 如果不在tmux中或不是q_instance会话，返回空
    return 1
}

# 任务完成命令
task_complete() {
    local instance_id="$1"
    local task_desc="${2:-任务已完成}"
    
    # 如果没有指定实例ID，尝试自动检测
    if [[ -z "$instance_id" ]]; then
        instance_id=$(get_current_instance_id)
        if [[ $? -ne 0 || -z "$instance_id" ]]; then
            echo "错误: 无法自动检测实例ID，请手动指定"
            echo "用法: qq task complete <instance_id>"
            return 1
        fi
        echo "✓ 自动检测到实例ID: $instance_id"
    fi
    
    # 获取实例的namespace
    local namespace=$(get_instance_namespace "$instance_id")
    if [[ -z "$namespace" ]]; then
        namespace="$CLIEXTRA_DEFAULT_NS"
    fi
    
    # 更新状态为 idle
    if update_status_file "$instance_id" "$STATUS_IDLE" "$task_desc" "$namespace"; then
        echo "✓ 实例 $instance_id 任务已完成，状态已设置为空闲"
        return 0
    else
        echo "错误: 无法更新实例 $instance_id 的状态"
        return 1
    fi
}

# 任务开始命令
task_start() {
    local instance_id="$1"
    local task_desc="${2:-开始新任务}"
    
    # 如果没有指定实例ID，尝试自动检测
    if [[ -z "$instance_id" ]]; then
        instance_id=$(get_current_instance_id)
        if [[ $? -ne 0 || -z "$instance_id" ]]; then
            echo "错误: 无法自动检测实例ID，请手动指定"
            echo "用法: qq task start <instance_id>"
            return 1
        fi
        echo "✓ 自动检测到实例ID: $instance_id"
    fi
    
    # 获取实例的namespace
    local namespace=$(get_instance_namespace "$instance_id")
    if [[ -z "$namespace" ]]; then
        namespace="$CLIEXTRA_DEFAULT_NS"
    fi
    
    # 更新状态为 busy
    if update_status_file "$instance_id" "$STATUS_BUSY" "$task_desc" "$namespace"; then
        echo "✓ 实例 $instance_id 已开始新任务，状态已设置为忙碌"
        echo "  任务描述: $task_desc"
        return 0
    else
        echo "错误: 无法更新实例 $instance_id 的状态"
        return 1
    fi
}

# 任务暂停命令
task_pause() {
    local instance_id="$1"
    local task_desc="${2:-任务已暂停，等待处理}"
    
    # 如果没有指定实例ID，尝试自动检测
    if [[ -z "$instance_id" ]]; then
        instance_id=$(get_current_instance_id)
        if [[ $? -ne 0 || -z "$instance_id" ]]; then
            echo "错误: 无法自动检测实例ID，请手动指定"
            echo "用法: qq task pause <instance_id>"
            return 1
        fi
        echo "✓ 自动检测到实例ID: $instance_id"
    fi
    
    # 获取实例的namespace
    local namespace=$(get_instance_namespace "$instance_id")
    if [[ -z "$namespace" ]]; then
        namespace="$CLIEXTRA_DEFAULT_NS"
    fi
    
    # 更新状态为 waiting
    if update_status_file "$instance_id" "$STATUS_WAITING" "$task_desc" "$namespace"; then
        echo "✓ 实例 $instance_id 任务已暂停，状态已设置为等待"
        echo "  等待原因: $task_desc"
        return 0
    else
        echo "错误: 无法更新实例 $instance_id 的状态"
        return 1
    fi
}

# 任务错误命令
task_error() {
    local instance_id="$1"
    local task_desc="${2:-任务遇到错误，需要人工干预}"
    
    # 如果没有指定实例ID，尝试自动检测
    if [[ -z "$instance_id" ]]; then
        instance_id=$(get_current_instance_id)
        if [[ $? -ne 0 || -z "$instance_id" ]]; then
            echo "错误: 无法自动检测实例ID，请手动指定"
            echo "用法: qq task error <instance_id>"
            return 1
        fi
        echo "✓ 自动检测到实例ID: $instance_id"
    fi
    
    # 获取实例的namespace
    local namespace=$(get_instance_namespace "$instance_id")
    if [[ -z "$namespace" ]]; then
        namespace="$CLIEXTRA_DEFAULT_NS"
    fi
    
    # 更新状态为 error
    if update_status_file "$instance_id" "$STATUS_ERROR" "$task_desc" "$namespace"; then
        echo "✓ 实例 $instance_id 任务错误，状态已设置为错误"
        echo "  错误描述: $task_desc"
        return 0
    else
        echo "错误: 无法更新实例 $instance_id 的状态"
        return 1
    fi
}

# 参数解析
COMMAND=""
INSTANCE_ID=""
TASK_DESC=""
AUTO_DETECT=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        complete|start|pause|error)
            COMMAND="$1"
            shift
            ;;
        --task)
            TASK_DESC="$2"
            shift 2
            ;;
        --auto)
            AUTO_DETECT=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            echo "错误: 未知选项 $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$INSTANCE_ID" ]]; then
                INSTANCE_ID="$1"
            else
                echo "错误: 多余的参数 $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# 检查必需参数
if [[ -z "$COMMAND" ]]; then
    echo "错误: 请指定命令"
    show_help
    exit 1
fi

# 如果启用自动检测，清空实例ID让函数自动检测
if [[ "$AUTO_DETECT" == "true" ]]; then
    INSTANCE_ID=""
fi

# 执行对应的命令
case "$COMMAND" in
    complete)
        task_complete "$INSTANCE_ID" "$TASK_DESC"
        ;;
    start)
        task_start "$INSTANCE_ID" "$TASK_DESC"
        ;;
    pause)
        task_pause "$INSTANCE_ID" "$TASK_DESC"
        ;;
    error)
        task_error "$INSTANCE_ID" "$TASK_DESC"
        ;;
    *)
        echo "错误: 未知命令 $COMMAND"
        show_help
        exit 1
        ;;
esac
