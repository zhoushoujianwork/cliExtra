#!/bin/bash

# 批量同步历史实例到软链接方式
# 作者: cliExtra
# 日期: 2025-07-27

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIEXTRA_HOME="$HOME/Library/Application Support/cliExtra"
RULES_SOURCE_DIR="$SCRIPT_DIR/../rules"
TOOLS_SOURCE_DIR="$SCRIPT_DIR/../tools"

echo "🔄 开始同步历史实例到软链接方式..."
echo "源目录: $RULES_SOURCE_DIR"
echo "工具目录: $TOOLS_SOURCE_DIR"
echo ""

# 统计变量
total_instances=0
synced_instances=0
failed_instances=0

# 同步单个实例的函数
sync_instance() {
    local instance_path="$1"
    local instance_name=$(basename "$instance_path")
    local project_path_file="$instance_path/project_path"
    
    if [[ ! -f "$project_path_file" ]]; then
        echo "  ⚠ 跳过 $instance_name: 无项目路径文件"
        return 1
    fi
    
    local project_dir=$(cat "$project_path_file")
    if [[ ! -d "$project_dir" ]]; then
        echo "  ⚠ 跳过 $instance_name: 项目目录不存在 ($project_dir)"
        return 1
    fi
    
    local rules_dir="$project_dir/.amazonq/rules"
    if [[ ! -d "$rules_dir" ]]; then
        echo "  ⚠ 跳过 $instance_name: 无 rules 目录"
        return 1
    fi
    
    echo "  🔧 同步 $instance_name..."
    echo "    项目目录: $project_dir"
    
    local rules_synced=0
    local tools_synced=0
    local errors=0
    
    # 同步 rules 文件
    for rule_file in "$RULES_SOURCE_DIR"/*.md; do
        if [[ -f "$rule_file" ]]; then
            local filename=$(basename "$rule_file")
            local target_file="$rules_dir/$filename"
            
            # 如果已存在且不是软链接，或者是损坏的软链接，则替换
            if [[ -e "$target_file" && ! -L "$target_file" ]] || [[ -L "$target_file" && ! -e "$target_file" ]]; then
                rm -f "$target_file"
                if ln -s "$rule_file" "$target_file"; then
                    echo "    ✓ $filename -> 软链接已创建"
                    ((rules_synced++))
                else
                    echo "    ✗ $filename -> 软链接创建失败"
                    ((errors++))
                fi
            elif [[ -L "$target_file" && -e "$target_file" ]]; then
                echo "    ✓ $filename -> 软链接已存在"
                ((rules_synced++))
            else
                # 文件不存在，创建软链接
                if ln -s "$rule_file" "$target_file"; then
                    echo "    ✓ $filename -> 软链接已创建"
                    ((rules_synced++))
                else
                    echo "    ✗ $filename -> 软链接创建失败"
                    ((errors++))
                fi
            fi
        fi
    done
    
    # 同步 tools 文件
    for tool_file in "$rules_dir"/tools_*.md; do
        if [[ -e "$tool_file" || -L "$tool_file" ]]; then
            local filename=$(basename "$tool_file")
            local tool_name=${filename#tools_}
            tool_name=${tool_name%.md}
            local source_tool_file="$TOOLS_SOURCE_DIR/$tool_name.md"
            
            if [[ -f "$source_tool_file" ]]; then
                # 如果是普通文件或损坏的软链接，则替换
                if [[ -f "$tool_file" && ! -L "$tool_file" ]] || [[ -L "$tool_file" && ! -e "$tool_file" ]]; then
                    rm -f "$tool_file"
                    if ln -s "$source_tool_file" "$tool_file"; then
                        echo "    ✓ $filename -> 工具软链接已创建"
                        ((tools_synced++))
                    else
                        echo "    ✗ $filename -> 工具软链接创建失败"
                        ((errors++))
                    fi
                elif [[ -L "$tool_file" && -e "$tool_file" ]]; then
                    echo "    ✓ $filename -> 工具软链接已存在"
                    ((tools_synced++))
                fi
            else
                echo "    ⚠ $filename -> 源工具文件不存在，跳过"
            fi
        fi
    done
    
    echo "    📊 同步结果: rules($rules_synced) tools($tools_synced) errors($errors)"
    
    if [[ $errors -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# 遍历所有 namespace
for namespace_dir in "$CLIEXTRA_HOME/namespaces"/*; do
    if [[ -d "$namespace_dir" ]]; then
        namespace_name=$(basename "$namespace_dir")
        echo "📁 处理 namespace: $namespace_name"
        
        instances_dir="$namespace_dir/instances"
        if [[ -d "$instances_dir" ]]; then
            for instance_dir in "$instances_dir"/instance_*; do
                if [[ -d "$instance_dir" ]]; then
                    ((total_instances++))
                    if sync_instance "$instance_dir"; then
                        ((synced_instances++))
                    else
                        ((failed_instances++))
                    fi
                fi
            done
        fi
        echo ""
    fi
done

echo "🎉 同步完成!"
echo "📊 统计结果:"
echo "  总实例数: $total_instances"
echo "  成功同步: $synced_instances"
echo "  失败/跳过: $failed_instances"

if [[ $synced_instances -gt 0 ]]; then
    echo ""
    echo "✅ 建议操作:"
    echo "  1. 使用 'qq tools check-links' 检查项目的软链接状态"
    echo "  2. 修改源文件后，所有实例将自动获取最新版本"
    echo "  3. 如有问题，使用 'qq tools repair-links' 修复"
fi
