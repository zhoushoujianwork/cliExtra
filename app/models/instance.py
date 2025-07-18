"""
Q CLI Instance Model
"""
from dataclasses import dataclass
from datetime import datetime
from typing import Optional, Dict, Any
import subprocess
import threading
import queue
import time

@dataclass
class QInstance:
    """Q CLI实例模型"""
    id: str
    process: Optional[subprocess.Popen] = None
    status: str = 'stopped'  # stopped, starting, running, error
    created_at: datetime = None
    last_activity: datetime = None
    details: str = ''
    output_queue: Optional[queue.Queue] = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now()
        if self.last_activity is None:
            self.last_activity = datetime.now()
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式"""
        return {
            'id': self.id,
            'status': self.status,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'last_activity': self.last_activity.isoformat() if self.last_activity else None,
            'details': self.details,
            'is_running': self.is_running()
        }
    
    def is_running(self) -> bool:
        """检查实例是否正在运行"""
        if not self.process:
            return False
        return self.process.poll() is None
    
    def update_activity(self):
        """更新最后活动时间"""
        self.last_activity = datetime.now()

@dataclass
class ChatMessage:
    """聊天消息模型"""
    sender: str
    message: str
    timestamp: datetime
    instance_id: Optional[str] = None
    message_type: str = 'chat'  # chat, system, error
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now()
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式"""
        return {
            'sender': self.sender,
            'message': self.message,
            'timestamp': self.timestamp.strftime('%Y-%m-%d %H:%M:%S'),
            'instance_id': self.instance_id,
            'message_type': self.message_type
        }
