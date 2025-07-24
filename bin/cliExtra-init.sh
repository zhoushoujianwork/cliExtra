#!/bin/bash

# cliExtra-init.sh - 项目初始化和分析脚本
# 启动临时实例分析项目并生成 project.md 文件

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-common.sh"

# 显示帮助信息
show_help() {
    echo "cliExtra 项目初始化工具"
    echo ""
    echo "用法:"
    echo "  $0 <project_path> [project_name] [options]"
    echo ""
    echo "参数:"
    echo "  project_path    项目目录路径（如：./ 或 /path/to/project）"
    echo "  project_name    项目名称（可选，默认使用目录名）"
    echo ""
    echo "选项:"
    echo "  -n, --namespace <ns>  指定使用的 namespace (默认: default)"
    echo "  --verbose, -v         显示详细的分析过程和实时输出"
    echo "  --quiet, -q           静默模式，只显示关键信息"
    echo "  --force, -f           强制覆盖现有文件，不显示确认提示"
    echo ""
    echo "功能:"
    echo "  - 使用指定 namespace 的 system 实例进行分析"
    echo "  - 自动分析项目结构、技术栈、架构"
    echo "  - 生成详细的 .amazonq/rules/project.md 项目描述文件"
    echo "  - 建议合适的开发人员(agent)配置"
    echo ""
    echo "System 实例说明:"
    echo "  每个 namespace 都有一个 system 实例 ({namespace}-system)"
    echo "  如果 system 实例不存在，会自动创建和修复"
    echo ""
    echo "示例:"
    echo "  $0 ./                           # 使用 default namespace 分析当前目录"
    echo "  $0 ./ myproject                 # 分析当前目录并指定项目名"
    echo "  $0 ./ -n frontend               # 使用 frontend namespace 分析"
    echo "  $0 /path/to/project --namespace backend  # 使用 backend namespace"
    echo "  $0 ./ myproject --verbose       # 显示详细分析过程"
    echo "  $0 ./ myproject --force         # 强制覆盖现有文件"
    echo "  $0 ./ -n frontend -v -f         # 组合使用多个选项"
    echo ""
}

