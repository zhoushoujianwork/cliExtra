每次功能完成后记得更新 README.md 文件；

## 2025-07-28 软链接改进和历史实例同步功能

### 🔗 功能实现：软链接替代文件复制
完全重构了 rules 和 tools 的管理方式，从文件复制改为软链接方式，解决了开发过程中修改定义文件无法应用到已创建实例的问题。

#### 核心改进
1. **Rules 同步改进**: 修改 `sync_rules_to_project()` 函数使用软链接
2. **工具安装改进**: 修改 `add_tool_to_project()` 函数使用软链接
3. **软链接管理功能**: 新增完整的软链接检查、修复和转换工具
4. **历史实例同步**: 批量同步所有历史实例到软链接方式

#### 实现的功能
1. **软链接管理命令**:
   - `qq tools check-links` - 检查工具软链接状态
   - `qq tools repair-links` - 修复损坏的软链接
   - `qq tools convert-to-links` - 将普通文件转换为软链接

2. **历史实例同步**:
   - `qq sync-historical` - 批量同步历史实例到软链接方式
   - 成功同步 20 个历史实例，涵盖 6 个 namespace
   - 智能处理普通文件、正常软链接、损坏软链接

3. **技术实现亮点**:
   - 智能文件处理：自动识别并处理已存在的文件/链接
   - 详细状态反馈：提供完整的操作结果和统计信息
   - 错误处理：优雅处理各种异常情况
   - 向后兼容：支持现有普通文件的平滑迁移

#### 用户价值
- **实时更新**: 修改源文件后，所有实例立即获取最新版本
- **统一管理**: 所有定义文件集中在源目录，便于版本控制
- **减少冗余**: 避免多份相同文件的存储
- **一处修改，处处生效**: 修改 rules、roles、tools 后立即在所有项目中生效

#### 测试验证
- ✅ Rules 软链接创建正常
- ✅ 工具软链接创建正常
- ✅ 软链接检查功能正常
- ✅ 实时更新效果验证成功
- ✅ 历史实例同步完成（20/20 成功）

#### 使用示例
```bash
# 启动实例（自动创建软链接）
qq start --name myproject

# 检查软链接状态
qq tools check-links

# 添加新工具（创建软链接）
qq tools add dingtalk

# 修复损坏的链接
qq tools repair-links

# 同步历史实例
qq sync-historical
```

#### 技术优势
- **开发体验改进**: 修改源文件后立即在所有实例中生效
- **维护便利性**: 统一管理，版本一致性保证
- **管理工具完善**: 状态检查、自动修复、平滑迁移
- **批量处理能力**: 多 namespace 支持，智能同步逻辑

#### 向后兼容性
- ✅ 保持现有命令行接口不变
- ✅ 新功能对用户透明
- ✅ 支持现有普通文件的平滑迁移
- ✅ 不影响现有脚本和工作流

## 2025-07-27 qq list 集成重启次数显示功能

### 📊 功能增强：在实例列表中显示重启次数
将重启次数信息集成到 `qq list` 命令中，方便用户查看每个实例的重启情况。

#### 核心特性
1. **表格格式增强**: 在表格输出中添加 `RESTARTS` 列显示重启次数
2. **JSON 格式增强**: 在 JSON 输出中添加 `restart_count` 字段
3. **详细信息增强**: 在单个实例详细信息中显示重启次数
4. **智能获取**: 自动从重启记录文件中读取重启次数，无记录时显示 0

#### 实现的功能
1. **重启次数获取函数**: `get_instance_restart_count()`
   - 从重启记录文件中读取重启次数
   - 支持 jq 和简单文本解析两种方式
   - 无记录时返回 0

2. **表格输出增强**: 
   - 添加 `RESTARTS` 列（宽度 10 字符）
   - 显示每个实例的重启次数
   - 保持原有的列对齐格式

3. **JSON 输出增强**:
   - 在 `get_instance_rich_info()` 中添加重启次数获取
   - 在所有 JSON 输出函数中添加 `restart_count` 字段
   - 保持 JSON 格式的完整性

4. **详细信息增强**:
   - 在 `output_instance_details()` 中添加重启次数显示
   - 格式：`重启次数: X`

#### 技术实现
1. **文件修改**:
   - `bin/cliExtra-list.sh` - 添加重启次数获取和显示逻辑
   - 引入 `cliExtra-restart-manager.sh` 依赖

