#!/bin/bash

# cliExtra 状态检测引擎 - 基于文件时间戳的监控方案
# 通过监控 tmux.log 文件的修改时间判断 agent 状态

# 加载配置和公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"

# 状态检测配置
DEFAULT_IDLE_THRESHOLD=5        # 默认空闲阈值（秒）
INTERACTIVE_THRESHOLD=5         # 交互场景阈值
BATCH_THRESHOLD=30             # 批处理场景阈值
DEVELOPMENT_THRESHOLD=10       # 开发场景阈值

# 跨平台时间戳获取
get_file_timestamp() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        echo "0"
        return 1
    fi
    
    # 检测操作系统
    case "$(uname)" in
        "Darwin")  # macOS
            stat -f %m "$file_path" 2>/dev/null || echo "0"
            ;;
        "Linux")   # Linux
            stat -c %Y "$file_path" 2>/dev/null || echo "0"
            ;;
        *)         # 其他系统，尝试通用方法
            stat -c %Y "$file_path" 2>/dev/null || stat -f %m "$file_path" 2>/dev/null || echo "0"
            ;;
    esac
}

# 获取当前时间戳
get_current_timestamp() {
    date +%s
}

# 计算文件空闲时间
calculate_idle_time() {
    local file_path="$1"
    local current_time=$(get_current_timestamp)
    local file_time=$(get_file_timestamp "$file_path")
    
    if [[ "$file_time" == "0" ]]; then
        echo "-1"  # 文件不存在或无法访问
        return 1
    fi
    
    echo $((current_time - file_time))
}

# 获取实例的 tmux 日志文件路径
get_instance_tmux_log() {
    local instance_id="$1"
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    
    local logs_dir=$(get_instance_log_dir "$namespace")
    echo "$logs_dir/instance_${instance_id}_tmux.log"
}

# 基于时间戳检测实例状态
detect_instance_status_by_timestamp() {
    local instance_id="$1"
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    local threshold="${3:-$DEFAULT_IDLE_THRESHOLD}"
    
    # 获取 tmux 日志文件路径
    local tmux_log=$(get_instance_tmux_log "$instance_id" "$namespace")
    
    # 计算空闲时间
    local idle_time=$(calculate_idle_time "$tmux_log")
    
    if [[ "$idle_time" == "-1" ]]; then
        echo "unknown"
        return 2  # 无法确定状态
    fi
    
    # 判断状态
    if [[ $idle_time -ge $threshold ]]; then
        echo "idle"
        return 0  # 空闲状态
    else
        echo "busy"
        return 1  # 忙碌状态
    fi
}

