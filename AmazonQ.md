每次功能完成后记得更新 readme.md 文件；

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

## 2025-07-24 Namespace System 实例功能

### 设计理念
为每个 namespace 配备一个标配的 system 级别协调实例，作为该 namespace 的协调中心和系统任务执行者。

### 功能特点
1. **自动创建**: `qq ns create xxx` 时自动创建 `{namespace}-system` 实例
2. **自动修复**: `qq ns show xxx` 时检查并修复缺失的 system 实例
3. **系统级权限**: 可以协调该 namespace 下的其他实例，执行系统级任务
4. **专用角色**: 使用 `system-coordinator` 角色，专门负责系统协调

### 技术实现
1. **System 实例规范**:
   - 实例名称: `{namespace}-system`
   - 工作目录: 系统目录下的 namespace 目录
   - 角色: `system-coordinator`
   - 用途: namespace 协调中心和系统任务执行

2. **创建和修复机制**:
   - `create_system_instance()`: 创建 system 实例
   - `check_and_repair_system_instance()`: 检查和修复 system 实例
   - 集成到 namespace 创建和显示流程中

3. **System Coordinator 角色**:
   - 专门的角色定义文件 `system-coordinator.md`
   - 具备项目初始化、实例协调、系统任务执行能力
   - 可以替代临时 agent，执行 `qq init` 等系统任务

### 使用场景
1. **项目初始化**: 通过 system 实例执行项目分析和初始化
2. **实例协调**: 协调 namespace 内其他实例的工作
3. **系统任务**: 执行跨实例的系统级任务
4. **状态监控**: 监控 namespace 内实例状态和健康度

### 测试验证
- ✅ namespace 创建时自动创建 system 实例
- ✅ system 实例使用正确的角色和工作目录
- ✅ 检查和修复功能正常工作
- ✅ system 实例可以正常接收和处理消息
- ✅ 删除 namespace 时正确清理 system 实例

### 用户价值
- **简化操作**: 不再需要手动创建临时 agent
- **统一管理**: 每个 namespace 都有标准的协调实例
- **自动修复**: 系统自动检查和修复缺失的 system 实例
- **角色专业**: 专门的 system-coordinator 角色提供更好的系统服务