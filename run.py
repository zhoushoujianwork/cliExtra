#!/usr/bin/env python3
"""
Q Chat Manager - 主应用入口
"""
import os
from app import create_app, socketio
from app.utils.logger import setup_logging

# 获取配置环境
config_name = os.environ.get('FLASK_ENV', 'development')

# 创建应用
app = create_app()

# 设置日志
setup_logging(app)

if __name__ == '__main__':
    # 开发环境使用socketio.run，生产环境使用gunicorn
    socketio.run(
        app, 
        host='0.0.0.0', 
        port=5001, 
        debug=True,
        allow_unsafe_werkzeug=True
    )
