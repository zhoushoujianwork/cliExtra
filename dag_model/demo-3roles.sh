#!/bin/bash

# demo-3roles.sh - 三角色协作演示脚本

echo "🚀 三角色协作开发流程演示"
echo "================================"
echo ""

# 1. 初始化workflow
echo "📋 1. 初始化workflow配置"
echo "qq workflow init simple_dev"
echo ""

# 2. 导入三角色配置
echo "📋 2. 导入三角色协作配置"
echo "cp examples/simple-3roles-workflow.json ~/.../namespaces/simple_dev/workflow.json"
echo ""

# 3. 启动三个角色实例
echo "👥 3. 启动三个角色实例"
echo "qq start --name backend-api --role backend --namespace simple_dev"
echo "qq start --name frontend-web --role frontend --namespace simple_dev" 
echo "qq start --name devops-deploy --role devops --namespace simple_dev"
echo ""

# 4. 查看workflow状态
echo "📊 4. 查看workflow状态"
echo "workflow-engine status simple_dev"
echo ""

# 5. 模拟后端完成开发
echo "✅ 5. 后端工程师完成接口开发"
echo "workflow-engine complete backend_dev simple_dev 'API接口,接口文档,测试数据'"
echo ""
echo "预期结果: 自动发送通知给前端工程师"
echo "实际命令: qq send frontend-web '🚀 后端接口开发完成！...'"
echo ""

# 6. 模拟前端集成
echo "🔄 6. 前端工程师集成测试"
echo "# 如果接口满足需求:"
echo "workflow-engine complete frontend_dev simple_dev '前端页面,接口集成,功能测试'"
echo ""
echo "# 如果需要后端调整:"
echo "qq send backend-api '接口需要调整：参数格式不对，请修改...'"
echo ""

# 7. 模拟运维部署
echo "🚀 7. 运维工程师部署"
echo "workflow-engine complete deployment simple_dev '部署完成,环境验证,监控配置'"
echo ""
echo "预期结果: 广播通知所有人部署完成"
echo ""

echo "💡 关键特性:"
echo "- 自动触发: 任务完成后自动通知下一个角色"
echo "- 反馈循环: 前端可以要求后端调整"
echo "- 实例匹配: 根据名称模式自动找到对应实例"
echo "- 消息模板: 标准化的协作消息格式"
