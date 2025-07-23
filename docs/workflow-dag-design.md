# cliExtra Workflow DAG 设计方案

## 设计目标

1. **支持 DAG (有向无环图) 编辑** - 可视化工作流程设计
2. **兼容现有命令行功能** - 无缝集成到现有 cliExtra 系统
3. **支持复杂协作场景** - 多角色、多步骤、条件分支
4. **AI 友好** - 结构化数据便于 AI 理解和自动化

## 新的数据结构设计

### 1. 核心结构 (workflow.json)

```json
{
  "version": "2.0",
  "metadata": {
    "name": "项目开发流程",
    "description": "前后端协作开发工作流",
    "namespace": "development",
    "created_at": "2025-01-20T10:00:00Z",
    "updated_at": "2025-01-20T10:00:00Z"
  },
  "roles": {
    "frontend": {
      "name": "前端工程师",
      "description": "负责前端开发和UI实现",
      "tools": ["git", "npm", "webpack"],
      "responsibilities": ["UI开发", "前端逻辑", "用户体验"]
    },
    "backend": {
      "name": "后端工程师", 
      "description": "负责API开发和业务逻辑",
      "tools": ["git", "docker", "database"],
      "responsibilities": ["API开发", "数据库设计", "业务逻辑"]
    }
  },
  "nodes": {
    "start": {
      "id": "start",
      "type": "start",
      "title": "项目开始",
      "description": "项目启动节点"
    },
    "requirement_analysis": {
      "id": "requirement_analysis",
      "type": "task",
      "title": "需求分析",
      "description": "分析项目需求和技术方案",
      "owner": "backend",
      "estimated_time": "2h",
      "deliverables": ["需求文档", "技术方案"],
      "tools_required": ["文档工具"]
    },
    "api_design": {
      "id": "api_design", 
      "type": "task",
      "title": "API设计",
      "description": "设计RESTful API接口",
      "owner": "backend",
      "estimated_time": "4h",
      "deliverables": ["API文档", "接口规范"],
      "dependencies": ["requirement_analysis"]
    },
    "ui_design": {
      "id": "ui_design",
      "type": "task", 
      "title": "UI设计",
      "description": "设计用户界面和交互",
      "owner": "frontend",
      "estimated_time": "6h",
      "deliverables": ["UI设计稿", "交互原型"],
      "dependencies": ["requirement_analysis"]
    },
    "parallel_dev": {
      "id": "parallel_dev",
      "type": "parallel",
      "title": "并行开发",
      "description": "前后端并行开发",
      "branches": ["backend_dev", "frontend_dev"]
    },
    "backend_dev": {
      "id": "backend_dev",
      "type": "task",
      "title": "后端开发",
      "description": "实现API和业务逻辑",
      "owner": "backend", 
      "estimated_time": "16h",
      "deliverables": ["API实现", "单元测试"],
      "dependencies": ["api_design"]
    },
    "frontend_dev": {
      "id": "frontend_dev",
      "type": "task",
      "title": "前端开发", 
      "description": "实现用户界面和前端逻辑",
      "owner": "frontend",
      "estimated_time": "12h", 
      "deliverables": ["前端页面", "前端测试"],
      "dependencies": ["ui_design"]
    },
    "integration": {
      "id": "integration",
      "type": "task",
      "title": "集成测试",
      "description": "前后端集成和联调",
      "owner": ["frontend", "backend"],
      "estimated_time": "4h",
      "deliverables": ["集成测试报告"],
      "dependencies": ["backend_dev", "frontend_dev"]
    },
    "end": {
      "id": "end",
      "type": "end", 
      "title": "项目完成",
      "description": "项目交付完成"
    }
  },
  "edges": [
    {"from": "start", "to": "requirement_analysis"},
    {"from": "requirement_analysis", "to": "api_design"},
    {"from": "requirement_analysis", "to": "ui_design"},
    {"from": "api_design", "to": "parallel_dev"},
    {"from": "ui_design", "to": "parallel_dev"},
    {"from": "parallel_dev", "to": "backend_dev"},
    {"from": "parallel_dev", "to": "frontend_dev"},
    {"from": "backend_dev", "to": "integration"},
    {"from": "frontend_dev", "to": "integration"},
    {"from": "integration", "to": "end"}
  ],
  "collaboration_rules": {
    "auto_notify": {
      "task_complete": {
        "enabled": true,
        "template": "任务完成通知：{task_title} 已完成，交付物：{deliverables}，下一步：{next_tasks}"
      },
      "dependency_ready": {
        "enabled": true,
        "template": "依赖就绪通知：{task_title} 的前置条件已满足，可以开始执行"
      }
    },
    "escalation": {
      "overdue_threshold": "24h",
      "escalation_template": "任务超时提醒：{task_title} 已超过预期时间 {overdue_time}"
    }
  },
  "state": {
    "current_nodes": ["start"],
    "completed_nodes": [],
    "active_tasks": {},
    "task_history": []
  }
}
```

### 2. 节点类型定义

- **start**: 开始节点
- **end**: 结束节点  
- **task**: 任务节点（单个角色执行）
- **parallel**: 并行分支节点
- **merge**: 合并节点
- **condition**: 条件判断节点
- **approval**: 审批节点

### 3. 状态管理

```json
{
  "task_states": {
    "pending": "等待开始",
    "in_progress": "进行中", 
    "completed": "已完成",
    "blocked": "被阻塞",
    "failed": "失败"
  }
}
```

## 命令行接口设计

### 基础命令

```bash
# 查看 workflow
qq workflow show [namespace]
qq workflow list
qq workflow status [namespace]

# 编辑 workflow  
qq workflow init [namespace]
qq workflow edit [namespace]
qq workflow validate [namespace]

# 执行控制
qq workflow start [namespace] [node_id]
qq workflow complete <task_id> [deliverables]
qq workflow block <task_id> [reason]
qq workflow resume <task_id>

# DAG 操作
qq workflow dag show [namespace]
qq workflow dag export [namespace] [format]
qq workflow dag import [namespace] [file]
```

### 高级命令

```bash
# 任务管理
qq workflow task list [namespace]
qq workflow task assign <task_id> <role>
qq workflow task progress <task_id> <percentage>

# 协作功能
qq workflow notify <task_id> <message>
qq workflow escalate <task_id>
qq workflow dependencies <task_id>
```

## 与现有功能的集成

1. **实例管理集成** - workflow 状态与实例状态同步
2. **角色系统集成** - workflow 角色与 cliExtra 角色预设对应
3. **通知系统集成** - 使用现有的 send/broadcast 功能
4. **Namespace 集成** - workflow 配置存储在对应 namespace 目录

## 下一步实现计划

1. **第一阶段**: 基础数据结构和存储
2. **第二阶段**: 命令行接口实现
3. **第三阶段**: DAG 可视化和编辑
4. **第四阶段**: 自动化执行和通知
5. **第五阶段**: Web 界面集成
