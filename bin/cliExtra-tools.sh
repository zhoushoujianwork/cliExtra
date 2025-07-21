#!/bin/bash

# cliExtra 工具管理脚本

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra tools <command> [options]"
    echo ""
    echo "命令:"
    echo "  list                     列出所有可用工具"
    echo "  add <tool_name>          添加工具到当前项目"
    echo "  remove <tool_name>       从当前项目移除工具"
    echo "  show <tool_name>         显示工具详细信息"
    echo "  installed                显示当前项目已安装的工具"
    echo ""
    echo "选项:"
    echo "  --project <path>         指定项目路径（默认当前目录）"
    echo ""
    echo "示例:"
    echo "  cliExtra tools list                    # 列出所有可用工具"
    echo "  cliExtra tools add git                 # 添加git工具到当前项目"
    echo "  cliExtra tools add dingtalk            # 添加钉钉工具到当前项目"
    echo "  cliExtra tools remove git              # 从当前项目移除git工具"
    echo "  cliExtra tools show git                # 显示git工具详细信息"
    echo "  cliExtra tools installed               # 显示当前项目已安装的工具"
}

# 获取tools源目录
get_tools_source_dir() {
    echo "$SCRIPT_DIR/../tools"
}

# 获取项目目录
get_project_dir() {
    local project_path="${1:-$(pwd)}"
    
    # 转换为绝对路径
    if [[ "$project_path" = /* ]]; then
        echo "$project_path"
    else
        echo "$(pwd)/$project_path"
    fi
}

# 获取项目的tools目录
get_project_tools_dir() {
    local project_dir="$1"
    echo "$project_dir/.amazonq/rules"
}

# 列出所有可用工具
list_available_tools() {
    local tools_source_dir=$(get_tools_source_dir)
    
    if [[ ! -d "$tools_source_dir" ]]; then
        echo "错误: tools源目录不存在: $tools_source_dir"
        return 1
    fi
    
    echo "=== 可用工具 ==="
    printf "%-15s %s\n" "工具名称" "描述"
    printf "%-15s %s\n" "--------" "----"
    
    for tool_file in "$tools_source_dir"/*.md; do
        if [[ -f "$tool_file" ]]; then
            local tool_name=$(basename "$tool_file" .md)
            local description=$(head -n 1 "$tool_file" | sed 's/^# //')
            printf "%-15s %s\n" "$tool_name" "$description"
        fi
    done
}

# 显示工具详细信息
show_tool_info() {
    local tool_name="$1"
    local tools_source_dir=$(get_tools_source_dir)
    local tool_file="$tools_source_dir/$tool_name.md"
    
    if [[ ! -f "$tool_file" ]]; then
        echo "错误: 工具 '$tool_name' 不存在"
        return 1
    fi
    
    echo "=== 工具详情: $tool_name ==="
    cat "$tool_file"
}

# 添加工具到项目
add_tool_to_project() {
    local tool_name="$1"
    local project_dir="$2"
    local tools_source_dir=$(get_tools_source_dir)
    local project_tools_dir=$(get_project_tools_dir "$project_dir")
    
    # 检查工具是否存在
    local source_tool_file="$tools_source_dir/$tool_name.md"
    if [[ ! -f "$source_tool_file" ]]; then
        echo "错误: 工具 '$tool_name' 不存在"
        echo "使用 'cliExtra tools list' 查看可用工具"
        return 1
    fi
    
    # 创建项目tools目录
    mkdir -p "$project_tools_dir"
    
    # 目标文件名
    local target_tool_file="$project_tools_dir/tools_$tool_name.md"
    
    # 检查是否已经安装
    if [[ -f "$target_tool_file" ]]; then
        echo "工具 '$tool_name' 已经安装在项目中"
        echo "文件位置: $target_tool_file"
        return 0
    fi
    
    # 复制工具文件
    if cp "$source_tool_file" "$target_tool_file"; then
        echo "✓ 工具 '$tool_name' 已添加到项目"
        echo "文件位置: $target_tool_file"
        
        # 记录安装信息
        local install_log="$project_dir/.cliExtra/tools_installed.log"
        mkdir -p "$(dirname "$install_log")"
        echo "$(date): 安装工具 $tool_name" >> "$install_log"
    else
        echo "✗ 工具 '$tool_name' 添加失败"
        return 1
    fi
}

# 从项目移除工具
remove_tool_from_project() {
    local tool_name="$1"
    local project_dir="$2"
    local project_tools_dir=$(get_project_tools_dir "$project_dir")
    local target_tool_file="$project_tools_dir/tools_$tool_name.md"
    
    # 检查工具是否已安装
    if [[ ! -f "$target_tool_file" ]]; then
        echo "工具 '$tool_name' 未安装在当前项目中"
        return 1
    fi
    
    # 删除工具文件
    if rm -f "$target_tool_file"; then
        echo "✓ 工具 '$tool_name' 已从项目中移除"
        
        # 记录卸载信息
        local install_log="$project_dir/.cliExtra/tools_installed.log"
        mkdir -p "$(dirname "$install_log")"
        echo "$(date): 卸载工具 $tool_name" >> "$install_log"
    else
        echo "✗ 工具 '$tool_name' 移除失败"
        return 1
    fi
}

# 显示项目已安装的工具
show_installed_tools() {
    local project_dir="$1"
    local project_tools_dir=$(get_project_tools_dir "$project_dir")
    
    if [[ ! -d "$project_tools_dir" ]]; then
        echo "当前项目未安装任何工具"
        return 0
    fi
    
    echo "=== 已安装工具 (项目: $project_dir) ==="
    printf "%-15s %s\n" "工具名称" "描述"
    printf "%-15s %s\n" "--------" "----"
    
    local found_tools=false
    for tool_file in "$project_tools_dir"/tools_*.md; do
        if [[ -f "$tool_file" ]]; then
            found_tools=true
            local tool_name=$(basename "$tool_file" | sed 's/^tools_//' | sed 's/\.md$//')
            local description=$(head -n 1 "$tool_file" | sed 's/^# //')
            printf "%-15s %s\n" "$tool_name" "$description"
        fi
    done
    
    if [[ "$found_tools" == false ]]; then
        echo "当前项目未安装任何工具"
    fi
}

# 解析参数
PROJECT_DIR=""
COMMAND=""
TOOL_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_DIR="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        list|add|remove|show|installed)
            COMMAND="$1"
            if [[ "$1" == "add" || "$1" == "remove" || "$1" == "show" ]]; then
                TOOL_NAME="$2"
                shift 2
            else
                shift
            fi
            ;;
        *)
            if [[ -z "$COMMAND" ]]; then
                COMMAND="$1"
                shift
            elif [[ -z "$TOOL_NAME" && ("$COMMAND" == "add" || "$COMMAND" == "remove" || "$COMMAND" == "show") ]]; then
                TOOL_NAME="$1"
                shift
            else
                echo "未知参数: $1"
                show_help
                exit 1
            fi
            ;;
    esac
done

# 设置默认项目目录
if [[ -z "$PROJECT_DIR" ]]; then
    PROJECT_DIR=$(get_project_dir)
fi

# 主逻辑
case "$COMMAND" in
    "list")
        list_available_tools
        ;;
    "add")
        if [[ -z "$TOOL_NAME" ]]; then
            echo "错误: 请指定要添加的工具名称"
            show_help
            exit 1
        fi
        add_tool_to_project "$TOOL_NAME" "$PROJECT_DIR"
        ;;
    "remove")
        if [[ -z "$TOOL_NAME" ]]; then
            echo "错误: 请指定要移除的工具名称"
            show_help
            exit 1
        fi
        remove_tool_from_project "$TOOL_NAME" "$PROJECT_DIR"
        ;;
    "show")
        if [[ -z "$TOOL_NAME" ]]; then
            echo "错误: 请指定要查看的工具名称"
            show_help
            exit 1
        fi
        show_tool_info "$TOOL_NAME"
        ;;
    "installed")
        show_installed_tools "$PROJECT_DIR"
        ;;
    "")
        show_help
        ;;
    *)
        echo "未知命令: $COMMAND"
        show_help
        exit 1
        ;;
esac
