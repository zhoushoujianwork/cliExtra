#!/bin/bash

# cliExtra 自动恢复功能 - 类似 k8s 容器自动恢复

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"
source "$SCRIPT_DIR/cliExtra-status-manager.sh"

# 显示帮助
show_help() {
    echo "用法: cliExtra auto-recovery <command> [options]"
    echo ""
    echo "命令:"
    echo "  start                     启动自动恢复守护进程"
    echo "  stop                      停止自动恢复守护进程"
    echo "  status                    显示自动恢复守护进程状态"
    echo "  restart                   重启自动恢复守护进程"
    echo "  recover-all               立即恢复所有停止的实例"
    echo "  recover <instance_id>     恢复指定的停止实例"
    echo "  list-stopped              列出所有停止的实例"
    echo ""
    echo "选项:"
    echo "  -n, --namespace <ns>      只处理指定 namespace 的实例"
    echo "  -A, --all                 处理所有 namespace 的实例"
    echo "  --dry-run                 预览模式，不实际执行恢复"
    echo "  --interval <seconds>      设置检查间隔（默认30秒）"
    echo ""
    echo "功能说明:"
    echo "  自动恢复守护进程会："
    echo "  - 定期检查所有实例状态"
    echo "  - 自动识别停止的实例"
    echo "  - 使用原有配置重新启动实例（保持工作目录、namespace、角色等）"
    echo "  - 记录恢复日志和统计信息"
    echo ""
    echo "示例:"
    echo "  cliExtra auto-recovery start              # 启动自动恢复守护进程"
    echo "  cliExtra auto-recovery recover-all        # 立即恢复所有停止的实例"
    echo "  cliExtra auto-recovery list-stopped       # 列出所有停止的实例"
    echo "  cliExtra auto-recovery recover-all --dry-run  # 预览恢复操作"
}

# 获取所有停止的实例
get_stopped_instances() {
    local namespace_filter="$1"
    local show_all="$2"
    
    # 构建 list 命令参数
    local list_args=()
    if [[ "$show_all" == "true" ]]; then
        list_args+=("-A")
    elif [[ -n "$namespace_filter" ]]; then
        list_args+=("-n" "$namespace_filter")
    fi
    list_args+=("-o" "json")
    
    # 获取实例列表并过滤停止的实例
    local instances_json
    instances_json=$(qq list "${list_args[@]}" 2>/dev/null)
    
    if [[ $? -ne 0 || -z "$instances_json" ]]; then
        echo "[]"
        return
    fi
    
    # 使用 jq 过滤停止的实例（如果没有 jq，使用简单的文本处理）
    if command -v jq >/dev/null 2>&1; then
        echo "$instances_json" | jq '[.instances[] | select(.status == "stopped")]'
    else
        # 简单的文本处理方式
        echo "$instances_json" | grep -A 20 -B 5 '"status": "stopped"' | \
        awk '/^{/,/^}/' | sed 's/^  //' | \
        awk 'BEGIN{print "["} {if(NR>1) print ","} {print} END{print "]"}'
    fi
}

# 恢复单个实例
recover_instance() {
    local instance_info="$1"
    local dry_run="$2"
    
    # 解析实例信息
    local instance_id project_dir namespace role
    
    if command -v jq >/dev/null 2>&1; then
        instance_id=$(echo "$instance_info" | jq -r '.id')
        project_dir=$(echo "$instance_info" | jq -r '.project_dir')
        namespace=$(echo "$instance_info" | jq -r '.namespace')
        role=$(echo "$instance_info" | jq -r '.role // empty')
    else
        # 简单的文本解析
        instance_id=$(echo "$instance_info" | grep '"id"' | cut -d'"' -f4)
        project_dir=$(echo "$instance_info" | grep '"project_dir"' | cut -d'"' -f4)
        namespace=$(echo "$instance_info" | grep '"namespace"' | cut -d'"' -f4)
        role=$(echo "$instance_info" | grep '"role"' | cut -d'"' -f4)
    fi
    
    if [[ -z "$instance_id" || -z "$namespace" ]]; then
        echo "❌ 无法解析实例信息: $instance_id"
        return 1
    fi
    
    # 跳过 system 实例（它们通常没有有效的项目目录）
    if [[ "$instance_id" == *"_system" ]]; then
        if [[ "$dry_run" == "true" ]]; then
            echo "⏭️  [预览] 跳过系统实例: $instance_id (系统实例)"
        else
            echo "⏭️  跳过系统实例: $instance_id"
        fi
        return 0
    fi
    
    # 检查项目目录是否存在且不为空
    if [[ -z "$project_dir" || "$project_dir" == "null" || ! -d "$project_dir" ]]; then
        if [[ "$dry_run" == "true" ]]; then
            echo "❌ [预览] 跳过实例: $instance_id (项目目录无效: $project_dir)"
        else
            echo "❌ 项目目录不存在，跳过恢复: $instance_id ($project_dir)"
        fi
        return 1
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        echo "🔍 [预览] 将恢复实例: $instance_id"
        echo "   - 项目目录: $project_dir"
        echo "   - Namespace: $namespace"
        echo "   - 角色: ${role:-无}"
        return 0
    fi
    
    echo "🔄 正在恢复实例: $instance_id"
    echo "   - 项目目录: $project_dir"
    echo "   - Namespace: $namespace"
    echo "   - 角色: ${role:-无}"
    
    # 构建启动命令
    local start_args=("$project_dir" "--name" "$instance_id" "--namespace" "$namespace")
    
    if [[ -n "$role" && "$role" != "null" && "$role" != "" ]]; then
        start_args+=("--role" "$role")
    fi
    
    # 执行恢复
    if qq start "${start_args[@]}" >/dev/null 2>&1; then
        echo "✅ 实例恢复成功: $instance_id"
        return 0
    else
        echo "❌ 实例恢复失败: $instance_id"
        return 1
    fi
}

