# cliExtra

基于tmux的Amazon Q CLI实例管理系统

cliExtra 是一个基于 shell 快速实现的 AWS AI 终端 Q 的多终端交互工具，旨在帮助开发者降低协作多终端的沟通成本。它提供了完整的实例生命周期管理、角色预设、工具集成和协作通信功能。

> **前置要求**: 使用本工具前，请先安装并初始化 Amazon Q CLI。支持免费版本和 Pro 版本。
> 
> 📖 **安装指南**: [Amazon Q CLI 安装文档](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-installing.html)

## 🌐 图形化管理界面

除了命令行工具，我们还提供了功能强大的 **Web 图形化管理界面**：

### 🔗 [cliExtraWeb - 图形化管理项目](https://github.com/zhoushoujianwork/cliExtraWeb)

![cliExtra Web 界面](docs/cliextra-web-interface.png)

### Web 界面特性
- **📊 实例管理面板** - 可视化查看所有实例状态和信息
- **💬 实时聊天界面** - 直接与 AI 实例进行对话交互
- **🔄 Namespace 管理** - 图形化的 namespace 切换和管理
- **📈 统计数据展示** - 实例数量统计和分布可视化
- **🛠️ 工具集成** - Web 端的工具管理和配置

- **🎯 角色管理** - 可视化的角色预设管理和应用
- **📱 响应式设计** - 支持桌面和移动设备访问

### 使用方式
1. **CLI 管理** - 使用 `cliExtra` 命令进行快速操作
2. **Web 管理** - 通过浏览器访问图形化界面进行可视化管理
3. **混合使用** - CLI 和 Web 界面数据实时同步，可以灵活切换使用

## 功能特点

- **自动生成实例ID**: 支持自动生成与目录相关的实例ID（如：cliExtra_project_timestamp_random），也可自定义实例名
- **统一工作目录管理**: 所有实例信息集中在系统工作目录，项目目录保持干净
- **灵活启动**: 支持当前目录、指定目录或Git仓库克隆启动
- **会话管理**: 基于tmux，支持会话保持和上下文管理
- **实时监控**: 支持实时监控实例输出和日志查看
- **消息发送**: 可以向运行中的实例发送消息
- **实例协作**: 支持实例间协作通信和广播通知
- **单个实例清理**: 支持停止和清理单个实例
- **Namespace管理**: 支持类似k8s namespace的概念，实例归属管理
- **智能默认行为**: 命令默认操作 default namespace，使用 -A/--all 显示所有 namespace
- **角色预设管理**: 支持前端、后端、测试、代码审查、运维等角色预设

- **跨项目协作**: 不同项目的实例可以在同一namespace中协作
- **Web 图形化管理**: 提供完整的 Web 界面进行可视化管理和实时交互
- **全局可用**: 安装后可在系统任何位置使用

## 安装

### 前置条件

在安装 cliExtra 之前，请确保已经安装并初始化了 Amazon Q CLI：

1. **安装 Amazon Q CLI**
   - 访问 [Amazon Q CLI 安装文档](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-installing.html)
   - 按照文档说明安装适合您系统的版本

2. **初始化 Amazon Q CLI**
   ```bash
   # 初始化 Amazon Q CLI（免费版本或 Pro 版本）
   q login
   ```

### 快速安装

```bash
# 克隆项目
git clone https://github.com/zhoushoujianwork/cliExtra.git
cd cliExtra

# 安装（会创建两个命令：cliExtra 和 qq）
./install.sh
```

安装后可以使用两种命令：
- `cliExtra` - 完整命令名
- `qq` - 简化命令（推荐）

### 手动安装

```bash
# 创建软链接
sudo ln -sf /path/to/cliExtra/cliExtra.sh /usr/local/bin/cliExtra
sudo ln -sf /path/to/cliExtra/cliExtra.sh /usr/local/bin/qq

# 设置执行权限
chmod +x /usr/local/bin/cliExtra
chmod +x /usr/local/bin/qq
```

## 使用方法

### 🌐 Web 图形化管理

