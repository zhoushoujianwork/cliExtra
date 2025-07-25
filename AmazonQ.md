每次功能完成后记得更新 README.md 文件；

## 2025-07-25 移除 qq init 功能

### 🗑️ 功能移除
移除了 `qq init` 项目初始化功能，简化系统架构。

#### 移除的内容
1. **主脚本**: 移除 `cliExtra.sh` 中的 init 命令处理逻辑
2. **帮助信息**: 移除帮助文档中的 init 相关说明和示例
3. **README.md**: 移除项目初始化章节和相关使用示例
4. **规则文档**: 移除 `.amazonq/rules/cliExtra.md` 中的 init 相关内容

#### 移除原因
- **简化架构**: 专注于核心的实例管理和协作功能
- **减少复杂性**: 避免功能重叠和维护负担
- **用户反馈**: 用户更多使用 start 功能而非 init 功能

#### 影响范围
- ✅ 不影响现有实例的运行
- ✅ 不影响其他核心功能
- ✅ 用户可以直接使用 `qq start` 启动实例
- ✅ 保持向后兼容性

#### 替代方案
用户可以使用以下方式替代原有的 init 功能：
```bash
# 原来的 init 功能
# qq init ./

# 现在使用 start 功能
qq start --name myproject
```

### 📋 清理完成
- ✅ 移除主脚本中的 init 命令处理
- ✅ 移除帮助信息中的 init 相关内容
- ✅ 移除 README.md 中的项目初始化章节
- ✅ 移除规则文档中的 init 相关说明
- ✅ 更新快速上手示例，移除 init 步骤

## 2025-07-24 异常 Namespace 创建问题修复

### 🐛 问题发现
用户报告系统创建了大量异常的 namespace，这些 namespace 名称都是中文消息内容，如：
- "小程序是否支持使用手机蓝牙连接外部设备进行数据交互"
- "任务已完成"
- "消息处理完成"
- "状态管理测试消息 - 验证修复效果"

### 🔍 根本原因分析
通过代码分析发现问题出现在 `cliExtra-start.sh` 中调用 `create_status_file` 函数时：

**错误的调用方式**:
```bash
create_status_file "$instance_id" "$STATUS_IDLE" "$initial_task" "$namespace"
```

**函数期望的参数**:
```bash
create_status_file(instance_id, status, namespace)
```

**实际传递的参数**:
1. `instance_id` ✅
2. `STATUS_IDLE` ✅  
3. `initial_task` ❌ (被当作 namespace)
4. `namespace` ❌ (被忽略)

导致 `initial_task` 变量的值（如中文消息）被当作 namespace 名称，系统自动创建了这些异常目录。

### 🛠️ 解决方案

#### 1. 修复参数传递错误
```bash
# 修复前
create_status_file "$instance_id" "$STATUS_IDLE" "$initial_task" "$namespace"

# 修复后  
create_status_file "$instance_id" "$STATUS_IDLE" "$namespace"
```

#### 2. 加强 Namespace 名称验证
在 `create_status_file` 函数中添加严格的验证：
- **字符验证**: 只允许 `[a-zA-Z0-9_-]`
- **长度验证**: 不超过 32 个字符
- **自动回退**: 无效名称自动使用默认 namespace

#### 3. 增强 Namespace 创建验证
在 `cliExtra-ns.sh` 中加强验证：
- 多重字符检查
- 长度限制检查
- 清晰的错误提示

#### 4. 新增清理工具
创建 `cliExtra-cleanup-invalid-ns.sh` 脚本：
- **预览模式**: `--dry-run` 查看将要清理的目录
- **强制清理**: `--force` 直接删除无效目录
- **智能识别**: 自动识别包含无效字符的 namespace

### 🧪 测试验证
- ✅ 修复参数传递错误，状态文件创建正常
- ✅ 中文 namespace 名称被正确拒绝并回退到默认值
- ✅ 过长 namespace 名称被正确拒绝
- ✅ 清理工具能正确识别和清理异常目录
- ✅ 系统不再创建异常 namespace

### 💡 用户价值
- **系统稳定性**: 防止异常 namespace 的创建
- **目录整洁**: 保持系统目录结构的整洁
- **问题修复**: 提供工具清理已有的异常目录
- **健壮性**: 增强系统对无效输入的处理能力