# 恢复所有停止的实例
recover_all_instances() {
    local namespace_filter="$1"
    local show_all="$2"
    local dry_run="$3"
    
    echo "🔍 正在扫描停止的实例..."
    
    local stopped_instances
    stopped_instances=$(get_stopped_instances "$namespace_filter" "$show_all")
    
    if [[ -z "$stopped_instances" || "$stopped_instances" == "[]" ]]; then
        echo "✅ 没有发现停止的实例"
        return 0
    fi
    
    # 统计信息
    local total_count=0
    local success_count=0
    local failed_count=0
    
    if command -v jq >/dev/null 2>&1; then
        total_count=$(echo "$stopped_instances" | jq 'length')
        
        echo "📊 发现 $total_count 个停止的实例"
        echo ""
        
        # 逐个恢复实例
        for i in $(seq 0 $((total_count - 1))); do
            local instance_info
            instance_info=$(echo "$stopped_instances" | jq ".[$i]")
            
            if recover_instance "$instance_info" "$dry_run"; then
                ((success_count++))
            else
                ((failed_count++))
            fi
            echo ""
        done
    else
        echo "⚠️  建议安装 jq 以获得更好的 JSON 处理能力"
        echo "📊 发现停止的实例，正在尝试恢复..."
        
        # 简单的处理方式
        local instance_ids
        instance_ids=$(echo "$stopped_instances" | grep '"id"' | cut -d'"' -f4)
        
        for instance_id in $instance_ids; do
            if [[ -n "$instance_id" ]]; then
                echo "🔄 尝试恢复实例: $instance_id"
                if qq resume "$instance_id" >/dev/null 2>&1; then
                    echo "✅ 实例恢复成功: $instance_id"
                    ((success_count++))
                else
                    echo "❌ 实例恢复失败: $instance_id"
                    ((failed_count++))
                fi
                ((total_count++))
                echo ""
            fi
        done
    fi
    
    # 显示统计结果
    if [[ "$dry_run" == "true" ]]; then
        echo "🔍 预览完成："
        echo "   - 发现停止实例: $total_count 个"
    else
        echo "📊 恢复完成："
        echo "   - 总计: $total_count 个"
        echo "   - 成功: $success_count 个"
        echo "   - 失败: $failed_count 个"
    fi
}

