#!/bin/bash

# cliExtra 实例列表脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra list [instance_id] [options]"
    echo ""
    echo "参数:"
    echo "  instance_id   显示指定实例的详细信息"
    echo ""
    echo "选项:"
    echo "  -o, --output <format>     输出格式：table（默认）或 json"
    echo "  -n, --namespace <name>    只显示指定 namespace 中的实例"
    echo "  --names-only              只输出实例名称（便于脚本解析）"
    echo "  -A, --all                 显示所有 namespace 中的实例"
    echo ""
    echo "默认行为:"
    echo "  默认只显示 'default' namespace 中的实例"
    echo "  使用 -A/--all 显示所有 namespace 的实例"
    echo "  使用 -n/--namespace 显示指定 namespace 的实例"
    echo ""
    echo "输出格式:"
    echo "  默认: 表格格式显示实例信息（包含 namespace、状态等）"
    echo "  --names-only: 每行一个实例ID，便于脚本解析"
    echo "  有实例ID: 显示该实例的详细信息"
    echo "  -o json: 结构化的JSON格式输出"
    echo ""
    echo "示例:"
    echo "  cliExtra list                         # 只显示 default namespace 的实例"
    echo "  cliExtra list -A                      # 显示所有 namespace 的实例"
    echo "  cliExtra list --all                   # 显示所有 namespace 的实例"
    echo "  cliExtra list -n frontend             # 只显示 frontend namespace 的实例"
    echo "  cliExtra list --names-only            # 只列出 default namespace 的实例名称"
    echo "  cliExtra list -A --names-only         # 列出所有 namespace 的实例名称"
    echo "  cliExtra list -o json                 # JSON格式显示 default namespace 的实例"
    echo "  cliExtra list -A -o json              # JSON格式显示所有 namespace 的实例"
    echo "  cliExtra list -n frontend             # 列出frontend namespace中的实例"
    echo "  cliExtra list -n backend -o json      # JSON格式列出backend namespace中的实例"
    echo "  cliExtra list myinstance              # 显示实例myinstance的详细信息"
    echo "  cliExtra list myinstance -o json      # JSON格式显示实例详细信息"
}

