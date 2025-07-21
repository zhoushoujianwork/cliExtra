#!/bin/bash

# cliExtra 发送消息脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 发送消息到Screen实例
send_to_screen_instance() {
    local instance_id="$1"
    local message="$2"
    local session_name="q_instance_$instance_id"
    
    if ! screen -list | grep -q "$session_name"; then
        echo "✗ 实例 $instance_id 不存在或未运行"
        echo "请先启动实例: cliExtra start $instance_id"
        return 1
    fi
    
    # 发送消息到screen会话，使用正确的回车符
    screen -S "$session_name" -X stuff "$message"
    screen -S "$session_name" -X stuff $'\015'
    
    echo "✓ 消息已发送到实例 $instance_id: $message"
}

# 主逻辑
if [ -n "$1" ] && [ -n "$2" ]; then
    send_to_screen_instance "$1" "$2"
else
    echo "用法: cliExtra-send.sh <instance_id> <message>"
    echo "示例: cliExtra-send.sh myproject '你好，Q!'"
fi 