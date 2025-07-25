#!/bin/bash
source bin/cliExtra-common.sh
source bin/cliExtra-status-manager.sh

instance_id="q_cli_system"
namespace="q_cli"

echo "=== 调试状态检查 ==="
echo "实例ID: $instance_id"
echo "Namespace: $namespace"
echo ""

echo "1. 状态文件路径:"
status_file=$(get_instance_status_file "$instance_id" "$namespace")
echo "   $status_file"

echo "2. 状态文件是否存在:"
if [[ -f "$status_file" ]]; then
    echo "   存在"
else
    echo "   不存在"
fi

echo "3. 状态文件内容:"
if [[ -f "$status_file" ]]; then
    content=$(cat "$status_file")
    echo "   '$content'"
else
    echo "   无法读取"
fi

echo "4. read_status_file 结果:"
result=$(read_status_file "$instance_id" "$namespace")
echo "   '$result'"

echo "5. get_instance_status 结果:"
result=$(get_instance_status "$instance_id" "$namespace")
echo "   '$result'"

echo "6. tmux 会话检查:"
session_name="q_instance_$instance_id"
if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "   会话存在: $session_name"
else
    echo "   会话不存在: $session_name"
fi