访问 [cliExtraWeb 项目](https://github.com/zhoushoujianwork/cliExtraWeb) 获取完整的图形化管理界面，支持：
- 可视化实例管理和监控
- 实时聊天交互界面
- Namespace 管理
- 角色预设和工具配置

### 📟 命令行管理

### 启动实例

```bash
# 自动生成实例ID（推荐）
qq start                    # 在当前目录启动 (如: cliExtra_myproject_1234567890_1234)
qq start ../                # 在上级目录启动 (如: cliExtra_parentdir_1234567890_5678)
qq start /path/to/project   # 在指定目录启动 (如: cliExtra_project_1234567890_9012)
qq start https://github.com/user/repo.git  # 克隆并启动 (如: cliExtra_repo_1234567890_3456)

# 指定实例名字
qq start --name myproject   # 在当前目录启动，实例名为myproject
qq start ../ --name test    # 在上级目录启动，实例名为test

# 应用角色预设
qq start --role frontend    # 启动并应用前端工程师角色
qq start --name backend --role backend  # 启动并应用后端工程师角色
```

### 监控守护进程

cliExtra 提供了智能监控守护进程，基于文件时间戳自动检测 agent 的工作状态并更新状态文件。

#### 🔧 新一代状态检测技术

**基于时间戳的监控方案**：
- **检测原理**: 监控 tmux.log 文件的最后修改时间
- **空闲判断**: 文件超过阈值时间未更新 → 设置为 idle
- **忙碌判断**: 文件在阈值时间内有更新 → 设置为 busy
- **零误判**: 基于实际输出变化，不受内容格式影响
- **高性能**: stat系统调用比文本解析效率高数倍
- **自适应**: 自动适应所有AI agent的输出格式

#### 🔄 自动重启功能（类似 k8s pod）

**重启机制特性**：
- **智能检测**: 自动检测 tmux 会话异常退出
- **失败分析**: 记录详细的失败原因（TmuxSessionDied, QChatCrashed, SystemError 等）
- **重启策略**: 支持 Always, OnFailure, Never 三种策略
- **指数退避**: 5s → 10s → 20s → ... → 300s 的重启延迟
- **次数限制**: 最大重启次数限制（10次）防止无限重启
- **状态记录**: 完整的重启历史和统计信息

#### 功能特点
- **智能检测**: 基于文件时间戳，避免复杂的文本模式匹配
- **跨平台兼容**: 支持 macOS 和 Linux 系统
- **配置灵活**: 支持按 namespace 设置不同的空闲阈值
- **状态更新**: 自动更新 agent 状态文件（0=idle, 1=busy）
- **后台运行**: 守护进程模式，不影响正常使用
- **自动重启**: 类似 k8s pod 的自动重启机制
- **故障恢复**: 智能故障检测和自动恢复

#### 基本操作

```bash
# 启动监控守护进程（包含自动重启功能）
qq eg start

# 查看监控状态
qq eg status

# 查看监控日志
qq eg logs

# 重启监控
qq eg restart

# 停止监控
qq eg stop

# 状态检测引擎
qq status-engine health          # 健康检查
qq status-engine detect <id>     # 检测单个实例状态
qq status-engine batch           # 批量检测所有实例
qq status-engine set-threshold <ns> <seconds>  # 设置namespace阈值
```

#### 🔄 重启管理命令

```bash
# 查看重启统计
qq eg restart-stats              # 查看所有实例重启统计
qq eg restart-stats <instance_id> # 查看指定实例重启历史

# 设置重启策略
qq eg restart-config <instance_id> Always     # 总是重启（默认）
qq eg restart-config <instance_id> OnFailure  # 仅在失败时重启
qq eg restart-config <instance_id> Never      # 从不重启

# 清理重启记录
qq eg restart-cleanup            # 清理过期的重启记录
```

#### 检测规则

**基于时间戳的状态检测**：
- **空闲状态**: tmux.log 文件超过阈值时间（默认5秒）未更新
- **忙碌状态**: tmux.log 文件在阈值时间内有更新
- **默认阈值**: 5秒（可按 namespace 自定义）
- **场景阈值**: 
  - 交互式对话: 5秒
  - 批处理任务: 30秒
  - 开发调试: 10秒

**阈值配置**：
```bash
# 设置 namespace 特定阈值
qq status-engine set-threshold frontend 3

# 查看 namespace 阈值配置
qq status-engine get-threshold frontend
```

#### 🔄 自动重启规则

**重启触发条件**：
- tmux 会话异常退出
- Q chat 进程崩溃
- 系统资源不足导致的异常
- 长时间无响应（可配置）

**重启策略**：
- **Always**: 总是重启（默认策略）
- **OnFailure**: 仅在非用户主动操作的失败时重启
- **Never**: 从不自动重启

**重启延迟算法**：
```
第1次重启: 5秒
第2次重启: 10秒  
第3次重启: 20秒
第4次重启: 40秒
...
最大延迟: 300秒（5分钟）
```

**失败原因分类**：
- `TmuxSessionDied`: tmux 会话异常退出
- `QChatCrashed`: Q chat 进程崩溃
- `SystemError`: 系统资源不足
- `UserKilled`: 用户主动杀死进程
- `Timeout`: 响应超时
- `Unknown`: 未知原因

#### 监控日志示例
```
[2025-07-27 10:11:19] [DEBUG] Agent backend-api is waiting for input
[2025-07-27 10:11:19] [INFO] Updated agent backend-api status: 1 -> 0 (idle)
[2025-07-27 10:11:22] [DEBUG] Agent frontend-dev is busy
[2025-07-27 10:11:22] [INFO] Updated agent frontend-dev status: 0 -> 1 (busy)
[2025-07-27 10:11:25] [RESTART-WARN] Instance backend-api tmux session not found, attempting restart
[2025-07-27 10:11:25] [RESTART-INFO] Waiting 5s before restarting backend-api (attempt #1)
[2025-07-27 10:11:30] [RESTART-INFO] Successfully restarted instance backend-api
```

#### 配置说明
- **监控间隔**: 3秒检查一次
- **重启检查**: 30秒检查一次
- **日志文件**: `~/Library/Application Support/cliExtra/engine.log`
- **PID文件**: `~/Library/Application Support/cliExtra/engine.pid`
- **重启记录**: `~/Library/Application Support/cliExtra/namespaces/<namespace>/restart/<instance_id>.restart`

### 自动恢复功能

cliExtra 提供了类似 Kubernetes 容器自动恢复的功能，能够自动识别停止的实例并使用原有配置重新启动。

#### 🔄 自动恢复特性
- **智能识别**: 自动扫描所有 namespace 中的停止实例
- **配置保持**: 使用原有的工作目录、namespace、角色等信息启动
- **系统实例跳过**: 自动跳过 `*_system` 实例（通常没有有效项目目录）
- **守护进程**: 支持后台守护进程定期检查和恢复
- **批量操作**: 支持一次性恢复所有或指定 namespace 的实例

#### 基本操作

```bash
# 列出所有停止的实例
qq auto-recovery list-stopped
qq auto-recovery list-stopped -A          # 所有 namespace
qq auto-recovery list-stopped -n frontend # 指定 namespace

# 立即恢复停止的实例
qq recover-all                            # 恢复 default namespace 的实例
qq recover-all -A                         # 恢复所有 namespace 的实例
qq recover-all -n backend                 # 恢复指定 namespace 的实例
qq recover-all --dry-run                  # 预览模式，不实际执行

# 恢复单个实例
qq auto-recovery recover <instance_id>

# 启动自动恢复守护进程
qq auto-recovery start                    # 默认30秒检查间隔
qq auto-recovery start --interval 60      # 自定义检查间隔

# 管理守护进程
qq auto-recovery status                   # 查看守护进程状态
qq auto-recovery stop                     # 停止守护进程
qq auto-recovery restart                  # 重启守护进程
```

#### 使用场景

**机器重启后恢复**:
```bash
# 机器重启后，所有实例都变成 stopped 状态
qq list -A                                # 查看所有实例状态
qq recover-all -A                         # 一键恢复所有实例
```

**开发环境管理**:
```bash
# 启动守护进程，自动维护开发环境
qq auto-recovery start --interval 30

# 只恢复特定项目的实例
qq recover-all -n frontend --dry-run      # 预览
qq recover-all -n frontend                # 执行恢复
```

**批量运维**:
```bash
# 检查哪些实例需要恢复
qq auto-recovery list-stopped -A

# 分批恢复不同 namespace
qq recover-all -n backend
qq recover-all -n frontend
qq recover-all -n devops
```

#### 恢复逻辑

1. **实例扫描**: 扫描指定 namespace 中状态为 `stopped` 的实例
2. **配置读取**: 从实例信息文件中读取原有配置（项目目录、角色等）
3. **有效性检查**: 验证项目目录是否存在，跳过无效实例
4. **系统实例过滤**: 自动跳过 `*_system` 实例
5. **启动恢复**: 使用 `qq start` 命令和原有配置重新启动实例

#### 守护进程日志

守护进程会记录详细的恢复日志：

```bash
# 查看守护进程日志
tail -f ~/Library/Application\ Support/cliExtra/auto-recovery.log

# 日志示例
[2025-07-27 04:58:29] [INFO] 开始检查停止的实例
[2025-07-27 04:58:29] [INFO] 发现 3 个停止的实例，开始恢复
[2025-07-27 04:58:29] [INFO] 正在恢复实例: backend-api
[2025-07-27 04:58:30] [INFO] 实例恢复成功: backend-api
[2025-07-27 04:58:30] [INFO] 跳过系统实例: backend_system
[2025-07-27 04:58:30] [INFO] 检查完成，等待 30秒
```

### 实例管理

```bash
# 列出默认namespace的实例（简洁格式，每行一个实例ID，包含状态信息和重启次数）
qq list

# 列出所有namespace的实例（使用 -A 或 --all 参数）
qq list -A
qq list --all

# 列出指定namespace的实例
qq list --namespace frontend
qq list -n backend

# 列出默认namespace的实例（JSON格式，包含详细信息和重启次数）
qq list -o json

# 列出所有namespace的实例（JSON格式）
qq list -A -o json

# 显示指定实例的详细信息（包含namespace、状态和重启次数）
qq list myinstance

# 显示指定实例的详细信息（JSON格式，包含namespace、状态和重启次数）
qq list myinstance -o json

# 发送消息到实例
qq send myproject "你好，Q!"

# 接管实例终端
qq attach myproject

# 停止实例（保留数据，可恢复）
qq stop myproject

# 恢复已停止的实例，载入历史上下文
qq resume myproject
qq start --context myproject  # 等效命令

# 创建新实例并加载指定实例的历史上下文
qq start --name new-instance --context old-instance

# 清理单个实例（停止并删除文件）
qq clean myproject

# 清理所有实例
qq clean all

# 清理指定namespace中的所有实例
qq clean all --namespace frontend

# 预览将要清理的实例（不实际执行）
qq clean all --dry-run
qq clean all --namespace backend --dry-run
```

**实例状态说明**:
- `idle` - 空闲，可接收新任务
- `busy` - 忙碌，正在处理任务  
- `stopped` - 实例已停止

**重启次数显示**:
- `qq list` 命令现在显示每个实例的重启次数
- 表格格式中的 `RESTARTS` 列显示自动重启次数
- JSON 格式中的 `restart_count` 字段包含重启次数
- 详细信息中显示 `重启次数: X` 信息

**状态文件位置**: `~/Library/Application Support/cliExtra/namespaces/<namespace>/status/<instance_id>.status`

### 配置管理

```bash
# 查看当前配置和系统状态
qq config show

# 获取特定配置项
qq config get home          # 显示工作目录
qq config get os            # 显示操作系统类型

# 自定义工作目录（如果需要）
qq config set home /custom/path

# 重置为默认配置
qq config reset
```

### 角色预设管理

```bash
# 列出所有可用角色
qq role list

# 显示角色预设内容
qq role show frontend
qq role show shell      # 显示Shell工程师角色预设

# 应用角色预设到运行中的实例
qq role apply frontend             # 自动查找当前目录的运行实例并应用前端工程师角色
qq role apply backend myproject    # 指定实例应用后端工程师角色

# 强制应用（不需要确认，适合自动化脚本）
qq role apply devops -f            # 强制应用运维工程师角色
qq role apply frontend myproject -f
qq role apply backend -f myproject # 参数顺序灵活

# 移除实例中的角色预设
qq role remove                     # 自动查找当前目录的运行实例并移除角色
qq role remove myproject           # 移除指定实例的角色预设
```

#### 🤖 新的角色应用机制

**重要变更**: `qq role apply` 现在采用全新的应用机制：

1. **消息方式发送**: 角色定义通过消息直接发送到运行中的实例
2. **系统目录保存**: 角色信息保存到系统目录 `~/Library/Application Support/cliExtra/namespaces/<namespace>/instances/instance_<id>/roles/`
3. **实例信息更新**: 自动更新实例的 info 文件中的 ROLE 和 ROLE_FILE 信息
4. **智能查找**: 不指定实例ID时自动查找当前目录对应的运行实例

**使用流程**:
```bash
# 1. 启动实例
qq start --name myproject

# 2. 应用角色（会立即生效）
qq role apply shell

# 3. 验证角色应用
qq list  # 查看实例列表中的角色信息

# 4. 移除角色（如需要）
qq role remove
```

**技术优势**:
- **即时生效**: 角色定义立即发送到AI实例，无需重启
- **持久保存**: 角色信息保存在系统目录，支持实例恢复
- **状态同步**: 实例列表正确显示角色信息
- **智能操作**: 自动查找当前目录对应的实例

### Namespace管理

#### 默认行为说明

**重要**: 为了避免信息过载，所有支持 namespace 的命令都采用智能默认行为：

- **默认显示**: 只显示 `default` namespace 中的内容
- **显示所有**: 使用 `-A` 或 `--all` 参数显示所有 namespace 的内容
- **指定显示**: 使用 `-n` 或 `--namespace` 参数显示特定 namespace 的内容

#### Namespace 基本操作

```bash
# 创建namespace
qq ns create frontend
qq ns create backend
qq ns create devops

# 查看namespace
qq ns show                    # 显示所有namespace
qq ns show frontend           # 显示frontend namespace详情
qq ns show -o json            # JSON格式输出

# 删除namespace（完全清理）
qq ns delete frontend         # 删除 namespace 及所有相关目录和文件
qq ns delete backend --force  # 强制删除（停止其中的实例并清理所有数据）

# 启动实例到指定namespace
qq start --namespace frontend
qq start --name api --ns backend

# 修改实例的namespace
qq set-ns myinstance backend  # 将实例移动到backend namespace

# 清理无效的namespace目录
qq cleanup-invalid-ns --dry-run    # 预览模式，查看将要清理的目录
qq cleanup-invalid-ns --force      # 强制清理包含无效字符的namespace
```

#### Namespace 名称规则

为确保系统稳定性，namespace 名称必须符合以下规则：

- **字符限制**: 只能包含英文字母、数字、下划线(_)和连字符(-)
- **长度限制**: 不超过 32 个字符
- **禁止字符**: 不能包含中文、空格或其他特殊字符

**示例**:
```bash
# ✅ 有效的 namespace 名称
qq ns create frontend
qq ns create backend-api
qq ns create test_env
qq ns create dev123

# ❌ 无效的 namespace 名称
qq ns create "前端开发"           # 包含中文
qq ns create "frontend dev"      # 包含空格
qq ns create "very-long-namespace-name-that-exceeds-limit"  # 超过32字符
```

#### 智能默认行为示例

```bash
# 实例管理 - 默认只显示 default namespace
qq list                       # 只显示 default namespace 的实例
qq list -A                    # 显示所有 namespace 的实例
qq list -n frontend           # 只显示 frontend namespace 的实例

# 广播通信 - 默认只广播给 default namespace
qq broadcast "系统维护通知"    # 只广播给 default namespace
qq broadcast "系统更新" -A     # 广播给所有 namespace
qq broadcast "前端更新" -n frontend  # 只广播给 frontend namespace

# 批量清理 - 默认只清理 default namespace
qq clean all                  # 只清理 default namespace 的实例
qq clean all -A               # 清理所有 namespace 的实例
qq clean all -n backend       # 只清理 backend namespace 的实例
```

### 工具管理

```bash
# 查看所有可用工具
qq tools list

# 以JSON格式查看所有可用工具
qq tools list -o json

# 显示工具详细信息
qq tools show git
qq tools show dingtalk

# 创建工具软链接到当前项目（自动覆盖已存在的工具）
qq tools add git              # 创建git工具软链接
qq tools add dingtalk         # 创建钉钉工具软链接

# 移除项目中的工具
qq tools remove git           # 移除git工具
qq tools remove dingtalk      # 移除钉钉工具

# 查看当前项目已安装的工具
qq tools installed

# 软链接管理（新功能）
qq tools check-links          # 检查工具软链接状态
qq tools repair-links         # 修复损坏的软链接
qq tools convert-to-links     # 将普通文件转换为软链接

# 指定项目路径操作工具
qq tools add git --project /path/to/project
```

#### 🔗 软链接优势

**实时更新**: 使用软链接替代文件复制，修改源文件后所有项目立即获取最新版本
- **统一管理**: 所有定义文件集中在源目录，便于版本控制
- **减少冗余**: 避免多份相同文件的存储
- **一处修改，处处生效**: 修改 rules、roles、tools 后立即在所有项目中生效

**注意**: `qq tools add` 命令现在创建软链接而非复制文件，确保使用最新版本的工具配置。

### 对话记录和回放

```bash
# 查看可用的对话记录
qq replay list

# 回放指定实例的对话记录
qq replay instance backend-api
qq replay instance frontend-dev --format json

# 回放指定namespace的消息历史
qq replay namespace development
qq replay namespace backend --format timeline

# 限制显示记录数量
qq replay instance backend-api --limit 10

# 显示指定时间后的记录
qq replay namespace development --since "2025-01-20"
```

### 实例协作

```bash
# 发送消息到指定实例（自动注入身份信息）
qq send backend-api "API开发完成，请进行前端集成"

# 发送消息时不添加发送者标识
qq send frontend-dev "调试消息" --no-sender-id

# 广播消息到默认namespace的所有实例（自动注入身份信息）
qq broadcast "系统维护通知：今晚22:00-24:00进行系统升级"

# 广播消息到所有namespace的实例
qq broadcast "全系统更新通知" -A
qq broadcast "全系统更新通知" --all

# 广播到指定namespace
qq broadcast "前端组件库更新" --namespace frontend

# 广播时不添加发送者标识
qq broadcast "系统通知" --no-sender-id

# 排除特定实例的广播
qq broadcast "测试环境重启" --exclude self

# 预览广播目标（不实际发送）
qq broadcast "部署通知" --dry-run

# 查看发送者统计信息
qq sender-stats                    # 查看24小时内的统计
qq sender-stats 7d                 # 查看7天内的统计
qq sender-stats all                # 查看所有统计
```

#### 🤖 身份信息自动注入功能

为了让AI实例能够持续感知自己的身份和角色，cliExtra 在每次发送消息时都会自动注入身份信息：

**自动注入机制**：
- 每次 `qq send` 和 `qq broadcast` 都会自动在消息前添加身份信息
- 格式：`你是 ns:namespace 的 角色工程师。原始消息内容`
- 例如：`你是 ns:q_cli 的 Shell工程师。请优化这个脚本的性能`

**身份信息来源**：
- **Namespace**: 从实例的namespace配置获取
- **角色信息**: 从实例的info文件中的ROLE字段获取
- **角色映射**: 自动将英文角色名映射为中文（如 shell → Shell工程师）

**支持的角色类型**：
- `shell` → Shell工程师
- `frontend` → 前端工程师  
- `backend` → 后端工程师
- `fullstack` → 全栈工程师
- `devops` → 运维工程师
- `test` → 测试工程师
- `embedded` → 嵌入式工程师
- `data` → 数据工程师
- `ai` → AI工程师
- `security` → 安全工程师
- `ui-ux` → UI/UX设计师
- `system-coordinator` → 系统协调员

**功能价值**：
- **持续身份感知**: AI实例在每次对话中都能明确自己的身份
- **角色一致性**: 确保AI按照指定角色进行响应和协作
- **上下文连续性**: 避免AI在长时间对话中忘记自己的角色定位
- **协作效率**: 接收方能立即了解发送方的专业领域和职责范围

#### 🏷️ 发送者标识功能

为了支持 DAG 流程追踪和协作上下文管理，cliExtra 提供了自动发送者标识功能：

**默认行为**：
- 所有消息（send/broadcast）默认自动添加发送者标识
- 格式：`[发送者: namespace:instance_id] 身份信息。原始消息内容`
- 例如：`[发送者: default:user] 你是 ns:q_cli 的 Shell工程师。API开发完成，请进行前端集成`

**功能价值**：
- **DAG 流程追踪**：明确知道是哪个节点完成了任务
- **协作上下文**：接收方知道与谁协作，便于后续沟通
- **消息审计**：完整的消息来源追踪和统计分析
- **智能路由**：根据发送者和接收者更新工作流状态

**控制选项**：
- `--sender-id`：显式启用发送者标识（默认）
- `--no-sender-id`：禁用发送者标识
- `qq sender-stats`：查看发送者统计信息
- `qq sender-info`：获取当前发送者信息

**使用场景**：
```bash
# 正常协作消息（带发送者标识）
qq send backend-api "API接口已完成，请进行集成测试"

# 调试或临时消息（不带发送者标识）
qq send test-instance "临时调试信息" --no-sender-id

# 系统广播（带发送者标识，便于追踪）
qq broadcast "部署完成，请各团队验证功能"

# 简单通知（不带发送者标识）
qq broadcast "系统重启完成" --no-sender-id
```

**注意**: 每个项目建议只保留一个角色预设，多个角色可能导致意图识别混乱。应用新角色时会自动移除现有角色。

### AI协作感知

每个角色实例都具备协作感知能力：

- **自动识别协作场景**: 完成工作后主动询问是否需要通知其他实例
- **智能推荐协作对象**: 基于工作内容推荐合适的协作实例
- **标准化协作消息**: 提供协作消息模板，确保信息传递准确
- **跨职能任务识别**: 识别需要多角色协作的任务并建议启动专门实例

协作示例：
```bash
# 后端工程师完成API开发后，AI会主动询问：
# "API开发已完成，是否需要通知前端工程师进行集成？"
# 建议命令：qq send frontend-dev "API接口已完成，请进行前端集成测试"

# 运维工程师完成部署后，AI会建议：
# "部署环境已准备完成，建议广播通知相关开发团队"
# 建议命令：qq broadcast "生产环境部署完成，可以开始发布" --namespace backend
```

### 角色预设结构

当应用角色预设时，会在项目目录下创建 `.amazonq` 目录：

```
project/
├── .amazonq/
│   └── rules/              # Amazon Q规则目录
│       ├── [role]-engineer.md    # 具体角色预设文件
│       └── role-boundaries.md    # 通用角色边界限制规则
└── ... (项目文件)
```

**重要**: 
- 每个项目只保留一个角色预设，确保意图识别的准确性
- 应用新角色时会自动替换现有角色
- 通用边界规则确保每个角色专注于自己的职责范围
- 遇到跨职能任务时，系统会主动建议启动专门的实例

## 项目结构

cliExtra 采用工作目录统一管理的方式，所有实例信息都存储在系统工作目录中，项目目录只保留配置文件：

### 工作目录结构

```
# macOS 系统
~/Library/Application Support/cliExtra/
├── config                      # 全局配置
├── namespaces/                 # 所有namespace统一管理
│   ├── default/                # default namespace
│   │   ├── instances/          # 实例目录
│   │   │   └── instance_123/
│   │   │       ├── tmux.log    # tmux会话日志
│   │   │       ├── info        # 实例详细信息
│   │   │       ├── project_path # 项目路径引用
│   │   │       └── namespace   # namespace信息（向后兼容）
│   │   ├── logs/               # 实例日志目录
│   │   │   └── instance_123.log
│   │   ├── conversations/      # 对话记录目录
│   │   │   └── instance_123.json
│   │   └── namespace_cache.json # namespace缓存
│   ├── frontend/               # frontend namespace
│   │   ├── instances/
│   │   ├── logs/
│   │   ├── conversations/
│   │   └── namespace_cache.json
│   └── backend/                # backend namespace
│       ├── instances/
│       ├── logs/
│       ├── conversations/
│       └── namespace_cache.json
└── projects/                   # Git克隆的项目（可选）
    └── cloned-repo/

# Linux 系统
~/.cliExtra/                    # 普通用户使用用户目录
# 或
/opt/cliExtra/                  # root 用户使用系统级目录
├── config
├── namespaces/
│   ├── default/
│   ├── frontend/
│   └── backend/
└── projects/
```

### 项目目录结构

每个被管理的项目目录只包含配置文件，不存储实例运行信息：

```
/path/to/your/project/
├── .amazonq/
│   └── rules/                  # Amazon Q规则目录（自动同步）
│       ├── frontend-engineer.md    # 前端工程师角色预设
│       ├── backend-engineer.md     # 后端工程师角色预设
│       ├── devops-engineer.md      # 运维工程师角色预设
│       ├── cliextra-collaboration.md # 协作增强规则
│       ├── role-boundaries.md      # 角色边界规则
│       ├── tools_git.md            # Git工具能力（自动安装）
│       └── tools_dingtalk.md       # 钉钉工具能力（手动添加）
└── ... (项目文件)
```

### 目录设计优势

1. **统一管理**: 所有实例信息集中在工作目录，便于管理和备份
2. **项目隔离**: 项目目录保持干净，只包含必要的配置文件
3. **跨项目协作**: 不同项目的实例可以在同一namespace中协作
4. **系统级服务**: 支持系统级的实例管理和监控
5. **向后兼容**: 保持对旧版本目录结构的兼容性
6. **完整清理**: namespace 删除时完全清理所有相关目录和文件
7. **安全保护**: 防止误删默认 namespace，支持强制删除模式

## tmux操作

- **接管会话**: `tmux attach-session -t q_instance_<id>`
- **分离会话**: 在会话中按 `Ctrl+B, D`
- **查看所有**: `tmux list-sessions`

## 卸载

```bash
# 使用卸载脚本
./install.sh uninstall

# 或手动删除软链接
sudo rm -f /usr/local/bin/cliExtra
sudo rm -f /usr/local/bin/qq
```

## 故障排除

### 命令不可用
如果安装后 `qq` 或 `cliExtra` 命令不可用：
1. 检查PATH环境变量是否包含安装目录
2. 运行 `source ~/.zshrc` 或 `source ~/.bashrc`
3. 重新打开终端

### 权限问题
如果遇到权限问题：
```bash
sudo ./install.sh
```

### 软链接问题
如果软链接有问题：
```bash
sudo rm -f /usr/local/bin/cliExtra /usr/local/bin/qq
sudo ln -sf /path/to/cliExtra/cliExtra.sh /usr/local/bin/cliExtra
sudo ln -sf /path/to/cliExtra/cliExtra.sh /usr/local/bin/qq
```

## 依赖

- **Amazon Q CLI**: AI 助手核心（必需）
- **tmux**: 会话管理
- **Git**: 仓库克隆（可选）
- **Bash**: 脚本执行

## 更新日志

### 2025-07-24
- **新增**: Namespace 默认行为优化
  - `qq list` 等命令默认只显示 default namespace 的内容
  - 添加 `-A` 或 `--all` 参数显示所有 namespace 的内容
  - `qq broadcast` 默认只广播给 default namespace，使用 `-A` 广播给所有
  - 统一所有支持 namespace 的命令行为，避免信息过载
  - 更新文档说明新的默认行为和参数使用方法

### 2025-07-23
- **修复**: 修复了 `qq ns show -o json` 命令的显示问题
  - 现在能正确显示所有存在的 namespace（包括 default）
  - 修复了 JSON 输出格式，确保 instances 数组格式正确
  - 改进了 namespace 检测逻辑，支持从目录结构和配置文件中获取
  - 增强了实例计数的准确性

## 许可证
MIT License
