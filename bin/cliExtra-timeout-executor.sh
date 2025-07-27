#!/bin/bash

# cliExtra 超时控制命令执行器
# 为所有命令添加超时控制，防止无限期等待

# 默认超时配置
DEFAULT_TIMEOUT=10
KILL_TIMEOUT=2

# 超时执行函数
execute_with_timeout() {
    local timeout="${1:-$DEFAULT_TIMEOUT}"
    local kill_timeout="${2:-$KILL_TIMEOUT}"
    shift 2
    
    local command=("$@")
    local temp_dir="/tmp/cliextra_timeout_$$"
    local pid_file="$temp_dir/pid"
    local result_file="$temp_dir/result"
    local output_file="$temp_dir/output"
    local error_file="$temp_dir/error"
    
    # 创建临时目录
    mkdir -p "$temp_dir"
    
    # 清理函数
    cleanup() {
        local cleanup_pid="$1"
        if [[ -n "$cleanup_pid" && "$cleanup_pid" != "0" ]]; then
            # 尝试优雅终止
            if kill -0 "$cleanup_pid" 2>/dev/null; then
                kill -TERM "$cleanup_pid" 2>/dev/null
                
                # 等待进程终止
                local wait_count=0
                while [[ $wait_count -lt $kill_timeout ]] && kill -0 "$cleanup_pid" 2>/dev/null; do
                    sleep 1
                    wait_count=$((wait_count + 1))
                done
                
                # 强制终止
                if kill -0 "$cleanup_pid" 2>/dev/null; then
                    kill -KILL "$cleanup_pid" 2>/dev/null
                fi
            fi
        fi
        
        # 清理临时文件
        rm -rf "$temp_dir"
    }
    
    # 在后台执行命令
    (
        exec "${command[@]}" > "$output_file" 2> "$error_file"
        echo $? > "$result_file"
    ) &
    
    local cmd_pid=$!
    echo "$cmd_pid" > "$pid_file"
    
    # 超时监控
    (
        sleep "$timeout"
        if [[ -f "$pid_file" ]]; then
            local monitored_pid=$(cat "$pid_file" 2>/dev/null)
            if [[ -n "$monitored_pid" && "$monitored_pid" != "0" ]] && kill -0 "$monitored_pid" 2>/dev/null; then
                echo "TIMEOUT" > "$result_file"
                cleanup "$monitored_pid"
            fi
        fi
    ) &
    
    local timeout_pid=$!
    
    # 等待命令完成或超时
    wait "$cmd_pid" 2>/dev/null
    local exit_code=$?
    
    # 停止超时监控
    kill "$timeout_pid" 2>/dev/null
    wait "$timeout_pid" 2>/dev/null
    
    # 检查结果
    local result=""
    if [[ -f "$result_file" ]]; then
        result=$(cat "$result_file" 2>/dev/null)
    fi
    
    if [[ "$result" == "TIMEOUT" ]]; then
        echo "错误: 命令执行超时 (${timeout}s): ${command[*]}" >&2
        cleanup "$cmd_pid"
        rm -rf "$temp_dir"
        return 124  # timeout 命令的标准退出码
    fi
    
    # 输出结果
    if [[ -f "$output_file" ]]; then
        cat "$output_file"
    fi
    
    if [[ -f "$error_file" && -s "$error_file" ]]; then
        cat "$error_file" >&2
    fi
    
    # 清理
    rm -rf "$temp_dir"
    
    return $exit_code
}

# 带重试的超时执行
execute_with_retry() {
    local max_retries="${1:-3}"
    local timeout="${2:-$DEFAULT_TIMEOUT}"
    local retry_delay="${3:-1}"
    shift 3
    
    local command=("$@")
    local attempt=1
    
    while [[ $attempt -le $max_retries ]]; do
        echo "尝试执行 (第${attempt}次): ${command[*]}" >&2
        
        if execute_with_timeout "$timeout" "$KILL_TIMEOUT" "${command[@]}"; then
            return 0
        fi
        
        local exit_code=$?
        
        if [[ $exit_code -eq 124 ]]; then
            echo "第${attempt}次尝试超时" >&2
        else
            echo "第${attempt}次尝试失败 (退出码: $exit_code)" >&2
        fi
        
        if [[ $attempt -lt $max_retries ]]; then
            echo "等待 ${retry_delay}s 后重试..." >&2
            sleep "$retry_delay"
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo "所有重试都失败了" >&2
    return 1
}

