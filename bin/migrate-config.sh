#!/bin/bash

# 配置迁移脚本
# 将旧的配置文件迁移到统一的配置系统

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置
source "$SCRIPT_DIR/cliExtra-config.sh"

echo "=== cliExtra 配置迁移工具 ==="
echo "工作目录: $CLIEXTRA_HOME"
echo "配置目录: $CLIEXTRA_CONFIG_DIR"
echo ""

# 迁移函数
migrate_namespace_configs() {
    echo "正在迁移 namespace 配置文件..."
    
    # 旧的配置文件可能存在的位置
    local old_locations=(
        "$CLIEXTRA_NAMESPACES_DIR"
        "$HOME/.cliExtra/namespaces"
        "$(pwd)/.cliExtra/namespaces"
    )
    
    local migrated_count=0
    
    for old_dir in "${old_locations[@]}"; do
        if [[ -d "$old_dir" ]]; then
            echo "检查目录: $old_dir"
            
            for conf_file in "$old_dir"/*.conf; do
                if [[ -f "$conf_file" ]]; then
                    local filename=$(basename "$conf_file")
                    local target_file="$CLIEXTRA_CONFIG_DIR/$filename"
                    
                    # 检查目标文件是否已存在
                    if [[ -f "$target_file" ]]; then
                        echo "  跳过 $filename (目标位置已存在)"
                    else
                        echo "  迁移: $filename"
                        if cp "$conf_file" "$target_file"; then
                            echo "    ✓ 复制成功: $target_file"
                            # 验证迁移后删除原文件
                            if [[ -f "$target_file" ]]; then
                                rm -f "$conf_file"
                                echo "    ✓ 删除原文件: $conf_file"
                                ((migrated_count++))
                            fi
                        else
                            echo "    ❌ 复制失败: $conf_file"
                        fi
                    fi
                fi
            done
        fi
    done
    
    echo "✓ 迁移完成，共迁移 $migrated_count 个配置文件"
}

# 验证配置完整性
verify_config() {
    echo ""
    echo "正在验证配置完整性..."
    
    # 检查必要目录
    local required_dirs=(
        "$CLIEXTRA_HOME"
        "$CLIEXTRA_CONFIG_DIR"
        "$CLIEXTRA_NAMESPACES_DIR"
        "$CLIEXTRA_PROJECTS_DIR"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "  ✓ 目录存在: $dir"
        else
            echo "  ❌ 目录缺失: $dir"
            echo "    正在创建..."
            if mkdir -p "$dir"; then
                echo "    ✓ 创建成功"
            else
                echo "    ❌ 创建失败"
            fi
        fi
    done
    
    # 检查配置文件
    echo ""
    echo "配置文件列表:"
    if [[ -d "$CLIEXTRA_CONFIG_DIR" ]]; then
        local config_count=0
        for conf_file in "$CLIEXTRA_CONFIG_DIR"/*.conf; do
            if [[ -f "$conf_file" ]]; then
                local ns_name=$(basename "$conf_file" .conf)
                echo "  - $ns_name ($(basename "$conf_file"))"
                ((config_count++))
            fi
        done
        
        if [[ $config_count -eq 0 ]]; then
            echo "  (无配置文件)"
        else
            echo "  共 $config_count 个 namespace 配置"
        fi
    else
        echo "  配置目录不存在"
    fi
}

# 显示迁移后的状态
show_migration_summary() {
    echo ""
    echo "=== 迁移摘要 ==="
    echo "配置目录: $CLIEXTRA_CONFIG_DIR"
    echo "Namespace目录: $CLIEXTRA_NAMESPACES_DIR"
    echo ""
    echo "可用的 namespace:"
    
    if command -v qq >/dev/null 2>&1; then
        qq ns show
    else
        echo "  (qq 命令不可用，请检查安装)"
    fi
}

# 主执行流程
main() {
    # 确保目录存在
    init_directories
    
    # 迁移配置
    migrate_namespace_configs
    
    # 验证配置
    verify_config
    
    # 显示摘要
    show_migration_summary
    
    echo ""
    echo "✓ 配置迁移完成！"
    echo ""
    echo "现在所有 namespace 配置文件都统一存储在:"
    echo "  $CLIEXTRA_CONFIG_DIR"
    echo ""
    echo "Namespace 数据目录:"
    echo "  $CLIEXTRA_NAMESPACES_DIR"
}

# 执行迁移
main "$@"
