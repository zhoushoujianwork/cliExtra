"""
Q CLI Instance Manager Service
"""
import subprocess
import threading
import queue
import time
import logging
from typing import Dict, List, Optional
from datetime import datetime

from app.models.instance import QInstance
from config.config import Config

logger = logging.getLogger(__name__)

class InstanceManager:
    """Q CLI实例管理器"""
    
    def __init__(self):
        self.instances: Dict[str, QInstance] = {}
        self.config = Config()
        self._lock = threading.Lock()
    
    def create_instance(self, instance_id: str) -> Dict[str, any]:
        """创建新的Q CLI实例"""
        with self._lock:
            if instance_id in self.instances:
                return {'success': False, 'error': f'实例 {instance_id} 已存在'}
            
            if len(self.instances) >= self.config.MAX_INSTANCES:
                return {'success': False, 'error': f'实例数量已达上限 ({self.config.MAX_INSTANCES})'}
            
            try:
                instance = QInstance(id=instance_id)
                instance.status = 'starting'
                instance.details = '正在启动...'
                
                # 启动Q CLI进程
                process = subprocess.Popen(
                    [self.config.Q_CLI_COMMAND, 'chat'],
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    universal_newlines=True
                )
                
                instance.process = process
                instance.output_queue = queue.Queue()
                instance.status = 'running'
                instance.details = f'PID: {process.pid}'
                
                self.instances[instance_id] = instance
                
                # 启动输出监控线程
                self._start_output_monitor(instance)
                
                logger.info(f"实例 {instance_id} 创建成功，PID: {process.pid}")
                return {'success': True, 'instance': instance.to_dict()}
                
            except Exception as e:
                logger.error(f"创建实例 {instance_id} 失败: {str(e)}")
                return {'success': False, 'error': str(e)}
    
    def stop_instance(self, instance_id: str) -> Dict[str, any]:
        """停止Q CLI实例"""
        with self._lock:
            if instance_id not in self.instances:
                return {'success': False, 'error': f'实例 {instance_id} 不存在'}
            
            instance = self.instances[instance_id]
            
            try:
                if instance.process and instance.is_running():
                    instance.process.terminate()
                    
                    # 等待进程结束
                    try:
                        instance.process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        instance.process.kill()
                        instance.process.wait()
                
                instance.status = 'stopped'
                instance.details = '已停止'
                
                logger.info(f"实例 {instance_id} 已停止")
                return {'success': True}
                
            except Exception as e:
                logger.error(f"停止实例 {instance_id} 失败: {str(e)}")
                return {'success': False, 'error': str(e)}
    
    def send_message(self, instance_id: str, message: str) -> Dict[str, any]:
        """向实例发送消息"""
        if instance_id not in self.instances:
            return {'success': False, 'error': f'实例 {instance_id} 不存在'}
        
        instance = self.instances[instance_id]
        
        if not instance.is_running():
            return {'success': False, 'error': f'实例 {instance_id} 未运行'}
        
        try:
            instance.process.stdin.write(message + '\n')
            instance.process.stdin.flush()
            instance.update_activity()
            
            logger.info(f"向实例 {instance_id} 发送消息: {message}")
            return {'success': True}
            
        except Exception as e:
            logger.error(f"向实例 {instance_id} 发送消息失败: {str(e)}")
            return {'success': False, 'error': str(e)}
    
    def get_instances(self) -> List[Dict[str, any]]:
        """获取所有实例信息"""
        with self._lock:
            return [instance.to_dict() for instance in self.instances.values()]
    
    def get_instance(self, instance_id: str) -> Optional[QInstance]:
        """获取指定实例"""
        return self.instances.get(instance_id)
    
    def cleanup_all(self) -> Dict[str, any]:
        """清理所有实例"""
        with self._lock:
            stopped_count = 0
            errors = []
            
            for instance_id in list(self.instances.keys()):
                result = self.stop_instance(instance_id)
                if result['success']:
                    stopped_count += 1
                else:
                    errors.append(f"{instance_id}: {result['error']}")
            
            # 清空实例字典
            self.instances.clear()
            
            if errors:
                return {
                    'success': False, 
                    'message': f'停止了 {stopped_count} 个实例，但有错误',
                    'errors': errors
                }
            else:
                return {
                    'success': True, 
                    'message': f'成功清理了 {stopped_count} 个实例'
                }
    
    def _start_output_monitor(self, instance: QInstance):
        """启动输出监控线程"""
        def monitor_output():
            try:
                response_buffer = []
                last_output_time = time.time()
                response_timeout = 3.0  # 3秒无输出认为回复完成
                
                while instance.is_running():
                    line = instance.process.stdout.readline()
                    if line:
                        line = line.strip()
                        if line:
                            response_buffer.append(line)
                            last_output_time = time.time()
                            instance.update_activity()
                    else:
                        # 检查是否回复完成
                        if response_buffer and (time.time() - last_output_time) > response_timeout:
                            # 合并完整回复
                            complete_response = '\n'.join(response_buffer)
                            
                            # 格式化为markdown并输出到终端
                            formatted_response = self._format_markdown_for_terminal(complete_response)
                            
                            # 放入队列供WebSocket推送
                            instance.output_queue.put({
                                'content': formatted_response,
                                'raw_content': complete_response,
                                'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                                'is_complete': True
                            })
                            
                            # 清空缓冲区
                            response_buffer.clear()
                        
                        time.sleep(0.1)
            except Exception as e:
                logger.error(f"实例 {instance.id} 输出监控错误: {str(e)}")
                instance.status = 'error'
                instance.details = f'监控错误: {str(e)}'
        
        thread = threading.Thread(target=monitor_output, daemon=True)
        thread.start()
    
    def _format_markdown_for_terminal(self, content: str) -> str:
        """将markdown内容格式化为终端富文本显示"""
        import re
        
        # ANSI颜色代码
        COLORS = {
            'reset': '\033[0m',
            'bold': '\033[1m',
            'italic': '\033[3m',
            'underline': '\033[4m',
            'red': '\033[31m',
            'green': '\033[32m',
            'yellow': '\033[33m',
            'blue': '\033[34m',
            'magenta': '\033[35m',
            'cyan': '\033[36m',
            'white': '\033[37m',
            'bg_black': '\033[40m',
            'bg_gray': '\033[100m'
        }
        
        formatted = content
        
        # 处理代码块
        def format_code_block(match):
            lang = match.group(1) or ''
            code = match.group(2)
            return f"\n{COLORS['bg_gray']}{COLORS['white']} {lang} {COLORS['reset']}\n{COLORS['cyan']}{code}{COLORS['reset']}\n"
        
        formatted = re.sub(r'```(\w+)?\n(.*?)\n```', format_code_block, formatted, flags=re.DOTALL)
        
        # 处理行内代码
        formatted = re.sub(r'`([^`]+)`', f"{COLORS['bg_gray']}{COLORS['white']} \\1 {COLORS['reset']}", formatted)
        
        # 处理标题
        formatted = re.sub(r'^### (.*?)$', f"{COLORS['yellow']}{COLORS['bold']}### \\1{COLORS['reset']}", formatted, flags=re.MULTILINE)
        formatted = re.sub(r'^## (.*?)$', f"{COLORS['green']}{COLORS['bold']}## \\1{COLORS['reset']}", formatted, flags=re.MULTILINE)
        formatted = re.sub(r'^# (.*?)$', f"{COLORS['blue']}{COLORS['bold']}# \\1{COLORS['reset']}", formatted, flags=re.MULTILINE)
        
        # 处理粗体
        formatted = re.sub(r'\*\*(.*?)\*\*', f"{COLORS['bold']}\\1{COLORS['reset']}", formatted)
        
        # 处理斜体
        formatted = re.sub(r'\*(.*?)\*', f"{COLORS['italic']}\\1{COLORS['reset']}", formatted)
        
        # 处理列表
        formatted = re.sub(r'^- (.*?)$', f"{COLORS['cyan']}• {COLORS['reset']}\\1", formatted, flags=re.MULTILINE)
        formatted = re.sub(r'^\d+\. (.*?)$', f"{COLORS['cyan']}\\g<0>{COLORS['reset']}", formatted, flags=re.MULTILINE)
        
        # 处理链接
        formatted = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', f"{COLORS['blue']}{COLORS['underline']}\\1{COLORS['reset']} ({COLORS['cyan']}\\2{COLORS['reset']})", formatted)
        
        # 添加边框和标题
        lines = formatted.split('\n')
        max_width = max(len(line.encode('utf-8')) for line in lines) if lines else 50
        border = '─' * min(max_width, 80)
        
        result = f"\n{COLORS['blue']}┌{border}┐{COLORS['reset']}\n"
        result += f"{COLORS['blue']}│{COLORS['bold']} Q CLI 完整回复 {' ' * (min(max_width, 80) - 12)}│{COLORS['reset']}\n"
        result += f"{COLORS['blue']}├{border}┤{COLORS['reset']}\n"
        
        for line in lines:
            if line.strip():
                result += f"{COLORS['blue']}│{COLORS['reset']} {line}\n"
            else:
                result += f"{COLORS['blue']}│{COLORS['reset']}\n"
        
        result += f"{COLORS['blue']}└{border}┘{COLORS['reset']}\n"
        
        return result
    
    def get_instance_output(self, instance_id: str) -> List[Dict[str, any]]:
        """获取实例输出"""
        if instance_id not in self.instances:
            return []
        
        instance = self.instances[instance_id]
        if not instance.output_queue:
            return []
        
        outputs = []
        try:
            while not instance.output_queue.empty():
                outputs.append(instance.output_queue.get_nowait())
        except queue.Empty:
            pass
        
        return outputs

# 全局实例管理器
instance_manager = InstanceManager()
