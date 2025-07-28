#!/usr/bin/env python3
"""
高级代码分析工具
提供类似VSCode的代码导航功能
"""

import os
import re
import json
import argparse
from pathlib import Path
from collections import defaultdict
import subprocess

class CodeNavigator:
    def __init__(self, project_root):
        self.project_root = Path(project_root)
        self.js_files = []
        self.py_files = []
        self.html_files = []
        self.scan_files()
    
    def scan_files(self):
        """扫描项目文件"""
        for root, dirs, files in os.walk(self.project_root):
            # 跳过一些目录
            dirs[:] = [d for d in dirs if d not in ['.git', 'node_modules', '__pycache__', '.venv']]
            
            for file in files:
                file_path = Path(root) / file
                if file.endswith('.js'):
                    self.js_files.append(file_path)
                elif file.endswith('.py'):
                    self.py_files.append(file_path)
                elif file.endswith('.html'):
                    self.html_files.append(file_path)
    
    def find_function_definition(self, func_name):
        """查找函数定义"""
        results = {
            'javascript': [],
            'python': [],
            'references': []
        }
        
        # JavaScript函数定义模式
        js_patterns = [
            rf'function\s+{func_name}\s*\(',
            rf'const\s+{func_name}\s*=',
            rf'let\s+{func_name}\s*=',
            rf'var\s+{func_name}\s*=',
            rf'{func_name}\s*:\s*function',
            rf'{func_name}\s*=>\s*'
        ]
        
        # Python函数定义模式
        py_pattern = rf'def\s+{func_name}\s*\('
        
        # 搜索JavaScript文件
        for file_path in self.js_files + self.html_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    for i, line in enumerate(lines, 1):
                        for pattern in js_patterns:
                            if re.search(pattern, line):
                                results['javascript'].append({
                                    'file': str(file_path),
                                    'line': i,
                                    'content': line.strip(),
                                    'type': 'definition'
                                })
            except Exception as e:
                continue
        
        # 搜索Python文件
        for file_path in self.py_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    for i, line in enumerate(lines, 1):
                        if re.search(py_pattern, line):
                            results['python'].append({
                                'file': str(file_path),
                                'line': i,
                                'content': line.strip(),
                                'type': 'definition'
                            })
            except Exception as e:
                continue
        
        # 查找函数调用
        call_pattern = rf'{func_name}\s*\('
        for file_path in self.js_files + self.html_files + self.py_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    for i, line in enumerate(lines, 1):
                        if re.search(call_pattern, line):
                            # 排除定义行
                            if not any(re.search(p, line) for p in js_patterns + [py_pattern]):
                                results['references'].append({
                                    'file': str(file_path),
                                    'line': i,
                                    'content': line.strip(),
                                    'type': 'reference'
                                })
            except Exception as e:
                continue
        
        return results
    
    def analyze_variable(self, var_name):
        """分析变量使用"""
        results = {
            'declarations': [],
            'usages': []
        }
        
        # 变量声明模式
        decl_patterns = [
            rf'(let|const|var)\s+{var_name}\s*=',
            rf'{var_name}\s*:',  # 对象属性
            rf'function\s+\w+\s*\([^)]*{var_name}[^)]*\)',  # 函数参数
        ]
        
        for file_path in self.js_files + self.html_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    for i, line in enumerate(lines, 1):
                        # 检查声明
                        for pattern in decl_patterns:
                            if re.search(pattern, line):
                                results['declarations'].append({
                                    'file': str(file_path),
                                    'line': i,
                                    'content': line.strip(),
                                    'type': 'declaration'
                                })
                        
                        # 检查使用
                        if var_name in line:
                            results['usages'].append({
                                'file': str(file_path),
                                'line': i,
                                'content': line.strip(),
                                'type': 'usage'
                            })
            except Exception as e:
                continue
        
        return results
    
    def get_file_structure(self, file_path):
        """获取文件结构"""
        file_path = Path(file_path)
        if not file_path.exists():
            return None
        
        structure = {
            'functions': [],
            'classes': [],
            'variables': [],
            'imports': []
        }
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                
                for i, line in enumerate(lines, 1):
                    line_stripped = line.strip()
                    
                    if file_path.suffix == '.py':
                        # Python结构
                        if re.match(r'def\s+\w+', line_stripped):
                            structure['functions'].append({
                                'line': i,
                                'content': line_stripped,
                                'name': re.search(r'def\s+(\w+)', line_stripped).group(1)
                            })
                        elif re.match(r'class\s+\w+', line_stripped):
                            structure['classes'].append({
                                'line': i,
                                'content': line_stripped,
                                'name': re.search(r'class\s+(\w+)', line_stripped).group(1)
                            })
                        elif re.match(r'(import|from)\s+', line_stripped):
                            structure['imports'].append({
                                'line': i,
                                'content': line_stripped
                            })
                    
                    elif file_path.suffix in ['.js', '.html']:
                        # JavaScript结构
                        if re.search(r'function\s+\w+\s*\(', line_stripped):
                            match = re.search(r'function\s+(\w+)\s*\(', line_stripped)
                            if match:
                                structure['functions'].append({
                                    'line': i,
                                    'content': line_stripped,
                                    'name': match.group(1)
                                })
                        elif re.search(r'(const|let|var)\s+\w+\s*=.*function', line_stripped):
                            match = re.search(r'(const|let|var)\s+(\w+)\s*=', line_stripped)
                            if match:
                                structure['functions'].append({
                                    'line': i,
                                    'content': line_stripped,
                                    'name': match.group(2)
                                })
                        elif re.search(r'(const|let|var)\s+\w+\s*=', line_stripped):
                            match = re.search(r'(const|let|var)\s+(\w+)\s*=', line_stripped)
                            if match:
                                structure['variables'].append({
                                    'line': i,
                                    'content': line_stripped,
                                    'name': match.group(2)
                                })
        
        except Exception as e:
            return None
        
        return structure
    
    def find_api_endpoints(self):
        """查找API端点"""
        results = {
            'routes': [],
            'fetch_calls': []
        }
        
        # Python路由模式
        route_patterns = [
            r'@.*\.route\s*\(',
            r'app\.route\s*\(',
            r'@bp\.route\s*\('
        ]
        
        # 搜索Python路由
        for file_path in self.py_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    for i, line in enumerate(lines, 1):
                        for pattern in route_patterns:
                            if re.search(pattern, line):
                                results['routes'].append({
                                    'file': str(file_path),
                                    'line': i,
                                    'content': line.strip()
                                })
            except Exception as e:
                continue
        
        # 搜索fetch调用
        fetch_pattern = r'fetch\s*\('
        for file_path in self.js_files + self.html_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    for i, line in enumerate(lines, 1):
                        if re.search(fetch_pattern, line):
                            results['fetch_calls'].append({
                                'file': str(file_path),
                                'line': i,
                                'content': line.strip()
                            })
            except Exception as e:
                continue
        
        return results
    
    def get_context(self, file_path, line_num, context_lines=5):
        """获取文件上下文"""
        file_path = Path(file_path)
        if not file_path.exists():
            return None
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                
                start = max(0, line_num - context_lines - 1)
                end = min(len(lines), line_num + context_lines)
                
                context = []
                for i in range(start, end):
                    context.append({
                        'line': i + 1,
                        'content': lines[i].rstrip(),
                        'is_target': i + 1 == line_num
                    })
                
                return context
        except Exception as e:
            return None

