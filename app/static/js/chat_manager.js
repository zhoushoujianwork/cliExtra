// Q Chat Manager JavaScript
let availableInstances = [];
let currentAtPosition = -1;
const socket = io();

// WebSocket事件处理
socket.on('connect', function() {
    console.log('WebSocket连接成功');
    addSystemMessage('WebSocket连接成功 🔗');
});

socket.on('disconnect', function() {
    console.log('WebSocket连接断开');
    addSystemMessage('WebSocket连接断开 ❌');
});

socket.on('instance_output', function(data) {
    console.log('收到实例输出:', data);
    // 旧的分段输出，暂时忽略
});

socket.on('instance_complete_response', function(data) {
    console.log('收到完整回复:', data);
    addInstanceCompleteMessage(data.instance_id, data.raw_content, data.timestamp);
});

// 添加完整实例回复
function addInstanceCompleteMessage(instanceId, content, timestamp) {
    const container = document.getElementById('chatHistory');
    
    const messageDiv = document.createElement('div');
    messageDiv.className = 'message mb-3 p-3 border rounded';
    messageDiv.innerHTML = `
        <div class="d-flex justify-content-between align-items-center mb-2">
            <strong class="text-success">
                <i class="fas fa-robot me-1"></i>实例${instanceId} 完整回复
            </strong>
            <small class="text-muted">${timestamp}</small>
        </div>
        <div class="response-content">
            ${formatMarkdownForWeb(content)}
        </div>
    `;
    
    container.appendChild(messageDiv);
    container.scrollTop = container.scrollHeight;
}

