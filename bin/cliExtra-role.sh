#!/bin/bash

# cliExtra 角色管理脚本
# 用于管理q chat的角色预设

# 加载公共函数
source "$(dirname "$0")/cliExtra-common.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 系统配置
CLIEXTRA_HOME="${CLIEXTRA_HOME}"

# 角色定义（动态加载 roles 目录）
ROLES_DIR="$(dirname "$(dirname "$0")")/roles"

# 动态获取所有角色key（如 frontend、backend、embedded 等）
get_all_role_keys() {
    local files=($(ls "$ROLES_DIR"/*-engineer.md 2>/dev/null))
    for file in "${files[@]}"; do
        basename "$file" | sed 's/-engineer\.md$//'
    done
}

# 动态获取角色中文名称（取文件第一行或第二行的中文）
get_role_name() {
    local role="$1"
    local file="$ROLES_DIR/${role}-engineer.md"
    if [ -f "$file" ]; then
        # 取第一行 # 后的中文，去除空格和“角色预设”
        local name_line=$(head -n 1 "$file")
        local zh_name=$(echo "$name_line" | sed -E 's/^# *([^ ]+).*角色预设.*/\1/' | tr -d ' ')
        if [[ -n "$zh_name" && "$zh_name" != "$name_line" ]]; then
            echo "$zh_name"
            return 0
        fi
        # 取第二行的**中文**
        name_line=$(sed -n '2p' "$file")
        zh_name=$(echo "$name_line" | grep -oE '\*\*([^*]+)\*\*' | head -n1 | sed 's/\*//g')
        if [ -n "$zh_name" ]; then
            echo "$zh_name"
            return 0
        fi
    fi
    echo "$role"
    return 1
}

# 检查角色是否存在
role_exists() {
    local role="$1"
    local file="$ROLES_DIR/${role}-engineer.md"
    [ -f "$file" ]
}

# 显示帮助
show_help() {
    echo ""
    echo "=== cliExtra 角色管理 ==="
    echo "用法:"
    echo "  $0 list                    - 列出所有可用角色"
    echo "  $0 show <role>             - 显示指定角色的预设内容"
    echo "  $0 apply <role> [instance] [-f] - 应用角色预设到运行中的实例"
    echo "  $0 remove [instance]       - 移除实例中的角色预设"
    echo "  $0 help                    - 显示此帮助"
    echo ""
    echo "可用角色:"
    for role in $(get_all_role_keys); do
        local name=$(get_role_name "$role")
        echo "  $role - $name"
    done
    echo ""
    echo "角色应用说明:"
    echo "  - apply 命令会将角色定义发送到运行中的实例"
    echo "  - 角色信息会保存到系统目录中"
    echo "  - 如果不指定实例ID，会自动查找当前目录对应的运行实例"
    echo ""
    echo "示例:"
    echo "  $0 list                    # 列出所有角色"
    echo "  $0 show frontend           # 显示前端工程师预设"
    echo "  $0 apply frontend          # 在当前目录的实例应用前端工程师角色"
    echo "  $0 apply backend myproject # 在指定实例应用后端工程师角色"
    echo "  $0 apply devops -f         # 强制应用运维工程师角色（不确认）"
    echo "  $0 remove                  # 移除当前目录实例的角色预设"
    echo "  $0 remove myproject        # 移除指定实例的角色预设"
    echo ""
}

# 列出所有角色
list_roles() {
    echo -e "${BLUE}=== 可用角色列表 ===${NC}"
    echo ""
    for role in $(get_all_role_keys); do
        local name=$(get_role_name "$role")
        echo -e "${GREEN}${role}${NC} - ${name}"
    done
    echo ""
}

# 显示角色预设内容
show_role() {
    local arg="${1:-.}"
    
    # 如果是角色名
    if role_exists "$arg"; then
        local role_file="$ROLES_DIR/${arg}-engineer.md"
        if [ ! -f "$role_file" ]; then
            echo -e "${RED}错误: 角色文件不存在: $role_file${NC}"
            return 1
        fi
        local role_name=$(get_role_name "$arg")
        echo -e "${BLUE}=== $role_name 角色预设 ===${NC}"
        echo ""
        cat "$role_file"
        echo ""
        return 0
    fi
    
    # 如果是目录
    if [ -d "$arg" ]; then
        local rules_dir="$(get_project_rules_dir "$arg")"
        if [ ! -d "$rules_dir" ]; then
            echo -e "${YELLOW}该目录下没有角色预设${NC}"
            return 0
        fi
        local found_files=("$rules_dir"/*-engineer.md)
        if [ ! -e "${found_files[0]}" ]; then
            echo -e "${YELLOW}该目录下没有角色预设${NC}"
            return 0
        fi
        if [ ${#found_files[@]} -gt 1 ]; then
            echo -e "${YELLOW}警告: 该目录下存在多个角色预设文件，仅显示第一个${NC}"
        fi
        local file="${found_files[0]}"
        local role_key=$(basename "$file" -engineer.md)
        local role_name=$(get_role_name "$role_key")
        echo -e "${GREEN}当前角色: $role_name${NC}"
        return 0
    fi
    
    echo -e "${RED}错误: 未知角色或目录: $arg${NC}"
    return 1
}

# 应用角色预设到实例
apply_role() {
    local role="$1"
    local instance_id="$2"
    local force="$3"
    
    if [ -z "$role" ]; then
        echo -e "${RED}错误: 请指定角色名称${NC}"
        return 1
    fi
    
    if ! role_exists "$role"; then
        echo -e "${RED}错误: 未知角色 '$role'${NC}"
        echo "可用角色: $(get_all_role_keys)"
        return 1
    fi
    
    # 如果没有指定实例ID，尝试从当前目录查找运行中的实例
    if [ -z "$instance_id" ]; then
        instance_id=$(find_current_directory_instance)
        if [ -z "$instance_id" ]; then
            echo -e "${RED}错误: 请指定实例ID或在有运行实例的项目目录中执行${NC}"
            echo "使用方法: qq role apply $role <instance_id>"
            return 1
        fi
        echo -e "${BLUE}找到当前目录的实例: $instance_id${NC}"
    fi
    
    # 检查实例是否存在和运行
    local session_name="q_instance_$instance_id"
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo -e "${RED}错误: 实例 $instance_id 未运行${NC}"
        echo "请先启动实例或指定正确的实例ID"
        return 1
    fi
    
    # 获取实例信息
    local instance_info=$(get_instance_info "$instance_id")
    if [ -z "$instance_info" ]; then
        echo -e "${RED}错误: 找不到实例 $instance_id 的信息${NC}"
        return 1
    fi
    
    local namespace=$(get_instance_namespace "$instance_id")
    if [ -z "$namespace" ]; then
        namespace="default"
    fi
    
    local role_file="$ROLES_DIR/${role}-engineer.md"
    if [ ! -f "$role_file" ]; then
        echo -e "${RED}错误: 角色文件不存在: $role_file${NC}"
        return 1
    fi
    
    local role_name=$(get_role_name "$role")
    
    # 检查是否需要确认
    if [ "$force" != "true" ]; then
        echo -e "${YELLOW}将为实例 $instance_id 应用角色: $role_name${NC}"
        read -p "确认继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}操作已取消${NC}"
            return 0
        fi
    fi
    
    # 1. 保存角色信息到系统目录
    echo -e "${YELLOW}保存角色信息到系统目录...${NC}"
    local instance_dir="$CLIEXTRA_HOME/namespaces/$namespace/instances/instance_$instance_id"
    local roles_dir="$instance_dir/roles"
    
    # 创建角色目录
    mkdir -p "$roles_dir"
    
    # 复制角色文件到系统目录
    local target_role_file="$roles_dir/${role}-engineer.md"
    cp "$role_file" "$target_role_file"
    echo -e "${GREEN}✓ 角色文件已保存: $target_role_file${NC}"
    
    # 复制通用边界规则
    local boundary_file="$(dirname "$(dirname "$0")")/rules/role-boundaries.md"
    if [ -f "$boundary_file" ]; then
        local boundary_target="$roles_dir/role-boundaries.md"
        cp "$boundary_file" "$boundary_target"
        echo -e "${GREEN}✓ 边界规则已保存: $boundary_target${NC}"
    fi
    
    # 2. 更新实例info文件中的角色信息
    echo -e "${YELLOW}更新实例角色信息...${NC}"
    local info_file="$instance_dir/info"
    if [ -f "$info_file" ]; then
        # 移除旧的ROLE行并添加新的
        grep -v "^ROLE=" "$info_file" > "$info_file.tmp"
        echo "ROLE=$role" >> "$info_file.tmp"
        echo "ROLE_FILE=$target_role_file" >> "$info_file.tmp"
        mv "$info_file.tmp" "$info_file"
        echo -e "${GREEN}✓ 实例信息已更新${NC}"
    else
        echo -e "${RED}警告: 实例信息文件不存在: $info_file${NC}"
    fi
    
    # 3. 通过消息方式发送角色定义到实例
    echo -e "${YELLOW}发送角色定义到实例...${NC}"
    
    # 读取角色文件内容
    local role_content=$(cat "$role_file")
    
    # 构建角色应用消息
    local role_message="请按照以下角色定义来协助我：

$role_content

请确认你已理解并将按照以上角色定义来协助我的工作。"
    
    # 发送角色定义消息到实例
    tmux send-keys -t "$session_name" "$role_message" Enter
    
    echo -e "${GREEN}✓ 角色定义已发送到实例 $instance_id${NC}"
    echo -e "${GREEN}✓ 角色预设应用完成: $role_name${NC}"
    echo ""
    echo -e "${BLUE}角色信息:${NC}"
    echo -e "  实例ID: $instance_id"
    echo -e "  角色: $role_name"
    echo -e "  命名空间: $namespace"
    echo -e "  角色文件: $target_role_file"
}

# 移除实例中的角色预设
remove_role() {
    local instance_id="$1"
    
    # 如果没有指定实例ID，尝试从当前目录查找运行中的实例
    if [ -z "$instance_id" ]; then
        instance_id=$(find_current_directory_instance)
        if [ -z "$instance_id" ]; then
            echo -e "${RED}错误: 请指定实例ID或在有运行实例的项目目录中执行${NC}"
            echo "使用方法: qq role remove <instance_id>"
            return 1
        fi
        echo -e "${BLUE}找到当前目录的实例: $instance_id${NC}"
    fi
    
    # 检查实例是否存在
    local instance_info=$(get_instance_info "$instance_id")
    if [ -z "$instance_info" ]; then
        echo -e "${RED}错误: 找不到实例 $instance_id${NC}"
        return 1
    fi
    
    local namespace=$(get_instance_namespace "$instance_id")
    if [ -z "$namespace" ]; then
        namespace="default"
    fi
    
    local instance_dir="$CLIEXTRA_HOME/namespaces/$namespace/instances/instance_$instance_id"
    local roles_dir="$instance_dir/roles"
    
    if [ ! -d "$roles_dir" ]; then
        echo -e "${YELLOW}实例中没有角色预设${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}移除实例 $instance_id 中的角色预设...${NC}"
    
    # 移除所有角色预设文件
    local removed_count=0
    for role in $(get_all_role_keys); do
        local role_file="$roles_dir/${role}-engineer.md"
        if [ -f "$role_file" ]; then
            rm -f "$role_file"
            local role_name=$(get_role_name "$role")
            echo -e "${GREEN}✓ 已移除: $role_name${NC}"
            ((removed_count++))
        fi
    done
    
    # 移除通用边界规则
    local boundary_file="$roles_dir/role-boundaries.md"
    if [ -f "$boundary_file" ]; then
        rm -f "$boundary_file"
        echo -e "${GREEN}✓ 已移除: 通用角色边界规则${NC}"
        ((removed_count++))
    fi
    
    # 更新实例info文件，移除角色信息
    local info_file="$instance_dir/info"
    if [ -f "$info_file" ]; then
        grep -v "^ROLE=" "$info_file" | grep -v "^ROLE_FILE=" > "$info_file.tmp"
        mv "$info_file.tmp" "$info_file"
        echo -e "${GREEN}✓ 已更新实例信息${NC}"
    fi
    
    # 如果角色目录为空，删除它
    if [ -d "$roles_dir" ] && [ -z "$(ls -A "$roles_dir")" ]; then
        rmdir "$roles_dir"
        echo -e "${GREEN}✓ 已清理空的角色目录${NC}"
    fi
    
    if [ $removed_count -eq 0 ]; then
        echo -e "${YELLOW}没有找到角色预设文件${NC}"
    else
        echo -e "${GREEN}✓ 已移除 $removed_count 个文件${NC}"
        
        # 发送角色移除通知到实例（如果实例在运行）
        local session_name="q_instance_$instance_id"
        if tmux has-session -t "$session_name" 2>/dev/null; then
            local remove_message="角色预设已被移除，你现在可以按照通用AI助手的方式协助工作。"
            tmux send-keys -t "$session_name" "$remove_message" Enter
            echo -e "${GREEN}✓ 已通知实例角色预设已移除${NC}"
        fi
    fi
}

# 查找当前目录对应的运行实例
find_current_directory_instance() {
    local current_dir=$(pwd)
    local current_dir_abs=$(cd "$current_dir" && pwd)
    
    # 遍历所有namespace查找匹配的实例
    for namespace_dir in "$CLIEXTRA_HOME/namespaces"/*; do
        if [ ! -d "$namespace_dir" ]; then
            continue
        fi
        
        local namespace=$(basename "$namespace_dir")
        local instances_dir="$namespace_dir/instances"
        
        if [ ! -d "$instances_dir" ]; then
            continue
        fi
        
        # 遍历该namespace下的所有实例
        for instance_dir in "$instances_dir"/instance_*; do
            if [ ! -d "$instance_dir" ]; then
                continue
            fi
            
            local instance_id=$(basename "$instance_dir" | sed 's/^instance_//')
            local project_path_file="$instance_dir/project_path"
            
            if [ -f "$project_path_file" ]; then
                local project_path=$(cat "$project_path_file")
                local project_path_abs=$(cd "$project_path" 2>/dev/null && pwd)
                
                # 检查路径是否匹配
                if [ "$current_dir_abs" = "$project_path_abs" ]; then
                    # 检查实例是否在运行
                    local session_name="q_instance_$instance_id"
                    if tmux has-session -t "$session_name" 2>/dev/null; then
                        echo "$instance_id"
                        return 0
                    fi
                fi
            fi
        done
    done
    
    return 1
}

# 获取实例信息
get_instance_info() {
    local instance_id="$1"
    
    # 遍历所有namespace查找实例
    for namespace_dir in "$CLIEXTRA_HOME/namespaces"/*; do
        if [ ! -d "$namespace_dir" ]; then
            continue
        fi
        
        local instance_dir="$namespace_dir/instances/instance_$instance_id"
        local info_file="$instance_dir/info"
        
        if [ -f "$info_file" ]; then
            cat "$info_file"
            return 0
        fi
    done
    
    return 1
}

# 获取实例的命名空间
get_instance_namespace() {
    local instance_id="$1"
    
    # 遍历所有namespace查找实例
    for namespace_dir in "$CLIEXTRA_HOME/namespaces"/*; do
        if [ ! -d "$namespace_dir" ]; then
            continue
        fi
        
        local namespace=$(basename "$namespace_dir")
        local instance_dir="$namespace_dir/instances/instance_$instance_id"
        
        if [ -d "$instance_dir" ]; then
            echo "$namespace"
            return 0
        fi
    done
    
    return 1
}

# 解析参数
parse_apply_args() {
    local role=""
    local instance_id=""
    local force="false"
    
    shift  # 移除 "apply" 参数
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force="true"
                shift
                ;;
            -*)
                echo "未知参数: $1"
                return 1
                ;;
            *)
                if [ -z "$role" ]; then
                    role="$1"
                elif [ -z "$instance_id" ]; then
                    instance_id="$1"
                else
                    echo "多余的参数: $1"
                    return 1
                fi
                shift
                ;;
        esac
    done
    
    echo "$role|$instance_id|$force"
}

# 主逻辑
case "${1:-}" in
    "list")
        list_roles
        ;;
    "show")
        show_role "$2"
        ;;
    "apply")
        args_result=$(parse_apply_args "$@")
        if [ $? -ne 0 ]; then
            echo "参数解析错误"
            exit 1
        fi
        IFS='|' read -r role instance_id force <<< "$args_result"
        apply_role "$role" "$instance_id" "$force"
        ;;
    "remove")
        remove_role "$2"
        ;;
    "help"|"")
        show_help
        ;;
    *)
        echo "未知命令: $1"
        show_help
        exit 1
        ;;
esac 