2. **重启次数获取逻辑**:
   ```bash
   get_instance_restart_count() {
       local instance_id="$1"
       local namespace="$2"
       local record_file=$(get_restart_record_file "$instance_id" "$namespace")
       
       if [[ -f "$record_file" ]]; then
           # 使用 jq 或文本解析获取 restart_count
           restart_count=$(cat "$record_file" | jq -r '.restart_count // 0')
           echo "${restart_count:-0}"
       else
           echo "0"
       fi
   }
   ```

3. **输出格式变更**:
   - 表格格式：`NAME NAMESPACE STATUS SESSION ROLE RESTARTS`
   - JSON 格式：添加 `"restart_count": X` 字段
   - 详细信息：添加 `重启次数: X` 行

#### 用户价值
- **一目了然**: 在实例列表中直接查看重启次数，快速识别问题实例
- **运维监控**: 方便运维人员监控实例稳定性
- **问题诊断**: 重启次数高的实例可能存在问题，需要关注
- **脚本友好**: JSON 格式包含重启次数，便于脚本处理

#### 测试验证
- ✅ 表格格式正确显示重启次数列
- ✅ JSON 格式包含 restart_count 字段
- ✅ 详细信息显示重启次数
- ✅ 无重启记录的实例显示 0
- ✅ 有重启记录的实例显示正确次数
- ✅ 向后兼容性保持

#### 使用示例
```bash
# 表格格式查看重启次数
qq list -A
# 输出包含 RESTARTS 列

# JSON 格式查看重启次数
qq list -A -o json
# 输出包含 "restart_count" 字段

# 查看单个实例重启次数
qq list patsnap-xops_system
# 输出包含 "重启次数: 1"
```

#### 输出示例
**表格格式**:
```
NAME                           NAMESPACE       STATUS          SESSION         ROLE            RESTARTS  
------------------------------ --------------- --------------- --------------- --------------- ----------
patsnap-xops_system            patsnap-xops    idle            q_instance_patsnap-xops_system                 1         
backend-api_1753585861_32737   default         idle            q_instance_backend-api_1753585861_32737 golang          1         
admin-web_1753585814_5405      default         idle            q_instance_admin-web_1753585814_5405 vue             0         
```

**JSON 格式**:
```json
{
  "id": "patsnap-xops_system",
  "status": "idle",
  "namespace": "patsnap-xops",
  "restart_count": 1,
  ...
}
```

#### 向后兼容性
- ✅ 保持现有命令行接口不变
- ✅ 只是增加显示信息，不影响现有功能
- ✅ JSON 格式向前兼容
- ✅ 不影响脚本解析

#### 技术优势
- **统一数据源**: 使用重启管理器的记录文件作为数据源
- **高效获取**: 直接读取 JSON 文件，性能良好
- **容错处理**: 无记录文件时优雅降级为 0
- **格式一致**: 所有输出格式都包含重启次数信息

## 2025-07-27 自动重启功能集成到 qq eg 守护进程

### 🔄 功能集成：类似 k8s pod 的自动重启机制
将 auto-recovery 功能完全集成到 `qq eg` 守护进程中，实现了类似 Kubernetes pod 的自动重启和状态记录功能。

#### 核心特性
1. **智能故障检测**: 自动检测 tmux 会话异常退出、Q chat 进程崩溃等故障
2. **重启策略管理**: 支持 Always、OnFailure、Never 三种重启策略
3. **指数退避算法**: 5s → 10s → 20s → ... → 300s 的重启延迟，防止无限重启
4. **失败原因记录**: 详细记录失败原因（TmuxSessionDied、QChatCrashed、SystemError 等）
5. **重启次数限制**: 最大重启次数限制（10次）防止资源浪费
6. **完整状态记录**: JSON 格式记录重启历史和统计信息

#### 实现的功能
1. **重启管理器**: `cliExtra-restart-manager.sh` - 核心重启逻辑和记录管理
   - `init_restart_record()` - 初始化重启记录
   - `update_restart_record()` - 更新重启记录
   - `detect_failure_reason()` - 检测失败原因
   - `restart_instance()` - 执行实例重启
   - `check_instance_for_restart()` - 检查实例是否需要重启