// 将markdown格式化为HTML
function formatMarkdownForWeb(content) {
    let formatted = content;
    
    // 转义HTML
    formatted = formatted.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    
    // 处理代码块
    formatted = formatted.replace(/```(\w+)?\n([\s\S]*?)\n```/g, function(match, lang, code) {
        return `<div class="code-block mt-2 mb-2">
            <div class="code-header bg-dark text-white px-2 py-1 small">${lang || 'code'}</div>
            <pre class="bg-light p-2 mb-0"><code>${code}</code></pre>
        </div>`;
    });
    
    // 处理行内代码
    formatted = formatted.replace(/`([^`]+)`/g, '<code class="bg-light px-1">$1</code>');
    
    // 处理标题
    formatted = formatted.replace(/^### (.*?)$/gm, '<h5 class="text-warning mt-3 mb-2">$1</h5>');
    formatted = formatted.replace(/^## (.*?)$/gm, '<h4 class="text-success mt-3 mb-2">$1</h4>');
    formatted = formatted.replace(/^# (.*?)$/gm, '<h3 class="text-primary mt-3 mb-2">$1</h3>');
    
    // 处理粗体
    formatted = formatted.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
    
    // 处理斜体
    formatted = formatted.replace(/\*(.*?)\*/g, '<em>$1</em>');
    
    // 处理列表
    formatted = formatted.replace(/^- (.*?)$/gm, '<li class="ms-3">$1</li>');
    formatted = formatted.replace(/^(\d+)\. (.*?)$/gm, '<li class="ms-3">$2</li>');
    
    // 处理链接
    formatted = formatted.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" class="text-decoration-none">$1 <i class="fas fa-external-link-alt small"></i></a>');
    
    // 处理换行
    formatted = formatted.replace(/\n/g, '<br>');
    
    return formatted;
}

// 页面初始化
document.addEventListener('DOMContentLoaded', function() {
    console.log('页面加载完成');
    setupAtMentionFeature();
    startAutoRefresh();
    
    // 绑定回车发送消息
    const messageInput = document.getElementById('messageInput');
    if (messageInput) {
        messageInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
            }
        });
    }
});

// @功能设置
function setupAtMentionFeature() {
    const messageInput = document.getElementById('messageInput');
    const suggestions = document.getElementById('instanceSuggestions');
    
    messageInput.addEventListener('input', function(e) {
        const value = e.target.value;
        const cursorPos = e.target.selectionStart;
        
        if (value[cursorPos - 1] === '@') {
            currentAtPosition = cursorPos - 1;
            showAllInstanceSuggestions();
        } else {
            const beforeCursor = value.substring(0, cursorPos);
            const atMatch = beforeCursor.match(/@([^@\s]*)$/);
            
            if (atMatch) {
                currentAtPosition = atMatch.index;
                const query = atMatch[1].toLowerCase();
                showFilteredInstanceSuggestions(query);
            } else {
                hideSuggestions();
                currentAtPosition = -1;
            }
        }
    });
}

function showAllInstanceSuggestions() {
    const suggestions = document.getElementById('instanceSuggestions');
    
    if (availableInstances.length > 0) {
        suggestions.innerHTML = availableInstances.map((instance, index) => `
            <div class="suggestion-item p-2 cursor-pointer ${index === 0 ? 'active' : ''}" 
                 data-instance-id="${instance.id}" 
                 onclick="selectInstanceFromSuggestion('${instance.id}')">
                <div class="d-flex align-items-center">
                    <i class="fas fa-server me-2 text-success"></i>
                    <div>
                        <strong>实例 ${instance.id}</strong>
                        <small class="text-muted d-block">${instance.details || '无描述'}</small>
                    </div>
                </div>
            </div>
        `).join('');
        suggestions.style.display = 'block';
    } else {
        suggestions.innerHTML = '<div class="p-2 text-muted">暂无可用实例</div>';
        suggestions.style.display = 'block';
    }
}

function selectInstanceFromSuggestion(instanceId) {
    const messageInput = document.getElementById('messageInput');
    const value = messageInput.value;
    const cursorPos = messageInput.selectionStart;
    
    if (currentAtPosition >= 0) {
        const beforeAt = value.substring(0, currentAtPosition);
        const afterCursor = value.substring(cursorPos);
        const newValue = beforeAt + `@实例${instanceId} ` + afterCursor;
        messageInput.value = newValue;
        
        const newCursorPos = currentAtPosition + `@实例${instanceId} `.length;
        messageInput.focus();
        messageInput.setSelectionRange(newCursorPos, newCursorPos);
    }
    
    hideSuggestions();
}

function hideSuggestions() {
    document.getElementById('instanceSuggestions').style.display = 'none';
    currentAtPosition = -1;
}

// 发送消息
function sendMessage() {
    const message = document.getElementById('messageInput').value.trim();
    
    if (!message) {
        alert('请输入消息');
        return;
    }
    
    const { instances, cleanMessage } = parseMessage(message);
    
    if (instances.length === 0) {
        alert('请使用@符号选择要发送消息的实例');
        return;
    }
    
    // 显示用户消息
    addMessageToChat('user', message);
    document.getElementById('messageInput').value = '';
    
    // 发送到各个实例
    instances.forEach(instanceId => {
        fetch('/api/send', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ instance_id: instanceId, message: cleanMessage })
        })
        .then(r => r.json())
        .then(data => {
            if (!data.success) {
                addSystemMessage(`向实例${instanceId}发送失败: ${data.error}`);
            }
        });
    });
}

// 解析@提及
function parseMessage(message) {
    const atMatches = message.match(/@实例(\w+)/g);
    if (!atMatches) {
        return { instances: [], cleanMessage: message };
    }
    
    const instances = atMatches.map(match => match.replace('@实例', ''));
    const cleanMessage = message.replace(/@实例\w+\s*/g, '').trim();
    
    return { instances, cleanMessage };
}

// 添加消息到聊天
function addMessageToChat(sender, message) {
    const container = document.getElementById('chatHistory');
    const now = new Date().toLocaleString();
    
    const messageDiv = document.createElement('div');
    messageDiv.className = 'message mb-2';
    messageDiv.innerHTML = `
        <small class="text-muted">${now}</small>
        <div class="d-flex">
            <strong class="me-2 ${sender === 'user' ? 'text-primary' : 'text-success'}">${sender}:</strong>
            <span style="white-space: pre-wrap;">${message}</span>
        </div>
    `;
    
    container.appendChild(messageDiv);
    container.scrollTop = container.scrollHeight;
}

// 添加实例消息
function addInstanceMessage(instanceId, content, timestamp) {
    const container = document.getElementById('chatHistory');
    
    const messageDiv = document.createElement('div');
    messageDiv.className = 'message mb-2';
    messageDiv.innerHTML = `
        <small class="text-muted">${timestamp}</small>
        <div class="d-flex">
            <strong class="me-2 text-success">实例${instanceId}:</strong>
            <span style="white-space: pre-wrap;">${content}</span>
        </div>
    `;
    
    container.appendChild(messageDiv);
    container.scrollTop = container.scrollHeight;
}

// 添加系统消息
function addSystemMessage(message) {
    const container = document.getElementById('systemLogs');
    const now = new Date().toLocaleString();
    
    const messageDiv = document.createElement('div');
    messageDiv.className = 'system-message mb-2 p-2 border-start border-info border-3';
    messageDiv.innerHTML = `
        <small class="text-muted d-block">${now}</small>
        <div class="text-info">
            <i class="fas fa-info-circle me-1"></i>
            <span>${message}</span>
        </div>
    `;
    
    container.appendChild(messageDiv);
    container.scrollTop = container.scrollHeight;
}

// 实例管理函数
function startInstance() {
    const instanceId = document.getElementById('newInstanceId').value.trim();
    if (!instanceId) {
        alert('请输入实例ID');
        return;
    }
    
    fetch(`/api/start/${instanceId}`, { method: 'POST' })
        .then(r => r.json())
        .then(data => {
            if (data.success) {
                document.getElementById('newInstanceId').value = '';
                refreshInstances();
                socket.emit('join_monitoring', { instance_id: instanceId });
            } else {
                alert('启动失败: ' + data.error);
            }
        });
}

function stopInstance(id) {
    fetch(`/api/stop/${id}`, { method: 'POST' })
        .then(r => r.json())
        .then(data => {
            if (data.success) {
                refreshInstances();
            } else {
                alert('停止失败: ' + data.error);
            }
        });
}

function cleanAll() {
    if (confirm('确定清理所有实例？')) {
        fetch('/api/clean', { method: 'POST' })
            .then(r => r.json())
            .then(data => {
                refreshInstances();
            });
    }
}

function refreshInstances() {
    fetch('/api/instances')
        .then(r => r.json())
        .then(data => {
            if (data.success) {
                availableInstances = data.instances;
                updateInstancesList(data.instances);
            }
        });
}

function updateInstancesList(instances) {
    const container = document.getElementById('instancesList');
    container.innerHTML = instances.map(instance => `
        <div class="instance-item mb-2 p-2 border rounded">
            <div class="d-flex justify-content-between">
                <span><strong>实例 ${instance.id}</strong></span>
                <button class="btn btn-sm btn-danger" onclick="stopInstance('${instance.id}')">停止</button>
            </div>
            <small class="text-muted">${instance.details}</small>
        </div>
    `).join('');
}

function clearSystemLogs() {
    document.getElementById('systemLogs').innerHTML = '';
    addSystemMessage('系统日志已清空');
}

// 自动刷新
let refreshInterval;
let autoRefreshEnabled = true;

function startAutoRefresh() {
    refreshInterval = setInterval(refreshInstances, 5000);
}

function toggleAutoRefresh() {
    const btn = document.getElementById('refreshBtn');
    if (autoRefreshEnabled) {
        clearInterval(refreshInterval);
        autoRefreshEnabled = false;
        btn.innerHTML = '<i class="fas fa-pause"></i> 自动刷新: 关闭';
        btn.className = 'btn btn-sm btn-warning';
    } else {
        startAutoRefresh();
        autoRefreshEnabled = true;
        btn.innerHTML = '<i class="fas fa-sync"></i> 自动刷新: 开启';
        btn.className = 'btn btn-sm btn-success';
    }
}

function manualRefresh() {
    refreshInstances();
    addSystemMessage('已刷新实例状态');
}
