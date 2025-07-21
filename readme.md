# cliExtra

基于Screen的q CLI实例管理系统

## 功能特点

- **自动生成实例ID**: 支持自动生成随机实例ID，也可自定义实例名
- **项目级管理**: 每个项目有自己的 `.cliExtra` 目录，状态和日志独立管理
- **灵活启动**: 支持当前目录、指定目录或Git仓库克隆启动
- **会话管理**: 基于GNU Screen，支持会话保持和上下文管理
- **实时监控**: 支持实时监控实例输出和日志查看
- **消息发送**: 可以向运行中的实例发送消息
- **单个实例清理**: 支持停止和清理单个实例
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
```

### 实例管理

```bash
# 列出所有实例
cliExtra list

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

### 监控和日志

```bash
# 查看实例日志
cliExtra logs myproject           # 查看最近50行
cliExtra logs myproject 20        # 查看最近20行

# 实时监控实例输出
cliExtra monitor myproject
```

### 配置管理

```bash
# 交互式配置
cliExtra config

# 显示当前配置
cliExtra config show

# 设置配置项
cliExtra config set CLIEXTRA_HOME "/path/to/home"
```

## 目录结构

```
cliExtra/
├── cliExtra.sh              # 主控制脚本
├── install.sh               # 安装脚本
├── uninstall.sh             # 卸载脚本
├── README.md               # 本文件
└── bin/                    # 子命令脚本目录
    ├── cliExtra-common.sh   # 公共函数库
    ├── cliExtra-config.sh   # 配置管理
    ├── cliExtra-start.sh    # 启动实例
    ├── cliExtra-send.sh     # 发送消息
    ├── cliExtra-attach.sh   # 接管实例
    ├── cliExtra-stop.sh     # 停止实例
    ├── cliExtra-list.sh     # 列出实例
    ├── cliExtra-status.sh   # 查看状态
    ├── cliExtra-logs.sh     # 查看日志
    ├── cliExtra-monitor.sh  # 监控输出
    └── cliExtra-clean.sh    # 清理实例
```

## 项目结构

每个项目目录下会创建 `.cliExtra` 目录：

```
project/
├── .cliExtra/
│   ├── config              # 项目配置
│   ├── instances/          # 实例目录
│   │   └── instance_123/   # 实例123的会话信息
│   └── logs/               # 日志目录
│       └── instance_123.log # 实例123的日志
└── ... (项目文件)
```

## Screen操作

- **接管会话**: `screen -r q_instance_<id>`
- **分离会话**: 在会话中按 `Ctrl+A, D`
- **查看所有**: `screen -list`

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

- **GNU Screen**: 会话管理
- **Git**: 仓库克隆（可选）
- **Bash**: 脚本执行

## 许可证

[许可证信息]
