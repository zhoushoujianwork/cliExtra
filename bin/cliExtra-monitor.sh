#!/bin/bash

# cliExtra 监控脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 监控Screen实例输出
monitor_screen_instance() {
    local instance_id="$1"
    local session_name="q_instance_$instance_id"
    
    if ! screen -list | grep -q "$session_name"; then
        echo "✗ 实例 $instance_id 不存在或未运行"
        echo "请先启动实例: cliExtra start $instance_id"
        return 1
    fi
    
    echo "正在监控实例 $instance_id..."
    echo "按 Ctrl+C 停止监控"
    
    # 监控screen会话的日志
    screen -S "$session_name" -X logfile /tmp/screen_monitor_$$.log
    screen -S "$session_name" -X logfile flush 1
    screen -S "$session_name" -X log on
    
    # 实时显示日志
    tail -f /tmp/screen_monitor_$$.log 2>/dev/null &
    local tail_pid=$!
    
    # 等待用户中断
    trap "kill $tail_pid 2>/dev/null; rm -f /tmp/screen_monitor_$$.log; exit" INT
    
    wait $tail_pid
}

# 主逻辑
if [ -n "$1" ]; then
    monitor_screen_instance "$1"
else
    echo "用法: cliExtra-monitor.sh <instance_id>"
    echo "示例: cliExtra-monitor.sh myproject"
fi 