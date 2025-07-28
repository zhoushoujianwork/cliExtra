#!/bin/bash

# 智能代码分析工具
# 提供类似VSCode的代码导航功能

PROJECT_ROOT="/Users/mikas/github/cliExtraWeb"
JS_DIRS="$PROJECT_ROOT/app/static/js $PROJECT_ROOT/app/templates"
PY_DIRS="$PROJECT_ROOT/app"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 函数：查找函数定义
find_function_definition() {
    local func_name="$1"
    echo -e "${GREEN}🔍 查找函数定义: ${YELLOW}$func_name${NC}"
    echo "----------------------------------------"
    
    # JavaScript函数定义
    echo -e "${BLUE}📄 JavaScript定义:${NC}"
    rg -n "function\s+$func_name\s*\(|const\s+$func_name\s*=|let\s+$func_name\s*=|var\s+$func_name\s*=" \
       --type js --type html $JS_DIRS | head -10
    
    # Python函数定义
    echo -e "${BLUE}🐍 Python定义:${NC}"
    rg -n "def\s+$func_name\s*\(" --type py $PY_DIRS | head -10
    echo
}

# 函数：查找函数引用
find_function_references() {
    local func_name="$1"
    echo -e "${GREEN}🔗 查找函数引用: ${YELLOW}$func_name${NC}"
    echo "----------------------------------------"
    
    # 排除定义，只显示调用
    rg -n "$func_name\s*\(" --type js --type html --type py $PROJECT_ROOT \
       | grep -v "function\s*$func_name" \
       | grep -v "def\s*$func_name" \
       | head -20
    echo
}

# 函数：分析变量作用域
analyze_variable() {
    local var_name="$1"
    echo -e "${GREEN}📊 分析变量: ${YELLOW}$var_name${NC}"
    echo "----------------------------------------"
    
    echo -e "${BLUE}🔍 变量声明:${NC}"
    rg -n "(let|const|var)\s+$var_name\s*=|$var_name\s*:" --type js --type html $JS_DIRS | head -5
    
    echo -e "${BLUE}📝 变量使用:${NC}"
    rg -n "$var_name" --type js --type html $JS_DIRS | head -15
    echo
}

# 函数：显示文件结构
show_file_structure() {
    local file_path="$1"
    echo -e "${GREEN}🏗️  文件结构: ${YELLOW}$(basename $file_path)${NC}"
    echo "----------------------------------------"
    
    if [[ $file_path == *.js ]] || [[ $file_path == *.html ]]; then
        # JavaScript/HTML 函数列表
        echo -e "${BLUE}📋 函数列表:${NC}"
        rg -n "function\s+\w+\s*\(|const\s+\w+\s*=.*function|let\s+\w+\s*=.*function" "$file_path" | head -20
        
        echo -e "${BLUE}🔧 主要变量:${NC}"
        rg -n "(let|const|var)\s+\w+\s*=" "$file_path" | head -10
        
    elif [[ $file_path == *.py ]]; then
        # Python 类和函数
        echo -e "${BLUE}🏛️  类定义:${NC}"
        rg -n "class\s+\w+" "$file_path"
        
        echo -e "${BLUE}📋 函数列表:${NC}"
        rg -n "def\s+\w+\s*\(" "$file_path"
    fi
    echo
}

# 函数：查找API端点
find_api_endpoints() {
    echo -e "${GREEN}🌐 API端点分析${NC}"
    echo "----------------------------------------"
    
    echo -e "${BLUE}🔗 路由定义:${NC}"
    rg -n "@.*route\(|app\.route\(|@bp\.route\(" --type py $PY_DIRS
    
    echo -e "${BLUE}📡 前端API调用:${NC}"
    rg -n "fetch\s*\(|axios\.|\.get\(|\.post\(" --type js --type html $JS_DIRS | head -15
    echo
}

# 函数：依赖关系分析
analyze_dependencies() {
    local file_path="$1"
    echo -e "${GREEN}🔗 依赖关系: ${YELLOW}$(basename $file_path)${NC}"
    echo "----------------------------------------"
    
    if [[ $file_path == *.js ]] || [[ $file_path == *.html ]]; then
        echo -e "${BLUE}📥 导入/引用:${NC}"
        rg -n "import.*from|require\(|<script.*src" "$file_path"
        
        echo -e "${BLUE}🔧 使用的函数:${NC}"
        rg -n "\w+\s*\(" "$file_path" | head -10
        
    elif [[ $file_path == *.py ]]; then
        echo -e "${BLUE}📥 导入:${NC}"
        rg -n "import\s+|from\s+.*import" "$file_path"
    fi
    echo
}

# 主菜单
show_menu() {
    echo -e "${PURPLE}🔧 智能代码分析工具${NC}"
    echo "========================================"
    echo "1. 查找函数定义 (find-def)"
    echo "2. 查找函数引用 (find-ref)"
    echo "3. 分析变量 (analyze-var)"
    echo "4. 文件结构 (file-struct)"
    echo "5. API端点分析 (api-endpoints)"
    echo "6. 依赖关系 (dependencies)"
    echo "========================================"
}

# 主逻辑
case "$1" in
    "find-def"|"fd")
        find_function_definition "$2"
        ;;
    "find-ref"|"fr")
        find_function_references "$2"
        ;;
    "analyze-var"|"av")
        analyze_variable "$2"
        ;;
    "file-struct"|"fs")
        show_file_structure "$2"
        ;;
    "api-endpoints"|"api")
        find_api_endpoints
        ;;
    "dependencies"|"dep")
        analyze_dependencies "$2"
        ;;
    "help"|"-h"|"--help")
        show_menu
        echo
        echo "使用示例:"
        echo "  $0 find-def transformFastApiInstance"
        echo "  $0 find-ref loadInstancesSimple"
        echo "  $0 analyze-var currentNamespace"
        echo "  $0 file-struct app/static/js/ultra_simple_namespace.js"
        ;;
    *)
        show_menu
        echo
        echo "请选择一个选项或使用 '$0 help' 查看帮助"
        ;;
esac
