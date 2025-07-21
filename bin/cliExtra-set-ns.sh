#!/bin/bash

# cliExtra 实例namespace修改脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra set-ns <instance_id> <namespace>"
    echo ""
    echo "参数:"
    echo "  instance_id   要修改的实例ID"
    echo "  namespace     目标namespace名称"
    echo ""
    echo "示例:"
    echo "  cliExtra set-ns myinstance frontend    # 将实例移动到frontend namespace"
    echo "  cliExtra set-ns myinstance default     # 将实例移动到default namespace"
}

# 修改实例的namespace
set_instance_namespace() {
    local instance_id="$1"
    local new_namespace="$2"
    
    if [[ -z "$instance_id" || -z "$new_namespace" ]]; then
        echo "错误: 请指定实例ID和目标namespace"
        show_help
        return 1
    fi
    
    # 验证namespace名称
    if [[ ! "$new_namespace" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "错误: namespace名称只能包含字母、数字、下划线和连字符"
        return 1
    fi
    
    # 检查实例是否存在
    local session_name="q_instance_$instance_id"
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "错误: 实例 $instance_id 不存在或未运行"
        return 1
    fi
    
    # 查找实例的项目目录
    local project_dir=$(find_instance_project "$instance_id")
    if [[ $? -ne 0 ]]; then
        echo "错误: 未找到实例 $instance_id 的项目目录"
        return 1
    fi
    
    local instance_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
    local ns_file="$instance_dir/namespace"
    local info_file="$instance_dir/info"
    
    # 获取当前namespace
    local current_namespace="default"
    if [[ -f "$ns_file" ]]; then
        current_namespace=$(cat "$ns_file")
    fi
    
    if [[ "$current_namespace" == "$new_namespace" ]]; then
        echo "实例 $instance_id 已经在namespace '$new_namespace' 中"
        return 0
    fi
    
    # 如果目标namespace不是default，检查是否存在
    if [[ "$new_namespace" != "default" ]]; then
        local ns_config_dir="$CLIEXTRA_HOME/namespaces"
        local ns_config_file="$ns_config_dir/$new_namespace.conf"
        
        if [[ ! -f "$ns_config_file" ]]; then
            echo "错误: namespace '$new_namespace' 不存在"
            echo "请先创建namespace: cliExtra ns create $new_namespace"
            return 1
        fi
    fi
    
    echo "将实例 $instance_id 从 '$current_namespace' 移动到 '$new_namespace'"
    
    # 更新namespace文件
    echo "$new_namespace" > "$ns_file"
    
    # 更新info文件中的namespace信息
    if [[ -f "$info_file" ]]; then
        # 创建临时文件
        local temp_file=$(mktemp)
        
        # 更新或添加NAMESPACE行
        if grep -q "^NAMESPACE=" "$info_file"; then
            sed "s/^NAMESPACE=.*/NAMESPACE=\"$new_namespace\"/" "$info_file" > "$temp_file"
        else
            cp "$info_file" "$temp_file"
            echo "NAMESPACE=\"$new_namespace\"" >> "$temp_file"
        fi
        
        # 替换原文件
        mv "$temp_file" "$info_file"
    fi
    
    # 记录到日志
    local log_file="$project_dir/.cliExtra/logs/instance_$instance_id.log"
    echo "$(date): 实例namespace从 '$current_namespace' 修改为 '$new_namespace'" >> "$log_file"
    
    echo "✓ 实例 $instance_id 已移动到namespace '$new_namespace'"
}

# 主逻辑
if [[ $# -eq 2 ]]; then
    set_instance_namespace "$1" "$2"
else
    show_help
fi
