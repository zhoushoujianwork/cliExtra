"""
WebSocket handlers for real-time communication
"""
from flask import Blueprint
from flask_socketio import emit, join_room, leave_room
import threading
import time
import logging

from app import socketio
from app.services.instance_manager import instance_manager
from app.services.chat_manager import chat_manager

bp = Blueprint('websocket', __name__)
logger = logging.getLogger(__name__)

# 存储客户端监控的实例
client_monitors = {}

@socketio.on('connect')
def handle_connect():
    """客户端连接"""
    logger.info('客户端已连接')
    emit('connected', {'message': 'WebSocket连接成功'})

@socketio.on('disconnect')
def handle_disconnect():
    """客户端断开连接"""
    logger.info('客户端已断开连接')

@socketio.on('join_monitoring')
def handle_join_monitoring(data):
    """加入实例监控"""
    instance_id = data.get('instance_id')
    if not instance_id:
        emit('error', {'message': '缺少实例ID'})
        return
    
    # 加入房间
    join_room(f'instance_{instance_id}')
    
    # 启动监控线程
    if instance_id not in client_monitors:
        client_monitors[instance_id] = True
        thread = threading.Thread(
            target=monitor_instance_output, 
            args=(instance_id,), 
            daemon=True
        )
        thread.start()
        logger.info(f'开始监控实例 {instance_id}')
    
    emit('monitoring_started', {'instance_id': instance_id})

@socketio.on('leave_monitoring')
def handle_leave_monitoring(data):
    """离开实例监控"""
    instance_id = data.get('instance_id')
    if not instance_id:
        emit('error', {'message': '缺少实例ID'})
        return
    
    # 离开房间
    leave_room(f'instance_{instance_id}')
    
    # 停止监控
    if instance_id in client_monitors:
        client_monitors[instance_id] = False
        del client_monitors[instance_id]
        logger.info(f'停止监控实例 {instance_id}')
    
    emit('monitoring_stopped', {'instance_id': instance_id})

def monitor_instance_output(instance_id):
    """监控实例输出"""
    while client_monitors.get(instance_id, False):
        try:
            instance = instance_manager.get_instance(instance_id)
            if not instance or not instance.is_running():
                time.sleep(1)
                continue
            
            # 获取实例输出
            outputs = instance_manager.get_instance_output(instance_id)
            
            for output in outputs:
                if output.get('is_complete', False):
                    # 完整回复，发送到聊天历史
                    chat_manager.add_chat_message(
                        sender=f'实例{instance_id}',
                        message=output.get('raw_content', output['content']),
                        instance_id=instance_id
                    )
                    
                    # 实时推送给客户端（包含格式化的内容）
                    socketio.emit('instance_complete_response', {
                        'instance_id': instance_id,
                        'content': output['content'],  # 格式化的内容
                        'raw_content': output.get('raw_content', output['content']),  # 原始内容
                        'timestamp': output['timestamp'],
                        'is_markdown': True
                    }, room=f'instance_{instance_id}')
                    
                    # 同时在服务器终端显示格式化内容
                    print(output['content'])
                else:
                    # 部分输出，暂时不处理（等待完整回复）
                    pass
            
            time.sleep(0.5)  # 避免过于频繁的检查
            
        except Exception as e:
            logger.error(f'监控实例 {instance_id} 输出时出错: {str(e)}')
            time.sleep(1)
    
    logger.info(f'实例 {instance_id} 监控线程已停止')

@socketio.on('send_message')
def handle_send_message(data):
    """通过WebSocket发送消息"""
    try:
        instance_ids = data.get('instance_ids', [])
        message = data.get('message', '')
        
        if not instance_ids or not message:
            emit('error', {'message': '缺少必要参数'})
            return
        
        success_count = 0
        errors = []
        
        for instance_id in instance_ids:
            result = instance_manager.send_message(instance_id, message)
            if result['success']:
                success_count += 1
            else:
                errors.append(f'实例{instance_id}: {result["error"]}')
        
        if errors:
            emit('message_result', {
                'success': False,
                'message': f'成功发送到 {success_count} 个实例，失败: {len(errors)}',
                'errors': errors
            })
        else:
            emit('message_result', {
                'success': True,
                'message': f'成功发送到 {success_count} 个实例'
            })
            
    except Exception as e:
        logger.error(f'WebSocket发送消息失败: {str(e)}')
        emit('error', {'message': f'发送消息失败: {str(e)}'})

@socketio.on('get_instances')
def handle_get_instances():
    """获取实例列表"""
    try:
        instances = instance_manager.get_instances()
        emit('instances_list', {'instances': instances})
    except Exception as e:
        logger.error(f'获取实例列表失败: {str(e)}')
        emit('error', {'message': f'获取实例列表失败: {str(e)}'})