### 📋 使用方法
```bash
# 预览将要清理的异常 namespace
qq cleanup-invalid-ns --dry-run

# 强制清理所有异常 namespace
qq cleanup-invalid-ns --force

# 查看清理后的状态
qq ns show
```

### 🔧 技术实现
1. **参数修复**: 移除多余的 `initial_task` 参数传递
2. **验证增强**: 使用正则表达式 `^[a-zA-Z0-9_-]+$` 验证名称
3. **长度限制**: 限制 namespace 名称不超过 32 字符
4. **错误处理**: 无效名称自动回退到 `default` namespace
5. **清理工具**: 提供安全的批量清理功能

### 📊 影响范围
- **修复文件**: 
  - `bin/cliExtra-start.sh` - 修复参数传递
  - `bin/cliExtra-status-manager.sh` - 加强验证
  - `bin/cliExtra-ns.sh` - 增强创建验证
  - `cliExtra.sh` - 添加清理命令
- **新增文件**: 
  - `bin/cliExtra-cleanup-invalid-ns.sh` - 清理工具
- **用户体验**: 系统更加稳定，目录结构更加整洁

## 2025-07-24 实例状态管理机制实现

### 🔧 新功能：实例状态管理系统
实现了类似 PID 文件的实例状态标记系统，用于工作流协作和状态检测。

#### 核心设计
1. **状态文件位置**: `~/Library/Application Support/cliExtra/namespaces/<namespace>/status/<instance_id>.status`
2. **状态值定义**: 
   - `idle` - 空闲，可接收新任务
   - `busy` - 忙碌，正在处理任务  
   - `waiting` - 等待用户输入或外部响应
   - `error` - 错误状态，需要人工干预
3. **状态文件格式**: JSON 格式，包含状态、时间戳、任务描述、PID 等信息

#### 实现的功能
1. **状态查看**: `qq status [instance_id] [options]`
   - 支持查看单个实例或所有实例状态
   - 支持 table 和 json 两种输出格式
   - 遵循 namespace 默认行为（默认只显示 default namespace）

2. **状态设置**: `qq status <instance_id> --set <status> [--task <description>]`
   - 支持设置实例状态和任务描述
   - 自动更新最后活动时间

3. **状态文件清理**: `qq status --cleanup [--timeout <minutes>]`
   - 自动清理过期的状态文件
   - 支持自定义超时时间

#### 生命周期集成
- **启动时**: 自动创建状态文件，设为 `idle` 状态
- **停止时**: 自动清理状态文件
- **清理时**: 在实例清理过程中同时清理状态文件

#### 技术实现
1. **状态管理器**: `cliExtra-status-manager.sh` - 核心状态管理函数库
2. **状态命令**: `cliExtra-status.sh` - 完整的状态管理命令实现
3. **生命周期集成**: 在 start、stop、clean 脚本中集成状态文件管理
4. **并发安全**: 使用原子操作和临时文件确保并发安全

#### 用户价值
- **协作感知**: AI 实例可以检查其他实例状态，避免重复工作
- **工作流管理**: 支持基于状态的工作流协作
- **系统监控**: 提供实例运行状态的统一视图
- **自动清理**: 防止状态文件积累，保持系统整洁

#### 测试验证
- ✅ 状态文件创建和更新功能正常
- ✅ 状态查看和设置功能正常
- ✅ 生命周期集成功能正常
- ✅ 清理功能正常
- ✅ JSON 输出格式正确
- ✅ Namespace 过滤功能正常

## 2025-07-24 重构记录

