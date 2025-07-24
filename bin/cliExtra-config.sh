#!/bin/bash

# cliExtra 统一配置文件
# 包含所有目录定义、路径配置和全局变量

# =============================================================================
# 系统检测和基础配置
# =============================================================================

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 获取当前操作系统
CLIEXTRA_OS=$(detect_os)

# =============================================================================
# 目录配置
# =============================================================================

# 根据操作系统设置工作目录
case "$CLIEXTRA_OS" in
    "macos")
        CLIEXTRA_HOME="$HOME/Library/Application Support/cliExtra"
        ;;
    "linux")
        # 优先使用用户目录，避免权限问题
        if [ -w "/opt" ] && [ "$EUID" -eq 0 ]; then
            # 如果是 root 用户且有写权限，使用系统级目录
            CLIEXTRA_HOME="/opt/cliExtra"
        else
            # 普通用户使用用户目录
            CLIEXTRA_HOME="$HOME/.cliExtra"
        fi
        ;;
    *)
        CLIEXTRA_HOME="$HOME/.cliExtra"
        ;;
esac

# 核心目录结构
CLIEXTRA_CONFIG_DIR="$CLIEXTRA_HOME/config"
CLIEXTRA_NAMESPACES_DIR="$CLIEXTRA_HOME/namespaces"
CLIEXTRA_PROJECTS_DIR="$CLIEXTRA_HOME/projects"
CLIEXTRA_LOGS_DIR="$CLIEXTRA_HOME/logs"
CLIEXTRA_CACHE_DIR="$CLIEXTRA_HOME/cache"

# 默认 namespace 目录
CLIEXTRA_DEFAULT_NS="default"
CLIEXTRA_DEFAULT_NS_DIR="$CLIEXTRA_NAMESPACES_DIR/$CLIEXTRA_DEFAULT_NS"

# 脚本相关目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIEXTRA_BIN_DIR="$SCRIPT_DIR"
CLIEXTRA_ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CLIEXTRA_TOOLS_SOURCE_DIR="$CLIEXTRA_ROOT_DIR/tools"
CLIEXTRA_RULES_SOURCE_DIR="$CLIEXTRA_ROOT_DIR/rules"

# =============================================================================
# 文件路径配置
# =============================================================================

# 全局配置文件
CLIEXTRA_GLOBAL_CONFIG="$CLIEXTRA_CONFIG_DIR/global.conf"
CLIEXTRA_USER_CONFIG="$HOME/.cliExtra/config"

# 日志文件
CLIEXTRA_MAIN_LOG="$CLIEXTRA_LOGS_DIR/cliExtra.log"
CLIEXTRA_ERROR_LOG="$CLIEXTRA_LOGS_DIR/error.log"

# 缓存文件
CLIEXTRA_INSTANCE_CACHE="$CLIEXTRA_CACHE_DIR/instances.cache"
CLIEXTRA_NS_CACHE="$CLIEXTRA_CACHE_DIR/namespaces.cache"

# =============================================================================
# 项目相关配置
# =============================================================================

# 项目配置目录名
CLIEXTRA_PROJECT_CONFIG_DIR=".amazonq"
CLIEXTRA_PROJECT_RULES_DIR="rules"
CLIEXTRA_PROJECT_TOOLS_DIR="tools"

# 项目配置文件
CLIEXTRA_PROJECT_INFO_FILE="info"
CLIEXTRA_PROJECT_NAMESPACE_FILE="namespace"
CLIEXTRA_PROJECT_PATH_FILE="project_path"

# =============================================================================
# 实例相关配置
# =============================================================================

# 实例目录结构
CLIEXTRA_INSTANCES_SUBDIR="instances"
CLIEXTRA_LOGS_SUBDIR="logs"
CLIEXTRA_CONVERSATIONS_SUBDIR="conversations"
CLIEXTRA_STATUS_SUBDIR="status"

# 实例文件名
CLIEXTRA_INSTANCE_INFO_FILE="info"
CLIEXTRA_INSTANCE_LOG_FILE="tmux.log"
CLIEXTRA_INSTANCE_CONVERSATION_FILE="conversation.json"

# tmux 相关配置
CLIEXTRA_TMUX_SESSION_PREFIX="q_instance_"

# =============================================================================
# 默认值配置
# =============================================================================

# 默认工具列表（自动安装）
CLIEXTRA_DEFAULT_TOOLS=("git")

# 默认角色
CLIEXTRA_DEFAULT_ROLE=""

# 超时配置（秒）
CLIEXTRA_TIMEOUT_START=30
CLIEXTRA_TIMEOUT_STOP=10

