"""
Chat Manager Service
"""
import re
from typing import List, Dict, Tuple
from datetime import datetime
from collections import deque

from app.models.instance import ChatMessage
from config.config import Config

class ChatManager:
    """聊天管理器"""
    
    def __init__(self):
        self.config = Config()
        self.chat_history = deque(maxlen=self.config.MAX_CHAT_HISTORY)
        self.system_logs = deque(maxlen=self.config.MAX_SYSTEM_LOGS)
    
    def add_chat_message(self, sender: str, message: str, instance_id: str = None):
        """添加聊天消息"""
        chat_msg = ChatMessage(
            sender=sender,
            message=message,
            timestamp=datetime.now(),
            instance_id=instance_id,
            message_type='chat'
        )
        self.chat_history.append(chat_msg)
    
    def add_system_log(self, message: str):
        """添加系统日志"""
        log_msg = ChatMessage(
            sender='system',
            message=message,
            timestamp=datetime.now(),
            message_type='system'
        )
        self.system_logs.append(log_msg)
    
    def get_chat_history(self, limit: int = None) -> List[Dict]:
        """获取聊天历史"""
        if limit:
            history = list(self.chat_history)[-limit:]
        else:
            history = list(self.chat_history)
        
        return [msg.to_dict() for msg in history]
    
    def get_system_logs(self, limit: int = None) -> List[Dict]:
        """获取系统日志"""
        if limit:
            logs = list(self.system_logs)[-limit:]
        else:
            logs = list(self.system_logs)
        
        return [msg.to_dict() for msg in logs]
    
    def parse_at_mentions(self, message: str) -> Tuple[List[str], str]:
        """解析@提及
        
        Args:
            message: 原始消息，如 "@实例1 @实例2 你好世界"
            
        Returns:
            Tuple[List[str], str]: (实例ID列表, 清理后的消息)
        """
        # 匹配@实例ID的模式
        pattern = r'@实例(\w+)'
        matches = re.findall(pattern, message)
        
        # 移除@提及，获取纯净消息
        clean_message = re.sub(r'@实例\w+\s*', '', message).strip()
        
        return matches, clean_message
    
    def clear_chat_history(self):
        """清空聊天历史"""
        self.chat_history.clear()
    
    def clear_system_logs(self):
        """清空系统日志"""
        self.system_logs.clear()

# 全局聊天管理器
chat_manager = ChatManager()