### qq start 功能重构
- **移除**: 移除了 workflow 相关的所有逻辑和配置
- **保留**: 保留了 rules/* 下内容到 .amazonq/rules/ 的同步功能
- **简化**: 简化了启动流程，专注于核心的 rules 同步和工具安装
- **清理**: 移除了 workflow-loader 的调用和相关依赖

### 具体变更
1. **cliExtra-start.sh**: 移除了 workflow-loader 调用，保留 sync_rules_to_project 函数
2. **cliExtra.sh**: 移除了帮助信息中的 workflow 相关命令和示例
3. **README.md**: 移除了 Workflow 智能协作管理章节和相关描述
4. **测试验证**: 确保重构后功能正常，rules 同步和工具安装正常工作

### 重构目标达成
- ✅ 移除 workflow 配置逻辑
- ✅ 保留 rules 同步功能  
- ✅ 保持向后兼容性
- ✅ 简化代码结构

## 2025-07-24 角色定义功能增强

### 新增角色定义管理功能
- **角色定义位置**: 项目目录的 `.cliExtra/roles` 目录
- **自动复制**: 从工程目录 `roles/` 复制角色定义到项目目录
- **Context传入**: 将角色内容作为 `--context` 参数传入 Q CLI
- **自动发现**: 未指定角色时自动发现项目中现有角色定义

### 功能特点
1. **智能角色管理**:
   - 检查项目目录 `.cliExtra/roles` 是否已有角色定义
   - 如果没有，从工程目录复制对应角色文件
   - 支持自动发现现有角色定义

2. **Context集成**:
   - 使用 `q chat --context "角色文件路径"` 启动
   - 角色定义直接作为上下文传入，无需复制到 `.amazonq/rules`
   - 保持角色定义与项目的独立性

3. **实例信息记录**:
   - 在实例 info 文件中记录 `ROLE` 和 `ROLE_FILE` 信息
   - 支持后续查询和管理

### 使用示例
```bash
# 指定角色启动（会复制角色定义到项目）
qq start --role frontend

# 不指定角色启动（自动发现现有角色）
qq start --name myinstance

# 角色定义文件位置
project/.cliExtra/roles/frontend-engineer.md
```

### 测试验证
- ✅ 角色定义复制功能正常
- ✅ 自动发现现有角色功能正常
- ✅ Context传入功能正常
- ✅ 实例信息记录正确
- ✅ 向后兼容性保持

## 2025-07-24 角色加载方式修复

### 问题发现
- Amazon Q CLI 不支持 `--context` 参数
- 原有实现导致启动失败，错误信息：`Error: unexpected argument '--context' found`

### 解决方案
- **修改角色加载方式**: 改为在 Q 启动后通过消息方式发送角色定义
- **优化用户体验**: 角色定义作为初始消息发送，确保 AI 按角色行为
- **保持功能完整性**: 角色定义仍然从 `.cliExtra/roles` 目录加载

### 技术实现
1. **启动流程优化**:
   - 先启动 `q chat --trust-all-tools`
   - 等待 Q 启动完成（3秒）
   - 读取角色文件内容并作为消息发送
   - 构建角色确认消息，确保 AI 理解角色定义

2. **消息格式**:
   ```
   请按照以下角色定义来协助我：
   
   [角色文件内容]
   
   请确认你已理解并将按照以上角色定义来协助我的工作。
   ```

### 测试验证
- ✅ 修复启动失败问题
- ✅ 角色定义正确加载
- ✅ AI 按角色定义行为
- ✅ 实例正常运行
- ✅ 消息发送功能正常

## 2025-07-24 tmux会话启动方式优化

### 问题发现
- 实例启动后没有进入 Q chat 对话页面
- 停留在 shell 提示符状态，`q chat` 命令执行后立即退出
- 原因：先创建空会话再发送命令的方式不稳定

### 解决方案
- **直接启动方式**: 在创建 tmux 会话时直接启动 `q chat --trust-all-tools`
- **简化流程**: 移除中间的命令发送步骤，确保 Q chat 持续运行
- **优化时序**: 调整等待时间和角色加载时机

### 技术实现
1. **启动方式改进**:
   ```bash
   # 之前：先创建会话再发送命令
   tmux new-session -d -s "$session_name" -c "$project_dir"
   tmux send-keys -t "$session_name" "q chat --trust-all-tools" Enter
   
   # 现在：直接启动 Q chat
   tmux new-session -d -s "$session_name" -c "$project_dir" "q chat --trust-all-tools"
   ```

2. **角色加载优化**:
   - Q chat 启动后等待3秒确保完全初始化
   - 通过 `tmux send-keys` 发送角色定义消息
   - 提供清晰的状态反馈

### 测试验证
- ✅ 实例正确进入 Q chat 对话模式
- ✅ 角色定义成功加载并生效
- ✅ AI 按角色进行自我介绍
- ✅ 消息发送和接收功能正常
- ✅ tmux 会话稳定运行

### 用户体验改进
- 启动后直接进入可用状态
- 角色定义自动加载并确认
- 清晰的状态提示和反馈
- 稳定的会话持久化

