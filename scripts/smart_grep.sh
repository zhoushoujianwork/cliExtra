#!/bin/bash

# 智能代码分析工具 (基于grep)
# 提供更好的代码导航体验

PROJECT_ROOT="/Users/mikas/github/cliExtraWeb"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 函数：智能查找函数定义
find_function() {
    local func_name="$1"
    echo -e "${GREEN}🔍 查找函数: ${YELLOW}$func_name${NC}"
    echo "========================================"
    
    echo -e "${BLUE}📄 JavaScript/HTML 定义:${NC}"
    find $PROJECT_ROOT -name "*.js" -o -name "*.html" | xargs grep -n -H --color=always \
        -E "(function\s+$func_name\s*\(|const\s+$func_name\s*=|let\s+$func_name\s*=|var\s+$func_name\s*=)" 2>/dev/null
    
    echo -e "${BLUE}🐍 Python 定义:${NC}"
    find $PROJECT_ROOT -name "*.py" | xargs grep -n -H --color=always \
        -E "def\s+$func_name\s*\(" 2>/dev/null
    
    echo -e "${BLUE}🔗 函数调用:${NC}"
    find $PROJECT_ROOT -name "*.js" -o -name "*.html" -o -name "*.py" | xargs grep -n -H --color=always \
        "$func_name\s*(" 2>/dev/null | grep -v -E "(function\s+$func_name|def\s+$func_name)" | head -10
    echo
}

# 函数：分析变量使用
analyze_variable() {
    local var_name="$1"
    echo -e "${GREEN}📊 分析变量: ${YELLOW}$var_name${NC}"
    echo "========================================"
    
    echo -e "${BLUE}🔍 变量声明:${NC}"
    find $PROJECT_ROOT -name "*.js" -o -name "*.html" | xargs grep -n -H --color=always \
        -E "(let|const|var)\s+$var_name\s*=|$var_name\s*:" 2>/dev/null | head -5
    
    echo -e "${BLUE}📝 变量使用 (前15个):${NC}"
    find $PROJECT_ROOT -name "*.js" -o -name "*.html" | xargs grep -n -H --color=always \
        "$var_name" 2>/dev/null | head -15
    echo
}

# 函数：显示文件函数列表
show_functions() {
    local file_path="$1"
    echo -e "${GREEN}🏗️  文件函数列表: ${YELLOW}$(basename $file_path)${NC}"
    echo "========================================"
    
    if [[ $file_path == *.js ]] || [[ $file_path == *.html ]]; then
        echo -e "${BLUE}📋 JavaScript 函数:${NC}"
        grep -n --color=always -E "function\s+\w+\s*\(|const\s+\w+\s*=.*function|let\s+\w+\s*=.*function" "$file_path" 2>/dev/null
        
        echo -e "${BLUE}🔧 主要变量:${NC}"
        grep -n --color=always -E "(let|const|var)\s+\w+\s*=" "$file_path" 2>/dev/null | head -10
        
    elif [[ $file_path == *.py ]]; then
        echo -e "${BLUE}🏛️  类定义:${NC}"
        grep -n --color=always -E "class\s+\w+" "$file_path" 2>/dev/null
        
        echo -e "${BLUE}📋 函数定义:${NC}"
        grep -n --color=always -E "def\s+\w+\s*\(" "$file_path" 2>/dev/null
    fi
    echo
}

# 函数：查找API调用
find_api_calls() {
    echo -e "${GREEN}🌐 API调用分析${NC}"
    echo "========================================"
    
    echo -e "${BLUE}📡 fetch 调用:${NC}"
    find $PROJECT_ROOT -name "*.js" -o -name "*.html" | xargs grep -n -H --color=always \
        "fetch\s*(" 2>/dev/null | head -15
    
    echo -e "${BLUE}🔗 API路由 (Python):${NC}"
    find $PROJECT_ROOT -name "*.py" | xargs grep -n -H --color=always \
        -E "@.*route\(|app\.route\(" 2>/dev/null
    echo
}

# 函数：查找特定模式
search_pattern() {
    local pattern="$1"
    local file_type="$2"
    
    echo -e "${GREEN}🔍 搜索模式: ${YELLOW}$pattern${NC}"
    echo "========================================"
    
    case $file_type in
        "js")
            find $PROJECT_ROOT -name "*.js" | xargs grep -n -H --color=always "$pattern" 2>/dev/null
            ;;
        "py")
            find $PROJECT_ROOT -name "*.py" | xargs grep -n -H --color=always "$pattern" 2>/dev/null
            ;;
        "html")
            find $PROJECT_ROOT -name "*.html" | xargs grep -n -H --color=always "$pattern" 2>/dev/null
            ;;
        *)
            find $PROJECT_ROOT -name "*.js" -o -name "*.html" -o -name "*.py" | xargs grep -n -H --color=always "$pattern" 2>/dev/null
            ;;
    esac
    echo
}

# 函数：显示文件上下文
show_context() {
    local file_path="$1"
    local line_num="$2"
    local context_lines="${3:-5}"
    
    echo -e "${GREEN}📖 文件上下文: ${YELLOW}$(basename $file_path):$line_num${NC}"
    echo "========================================"
    
    if [[ -f "$file_path" ]]; then
        local start_line=$((line_num - context_lines))
        local end_line=$((line_num + context_lines))
        
        [[ $start_line -lt 1 ]] && start_line=1
        
        sed -n "${start_line},${end_line}p" "$file_path" | nl -v$start_line -nln | \
        sed "s/^[ ]*$line_num[ ]*/$(printf "${RED}%6d${NC}" $line_num) /"
    else
        echo "文件不存在: $file_path"
    fi
    echo
}

# 主菜单
show_help() {
    echo -e "${PURPLE}🔧 智能代码分析工具 (基于grep)${NC}"
    echo "========================================"
    echo "用法: $0 <命令> [参数]"
    echo
    echo "命令:"
    echo "  func <函数名>           - 查找函数定义和调用"
    echo "  var <变量名>            - 分析变量使用"
    echo "  file <文件路径>         - 显示文件函数列表"
    echo "  api                     - 查找API调用"
    echo "  search <模式> [类型]    - 搜索特定模式"
    echo "  context <文件> <行号>   - 显示文件上下文"
    echo
    echo "示例:"
    echo "  $0 func transformFastApiInstance"
    echo "  $0 var currentNamespace"
    echo "  $0 file app/static/js/ultra_simple_namespace.js"
    echo "  $0 search 'loadInstances' js"
    echo "  $0 context app/static/js/ultra_simple_namespace.js 176"
    echo
}

# 主逻辑
case "$1" in
    "func"|"f")
        find_function "$2"
        ;;
    "var"|"v")
        analyze_variable "$2"
        ;;
    "file"|"fl")
        show_functions "$2"
        ;;
    "api"|"a")
        find_api_calls
        ;;
    "search"|"s")
        search_pattern "$2" "$3"
        ;;
    "context"|"c")
        show_context "$2" "$3" "$4"
        ;;
    "help"|"-h"|"--help"|"")
        show_help
        ;;
    *)
        echo -e "${RED}未知命令: $1${NC}"
        show_help
        ;;
esac
