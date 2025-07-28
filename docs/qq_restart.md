
## 总结

我已经成功将 auto-recovery 功能集成到 qq eg 守护进程中，实现了类似 k8s pod 的自动重启机制。主要功能包括：

### 🔄 核心特性
1. 智能故障检测: 自动检测 tmux 会话异常退出、Q chat 进程崩溃等故障
2. 重启策略管理: 支持 Always、OnFailure、Never 三种重启策略
3. 指数退避算法: 5s → 10s → 20s → ... → 300s 的重启延迟，防止无限重启
4. 失败原因记录: 详细记录失败原因（TmuxSessionDied、QChatCrashed、SystemError 等）
5. 重启次数限制: 最大重启次数限制（10次）防止资源浪费
6. 完整状态记录: JSON 格式记录重启历史和统计信息

### 📋 实现的文件
1. cliExtra-restart-manager.sh - 核心重启逻辑和记录管理
2. cliExtra-engine-daemon.sh - 集成自动重启检查到监控守护进程
3. cliExtra-eg.sh - 扩展命令行管理功能
4. 生命周期集成 - 在启动、停止、清理脚本中集成重启记录管理

### 🎯 用户价值
• **高可用性**: 自动恢复异常退出的实例，确保服务连续性
• **智能管理**: 基于失败原因和重启策略的智能重启决策
• **可观测性**: 完整的重启历史和统计信息，便于问题诊断
• **资源保护**: 指数退避和次数限制防止无限重启
• **用户友好**: 集成到现有的 qq eg 命令，使用简单

### 💻 使用方法
bash
# 启动监控守护进程（包含自动重启）
qq eg start

# 查看重启统计
qq eg restart-stats
qq eg restart-stats <instance_id>

# 设置重启策略
qq eg restart-config <instance_id> Always     # 总是重启（默认）
qq eg restart-config <instance_id> OnFailure  # 仅在失败时重启
qq eg restart-config <instance_id> Never      # 从不重启

# 查看监控日志（包含重启信息）
qq eg logs

# 清理过期重启记录
qq eg restart-cleanup