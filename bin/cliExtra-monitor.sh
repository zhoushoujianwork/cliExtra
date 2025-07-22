#!/bin/bash

# cliExtra AI 回答监听和记录脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra monitor <instance_id> [options]"
    echo ""
    echo "参数:"
    echo "  instance_id       要监听的实例ID"
    echo ""
    echo "选项:"
    echo "  --daemon         后台运行监听进程"
    echo "  --stop           停止指定实例的监听进程"
    echo "  --status         显示监听进程状态"
    echo ""
    echo "示例:"
    echo "  cliExtra monitor myproject              # 开始监听实例"
    echo "  cliExtra monitor myproject --daemon     # 后台监听"
    echo "  cliExtra monitor myproject --stop       # 停止监听"
    echo "  cliExtra monitor myproject --status     # 查看状态"
}

# 获取监听进程PID文件路径
get_monitor_pid_file() {
    local instance_id="$1"
    local instance_dir=$(find_instance_info_dir "$instance_id")
    
    if [[ $? -eq 0 && -n "$instance_dir" ]]; then
        echo "$instance_dir/monitor.pid"
    else
        echo ""
    fi
}

# 检查监听进程状态
check_monitor_status() {
    local instance_id="$1"
    local pid_file=$(get_monitor_pid_file "$instance_id")
    
    if [[ -z "$pid_file" ]]; then
        echo "实例 $instance_id 不存在"
        return 1
    fi
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "监听进程运行中 (PID: $pid)"
            return 0
        else
            echo "监听进程已停止，清理PID文件"
            rm -f "$pid_file"
            return 1
        fi
    else
        echo "监听进程未运行"
        return 1
    fi
}

# 停止监听进程
stop_monitor() {
    local instance_id="$1"
    local pid_file=$(get_monitor_pid_file "$instance_id")
    
    if [[ -z "$pid_file" ]]; then
        echo "实例 $instance_id 不存在"
        return 1
    fi
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "停止监听进程 (PID: $pid)"
            kill "$pid"
            rm -f "$pid_file"
            echo "✓ 监听进程已停止"
        else
            echo "监听进程已经停止"
            rm -f "$pid_file"
        fi
    else
        echo "监听进程未运行"
    fi
}

# 记录AI回答到对话文件
record_ai_response() {
    local instance_id="$1"
    local response="$2"
    local timestamp="$3"
    
    # 获取对话文件路径
    local instance_dir=$(find_instance_info_dir "$instance_id")
    local conversation_file=""
    local namespace="default"
    
    if [[ $? -eq 0 && -n "$instance_dir" ]]; then
        local ns_dir=$(dirname "$(dirname "$instance_dir")")
        conversation_file="$ns_dir/conversations/instance_$instance_id.json"
        namespace=$(basename "$ns_dir")
    else
        echo "警告: 无法找到实例 $instance_id 的信息目录"
        return 1
    fi
    
    # 确保对话文件存在
    if [[ ! -f "$conversation_file" ]]; then
        mkdir -p "$(dirname "$conversation_file")"
        local project_dir=$(find_instance_project "$instance_id")
        cat > "$conversation_file" << EOF
{
  "instance_id": "$instance_id",
  "namespace": "$namespace",
  "project_dir": "$project_dir",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "conversations": []
}
EOF
    fi
    
    # 使用jq添加AI回答记录
    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        jq --arg timestamp "$timestamp" \
           --arg response "$response" \
           --arg type "ai_response" \
           '.conversations += [{
               "timestamp": $timestamp,
               "type": $type,
               "sender": "ai",
               "message": $response
           }]' "$conversation_file" > "$temp_file" && mv "$temp_file" "$conversation_file"
        
        echo "✓ AI回答已记录到: $conversation_file"
    else
        echo "警告: jq未安装，无法记录AI回答"
    fi
}

