#!/bin/bash

# cliExtra List 命令性能优化补丁
# 可以直接替换原有的list功能

# 检查是否启用快速模式
FAST_MODE="${CLIEXTRA_FAST_MODE:-true}"
CACHE_ENABLED="${CLIEXTRA_CACHE_ENABLED:-true}"

# 如果启用快速模式，使用优化版本
if [[ "$FAST_MODE" == "true" ]]; then
    # 加载快速版本的函数
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/cliExtra-list-fast.sh"
    
    # 重定义主要的list函数
    list_instances() {
        local show_all="$1"
        local filter_namespace="$2"
        local json_output="$3"
        local names_only="$4"
        
        # 使用快速版本
        list_instances_fast "$show_all" "$filter_namespace" "$json_output" "$names_only"
    }
    
    # 添加性能监控
    if [[ "${CLIEXTRA_PERF_MONITOR:-false}" == "true" ]]; then
        echo "使用快速模式执行 list 命令" >&2
    fi
else
    # 使用原始版本
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/cliExtra-list.sh"
fi

# 导出优化后的函数
export -f list_instances 2>/dev/null || true
