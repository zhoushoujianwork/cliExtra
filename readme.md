# Q Chat Manager

基于Amazon Q Developer CLI的智能聊天管理平台，支持多实例管理、实时通信和Markdown富文本显示。

## 🌟 功能特性

- 🚀 **多实例管理**: 同时管理多个Q CLI实例
- 💬 **实时聊天**: WebSocket实时通信，支持@符号选择实例
- 📝 **Markdown渲染**: 富文本显示，支持代码高亮和格式化
- 🎨 **美观界面**: 响应式Web界面，系统日志分离显示
- 🔧 **标准架构**: Flask应用工厂模式，模块化设计

## 📋 系统要求

- Python 3.8+
- Amazon Q Developer CLI
- 现代浏览器 (Chrome, Firefox, Safari, Edge)

## 🚀 快速开始

### 1. 克隆项目
```bash
git clone <repository-url>
cd cliExtra
```

### 2. 安装依赖
```bash
# 使用启动脚本（推荐）
./start_new.sh

# 或手动安装
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. 启动应用
```bash
# 使用启动脚本
./start_new.sh

# 或手动启动
python3 run.py
```

### 4. 访问应用
打开浏览器访问: http://localhost:5001

## 📁 项目结构

```
cliExtra/
├── app/                    # 应用主目录
│   ├── models/            # 数据模型
│   ├── services/          # 业务逻辑
│   ├── views/             # 视图控制
│   ├── utils/             # 工具类
│   ├── static/            # 静态资源
│   └── templates/         # 模板文件
├── config/                # 配置管理
├── run.py                # 应用入口
├── requirements.txt      # 依赖包
└── start_new.sh         # 启动脚本
```

## 🎯 使用方法

### 启动Q CLI实例
1. 在左侧面板输入实例ID
2. 点击"启动"按钮
3. 等待实例启动完成

### 发送消息
1. 在消息输入框中输入 `@实例1 你的问题`
2. 按回车发送消息
3. 查看格式化的回复

### 查看系统日志
- 右侧面板显示系统操作日志
- 可以清空日志记录

## 🔧 配置选项

### 环境变量
```bash
export FLASK_ENV=development  # 开发环境
export FLASK_DEBUG=1         # 调试模式
export SECRET_KEY=your-secret-key  # 生产环境密钥
```

### 应用配置
在 `config/config.py` 中修改：
- `MAX_INSTANCES`: 最大实例数量
- `MAX_CHAT_HISTORY`: 聊天历史记录数量
- `Q_CLI_TIMEOUT`: Q CLI超时时间

## 📝 Markdown支持

支持完整的Markdown语法：
- 标题 (H1-H3)
- **粗体** 和 *斜体*
- `行内代码` 和代码块
- 列表和链接
- 语法高亮

## 🔌 API接口

### 实例管理
- `GET /api/instances` - 获取实例列表
- `POST /api/start/<id>` - 启动实例
- `POST /api/stop/<id>` - 停止实例
- `POST /api/clean` - 清理所有实例

### 消息管理
- `POST /api/send` - 发送消息
- `GET /api/chat/history` - 获取聊天历史
- `GET /api/logs/system` - 获取系统日志

## 🧪 开发指南

### 添加新功能
1. **模型**: 在 `app/models/` 中定义数据结构
2. **服务**: 在 `app/services/` 中实现业务逻辑
3. **视图**: 在 `app/views/` 中添加路由
4. **模板**: 在 `app/templates/` 中创建页面

### 运行测试
```bash
# 激活虚拟环境
source venv/bin/activate

# 运行测试
python -m pytest tests/
```

## 🐛 故障排除

### 常见问题

**Q CLI未找到**
```bash
# 确保Q CLI已安装
q --version

# 如果未安装，请参考官方文档安装
```

**端口被占用**
```bash
# 修改 run.py 中的端口号
socketio.run(app, port=5002)
```

**依赖安装失败**
```bash
# 升级pip
pip install --upgrade pip

# 重新安装依赖
pip install -r requirements.txt
```

## 🤝 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🙏 致谢

- [Amazon Q Developer CLI](https://github.com/aws/amazon-q-developer-cli)
- [Flask](https://flask.palletsprojects.com/)
- [Socket.IO](https://socket.io/)
- [Bootstrap](https://getbootstrap.com/)

## 📞 联系方式

如有问题或建议，请创建 Issue 或联系项目维护者。

---

**项目状态**: ✅ 稳定版本  
**最后更新**: 2025-07-18