# 解析参数
JSON_OUTPUT=false
TARGET_INSTANCE=""
FILTER_NAMESPACE=""
NAMES_ONLY=false
SHOW_ALL_NAMESPACES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            if [[ -z "$2" ]]; then
                echo "错误: -o|--output 参数需要指定格式 (json)"
                echo ""
                show_help
                exit 1
            fi
            if [[ "$2" != "json" ]]; then
                echo "错误: 不支持的输出格式 '$2'，支持的格式: json"
                echo ""
                show_help
                exit 1
            fi
            JSON_OUTPUT=true
            shift 2
            ;;
        -n|--namespace)
            if [[ -z "$2" ]]; then
                echo "错误: -n|--namespace 参数需要指定 namespace 名称"
                echo ""
                show_help
                exit 1
            fi
            FILTER_NAMESPACE="$2"
            shift 2
            ;;
        -A|--all)
            SHOW_ALL_NAMESPACES=true
            shift
            ;;
        --names-only)
            NAMES_ONLY=true
            shift
            ;;
        --json)
            # 保持向后兼容
            JSON_OUTPUT=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            echo "错误: 未知选项 '$1'"
            echo ""
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$TARGET_INSTANCE" ]]; then
                TARGET_INSTANCE="$1"
            else
                echo "错误: 多余的参数 '$1'"
                echo ""
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# 获取实例的namespace
get_instance_namespace() {
    local instance_id="$1"
    
    # 从工作目录的namespace结构中查找实例
    if [ -d "$CLIEXTRA_HOME/namespaces" ]; then
        for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
            local instance_dir="$ns_dir/instances/instance_$instance_id"
            if [[ -d "$instance_dir" ]]; then
                basename "$ns_dir"
                return 0
            fi
        done
    fi
    
    # 向后兼容：查找实例所在的项目目录
    local project_dir=$(find_instance_project "$instance_id")
    if [[ $? -eq 0 ]]; then
        # 首先尝试新的namespace目录结构
        local namespaces_dir="$project_dir/.cliExtra/namespaces"
        if [[ -d "$namespaces_dir" ]]; then
            for ns_dir in "$namespaces_dir"/*; do
                if [[ -d "$ns_dir" ]]; then
                    local instance_dir="$ns_dir/instances/instance_$instance_id"
                    if [[ -d "$instance_dir" ]]; then
                        basename "$ns_dir"
                        return 0
                    fi
                fi
            done
        fi
        
        # 回退到旧的结构
        local old_instance_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
        if [[ -d "$old_instance_dir" ]]; then
            local ns_file="$old_instance_dir/namespace"
            if [[ -f "$ns_file" ]]; then
                cat "$ns_file"
            else
                echo "default"
            fi
            return 0
        fi
    fi
    
    echo "default"
}

# 获取实例详细信息
get_instance_details() {
    local instance_id="$1"
    local project_dir=""
    local log_file=""
    local config_file=""
    local instance_dir=""
    
    # 使用新的实例查找函数
    instance_dir=$(find_instance_info_dir "$instance_id")
    if [[ $? -eq 0 && -n "$instance_dir" ]]; then
        # 从实例信息中获取项目目录
        if [ -f "$instance_dir/project_path" ]; then
            project_dir=$(cat "$instance_dir/project_path")
        elif [ -f "$instance_dir/info" ]; then
            source "$instance_dir/info"
            project_dir="$PROJECT_DIR"
        fi
        
        # 构建日志文件路径
        local ns_dir=$(dirname "$(dirname "$instance_dir")")
        log_file="$ns_dir/logs/instance_$instance_id.log"
    else
        # 向后兼容：查找实例所在的项目目录 - 从当前目录开始向上查找
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
    fi
    
    # 获取tmux会话信息
    local session_info=""
    local status="Not Running"
    local session_name="q_instance_$instance_id"
    
    if tmux has-session -t "$session_name" 2>/dev/null; then
        session_info="$session_name"
        # 检查会话是否有客户端连接
        local client_count=$(tmux list-clients -t "$session_name" 2>/dev/null | wc -l)
        if [ "$client_count" -gt 0 ]; then
            status="Attached"
        else
            status="Detached"
        fi
    fi
    
    # 获取日志文件大小和最后修改时间
    local log_size="0"
    local log_modified=""
    if [[ -f "$log_file" ]]; then
        log_size=$(stat -f%z "$log_file" 2>/dev/null || echo "0")
        log_modified=$(stat -f%Sm "$log_file" 2>/dev/null || echo "Unknown")
    fi
    
    # 获取namespace信息
    local namespace=$(get_instance_namespace "$instance_id")
    
    # 输出详细信息
    if [ "$JSON_OUTPUT" = true ]; then
        output_instance_json "$instance_id" "$status" "$session_info" "$project_dir" "$log_file" "$log_size" "$log_modified" "$instance_dir" "$namespace"
    else
        output_instance_details "$instance_id" "$status" "$session_info" "$project_dir" "$log_file" "$log_size" "$log_modified" "$instance_dir" "$namespace"
    fi
}

# 获取所有实例信息
get_all_instances() {
    local instances=()
    local instance_data=()
    
    # 从工作目录的namespace结构中查找所有实例
    if [ -d "$CLIEXTRA_HOME/namespaces" ]; then
        for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
            if [ -d "$ns_dir/instances" ]; then
                local namespace=$(basename "$ns_dir")
                
                # 实现默认行为：只显示 default namespace，除非指定了其他选项
                if [[ -n "$FILTER_NAMESPACE" ]]; then
                    # 如果指定了namespace过滤，只显示指定的namespace
                    if [[ "$namespace" != "$FILTER_NAMESPACE" ]]; then
                        continue
                    fi
                elif [[ "$SHOW_ALL_NAMESPACES" != "true" ]]; then
                    # 如果没有指定 -A/--all，默认只显示 default namespace
                    if [[ "$namespace" != "default" ]]; then
                        continue
                    fi
                fi
                # 如果 SHOW_ALL_NAMESPACES=true，则显示所有namespace
                
                for instance_dir in "$ns_dir/instances"/instance_*; do
                    if [ -d "$instance_dir" ]; then
                        local instance_id=$(basename "$instance_dir" | sed 's/instance_//')
                        local session_name="q_instance_$instance_id"
                        
                        # 检查tmux会话状态
                        local status="Not Running"
                        if tmux has-session -t "$session_name" 2>/dev/null; then
                            local client_count=$(tmux list-clients -t "$session_name" 2>/dev/null | wc -l)
                            if [ "$client_count" -gt 0 ]; then
                                status="Attached"
                            else
                                status="Detached"
                            fi
                        fi
                        
                        instances+=("$instance_id")
                        instance_data+=("$instance_id:$status:$session_name:$namespace")
                    fi
                done
            fi
        done
    fi
    
    # 向后兼容：获取所有tmux会话
    while IFS= read -r session_line; do
        if [[ "$session_line" == q_instance_* ]]; then
            # 提取实例信息
            session_info=$(echo "$session_line" | cut -d: -f1)
            instance_id=$(echo "$session_info" | sed 's/q_instance_//')
            
            # 检查是否已经在新结构中找到了这个实例
            local found=false
            for existing_instance in "${instances[@]}"; do
                if [ "$existing_instance" = "$instance_id" ]; then
                    found=true
                    break
                fi
            done
            
            # 如果没有在新结构中找到，添加到列表中
            if [ "$found" = false ]; then
                # 获取namespace信息
                local namespace=$(get_instance_namespace "$instance_id")
                
                # 应用与新结构相同的过滤逻辑
                if [[ -n "$FILTER_NAMESPACE" ]]; then
                    # 如果指定了namespace过滤，只显示指定的namespace
                    if [[ "$namespace" != "$FILTER_NAMESPACE" ]]; then
                        continue
                    fi
                elif [[ "$SHOW_ALL_NAMESPACES" != "true" ]]; then
                    # 如果没有指定 -A/--all，默认只显示 default namespace
                    if [[ "$namespace" != "default" ]]; then
                        continue
                    fi
                fi
                
                # 检查会话状态
                local client_count=$(tmux list-clients -t "$session_info" 2>/dev/null | wc -l)
                if [ "$client_count" -gt 0 ]; then
                    status="Attached"
                else
                    status="Detached"
                fi
                
                instances+=("$instance_id")
                instance_data+=("$instance_id:$status:$session_info:$namespace")
            fi
        fi
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    # 输出结果
    if [ "$JSON_OUTPUT" = true ]; then
        output_json "${instance_data[@]}"
    elif [ "$NAMES_ONLY" = true ]; then
        output_names_only "${instance_data[@]}"
    else
        output_simple "${instance_data[@]}"
    fi
}

# 只输出实例名称（便于脚本解析）
output_names_only() {
    local instance_data=("$@")
    
    if [ ${#instance_data[@]} -eq 0 ]; then
        # 没有实例时不输出任何内容，便于脚本解析
        return 0
    fi
    
    # 只输出实例名称
    for data in "${instance_data[@]}"; do
        IFS=':' read -r instance_id status session_name namespace <<< "$data"
        echo "$instance_id"
    done
}

# 简洁输出格式（类似 kubectl 的格式）
output_simple() {
    local instance_data=("$@")
    
    if [ ${#instance_data[@]} -eq 0 ]; then
        # 没有实例时不输出任何内容，便于脚本解析
        return 0
    fi
    
    # 输出表头
    printf "%-30s %-15s %-15s %-15s %-15s\n" "NAME" "NAMESPACE" "STATUS" "SESSION" "ROLE"
    
    # 输出分隔线
    printf "%-30s %-15s %-15s %-15s %-15s\n" "$(printf '%*s' 30 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')"
    
    # 输出实例信息
    for data in "${instance_data[@]}"; do
        IFS=':' read -r instance_id status session_name namespace <<< "$data"
        local role=$(get_instance_role "$instance_id" "$namespace")
        printf "%-30s %-15s %-15s %-15s %-15s\n" "$instance_id" "$namespace" "$status" "$session_name" "$role"
    done
}

# 获取实例详细信息
get_instance_rich_info() {
    local instance_id="$1"
    local status="$2"
    local session_info="$3"
    local namespace="$4"
    
    # 基础信息
    local project_dir=""
    local started_at=""
    local pid=""
    local role=""
    local tools=()
    local conversation_file=""
    
    # 从实例信息目录获取详细信息
    local instance_dir=$(find_instance_info_dir "$instance_id")
    if [[ $? -eq 0 && -n "$instance_dir" ]]; then
        # 读取 info 文件
        if [ -f "$instance_dir/info" ]; then
            source "$instance_dir/info"
            project_dir="$PROJECT_DIR"
            started_at="$STARTED_AT"
            pid="$PID"
            conversation_file="$CONVERSATION_FILE"
        fi
        
        # 读取 project_path 文件
        if [ -f "$instance_dir/project_path" ]; then
            project_dir=$(cat "$instance_dir/project_path")
        fi
    fi
    
    # 如果没有从实例目录获取到项目路径，尝试其他方法
    if [[ -z "$project_dir" ]]; then
        project_dir=$(find_instance_project "$instance_id")
    fi
    
    # 获取角色信息
    role=$(get_instance_role "$instance_id" "$namespace")
    
    # 获取工具列表
    if [[ -n "$project_dir" && -d "$project_dir/.amazonq/rules" ]]; then
        for tool_file in "$project_dir/.amazonq/rules"/tools_*.md; do
            if [[ -f "$tool_file" ]]; then
                local tool_name=$(basename "$tool_file" | sed 's/tools_//' | sed 's/.md$//')
                tools+=("$tool_name")
            fi
        done
    fi
    
    # 获取日志文件信息
    local log_file=""
    local log_size="0"
    local log_modified=""
    if [[ -n "$instance_dir" ]]; then
        local ns_dir=$(dirname "$(dirname "$instance_dir")")
        log_file="$ns_dir/logs/instance_$instance_id.log"
        if [[ -f "$log_file" ]]; then
            log_size=$(stat -f%z "$log_file" 2>/dev/null || echo "0")
            log_modified=$(stat -f%Sm "$log_file" 2>/dev/null || echo "Unknown")
        fi
    fi
    
    # 构建 JSON 对象
    local tools_json=""
    if [ ${#tools[@]} -gt 0 ]; then
        tools_json="["
        local first_tool=true
        for tool in "${tools[@]}"; do
            if [ "$first_tool" = true ]; then
                first_tool=false
            else
                tools_json+=", "
            fi
            tools_json+="\"$tool\""
        done
        tools_json+="]"
    else
        tools_json="[]"
    fi
    
    # 输出 JSON 格式的实例信息
    echo -n "{"
    echo -n "\"id\": \"$instance_id\", "
    echo -n "\"status\": \"$status\", "
    echo -n "\"session\": \"$session_info\", "
    echo -n "\"namespace\": \"$namespace\", "
    echo -n "\"project_dir\": \"${project_dir:-""}\", "
    echo -n "\"role\": \"${role:-""}\", "
    echo -n "\"tools\": $tools_json, "
    echo -n "\"started_at\": \"${started_at:-""}\", "
    echo -n "\"pid\": \"${pid:-""}\", "
    echo -n "\"log_file\": \"${log_file:-""}\", "
    echo -n "\"log_size\": $log_size, "
    echo -n "\"log_modified\": \"${log_modified:-""}\", "
    echo -n "\"conversation_file\": \"${conversation_file:-""}\", "
    echo -n "\"attach_command\": \"tmux attach-session -t q_instance_$instance_id\""
    echo -n "}"
}

# JSON输出格式
output_json() {
    local instance_data=("$@")
    
    echo "{"
    
    # 添加过滤信息
    if [[ -n "$FILTER_NAMESPACE" ]]; then
        echo "  \"filter\": {"
        echo "    \"namespace\": \"$FILTER_NAMESPACE\""
        echo "  },"
    fi
    
    echo "  \"instances\": ["
    
    local first=true
    for data in "${instance_data[@]}"; do
        IFS=':' read -r instance_id status session_info namespace <<< "$data"
        
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        
        echo -n "    "
        get_instance_rich_info "$instance_id" "$status" "$session_info" "$namespace"
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
    local namespace="$9"
    
    echo "=== 实例详细信息 ==="
    echo "实例ID: $instance_id"
    echo "状态: $status"
    echo "Namespace: $namespace"
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
    echo "  接管会话: tmux attach-session -t q_instance_$instance_id"
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
    echo "    \"attach\": \"tmux attach-session -t q_instance_$instance_id\","
    echo "    \"send\": \"cliExtra send $instance_id\","
    echo "    \"logs\": \"cliExtra logs $instance_id\","
    echo "    \"stop\": \"cliExtra stop $instance_id\","
    echo "    \"clean\": \"cliExtra clean $instance_id\""
    echo "  }"
    echo "}"
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
    local namespace="$9"
    
    # 获取角色和工具信息
    local role=""
    local tools=()
    local started_at=""
    local pid=""
    local conversation_file=""
    
    # 从实例信息目录获取详细信息
    if [[ -n "$instance_dir" && -f "$instance_dir/info" ]]; then
        source "$instance_dir/info"
        started_at="$STARTED_AT"
        pid="$PID"
        conversation_file="$CONVERSATION_FILE"
    fi
    
    # 获取角色信息
    role=$(get_instance_role "$instance_id" "$namespace")
    
    # 获取工具列表
    if [[ -n "$project_dir" && -d "$project_dir/.amazonq/rules" ]]; then
        for tool_file in "$project_dir/.amazonq/rules"/tools_*.md; do
            if [[ -f "$tool_file" ]]; then
                local tool_name=$(basename "$tool_file" | sed 's/tools_//' | sed 's/.md$//')
                tools+=("$tool_name")
            fi
        done
    fi
    
    # 构建工具 JSON 数组
    local tools_json=""
    if [ ${#tools[@]} -gt 0 ]; then
        tools_json="["
        local first_tool=true
        for tool in "${tools[@]}"; do
            if [ "$first_tool" = true ]; then
                first_tool=false
            else
                tools_json+=", "
            fi
            tools_json+="\"$tool\""
        done
        tools_json+="]"
    else
        tools_json="[]"
    fi
    
    echo "{"
    echo "  \"id\": \"$instance_id\","
    echo "  \"status\": \"$status\","
    echo "  \"namespace\": \"$namespace\","
    echo "  \"session\": \"${session_info:-q_instance_$instance_id}\","
    echo "  \"project_dir\": \"${project_dir:-null}\","
    echo "  \"role\": \"${role:-""}\","
    echo "  \"tools\": $tools_json,"
    echo "  \"started_at\": \"${started_at:-""}\","
    echo "  \"pid\": \"${pid:-""}\","
    echo "  \"instance_dir\": \"${instance_dir:-null}\","
    echo "  \"log_file\": \"${log_file:-null}\","
    
    if [[ -f "$log_file" ]]; then
        echo "  \"log_size\": $log_size,"
        echo "  \"log_modified\": \"$log_modified\","
    else
        echo "  \"log_size\": 0,"
        echo "  \"log_modified\": null,"
    fi
    
    echo "  \"conversation_file\": \"${conversation_file:-""}\","
    echo "  \"attach_command\": \"tmux attach-session -t q_instance_$instance_id\""
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