# 批量超时执行
batch_execute_with_timeout() {
    local timeout="$1"
    local max_parallel="${2:-5}"
    shift 2
    
    local commands=("$@")
    local temp_dir="/tmp/cliextra_batch_$$"
    local pids=()
    local results=()
    
    mkdir -p "$temp_dir"
    
    # 清理函数
    cleanup_batch() {
        for pid in "${pids[@]}"; do
            if [[ -n "$pid" && "$pid" != "0" ]] && kill -0 "$pid" 2>/dev/null; then
                kill -TERM "$pid" 2>/dev/null
            fi
        done
        
        sleep 1
        
        for pid in "${pids[@]}"; do
            if [[ -n "$pid" && "$pid" != "0" ]] && kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null
            fi
        done
        
        rm -rf "$temp_dir"
    }
    
    trap cleanup_batch EXIT INT TERM
    
    local cmd_index=0
    local active_jobs=0
    
    for cmd in "${commands[@]}"; do
        # 等待有空闲槽位
        while [[ $active_jobs -ge $max_parallel ]]; do
            # 检查已完成的任务
            local new_pids=()
            for i in "${!pids[@]}"; do
                local pid="${pids[$i]}"
                if [[ -n "$pid" && "$pid" != "0" ]]; then
                    if ! kill -0 "$pid" 2>/dev/null; then
                        # 任务已完成
                        wait "$pid" 2>/dev/null
                        results[$i]=$?
                        active_jobs=$((active_jobs - 1))
                    else
                        new_pids+=("$pid")
                    fi
                fi
            done
            pids=("${new_pids[@]}")
            
            if [[ $active_jobs -ge $max_parallel ]]; then
                sleep 0.1
            fi
        done
        
        # 启动新任务
        (
            execute_with_timeout "$timeout" "$KILL_TIMEOUT" $cmd
            echo $? > "$temp_dir/result_$cmd_index"
        ) &
        
        pids+=($!)
        active_jobs=$((active_jobs + 1))
        cmd_index=$((cmd_index + 1))
    done
    
    # 等待所有任务完成
    for pid in "${pids[@]}"; do
        if [[ -n "$pid" && "$pid" != "0" ]]; then
            wait "$pid" 2>/dev/null
        fi
    done
    
    # 收集结果
    local success_count=0
    local total_count=${#commands[@]}
    
    for i in $(seq 0 $((total_count - 1))); do
        local result_file="$temp_dir/result_$i"
        if [[ -f "$result_file" ]]; then
            local result=$(cat "$result_file" 2>/dev/null || echo "1")
            if [[ "$result" == "0" ]]; then
                success_count=$((success_count + 1))
            fi
        fi
    done
    
    echo "批量执行完成: $success_count/$total_count 成功" >&2
    
    # 清理
    rm -rf "$temp_dir"
    
    # 如果所有任务都成功，返回0
    if [[ $success_count -eq $total_count ]]; then
        return 0
    else
        return 1
    fi
}

# 智能超时检测
detect_optimal_timeout() {
    local command=("$@")
    local test_runs=3
    local times=()
    
    echo "检测最优超时时间..." >&2
    
    for i in $(seq 1 $test_runs); do
        echo "测试运行 $i/$test_runs..." >&2
        
        local start_time=$(date +%s.%N)
        if "${command[@]}" >/dev/null 2>&1; then
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc)
            times+=("$duration")
            echo "  耗时: ${duration}s" >&2
        else
            echo "  测试失败" >&2
        fi
    done
    
    if [[ ${#times[@]} -eq 0 ]]; then
        echo "无法检测，使用默认超时: ${DEFAULT_TIMEOUT}s" >&2
        echo "$DEFAULT_TIMEOUT"
        return 1
    fi
    
    # 计算平均时间和标准差
    local sum=0
    for time in "${times[@]}"; do
        sum=$(echo "$sum + $time" | bc)
    done
    local avg=$(echo "scale=2; $sum / ${#times[@]}" | bc)
    
    # 建议超时时间为平均时间的3倍（考虑变异性）
    local suggested_timeout=$(echo "scale=0; $avg * 3 / 1" | bc)
    
    # 最小超时时间为5秒
    if [[ $suggested_timeout -lt 5 ]]; then
        suggested_timeout=5
    fi
    
    echo "平均执行时间: ${avg}s" >&2
    echo "建议超时时间: ${suggested_timeout}s" >&2
    
    echo "$suggested_timeout"
}

# 超时配置管理
manage_timeout_config() {
    local config_file="$CLIEXTRA_HOME/.timeout_config"
    local action="$1"
    local command_pattern="$2"
    local timeout_value="$3"
    
    case "$action" in
        "set")
            if [[ -z "$command_pattern" || -z "$timeout_value" ]]; then
                echo "用法: set <命令模式> <超时秒数>" >&2
                return 1
            fi
            
            mkdir -p "$(dirname "$config_file")"
            
            # 移除现有配置
            if [[ -f "$config_file" ]]; then
                grep -v "^$command_pattern:" "$config_file" > "$config_file.tmp" 2>/dev/null || true
                mv "$config_file.tmp" "$config_file"
            fi
            
            # 添加新配置
            echo "$command_pattern:$timeout_value" >> "$config_file"
            echo "已设置 '$command_pattern' 的超时时间为 ${timeout_value}s"
            ;;
        "get")
            if [[ -z "$command_pattern" ]]; then
                echo "用法: get <命令模式>" >&2
                return 1
            fi
            
            if [[ -f "$config_file" ]]; then
                local timeout=$(grep "^$command_pattern:" "$config_file" | cut -d: -f2)
                if [[ -n "$timeout" ]]; then
                    echo "$timeout"
                else
                    echo "$DEFAULT_TIMEOUT"
                fi
            else
                echo "$DEFAULT_TIMEOUT"
            fi
            ;;
        "list")
            if [[ -f "$config_file" ]]; then
                echo "超时配置:"
                while IFS=: read -r pattern timeout; do
                    echo "  $pattern: ${timeout}s"
                done < "$config_file"
            else
                echo "没有自定义超时配置"
            fi
            ;;
        "remove")
            if [[ -z "$command_pattern" ]]; then
                echo "用法: remove <命令模式>" >&2
                return 1
            fi
            
            if [[ -f "$config_file" ]]; then
                grep -v "^$command_pattern:" "$config_file" > "$config_file.tmp" 2>/dev/null || true
                mv "$config_file.tmp" "$config_file"
                echo "已移除 '$command_pattern' 的超时配置"
            fi
            ;;
        *)
            echo "超时配置管理"
            echo ""
            echo "用法: manage_timeout_config <action> [参数]"
            echo ""
            echo "操作:"
            echo "  set <pattern> <timeout>  - 设置命令超时"
            echo "  get <pattern>            - 获取命令超时"
            echo "  list                     - 列出所有配置"
            echo "  remove <pattern>         - 移除配置"
            ;;
    esac
}