# 列出停止的实例
list_stopped_instances() {
    local namespace_filter="$1"
    local show_all="$2"
    
    echo "🔍 正在扫描停止的实例..."
    echo ""
    
    local stopped_instances
    stopped_instances=$(get_stopped_instances "$namespace_filter" "$show_all")
    
    if [[ -z "$stopped_instances" || "$stopped_instances" == "[]" ]]; then
        echo "✅ 没有发现停止的实例"
        return 0
    fi
    
    # 显示停止的实例
    if command -v jq >/dev/null 2>&1; then
        local total_count
        total_count=$(echo "$stopped_instances" | jq 'length')
        
        echo "📊 发现 $total_count 个停止的实例："
        echo ""
        
        printf "%-30s %-15s %-15s %-20s\n" "实例ID" "NAMESPACE" "角色" "项目目录"
        printf "%-30s %-15s %-15s %-20s\n" "------------------------------" "---------------" "---------------" "--------------------"
        
        for i in $(seq 0 $((total_count - 1))); do
            local instance_info
            instance_info=$(echo "$stopped_instances" | jq ".[$i]")
            
            local instance_id project_dir namespace role
            instance_id=$(echo "$instance_info" | jq -r '.id')
            project_dir=$(echo "$instance_info" | jq -r '.project_dir')
            namespace=$(echo "$instance_info" | jq -r '.namespace')
            role=$(echo "$instance_info" | jq -r '.role // "无"')
            
            # 截断过长的路径
            local short_path="$project_dir"
            if [[ ${#project_dir} -gt 20 ]]; then
                short_path="...${project_dir: -17}"
            fi
            
            printf "%-30s %-15s %-15s %-20s\n" "$instance_id" "$namespace" "$role" "$short_path"
        done
    else
        echo "⚠️  建议安装 jq 以获得更好的显示效果"
        echo "停止的实例："
        echo "$stopped_instances" | grep '"id"' | cut -d'"' -f4
    fi
}

# 自动恢复守护进程
start_recovery_daemon() {
    local interval="${1:-30}"
    local namespace_filter="$2"
    local show_all="$3"
    
    local pid_file="$CLIEXTRA_HOME/auto-recovery.pid"
    local log_file="$CLIEXTRA_HOME/auto-recovery.log"
    
    # 检查是否已经运行
    if [[ -f "$pid_file" ]]; then
        local existing_pid
        existing_pid=$(cat "$pid_file")
        if kill -0 "$existing_pid" 2>/dev/null; then
            echo "❌ 自动恢复守护进程已在运行 (PID: $existing_pid)"
            return 1
        else
            rm -f "$pid_file"
        fi
    fi
    
    echo "🚀 启动自动恢复守护进程..."
    echo "   - 检查间隔: ${interval}秒"
    echo "   - 日志文件: $log_file"
    
    # 获取当前脚本的完整路径
    local main_script
    main_script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/cliExtra.sh"
    
    # 启动守护进程
    (
        echo $$ > "$pid_file"
        
        while true; do
            {
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 开始检查停止的实例"
                
                # 构建 list 命令参数
                local list_args=()
                if [[ "$show_all" == "true" ]]; then
                    list_args+=("-A")
                elif [[ -n "$namespace_filter" ]]; then
                    list_args+=("-n" "$namespace_filter")
                fi
                list_args+=("-o" "json")
                
                # 获取实例列表并过滤停止的实例
                local instances_json
                instances_json=$("$main_script" list "${list_args[@]}" 2>/dev/null)
                
                if [[ $? -eq 0 && -n "$instances_json" ]]; then
                    local stopped_instances
                    if command -v jq >/dev/null 2>&1; then
                        stopped_instances=$(echo "$instances_json" | jq '[.instances[] | select(.status == "stopped")]')
                        
                        if [[ -n "$stopped_instances" && "$stopped_instances" != "[]" ]]; then
                            local count
                            count=$(echo "$stopped_instances" | jq 'length')
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 发现 $count 个停止的实例，开始恢复"
                            
                            for i in $(seq 0 $((count - 1))); do
                                local instance_info
                                instance_info=$(echo "$stopped_instances" | jq ".[$i]")
                                local instance_id project_dir namespace role
                                
                                instance_id=$(echo "$instance_info" | jq -r '.id')
                                project_dir=$(echo "$instance_info" | jq -r '.project_dir')
                                namespace=$(echo "$instance_info" | jq -r '.namespace')
                                role=$(echo "$instance_info" | jq -r '.role // empty')
                                
                                # 跳过 system 实例
                                if [[ "$instance_id" == *"_system" ]]; then
                                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 跳过系统实例: $instance_id"
                                    continue
                                fi
                                
                                # 检查项目目录
                                if [[ -z "$project_dir" || "$project_dir" == "null" || ! -d "$project_dir" ]]; then
                                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] 跳过实例 $instance_id (项目目录无效: $project_dir)"
                                    continue
                                fi
                                
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 正在恢复实例: $instance_id"
                                
                                # 构建启动命令
                                local start_args=("$project_dir" "--name" "$instance_id" "--namespace" "$namespace")
                                
                                if [[ -n "$role" && "$role" != "null" && "$role" != "" ]]; then
                                    start_args+=("--role" "$role")
                                fi
                                
                                # 执行恢复
                                if "$main_script" start "${start_args[@]}" >/dev/null 2>&1; then
                                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 实例恢复成功: $instance_id"
                                else
                                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] 实例恢复失败: $instance_id"
                                fi
                            done
                        else
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] 没有发现停止的实例"
                        fi
                    else
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] 建议安装 jq 以获得更好的处理能力"
                    fi
                else
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] 无法获取实例列表"
                fi
                
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 检查完成，等待 ${interval}秒"
            } >> "$log_file" 2>&1
            
            sleep "$interval"
        done
    ) &
    
    local daemon_pid=$!
    echo "$daemon_pid" > "$pid_file"
    
    echo "✅ 自动恢复守护进程已启动 (PID: $daemon_pid)"
    echo "   使用 'qq auto-recovery status' 查看状态"
    echo "   使用 'qq auto-recovery stop' 停止守护进程"
}

