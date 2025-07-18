"""
Main views for Q Chat Manager
"""
from flask import Blueprint, render_template, request

from app.services.instance_manager import instance_manager
from app.services.chat_manager import chat_manager

bp = Blueprint('main', __name__)

@bp.route('/')
def index():
    """主页面"""
    instances = instance_manager.get_instances()
    chat_history = chat_manager.get_chat_history(limit=50)
    
    return render_template('chat_manager.html', 
                         instances=instances, 
                         chat_history=chat_history)

@bp.route('/health')
def health():
    """健康检查"""
    return {'status': 'ok', 'instances': len(instance_manager.instances)}
