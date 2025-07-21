#!/bin/bash

# cliExtra 实例列表脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra list [instance_id] [--json]"
    echo ""
    echo "参数:"
    echo "  instance_id   显示指定实例的详细信息"
    echo ""
    echo "选项:"
    echo "  --json        以JSON格式输出信息"
    echo ""
    echo "输出格式:"
    echo "  无参数: 每行一个实例ID，便于脚本解析"
    echo "  有实例ID: 显示该实例的详细信息"
    echo "  --json: 结构化的JSON格式输出"
    echo ""
    echo "示例:"
    echo "  cliExtra list                    # 列出所有实例ID"
    echo "  cliExtra list --json             # JSON格式列出所有实例"
    echo "  cliExtra list myinstance         # 显示实例myinstance的详细信息"
    echo "  cliExtra list myinstance --json  # JSON格式显示实例详细信息"
}

# 解析参数
JSON_OUTPUT=false
TARGET_INSTANCE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$TARGET_INSTANCE" ]]; then
                TARGET_INSTANCE="$1"
            fi
            shift
            ;;
    esac
done

# 获取实例详细信息
get_instance_details() {
    local instance_id="$1"
    local project_dir=""
    local log_file=""
    local config_file=""
    local instance_dir=""
    
    # 查找实例所在的项目目录 - 从当前目录开始向上查找
    local current_dir="$(pwd)"
    while [[ "$current_dir" != "/" ]]; do
        local cliextra_dir="$current_dir/.cliExtra"
        if [[ -d "$cliextra_dir" ]]; then
            local instance_path="$cliextra_dir/instances/instance_$instance_id"
            local log_path="$cliextra_dir/logs/instance_$instance_id.log"
            
            if [[ -d "$instance_path" ]] || [[ -f "$log_path" ]]; then
                project_dir="$current_dir"
                instance_dir="$instance_path"
                log_file="$log_path"
                config_file="$cliextra_dir/config"
                break
            fi
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    # 如果在当前目录树中没找到，尝试在常见位置查找
    if [[ -z "$project_dir" ]]; then
        for search_dir in "$HOME" "/Users" "/home"; do
            if [[ -d "$search_dir" ]]; then
                while IFS= read -r -d '' cliextra_dir; do
                    local parent_dir=$(dirname "$cliextra_dir")
                    local instance_path="$cliextra_dir/instances/instance_$instance_id"
                    local log_path="$cliextra_dir/logs/instance_$instance_id.log"
                    
                    if [[ -d "$instance_path" ]] || [[ -f "$log_path" ]]; then
                        project_dir="$parent_dir"
                        instance_dir="$instance_path"
                        log_file="$log_path"
                        config_file="$cliextra_dir/config"
                        break 2
                    fi
                done < <(find "$search_dir" -name ".cliExtra" -type d -maxdepth 5 -print0 2>/dev/null)
            fi
        done
    fi
    
    # 获取Screen会话信息
    local session_info=""
    local status="Not Running"
    local session_name="q_instance_$instance_id"
    
    while IFS= read -r line; do
        if [[ "$line" == *"q_instance_$instance_id"* ]]; then
            session_info=$(echo "$line" | grep -o 'q_instance_[^[:space:]]*')
            status=$(echo "$line" | grep -o '(Attached)\|(Detached)' || echo "(Unknown)")
            status=$(echo "$status" | sed 's/[()]//g')
            break
        fi
    done < <(screen -list 2>/dev/null)
    
    # 获取日志文件大小和最后修改时间
    local log_size="0"
    local log_modified=""
    if [[ -f "$log_file" ]]; then
        log_size=$(stat -f%z "$log_file" 2>/dev/null || echo "0")
        log_modified=$(stat -f%Sm "$log_file" 2>/dev/null || echo "Unknown")
    fi
    
    # 输出详细信息
    if [ "$JSON_OUTPUT" = true ]; then
        output_instance_json "$instance_id" "$status" "$session_info" "$project_dir" "$log_file" "$log_size" "$log_modified" "$instance_dir"
    else
        output_instance_details "$instance_id" "$status" "$session_info" "$project_dir" "$log_file" "$log_size" "$log_modified" "$instance_dir"
    fi
}

# 获取所有实例信息
get_all_instances() {
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

# 输出单个实例详细信息（文本格式）
output_instance_details() {
    local instance_id="$1"
    local status="$2"
    local session_info="$3"
    local project_dir="$4"
    local log_file="$5"
    local log_size="$6"
    local log_modified="$7"
    local instance_dir="$8"
    
    echo "=== 实例详细信息 ==="
    echo "实例ID: $instance_id"
    echo "状态: $status"
    echo "会话名称: ${session_info:-q_instance_$instance_id}"
    echo "项目目录: ${project_dir:-"未找到"}"
    echo "实例目录: ${instance_dir:-"未找到"}"
    echo "日志文件: ${log_file:-"未找到"}"
    
    if [[ -f "$log_file" ]]; then
        echo "日志大小: $(numfmt --to=iec $log_size 2>/dev/null || echo "${log_size} bytes")"
        echo "最后修改: $log_modified"
    fi
    
    echo ""
    echo "操作命令:"
    echo "  接管会话: screen -r q_instance_$instance_id"
    echo "  发送消息: cliExtra send $instance_id \"消息内容\""
    echo "  查看日志: cliExtra logs $instance_id"
    echo "  停止实例: cliExtra stop $instance_id"
    echo "  清理实例: cliExtra clean $instance_id"
    
    # 显示最近的日志内容
    if [[ -f "$log_file" && -s "$log_file" ]]; then
        echo ""
        echo "=== 最近日志 (最后10行) ==="
        tail -n 10 "$log_file" 2>/dev/null || echo "无法读取日志文件"
    fi
}

# 输出单个实例详细信息（JSON格式）
output_instance_json() {
    local instance_id="$1"
    local status="$2"
    local session_info="$3"
    local project_dir="$4"
    local log_file="$5"
    local log_size="$6"
    local log_modified="$7"
    local instance_dir="$8"
    
    # 获取最近日志内容
    local recent_logs=""
    if [[ -f "$log_file" && -s "$log_file" ]]; then
        recent_logs=$(tail -n 10 "$log_file" 2>/dev/null | sed 's/"/\\"/g' | tr '\n' '\\' | sed 's/\\$//' | sed 's/\\/\\n/g')
    fi
    
    echo "{"
    echo "  \"instance\": {"
    echo "    \"id\": \"$instance_id\","
    echo "    \"status\": \"$status\","
    echo "    \"session\": \"${session_info:-q_instance_$instance_id}\","
    echo "    \"project_dir\": \"${project_dir:-""}\","
    echo "    \"instance_dir\": \"${instance_dir:-""}\","
    echo "    \"log_file\": \"${log_file:-""}\","
    echo "    \"log_size\": $log_size,"
    echo "    \"log_modified\": \"$log_modified\","
    echo "    \"recent_logs\": \"$recent_logs\""
    echo "  },"
    echo "  \"commands\": {"
    echo "    \"attach\": \"screen -r q_instance_$instance_id\","
    echo "    \"send\": \"cliExtra send $instance_id\","
    echo "    \"logs\": \"cliExtra logs $instance_id\","
    echo "    \"stop\": \"cliExtra stop $instance_id\","
    echo "    \"clean\": \"cliExtra clean $instance_id\""
    echo "  }"
    echo "}"
}

# 主逻辑
if [[ -n "$TARGET_INSTANCE" ]]; then
    # 显示特定实例的详细信息
    get_instance_details "$TARGET_INSTANCE"
else
    # 显示所有实例列表
    get_all_instances
fi 