# 停止守护进程
stop_recovery_daemon() {
    local pid_file="$CLIEXTRA_HOME/auto-recovery.pid"
    
    if [[ ! -f "$pid_file" ]]; then
        echo "✅ 自动恢复守护进程未运行"
        return 0
    fi
    
    local pid
    pid=$(cat "$pid_file")
    
    if kill -0 "$pid" 2>/dev/null; then
        echo "🛑 正在停止自动恢复守护进程 (PID: $pid)..."
        kill "$pid"
        rm -f "$pid_file"
        echo "✅ 自动恢复守护进程已停止"
    else
        echo "✅ 自动恢复守护进程未运行"
        rm -f "$pid_file"
    fi
}

# 查看守护进程状态
show_recovery_status() {
    local pid_file="$CLIEXTRA_HOME/auto-recovery.pid"
    local log_file="$CLIEXTRA_HOME/auto-recovery.log"
    
    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        
        if kill -0 "$pid" 2>/dev/null; then
            echo "✅ 自动恢复守护进程正在运行 (PID: $pid)"
            
            if [[ -f "$log_file" ]]; then
                local log_lines
                log_lines=$(wc -l < "$log_file" 2>/dev/null || echo "0")
                echo "   日志条目: $log_lines"
                echo "   日志文件: $log_file"
                
                echo ""
                echo "最近的日志条目:"
                tail -n 5 "$log_file" 2>/dev/null || echo "   (无日志内容)"
            fi
        else
            echo "❌ 自动恢复守护进程未运行 (PID文件存在但进程不存在)"
            rm -f "$pid_file"
        fi
    else
        echo "❌ 自动恢复守护进程未运行"
    fi
    
    # 额外检查：通过进程名查找可能的守护进程
    local running_pids
    running_pids=$(pgrep -f "cliExtra-auto-recovery" 2>/dev/null || true)
    
    if [[ -n "$running_pids" && ! -f "$pid_file" ]]; then
        echo ""
        echo "⚠️  发现可能的孤儿进程:"
        for pid in $running_pids; do
            echo "   PID: $pid"
            ps -p "$pid" -o pid,ppid,command 2>/dev/null || true
        done
        echo "   建议手动清理: kill $running_pids"
    fi
}

# 主逻辑
main() {
    local command="$1"
    shift
    
    # 解析通用参数
    local namespace_filter=""
    local show_all="false"
    local dry_run="false"
    local interval="30"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--namespace)
                namespace_filter="$2"
                shift 2
                ;;
            -A|--all)
                show_all="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --interval)
                interval="$2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done
    
    case "$command" in
        start)
            start_recovery_daemon "$interval" "$namespace_filter" "$show_all"
            ;;
        stop)
            stop_recovery_daemon
            ;;
        status)
            show_recovery_status
            ;;
        restart)
            stop_recovery_daemon
            sleep 2
            start_recovery_daemon "$interval" "$namespace_filter" "$show_all"
            ;;
        recover-all)
            recover_all_instances "$namespace_filter" "$show_all" "$dry_run"
            ;;
        recover)
            local instance_id="$1"
            if [[ -z "$instance_id" ]]; then
                echo "❌ 请指定要恢复的实例ID"
                echo "用法: qq auto-recovery recover <instance_id>"
                exit 1
            fi
            
            # 获取实例信息
            local instance_info
            instance_info=$(qq list "$instance_id" -o json 2>/dev/null)
            
            if [[ $? -ne 0 || -z "$instance_info" ]]; then
                echo "❌ 实例不存在: $instance_id"
                exit 1
            fi
            
            recover_instance "$instance_info" "$dry_run"
            ;;
        list-stopped)
            list_stopped_instances "$namespace_filter" "$show_all"
            ;;
        --help|-h|help)
            show_help
            ;;
        *)
            echo "❌ 未知命令: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主逻辑
main "$@"
