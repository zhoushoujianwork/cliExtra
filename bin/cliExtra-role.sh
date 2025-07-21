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

# 角色定义
ROLE_KEYS=("frontend" "backend" "test" "reviewer" "devops")
ROLE_NAMES=("前端工程师" "后端工程师" "测试工程师" "代码审查工程师" "运维工程师")

# 获取角色名称
get_role_name() {
    local role="$1"
    for i in "${!ROLE_KEYS[@]}"; do
        if [ "${ROLE_KEYS[$i]}" = "$role" ]; then
            echo "${ROLE_NAMES[$i]}"
            return 0
        fi
    done
    return 1
}

# 检查角色是否存在
role_exists() {
    local role="$1"
    for key in "${ROLE_KEYS[@]}"; do
        if [ "$key" = "$role" ]; then
            return 0
        fi
    done
    return 1
}

# 显示帮助
show_help() {
    echo ""
    echo "=== cliExtra 角色管理 ==="
    echo "用法:"
    echo "  $0 list                    - 列出所有可用角色"
    echo "  $0 show <role>             - 显示指定角色的预设内容"
    echo "  $0 apply <role> [instance] [-f] - 应用角色预设到项目或指定实例"
    echo "  $0 remove [instance]       - 移除项目或指定实例中的角色预设"
    echo "  $0 help                    - 显示此帮助"
    echo ""
    echo "可用角色:"
    for i in "${!ROLE_KEYS[@]}"; do
        echo "  ${ROLE_KEYS[$i]} - ${ROLE_NAMES[$i]}"
    done
    echo ""
    echo "示例:"
    echo "  $0 list                    # 列出所有角色"
    echo "  $0 show frontend           # 显示前端工程师预设"
    echo "  $0 apply frontend          # 在当前项目应用前端工程师角色"
    echo "  $0 apply backend myproject # 在指定实例应用后端工程师角色"
    echo "  $0 apply devops -f         # 强制应用运维工程师角色（不确认）"
    echo "  $0 remove                  # 移除当前项目的角色预设"
    echo "  $0 remove myproject        # 移除指定实例的角色预设"
    echo ""
}

# 列出所有角色
list_roles() {
    echo -e "${BLUE}=== 可用角色列表 ===${NC}"
    echo ""
    for i in "${!ROLE_KEYS[@]}"; do
        echo -e "${GREEN}${ROLE_KEYS[$i]}${NC} - ${ROLE_NAMES[$i]}"
    done
    echo ""
}