# 生成项目分析提示词
generate_analysis_prompt() {
    local project_path="$1"
    local project_name="$2"
    
    cat << EOF
请分析这个项目并生成详细的项目描述文件。

## 分析要求

请基于项目目录结构和文件内容，生成一个完整的项目描述文件，保存为 \`.amazonq/rules/project.md\` 文件。

## 分析内容

### 1. 项目概述
- **项目名称**: $project_name
- **项目类型**: Web应用、移动应用、库/框架、工具等
- **主要功能**: 项目的核心功能和用途

### 2. 技术栈
- **开发语言**: 主要编程语言和版本
- **框架和库**: 使用的主要框架、库及版本
- **构建工具**: 构建系统、包管理器、自动化工具
- **数据库**: 数据库类型和ORM（如果有）
- **其他技术**: 缓存、消息队列、容器化等

### 3. 项目架构
- **架构模式**: MVC、微服务、单体应用、组件化等
- **目录结构**: 主要目录和文件组织方式
- **核心模块**: 主要功能模块和组件
- **依赖关系**: 模块间依赖和外部依赖

### 4. 开发环境
- **环境要求**: 操作系统、运行时版本等
- **开发工具**: 推荐的IDE、编辑器、调试工具
- **构建和部署**: 构建流程、测试方法、部署方式

## 建议的开发人员配置

基于项目技术栈和复杂度，分析并推荐合适的开发角色：

### 推荐角色
- **主要角色**: 根据项目特点推荐1-2个核心角色
- **辅助角色**: 可选的支持角色
- **协作建议**: 角色间的协作方式

### 角色选择指南
- 前端项目 → frontend-engineer
- 后端API → backend-engineer  
- 全栈项目 → fullstack-engineer
- Python项目 → python-engineer
- Go项目 → golang-engineer
- Vue项目 → vue-engineer
- Shell脚本 → shell-engineer
- 部署运维 → devops-engineer
- 测试相关 → test-engineer

### 启动命令示例
提供具体的启动命令，例如：
\`\`\`bash
# 启动推荐的开发实例
qq start --role frontend-engineer --name myproject-dev

# 如果需要多角色协作
qq start --role backend-engineer --name api-dev
qq start --role frontend-engineer --name ui-dev
\`\`\`

## 输出格式

请直接创建或更新项目的 \`.amazonq/rules/project.md\` 文件，内容格式如下：

\`\`\`markdown
# $project_name 项目分析

## 项目概述

**项目名称**: $project_name  
**项目类型**: [项目类型]  
**主要功能**: [项目核心功能描述]

[项目的详细描述和背景]

## 技术栈

### 开发语言
- [主要编程语言和版本]

### 框架和库
- [使用的框架和库]

### 构建工具
- [构建系统和包管理器]

## 项目架构

### 架构模式
[架构设计说明]

### 目录结构
\\\`\\\`\\\`
[项目目录结构展示]
\\\`\\\`\\\`

### 核心模块
[主要模块和功能说明]

## 开发环境

### 环境要求
- [运行环境要求]
- [依赖软件版本]

### 开发工具
- [推荐的IDE和编辑器]
- [调试和测试工具]

### 构建和部署
- [构建流程说明]
- [部署方式和要求]

## 建议的开发人员配置

### 推荐角色
- **主要角色**: [推荐的核心角色]
- **辅助角色**: [可选的支持角色]

### 协作建议
[角色间的协作方式和建议]

### 启动命令示例
\\\`\\\`\\\`bash
# 启动推荐的开发实例
qq start --role [推荐角色] --name [实例名]

# 如果需要多角色协作
qq start --role [角色1] --name [实例名1]
qq start --role [角色2] --name [实例名2]
\\\`\\\`\\\`

## 项目特点

### 技术特点
[项目的技术特色和亮点]

### 开发注意事项
[开发过程中需要注意的事项]

### 扩展方向
[项目的扩展可能性和发展方向]
\`\`\`
[项目的独特性和技术亮点]

## 执行步骤

1. 首先分析项目目录结构和文件内容
2. 检查配置文件（package.json, requirements.txt, pom.xml等）
3. 分析源代码文件和现有文档
4. 识别技术栈和架构模式
5. 生成详细的项目描述文件
6. 将内容保存到 .amazonq/rules/project.md
7. 提供具体的角色推荐和启动命令

## 完成确认

完成分析后，请输出以下确认信息：
- "✅ 项目分析完成！"
- "📄 项目描述文件已创建: .amazonq/rules/project.md"
- "🎯 推荐角色: [具体角色名称]"
- 最后输出: "--- PROJECT_ANALYSIS_COMPLETE ---"
- 输出 "📄 项目描述文件已创建: .amazonq/rules/project.md"
- 输出 "🎯 推荐角色: [具体角色名称]"
- 最后输出结束标记: "--- PROJECT_ANALYSIS_COMPLETE ---"

请开始分析项目：$project_path
EOF
}

# 检查 project.md 内容完整性
check_readme_completeness() {
    local project_md_file="$1"
    local verbose_mode="$2"
    
    if [ ! -f "$project_md_file" ]; then
        return 1
    fi
    
    local file_size=$(wc -c < "$project_md_file" 2>/dev/null || echo "0")
    if [ "$file_size" -lt 800 ]; then
        if [ "$verbose_mode" = true ]; then
            echo "🔍 项目描述文件过小 (${file_size} 字节)，可能未完成"
        fi
        return 1
    fi
    
    # 检查必需的章节
    local required_sections=(
        "# "                    # 标题
        "## 项目概述"
        "## 技术栈"
        "## 项目架构"
        "## 建议的开发人员配置"
    )
    
    local missing_sections=()
    for section in "${required_sections[@]}"; do
        if ! grep -q "$section" "$project_md_file"; then
            missing_sections+=("$section")
        fi
    done
    
    if [ ${#missing_sections[@]} -gt 0 ]; then
        if [ "$verbose_mode" = true ]; then
            echo "🔍 项目描述文件缺少必需章节: ${missing_sections[*]}"
        fi
        return 1
    fi
    
    # 检查是否有结束标记（表示生成完整）
    if grep -q "## 项目特点" "$project_md_file" || grep -q "## 扩展方向" "$project_md_file" || grep -q "--- PROJECT_ANALYSIS_COMPLETE ---" "$project_md_file"; then
        if [ "$verbose_mode" = true ]; then
            echo "✅ 项目描述文件内容检测完整 (${file_size} 字节)"
        fi
        return 0
    fi
    
    # 如果文件较大但没有结束标记，可能还在生成中
    if [ "$file_size" -gt 3000 ]; then
        if [ "$verbose_mode" = true ]; then
            echo "⏳ README.md 内容较完整但可能仍在生成中 (${file_size} 字节)"
        fi
        return 2  # 返回2表示可能完成但不确定
    fi
    
    return 1
}
wait_for_instance() {
    local instance_id="$1"
    local max_wait=30
    local count=0
    
    echo "等待实例启动完成..."
    
    while [ $count -lt $max_wait ]; do
        if tmux has-session -t "q_instance_$instance_id" 2>/dev/null; then
            # 等待额外2秒确保Q CLI完全启动
            sleep 2
            echo "实例启动完成"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        echo -n "."
    done
    
    echo ""
    echo "错误: 实例启动超时"
    return 1
}

# 发送分析请求并实时显示输出
send_analysis_request() {
    local instance_id="$1"
    local prompt="$2"
    local project_path="$3"
    local verbose_mode="$4"
    local quiet_mode="$5"
    
    if [ "$quiet_mode" = false ]; then
        echo "发送项目分析请求..."
    fi
    
    # 发送分析提示词
    "$SCRIPT_DIR/cliExtra-send.sh" "$instance_id" "$prompt"
    
    if [ $? -ne 0 ]; then
        echo "错误: 发送分析请求失败"
        return 1
    fi
    
    if [ "$quiet_mode" = false ]; then
        echo "分析请求已发送，AI正在分析项目..."
        if [ "$verbose_mode" = true ]; then
            echo "实时输出 (按 Ctrl+C 可中断):"
            echo "----------------------------------------"
        fi
    fi
    
    # 实时监控tmux会话输出
    monitor_analysis_progress "$instance_id" "$project_path" "$verbose_mode" "$quiet_mode"
}

# 监控分析进度并实时显示输出
monitor_analysis_progress() {
    local instance_id="$1"
    local project_path="$2"
    local verbose_mode="$3"
    local quiet_mode="$4"
    local session_name="q_instance_$instance_id"
    local project_md_file="$project_path/README.md"
    local max_wait=300  # 最多等待5分钟
    local count=0
    local last_output=""
    local completion_indicators=(
        "项目分析完成"
        "README.md 文件已创建"
        "README.md 文件已保存"
        "README.md 已生成"
        "项目描述文件已创建"
        "✅ 项目分析完成"
        "📄 项目描述文件已创建: .amazonq/rules/project.md"
        "🎯 推荐角色:"
        "--- PROJECT_ANALYSIS_COMPLETE ---"
    )
    
    local thinking_indicators=(
        "⠋ Thinking"
        "⠙ Thinking"
        "⠹ Thinking"
        "⠸ Thinking"
        "⠼ Thinking"
        "⠴ Thinking"
        "⠦ Thinking"
        "⠧ Thinking"
        "⠇ Thinking"
        "⠏ Thinking"
    )
    
    if [ "$verbose_mode" = true ] && [ "$quiet_mode" = false ]; then
        echo "🔍 开始监控分析进程..."
    fi
    
    # 创建临时文件存储输出
    local temp_output="/tmp/tmux_output_$$"
    
    while [ $count -lt $max_wait ]; do
        # 捕获tmux会话的当前输出
        if tmux has-session -t "$session_name" 2>/dev/null; then
            # 获取最新的输出内容
            tmux capture-pane -t "$session_name" -p > "$temp_output" 2>/dev/null
            
            # 检查是否有新输出
            local current_output=$(tail -10 "$temp_output" 2>/dev/null)
            if [ "$current_output" != "$last_output" ] && [ "$verbose_mode" = true ] && [ "$quiet_mode" = false ]; then
                # 显示新的输出内容
                echo "📝 AI输出更新:"
                echo "$current_output" | tail -5
                echo "----------------------------------------"
                last_output="$current_output"
            fi
            
            # 检查是否包含完成指示符
            local is_thinking=false
            for thinking in "${thinking_indicators[@]}"; do
                if echo "$current_output" | grep -q "$thinking"; then
                    is_thinking=true
                    if [ "$verbose_mode" = true ] && [ "$quiet_mode" = false ]; then
                        echo "🤔 AI正在思考中..."
                    fi
                    break
                fi
            done
            
            # 检查是否包含完成指示符
            local is_thinking=false
            local found_completion_signal=false
            
            for thinking in "${thinking_indicators[@]}"; do
                if echo "$current_output" | grep -q "$thinking"; then
                    is_thinking=true
                    if [ "$verbose_mode" = true ] && [ "$quiet_mode" = false ]; then
                        echo "🤔 AI正在思考中..."
                    fi
                    break
                fi
            done
            
            # 检查完成指示符
            if [ "$is_thinking" = false ]; then
                for indicator in "${completion_indicators[@]}"; do
                    if echo "$current_output" | grep -q "$indicator"; then
                        found_completion_signal=true
                        if [ "$verbose_mode" = true ] && [ "$quiet_mode" = false ]; then
                            echo "🎯 检测到完成指示符: $indicator"
                        fi
                        break
                    fi
                done
            fi
            
            # 智能检测 README.md 完整性
            if [ -f "$project_md_file" ]; then
                check_readme_completeness "$project_md_file" "$verbose_mode"
                local completeness_status=$?
                
                case $completeness_status in
                    0)  # 完全完成
                        if [ "$quiet_mode" = false ]; then
                            local file_size=$(wc -c < "$project_md_file" 2>/dev/null || echo "0")
                            echo "✅ README.md 生成完成！"
                            echo "📄 文件路径: $project_md_file"
                            echo "📊 文件大小: ${file_size} 字节"
                        fi
                        rm -f "$temp_output"
                        return 0
                        ;;
                    2)  # 可能完成，等待确认
                        if [ "$found_completion_signal" = true ]; then
                            if [ "$quiet_mode" = false ]; then
                                local file_size=$(wc -c < "$project_md_file" 2>/dev/null || echo "0")
                                echo "✅ README.md 生成完成！"
                                echo "📄 文件路径: $project_md_file"
                                echo "📊 文件大小: ${file_size} 字节"
                            fi
                            rm -f "$temp_output"
                            return 0
                        fi
                        ;;
                    1)  # 未完成，继续等待
                        if [ "$verbose_mode" = true ] && [ "$quiet_mode" = false ]; then
                            local current_size=$(wc -c < "$project_md_file" 2>/dev/null || echo "0")
                            echo "📝 README.md 正在生成中... (${current_size} 字节)"
                        fi
                        ;;
                esac
            fi
        else
            if [ "$quiet_mode" = false ]; then
                echo "⚠️  tmux会话已结束，检查是否有错误..."
            fi
            break
        fi
        
        sleep 3
        count=$((count + 3))
        
        # 每15秒显示一次进度（更频繁的反馈）
        if [ $((count % 15)) -eq 0 ] && [ "$quiet_mode" = false ]; then
            echo "⏳ README.md 生成进行中... (${count}s/${max_wait}s)"
            if [ -f "$project_md_file" ]; then
                local current_size=$(wc -c < "$project_md_file" 2>/dev/null || echo "0")
                echo "📝 当前文件大小: ${current_size} 字节"
                
                # 显示当前生成的章节
                if [ "$current_size" -gt 100 ]; then
                    local sections_found=()
                    grep "^## " "$project_md_file" 2>/dev/null | head -3 | while read -r line; do
                        echo "   ✓ $line"
                    done
                fi
            fi
        fi
    done
    
    # 清理临时文件
    rm -f "$temp_output"
    
    # 检查最终状态
    if [ -f "$project_md_file" ]; then
        check_readme_completeness "$project_md_file" false
        local final_status=$?
        local final_size=$(wc -c < "$project_md_file" 2>/dev/null || echo "0")
        
        case $final_status in
            0)  # 完全完成
                if [ "$quiet_mode" = false ]; then
                    echo "✅ README.md 生成完成！"
                    echo "📄 文件路径: $project_md_file"
                    echo "📊 文件大小: ${final_size} 字节"
                fi
                return 0
                ;;
            2)  # 可能完成
                if [ "$quiet_mode" = false ]; then
                    echo "⚠️  README.md 可能已完成，但建议检查内容完整性"
                    echo "📄 文件路径: $project_md_file"
                    echo "📊 文件大小: ${final_size} 字节"
                    echo "💡 建议检查文件内容确认生成质量"
                fi
                return 0
                ;;
            1)  # 未完成
                if [ "$final_size" -gt 500 ]; then
                    echo "⚠️  README.md 部分完成，但内容可能不完整"
                    echo "📄 文件路径: $project_md_file"
                    echo "📊 文件大小: ${final_size} 字节"
                    echo "💡 建议重新运行或手动完善内容"
                    return 1
                else
                    echo "❌ README.md 生成失败，文件内容过少"
                    echo "📄 文件路径: $project_md_file"
                    echo "📊 文件大小: ${final_size} 字节"
                    return 1
                fi
                ;;
        esac
    else
        echo "❌ 生成超时或失败，未生成 README.md 文件"
        echo "💡 建议检查项目目录和AI实例状态"
        return 1
    fi
}

# 清理临时实例
cleanup_temp_instance() {
    local instance_id="$1"
    
    echo "清理临时分析实例..."
    "$SCRIPT_DIR/cliExtra-stop.sh" "$instance_id" >/dev/null 2>&1
    "$SCRIPT_DIR/cliExtra-clean.sh" "$instance_id" >/dev/null 2>&1
    echo "临时实例已清理"
}

# 主函数
main() {
    local project_path=""
    local project_name=""
    local namespace="default"
    local verbose_mode=false
    local quiet_mode=false
    local force_mode=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                if [[ -z "$2" ]]; then
                    echo "错误: --namespace 参数需要指定 namespace 名称"
                    exit 1
                fi
                namespace="$2"
                shift 2
                ;;
            --verbose|-v)
                verbose_mode=true
                shift
                ;;
            --quiet|-q)
                quiet_mode=true
                shift
                ;;
            --force|-f)
                force_mode=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                if [ -z "$project_path" ]; then
                    project_path="$1"
                elif [ -z "$project_name" ]; then
                    project_name="$1"
                else
                    echo "错误: 未知参数 $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # 参数验证
    if [ -z "$project_path" ]; then
        echo "错误: 请指定项目路径"
        show_help
        exit 1
    fi
    
    # 转换为绝对路径
    project_path=$(cd "$project_path" && pwd)
    
    if [ ! -d "$project_path" ]; then
        echo "错误: 项目目录不存在: $project_path"
        exit 1
    fi
    
    # 如果没有指定项目名，使用目录名
    if [ -z "$project_name" ]; then
        project_name=$(basename "$project_path")
    fi
    
    if [ "$quiet_mode" = false ]; then
        echo "🚀 开始项目初始化分析"
        echo "📁 项目路径: $project_path"
        echo "📝 项目名称: $project_name"
        if [ "$verbose_mode" = true ]; then
            echo "🔍 详细模式: 将显示实时分析过程"
        fi
        echo ""
    fi
    
    # 检查是否已存在project.md文件
    local project_md_file="$project_path/.amazonq/rules/project.md"
    local project_md_dir="$(dirname "$project_md_file")"
    
    # 确保目录存在
    mkdir -p "$project_md_dir"
    
    if [ -f "$project_md_file" ]; then
        if [ "$force_mode" = true ]; then
            if [ "$quiet_mode" = false ]; then
                echo "🔄 强制模式：覆盖现有文件 $project_md_file"
            fi
        else
            if [ "$quiet_mode" = false ]; then
                echo "⚠️  项目描述文件已存在: $project_md_file"
                read -p "是否覆盖现有文件？(y/N): " confirm
                if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                    echo "操作已取消"
                    exit 0
                fi
            fi
        fi
    fi
    
    # 确定使用的 system 实例
    local system_instance_id="${namespace}-system"
    
    if [ "$quiet_mode" = false ]; then
        echo "🔧 使用 namespace '$namespace' 的 system 实例: $system_instance_id"
    fi
    
    # 检查并修复 system 实例
    if [ "$quiet_mode" = false ]; then
        echo "🔍 检查 system 实例状态..."
    fi
    
    "$SCRIPT_DIR/cliExtra-ns.sh" show "$namespace" >/dev/null 2>&1
    
    # 验证 system 实例是否存在和运行
    if ! "$SCRIPT_DIR/cliExtra-list.sh" "$system_instance_id" >/dev/null 2>&1; then
        echo "错误: system 实例 $system_instance_id 不存在或无法访问"
        echo "请先创建 namespace: qq ns create $namespace"
        exit 1
    fi
    
    # 等待实例准备就绪
    if ! wait_for_instance "$system_instance_id"; then
        echo "错误: system 实例未准备就绪"
        exit 1
    fi
    
    # 生成分析提示词
    local analysis_prompt=$(generate_analysis_prompt "$project_path" "$project_name")
    
    # 发送分析请求
    if send_analysis_request "$system_instance_id" "$analysis_prompt" "$project_path" "$verbose_mode" "$quiet_mode"; then
        if [ "$quiet_mode" = false ]; then
            echo ""
            echo "🎉 项目初始化完成！"
            echo ""
            echo "📋 生成的文件:"
            echo "   $project_md_file"
            echo ""
            echo "💡 下一步建议:"
            echo "   1. 查看生成的项目描述: cat '$project_md_file'"
            echo "   2. 根据建议启动合适的开发实例"
            echo "   3. 开始项目开发工作"
            echo ""
            echo "🤖 System 实例信息:"
            echo "   - 实例ID: $system_instance_id"
            echo "   - Namespace: $namespace"
            echo "   - 可以继续与此实例交互: qq send $system_instance_id \"消息内容\""
            echo ""
        fi
    else
        echo "❌ 项目分析可能未完成，请检查实例状态"
        echo "💡 可以手动与 system 实例交互: qq send $system_instance_id \"请重新分析项目\""
    fi
}

# 处理命令行参数
case "${1:-}" in
    "help"|"-h"|"--help")
        show_help
        ;;
    "")
        echo "错误: 缺少项目路径参数"
        show_help
        exit 1
        ;;
    *)
        main "$@"
        ;;
esac
