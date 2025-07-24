# cliExtra (qq) 快速使用指南


**注意**：协作的时候注意 namespace 必须要有，注意自己的工作边界

## 实例状态管理机制

### 状态标记文件设计
每个实例都有对应的状态标记文件，类似 PID 文件的概念：

```bash
# 状态文件位置
~/Library/Application Support/cliExtra/namespaces/<namespace>/status/<instance_id>.status

# 状态值定义
idle     # 空闲状态，可以接收新任务
busy     # 忙碌状态，正在处理任务
waiting  # 等待状态，等待用户输入或外部响应
error    # 错误状态，需要人工干预
```

### AI 实例状态管理规则
作为 AI 实例，你需要在处理任务时主动管理自己的状态：

1. **开始处理任务时**：
   - 立即将状态设置为 `busy`
   - 记录开始时间和任务描述

2. **任务处理完成时**：
   - 将状态设置为 `idle`
   - 清理临时状态信息

3. **等待用户输入时**：
   - 将状态设置为 `waiting`
   - 记录等待原因

4. **遇到错误时**：
   - 将状态设置为 `error`
   - 记录错误信息

### 状态文件格式
```json
{
  "status": "busy",
  "timestamp": "2025-07-24T10:00:00Z",
  "task": "处理用户请求：优化界面布局",
  "pid": "12345",
  "last_activity": "2025-07-24T10:05:00Z"
}
```

### 协作时的状态检查
在发送协作消息前，应该检查目标实例的状态：
- `idle`: 可以立即发送消息
- `busy`: 建议等待或使用低优先级发送
- `waiting`: 可以发送，但可能需要等待响应
- `error`: 不建议发送任务消息，可发送帮助消息

## 基本命令

```bash
qq help                    # 查看完整帮助信息
qq init ./ [project_name]  # 分析项目并生成项目描述
qq list --namespace [namespace]                   # 查看指定namespace的实例
qq list --namespace [namespace] -o json            # JSON格式查看指定namespace的实例详情
```

## 项目初始化

```bash
# 分析当前目录项目
qq init ./

# 分析项目并指定名称
qq init ./ myproject

# 分析指定目录
qq init /path/to/project
```

**init 功能**：
- 🔍 自动分析项目结构、技术栈、架构
- 📝 生成 `.amazonq/rules/project.md` 项目描述文件
- 🎯 推荐合适的开发人员(agent)角色配置
- 🚀 提供启动命令示例和开发建议

## 协作核心功能

### 1. 查看同 namespace 下的协作伙伴

```bash
# 查看所有实例（显示所有 namespace）
qq list

# 查看指定 namespace 的实例
qq list --namespace q_cli
qq list --namespace frontend

# JSON格式查看详细信息（包含角色、状态、工具等）
qq list -o json

# 示例输出：可以看到每个实例的角色和 namespace
# cliextra_1753323696_2086 (namespace: q_cli, role: fullstack)
# cliextraweb_1753324164_28651 (namespace: q_cli, role: fullstack)
```

### 2. Workflow 协作流程

```bash
# 查看当前 workflow 配置
qq workflow show

# 查看 workflow 执行状态和角色分配
qq workflow-engine status

# 完成任务并自动通知下一个角色
qq workflow-engine complete <task_id> [namespace] [deliverables]

# 示例：后端完成开发任务
qq workflow-engine complete backend_dev default "API接口,接口文档,测试数据"
```

### 3. 直接协作通信

```bash
# 发送消息给特定实例
qq send cliextra_1753323696_2086 "需要协助处理这个功能"

# 广播消息给所有实例
qq broadcast "系统维护通知：今晚22:00-24:00"

# 广播给指定 namespace
qq broadcast "前端组件更新完成" --namespace frontend
```

## 协作工作流程

1. **查看协作环境**：使用 `qq list` 了解当前有哪些协作伙伴
2. **检查工作流程**：使用 `qq workflow show` 了解协作流程
3. **查看角色分配**：使用 `qq workflow-engine status` 查看角色实例映射
4. **完成任务**：使用 `qq workflow-engine complete` 自动触发协作
5. **直接沟通**：必要时使用 `qq send` 进行点对点沟通

## 快速上手示例

```bash
# 1. 查看帮助
qq help

# 2. 分析项目（推荐第一步）
qq init ./ myproject

# 3. 查看当前协作环境
qq list -o json

# 4. 查看工作流程配置
qq workflow show

# 5. 查看角色实例映射状态
qq workflow-engine status

# 6. 开始协作！
# 完成任务时：
qq workflow-engine complete backend_dev default "API开发完成"

# 直接沟通时：
qq send <实例名> "消息内容"
```

**记住**：不确定命令用法时，随时使用 `qq help` 查看完整文档。
