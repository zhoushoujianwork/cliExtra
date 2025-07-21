#!/bin/bash

# cliExtra 实例列表脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 检查是否需要JSON输出
JSON_OUTPUT=false
if [[ "$1" == "--json" ]]; then
    JSON_OUTPUT=true
fi

# 获取所有实例信息
get_instances() {
    local instances=()
    local instance_data=()
    
    while IFS= read -r line; do
        if [[ "$line" == *"q_instance_"* ]]; then
            # 提取实例信息
            session_info=$(echo "$line" | grep -o 'q_instance_[^[:space:]]*')
            instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            status=$(echo "$line" | grep -o '(Attached)\|(Detached)' || echo "(Unknown)")
            
            # 清理状态信息
            status=$(echo "$status" | sed 's/[()]//g')
            
            instances+=("$instance_id")
            instance_data+=("$instance_id:$status:$session_info")
        fi
    done < <(screen -list 2>/dev/null)
    
    # 输出结果
    if [ "$JSON_OUTPUT" = true ]; then
        output_json "${instance_data[@]}"
    else
        output_simple "${instances[@]}"
    fi
}

# 简洁输出格式（每行一个实例ID）
output_simple() {
    local instances=("$@")
    
    if [ ${#instances[@]} -eq 0 ]; then
        # 没有实例时不输出任何内容，便于脚本解析
        return 0
    fi
    
    for instance_id in "${instances[@]}"; do
        echo "$instance_id"
    done
}

# JSON输出格式
output_json() {
    local instance_data=("$@")
    
    echo "{"
    echo "  \"instances\": ["
    
    local first=true
    for data in "${instance_data[@]}"; do
        IFS=':' read -r instance_id status session_info <<< "$data"
        
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        
        echo -n "    {"
        echo -n "\"id\": \"$instance_id\", "
        echo -n "\"status\": \"$status\", "
        echo -n "\"session\": \"$session_info\", "
        echo -n "\"attach_command\": \"screen -r q_instance_$instance_id\""
        echo -n "}"
    done
    
    echo ""
    echo "  ],"
    echo "  \"count\": ${#instance_data[@]}"
    echo "}"
}

# 显示帮助
show_help() {
    echo "用法: cliExtra list [--json]"
    echo ""
    echo "选项:"
    echo "  --json    以JSON格式输出实例信息"
    echo ""
    echo "输出格式:"
    echo "  默认: 每行一个实例ID，便于脚本解析"
    echo "  JSON: 结构化的实例详细信息"
    echo ""
    echo "示例:"
    echo "  cliExtra list           # 简洁输出"
    echo "  cliExtra list --json    # JSON输出"
}

# 主逻辑
case "${1:-}" in
    "--help"|"-h")
        show_help
        ;;
    *)
        get_instances "$@"
        ;;
esac 