# 解析AI回答内容
parse_ai_response() {
    local log_content="$1"
    
    # 简单的AI回答识别逻辑
    # 这里可以根据实际的AI回答格式进行调整
    
    # 移除ANSI转义序列
    local clean_content=$(echo "$log_content" | sed 's/\x1b\[[0-9;]*m//g')
    
    # 过滤掉明显的系统消息和命令
    if [[ "$clean_content" =~ ^(q|quit|exit|clear|ls|cd|pwd|cat|echo|grep|find|tmux|cliExtra) ]]; then
        return 1
    fi
    
    # 过滤掉空行和过短的内容
    if [[ ${#clean_content} -lt 10 ]]; then
        return 1
    fi
    
    # 过滤掉明显的错误信息
    if [[ "$clean_content" =~ ^(Error|错误|Warning|警告|Failed|失败) ]]; then
        return 1
    fi
    
    echo "$clean_content"
    return 0
}

# 监听tmux会话输出
monitor_tmux_session() {
    local instance_id="$1"
    local daemon_mode="$2"
    
    local session_name="q_instance_$instance_id"
    
    # 检查tmux会话是否存在
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "错误: tmux会话 $session_name 不存在"
        return 1
    fi
    
    # 获取日志文件路径
    local instance_dir=$(find_instance_info_dir "$instance_id")
    if [[ $? -ne 0 || -z "$instance_dir" ]]; then
        echo "错误: 无法找到实例 $instance_id 的信息目录"
        return 1
    fi
    
    local ns_dir=$(dirname "$(dirname "$instance_dir")")
    local log_file="$ns_dir/logs/instance_$instance_id.log"
    
    if [[ ! -f "$log_file" ]]; then
        echo "错误: 日志文件不存在: $log_file"
        return 1
    fi
    
    echo "开始监听实例 $instance_id 的AI回答..."
    echo "日志文件: $log_file"
    echo "会话名称: $session_name"
    
    # 记录监听进程PID
    local pid_file=$(get_monitor_pid_file "$instance_id")
    if [[ -n "$pid_file" ]]; then
        echo $$ > "$pid_file"
    fi
    
    # 获取当前日志文件大小，从末尾开始监听
    local last_size=$(stat -f%z "$log_file" 2>/dev/null || echo "0")
    local buffer=""
    local last_timestamp=""
    
    echo "监听开始，按 Ctrl+C 停止..."
    
    # 监听循环
    while true; do
        # 检查日志文件大小变化
        local current_size=$(stat -f%z "$log_file" 2>/dev/null || echo "0")
        
        if [[ $current_size -gt $last_size ]]; then
            # 读取新增内容
            local new_content=$(tail -c +$((last_size + 1)) "$log_file")
            
            # 按行处理新内容
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    # 尝试解析AI回答
                    local ai_response=$(parse_ai_response "$line")
                    if [[ $? -eq 0 && -n "$ai_response" ]]; then
                        local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                        
                        # 避免重复记录相同的回答
                        if [[ "$ai_response" != "$last_timestamp" ]]; then
                            echo "检测到AI回答: ${ai_response:0:50}..."
                            record_ai_response "$instance_id" "$ai_response" "$timestamp"
                            last_timestamp="$ai_response"
                        fi
                    fi
                fi
            done <<< "$new_content"
            
            last_size=$current_size
        fi
        
        # 短暂休眠避免过度占用CPU
        sleep 1
    done
}

# 后台运行监听
start_daemon_monitor() {
    local instance_id="$1"
    
    # 检查是否已经在运行
    if check_monitor_status "$instance_id" >/dev/null 2>&1; then
        echo "监听进程已在运行"
        return 1
    fi
    
    echo "启动后台监听进程..."
    
    # 获取PID文件路径
    local pid_file=$(get_monitor_pid_file "$instance_id")
    if [[ -z "$pid_file" ]]; then
        echo "✗ 无法获取PID文件路径"
        return 1
    fi
    
    # 后台运行监听，使用当前脚本路径
    (
        # 在子shell中运行监听
        monitor_tmux_session "$instance_id" true
    ) &
    
    local monitor_pid=$!
    
    # 记录PID
    echo "$monitor_pid" > "$pid_file"
    
    # 等待一下确保进程启动
    sleep 2
    
    if kill -0 "$monitor_pid" 2>/dev/null; then
        echo "✓ 后台监听进程已启动 (PID: $monitor_pid)"
    else
        echo "✗ 后台监听进程启动失败"
        rm -f "$pid_file"
        return 1
    fi
}

# 解析参数
INSTANCE_ID=""
DAEMON_MODE=false
STOP_MODE=false
STATUS_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --daemon)
            DAEMON_MODE=true
            shift
            ;;
        --stop)
            STOP_MODE=true
            shift
            ;;
        --status)
            STATUS_MODE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            echo "未知选项: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$INSTANCE_ID" ]]; then
                INSTANCE_ID="$1"
            fi
            shift
            ;;
    esac
done

# 主逻辑
if [[ -z "$INSTANCE_ID" ]]; then
    echo "错误: 请指定实例ID"
    show_help
    exit 1
fi

if [[ "$STATUS_MODE" == "true" ]]; then
    check_monitor_status "$INSTANCE_ID"
elif [[ "$STOP_MODE" == "true" ]]; then
    stop_monitor "$INSTANCE_ID"
elif [[ "$DAEMON_MODE" == "true" ]]; then
    start_daemon_monitor "$INSTANCE_ID"
else
    monitor_tmux_session "$INSTANCE_ID" false
fi