# 批量检测多个实例状态
batch_detect_status() {
    local namespace="${1:-$CLIEXTRA_DEFAULT_NS}"
    local threshold="${2:-$DEFAULT_IDLE_THRESHOLD}"
    
    local instances_dir=$(get_instance_dir "$namespace")
    
    if [[ ! -d "$instances_dir" ]]; then
        echo "{}"
        return 0
    fi
    
    local result="{"
    local first=true
    
    for instance_dir in "$instances_dir"/*/; do
        if [[ -d "$instance_dir" ]]; then
            local instance_id=$(basename "$instance_dir")
            local status=$(detect_instance_status_by_timestamp "$instance_id" "$namespace" "$threshold")
            local status_code=$(name_to_status "$status")
            
            if [[ "$first" == "true" ]]; then
                first=false
            else
                result+=","
            fi
            
            result+="\"$instance_id\":{\"status\":\"$status\",\"code\":$status_code}"
        fi
    done
    
    result+="}"
    echo "$result"
}

# 获取实例详细状态信息
get_instance_status_detail() {
    local instance_id="$1"
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    local threshold="${3:-$DEFAULT_IDLE_THRESHOLD}"
    
    local tmux_log=$(get_instance_tmux_log "$instance_id" "$namespace")
    local idle_time=$(calculate_idle_time "$tmux_log")
    local status=$(detect_instance_status_by_timestamp "$instance_id" "$namespace" "$threshold")
    local status_code=$(name_to_status "$status")
    local file_time=$(get_file_timestamp "$tmux_log")
    local current_time=$(get_current_timestamp)
    
    echo "{"
    echo "  \"instance_id\": \"$instance_id\","
    echo "  \"namespace\": \"$namespace\","
    echo "  \"status\": \"$status\","
    echo "  \"status_code\": $status_code,"
    echo "  \"idle_time\": $idle_time,"
    echo "  \"threshold\": $threshold,"
    echo "  \"tmux_log\": \"$tmux_log\","
    echo "  \"file_exists\": $([ -f "$tmux_log" ] && echo "true" || echo "false"),"
    echo "  \"file_timestamp\": $file_time,"
    echo "  \"current_timestamp\": $current_time,"
    echo "  \"last_activity\": \"$(date -r "$file_time" 2>/dev/null || echo "unknown")\""
    echo "}"
}

# 监控单个实例并更新状态文件
# 状态变化钩子函数
# 当实例状态发生变化时调用，可以执行自定义操作
status_change_hook() {
    local instance_id="$1"
    local namespace="$2"
    local old_status="$3"  # idle/busy
    local new_status="$4"  # idle/busy
    local timestamp="$5"   # 变化时间戳
    
    # 预留钩子：可以在这里添加状态变化时的主动操作
    # 例如：
    # - 发送通知
    # - 更新外部系统
    # - 触发工作流
    # - 记录统计信息
    # - 执行清理操作
    
    # 示例：记录状态变化日志（可选）
    if [[ "${CLIEXTRA_DEBUG:-}" == "true" ]]; then
        # 如果在守护进程中，使用 log_message 函数
        if declare -f log_message > /dev/null 2>&1; then
            log_message "DEBUG" "[HOOK] Instance $instance_id ($namespace): $old_status -> $new_status"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HOOK] Instance $instance_id ($namespace): $old_status -> $new_status" >&2
        fi
    fi
    
    # 示例：状态变化统计（可选）
    # local stats_file="$CLIEXTRA_HOME/status_changes.log"
    # echo "$(date '+%Y-%m-%d %H:%M:%S'),$namespace,$instance_id,$old_status,$new_status" >> "$stats_file"
    
    # 示例：特定状态的处理（可选）
    case "$new_status" in
        "busy")
            # 实例变为忙碌时的操作
            # echo "Instance $instance_id is now busy" >&2
            ;;
        "idle")
            # 实例变为空闲时的操作
            # echo "Instance $instance_id is now idle" >&2
            ;;
    esac
    
    return 0
}

monitor_instance_by_timestamp() {
    local instance_id="$1"
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    local threshold="${3:-$DEFAULT_IDLE_THRESHOLD}"
    
    # 检测状态
    local new_status=$(detect_instance_status_by_timestamp "$instance_id" "$namespace" "$threshold")
    local new_status_code=$(name_to_status "$new_status")
    
    if [[ "$new_status" == "unknown" ]]; then
        return 2  # 无法确定状态，不更新
    fi
    
    # 读取当前状态
    local current_status_code=$(read_status_file "$instance_id" "$namespace")
    
    # 如果状态发生变化，更新状态文件
    if [[ "$current_status_code" != "$new_status_code" ]]; then
        if update_status_file "$instance_id" "$new_status_code" "$namespace"; then
            local old_status=$(status_to_name "$current_status_code")
            local change_timestamp=$(get_current_timestamp)
            
            echo "Updated $instance_id: $old_status -> $new_status"
            
            # 调用状态变化钩子函数
            status_change_hook "$instance_id" "$namespace" "$old_status" "$new_status" "$change_timestamp"
            
            return 0
        else
            echo "Failed to update $instance_id status" >&2
            return 1
        fi
    fi
    
    return 0  # 状态未变化
}

# 配置管理
set_threshold_for_namespace() {
    local namespace="$1"
    local threshold="$2"
    local config_file="$CLIEXTRA_HOME/thresholds.conf"
    
    # 确保配置目录存在
    mkdir -p "$(dirname "$config_file")"
    
    # 更新或添加配置
    if grep -q "^$namespace=" "$config_file" 2>/dev/null; then
        sed -i.bak "s/^$namespace=.*/$namespace=$threshold/" "$config_file"
    else
        echo "$namespace=$threshold" >> "$config_file"
    fi
}