# =============================================================================
# 颜色配置
# =============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# =============================================================================
# 功能函数
# =============================================================================

# 加载用户配置
load_user_config() {
    if [ -f "$CLIEXTRA_USER_CONFIG" ]; then
        source "$CLIEXTRA_USER_CONFIG"
    fi
    
    if [ -f "$CLIEXTRA_GLOBAL_CONFIG" ]; then
        source "$CLIEXTRA_GLOBAL_CONFIG"
    fi
}

# 初始化目录结构
init_directories() {
    local dirs=(
        "$CLIEXTRA_HOME"
        "$CLIEXTRA_CONFIG_DIR"
        "$CLIEXTRA_NAMESPACES_DIR"
        "$CLIEXTRA_PROJECTS_DIR"
        "$CLIEXTRA_LOGS_DIR"
        "$CLIEXTRA_CACHE_DIR"
        "$CLIEXTRA_DEFAULT_NS_DIR"
        "$CLIEXTRA_DEFAULT_NS_DIR/$CLIEXTRA_INSTANCES_SUBDIR"
        "$CLIEXTRA_DEFAULT_NS_DIR/$CLIEXTRA_LOGS_SUBDIR"
        "$CLIEXTRA_DEFAULT_NS_DIR/$CLIEXTRA_CONVERSATIONS_SUBDIR"
        "$CLIEXTRA_DEFAULT_NS_DIR/$CLIEXTRA_STATUS_SUBDIR"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
}

# 获取 namespace 目录
get_namespace_dir() {
    local namespace="${1:-$CLIEXTRA_DEFAULT_NS}"
    echo "$CLIEXTRA_NAMESPACES_DIR/$namespace"
}

# 获取当前 namespace（从环境变量或默认值）
get_current_namespace() {
    echo "${CLIEXTRA_CURRENT_NS:-$CLIEXTRA_DEFAULT_NS}"
}

# 获取实例目录
get_instance_dir() {
    local instance_id="$1"
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    local ns_dir=$(get_namespace_dir "$namespace")
    echo "$ns_dir/$CLIEXTRA_INSTANCES_SUBDIR/instance_$instance_id"
}

# 获取实例日志目录
get_instance_log_dir() {
    local namespace="${1:-$CLIEXTRA_DEFAULT_NS}"
    local ns_dir=$(get_namespace_dir "$namespace")
    echo "$ns_dir/$CLIEXTRA_LOGS_SUBDIR"
}

# 获取实例对话目录
get_instance_conversation_dir() {
    local namespace="${1:-$CLIEXTRA_DEFAULT_NS}"
    local ns_dir=$(get_namespace_dir "$namespace")
    echo "$ns_dir/$CLIEXTRA_CONVERSATIONS_SUBDIR"
}

# 获取实例状态目录
get_instance_status_dir() {
    local namespace="${1:-$CLIEXTRA_DEFAULT_NS}"
    local ns_dir=$(get_namespace_dir "$namespace")
    echo "$ns_dir/$CLIEXTRA_STATUS_SUBDIR"
}

# 获取实例状态文件路径
get_instance_status_file() {
    local instance_id="$1"
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    local status_dir=$(get_instance_status_dir "$namespace")
    echo "$status_dir/${instance_id}.status"
}

# 获取项目配置目录
get_project_config_dir() {
    local project_dir="$1"
    echo "$project_dir/$CLIEXTRA_PROJECT_CONFIG_DIR"
}

# 获取项目规则目录
get_project_rules_dir() {
    local project_dir="$1"
    local config_dir=$(get_project_config_dir "$project_dir")
    echo "$config_dir/$CLIEXTRA_PROJECT_RULES_DIR"
}

# 获取工具源目录
get_tools_source_dir() {
    echo "$CLIEXTRA_TOOLS_SOURCE_DIR"
}

# 获取规则源目录
get_rules_source_dir() {
    echo "$CLIEXTRA_RULES_SOURCE_DIR"
}

# 获取 tmux 会话名
get_tmux_session_name() {
    local instance_id="$1"
    echo "${CLIEXTRA_TMUX_SESSION_PREFIX}${instance_id}"
}

# =============================================================================
# 配置管理命令（保持向后兼容）
# =============================================================================

# 显示帮助
show_help() {
    echo "用法: cliExtra config <command> [options]"
    echo ""
    echo "命令:"
    echo "  show                     显示当前配置"
    echo "  set <key> <value>        设置配置项"
    echo "  get <key>                获取配置项"
    echo "  reset                    重置为默认配置"
    echo ""
    echo "配置项:"
    echo "  home                     工作目录路径"
    echo ""
    echo "示例:"
    echo "  cliExtra config show                    # 显示所有配置"
    echo "  cliExtra config get home                # 显示工作目录"
    echo "  cliExtra config set home /custom/path   # 设置工作目录"
}

# 显示配置
show_config() {
    echo "=== cliExtra 配置 ==="
    echo "操作系统: $CLIEXTRA_OS"
    echo "工作目录: $CLIEXTRA_HOME"
    echo "配置文件: $CLIEXTRA_USER_CONFIG"
    echo "工具源目录: $CLIEXTRA_TOOLS_SOURCE_DIR"
    echo "规则源目录: $CLIEXTRA_RULES_SOURCE_DIR"
    echo ""
    echo "=== 目录结构 ==="
    echo "Namespaces: $CLIEXTRA_NAMESPACES_DIR"
    echo "Projects: $CLIEXTRA_PROJECTS_DIR"
    echo "Logs: $CLIEXTRA_LOGS_DIR"
    echo "Cache: $CLIEXTRA_CACHE_DIR"
    echo ""
    echo "=== 目录状态 ==="
    if [ -d "$CLIEXTRA_HOME" ]; then
        echo "✓ 工作目录存在"
        echo "  实例数量: $(find "$CLIEXTRA_NAMESPACES_DIR" -name "instance_*" -type d 2>/dev/null | wc -l | tr -d ' ')"
        echo "  Namespace数量: $(find "$CLIEXTRA_NAMESPACES_DIR" -maxdepth 1 -type d 2>/dev/null | grep -v "^$CLIEXTRA_NAMESPACES_DIR$" | wc -l | tr -d ' ')"
    else
        echo "⚠ 工作目录不存在，将在首次使用时创建"
    fi
    
    if [ -f "$CLIEXTRA_USER_CONFIG" ]; then
        echo ""
        echo "=== 用户配置 ==="
        cat "$CLIEXTRA_USER_CONFIG"
    fi
    
    echo ""
    echo "=== 权限检查 ==="
    if [ -w "$(dirname "$CLIEXTRA_HOME")" ] || [ -w "$CLIEXTRA_HOME" ]; then
        echo "✓ 工作目录可写"
    else
        echo "⚠ 工作目录不可写，可能需要权限调整"
    fi
}

# 获取配置项
get_config() {
    local key="$1"
    case "$key" in
        "home")
            echo "$CLIEXTRA_HOME"
            ;;
        "os")
            echo "$CLIEXTRA_OS"
            ;;
        "tools")
            echo "$CLIEXTRA_TOOLS_SOURCE_DIR"
            ;;
        "rules")
            echo "$CLIEXTRA_RULES_SOURCE_DIR"
            ;;
        *)
            echo "未知配置项: $key"
            return 1
            ;;
    esac
}

