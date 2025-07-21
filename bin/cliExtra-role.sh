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
    echo "  $0 apply <role> [project]  - 应用角色预设到项目"
    echo "  $0 remove [project]        - 移除项目中的角色预设"
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
    echo "  $0 apply backend /path/to/project  # 在指定项目应用后端工程师角色"
    echo "  $0 remove                  # 移除当前项目的角色预设"
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
    local role="$1"
    
    if [ -z "$role" ]; then
        echo -e "${RED}错误: 请指定角色名称${NC}"
        return 1
    fi
    
    if ! role_exists "$role"; then
        echo -e "${RED}错误: 未知角色 '$role'${NC}"
        echo "可用角色: ${ROLE_KEYS[*]}"
        return 1
    fi
    
    local role_file="$(dirname "$(dirname "$0")")/roles/${role}-engineer.md"
    
    if [ ! -f "$role_file" ]; then
        echo -e "${RED}错误: 角色文件不存在: $role_file${NC}"
        return 1
    fi
    
    local role_name=$(get_role_name "$role")
    echo -e "${BLUE}=== $role_name 角色预设 ===${NC}"
    echo ""
    cat "$role_file"
    echo ""
}

# 应用角色预设到项目
apply_role() {
    local role="$1"
    local project_dir="${2:-.}"
    
    if [ -z "$role" ]; then
        echo -e "${RED}错误: 请指定角色名称${NC}"
        return 1
    fi
    
    if ! role_exists "$role"; then
        echo -e "${RED}错误: 未知角色 '$role'${NC}"
        echo "可用角色: ${ROLE_KEYS[*]}"
        return 1
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
    
    # 复制角色预设文件
    local target_file="$rules_dir/${role}-engineer.md"
    local role_name=$(get_role_name "$role")
    echo -e "${YELLOW}应用角色预设: $role_name${NC}"
    cp "$role_file" "$target_file"
    
    echo -e "${GREEN}✓ 角色预设已应用到项目: $project_dir${NC}"
    echo -e "${BLUE}预设文件位置: $target_file${NC}"
}

# 移除项目中的角色预设
remove_role() {
    local project_dir="${1:-.}"
    
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
    
    if [ $removed_count -eq 0 ]; then
        echo -e "${YELLOW}没有找到角色预设文件${NC}"
    else
        echo -e "${GREEN}✓ 已移除 $removed_count 个角色预设${NC}"
    fi
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
        apply_role "$2" "$3"
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