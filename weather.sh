#!/bin/bash

# 天气查询脚本
# 使用方法: ./weather.sh [城市名] [选项]

CITY="${1:-}"
FORMAT="${2:-full}"

# 帮助信息
show_help() {
    echo "天气查询工具"
    echo "使用方法: $0 [城市名] [格式]"
    echo ""
    echo "参数:"
    echo "  城市名    可选，不指定则自动检测位置"
    echo "  格式      可选值: full(默认), simple, today"
    echo ""
    echo "示例:"
    echo "  $0                    # 当前位置完整天气"
    echo "  $0 Beijing            # 北京完整天气"
    echo "  $0 Shanghai simple    # 上海简化天气"
    echo "  $0 Guangzhou today    # 广州今日天气"
}

# 检查参数
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# 构建URL
if [[ -n "$CITY" ]]; then
    URL="wttr.in/$CITY"
else
    URL="wttr.in"
fi

# 根据格式选择参数
case "$FORMAT" in
    "simple")
        URL="$URL?format=3"
        ;;
    "today")
        URL="$URL?0"
        ;;
    "full"|*)
        # 默认完整格式，不添加参数
        ;;
esac

# 执行查询
echo "正在查询天气信息..."
echo "URL: $URL"
echo ""

curl -s "$URL"

# 检查执行结果
if [[ $? -eq 0 ]]; then
    echo ""
    echo "查询完成！"
else
    echo "天气查询失败，请检查网络连接。"
    exit 1
fi
