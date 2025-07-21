#!/bin/bash

# cliExtra 卸载脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== cliExtra 卸载脚本 ===${NC}"
echo ""

# 检查软链接
if [ -L "/usr/local/bin/cliExtra" ]; then
    echo -e "${YELLOW}删除软链接...${NC}"
    sudo rm -f /usr/local/bin/cliExtra
    echo -e "${GREEN}✓ 软链接已删除${NC}"
else
    echo -e "${YELLOW}未找到软链接${NC}"
fi

# 检查用户bin目录
if [ -L "$HOME/bin/cliExtra" ]; then
    echo -e "${YELLOW}删除用户bin目录中的软链接...${NC}"
    rm -f "$HOME/bin/cliExtra"
    echo -e "${GREEN}✓ 用户bin软链接已删除${NC}"
fi

echo ""
echo -e "${GREEN}=== 卸载完成 ===${NC}"
echo ""
echo -e "${YELLOW}注意: 请手动从shell配置文件中删除PATH设置${NC}"
echo "  检查并删除以下文件中的cliExtra相关行:"
echo "    ~/.zshrc"
echo "    ~/.bashrc"
echo ""
echo -e "${BLUE}示例删除内容:${NC}"
echo "  # cliExtra PATH"
echo "  export PATH=\"/usr/local/bin:\$PATH\"" 