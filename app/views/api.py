"""
API endpoints for Q Chat Manager
"""
from flask import Blueprint, request, jsonify
import logging

from app.services.instance_manager import instance_manager
from app.services.chat_manager import chat_manager

bp = Blueprint('api', __name__)
logger = logging.getLogger(__name__)

@bp.route('/instances', methods=['GET'])
def get_instances():
    """获取所有实例"""
    try:
        instances = instance_manager.get_instances()
        return jsonify({'success': True, 'instances': instances})
    except Exception as e:
        logger.error(f"获取实例列表失败: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@bp.route('/start/<instance_id>', methods=['POST'])
def start_instance(instance_id):
    """启动实例"""
    try:
        result = instance_manager.create_instance(instance_id)
        if result['success']:
            chat_manager.add_system_log(f'实例 {instance_id} 启动成功')
        else:
            chat_manager.add_system_log(f'实例 {instance_id} 启动失败: {result["error"]}')
        return jsonify(result)
    except Exception as e:
        logger.error(f"启动实例 {instance_id} 失败: {str(e)}")
        error_msg = f'启动实例失败: {str(e)}'
        chat_manager.add_system_log(error_msg)
        return jsonify({'success': False, 'error': error_msg}), 500

@bp.route('/stop/<instance_id>', methods=['POST'])
def stop_instance(instance_id):
    """停止实例"""
    try:
        result = instance_manager.stop_instance(instance_id)
        if result['success']:
            chat_manager.add_system_log(f'实例 {instance_id} 已停止')
        else:
            chat_manager.add_system_log(f'停止实例 {instance_id} 失败: {result["error"]}')
        return jsonify(result)
    except Exception as e:
        logger.error(f"停止实例 {instance_id} 失败: {str(e)}")
        error_msg = f'停止实例失败: {str(e)}'
        chat_manager.add_system_log(error_msg)
        return jsonify({'success': False, 'error': error_msg}), 500

@bp.route('/send', methods=['POST'])
def send_message():
    """发送消息到实例"""
    try:
        data = request.get_json()
        instance_id = data.get('instance_id')
        message = data.get('message')
        
        if not instance_id or not message:
            return jsonify({'success': False, 'error': '缺少必要参数'}), 400
        
        result = instance_manager.send_message(instance_id, message)
        
        if result['success']:
            # 记录用户消息到聊天历史
            chat_manager.add_chat_message('user', message, instance_id)
        else:
            chat_manager.add_system_log(f'向实例 {instance_id} 发送消息失败: {result["error"]}')
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"发送消息失败: {str(e)}")
        error_msg = f'发送消息失败: {str(e)}'
        chat_manager.add_system_log(error_msg)
        return jsonify({'success': False, 'error': error_msg}), 500

@bp.route('/clean', methods=['POST'])
def clean_all():
    """清理所有实例"""
    try:
        result = instance_manager.cleanup_all()
        chat_manager.add_system_log(result['message'])
        return jsonify(result)
    except Exception as e:
        logger.error(f"清理实例失败: {str(e)}")
        error_msg = f'清理实例失败: {str(e)}'
        chat_manager.add_system_log(error_msg)
        return jsonify({'success': False, 'error': error_msg}), 500

@bp.route('/chat/history', methods=['GET'])
def get_chat_history():
    """获取聊天历史"""
    try:
        limit = request.args.get('limit', type=int)
        history = chat_manager.get_chat_history(limit=limit)
        return jsonify({'success': True, 'history': history})
    except Exception as e:
        logger.error(f"获取聊天历史失败: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@bp.route('/logs/system', methods=['GET'])
def get_system_logs():
    """获取系统日志"""
    try:
        limit = request.args.get('limit', type=int)
        logs = chat_manager.get_system_logs(limit=limit)
        return jsonify({'success': True, 'logs': logs})
    except Exception as e:
        logger.error(f"获取系统日志失败: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@bp.route('/chat/clear', methods=['POST'])
def clear_chat():
    """清空聊天历史"""
    try:
        chat_manager.clear_chat_history()
        chat_manager.add_system_log('聊天历史已清空')
        return jsonify({'success': True, 'message': '聊天历史已清空'})
    except Exception as e:
        logger.error(f"清空聊天历史失败: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@bp.route('/logs/clear', methods=['POST'])
def clear_logs():
    """清空系统日志"""
    try:
        chat_manager.clear_system_logs()
        chat_manager.add_system_log('系统日志已清空')
        return jsonify({'success': True, 'message': '系统日志已清空'})
    except Exception as e:
        logger.error(f"清空系统日志失败: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500
