# Workflow 上下文规则

## 🔄 当前 Namespace Workflow 配置

你必须严格遵循以下 workflow 配置进行工作和协作：

### 获取最新 Workflow 配置
```bash
# 显示当前namespace的workflow配置
qq workflow show

# 显示指定namespace的workflow配置  
qq workflow show <namespace>

# 查看workflow执行状态
qq workflow status

# 显示DAG结构和角色分配
qq workflow dag show

# 查看所有namespace的workflow列表
qq workflow list
```

### 获取当前任务状态
```bash
# 查看当前工作流状态和角色实例映射
workflow-engine status

# 查看指定namespace的状态
workflow-engine status <namespace>
```

## 🎯 基于 Workflow 的行为指导

### 强制性遵循规则
根据 workflow 配置，你必须：

1. **角色职责遵循**
   - 严格按照 `qq workflow dag show` 显示的角色定义工作
   - 只使用角色定义中允许的 tools
   - 专注于你的 responsibilities 范围内的工作

2. **任务执行流程**
   - 按照 DAG 中定义的节点顺序执行任务
   - 完成任务后使用 `workflow-engine complete` 自动触发协作
   - 遵循 completion_trigger 中定义的通知规则

3. **协作关系执行**
   - 根据 edges 定义的连接关系进行协作
   - 使用 message_template 中定义的消息格式
   - 支持条件分支和反馈循环

4. **自动化通知执行**
   - 优先使用 workflow-engine 的自动通知功能
   - 必要时使用 qq send 或 qq broadcast 手动通知
   - 遵循 auto_triggers 中定义的规则

### Workflow 命令使用示例

#### 查看当前工作流程
```bash
# 显示完整的workflow配置
qq workflow show

# 显示DAG结构和角色分配
qq workflow dag show

# 查看当前执行状态
workflow-engine status
```

#### 执行任务和协作
```bash
# 完成后端开发任务
workflow-engine complete backend_dev simple_dev "API接口,接口文档,测试数据"

# 完成前端开发任务  
workflow-engine complete frontend_dev simple_dev "前端页面,接口集成,功能测试"

# 完成部署任务
workflow-engine complete deployment simple_dev "部署完成,环境验证,监控配置"
```

#### 处理反馈和调整
```bash
# 前端发现问题，请求后端调整
qq send backend-api "接口参数格式需要调整：
- 用户ID应该是字符串类型，不是数字
- 时间格式请使用 ISO 8601 标准
- 请添加错误码说明

请尽快调整，谢谢！"

# 后端调整完成后
workflow-engine complete backend_feedback simple_dev "接口格式调整完成"
```

### 协作执行模板

#### 任务完成自动通知
当你完成任务时，使用 workflow 引擎自动触发通知：
```bash
# 完成任务并自动通知下一个角色
workflow-engine complete <task_id> [namespace] [deliverables]

# 示例：后端完成接口开发
workflow-engine complete backend_dev simple_dev "API接口,接口文档,测试数据"
# 自动执行: qq send frontend-web "🚀 后端接口开发完成！..."
```

#### 手动协作通知
如果需要手动发送协作消息：
```bash
# 发送给特定角色实例
qq send <target_instance> "协作消息内容"

# 广播给所有实例
qq broadcast "广播消息内容"

# 广播给指定namespace
qq broadcast "消息内容" --namespace <namespace>
```

#### 反馈和调整请求
```bash
# 前端向后端请求调整
qq send backend-api "接口需要调整：
- 问题描述：{具体问题}
- 期望调整：{调整要求}
- 优先级：{紧急程度}

请及时处理，谢谢！"

# 后端调整完成后通知前端
workflow-engine complete backend_feedback simple_dev "接口调整完成"
# 自动执行: qq send frontend-web "🔄 接口已根据反馈调整完成！..."
```

### 工作流程检查清单

在执行任何任务时，必须检查：

#### 1. 获取当前 Workflow 状态
```bash
# 查看当前workflow配置和角色分配
qq workflow dag show

# 查看当前任务状态和实例映射
workflow-engine status
```

#### 2. 确认任务执行条件
- [ ] 当前任务是否符合 workflow 中的角色定义
- [ ] 前置依赖任务是否已完成
- [ ] 所需工具和权限是否具备
- [ ] 交付物要求是否明确

#### 3. 任务完成后的协作流程
- [ ] 使用 `workflow-engine complete` 自动触发下一步
- [ ] 确认通知消息已发送给正确的角色实例
- [ ] 检查是否需要等待反馈或审批
- [ ] 记录任务完成状态和交付物

#### 4. 异常情况处理
- [ ] 如遇到阻塞，及时通知相关角色
- [ ] 如需要反馈调整，使用标准消息格式
- [ ] 如发现workflow配置问题，及时报告

#### 5. 质量保证
- [ ] 交付物是否符合 deliverables 要求
- [ ] 是否通过了必要的测试和验证
- [ ] 文档和说明是否完整
- [ ] 下一个角色是否能够顺利接手

---

**重要**: 这个 workflow 配置是强制性的，必须严格遵循。使用以下命令获取最新配置：

```bash
# 获取当前workflow配置
qq workflow show

# 查看DAG结构和任务流程  
qq workflow dag show

# 检查当前状态和角色映射
workflow-engine status
```

任何偏离 workflow 的行为都可能影响团队协作效率。优先使用 `workflow-engine complete` 进行任务完成和自动通知，必要时使用 `qq send` 进行手动协作。