# 设置配置项
set_config() {
    local key="$1"
    local value="$2"
    
    mkdir -p "$(dirname "$CLIEXTRA_USER_CONFIG")"
    
    case "$key" in
        "home")
            echo "CLIEXTRA_HOME=\"$value\"" > "$CLIEXTRA_USER_CONFIG"
            echo "✓ 工作目录已设置为: $value"
            ;;
        *)
            echo "未知配置项: $key"
            return 1
            ;;
    esac
}

# 重置配置
reset_config() {
    if [ -f "$CLIEXTRA_USER_CONFIG" ]; then
        rm "$CLIEXTRA_USER_CONFIG"
        echo "✓ 配置已重置为默认值"
    else
        echo "配置文件不存在，无需重置"
    fi
}

# =============================================================================
# 初始化
# =============================================================================

# 自动加载用户配置
load_user_config

# 自动初始化目录结构
init_directories

# 导出主要变量供其他脚本使用
export CLIEXTRA_HOME
export CLIEXTRA_NAMESPACES_DIR
export CLIEXTRA_DEFAULT_NS
export CLIEXTRA_TOOLS_SOURCE_DIR
export CLIEXTRA_RULES_SOURCE_DIR
export CLIEXTRA_TMUX_SESSION_PREFIX

# =============================================================================
# 命令行处理（当直接执行此脚本时）
# =============================================================================

# 如果脚本被直接执行（而不是被 source）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "show")
            show_config
            ;;
        "get")
            if [ -z "$2" ]; then
                echo "错误: 请指定配置项"
                show_help
                exit 1
            fi
            get_config "$2"
            ;;
        "set")
            if [ -z "$2" ] || [ -z "$3" ]; then
                echo "错误: 请指定配置项和值"
                show_help
                exit 1
            fi
            set_config "$2" "$3"
            ;;
        "reset")
            reset_config
            ;;
        *)
            show_help
            ;;
    esac
fi