def print_colored(text, color):
    """打印彩色文本"""
    colors = {
        'red': '\033[0;31m',
        'green': '\033[0;32m',
        'yellow': '\033[1;33m',
        'blue': '\033[0;34m',
        'purple': '\033[0;35m',
        'cyan': '\033[0;36m',
        'reset': '\033[0m'
    }
    print(f"{colors.get(color, '')}{text}{colors['reset']}")

def main():
    parser = argparse.ArgumentParser(description='高级代码分析工具')
    parser.add_argument('command', choices=['func', 'var', 'file', 'api', 'context'], 
                       help='命令类型')
    parser.add_argument('target', help='目标名称或文件路径')
    parser.add_argument('--line', type=int, help='行号 (用于context命令)')
    parser.add_argument('--context', type=int, default=5, help='上下文行数')
    parser.add_argument('--json', action='store_true', help='输出JSON格式')
    
    args = parser.parse_args()
    
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    navigator = CodeNavigator(project_root)
    
    if args.command == 'func':
        results = navigator.find_function_definition(args.target)
        if args.json:
            print(json.dumps(results, indent=2))
        else:
            print_colored(f"🔍 查找函数: {args.target}", 'green')
            print("=" * 50)
            
            if results['javascript']:
                print_colored("📄 JavaScript定义:", 'blue')
                for item in results['javascript']:
                    print(f"  {item['file']}:{item['line']} - {item['content']}")
            
            if results['python']:
                print_colored("🐍 Python定义:", 'blue')
                for item in results['python']:
                    print(f"  {item['file']}:{item['line']} - {item['content']}")
            
            if results['references']:
                print_colored("🔗 函数调用:", 'blue')
                for item in results['references'][:10]:  # 限制显示数量
                    print(f"  {item['file']}:{item['line']} - {item['content']}")
    
    elif args.command == 'var':
        results = navigator.analyze_variable(args.target)
        if args.json:
            print(json.dumps(results, indent=2))
        else:
            print_colored(f"📊 分析变量: {args.target}", 'green')
            print("=" * 50)
            
            if results['declarations']:
                print_colored("🔍 变量声明:", 'blue')
                for item in results['declarations']:
                    print(f"  {item['file']}:{item['line']} - {item['content']}")
            
            if results['usages']:
                print_colored("📝 变量使用:", 'blue')
                for item in results['usages'][:15]:  # 限制显示数量
                    print(f"  {item['file']}:{item['line']} - {item['content']}")
    
    elif args.command == 'file':
        structure = navigator.get_file_structure(args.target)
        if structure is None:
            print_colored(f"文件不存在或无法读取: {args.target}", 'red')
            return
        
        if args.json:
            print(json.dumps(structure, indent=2))
        else:
            print_colored(f"🏗️ 文件结构: {Path(args.target).name}", 'green')
            print("=" * 50)
            
            if structure['classes']:
                print_colored("🏛️ 类定义:", 'blue')
                for item in structure['classes']:
                    print(f"  {item['line']}: {item['name']}")
            
            if structure['functions']:
                print_colored("📋 函数列表:", 'blue')
                for item in structure['functions']:
                    print(f"  {item['line']}: {item['name']}")
            
            if structure['variables']:
                print_colored("🔧 变量列表:", 'blue')
                for item in structure['variables'][:10]:
                    print(f"  {item['line']}: {item['name']}")
    
    elif args.command == 'api':
        results = navigator.find_api_endpoints()
        if args.json:
            print(json.dumps(results, indent=2))
        else:
            print_colored("🌐 API端点分析", 'green')
            print("=" * 50)
            
            if results['routes']:
                print_colored("🔗 路由定义:", 'blue')
                for item in results['routes']:
                    print(f"  {item['file']}:{item['line']} - {item['content']}")
            
            if results['fetch_calls']:
                print_colored("📡 Fetch调用:", 'blue')
                for item in results['fetch_calls'][:15]:
                    print(f"  {item['file']}:{item['line']} - {item['content']}")
    
    elif args.command == 'context':
        if not args.line:
            print_colored("context命令需要--line参数", 'red')
            return
        
        context = navigator.get_context(args.target, args.line, args.context)
        if context is None:
            print_colored(f"文件不存在或无法读取: {args.target}", 'red')
            return
        
        if args.json:
            print(json.dumps(context, indent=2))
        else:
            print_colored(f"📖 文件上下文: {Path(args.target).name}:{args.line}", 'green')
            print("=" * 50)
            
            for item in context:
                if item['is_target']:
                    print_colored(f"{item['line']:6d} | {item['content']}", 'red')
                else:
                    print(f"{item['line']:6d} | {item['content']}")

if __name__ == '__main__':
    main()