2. **守护进程集成**: 在 `cliExtra-engine-daemon.sh` 中集成自动重启检查
   - 每30秒检查一次所有实例状态
   - 自动检测异常退出的实例并尝试重启
   - 记录详细的重启日志和统计信息

3. **命令行管理**: 扩展 `qq eg` 命令支持重启管理
   - `qq eg restart-stats` - 查看重启统计
   - `qq eg restart-config <id> <policy>` - 设置重启策略
   - `qq eg restart-cleanup` - 清理过期记录

4. **生命周期集成**: 在实例启动、停止、清理时自动管理重启记录
   - 启动时初始化重启记录
   - 停止时清理重启记录（用户主动操作）
   - 清理时删除重启记录

#### 技术实现
1. **重启记录格式**: JSON 格式存储在 `~/Library/Application Support/cliExtra/namespaces/<namespace>/restart/<instance_id>.restart`
   ```json
   {
     "instance_id": "test-instance",
     "namespace": "default",
     "restart_policy": "Always",
     "restart_count": 3,
     "last_restart_time": "2025-07-27T12:00:00Z",
     "last_failure_reason": "TmuxSessionDied",
     "restart_history": [...]
   }
   ```

2. **失败原因分类**:
   - `TmuxSessionDied`: tmux 会话异常退出
   - `QChatCrashed`: Q chat 进程崩溃
   - `SystemError`: 系统资源不足
   - `UserKilled`: 用户主动杀死进程
   - `Timeout`: 响应超时
   - `Unknown`: 未知原因

3. **重启策略逻辑**:
   - `Always`: 总是重启（默认）
   - `OnFailure`: 仅在非用户主动操作的失败时重启
   - `Never`: 从不自动重启

4. **指数退避算法**: 防止频繁重启消耗系统资源
   ```bash
   delay = base_delay * (multiplier ^ (restart_count - 1))
   max_delay = 300s (5分钟)
   ```

#### 用户价值
- **高可用性**: 自动恢复异常退出的实例，确保服务连续性
- **智能管理**: 基于失败原因和重启策略的智能重启决策
- **可观测性**: 完整的重启历史和统计信息，便于问题诊断
- **资源保护**: 指数退避和次数限制防止无限重启
- **用户友好**: 集成到现有的 `qq eg` 命令，使用简单

#### 测试验证
- ✅ 重启记录初始化和清理功能正常
- ✅ 重启策略配置和应用功能正常
- ✅ 失败原因检测和记录功能正常
- ✅ 指数退避重启延迟功能正常
- ✅ 守护进程集成功能正常
- ✅ 命令行管理功能正常

#### 使用示例
```bash
# 启动监控守护进程（包含自动重启）
qq eg start

# 查看重启统计
qq eg restart-stats
qq eg restart-stats myinstance

# 设置重启策略
qq eg restart-config myinstance Never

# 查看监控日志（包含重启信息）
qq eg logs

# 清理过期重启记录
qq eg restart-cleanup
```

#### 向后兼容性
- ✅ 保持现有 `auto-recovery` 命令可用（标记为已弃用）
- ✅ 新功能完全集成到 `qq eg` 中，使用更统一
- ✅ 不影响现有实例的运行和管理
- ✅ 重启记录格式向前兼容

#### 技术优势
- **统一管理**: 状态监控和自动重启集成在同一个守护进程中
- **高效检测**: 基于时间戳的状态检测 + 定期重启检查
- **智能决策**: 基于失败原因和重启策略的智能重启
- **完整记录**: 类似 k8s 的完整重启历史和统计
- **资源友好**: 指数退避和限制机制防止资源浪费

## 2025-07-27 qq send 状态更新机制完善

### 🔧 功能完善：消息发送状态更新机制
完善了 `qq send` 功能的状态更新机制，确保消息发送成功后立即将目标实例状态文件更新为 busy(值为1)。

#### 核心改进
1. **错误处理增强**: 改进了状态更新失败时的错误提示和反馈
2. **调试模式支持**: 添加了 `CLIEXTRA_DEBUG=true` 环境变量支持，显示详细的状态更新信息
3. **状态验证机制**: 添加了状态验证函数，确保状态更新确实成功
4. **用户体验优化**: 提供更清晰的状态更新反馈信息

#### 实现的功能
1. **状态更新流程**:
   - 消息发送成功后立即调用 `auto_set_busy_on_message`
   - 将目标实例状态文件更新为 1 (busy)
   - 提供成功/失败的明确反馈

