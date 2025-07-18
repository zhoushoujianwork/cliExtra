#!/bin/bash

# Q Chat Manager 启动脚本

echo "🚀 启动 Q Chat Manager..."

# 检查Python环境
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 未安装"
    exit 1
fi

# 检查Q CLI
if ! command -v q &> /dev/null; then
    echo "❌ Q CLI 未安装，请先安装 Amazon Q Developer CLI"
    exit 1
fi

# 创建虚拟环境（如果不存在）
if [ ! -d "venv" ]; then
    echo "📦 创建虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
echo "🔧 激活虚拟环境..."
source venv/bin/activate

# 安装依赖
echo "📚 安装依赖..."
pip install -r requirements.txt

# 创建日志目录
mkdir -p logs

# 设置环境变量
export FLASK_ENV=development
export FLASK_DEBUG=1

echo "✅ 启动完成！"
echo "🌐 访问地址: http://localhost:5001"
echo "📝 日志文件: logs/app.log"
echo ""

# 启动应用
python3 run.py
