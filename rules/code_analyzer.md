### 🔧 工具概览

1. smart_grep.sh - 基于grep的快速搜索
2. code_navigator.py - Python智能分析工具
3. code_analyzer.sh - 基于ripgrep的高性能工具

### 🚀 核心功能

• **函数跳转**：快速找到函数定义和所有调用位置
• **变量追踪**：分析变量声明和使用范围
• **文件结构**：显示文件中的函数、类、变量列表
• **API分析**：查找路由定义和fetch调用
• **上下文显示**：显示指定行的代码上下文

### 💡 使用示例

bash
# 查找函数 - 就像VSCode的"Go to Definition"
python3 tools/code_navigator.py func transformFastApiInstance

# 分析变量 - 就像VSCode的"Find All References"
python3 tools/code_navigator.py var currentNamespace

# 文件结构 - 就像VSCode的"Outline"视图
python3 tools/code_navigator.py file app/static/js/ultra_simple_namespace.js

# 代码上下文 - 就像VSCode的"Peek Definition"
python3 tools/code_navigator.py context app/static/js/ultra_simple_namespace.js --line 217