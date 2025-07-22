# cliExtra 配置系统

## 概述

cliExtra 使用统一的配置管理系统，所有目录定义和路径配置都集中在 `bin/cliExtra-config.sh` 文件中。

## 配置文件结构

### 主配置文件
- `bin/cliExtra-config.sh` - 统一配置文件，包含所有目录定义和全局变量
- `bin/cliExtra-common.sh` - 公共函数库，加载统一配置

### 用户配置文件
- `~/.cliExtra/config` - 用户自定义配置
- `$CLIEXTRA_HOME/config/global.conf` - 全局配置文件

## 目录配置

### 根据操作系统自动配置
```bash
# macOS
CLIEXTRA_HOME="$HOME/Library/Application Support/cliExtra"

# Linux
CLIEXTRA_HOME="/opt/cliExtra"

# 其他系统
CLIEXTRA_HOME="$HOME/.cliExtra"
```

### 核心目录结构
```bash
CLIEXTRA_CONFIG_DIR="$CLIEXTRA_HOME/config"
CLIEXTRA_NAMESPACES_DIR="$CLIEXTRA_HOME/namespaces"
CLIEXTRA_PROJECTS_DIR="$CLIEXTRA_HOME/projects"
CLIEXTRA_LOGS_DIR="$CLIEXTRA_HOME/logs"
CLIEXTRA_CACHE_DIR="$CLIEXTRA_HOME/cache"
```

### 项目配置
```bash
CLIEXTRA_PROJECT_CONFIG_DIR=".amazonq"
CLIEXTRA_PROJECT_RULES_DIR="rules"
CLIEXTRA_PROJECT_TOOLS_DIR="tools"
```

## 配置函数

### 目录获取函数
```bash
# 获取 namespace 目录
get_namespace_dir "frontend"

# 获取实例目录
get_instance_dir "my-instance" "backend"

# 获取项目配置目录
get_project_config_dir "/path/to/project"

# 获取项目规则目录
get_project_rules_dir "/path/to/project"

# 获取工具源目录
get_tools_source_dir

# 获取规则源目录
get_rules_source_dir
```

### 实用函数
```bash
# 获取 tmux 会话名
get_tmux_session_name "instance-id"

# 初始化目录结构
init_directories

# 加载用户配置
load_user_config
```

## 在脚本中使用配置

### 基本用法
```bash
#!/bin/bash

# 加载统一配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cliExtra-config.sh"

# 使用配置变量
echo "工作目录: $CLIEXTRA_HOME"
echo "工具目录: $CLIEXTRA_TOOLS_SOURCE_DIR"

# 使用配置函数
ns_dir=$(get_namespace_dir "frontend")
echo "Frontend namespace 目录: $ns_dir"
```

### 在现有脚本中集成
```bash
# 替换硬编码路径
# 旧方式
# local tools_dir="$SCRIPT_DIR/../tools"

# 新方式
local tools_dir=$(get_tools_source_dir)

# 替换项目配置路径
# 旧方式
# local rules_dir="$project_dir/.amazonq/rules"

# 新方式
local rules_dir=$(get_project_rules_dir "$project_dir")
```

## 配置管理命令

### 查看配置
```bash
# 显示所有配置信息
qq config show

# 获取特定配置项
qq config get home
qq config get tools
qq config get rules
```

### 设置配置
```bash
# 设置工作目录
qq config set home "/custom/path"

# 重置配置
qq config reset
```

## 环境变量

### 自动导出的变量
```bash
export CLIEXTRA_HOME
export CLIEXTRA_NAMESPACES_DIR
export CLIEXTRA_DEFAULT_NS
export CLIEXTRA_TOOLS_SOURCE_DIR
export CLIEXTRA_RULES_SOURCE_DIR
export CLIEXTRA_TMUX_SESSION_PREFIX
```

### 颜色变量
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
```

## 向后兼容性

### 保持兼容的功能
- 现有的 `load_config()` 函数
- 所有颜色变量
- 现有的 API 接口

### 迁移指南
1. 将硬编码路径替换为配置函数调用
2. 使用 `source cliExtra-config.sh` 替代 `source cliExtra-common.sh`
3. 利用新的配置函数简化路径管理

## 扩展配置

### 添加新的配置项
1. 在 `cliExtra-config.sh` 中定义新变量
2. 在 `get_config()` 函数中添加处理逻辑
3. 在 `set_config()` 函数中添加设置逻辑

### 添加新的目录配置
1. 在配置文件中定义目录变量
2. 在 `init_directories()` 中添加目录创建逻辑
3. 创建对应的获取函数

## 最佳实践

1. **统一使用配置函数**：避免硬编码路径
2. **检查目录存在性**：使用 `safe_mkdir()` 创建目录
3. **错误处理**：使用 `log_error()` 等日志函数
4. **向后兼容**：保持现有 API 不变
5. **文档更新**：及时更新相关文档

## 故障排除

### 常见问题
1. **配置文件不存在**：自动创建默认配置
2. **目录权限问题**：检查目录权限设置
3. **路径不正确**：使用配置函数而非硬编码

### 调试方法
```bash
# 检查配置加载
qq config show

# 验证目录结构
ls -la "$CLIEXTRA_HOME"

# 检查函数可用性
type get_namespace_dir
```