2. **错误处理机制**:
   - 状态更新失败时显示警告信息
   - 在调试模式下提供详细的错误诊断信息
   - 包含状态文件路径等调试信息

3. **调试模式功能**:
   - `CLIEXTRA_DEBUG=true` 启用详细调试信息
   - 显示状态文件路径和更新过程
   - 包含状态验证结果

4. **状态验证函数**:
   - `verify_instance_status()` - 验证实例状态是否为期望值
   - 在调试模式下自动验证状态更新结果

#### 技术实现
1. **文件修改**:
   - `bin/cliExtra-send.sh` - 改进状态更新的错误处理和调试信息
   - `bin/cliExtra-status-manager.sh` - 添加状态验证函数和错误信息优化

2. **状态更新机制**:
   ```bash
   # 发送消息后自动更新状态
   auto_set_busy_on_message "$instance_id" "$message" "$namespace"
   
   # 调试模式下验证状态更新
   verify_instance_status "$instance_id" "$STATUS_BUSY" "$namespace"
   ```

3. **调试模式使用**:
   ```bash
   # 启用调试模式发送消息
   CLIEXTRA_DEBUG=true qq send instance_id "消息内容"
   ```

#### 用户价值
- **实时状态反映**: 消息发送后立即更新实例状态，确保状态的实时性
- **可靠性保证**: 通过状态验证确保更新操作的成功
- **问题诊断**: 调试模式帮助快速定位状态更新问题
- **用户体验**: 清晰的反馈信息让用户了解操作结果

#### 测试验证
- ✅ 消息发送后状态正确更新为 busy (1)
- ✅ 错误处理机制正常工作
- ✅ 调试模式显示详细信息
- ✅ 状态验证功能正常
- ✅ 广播功能的状态更新机制也正常工作

#### 使用示例
```bash
# 正常发送消息（自动更新状态）
qq send instance_id "任务消息"
# 输出: ✓ 实例状态已自动设置为忙碌

# 调试模式发送消息
CLIEXTRA_DEBUG=true qq send instance_id "调试消息" --force
# 输出包含详细的调试信息

# 验证状态文件
cat "~/Library/Application Support/cliExtra/namespaces/default/status/instance_id.status"
# 输出: 1
```

#### 向后兼容性
- ✅ 保持现有命令行接口不变
- ✅ 状态更新机制对用户透明
- ✅ 调试模式为可选功能
- ✅ 不影响现有脚本和工作流

## 2025-07-27 qq role apply 功能重构

### 🔄 功能重构：角色应用机制改进
重构了 `qq role apply` 功能，改为通过消息方式发送身份信息并保存角色信息到系统目录。

#### 核心变更
1. **应用方式改变**: 从复制文件到项目目录改为通过消息发送角色定义到运行中的实例
2. **存储位置变更**: 角色信息保存到系统目录 `~/Library/Application Support/cliExtra/namespaces/<namespace>/instances/instance_<id>/roles/`
3. **实例信息更新**: 自动更新实例 info 文件中的 ROLE 和 ROLE_FILE 信息
4. **智能查找**: 不指定实例ID时自动查找当前目录对应的运行实例

#### 实现的功能
1. **角色应用**: `qq role apply <role> [instance_id] [-f]`
   - 支持自动查找当前目录对应的运行实例
   - 通过消息方式发送角色定义到实例
   - 保存角色文件到系统目录
   - 更新实例 info 文件中的角色信息

2. **角色移除**: `qq role remove [instance_id]`
   - 支持自动查找当前目录对应的运行实例
   - 移除系统目录中的角色文件
   - 更新实例 info 文件，移除角色信息
   - 发送角色移除通知到实例

3. **辅助函数**:
   - `find_current_directory_instance()` - 查找当前目录对应的运行实例
   - `get_instance_info()` - 获取实例信息
   - `get_instance_namespace()` - 获取实例的命名空间

#### 技术实现
1. **文件修改**:
   - `bin/cliExtra-role.sh` - 重构 apply_role 和 remove_role 函数
   - 添加辅助函数支持实例查找和信息获取

2. **消息发送机制**:
   - 读取角色文件内容
   - 构建角色应用消息：`请按照以下角色定义来协助我：\n\n[角色内容]\n\n请确认你已理解并将按照以上角色定义来协助我的工作。`
   - 通过 tmux send-keys 发送到实例

