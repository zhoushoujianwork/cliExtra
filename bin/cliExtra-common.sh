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
    
    # 搜索当前目录
    if [ -d ".cliExtra/instances/instance_$instance_id" ]; then
        echo "$(pwd)"
        return 0
    fi
    
    # 搜索全局项目目录
    if [ -d "$CLIEXTRA_HOME/projects" ]; then
        for project_dir in "$CLIEXTRA_HOME/projects"/*; do
            if [ -d "$project_dir/.cliExtra/instances/instance_$instance_id" ]; then
                echo "$project_dir"
                return 0
            fi
        done
    fi
    
    # 搜索用户主目录
    if [ -d "$HOME/.cliExtra/instances/instance_$instance_id" ]; then
        echo "$HOME"
        return 0
    fi
    
    # 搜索其他可能的位置
    for search_dir in "$HOME" "$HOME/Projects" "$HOME/workspace" "$HOME/dev"; do
        if [ -d "$search_dir/.cliExtra/instances/instance_$instance_id" ]; then
            echo "$search_dir"
            return 0
        fi
    done
    
    return 1
}

# 初始化配置
load_config 