# 显示角色预设内容
show_role() {
    local arg="${1:-.}"
    
    # 如果是角色名
    if role_exists "$arg"; then
        local role_file="$(dirname "$(dirname "$0")")/roles/${arg}-engineer.md"
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
        local rules_dir="$arg/.amazonq/rules"
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

# 应用角色预设到项目
apply_role() {
    local role="$1"
    local instance_id="$2"
    local force="$3"
    local project_dir=""
    
    if [ -z "$role" ]; then
        echo -e "${RED}错误: 请指定角色名称${NC}"
        return 1
    fi
    
    if ! role_exists "$role"; then
        echo -e "${RED}错误: 未知角色 '$role'${NC}"
        echo "可用角色: ${ROLE_KEYS[*]}"
        return 1
    fi
    
    # 如果指定了实例ID，查找对应的项目目录
    if [ -n "$instance_id" ]; then
        project_dir=$(find_instance_project "$instance_id")
        if [ $? -ne 0 ]; then
            echo -e "${RED}错误: 找不到实例 $instance_id 对应的项目${NC}"
            return 1
        fi
        echo -e "${BLUE}找到实例 $instance_id 的项目目录: $project_dir${NC}"
    else
        # 使用当前目录
        project_dir="."
    fi
    
    # 检查项目目录
    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}错误: 项目目录不存在: $project_dir${NC}"
        return 1
    fi
    
    local role_file="$(dirname "$(dirname "$0")")/roles/${role}-engineer.md"
    
    if [ ! -f "$role_file" ]; then
        echo -e "${RED}错误: 角色文件不存在: $role_file${NC}"
        return 1
    fi
    
    # 创建.amazonq目录（如果不存在）
    local amazonq_dir="$project_dir/.amazonq"
    if [ ! -d "$amazonq_dir" ]; then
        echo -e "${YELLOW}创建.amazonq目录: $amazonq_dir${NC}"
        mkdir -p "$amazonq_dir"
    fi
    
    # 创建rules目录（如果不存在）
    local rules_dir="$amazonq_dir/rules"
    if [ ! -d "$rules_dir" ]; then
        echo -e "${YELLOW}创建rules目录: $rules_dir${NC}"
        mkdir -p "$rules_dir"
    fi
    
    # 检查是否已有其他角色预设
    local existing_roles=()
    for existing_role in "${ROLE_KEYS[@]}"; do
        local existing_file="$rules_dir/${existing_role}-engineer.md"
        if [ -f "$existing_file" ]; then
            existing_roles+=("$existing_role")
        fi
    done
    
    # 如果已有角色预设，询问是否替换
    if [ ${#existing_roles[@]} -gt 0 ]; then
        echo -e "${YELLOW}警告: 项目中已存在角色预设${NC}"
        for existing_role in "${existing_roles[@]}"; do
            local existing_name=$(get_role_name "$existing_role")
            echo -e "  - $existing_name"
        done
        echo ""
        echo -e "${YELLOW}注意: 每个项目建议只保留一个角色预设，多个角色可能导致意图识别混乱${NC}"
        echo ""
        
        # 如果指定了强制模式，直接替换
        if [ "$force" = "true" ]; then
            echo -e "${YELLOW}强制模式: 自动替换现有角色预设${NC}"
        else
            read -p "是否替换现有角色预设? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}操作已取消${NC}"
                return 0
            fi
        fi
        
        # 移除现有角色预设
        echo -e "${YELLOW}移除现有角色预设...${NC}"
        for existing_role in "${existing_roles[@]}"; do
            local existing_file="$rules_dir/${existing_role}-engineer.md"
            rm -f "$existing_file"
            local existing_name=$(get_role_name "$existing_role")
            echo -e "${GREEN}✓ 已移除: $existing_name${NC}"
        done
    fi
    
    # 复制角色预设文件
    local target_file="$rules_dir/${role}-engineer.md"
    local role_name=$(get_role_name "$role")
    echo -e "${YELLOW}应用角色预设: $role_name${NC}"
    cp "$role_file" "$target_file"
    
    # 复制通用边界规则
    local boundary_file="$(dirname "$(dirname "$0")")/rules/role-boundaries.md"
    if [ -f "$boundary_file" ]; then
        local boundary_target="$rules_dir/role-boundaries.md"
        echo -e "${YELLOW}应用通用角色边界规则${NC}"
        cp "$boundary_file" "$boundary_target"
    fi
    
    echo -e "${GREEN}✓ 角色预设已应用到项目: $project_dir${NC}"
    echo -e "${BLUE}角色预设文件: $target_file${NC}"
    echo -e "${BLUE}边界规则文件: $rules_dir/role-boundaries.md${NC}"
}

# 移除项目中的角色预设
remove_role() {
    local instance_id="$1"
    local project_dir=""
    
    # 如果指定了实例ID，查找对应的项目目录
    if [ -n "$instance_id" ]; then
        project_dir=$(find_instance_project "$instance_id")
        if [ $? -ne 0 ]; then
            echo -e "${RED}错误: 找不到实例 $instance_id 对应的项目${NC}"
            return 1
        fi
        echo -e "${BLUE}找到实例 $instance_id 的项目目录: $project_dir${NC}"
    else
        # 使用当前目录
        project_dir="."
    fi
    
    # 检查项目目录
    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}错误: 项目目录不存在: $project_dir${NC}"
        return 1
    fi
    
    local rules_dir="$project_dir/.amazonq/rules"
    
    if [ ! -d "$rules_dir" ]; then
        echo -e "${YELLOW}项目中没有角色预设${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}移除项目中的角色预设...${NC}"
    
    # 移除所有角色预设文件
    local removed_count=0
    for role in "${ROLE_KEYS[@]}"; do
        local role_file="$rules_dir/${role}-engineer.md"
        if [ -f "$role_file" ]; then
            rm -f "$role_file"
            local role_name=$(get_role_name "$role")
            echo -e "${GREEN}✓ 已移除: $role_name${NC}"
            ((removed_count++))
        fi
    done
    
    # 移除通用边界规则
    local boundary_file="$rules_dir/role-boundaries.md"
    if [ -f "$boundary_file" ]; then
        rm -f "$boundary_file"
        echo -e "${GREEN}✓ 已移除: 通用角色边界规则${NC}"
        ((removed_count++))
    fi
    
    if [ $removed_count -eq 0 ]; then
        echo -e "${YELLOW}没有找到角色预设文件${NC}"
    else
        echo -e "${GREEN}✓ 已移除 $removed_count 个文件${NC}"
    fi
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