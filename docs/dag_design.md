# cliExtra DAG 工作流状态管理设计

## 设计理念

### 核心思想
基于现有的 AI agent 协作消息流，通过钩子机制实现 DAG 工作流的自动状态管理，无需 AI agent 学习额外的 DAG 命令，完全依赖现有的 `send` 和 `broadcast` 协作模式。

### 设计原则
1. **非侵入性**: 不破坏现有协作功能，通过钩子机制集成
2. **自动化**: 基于消息流自动检测和更新 DAG 状态
3. **智能识别**: 通过消息内容和发送者信息智能判断工作流进度
4. **完整追踪**: 记录完整的 DAG 执行历史和消息追踪
5. **向后兼容**: 不影响现有的实例协作和状态管理

## 触发机制

### DAG 启动触发
- **触发条件**: 只有来源为 `system:admin` 的广播消息才能启动 DAG
- **检测逻辑**: 在 `cliExtra-broadcast.sh` 中添加钩子，检测发送者身份
- **工作流匹配**: 基于消息内容和 namespace 匹配对应的工作流文件
- **实例创建**: 自动生成 DAG 实例状态文件，格式为 `dag_{workflow}_{timestamp}.json`

### 节点状态更新触发
- **触发条件**: AI agent 通过 `send` 命令发送任务完成消息
- **检测逻辑**: 在 `cliExtra-send.sh` 中添加钩子，分析消息内容
- **进度判断**: 通过发送者和接收者信息确定 DAG 节点转换
- **自动流转**: 根据工作流定义自动触发下一个节点

## 状态文件设计

### DAG 实例状态文件
```
路径: ~/Library/Application Support/cliExtra/namespaces/{namespace}/dags/dag_{workflow}_{timestamp}.json

结构:
- dag_instance_id: DAG 实例唯一标识
- workflow_file: 关联的工作流定义文件
- namespace: 所属命名空间
- status: running/completed/failed/blocked
- trigger: 触发信息(消息、发送者、时间)
- current_state: 当前活跃/完成/阻塞的节点
- node_execution_history: 节点执行历史记录
- message_tracking: 消息追踪记录
- collaboration_context: 协作上下文和角色分配
```

### 状态转换逻辑
- **pending**: 等待开始
- **in_progress**: 执行中
- **completed**: 已完成
- **blocked**: 被阻塞
- **failed**: 失败

## 消息流集成

### 广播钩子 (cliExtra-broadcast.sh)
1. 检测发送者是否为 `system:admin`
2. 解析消息内容，匹配工作流定义
3. 创建 DAG 实例状态文件
4. 触发第一个工作节点
5. 记录触发信息到追踪系统

### 发送钩子 (cliExtra-send.sh)
1. 检测消息是否为任务完成类型
2. 识别发送者和接收者的角色关系
3. 查找相关的活跃 DAG 实例
4. 更新节点状态为完成
5. 自动触发下一个节点
6. 记录状态变更历史

### 消息内容识别
- **完成标识**: 完成/完结/finished/done/ready/已完成/开发完成/测试完成/部署完成
- **交付标识**: 交付/delivery/deliverable/提交/可以开始/请开始
- **工作流匹配**: 开始/启动/start + 后端/前端/开发/协作等关键词

## 自动化流程

### DAG 启动流程
1. `system:admin` 发起广播 → 触发 DAG 检测
2. 匹配工作流定义 → 创建 DAG 实例
3. 标记 start 节点完成 → 触发第一个工作节点
4. 发送任务分配消息 → AI agent 开始工作

### 节点流转流程
1. AI agent 发送完成消息 → 触发进度检测
2. 识别发送者角色 → 查找对应的 DAG 节点
3. 标记当前节点完成 → 更新 DAG 状态
4. 查找下一个节点 → 发送任务分配消息
5. 记录转换历史 → 更新协作上下文

### 角色映射机制
- 基于实例命名模式匹配角色 (如 `*backend*` → backend 角色)
- 动态学习角色分配关系
- 支持多角色协作和并行任务

## 守护进程设计

### 功能职责
1. **状态监控**: 定期扫描活跃的 DAG 实例
2. **超时检测**: 检查任务执行超时情况
3. **异常处理**: 处理节点失败和阻塞情况
4. **清理维护**: 清理完成的 DAG 实例
5. **性能监控**: 统计 DAG 执行性能数据

### 监控策略
- 每 5 秒扫描一次 DAG 状态
- 检查节点超时阈值
- 自动恢复机制
- 异常告警通知

## 命令接口设计

### 查看命令
```bash
qq dag list [namespace]           # 列出活跃的 DAG 实例
qq dag show <dag_id> [namespace]  # 显示 DAG 实例详情
qq dag history [namespace]        # 显示 DAG 执行历史
```

### 控制命令 (管理员用)
```bash
qq dag kill <dag_id>             # 终止 DAG 实例
qq dag resume <dag_id> <node>    # 恢复阻塞的节点
qq dag reset <dag_id> <node>     # 重置节点状态
```

### 统计命令
```bash
qq dag stats [namespace]         # 显示 DAG 统计信息
qq dag performance [timerange]   # 显示性能分析
```

## 工作流定义集成

### 文件位置
- 工作流定义: `{namespace}/dags/dag_model.json`
- 实例状态: `{namespace}/dags/dag_*.json`
- 执行日志: `{namespace}/logs/dag_*.log`

### 角色映射
- 从工作流定义中读取角色配置
- 动态匹配实例命名模式
- 支持角色别名和多实例分配

### 消息模板
- 自动生成任务分配消息
- 支持自定义消息模板
- 包含 DAG 上下文信息

## 可观测性设计

### 状态追踪
- 完整的节点执行历史
- 消息流追踪记录
- 角色协作时间线
- 性能指标统计

### 可视化支持
- DAG 执行状态图
- 节点依赖关系图
- 消息流向图
- 性能分析图表

### 监控指标
- DAG 完成率
- 节点平均执行时间
- 协作响应时间
- 异常率统计

## 扩展性考虑

### 工作流扩展
- 支持条件分支节点
- 支持并行执行节点
- 支持循环和重试机制
- 支持动态工作流生成

### 集成扩展
- 支持外部系统触发
- 支持 Webhook 通知
- 支持 API 接口调用
- 支持多租户隔离

### 性能优化
- 状态文件压缩存储
- 历史数据归档机制
- 缓存热点数据
- 异步处理机制

## 实现阶段规划

### 第一阶段: 基础框架
- 消息钩子集成
- 状态文件管理
- 基础命令接口

### 第二阶段: 自动化
- 守护进程实现
- 超时和异常处理
- 性能监控

### 第三阶段: 高级功能
- 复杂工作流支持
- 可视化界面
- API 接口

### 第四阶段: 企业功能
- 多租户支持
- 权限管理
- 审计日志