# 获取命令的配置超时时间
get_command_timeout() {
    local command="$1"
    local config_file="$CLIEXTRA_HOME/.timeout_config"
    
    if [[ -f "$config_file" ]]; then
        while IFS=: read -r pattern timeout; do
            if [[ "$command" == *"$pattern"* ]]; then
                echo "$timeout"
                return 0
            fi
        done < "$config_file"
    fi
    
    echo "$DEFAULT_TIMEOUT"
}

# 主函数
main() {
    case "${1:-}" in
        "exec")
            shift
            local timeout=$(get_command_timeout "$*")
            execute_with_timeout "$timeout" "$KILL_TIMEOUT" "$@"
            ;;
        "retry")
            local max_retries="${2:-3}"
            local timeout="${3:-$DEFAULT_TIMEOUT}"
            shift 3
            execute_with_retry "$max_retries" "$timeout" 1 "$@"
            ;;
        "batch")
            local timeout="${2:-$DEFAULT_TIMEOUT}"
            local max_parallel="${3:-5}"
            shift 3
            batch_execute_with_timeout "$timeout" "$max_parallel" "$@"
            ;;
        "detect")
            shift
            detect_optimal_timeout "$@"
            ;;
        "config")
            shift
            manage_timeout_config "$@"
            ;;
        *)
            echo "cliExtra 超时控制命令执行器"
            echo ""
            echo "用法: $0 <命令> [参数]"
            echo ""
            echo "命令:"
            echo "  exec <cmd> [args...]              - 执行命令（带超时）"
            echo "  retry <retries> <timeout> <cmd>   - 重试执行"
            echo "  batch <timeout> <parallel> <cmds> - 批量执行"
            echo "  detect <cmd> [args...]            - 检测最优超时"
            echo "  config <action> [params...]       - 管理超时配置"
            echo ""
            echo "示例:"
            echo "  $0 exec tmux list-sessions"
            echo "  $0 retry 3 10 slow-command"
            echo "  $0 detect ./cliExtra.sh list"
            echo "  $0 config set 'tmux' 5"
            ;;
    esac
}

# 如果直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