3. **系统目录结构**:
   ```
   ~/Library/Application Support/cliExtra/namespaces/<namespace>/instances/instance_<id>/
   ├── roles/
   │   ├── <role>-engineer.md    # 角色定义文件
   │   └── role-boundaries.md    # 通用边界规则
   └── info                      # 实例信息文件（包含ROLE和ROLE_FILE）
   ```

#### 用户价值
- **即时生效**: 角色定义立即发送到AI实例，无需重启
- **持久保存**: 角色信息保存在系统目录，支持实例恢复
- **状态同步**: 实例列表正确显示角色信息
- **智能操作**: 自动查找当前目录对应的实例
- **统一管理**: 角色信息集中在系统目录，便于管理

#### 测试验证
- ✅ 角色应用功能正常，能正确发送角色定义到实例
- ✅ 角色信息正确保存到系统目录和实例 info 文件
- ✅ 实例列表正确显示角色信息
- ✅ 角色移除功能正常，能清理角色文件和更新实例信息
- ✅ 自动查找当前目录实例功能正常
- ✅ 强制模式和确认模式都正常工作

#### 使用示例
```bash
# 启动实例
qq start --name myproject

# 应用角色（自动查找当前目录实例）
qq role apply shell -f

# 验证角色应用
qq list  # 查看实例列表中的角色信息

# 移除角色
qq role remove

# 指定实例应用角色
qq role apply backend myproject -f
```

#### 向后兼容性
- ✅ 保持命令行接口不变
- ✅ 保持角色文件格式不变
- ✅ 新的系统目录结构不影响现有功能
- ✅ 实例列表显示保持一致

## 2025-07-25 身份信息自动注入功能实现

### 🤖 新功能：身份信息自动注入
实现了每次 `qq send` 发送消息时自动注入身份信息的功能，让AI实例能够持续感知自己的身份和角色。

#### 核心设计
1. **身份信息格式**: `你是 ns:namespace 的 xxx工程师`
2. **自动注入机制**: 在每次发送消息前自动添加身份信息
3. **角色映射**: 自动将英文角色名映射为中文工程师称谓

#### 实现的功能
1. **消息发送增强**: `qq send` 自动注入身份信息
   - 格式：`你是 ns:q_cli 的 Shell工程师。原始消息内容`
   - 从实例info文件中获取ROLE和NAMESPACE信息
   - 支持多种角色类型的中文映射

2. **广播功能增强**: `qq broadcast` 也支持身份信息注入
   - 每个接收实例都会收到针对自己身份的消息
   - 显示注入的身份信息便于调试

3. **角色映射系统**: 
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
   - `system-coordinator` → 系统协调员

4. **移除qq info功能**: 
   - 移除了 `qq sender-info` 命令
   - 移除了相关帮助信息
   - 身份信息现在通过每次对话自动提供

#### 技术实现
1. **身份信息获取**: 
   - `get_instance_role_info()` - 从info文件获取角色信息
   - `generate_identity_message()` - 生成格式化的身份信息

2. **消息注入逻辑**:
   - 在 `send_message_to_instance()` 中自动注入身份信息
   - 在 `broadcast_message()` 中为每个实例注入对应身份信息

3. **文件修改**:
   - `bin/cliExtra-send.sh` - 添加身份信息注入逻辑
   - `bin/cliExtra-broadcast.sh` - 添加广播身份信息注入
   - `bin/cliExtra-sender-id.sh` - 添加身份信息生成函数
   - `cliExtra.sh` - 移除sender-info命令处理

#### 用户价值
- **持续身份感知**: AI实例在每次对话中都能明确自己的身份
- **角色一致性**: 确保AI按照指定角色进行响应和协作
- **上下文连续性**: 避免AI在长时间对话中忘记自己的角色定位
- **协作效率**: 接收方能立即了解发送方的专业领域和职责范围

#### 测试验证
- ✅ 单个消息发送的身份信息注入功能正常
- ✅ 广播消息的身份信息注入功能正常
- ✅ 角色映射系统正确工作
- ✅ 移除qq info功能后系统正常运行
- ✅ 身份信息显示清晰，便于调试

