#!/bin/bash

# cliExtra 启动脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 生成随机实例ID
generate_instance_id() {
    echo "$(date +%s)_$$_$(shuf -i 1000-9999 -n 1 2>/dev/null || echo $RANDOM)"
}

# 解析命令行参数
parse_start_args() {
    local instance_name=""
    local project_path=""
    local role=""
    local namespace="default"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name)
                instance_name="$2"
                shift 2
                ;;
            --role)
                role="$2"
                shift 2
                ;;
            --namespace|--ns)
                namespace="$2"
                shift 2
                ;;
            -*)
                echo "未知参数: $1"
                return 1
                ;;
            *)
                if [ -z "$project_path" ]; then
                    project_path="$1"
                else
                    echo "多余的参数: $1"
                    return 1
                fi
                shift
                ;;
        esac
    done
    
    # 如果没有指定实例名字，生成一个
    if [ -z "$instance_name" ]; then
        instance_name=$(generate_instance_id)
        echo "自动生成实例ID: $instance_name" >&2
    fi
    
    echo "$instance_name|$project_path|$role|$namespace"
}

# 项目初始化
init_project() {
    local project_path="$1"
    local target_dir=""
    
    if [ -z "$project_path" ]; then
        # 使用当前目录
        target_dir=$(pwd)
    elif [[ "$project_path" == http*://* ]]; then
        # Git URL 处理
        local repo_name=$(basename "$project_path" .git)
        target_dir="$CLIEXTRA_HOME/projects/$repo_name"
        
        if [ -d "$target_dir" ]; then
            echo "项目已存在: $target_dir"
        else
            echo "正在克隆项目: $project_path"
            if git clone "$project_path" "$target_dir"; then
                echo "✓ 项目克隆成功: $target_dir"
            else
                echo "✗ 项目克隆失败"
                return 1
            fi
        fi
    else
        # 本地路径处理
        if [ ! -d "$project_path" ]; then
            echo "✗ 目录不存在: $project_path"
            return 1
        fi
        target_dir=$(realpath "$project_path")
    fi
    
    # 创建 .cliExtra 目录
    local cliextra_dir="$target_dir/.cliExtra"
    mkdir -p "$cliextra_dir/instances"
    mkdir -p "$cliextra_dir/logs"
    
    # 创建项目配置
    if [ ! -f "$cliextra_dir/config" ]; then
        cat > "$cliextra_dir/config" << EOF
# 项目配置
PROJECT_PATH="$target_dir"
PROJECT_NAME="$(basename "$target_dir")"
CREATED_AT="$(date)"
EOF
    fi
    
    echo "$target_dir"
}

# 同步rules到项目目录
sync_rules_to_project() {
    local project_dir="$1"
    local rules_source_dir="$SCRIPT_DIR/../rules"
    local rules_target_dir="$project_dir/.amazonq/rules"
    
    # 创建目标目录
    mkdir -p "$rules_target_dir"
    
    # 检查源rules目录是否存在
    if [[ ! -d "$rules_source_dir" ]]; then
        echo "警告: rules源目录不存在: $rules_source_dir"
        return 1
    fi
    
    echo "同步rules到项目目录..."
    echo "源目录: $rules_source_dir"
    echo "目标目录: $rules_target_dir"
    
    # 同步所有rules文件
    if cp -r "$rules_source_dir"/* "$rules_target_dir/" 2>/dev/null; then
        echo "✓ rules同步完成"
        
        # 列出同步的文件
        echo "已同步的rules文件:"
        ls -la "$rules_target_dir" | grep -v "^total" | awk '{print "  - " $9}' | grep -v "^  - $"
    else
        echo "⚠ rules同步失败或源目录为空"
    fi
}
start_tmux_instance() {
    local instance_id="$1"
    local project_dir="$2"
    local namespace="$3"
    local session_name="q_instance_$instance_id"
    
    # 使用项目的 .cliExtra 目录
    local cliextra_dir="$project_dir/.cliExtra"
    local session_dir="$cliextra_dir/instances/instance_$instance_id"
    local log_file="$cliextra_dir/logs/instance_$instance_id.log"
    
    echo "$(date): 启动tmux实例 $instance_id 在项目 $project_dir (namespace: $namespace)" >> "$log_file"
    
    # 创建会话目录
    mkdir -p "$session_dir"
    mkdir -p "$(dirname "$log_file")"
    
    # 同步rules到项目目录
    sync_rules_to_project "$project_dir"
    
    # 检查实例是否已经在运行
    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo "实例 $instance_id 已经在运行"
        echo "使用 'tmux attach-session -t $session_name' 接管会话"
        return
    fi
    
    echo "启动tmux q CLI实例 $instance_id"
    echo "项目目录: $project_dir"
    echo "Namespace: $namespace"
    echo "会话名称: $session_name"
    echo "会话目录: $session_dir"
    echo "日志文件: $log_file"
    
    # 启动tmux会话，在项目目录中运行
    tmux new-session -d -s "$session_name" -c "$project_dir" "q chat --resume --trust-all-tools"
    
    # 启用tmux日志记录
    tmux pipe-pane -t "$session_name" -o "cat >> '$session_dir/tmux.log'"
    
    # 等待一下确保会话启动
    sleep 3
    
    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo "✓ 实例 $instance_id 已启动"
        echo "接管会话: tmux attach-session -t $session_name"
        echo "分离会话: 在会话中按 Ctrl+B, D"
        
        # 保存实例信息
        cat > "$session_dir/info" << EOF
INSTANCE_ID="$instance_id"
PROJECT_DIR="$project_dir"
SESSION_NAME="$session_name"
NAMESPACE="$namespace"
STARTED_AT="$(date)"
PID="$$"
EOF
        
        # 保存namespace信息
        echo "$namespace" > "$session_dir/namespace"
        
    else
        echo "✗ 实例 $instance_id 启动失败"
    fi
}

# 主逻辑
# 解析启动参数
args_result=$(parse_start_args "$@")
if [ $? -ne 0 ]; then
    echo "参数解析错误"
    exit 1
fi

# 解析结果
IFS='|' read -r instance_id project_path role namespace <<< "$args_result"

# 初始化项目
project_dir=$(init_project "$project_path")
if [ $? -ne 0 ]; then
    echo "项目初始化失败"
    exit 1
fi

# 应用角色预设（如果指定）
if [ -n "$role" ]; then
    echo "应用角色预设: $role"
    "$SCRIPT_DIR/cliExtra-role.sh" apply "$role"
fi

# 启动实例
start_tmux_instance "$instance_id" "$project_dir" "$namespace" 