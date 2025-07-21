#!/bin/bash

# cliExtra 实例列表脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 列出所有Screen实例
list_screen_instances() {
    echo "当前活跃的q CLI Screen实例:"
    
    local found=false
    while IFS= read -r line; do
        if [[ "$line" == *"q_instance_"* ]]; then
            found=true
            # 提取实例信息 - 修复正则表达式以匹配所有格式
            session_info=$(echo "$line" | grep -o 'q_instance_[^[:space:]]*')
            instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            status=$(echo "$line" | grep -o '(Attached)\|(Detached)' || echo "(Unknown)")
            
            echo "  实例 $instance_id: $session_info $status"
            echo "    接管命令: screen -r q_instance_$instance_id"
        fi
    done < <(screen -list 2>/dev/null)
    
    if [ "$found" = false ]; then
        echo "  没有活跃的实例"
    fi
}

# 主逻辑
list_screen_instances 