#### 使用示例
```bash
# 发送消息时自动注入身份信息
qq send backend-api "API开发完成，请进行前端集成"
# 实际发送: "你是 ns:q_cli 的 后端工程师。API开发完成，请进行前端集成"

# 广播时为每个实例注入对应身份信息
qq broadcast "系统维护通知" --namespace q_cli
# 每个实例收到: "你是 ns:q_cli 的 [对应角色]工程师。系统维护通知"
```

## 2025-07-25 移除 qq init 功能

### 🗑️ 功能移除
移除了 `qq init` 项目初始化功能，简化系统架构。

#### 移除的内容
1. **主脚本**: 移除 `cliExtra.sh` 中的 init 命令处理逻辑
2. **帮助信息**: 移除帮助文档中的 init 相关说明和示例
3. **README.md**: 移除项目初始化章节和相关使用示例
4. **规则文档**: 移除 `.amazonq/rules/cliExtra.md` 中的 init 相关内容

#### 移除原因
- **简化架构**: 专注于核心的实例管理和协作功能
- **减少复杂性**: 避免功能重叠和维护负担
- **用户反馈**: 用户更多使用 start 功能而非 init 功能

#### 影响范围
- ✅ 不影响现有实例的运行
- ✅ 不影响其他核心功能
- ✅ 用户可以直接使用 `qq start` 启动实例
- ✅ 保持向后兼容性

#### 替代方案
用户可以使用以下方式替代原有的 init 功能：
```bash
# 原来的 init 功能
# qq init ./

# 现在使用 start 功能
qq start --name myproject
```

### 📋 清理完成
- ✅ 移除主脚本中的 init 命令处理
- ✅ 移除帮助信息中的 init 相关内容
- ✅ 移除 README.md 中的项目初始化章节
- ✅ 移除规则文档中的 init 相关说明
- ✅ 更新快速上手示例，移除 init 步骤

## 2025-07-24 异常 Namespace 创建问题修复

### 🐛 问题发现
用户报告系统创建了大量异常的 namespace，这些 namespace 名称都是中文消息内容，如：
- "小程序是否支持使用手机蓝牙连接外部设备进行数据交互"
- "任务已完成"
- "消息处理完成"
- "状态管理测试消息 - 验证修复效果"

### 🔍 根本原因分析
通过代码分析发现问题出现在 `cliExtra-start.sh` 中调用 `create_status_file` 函数时：

**错误的调用方式**:
```bash
create_status_file "$instance_id" "$STATUS_IDLE" "$initial_task" "$namespace"
```

**函数期望的参数**:
```bash
create_status_file(instance_id, status, namespace)
```

**实际传递的参数**:
1. `instance_id` ✅
2. `STATUS_IDLE` ✅  
3. `initial_task` ❌ (被当作 namespace)
4. `namespace` ❌ (被忽略)

导致 `initial_task` 变量的值（如中文消息）被当作 namespace 名称，系统自动创建了这些异常目录。

### 🛠️ 解决方案

#### 1. 修复参数传递错误
```bash
# 修复前
create_status_file "$instance_id" "$STATUS_IDLE" "$initial_task" "$namespace"

# 修复后  
create_status_file "$instance_id" "$STATUS_IDLE" "$namespace"
```

#### 2. 加强 Namespace 名称验证
在 `create_status_file` 函数中添加严格的验证：
- **字符验证**: 只允许 `[a-zA-Z0-9_-]`
- **长度验证**: 不超过 32 个字符
- **自动回退**: 无效名称自动使用默认 namespace

#### 3. 增强 Namespace 创建验证
在 `cliExtra-ns.sh` 中加强验证：
- 多重字符检查
- 长度限制检查
- 清晰的错误提示

#### 4. 新增清理工具
创建 `cliExtra-cleanup-invalid-ns.sh` 脚本：
- **预览模式**: `--dry-run` 查看将要清理的目录
- **强制清理**: `--force` 直接删除无效目录
- **智能识别**: 自动识别包含无效字符的 namespace

### 🧪 测试验证
- ✅ 修复参数传递错误，状态文件创建正常
- ✅ 中文 namespace 名称被正确拒绝并回退到默认值
- ✅ 过长 namespace 名称被正确拒绝
- ✅ 清理工具能正确识别和清理异常目录
- ✅ 系统不再创建异常 namespace

### 💡 用户价值
- **系统稳定性**: 防止异常 namespace 的创建
- **目录整洁**: 保持系统目录结构的整洁
- **问题修复**: 提供工具清理已有的异常目录
- **健壮性**: 增强系统对无效输入的处理能力

