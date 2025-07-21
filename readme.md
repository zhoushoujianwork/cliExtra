# cliExtra

基于tmux的q CLI实例管理系统

## 功能特点

- **自动生成实例ID**: 支持自动生成随机实例ID，也可自定义实例名
- **项目级管理**: 每个项目有自己的 `.cliExtra` 目录，状态和日志独立管理
- **灵活启动**: 支持当前目录、指定目录或Git仓库克隆启动
- **会话管理**: 基于tmux，支持会话保持和上下文管理
- **实时监控**: 支持实时监控实例输出和日志查看
- **消息发送**: 可以向运行中的实例发送消息
- **实例协作**: 支持实例间协作通信和广播通知
- **单个实例清理**: 支持停止和清理单个实例
- **Namespace管理**: 支持类似k8s namespace的概念，实例归属管理
- **角色预设管理**: 支持前端、后端、测试、代码审查、运维等角色预设
- **全局可用**: 安装后可在系统任何位置使用

## 安装

### 快速安装

```bash
# 克隆项目
git clone <repository-url>
cd cliExtra

# 安装
./install.sh
```

### 手动安装

```bash
# 创建软链接
sudo ln -sf /path/to/cliExtra/cliExtra.sh /usr/local/bin/cliExtra

# 设置执行权限
chmod +x /usr/local/bin/cliExtra
```

## 使用方法

### 启动实例

```bash
# 自动生成实例ID（推荐）
cliExtra start                    # 在当前目录启动
cliExtra start ../                # 在上级目录启动
cliExtra start /path/to/project   # 在指定目录启动
cliExtra start https://github.com/user/repo.git  # 克隆并启动

# 指定实例名字
cliExtra start --name myproject   # 在当前目录启动，实例名为myproject
cliExtra start ../ --name test    # 在上级目录启动，实例名为test

# 应用角色预设
cliExtra start --role frontend    # 启动并应用前端工程师角色
cliExtra start --name backend --role backend  # 启动并应用后端工程师角色
```

### 实例管理

```bash
# 列出所有实例（简洁格式，每行一个实例ID）
cliExtra list

# 列出所有实例（JSON格式，包含详细信息）
cliExtra list --json

# 显示指定实例的详细信息
cliExtra list myinstance

# 显示指定实例的详细信息（JSON格式）
cliExtra list myinstance --json

# 查看实例状态
cliExtra status myproject

# 发送消息到实例
cliExtra send myproject "你好，Q!"

# 接管实例终端
cliExtra attach myproject

# 停止实例
cliExtra stop myproject

# 清理单个实例（停止并删除文件）
cliExtra clean myproject

# 清理所有实例
cliExtra clean-all
```

### 角色预设管理

```bash
# 列出所有可用角色
cliExtra role list

# 显示角色预设内容
cliExtra role show frontend
cliExtra role show           # 显示当前目录的角色（只显示角色名）
cliExtra role show ./        # 显示指定目录的角色（只显示角色名）

# 应用角色预设到项目或实例
cliExtra role apply frontend             # 当前目录应用前端工程师角色
cliExtra role apply backend myproject    # 指定实例应用后端工程师角色

# 强制应用（不需要确认，适合自动化脚本）
cliExtra role apply devops -f            # 强制应用运维工程师角色
cliExtra role apply frontend myproject -f
cliExtra role apply backend -f myproject # 参数顺序灵活

# 移除项目/实例中的角色预设
cliExtra role remove
cliExtra role remove myproject
```

### Namespace管理

```bash
# 创建namespace
cliExtra ns create frontend
cliExtra ns create backend
cliExtra ns create devops

# 查看namespace
cliExtra ns show                    # 显示所有namespace
cliExtra ns show frontend           # 显示frontend namespace详情
cliExtra ns show --json             # JSON格式输出

# 删除namespace
cliExtra ns delete frontend         # 删除空的namespace
cliExtra ns delete backend --force  # 强制删除（停止其中的实例）

# 启动实例到指定namespace
cliExtra start --namespace frontend
cliExtra start --name api --ns backend

# 修改实例的namespace
cliExtra set-ns myinstance backend  # 将实例移动到backend namespace
```

