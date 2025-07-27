# 实时状态同步测试指南

## 🎯 测试目标

验证状态文件变更能够通过WebSocket实时推送到前端界面，实现真正的实时状态同步。

## 📁 测试文件说明

### 1. 自动化测试脚本

- **`test_realtime_status_sync.sh`** - 完整的自动化测试套件
  - 创建状态文件
  - 批量状态更新
  - 随机状态变更模拟
  - 高频状态变更测试
  - 并发状态更新测试

- **`demo_status_updates.sh`** - 演示脚本
  - 模拟真实的工作流程
  - 逐步激活服务
  - 负载变化模拟
  - 系统关闭流程

### 2. 交互式测试工具

- **`interactive_status_test.sh`** - 交互式菜单工具
  - 手动创建/更新状态文件
  - 实时查看状态变化
  - 批量操作功能
  - 清理测试数据

- **`quick_status_test.sh`** - 快速命令行工具
  ```bash
  ./quick_status_test.sh create test-instance 1
  ./quick_status_test.sh update test-instance 0
  ./quick_status_test.sh list
  ./quick_status_test.sh cleanup
  ```

### 3. 监控工具

- **`monitor_status_changes.sh`** - 实时监控状态文件变化
  ```bash
  ./monitor_status_changes.sh -n default -i 1
  ```

- **`continuous_status_test.sh`** - 连续状态更新测试
  - 持续随机更新状态
  - 测试WebSocket推送响应性

## 🧪 测试步骤

### 步骤1: 基础功能测试

```bash
# 1. 创建测试状态文件
echo "0" > "/Users/mikas/Library/Application Support/cliExtra/namespaces/default/status/test-1.status"
echo "1" > "/Users/mikas/Library/Application Support/cliExtra/namespaces/default/status/test-2.status"

# 2. 观察Web界面是否显示新实例

# 3. 更新状态文件
echo "1" > "/Users/mikas/Library/Application Support/cliExtra/namespaces/default/status/test-1.status"
echo "0" > "/Users/mikas/Library/Application Support/cliExtra/namespaces/default/status/test-2.status"

# 4. 观察Web界面状态是否实时更新
```

### 步骤2: 批量测试

```bash
# 运行演示脚本
./demo_status_updates.sh

# 观察Web界面的实时变化
```

### 步骤3: 高频测试

```bash
# 启动连续状态更新
./continuous_status_test.sh

# 观察Web界面是否能跟上高频更新
```

### 步骤4: 监控测试

```bash
# 在一个终端启动监控
./monitor_status_changes.sh

# 在另一个终端进行状态更新
./quick_status_test.sh batch-create 5
./quick_status_test.sh batch-update
```

## 📊 测试验证点

### 1. 实时性验证
- [ ] 状态文件创建后1秒内Web界面显示新实例
- [ ] 状态文件更新后1秒内Web界面状态变化
- [ ] 状态文件删除后1秒内Web界面移除实例

### 2. 准确性验证
- [ ] idle状态(0)正确显示为空闲
- [ ] busy状态(1)正确显示为忙碌
- [ ] 实例ID正确显示
- [ ] namespace正确分类

### 3. 稳定性验证
- [ ] 高频状态更新不丢失
- [ ] 并发状态更新正确处理
- [ ] 长时间运行无内存泄漏

### 4. 防抖机制验证
- [ ] 快速连续更新被正确防抖
- [ ] 最终状态正确反映
- [ ] 不会产生过多WebSocket消息

## 🔧 状态文件位置

```
~/Library/Application Support/cliExtra/namespaces/
├── default/
│   └── status/
│       ├── instance1.status
│       ├── instance2.status
│       └── ...
├── q_cli/
│   └── status/
│       └── ...
└── frontend/
    └── status/
        └── ...
```

## 🎮 快速测试命令

```bash
# 创建测试实例
echo "0" > "/Users/mikas/Library/Application Support/cliExtra/namespaces/default/status/quick-test.status"

# 切换状态
echo "1" > "/Users/mikas/Library/Application Support/cliExtra/namespaces/default/status/quick-test.status"
echo "0" > "/Users/mikas/Library/Application Support/cliExtra/namespaces/default/status/quick-test.status"

# 删除测试实例
rm "/Users/mikas/Library/Application Support/cliExtra/namespaces/default/status/quick-test.status"
```

## 🧹 清理测试数据

```bash
# 清理所有测试状态文件
rm -f "/Users/mikas/Library/Application Support/cliExtra/namespaces/default/status/test-"*.status
rm -f "/Users/mikas/Library/Application Support/cliExtra/namespaces/default/status/demo-"*.status
rm -f "/Users/mikas/Library/Application Support/cliExtra/namespaces/default/status/websocket-"*.status
rm -f "/Users/mikas/Library/Application Support/cliExtra/namespaces/default/status/batch-test-"*.status
rm -f "/Users/mikas/Library/Application Support/cliExtra/namespaces/default/status/realtime-test-"*.status
```

## 📝 测试报告模板

测试完成后，请记录以下信息：

- **实时性**: 状态变更到Web界面显示的延迟时间
- **准确性**: 状态显示是否正确
- **稳定性**: 长时间测试是否有问题
- **性能**: 高频更新时的表现
- **用户体验**: 界面响应是否流畅

## 🚀 下一步优化建议

基于测试结果，可能的优化方向：

1. **调整防抖时间**: 根据实际响应速度优化
2. **批量处理优化**: 提高大量状态更新的处理效率
3. **错误处理**: 增强异常情况的处理能力
4. **性能监控**: 添加性能指标监控