get_threshold_for_namespace() {
    local namespace="$1"
    local config_file="$CLIEXTRA_HOME/thresholds.conf"
    
    if [[ -f "$config_file" ]]; then
        local threshold=$(grep "^$namespace=" "$config_file" 2>/dev/null | cut -d= -f2)
        if [[ -n "$threshold" && "$threshold" =~ ^[0-9]+$ ]]; then
            echo "$threshold"
            return 0
        fi
    fi
    
    echo "$DEFAULT_IDLE_THRESHOLD"
}

# 性能测试
benchmark_detection() {
    local instance_id="$1"
    local namespace="${2:-$CLIEXTRA_DEFAULT_NS}"
    local iterations="${3:-100}"
    
    echo "Benchmarking status detection for $instance_id ($iterations iterations)..."
    
    local start_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    for ((i=1; i<=iterations; i++)); do
        detect_instance_status_by_timestamp "$instance_id" "$namespace" >/dev/null
    done
    
    local end_time=$(date +%s.%N 2>/dev/null || date +%s)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    local avg_time=$(echo "scale=6; $duration / $iterations" | bc 2>/dev/null || echo "N/A")
    
    echo "Total time: ${duration}s"
    echo "Average time per detection: ${avg_time}s"
}

# 健康检查
health_check() {
    local namespace="${1:-$CLIEXTRA_DEFAULT_NS}"
    
    echo "Status Engine Health Check:"
    echo "=========================="
    echo "Namespace: $namespace"
    echo "Default threshold: ${DEFAULT_IDLE_THRESHOLD}s"
    echo "Configured threshold: $(get_threshold_for_namespace "$namespace")s"
    echo "OS: $(uname)"
    echo "Timestamp command test: $(get_current_timestamp)"
    echo ""
    
    # 测试文件时间戳获取
    local test_file="/tmp/cliextra_test_$$"
    echo "test" > "$test_file"
    local test_timestamp=$(get_file_timestamp "$test_file")
    rm -f "$test_file"
    
    if [[ "$test_timestamp" != "0" ]]; then
        echo "✓ File timestamp detection: OK"
    else
        echo "❌ File timestamp detection: FAILED"
    fi
    
    # 检查实例目录
    local instances_dir=$(get_instance_dir "$namespace")
    if [[ -d "$instances_dir" ]]; then
        local instance_count=$(find "$instances_dir" -maxdepth 1 -type d | wc -l)
        echo "✓ Instances directory: OK ($((instance_count - 1)) instances)"
    else
        echo "⚠ Instances directory: Not found ($instances_dir)"
    fi
}

# 命令行接口（只在直接执行时运行）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "detect")
            detect_instance_status_by_timestamp "$2" "$3" "$4"
            ;;
        "batch")
            batch_detect_status "$2" "$3"
            ;;
        "detail")
            get_instance_status_detail "$2" "$3" "$4"
            ;;
        "monitor")
            monitor_instance_by_timestamp "$2" "$3" "$4"
            ;;
        "set-threshold")
            set_threshold_for_namespace "$2" "$3"
            ;;
        "get-threshold")
            get_threshold_for_namespace "$2"
            ;;
        "benchmark")
            benchmark_detection "$2" "$3" "$4"
            ;;
        "health")
            health_check "$2"
            ;;
        *)
            echo "用法: $0 <command> [args...]"
            echo ""
            echo "命令:"
            echo "  detect <instance_id> [namespace] [threshold]  - 检测实例状态"
            echo "  batch [namespace] [threshold]                 - 批量检测状态"
            echo "  detail <instance_id> [namespace] [threshold]  - 获取详细状态信息"
            echo "  monitor <instance_id> [namespace] [threshold] - 监控并更新状态"
            echo "  set-threshold <namespace> <threshold>         - 设置namespace阈值"
            echo "  get-threshold <namespace>                     - 获取namespace阈值"
            echo "  benchmark <instance_id> [namespace] [count]  - 性能测试"
            echo "  health [namespace]                            - 健康检查"
            ;;
    esac
fi
