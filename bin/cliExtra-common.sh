#!/bin/bash

# cliExtra 公共函数库
# 加载统一配置并提供公共函数

# 加载统一配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"

# =============================================================================
# 实例查找和管理函数
# =============================================================================

# 查找实例的项目目录
find_instance_project() {
    local instance_id="$1"
    
    # 从工作目录的namespace结构中查找实例
    if [ -d "$CLIEXTRA_NAMESPACES_DIR" ]; then
        for ns_dir in "$CLIEXTRA_NAMESPACES_DIR"/*; do
            local instance_dir="$ns_dir/$CLIEXTRA_INSTANCES_SUBDIR/instance_$instance_id"
            if [ -d "$instance_dir" ]; then
                # 读取项目路径引用
                if [ -f "$instance_dir/$CLIEXTRA_PROJECT_PATH_FILE" ]; then
                    cat "$instance_dir/$CLIEXTRA_PROJECT_PATH_FILE"
                    return 0
                elif [ -f "$instance_dir/$CLIEXTRA_INSTANCE_INFO_FILE" ]; then
                    # 从info文件中提取项目路径
                    source "$instance_dir/$CLIEXTRA_INSTANCE_INFO_FILE"
                    echo "$PROJECT_DIR"
                    return 0
                fi
            fi
        done
    fi
    
    # 向后兼容：搜索旧的项目目录结构
    # 搜索当前目录 - 旧的结构
    if [ -d ".cliExtra/instances/instance_$instance_id" ]; then
        echo "$(pwd)"
        return 0
    fi
    
    # 搜索父目录 - 旧的结构
    local current_dir="$(pwd)"
    while [ "$current_dir" != "/" ]; do
        if [ -d "$current_dir/.cliExtra/instances/instance_$instance_id" ]; then
            echo "$current_dir"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    return 1
}

# 获取 namespace 配置目录
get_ns_config_dir() {
    echo "$CLIEXTRA_CONFIG_DIR"
}

# 获取 namespace 配置文件路径
get_ns_config_file() {
    local ns_name="$1"
    echo "$(get_ns_config_dir)/$ns_name.conf"
}

# 检查 namespace 是否存在
namespace_exists() {
    local ns_name="$1"
    local ns_file="$(get_ns_config_file "$ns_name")"
    local ns_dir="$(get_namespace_dir "$ns_name")"
    
    [[ -f "$ns_file" ]] || [[ -d "$ns_dir" ]]
}

# 检查是否为保留的 namespace 名称
is_reserved_namespace() {
    local ns_name="$1"
    case "$ns_name" in
        "config"|"logs"|"cache"|"projects"|"bin"|"tools"|"rules"|"docs")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 验证 namespace 名称格式
validate_namespace_name() {
    local ns_name="$1"
    [[ "$ns_name" =~ ^[a-zA-Z0-9_-]+$ ]]
}

# 查找实例信息目录
find_instance_info_dir() {
    local instance_id="$1"
    
    # 从工作目录的namespace结构中查找实例
    if [ -d "$CLIEXTRA_NAMESPACES_DIR" ]; then
        for ns_dir in "$CLIEXTRA_NAMESPACES_DIR"/*; do
            local instance_dir="$ns_dir/$CLIEXTRA_INSTANCES_SUBDIR/instance_$instance_id"
            if [ -d "$instance_dir" ]; then
                echo "$instance_dir"
                return 0
            fi
        done
    fi
    
    return 1
}

# 查找实例的namespace
find_instance_namespace() {
    local instance_id="$1"
    
    # 从工作目录的namespace结构中查找实例
    if [ -d "$CLIEXTRA_NAMESPACES_DIR" ]; then
        for ns_dir in "$CLIEXTRA_NAMESPACES_DIR"/*; do
            local ns_name=$(basename "$ns_dir")
            local instance_dir="$ns_dir/$CLIEXTRA_INSTANCES_SUBDIR/instance_$instance_id"
            if [ -d "$instance_dir" ]; then
                echo "$ns_name"
                return 0
            fi
        done
    fi
    
    # 默认返回 default namespace
    echo "$CLIEXTRA_DEFAULT_NS"
    return 0
}

# =============================================================================
# 日志和输出函数
# =============================================================================

# 日志函数
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*" >> "$CLIEXTRA_MAIN_LOG"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$CLIEXTRA_ERROR_LOG"
    echo -e "${RED}错误: $*${NC}" >&2
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $*" >> "$CLIEXTRA_MAIN_LOG"
    echo -e "${YELLOW}警告: $*${NC}" >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $*" >> "$CLIEXTRA_MAIN_LOG"
    echo -e "${GREEN}✓ $*${NC}"
}

# =============================================================================
# 实用工具函数
# =============================================================================

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查tmux会话是否存在
tmux_session_exists() {
    local session_name="$1"
    tmux has-session -t "$session_name" 2>/dev/null
}

# 生成随机ID
generate_random_id() {
    local length="${1:-4}"
    LC_ALL=C tr -dc '0-9' < /dev/urandom | head -c "$length"
}

# 获取当前时间戳
get_timestamp() {
    date +%s
}

# 格式化时间戳
format_timestamp() {
    local timestamp="$1"
    date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$timestamp" '+%Y-%m-%d %H:%M:%S'
}

# =============================================================================
# 文件操作函数
# =============================================================================

# 安全创建目录
safe_mkdir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            log_error "无法创建目录: $dir"
            return 1
        }
    fi
}

# 安全删除文件
safe_remove() {
    local path="$1"
    if [ -e "$path" ]; then
        rm -rf "$path" || {
            log_error "无法删除: $path"
            return 1
        }
    fi
}

# 备份文件
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.bak}"
    
    if [ -f "$file" ]; then
        cp "$file" "$file$backup_suffix" || {
            log_error "无法备份文件: $file"
            return 1
        }
        log_info "文件已备份: $file -> $file$backup_suffix"
    fi
}

# =============================================================================
# 向后兼容函数
# =============================================================================

# 保持向后兼容的 load_config 函数
load_config() {
    load_user_config
}

# 向后兼容的颜色变量（已在配置文件中定义）
# RED, GREEN, YELLOW, BLUE, NC 等已在 cliExtra-config.sh 中定义

# =============================================================================
# 初始化检查
# =============================================================================

# 检查必要的命令
check_dependencies() {
    local missing_deps=()
    
    if ! command_exists tmux; then
        missing_deps+=("tmux")
    fi
    
    if ! command_exists q; then
        missing_deps+=("Amazon Q CLI")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少必要的依赖: ${missing_deps[*]}"
        echo "请安装缺少的依赖后重试"
        return 1
    fi
    
    return 0
}

# 自动执行依赖检查（可选）
# check_dependencies

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
        
        # 检查旧的实例目录结构
        local instance_dir="$project_dir/.cliExtra/instances/instance_$instance_id"
        if [[ -d "$instance_dir" ]]; then
            # 检查是否有namespace文件
            local namespace_file="$instance_dir/namespace"
            if [[ -f "$namespace_file" ]]; then
                cat "$namespace_file"
                return 0
            fi
        fi
    fi
    
    # 默认返回default
    echo "default"
    return 0
}
