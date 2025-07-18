"""
Logging configuration
"""
import logging
import os
from logging.handlers import RotatingFileHandler

def setup_logging(app):
    """设置日志配置"""
    if not app.debug:
        # 创建logs目录
        if not os.path.exists('logs'):
            os.mkdir('logs')
        
        # 文件日志处理器
        file_handler = RotatingFileHandler(
            'logs/app.log', 
            maxBytes=10240000, 
            backupCount=10
        )
        file_handler.setFormatter(logging.Formatter(
            '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
        ))
        file_handler.setLevel(logging.INFO)
        app.logger.addHandler(file_handler)
        
        app.logger.setLevel(logging.INFO)
        app.logger.info('Q Chat Manager startup')
    
    # 控制台日志
    if not app.logger.handlers:
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        ))
        app.logger.addHandler(console_handler)
        app.logger.setLevel(logging.DEBUG if app.debug else logging.INFO)
