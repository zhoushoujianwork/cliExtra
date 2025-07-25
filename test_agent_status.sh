#!/bin/bash

# 测试 tmux.log 文件是否空闲的脚本

LOG_FILE="/Users/mikas/Library/Application Support/cliExtra/namespaces/q_cli/logs/instance_q_cli_system_tmux.log"
IDLE_THRESHOLD_SECONDS=5

echo "检查文件: $LOG_FILE"
echo "空闲阈值: ${IDLE_THRESHOLD_SECONDS} 秒"
echo ""

# 检查文件是否存在
if [[ ! -f "$LOG_FILE" ]]; then
    echo "❌ 文件不存在"
    exit 1
fi

# 获取文件最后修改时间 (macOS 使用 stat -f %m)
last_modified=$(stat -f %m "$LOG_FILE" 2>/dev/null)
if [[ $? -ne 0 ]]; then
    echo "❌ 无法获取文件修改时间"
    exit 1
fi

# 获取当前时间
current_time=$(date +%s)

# 计算空闲时间
idle_seconds=$((current_time - last_modified))

echo "文件大小: $(wc -l < "$LOG_FILE") 行"
echo "最后修改: $(date -r $last_modified '+%Y-%m-%d %H:%M:%S')"
echo "当前时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "空闲时间: ${idle_seconds} 秒"
echo ""

# 判断是否空闲
if [[ $idle_seconds -ge $IDLE_THRESHOLD_SECONDS ]]; then
    echo "✅ Agent 状态: 空闲 (${idle_seconds}s >= ${IDLE_THRESHOLD_SECONDS}s)"
    echo "📄 查看最后几行输出:"
    echo "----------------------------------------"
    tail -n 3 "$LOG_FILE"
    echo "----------------------------------------"
    exit 0
else
    echo "⚡ Agent 状态: 忙碌 (${idle_seconds}s < ${IDLE_THRESHOLD_SECONDS}s)"
    echo "📄 查看最后几行输出:"
    echo "----------------------------------------"
    tail -n 3 "$LOG_FILE"
    echo "----------------------------------------"
    exit 1
fi