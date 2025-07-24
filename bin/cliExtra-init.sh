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
    echo "  $0 <project_path> [project_name]"
    echo ""
    echo "参数:"
    echo "  project_path    项目目录路径（如：./ 或 /path/to/project）"
    echo "  project_name    项目名称（可选，默认使用目录名）"
    echo ""
    echo "功能:"
    echo "  - 启动临时分析实例"
    echo "  - 自动分析项目结构、技术栈、架构"
    echo "  - 生成 .amazonq/rules/project.md 项目描述文件"
    echo "  - 建议合适的开发人员(agent)配置"
    echo ""
    echo "示例:"
    echo "  $0 ./                    # 分析当前目录项目"
    echo "  $0 ./ myproject          # 分析当前目录并指定项目名"
    echo "  $0 /path/to/project      # 分析指定目录项目"
    echo ""
}

# 生成项目分析提示词
generate_analysis_prompt() {
    local project_path="$1"
    local project_name="$2"
    
    cat << EOF
请分析这个项目并生成详细的项目描述文件。

## 分析要求

请基于项目目录结构和文件内容，生成一个完整的项目分析报告，保存为 \`.amazonq/rules/project.md\` 文件。

## 分析内容

### 1. 项目基本信息
- 项目名称：$project_name
- 项目类型（Web应用、移动应用、库/框架、工具等）
- 项目描述和主要功能

### 2. 技术栈分析
- **开发语言**：主要编程语言和版本
- **框架和库**：使用的主要框架、库及版本
- **构建工具**：构建系统、包管理器
- **数据库**：数据库类型和ORM
- **其他技术**：缓存、消息队列、容器化等

### 3. 项目架构
- **架构模式**：MVC、微服务、单体应用等
- **目录结构**：主要目录和文件组织方式
- **模块划分**：核心模块和功能模块
- **依赖关系**：模块间依赖和外部依赖

### 4. 开发环境和工具
- **开发环境**：所需的开发环境配置
- **调试工具**：调试和测试工具
- **部署方式**：部署流程和环境要求

### 5. 建议的开发人员配置

基于项目复杂度和技术栈，建议以下角色配置：

#### 推荐角色组合
- **主要角色**：根据项目特点推荐1-2个核心角色
- **辅助角色**：可选的支持角色
- **协作方式**：角色间的协作建议

#### 具体建议
- 如果是前端项目 → 推荐 frontend 角色
- 如果是后端API → 推荐 backend 角色  
- 如果是全栈项目 → 推荐 fullstack 角色
- 如果涉及部署 → 推荐 devops 角色
- 如果需要测试 → 推荐 test 角色

## 输出格式

请直接创建 \`.amazonq/rules/project.md\` 文件，内容格式如下：

\`\`\`markdown
# $project_name 项目分析

## 项目概述
[项目基本信息和描述]

## 技术栈
### 开发语言
- [语言列表]

### 框架和库
- [框架库列表]

### 构建工具
- [构建工具列表]

## 项目架构
### 架构模式
[架构描述]

### 目录结构
[目录结构分析]

### 核心模块
[模块分析]

## 开发环境
### 环境要求
[环境配置要求]

### 开发工具
[推荐的开发工具]

## 建议的开发人员配置

### 推荐角色
- **主要角色**: [角色名] - [角色职责]
- **辅助角色**: [角色名] - [角色职责]

### 协作建议
[协作方式建议]

### 启动命令示例
\\\`\\\`\\\`bash
# 启动推荐的开发实例
qq start --role [推荐角色] --name [项目名]-[角色]
\\\`\\\`\\\`

## 项目特点
[项目的特殊性和注意事项]
\`\`\`

## 执行步骤

1. 首先分析项目目录结构
2. 检查配置文件（package.json, requirements.txt, pom.xml等）
3. 分析源代码文件
4. 创建 .amazonq/rules/ 目录（如果不存在）
5. 生成并保存 project.md 文件
6. 输出分析完成的确认信息

请开始分析项目：$project_path
EOF
}

# 等待实例启动完成
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

# 发送分析请求并等待完成
send_analysis_request() {
    local instance_id="$1"
    local prompt="$2"
    local project_path="$3"
    
    echo "发送项目分析请求..."
    
    # 发送分析提示词
    "$SCRIPT_DIR/cliExtra-send.sh" "$instance_id" "$prompt"
    
    if [ $? -ne 0 ]; then
        echo "错误: 发送分析请求失败"
        return 1
    fi
    
    echo "分析请求已发送，AI正在分析项目..."
    echo "这可能需要1-2分钟时间，请耐心等待..."
    
    # 等待分析完成（检查project.md文件是否生成）
    local max_wait=120  # 最多等待2分钟
    local count=0
    local project_md_file="$project_path/.amazonq/rules/project.md"
    
    while [ $count -lt $max_wait ]; do
        if [ -f "$project_md_file" ]; then
            echo "✅ 项目分析完成！"
            echo "📄 项目描述文件已生成: $project_md_file"
            return 0
        fi
        sleep 2
        count=$((count + 2))
        
        # 每10秒显示一次进度
        if [ $((count % 10)) -eq 0 ]; then
            echo "⏳ 分析进行中... (${count}s/${max_wait}s)"
        fi
    done
    
    echo "⚠️  分析可能仍在进行中，请稍后检查文件: $project_md_file"
    return 0
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
    local project_path="$1"
    local project_name="$2"
    
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
    
    echo "🚀 开始项目初始化分析"
    echo "📁 项目路径: $project_path"
    echo "📝 项目名称: $project_name"
    echo ""
    
    # 检查是否已存在project.md文件
    local project_md_file="$project_path/.amazonq/rules/project.md"
    if [ -f "$project_md_file" ]; then
        echo "⚠️  项目描述文件已存在: $project_md_file"
        read -p "是否覆盖现有文件？(y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "操作已取消"
            exit 0
        fi
    fi
    
    # 生成临时实例ID
    local temp_instance_id="project_analyzer_$(date +%s)_$$"
    
    echo "🔧 启动临时分析实例: $temp_instance_id"
    
    # 启动临时实例
    "$SCRIPT_DIR/cliExtra-start.sh" "$project_path" --name "$temp_instance_id" --role fullstack >/dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo "错误: 启动临时实例失败"
        exit 1
    fi
    
    # 等待实例启动
    if ! wait_for_instance "$temp_instance_id"; then
        cleanup_temp_instance "$temp_instance_id"
        exit 1
    fi
    
    # 生成分析提示词
    local analysis_prompt=$(generate_analysis_prompt "$project_path" "$project_name")
    
    # 发送分析请求
    if send_analysis_request "$temp_instance_id" "$analysis_prompt" "$project_path"; then
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
    else
        echo "❌ 项目分析可能未完成，请检查实例状态"
    fi
    
    # 清理临时实例
    cleanup_temp_instance "$temp_instance_id"
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
