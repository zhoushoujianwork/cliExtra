#!/bin/bash

# 测试状态变化钩子函数

cd "$(dirname "$0")"
source bin/cliExtra-status-manager.sh
source bin/cliExtra-status-engine.sh

echo "=== 测试状态变化钩子函数 ==="
echo ""

instance_id="q_cli_system"
namespace="q_cli"

echo "测试实例: $instance_id"
echo "Namespace: $namespace"
echo ""

# 启用调试模式
export CLIEXTRA_DEBUG=true

echo "1. 当前状态:"
current_status=$(read_status_file "$instance_id" "$namespace")
echo "   状态文件: $current_status ($(status_to_name "$current_status"))"
detected_status=$(detect_instance_status_by_timestamp "$instance_id" "$namespace" 5)
echo "   检测状态: $detected_status"
echo ""

echo "2. 设置状态为 busy (1) 并触发变化检测:"
update_status_file "$instance_id" 1 "$namespace"
monitor_instance_by_timestamp "$instance_id" "$namespace" 5
echo ""

echo "3. 设置状态为 idle (0) 并触发变化检测:"
update_status_file "$instance_id" 0 "$namespace"
monitor_instance_by_timestamp "$instance_id" "$namespace" 5
echo ""

echo "4. 最终状态:"
final_status=$(read_status_file "$instance_id" "$namespace")
echo "   状态文件: $final_status ($(status_to_name "$final_status"))"
echo ""

echo "=== 测试完成 ==="