### 📋 使用方法
```bash
# 预览将要清理的异常 namespace
qq cleanup-invalid-ns --dry-run

# 强制清理所有异常 namespace
qq cleanup-invalid-ns --force

# 查看清理后的状态
qq ns show
```

### 🔧 技术实现
1. **参数修复**: 移除多余的 `initial_task` 参数传递
2. **验证增强**: 使用正则表达式 `^[a-zA-Z0-9_-]+$` 验证名称
3. **长度限制**: 限制 namespace 名称不超过 32 字符
4. **错误处理**: 无效名称自动回退到 `default` namespace
5. **清理工具**: 提供安全的批量清理功能

### 📊 影响范围
- **修复文件**: 
  - `bin/cliExtra-start.sh` - 修复参数传递
  - `bin/cliExtra-status-manager.sh` - 加强验证
  - `bin/cliExtra-ns.sh` - 增强创建验证
  - `cliExtra.sh` - 添加清理命令
- **新增文件**: 
  - `bin/cliExtra-cleanup-invalid-ns.sh` - 清理工具
- **用户体验**: 系统更加稳定，目录结构更加整洁

## 2025-07-24 实例状态管理机制实现

### 🔧 新功能：实例状态管理系统
实现了类似 PID 文件的实例状态标记系统，用于工作流协作和状态检测。

#### 核心设计
1. **状态文件位置**: `~/Library/Application Support/cliExtra/namespaces/<namespace>/status/<instance_id>.status`
2. **状态值定义**: 
   - `idle` - 空闲，可接收新任务
   - `busy` - 忙碌，正在处理任务  
   - `waiting` - 等待用户输入或外部响应
   - `error` - 错误状态，需要人工干预
3. **状态文件格式**: JSON 格式，包含状态、时间戳、任务描述、PID 等信息

#### 实现的功能
1. **状态查看**: `qq status [instance_id] [options]`
   - 支持查看单个实例或所有实例状态
   - 支持 table 和 json 两种输出格式
   - 遵循 namespace 默认行为（默认只显示 default namespace）

2. **状态设置**: `qq status <instance_id> --set <status> [--task <description>]`
   - 支持设置实例状态和任务描述
   - 自动更新最后活动时间

3. **状态文件清理**: `qq status --cleanup [--timeout <minutes>]`
   - 自动清理过期的状态文件
   - 支持自定义超时时间

#### 生命周期集成
- **启动时**: 自动创建状态文件，设为 `idle` 状态
- **停止时**: 自动清理状态文件
- **清理时**: 在实例清理过程中同时清理状态文件

#### 技术实现
1. **状态管理器**: `cliExtra-status-manager.sh` - 核心状态管理函数库
2. **状态命令**: `cliExtra-status.sh` - 完整的状态管理命令实现
3. **生命周期集成**: 在 start、stop、clean 脚本中集成状态文件管理
4. **并发安全**: 使用原子操作和临时文件确保并发安全

#### 用户价值
- **协作感知**: AI 实例可以检查其他实例状态，避免重复工作
- **工作流管理**: 支持基于状态的工作流协作
- **系统监控**: 提供实例运行状态的统一视图
- **自动清理**: 防止状态文件积累，保持系统整洁

#### 测试验证
- ✅ 状态文件创建和更新功能正常
- ✅ 状态查看和设置功能正常
- ✅ 生命周期集成功能正常
- ✅ 清理功能正常
- ✅ JSON 输出格式正确
- ✅ Namespace 过滤功能正常

## 2025-07-24 重构记录