### 工具管理

```bash
# 查看所有可用工具
cliExtra tools list

# 显示工具详细信息
cliExtra tools show git
cliExtra tools show dingtalk

# 添加工具到当前项目
cliExtra tools add git              # 添加git工具
cliExtra tools add dingtalk         # 添加钉钉工具

# 移除项目中的工具
cliExtra tools remove git           # 移除git工具
cliExtra tools remove dingtalk      # 移除钉钉工具

# 查看当前项目已安装的工具
cliExtra tools installed

# 指定项目路径操作工具
cliExtra tools add git --project /path/to/project
```

### 实例协作

```bash
# 发送消息到指定实例
cliExtra send backend-api "API开发完成，请进行前端集成"

# 广播消息到所有实例
cliExtra broadcast "系统维护通知：今晚22:00-24:00进行系统升级"

# 广播到指定namespace
cliExtra broadcast "前端组件库更新" --namespace frontend

# 排除特定实例的广播
cliExtra broadcast "测试环境重启" --exclude self

# 预览广播目标（不实际发送）
cliExtra broadcast "部署通知" --dry-run
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
# 建议命令：cliExtra send frontend-dev "API接口已完成，请进行前端集成测试"

# 运维工程师完成部署后，AI会建议：
# "部署环境已准备完成，建议广播通知相关开发团队"
# 建议命令：cliExtra broadcast "生产环境部署完成，可以开始发布" --namespace backend
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

每个项目目录下会创建 `.cliExtra` 目录和 `.amazonq` 目录：

```
project/
├── .cliExtra/
│   ├── config              # 项目配置
│   ├── instances/          # 实例目录
│   │   └── instance_123/   # 实例123的会话信息
│   │       ├── tmux.log    # tmux会话日志
│   │       ├── namespace   # 实例namespace信息
│   │       └── info        # 实例详细信息
│   └── logs/               # 日志目录
│       └── instance_123.log # 实例123的日志
├── .amazonq/
│   └── rules/              # Amazon Q规则目录（自动同步）
│       ├── frontend-engineer.md    # 前端工程师角色预设
│       ├── backend-engineer.md     # 后端工程师角色预设
│       ├── devops-engineer.md      # 运维工程师角色预设
│       ├── cliextra-collaboration.md # 协作增强规则
│       ├── role-boundaries.md      # 角色边界规则
│       ├── tools_git.md            # Git工具能力（自动安装）
│       └── tools_dingtalk.md       # 钉钉工具能力（手动添加）
└── ... (项目文件)
```

**重要**: 
- `.amazonq/rules` 目录在每次启动实例时自动从 `cliExtra/rules` 同步
- 每个项目都有独立的rules副本，确保项目间的隔离
- rules文件包含协作感知能力和角色边界管理
- 工具文件以 `tools_` 前缀命名，支持动态添加和移除

## tmux操作

- **接管会话**: `tmux attach-session -t q_instance_<id>`
- **分离会话**: 在会话中按 `Ctrl+B, D`
- **查看所有**: `tmux list-sessions`

## 卸载

```bash
# 使用卸载脚本
./uninstall.sh

# 或手动删除软链接
sudo rm -f /usr/local/bin/cliExtra
```

## 故障排除

### 命令不可用
如果安装后 `cliExtra` 命令不可用：
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
sudo rm -f /usr/local/bin/cliExtra
sudo ln -sf /path/to/cliExtra/cliExtra.sh /usr/local/bin/cliExtra
```

## 依赖

- **tmux**: 会话管理
- **Git**: 仓库克隆（可选）
- **Bash**: 脚本执行

## 许可证

[许可证信息]
