#!/bin/bash

# cliExtra 公共函数库

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 加载全局配置
load_config() {
    # 默认配置
    CLIEXTRA_HOME="$HOME/Library/Application Support/cliExtra"
    
    # 尝试加载用户配置
    if [ -f "$HOME/.cliExtra/config" ]; then
        source "$HOME/.cliExtra/config"
    fi
    
    # 确保目录存在
    mkdir -p "$CLIEXTRA_HOME"
}

# 查找实例的项目目录
find_instance_project() {
    local instance_id="$1"
    
    # 从工作目录的namespace结构中查找实例
    if [ -d "$CLIEXTRA_HOME/namespaces" ]; then
        for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
            local instance_dir="$ns_dir/instances/instance_$instance_id"
            if [ -d "$instance_dir" ]; then
                # 读取项目路径引用
                if [ -f "$instance_dir/project_path" ]; then
                    cat "$instance_dir/project_path"
                    return 0
                elif [ -f "$instance_dir/info" ]; then
                    # 从info文件中提取项目路径
                    source "$instance_dir/info"
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
    
    # 搜索当前目录 - 旧的namespace结构
    if [ -d ".cliExtra/namespaces" ]; then
        for ns_dir in .cliExtra/namespaces/*; do
            if [ -d "$ns_dir/instances/instance_$instance_id" ]; then
                echo "$(pwd)"
                return 0
            fi
        done
    fi
    
    # 搜索用户主目录 - 旧结构
    if [ -d "$HOME/.cliExtra/instances/instance_$instance_id" ]; then
        echo "$HOME"
        return 0
    fi
    
    # 搜索用户主目录 - 旧的namespace结构
    if [ -d "$HOME/.cliExtra/namespaces" ]; then
        for ns_dir in "$HOME/.cliExtra/namespaces"/*; do
            if [ -d "$ns_dir/instances/instance_$instance_id" ]; then
                echo "$HOME"
                return 0
            fi
        done
    fi
    
    return 1
}

# 查找实例信息目录
find_instance_info_dir() {
    local instance_id="$1"
    
    # 从工作目录的namespace结构中查找实例
    if [ -d "$CLIEXTRA_HOME/namespaces" ]; then
        for ns_dir in "$CLIEXTRA_HOME/namespaces"/*; do
            local instance_dir="$ns_dir/instances/instance_$instance_id"
            if [ -d "$instance_dir" ]; then
                echo "$instance_dir"
                return 0
            fi
        done
    fi
    
    # 向后兼容：搜索旧的结构
    # 搜索当前目录 - 旧的结构
    if [ -d ".cliExtra/instances/instance_$instance_id" ]; then
        echo ".cliExtra/instances/instance_$instance_id"
        return 0
    fi
    
    # 搜索当前目录 - 旧的namespace结构
    if [ -d ".cliExtra/namespaces" ]; then
        for ns_dir in .cliExtra/namespaces/*; do
            if [ -d "$ns_dir/instances/instance_$instance_id" ]; then
                echo "$ns_dir/instances/instance_$instance_id"
                return 0
            fi
        done
    fi
    
    # 搜索用户主目录 - 旧结构
    if [ -d "$HOME/.cliExtra/instances/instance_$instance_id" ]; then
        echo "$HOME/.cliExtra/instances/instance_$instance_id"
        return 0
    fi
    
    # 搜索用户主目录 - 旧的namespace结构
    if [ -d "$HOME/.cliExtra/namespaces" ]; then
        for ns_dir in "$HOME/.cliExtra/namespaces"/*; do
            if [ -d "$ns_dir/instances/instance_$instance_id" ]; then
                echo "$ns_dir/instances/instance_$instance_id"
                return 0
            fi
        done
    fi
    
    return 1
}

# 初始化配置
load_config 