### qq start 功能重构
- **移除**: 移除了 workflow 相关的所有逻辑和配置
- **保留**: 保留了 rules/* 下内容到 .amazonq/rules/ 的同步功能
- **简化**: 简化了启动流程，专注于核心的 rules 同步和工具安装
- **清理**: 移除了 workflow-loader 的调用和相关依赖

### 具体变更
1. **cliExtra-start.sh**: 移除了 workflow-loader 调用，保留 sync_rules_to_project 函数
2. **cliExtra.sh**: 移除了帮助信息中的 workflow 相关命令和示例
3. **README.md**: 移除了 Workflow 智能协作管理章节和相关描述
4. **测试验证**: 确保重构后功能正常，rules 同步和工具安装正常工作

### 重构目标达成
- ✅ 移除 workflow 配置逻辑
- ✅ 保留 rules 同步功能  
- ✅ 保持向后兼容性
- ✅ 简化代码结构

## 2025-07-24 角色定义功能增强

### 新增角色定义管理功能
- **角色定义位置**: 项目目录的 `.cliExtra/roles` 目录
- **自动复制**: 从工程目录 `roles/` 复制角色定义到项目目录
- **Context传入**: 将角色内容作为 `--context` 参数传入 Q CLI
- **自动发现**: 未指定角色时自动发现项目中现有角色定义

### 功能特点
1. **智能角色管理**:
   - 检查项目目录 `.cliExtra/roles` 是否已有角色定义
   - 如果没有，从工程目录复制对应角色文件
   - 支持自动发现现有角色定义

2. **Context集成**:
   - 使用 `q chat --context "角色文件路径"` 启动
   - 角色定义直接作为上下文传入，无需复制到 `.amazonq/rules`
   - 保持角色定义与项目的独立性

3. **实例信息记录**:
   - 在实例 info 文件中记录 `ROLE` 和 `ROLE_FILE` 信息
   - 支持后续查询和管理

### 使用示例
```bash
# 指定角色启动（会复制角色定义到项目）
qq start --role frontend

# 不指定角色启动（自动发现现有角色）
qq start --name myinstance

# 角色定义文件位置
project/.cliExtra/roles/frontend-engineer.md
```

### 测试验证
- ✅ 角色定义复制功能正常
- ✅ 自动发现现有角色功能正常
- ✅ Context传入功能正常
- ✅ 实例信息记录正确
- ✅ 向后兼容性保持

## 2025-07-24 角色加载方式修复

### 问题发现
- Amazon Q CLI 不支持 `--context` 参数
- 原有实现导致启动失败，错误信息：`Error: unexpected argument '--context' found`

### 解决方案
- **修改角色加载方式**: 改为在 Q 启动后通过消息方式发送角色定义
- **优化用户体验**: 角色定义作为初始消息发送，确保 AI 按角色行为
- **保持功能完整性**: 角色定义仍然从 `.cliExtra/roles` 目录加载

### 技术实现
1. **启动流程优化**:
   - 先启动 `q chat --trust-all-tools`
   - 等待 Q 启动完成（3秒）
   - 读取角色文件内容并作为消息发送
   - 构建角色确认消息，确保 AI 理解角色定义

2. **消息格式**:
   ```
   请按照以下角色定义来协助我：
   
   [角色文件内容]
   
   请确认你已理解并将按照以上角色定义来协助我的工作。
   ```

### 测试验证
- ✅ 修复启动失败问题
- ✅ 角色定义正确加载
- ✅ AI 按角色定义行为
- ✅ 实例正常运行
- ✅ 消息发送功能正常

## 2025-07-24 tmux会话启动方式优化

### 问题发现
- 实例启动后没有进入 Q chat 对话页面
- 停留在 shell 提示符状态，`q chat` 命令执行后立即退出
- 原因：先创建空会话再发送命令的方式不稳定

### 解决方案
- **直接启动方式**: 在创建 tmux 会话时直接启动 `q chat --trust-all-tools`
- **简化流程**: 移除中间的命令发送步骤，确保 Q chat 持续运行
- **优化时序**: 调整等待时间和角色加载时机

### 技术实现
1. **启动方式改进**:
   ```bash
   # 之前：先创建会话再发送命令
   tmux new-session -d -s "$session_name" -c "$project_dir"
   tmux send-keys -t "$session_name" "q chat --trust-all-tools" Enter
   
   # 现在：直接启动 Q chat
   tmux new-session -d -s "$session_name" -c "$project_dir" "q chat --trust-all-tools"
   ```

2. **角色加载优化**:
   - Q chat 启动后等待3秒确保完全初始化
   - 通过 `tmux send-keys` 发送角色定义消息
   - 提供清晰的状态反馈

### 测试验证
- ✅ 实例正确进入 Q chat 对话模式
- ✅ 角色定义成功加载并生效
- ✅ AI 按角色进行自我介绍
- ✅ 消息发送和接收功能正常
- ✅ tmux 会话稳定运行

### 用户体验改进
- 启动后直接进入可用状态
- 角色定义自动加载并确认
- 清晰的状态提示和反馈
- 稳定的会话持久化

